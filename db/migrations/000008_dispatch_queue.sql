-- migrate:up transaction:false
-- ============================================================================
-- step6_dispatch_queue.sql
-- ----------------------------------------------------------------------------
-- Graceful n8n degradation (Handover Task 2).
--
-- Problem: when a money RPC (approve_and_commit / reject_ticket) succeeds, the
-- downstream side-effects (Slack notify, ERP queue, supplier email, etc.) were
-- previously fired by a synchronous n8nPost() from the browser. If n8n was
-- down, the DB write committed but the notification was silently lost — and the
-- UI had no durable record that a dispatch was owed.
--
-- Fix: a durable outbox. The RPC enqueues a row in dispatch_queue inside the
-- SAME transaction as the PO/status write. If n8n is down, the row simply waits
-- as 'pending'. An n8n polling workflow drains the queue with exponential
-- backoff and dead-letters after 5 attempts. The Ops Board can surface any
-- 'dead_letter' / long-'pending' rows as a banner.
--
-- INVARIANT-safe: this migration only ADDS an outbox insert at the tail of each
-- RPC. Every pre-existing line of approve_and_commit / reject_ticket is
-- preserved verbatim (locking, precondition, idempotency gate, budget, PO).
--
-- Idempotent: safe to re-run. CREATE TABLE IF NOT EXISTS; CREATE OR REPLACE fns.
-- ============================================================================

-- ── 1. Outbox table ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dispatch_queue (
  id            uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticket_id     uuid REFERENCES tickets(id),
  event_type    text NOT NULL,                       -- 'approved' | 'rejected' | 'closed'
  payload       jsonb NOT NULL,
  status        text NOT NULL DEFAULT 'pending',     -- pending | sent | failed | dead_letter
  attempts      int  NOT NULL DEFAULT 0,
  last_error    text,
  next_retry_at timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  sent_at       timestamptz,
  CONSTRAINT dispatch_queue_status_chk
    CHECK (status IN ('pending','sent','failed','dead_letter')),
  CONSTRAINT dispatch_queue_event_type_chk
    CHECK (event_type IN ('approved','rejected','closed'))
);

-- Drain query hits this constantly: pending rows due for (re)try, oldest first.
CREATE INDEX IF NOT EXISTS dispatch_queue_pending_idx
  ON dispatch_queue (status, next_retry_at, created_at)
  WHERE status IN ('pending','failed');

-- ── 2. Grants + RLS (mirror the action_ledger pattern from step5) ────────────
GRANT SELECT, INSERT, UPDATE ON dispatch_queue TO truespend_app;
GRANT SELECT, INSERT, UPDATE ON dispatch_queue TO truespend;

ALTER TABLE dispatch_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dispatch_queue_app_all  ON dispatch_queue;
DROP POLICY IF EXISTS dispatch_queue_role_all ON dispatch_queue;

CREATE POLICY dispatch_queue_app_all  ON dispatch_queue
  FOR ALL TO truespend_app USING (true) WITH CHECK (true);
CREATE POLICY dispatch_queue_role_all ON dispatch_queue
  FOR ALL TO truespend     USING (true) WITH CHECK (true);

-- ── 3. Enqueue helper ───────────────────────────────────────────────────────
-- SECURITY DEFINER so it can write the outbox even though callers route through
-- the RPC boundary. Best-effort by design: callers wrap it so a queueing fault
-- never rolls back a committed money write (the row can be reconciled later).
CREATE OR REPLACE FUNCTION enqueue_dispatch(
  p_ticket_id  uuid,
  p_event_type text,
  p_payload    jsonb
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
declare
  v_id uuid;
begin
  insert into dispatch_queue (ticket_id, event_type, payload, status, next_retry_at)
  values (p_ticket_id, p_event_type, coalesce(p_payload, '{}'::jsonb), 'pending', now())
  returning id into v_id;
  return v_id;
end $function$;

-- ============================================================================
-- 4. approve_and_commit — re-create with the outbox insert appended.
--    Every line above Step 8.5 is identical to the live (step5) definition.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.approve_and_commit(
  p_ticket_id uuid, p_branch_id uuid, p_branch_code text, p_cost_center_id uuid,
  p_category spend_category, p_period text, p_supplier_id uuid, p_contract_id uuid,
  p_description text, p_amount numeric, p_currency text, p_amount_eur numeric,
  p_raised_by uuid, p_expected_delivery date, p_line_items jsonb
)
 RETURNS purchase_orders
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_po_number    text;
  v_po           purchase_orders;
  v_ticket       tickets;
  v_existing_po  purchase_orders;
  v_ledger_id    uuid;

  -- Identity guard — dormant until SSO issues app_role in the JWT.
  claims         json    := current_setting('request.jwt.claims', true)::json;
  approver_role  text    := claims->>'app_role';

  -- Statuses that may be approved
  approvable     ticket_status[] := array[
    'pending_confirm'::ticket_status,
    'pending_review'::ticket_status,
    'signature_required'::ticket_status,
    'escalated'::ticket_status
  ];
begin
  -- ── Role guard (dormant until SSO) ───────────────────────────────────────
  -- TODO(SSO): drop `approver_role IS NOT NULL AND` to go fail-closed.
  if approver_role is not null
     and approver_role not in ('procurement', 'admin') then
    raise exception 'not authorised to approve (app_role: %)', approver_role
      using errcode = '42501';
  end if;

  -- ── Step 1: Lock the ticket row (serialises concurrent approvers) ─────────
  select * into v_ticket
  from tickets
  where id = p_ticket_id
  for update;

  if not found then
    raise exception 'Ticket not found: %', p_ticket_id;
  end if;

  -- ── Step 2: Precondition check (after lock — sees committed state) ────────
  if v_ticket.status <> all(approvable) then
    if v_ticket.status = 'approved' and v_ticket.po_id is not null then
      select * into v_existing_po from purchase_orders where id = v_ticket.po_id;
      if found then
        insert into action_ledger (ticket_id, action, actor_role, outcome, po_id, amount_eur, notes)
        values (p_ticket_id, 'approve', approver_role, 'duplicate', v_existing_po.id, p_amount_eur,
                'Duplicate approve attempt — ticket already approved')
        on conflict (ticket_id, action) do nothing;
        return v_existing_po;
      end if;
    end if;
    raise exception 'Ticket % cannot be approved: current status is %',
      p_ticket_id, v_ticket.status
      using errcode = '55000';
  end if;

  -- ── Step 3: Idempotency gate — claim the action slot ─────────────────────
  begin
    insert into action_ledger (ticket_id, action, actor_role, outcome, amount_eur)
    values (p_ticket_id, 'approve', approver_role, 'committed', p_amount_eur)
    returning id into v_ledger_id;
  exception
    when unique_violation then
      select po.* into v_existing_po
      from purchase_orders po
      where po.ticket_id = p_ticket_id
      order by po.created_at desc
      limit 1;
      if found then return v_existing_po; end if;
      raise exception 'Concurrent approval in progress for ticket %; retry in a moment', p_ticket_id
        using errcode = '55P03';
  end;

  -- ── Step 4: Generate PO number (atomic sequence) ──────────────────────────
  v_po_number := next_po_number(p_branch_id, p_branch_code);

  -- ── Step 5: Commit budget (row-level lock, raises if insufficient) ─────────
  perform commit_budget(
    p_branch_id, p_cost_center_id, p_category, p_period, p_amount_eur
  );

  -- ── Step 6: Create PO row ─────────────────────────────────────────────────
  insert into purchase_orders (
    po_number, ticket_id, contract_id, supplier_id, branch_id,
    cost_center_id, raised_by, description, category, line_items,
    amount, currency, amount_eur, po_date, expected_delivery, status
  ) values (
    v_po_number, p_ticket_id, p_contract_id, p_supplier_id, p_branch_id,
    p_cost_center_id, p_raised_by, p_description, p_category, p_line_items,
    p_amount, p_currency, p_amount_eur, current_date, p_expected_delivery, 'draft'
  )
  returning * into v_po;

  -- ── Step 7: Update ledger with PO reference ───────────────────────────────
  update action_ledger set po_id = v_po.id where id = v_ledger_id;

  -- ── Step 8: Update ticket (status + PO link) ──────────────────────────────
  update tickets
  set status     = 'approved',
      po_id      = v_po.id,
      updated_at = now()
  where id = p_ticket_id;

  -- ── Step 8.5: Durable dispatch (NEW — Task 2) ─────────────────────────────
  -- Enqueue the 'approved' event in the same transaction. If n8n is down the
  -- row waits as 'pending' and is drained later — the approval is never lost.
  -- Best-effort: a queueing fault must NOT roll back the committed money write.
  begin
    perform enqueue_dispatch(
      p_ticket_id,
      'approved',
      jsonb_build_object(
        'ticket_id',  p_ticket_id,
        'po_id',      v_po.id,
        'po_number',  v_po.po_number,
        'supplier_id', p_supplier_id,
        'branch_id',  p_branch_id,
        'category',   p_category,
        'amount_eur', p_amount_eur,
        'currency',   p_currency,
        'description', p_description,
        'approved_at', now()
      )
    );
  exception
    when others then
      -- Never fail the approval because notification queueing hiccupped.
      raise warning 'enqueue_dispatch(approved) failed for ticket %: %', p_ticket_id, sqlerrm;
  end;

  return v_po;
end $function$;

-- ============================================================================
-- 5. reject_ticket — re-create with the outbox insert appended.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.reject_ticket(
  p_ticket_id uuid, p_branch_id uuid, p_cost_center_id uuid,
  p_category spend_category, p_period text, p_committed_amount numeric
)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_ticket     tickets;
  claims       json := current_setting('request.jwt.claims', true)::json;
  rejecter_role text := claims->>'app_role';

  rejectable   ticket_status[] := array[
    'pending_confirm'::ticket_status,
    'pending_review'::ticket_status,
    'signature_required'::ticket_status,
    'escalated'::ticket_status,
    'open'::ticket_status,
    'reasoning'::ticket_status
  ];
begin
  -- Dormant role guard — same pattern as approve_and_commit.
  if rejecter_role is not null
     and rejecter_role not in ('procurement', 'admin') then
    raise exception 'not authorised to reject (app_role: %)', rejecter_role
      using errcode = '42501';
  end if;

  -- Lock the ticket row (serialises concurrent reject + approve)
  select * into v_ticket from tickets where id = p_ticket_id for update;
  if not found then
    raise exception 'Ticket not found: %', p_ticket_id;
  end if;

  -- Precondition: already rejected/closed → idempotent no-op
  if v_ticket.status = 'rejected' or v_ticket.status = 'closed' then
    insert into action_ledger (ticket_id, action, actor_role, outcome, notes)
    values (p_ticket_id, 'reject', rejecter_role, 'duplicate',
            'Duplicate reject attempt — ticket already in status: ' || v_ticket.status)
    on conflict (ticket_id, action) do nothing;
    return;
  end if;

  if v_ticket.status <> all(rejectable) then
    raise exception 'Ticket % cannot be rejected: current status is %',
      p_ticket_id, v_ticket.status
      using errcode = '55000';
  end if;

  -- Idempotency gate
  insert into action_ledger (ticket_id, action, actor_role, outcome, amount_eur)
  values (p_ticket_id, 'reject', rejecter_role, 'rejected', p_committed_amount)
  on conflict (ticket_id, action) do nothing;

  -- Release committed budget if any was pre-committed
  if p_committed_amount > 0 and p_branch_id is not null then
    begin
      perform release_budget(
        p_branch_id, p_cost_center_id, p_category, p_period, p_committed_amount
      );
    exception
      when others then
        null;
    end;
  end if;

  -- Set ticket status
  update tickets
  set status     = 'rejected',
      updated_at = now(),
      closed_at  = now()
  where id = p_ticket_id;

  -- ── Durable dispatch (NEW — Task 2) ───────────────────────────────────────
  begin
    perform enqueue_dispatch(
      p_ticket_id,
      'rejected',
      jsonb_build_object(
        'ticket_id',   p_ticket_id,
        'branch_id',   p_branch_id,
        'category',    p_category,
        'released_eur', p_committed_amount,
        'rejected_at', now()
      )
    );
  exception
    when others then
      raise warning 'enqueue_dispatch(rejected) failed for ticket %: %', p_ticket_id, sqlerrm;
  end;
end $function$;

-- ============================================================================
-- 6. Grants on the RPCs are unchanged (CREATE OR REPLACE preserves them), but
--    re-assert EXECUTE on the helper for the login roles.
-- ============================================================================
GRANT EXECUTE ON FUNCTION enqueue_dispatch(uuid, text, jsonb) TO truespend_app;
GRANT EXECUTE ON FUNCTION enqueue_dispatch(uuid, text, jsonb) TO truespend;

-- migrate:down transaction:false
-- Irreversible / forward-only migration. Roll forward with a new migration
-- per invariant I-8; no automated down path.
select 1;
