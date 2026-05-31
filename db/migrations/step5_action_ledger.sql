-- TrueSpend — Step 5: Action ledger + hardened money RPCs
-- Migration: 2026-05-31
--
-- PROBLEMS FIXED:
--   1. approve_and_commit is not idempotent — a client retry after a timeout
--      creates a second PO and double-commits the budget.
--   2. approve_and_commit does not lock the ticket row before acting — two
--      concurrent approvers can both pass the precondition check and both
--      reach commit_budget (which row-locks the budget position but not the
--      ticket), creating two POs if the budget has enough headroom for both.
--   3. No precondition check — approving an already-approved ticket creates
--      a second PO silently instead of returning "already actioned".
--   4. reject_ticket has the same concurrency and idempotency gaps.
--   5. No DB-level constraints: amount > 0, budget >= 0.
--
-- SOLUTION:
--   action_ledger table with UNIQUE(ticket_id, action):
--     - First approval: INSERT succeeds → proceed to commit_budget + PO create.
--     - Retry / second approver: INSERT hits unique constraint → return the
--       prior result immediately, zero side-effects.
--   Ticket row lock (SELECT FOR UPDATE) acquired BEFORE the ledger INSERT,
--   so two concurrent approvers are serialised at the ticket level.
--   Precondition check on ticket.status AFTER the lock, so the second
--   concurrent approver sees the updated status and raises "already actioned".
--
-- INVARIANT IMPACT:
--   I-1 (money writes through RPCs): unchanged — approve_and_commit is still
--        the only path that sets status='approved' and creates a PO.
--   I-2 (RLS / truespend_app role): unchanged — SECURITY DEFINER still bypasses.
--
-- Run with: psql $DATABASE_URL -f db/migrations/step5_action_ledger.sql
--   or:     bash scripts/db-migrate.sh
-- (run as truespend superuser — truespend_app lacks DDL)
-- =============================================================================


-- =============================================================================
-- 1. action_ledger table (idempotent)
-- =============================================================================
-- Stores one row per (ticket_id, action). The UNIQUE constraint is the
-- idempotency gate: a duplicate INSERT raises 23505, which the RPC catches
-- and converts to a safe "already done" return.
-- Also serves as the full audit trail: who did what, when, outcome.

create table if not exists action_ledger (
  id            uuid        primary key default uuid_generate_v4(),
  ticket_id     uuid        not null references tickets(id) on delete cascade,
  action        text        not null,          -- 'approve' | 'reject' | 'close'
  actor_role    text,                          -- JWT app_role claim (null until SSO)
  outcome       text        not null,          -- 'committed' | 'rejected' | 'closed' | 'duplicate'
  po_id         uuid        references purchase_orders(id),  -- set on approve
  amount_eur    numeric,                        -- amount at time of action
  notes         text,
  created_at    timestamptz not null default now(),

  -- The idempotency constraint: one terminal action per ticket per action-type
  constraint action_ledger_ticket_action_unique unique (ticket_id, action)
);

-- Indexes for audit queries
create index if not exists action_ledger_ticket_idx  on action_ledger (ticket_id);
create index if not exists action_ledger_created_idx on action_ledger (created_at desc);

do $$ begin raise notice '1 OK — action_ledger table created'; end $$;


-- =============================================================================
-- 2. Hardened approve_and_commit
-- =============================================================================
-- Changes from step2 version:
--   + SELECT ticket FOR UPDATE (serialises concurrent approvers)
--   + Precondition: ticket must be in an approvable status
--   + action_ledger INSERT ON CONFLICT returns prior PO (idempotent)
--   + All existing steps (budget commit, PO create, ticket update) unchanged

create or replace function approve_and_commit(
  p_ticket_id       uuid,
  p_branch_id       uuid,
  p_branch_code     text,
  p_cost_center_id  uuid,
  p_category        spend_category,
  p_period          text,          -- '2026-Q2'
  p_supplier_id     uuid,
  p_contract_id     uuid,
  p_description     text,
  p_amount          numeric,
  p_currency        text,
  p_amount_eur      numeric,
  p_raised_by       uuid,
  p_expected_delivery date,
  p_line_items      jsonb
) returns purchase_orders language plpgsql security definer as $$
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
  -- FOR UPDATE means the second concurrent caller blocks here until the first
  -- commits or rolls back. After the lock, we re-read the current status.
  select * into v_ticket
  from tickets
  where id = p_ticket_id
  for update;

  if not found then
    raise exception 'Ticket not found: %', p_ticket_id;
  end if;

  -- ── Step 2: Precondition check (after lock — sees committed state) ────────
  if v_ticket.status <> all(approvable) then
    -- Already actioned — return the associated PO if it exists, otherwise raise
    if v_ticket.status = 'approved' and v_ticket.po_id is not null then
      select * into v_existing_po from purchase_orders where id = v_ticket.po_id;
      if found then
        -- Log as duplicate attempt in ledger (best-effort, non-blocking)
        insert into action_ledger (ticket_id, action, actor_role, outcome, po_id, amount_eur, notes)
        values (p_ticket_id, 'approve', approver_role, 'duplicate', v_existing_po.id, p_amount_eur,
                'Duplicate approve attempt — ticket already approved')
        on conflict (ticket_id, action) do nothing;
        return v_existing_po;
      end if;
    end if;
    raise exception 'Ticket % cannot be approved: current status is %',
      p_ticket_id, v_ticket.status
      using errcode = '55000';  -- object_not_in_prerequisite_state
  end if;

  -- ── Step 3: Idempotency gate — claim the action slot ─────────────────────
  -- If this insert succeeds, we own the approval. If it fails (23505 unique
  -- violation), another concurrent call already committed — return their PO.
  begin
    insert into action_ledger (ticket_id, action, actor_role, outcome, amount_eur)
    values (p_ticket_id, 'approve', approver_role, 'committed', p_amount_eur)
    returning id into v_ledger_id;
  exception
    when unique_violation then  -- 23505
      -- A concurrent approve already committed. Return their PO.
      select po.* into v_existing_po
      from purchase_orders po
      where po.ticket_id = p_ticket_id
      order by po.created_at desc
      limit 1;
      if found then return v_existing_po; end if;
      -- Ledger entry exists but PO wasn't created yet (race window) — fall through to create
      raise exception 'Concurrent approval in progress for ticket %; retry in a moment', p_ticket_id
        using errcode = '55P03';  -- lock_not_available
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

  return v_po;
end $$;

do $$ begin raise notice '2 OK — approve_and_commit hardened (lock + precondition + idempotency)'; end $$;


-- =============================================================================
-- 3. Hardened reject_ticket
-- =============================================================================

create or replace function reject_ticket(
  p_ticket_id       uuid,
  p_branch_id       uuid,
  p_cost_center_id  uuid,
  p_category        spend_category,
  p_period          text,
  p_committed_amount numeric   -- pass 0 if nothing was committed
) returns void language plpgsql security definer as $$
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
  -- TODO(SSO): drop IS NOT NULL guard to go fail-closed.
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
    -- Already in a terminal state — log and return silently
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
        -- Budget position may not exist if ticket was never committed — that's fine
        null;
    end;
  end if;

  -- Set ticket status
  update tickets
  set status     = 'rejected',
      updated_at = now(),
      closed_at  = now()
  where id = p_ticket_id;
end $$;

do $$ begin raise notice '3 OK — reject_ticket hardened (lock + precondition + idempotency)'; end $$;


-- =============================================================================
-- 4. DB-enforced constraints (Step 3 items — tightly coupled, same migration)
-- =============================================================================

-- purchase_orders: amount must be positive
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where table_name = 'purchase_orders' and constraint_name = 'purchase_orders_amount_positive'
  ) then
    alter table purchase_orders
      add constraint purchase_orders_amount_positive check (amount > 0);
    raise notice '4a OK — CHECK amount > 0 on purchase_orders';
  else
    raise notice '4a SKIP — constraint purchase_orders_amount_positive already exists';
  end if;
end $$;

-- purchase_orders: amount_eur must be positive
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where table_name = 'purchase_orders' and constraint_name = 'purchase_orders_amount_eur_positive'
  ) then
    alter table purchase_orders
      add constraint purchase_orders_amount_eur_positive check (amount_eur > 0);
    raise notice '4b OK — CHECK amount_eur > 0 on purchase_orders';
  else
    raise notice '4b SKIP — constraint purchase_orders_amount_eur_positive already exists';
  end if;
end $$;

-- budget_positions: budget allocation must be non-negative
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where table_name = 'budget_positions' and constraint_name = 'budget_positions_budget_nonneg'
  ) then
    alter table budget_positions
      add constraint budget_positions_budget_nonneg check (budget >= 0);
    raise notice '4c OK — CHECK budget >= 0 on budget_positions';
  else
    raise notice '4c SKIP — constraint budget_positions_budget_nonneg already exists';
  end if;
end $$;

-- budget_positions: committed and spent must be non-negative
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where table_name = 'budget_positions' and constraint_name = 'budget_positions_committed_nonneg'
  ) then
    alter table budget_positions
      add constraint budget_positions_committed_nonneg check (committed >= 0);
    raise notice '4d OK — CHECK committed >= 0 on budget_positions';
  else
    raise notice '4d SKIP — constraint budget_positions_committed_nonneg already exists';
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where table_name = 'budget_positions' and constraint_name = 'budget_positions_spent_nonneg'
  ) then
    alter table budget_positions
      add constraint budget_positions_spent_nonneg check (spent >= 0);
    raise notice '4e OK — CHECK spent >= 0 on budget_positions';
  else
    raise notice '4e SKIP — constraint budget_positions_spent_nonneg already exists';
  end if;
end $$;

do $$ begin raise notice '4 OK — DB-enforced constraints added'; end $$;


-- =============================================================================
-- 5. Grants on action_ledger to truespend_app
-- =============================================================================
grant select, insert on action_ledger to truespend_app;
grant select, insert on action_ledger to truespend;

-- RLS: truespend_app needs a policy to read/write action_ledger
-- (RLS not enabled on action_ledger by default — enable and add policy
-- consistent with the pattern from step4)
alter table action_ledger enable row level security;

drop policy if exists "action_ledger_all_app" on action_ledger;
create policy "action_ledger_all_app" on action_ledger
  for all to truespend_app using (true) with check (true);

drop policy if exists "action_ledger_all" on action_ledger;
create policy "action_ledger_all" on action_ledger
  for all to truespend using (true) with check (true);

do $$ begin raise notice '5 OK — grants and RLS policy on action_ledger'; end $$;


-- =============================================================================
-- 6. Verification
-- =============================================================================
do $$
declare
  has_ledger          boolean;
  has_unique          boolean;
  has_approve_exec    boolean;
  has_reject_exec     boolean;
  has_po_amount_chk   boolean;
  has_bp_budget_chk   boolean;
  ledger_rls          boolean;
begin
  -- action_ledger exists
  select exists(
    select 1 from information_schema.tables
    where table_name = 'action_ledger'
  ) into has_ledger;
  if not has_ledger then
    raise exception 'FAIL: action_ledger table not found';
  end if;

  -- unique constraint on (ticket_id, action)
  select exists(
    select 1 from information_schema.table_constraints
    where table_name = 'action_ledger'
      and constraint_name = 'action_ledger_ticket_action_unique'
      and constraint_type = 'UNIQUE'
  ) into has_unique;
  if not has_unique then
    raise exception 'FAIL: action_ledger unique constraint not found';
  end if;

  -- approve_and_commit still executable by truespend_app
  select exists(
    select 1 from information_schema.role_routine_grants
    where grantee = 'truespend_app'
      and routine_name = 'approve_and_commit'
      and privilege_type = 'EXECUTE'
  ) into has_approve_exec;
  if not has_approve_exec then
    raise exception 'FAIL: truespend_app cannot execute approve_and_commit';
  end if;

  -- reject_ticket still executable by truespend_app
  select exists(
    select 1 from information_schema.role_routine_grants
    where grantee = 'truespend_app'
      and routine_name = 'reject_ticket'
      and privilege_type = 'EXECUTE'
  ) into has_reject_exec;
  if not has_reject_exec then
    raise exception 'FAIL: truespend_app cannot execute reject_ticket';
  end if;

  -- CHECK amount > 0 on purchase_orders
  select exists(
    select 1 from information_schema.table_constraints
    where table_name = 'purchase_orders'
      and constraint_name = 'purchase_orders_amount_positive'
  ) into has_po_amount_chk;
  if not has_po_amount_chk then
    raise exception 'FAIL: purchase_orders_amount_positive constraint missing';
  end if;

  -- CHECK budget >= 0 on budget_positions
  select exists(
    select 1 from information_schema.table_constraints
    where table_name = 'budget_positions'
      and constraint_name = 'budget_positions_budget_nonneg'
  ) into has_bp_budget_chk;
  if not has_bp_budget_chk then
    raise exception 'FAIL: budget_positions_budget_nonneg constraint missing';
  end if;

  -- RLS enabled on action_ledger
  select relrowsecurity into ledger_rls
  from pg_class where relname = 'action_ledger';
  if not ledger_rls then
    raise exception 'FAIL: RLS not enabled on action_ledger';
  end if;

  -- tickets.status still NOT directly updatable by truespend_app (I-1 invariant)
  declare has_status_update boolean;
  begin
    select exists(
      select 1 from information_schema.column_privileges
      where grantee = 'truespend_app' and table_name = 'tickets'
        and column_name = 'status' and privilege_type = 'UPDATE'
    ) into has_status_update;
    if has_status_update then
      raise exception 'BOUNDARY BROKEN: truespend_app has UPDATE(status) on tickets';
    end if;
  end;

  raise notice '6 OK — all verification checks passed';
  raise notice '  action_ledger: exists, unique constraint, RLS enabled';
  raise notice '  approve_and_commit + reject_ticket: executable by truespend_app';
  raise notice '  Constraints: amount>0 on POs, budget>=0 on budget_positions';
  raise notice '  tickets.status: still RPC-only';
end $$;
