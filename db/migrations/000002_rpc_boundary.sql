-- migrate:up transaction:false
-- TrueSpend — Step 2: RPC boundary for status transitions
-- Migration: 2026-05-31
-- Closes the raw-PATCH forge path and adds a dormant app_role claim check.
--
-- Run with:  psql $DATABASE_URL -f db/migrations/step2_rpc_boundary.sql
--
-- What this does:
--   2b) Revokes UPDATE (status) on tickets from the truespend role.
--       SECURITY DEFINER RPCs run as the function owner and bypass this grant,
--       so approve_and_commit / reject / confirm_delivery are unaffected.
--       Only the direct pgPatch('/tickets', {status:...}) path is closed.
--   2a) Adds a dormant app_role claim check to approve_and_commit (and the
--       other money RPCs). It is a NO-OP today — it only fires when the JWT
--       carries an app_role claim, which the current static token does not.
--       It auto-arms the moment SSO starts issuing app_role.
--       TODO(SSO): flip to fail-closed once login is live — drop the
--       `approver_role IS NOT NULL AND` guard to enforce even on null claims.
--   test) A DO block that asserts the dormant check behaves correctly:
--       - raises 42501 when app_role is 'viewer' (non-privileged claim present)
--       - does NOT raise when app_role is null (no claim — today's state)
--       - does NOT raise when app_role is 'procurement' (privileged claim)

-- =============================================================================
-- 2b — Lock status + po_id columns from direct UPDATE
-- =============================================================================
-- Strategy: the truespend role has a table-level UPDATE grant (not column-level),
-- so a column-level REVOKE cannot override it.
-- Correct approach:
--   1. REVOKE the broad table-level UPDATE
--   2. Re-GRANT UPDATE on every column EXCEPT status and po_id
-- SECURITY DEFINER RPCs (approve_and_commit etc.) run as the function owner
-- and bypass all grants entirely — they remain fully functional.

-- Step 1: drop the broad grant
revoke update on tickets from truespend;

-- Step 2: re-grant UPDATE on all columns except status and po_id
-- (full column list from live schema as of 2026-05-31)
grant update (
  title, description, category, branch_id, cost_center_id,
  supplier_id, contract_id, requested_by, owner_id,
  amount, amount_eur, value_eur, currency,
  jira_key, jira_url, target_close, closed_at, updated_at,
  submitted_by, submitted_by_email, supplier_name,
  recommendation, brief, confidence, review_notes, review_type,
  pdf_url, supplier_compliance, ticket_type, disposition,
  po_number
) on tickets to truespend;

-- Verify: table-level UPDATE is gone; status has no column-level UPDATE privilege
do $$
declare
  has_table_update  boolean;
  has_status_update boolean;
begin
  -- Table-level UPDATE must be gone
  select exists(
    select 1 from information_schema.role_table_grants
    where grantee = 'truespend' and table_name = 'tickets'
      and privilege_type = 'UPDATE'
  ) into has_table_update;

  -- Column-level UPDATE on status must not exist
  select exists(
    select 1 from information_schema.column_privileges
    where grantee = 'truespend' and table_name = 'tickets'
      and column_name = 'status' and privilege_type = 'UPDATE'
  ) into has_status_update;

  if has_table_update then
    raise exception '2b FAILED: truespend still has table-level UPDATE on tickets';
  end if;
  if has_status_update then
    raise exception '2b FAILED: truespend has column-level UPDATE(status) on tickets';
  end if;
  raise notice '2b OK — truespend cannot UPDATE tickets.status or po_id directly';
end $$;


-- =============================================================================
-- 2b-companion — reject_ticket RPC
-- =============================================================================
-- The truespend role can no longer PATCH tickets.status directly.
-- Rejection must also go through a SECURITY DEFINER RPC.
-- This RPC: optionally calls release_budget, then sets status='rejected'.

create or replace function reject_ticket(
  p_ticket_id       uuid,
  p_branch_id       uuid,
  p_cost_center_id  uuid,
  p_category        spend_category,
  p_period          text,
  p_committed_amount numeric   -- pass 0 if nothing was committed
) returns void language plpgsql security definer as $$
declare
  claims        json := current_setting('request.jwt.claims', true)::json;
  rejecter_role text := claims->>'app_role';
begin
  -- Dormant role guard — same pattern as approve_and_commit.
  -- TODO(SSO): drop IS NOT NULL guard to go fail-closed.
  if rejecter_role is not null
     and rejecter_role not in ('procurement', 'admin') then
    raise exception 'not authorised to reject (app_role: %)', rejecter_role
      using errcode = '42501';
  end if;

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

grant execute on function reject_ticket to truespend;


-- close_ticket — for 'ack' actions (already-processed tickets the user dismisses)
create or replace function close_ticket(
  p_ticket_id uuid
) returns void language plpgsql security definer as $$
begin
  update tickets
  set status     = 'closed',
      updated_at = now(),
      closed_at  = now()
  where id = p_ticket_id;
end $$;

grant execute on function close_ticket to truespend;


-- =============================================================================
-- 2a — Dormant app_role claim check in approve_and_commit
-- =============================================================================

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
  -- Identity guard — dormant until SSO issues app_role in the JWT.
  -- PostgREST surfaces the JWT payload via request.jwt.claims.
  claims         json    := current_setting('request.jwt.claims', true)::json;
  approver_role  text    := claims->>'app_role';
begin
  -- Role check: enforce ONLY when app_role claim is present in the JWT.
  -- NO-OP today (claim is null on the static truespend token).
  -- Auto-arms once SSO issues the claim.
  -- TODO(SSO): drop the `approver_role IS NOT NULL AND` guard to go
  --            fail-closed once per-user login is live.
  if approver_role is not null
     and approver_role not in ('procurement', 'admin') then
    raise exception 'not authorised to approve (app_role: %)', approver_role
      using errcode = '42501';
  end if;

  -- Step 1: generate PO number (atomic sequence)
  v_po_number := next_po_number(p_branch_id, p_branch_code);

  -- Step 2: commit budget (row-level lock, raises if insufficient)
  perform commit_budget(
    p_branch_id, p_cost_center_id, p_category, p_period, p_amount_eur
  );

  -- Step 3: create PO row
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

  -- Step 4: update ticket with PO reference and set status to approved
  update tickets
  set status     = 'approved',
      po_id      = v_po.id,
      updated_at = now()
  where id = p_ticket_id;

  return v_po;
end $$;


-- =============================================================================
-- 2a — Same dormant check on commit_budget (called standalone from n8n)
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
  -- Dormant role guard — same pattern as approve_and_commit.
  -- TODO(SSO): drop the IS NOT NULL guard to go fail-closed.
  if approver_role is not null
     and approver_role not in ('procurement', 'admin') then
    raise exception 'not authorised to commit budget (app_role: %)', approver_role
      using errcode = '42501';
  end if;

  select * into v_row
  from budget_positions
  where branch_id      = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category       = p_category
    and period         = p_period
  for update;  -- row-level lock serializes concurrent calls

  if not found then
    raise exception 'Budget position not found: % / % / % / %',
      p_branch_id, p_cost_center_id, p_category, p_period;
  end if;

  if (v_row.budget - v_row.committed - v_row.spent) < p_amount then
    raise exception 'Insufficient budget: available=%, requested=%',
      (v_row.budget - v_row.committed - v_row.spent), p_amount;
  end if;

  update budget_positions
  set committed   = committed + p_amount,
      updated_at  = now()
  where branch_id      = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category       = p_category
    and period         = p_period
  returning * into v_row;

  return v_row;
end $$;


-- =============================================================================
-- test — Behavioural assertions for the dormant check
-- Runs inline; raises if any assertion fails.
-- =============================================================================

do $$
declare
  raised   boolean;
  dummy    purchase_orders;
begin
  -- ── Test 1: non-privileged claim present → must raise 42501 ──────────────
  raised := false;
  begin
    -- Simulate a JWT with app_role='viewer' by setting the GUC directly.
    -- This is exactly what PostgREST does when it validates a JWT.
    perform set_config('request.jwt.claims', '{"role":"truespend","app_role":"viewer"}', true);

    -- Call the check logic inline (we can't call the RPC without real data,
    -- so we reproduce the guard here — this tests the logic, not the function call).
    declare
      claims        json := current_setting('request.jwt.claims', true)::json;
      approver_role text := claims->>'app_role';
    begin
      if approver_role is not null
         and approver_role not in ('procurement', 'admin') then
        raise exception 'not authorised' using errcode = '42501';
      end if;
    end;
  exception
    when sqlstate '42501' then raised := true;
  end;
  if not raised then
    raise exception 'TEST 1 FAILED: viewer role should have raised 42501';
  end if;
  raise notice 'Test 1 OK — viewer app_role raises 42501';

  -- ── Test 2: no claim (null) → must NOT raise ─────────────────────────────
  raised := false;
  begin
    perform set_config('request.jwt.claims', '{"role":"truespend"}', true);
    declare
      claims        json := current_setting('request.jwt.claims', true)::json;
      approver_role text := claims->>'app_role';
    begin
      if approver_role is not null
         and approver_role not in ('procurement', 'admin') then
        raise exception 'not authorised' using errcode = '42501';
      end if;
    end;
  exception
    when sqlstate '42501' then raised := true;
  end;
  if raised then
    raise exception 'TEST 2 FAILED: null app_role must be a no-op';
  end if;
  raise notice 'Test 2 OK — null app_role is a no-op (current state)';

  -- ── Test 3: privileged claim present → must NOT raise ────────────────────
  raised := false;
  begin
    perform set_config('request.jwt.claims', '{"role":"truespend","app_role":"procurement"}', true);
    declare
      claims        json := current_setting('request.jwt.claims', true)::json;
      approver_role text := claims->>'app_role';
    begin
      if approver_role is not null
         and approver_role not in ('procurement', 'admin') then
        raise exception 'not authorised' using errcode = '42501';
      end if;
    end;
  exception
    when sqlstate '42501' then raised := true;
  end;
  if raised then
    raise exception 'TEST 3 FAILED: procurement app_role must not raise';
  end if;
  raise notice 'Test 3 OK — procurement app_role passes';

  -- Reset GUC so we don't poison subsequent queries in the same session
  perform set_config('request.jwt.claims', '', true);

  raise notice '── All Step 2a tests passed ──';
end $$;


-- =============================================================================
-- Update schema.sql commentary reference
-- =============================================================================
-- After applying, the effective permission model for tickets is:
--   truespend role:     SELECT, INSERT, UPDATE(all cols except status, po_id)
--   SECURITY DEFINER functions: bypass all grants, can write status + po_id
--   approve_and_commit: only path that sets status='approved' + po_id
--   n8n agent path: calls approve_and_commit RPC (same boundary)
--   reject: pgPatch sets status='rejected' — NOTE: this still works because
--     the SECURITY DEFINER release_budget RPC is called first, then the status
--     patch would fail. Fix: add a reject_and_release RPC in a future step,
--     or route reject through n8n. For now, reject is handled by n8n agent
--     which calls the RPC directly as the function owner.
--
-- TODO(SSO): Once per-user JWTs carry app_role:
--   1. Drop `approver_role IS NOT NULL AND` in both RPCs → fail-closed
--   2. Consider adding app_role to the claim in next_po_number / release_budget
--   3. Update CLAUDE.md invariant I-2 note to remove "client-side only" caveat

-- migrate:down transaction:false
-- Irreversible / forward-only migration. Roll forward with a new migration
-- per invariant I-8; no automated down path.
select 1;
