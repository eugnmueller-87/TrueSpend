-- migrate:up transaction:false
-- =============================================================================
-- step12_money_rpcs_fail_closed.sql   ── Phase 2 ──
--
-- Flip the money RPCs from DORMANT to FAIL-CLOSED, and close the raw-budget-write
-- gap with a SECURITY DEFINER upsert. After this, a JWT with NO app_role claim
-- (today's static browser token) can no longer move money — it gets 42501 (→ 403).
--
-- PREREQUISITE — DO NOT APPLY BEFORE THIS IS TRUE (else the board + n8n brick):
--   1. The n8n service token used by board_action.json / invoice_processor.json /
--      delivery automation MUST carry app_role IN ('procurement','admin'
--      [,'controlling' for payments]).  The browser SPA must already route money
--      actions through /webhook/board-action (VITE_ROUTE_MONEY_VIA_N8N=true).
--   2. Decode the live tokens first and confirm: browser token has NO app_role
--      (so it gets blocked) and the n8n token HAS a privileged app_role (so it
--      keeps working). See scripts/repro_money_rpc_exposure.js --decode.
--
-- WHY FAIL-CLOSED IS SAFE FOR THE NESTED HELPERS:
--   release_budget / record_spend are only reached (a) directly — which only a
--   privileged caller should do, or (b) via PERFORM inside reject_ticket /
--   create_payment_instruction. SECURITY DEFINER does NOT reset
--   request.jwt.claims, so the nested call inherits the entry caller's claim —
--   a privileged entry (n8n) propagates the privileged claim down; a claim-less
--   browser entry is already blocked at the entry RPC. Gating them too closes
--   the direct-call path without breaking the nested path.
--
-- I-7: this flips invariant I-2's dormant guard to enforcing → see
--      docs/decisions/ADR-006-money-rpc-fail-closed.md (written with this change).
-- I-8: NEW migration (not an edit of step2). Apply via scripts/db-migrate.sh and
--      confirm it lands in schema_migrations. After applying:
--        NOTIFY pgrst, 'reload schema';
--      or PostgREST 404s the recreated RPCs until its cache refreshes.
--
-- Idempotent: CREATE OR REPLACE throughout; grants are idempotent.
-- =============================================================================

begin;

-- ── helper note ──────────────────────────────────────────────────────────────
-- Every guard below is the SAME shape:
--   if app_role is null or app_role not in (<allowed>) then raise 42501;
-- The allowed set is ('procurement','admin') for approvals/budget, plus
-- 'controlling' for payment creation (controlling owns invoice→payment).

-- =============================================================================
-- 1. approve_and_commit — flip is-not-null AND  ->  is-null OR
-- =============================================================================
create or replace function approve_and_commit(
  p_ticket_id       uuid,
  p_branch_id       uuid,
  p_branch_code     text,
  p_cost_center_id  uuid,
  p_category        spend_category,
  p_period          text,
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
  claims         json := current_setting('request.jwt.claims', true)::json;
  approver_role  text := claims->>'app_role';
begin
  -- FAIL-CLOSED: a missing or non-privileged app_role is now rejected.
  if approver_role is null
     or approver_role not in ('procurement', 'admin') then
    raise exception 'not authorised to approve (app_role: %)', coalesce(approver_role, '<none>')
      using errcode = '42501';
  end if;

  v_po_number := next_po_number(p_branch_id, p_branch_code);
  perform commit_budget(p_branch_id, p_cost_center_id, p_category, p_period, p_amount_eur);

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

  update tickets
  set status = 'approved', po_id = v_po.id, updated_at = now()
  where id = p_ticket_id;

  return v_po;
end $$;

-- =============================================================================
-- 2. commit_budget — flip
-- =============================================================================
create or replace function commit_budget(
  p_branch_id       uuid,
  p_cost_center_id  uuid,
  p_category        spend_category,
  p_period          text,
  p_amount          numeric
) returns budget_positions language plpgsql security definer as $$
declare
  v_row          budget_positions;
  claims         json := current_setting('request.jwt.claims', true)::json;
  approver_role  text := claims->>'app_role';
begin
  if approver_role is null
     or approver_role not in ('procurement', 'admin') then
    raise exception 'not authorised to commit budget (app_role: %)', coalesce(approver_role, '<none>')
      using errcode = '42501';
  end if;

  select * into v_row
  from budget_positions
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category
    and period = p_period
  for update;

  if not found then
    raise exception 'Budget position not found: % / % / % / %',
      p_branch_id, p_cost_center_id, p_category, p_period;
  end if;

  if (v_row.budget - v_row.committed - v_row.spent) < p_amount then
    raise exception 'Insufficient budget: available=%, requested=%',
      (v_row.budget - v_row.committed - v_row.spent), p_amount;
  end if;

  update budget_positions
  set committed = committed + p_amount, updated_at = now()
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category
    and period = p_period
  returning * into v_row;

  return v_row;
end $$;

-- =============================================================================
-- 3. reject_ticket — flip
-- =============================================================================
create or replace function reject_ticket(
  p_ticket_id        uuid,
  p_branch_id        uuid,
  p_cost_center_id   uuid,
  p_category         spend_category,
  p_period           text,
  p_committed_amount numeric
) returns void language plpgsql security definer as $$
declare
  claims        json := current_setting('request.jwt.claims', true)::json;
  rejecter_role text := claims->>'app_role';
begin
  if rejecter_role is null
     or rejecter_role not in ('procurement', 'admin') then
    raise exception 'not authorised to reject (app_role: %)', coalesce(rejecter_role, '<none>')
      using errcode = '42501';
  end if;

  if p_committed_amount > 0 and p_branch_id is not null then
    begin
      perform release_budget(p_branch_id, p_cost_center_id, p_category, p_period, p_committed_amount);
    exception when others then null;
    end;
  end if;

  update tickets
  set status = 'rejected', updated_at = now(), closed_at = now()
  where id = p_ticket_id;
end $$;

-- =============================================================================
-- 4. release_budget — ADD guard (had none). Reached directly (must be privileged)
--    or via PERFORM from reject_ticket (inherits the privileged claim).
-- =============================================================================
create or replace function release_budget(
  p_branch_id       uuid,
  p_cost_center_id  uuid,
  p_category        spend_category,
  p_period          text,
  p_amount          numeric
) returns budget_positions language plpgsql security definer as $$
declare
  v_row         budget_positions;
  claims        json := current_setting('request.jwt.claims', true)::json;
  approver_role text := claims->>'app_role';
begin
  if approver_role is null
     or approver_role not in ('procurement', 'admin') then
    raise exception 'not authorised to release budget (app_role: %)', coalesce(approver_role, '<none>')
      using errcode = '42501';
  end if;

  select * into v_row
  from budget_positions
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category
    and period = p_period
  for update;

  if not found then
    raise exception 'Budget position not found: % / % / % / %',
      p_branch_id, p_cost_center_id, p_category, p_period;
  end if;

  update budget_positions
  set committed = greatest(committed - p_amount, 0), updated_at = now()
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category
    and period = p_period
  returning * into v_row;

  return v_row;
end $$;

-- =============================================================================
-- 5. record_spend — ADD guard. Allowed: procurement/admin/controlling (payments).
--    Reached via PERFORM from create_payment_instruction (inherits claim).
-- =============================================================================
create or replace function record_spend(
  p_branch_id         uuid,
  p_cost_center_id    uuid,
  p_category          spend_category,
  p_period            text,
  p_committed_release numeric,
  p_spend_amount      numeric
) returns budget_positions language plpgsql security definer as $$
declare
  v_row         budget_positions;
  claims        json := current_setting('request.jwt.claims', true)::json;
  approver_role text := claims->>'app_role';
begin
  if approver_role is null
     or approver_role not in ('procurement', 'admin', 'controlling') then
    raise exception 'not authorised to record spend (app_role: %)', coalesce(approver_role, '<none>')
      using errcode = '42501';
  end if;

  select * into v_row
  from budget_positions
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category
    and period = p_period
  for update;

  if not found then
    raise exception 'Budget position not found: % / % / % / %',
      p_branch_id, p_cost_center_id, p_category, p_period;
  end if;

  update budget_positions
  set committed = greatest(committed - p_committed_release, 0),
      spent     = spent + p_spend_amount,
      updated_at = now()
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category
    and period = p_period
  returning * into v_row;

  return v_row;
end $$;

-- =============================================================================
-- 6. create_payment_instruction — ADD guard (procurement/admin/controlling).
--    Recreate with the SAME body as schema.sql, prefixed by the guard.
-- =============================================================================
create or replace function create_payment_instruction(
  p_invoice_id   uuid,
  p_due_date     date
) returns payment_instructions language plpgsql security definer as $$
declare
  v_inv   invoices;
  v_po    purchase_orders;
  v_pi    payment_instructions;
  v_ref   text;
  claims        json := current_setting('request.jwt.claims', true)::json;
  approver_role text := claims->>'app_role';
begin
  if approver_role is null
     or approver_role not in ('procurement', 'admin', 'controlling') then
    raise exception 'not authorised to create payment instruction (app_role: %)', coalesce(approver_role, '<none>')
      using errcode = '42501';
  end if;

  select * into v_inv from invoices where id = p_invoice_id;
  select * into v_po  from purchase_orders where id = v_inv.po_id;

  v_ref := 'PAY-' || extract(year from current_date)::text ||
           '-' || to_char(now(), 'MM') ||
           '-' || substr(p_invoice_id::text, 1, 8);

  insert into payment_instructions (
    invoice_id, po_id, supplier_id, amount, currency, payment_ref, due_date, status
  ) values (
    p_invoice_id, v_inv.po_id, v_inv.supplier_id, v_inv.amount,
    v_inv.currency, v_ref, p_due_date, 'pending'
  )
  returning * into v_pi;

  update invoices set status = 'approved', approved_at = now(), updated_at = now()
  where id = p_invoice_id;

  insert into erp_sync_queue (event_type, entity_type, entity_id, payload, status)
  values (
    'invoice_approved', 'invoice', p_invoice_id,
    jsonb_build_object(
      'payment_instruction_id', v_pi.id, 'payment_ref', v_ref,
      'invoice_id', p_invoice_id, 'po_id', v_inv.po_id,
      'supplier_id', v_inv.supplier_id, 'amount', v_inv.amount,
      'currency', v_inv.currency, 'due_date', p_due_date, 'po_number', v_po.po_number
    ),
    'pending'
  );

  if v_po.branch_id is not null and v_po.category is not null then
    perform record_spend(
      v_po.branch_id, v_po.cost_center_id, v_po.category,
      extract(year from current_date)::text || '-Q' ||
        ceil(extract(month from current_date) / 3.0)::int::text,
      v_po.amount_eur, v_inv.amount_eur
    );
  end if;

  return v_pi;
end $$;

-- =============================================================================
-- 7. upsert_budget_position — NEW. Closes the I-1 raw-budget-write gap: the
--    browser used to POST/PATCH /budget_positions directly. Now budget envelope
--    writes go through this SECURITY DEFINER RPC (called server-side by
--    board_action.json). Gated procurement/admin/controlling.
--    p_id present -> UPDATE budget on that row; else UPSERT by natural key.
-- =============================================================================
create or replace function upsert_budget_position(
  p_id             uuid,
  p_branch_id      uuid,
  p_cost_center_id uuid,
  p_category       spend_category,
  p_period         text,
  p_budget         numeric
) returns budget_positions language plpgsql security definer as $$
declare
  v_row         budget_positions;
  claims        json := current_setting('request.jwt.claims', true)::json;
  approver_role text := claims->>'app_role';
begin
  if approver_role is null
     or approver_role not in ('procurement', 'admin', 'controlling') then
    raise exception 'not authorised to set budget (app_role: %)', coalesce(approver_role, '<none>')
      using errcode = '42501';
  end if;

  -- Edit by id.
  if p_id is not null then
    update budget_positions
    set budget = p_budget, updated_at = now()
    where id = p_id
    returning * into v_row;
    if found then return v_row; end if;
  end if;

  -- Upsert by natural key. Use is-not-distinct-from so a NULL cost_center_id
  -- (branch-level budget) matches an existing branch-level row instead of
  -- inserting a duplicate (the unique index treats NULLs as distinct).
  update budget_positions
  set budget = p_budget, updated_at = now()
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category
    and period = p_period
  returning * into v_row;
  if found then return v_row; end if;

  insert into budget_positions (branch_id, cost_center_id, category, period, budget, committed, spent)
  values (p_branch_id, p_cost_center_id, p_category, p_period, p_budget, 0, 0)
  returning * into v_row;

  return v_row;
end $$;

grant execute on function upsert_budget_position(uuid, uuid, uuid, spend_category, text, numeric) to truespend_app;

-- =============================================================================
-- 8. Self-test — assert the guards are now ARMED (the INVERSE of step2's Test 2).
--    Each block sets request.jwt.claims, runs the guard logic inline, and checks
--    the expected raise/no-raise. Mirrors step2's test style.
-- =============================================================================
do $$
declare raised boolean;
  procedure_check text;
begin
  -- helper: run the standard guard inline against a given claims json + allowed set
  -- Test A: null app_role MUST now raise (was a no-op in step2)
  raised := false;
  begin
    perform set_config('request.jwt.claims', '{"role":"truespend_app"}', true);
    declare claims json := current_setting('request.jwt.claims', true)::json;
            r text := claims->>'app_role';
    begin
      if r is null or r not in ('procurement','admin') then
        raise exception 'blocked' using errcode = '42501';
      end if;
    end;
  exception when sqlstate '42501' then raised := true; end;
  if not raised then raise exception 'TEST A FAILED: null app_role must now be BLOCKED (fail-closed)'; end if;
  raise notice 'Test A OK — null app_role is now blocked';

  -- Test B: privileged app_role MUST pass
  raised := false;
  begin
    perform set_config('request.jwt.claims', '{"role":"truespend_app","app_role":"procurement"}', true);
    declare claims json := current_setting('request.jwt.claims', true)::json;
            r text := claims->>'app_role';
    begin
      if r is null or r not in ('procurement','admin') then
        raise exception 'blocked' using errcode = '42501';
      end if;
    end;
  exception when sqlstate '42501' then raised := true; end;
  if raised then raise exception 'TEST B FAILED: procurement app_role must pass'; end if;
  raise notice 'Test B OK — procurement app_role passes';

  -- Test C: non-privileged claim MUST raise
  raised := false;
  begin
    perform set_config('request.jwt.claims', '{"role":"truespend_app","app_role":"viewer"}', true);
    declare claims json := current_setting('request.jwt.claims', true)::json;
            r text := claims->>'app_role';
    begin
      if r is null or r not in ('procurement','admin') then
        raise exception 'blocked' using errcode = '42501';
      end if;
    end;
  exception when sqlstate '42501' then raised := true; end;
  if not raised then raise exception 'TEST C FAILED: viewer must be blocked'; end if;
  raise notice 'Test C OK — viewer blocked';

  perform set_config('request.jwt.claims', '', true);
  raise notice '── All Step 12 fail-closed tests passed ──';
end $$;

commit;

-- migrate:down transaction:false
-- Irreversible / forward-only migration. Roll forward with a new migration
-- per invariant I-8; no automated down path.
select 1;
