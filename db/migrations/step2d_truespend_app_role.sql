-- TrueSpend — Step 2d: Create truespend_app as the PostgREST login role
-- Migration: 2026-05-31
--
-- WHY: PostgREST currently connects as truespend (SUPERUSER), which bypasses
-- all GRANT/REVOKE/column-level restrictions. The fix is to create a
-- non-superuser login role (truespend_app), grant it exactly the privileges
-- it needs, and point PGRST_DB_URI at it. truespend_app is both the login
-- role and the role the JWT 'role' claim resolves to — no SET ROLE chain,
-- no superuser in the session, hard boundary.
--
-- After this migration:
--   PGRST_DB_URI  → postgres://truespend_app:<REDACTED_ROTATE_ME>@...
--   PGRST_DB_ANON_ROLE → truespend_app (or keep web_anon for unauthenticated)
--   JWT role claim → "role":"truespend_app"
--   truespend (superuser) is kept for migrations/admin only — no app traffic
--
-- Run with: psql $DATABASE_URL -f db/migrations/step2d_truespend_app_role.sql
-- (truespend is still superuser, so it can run this)

-- =============================================================================
-- 1. Create the login role
-- =============================================================================
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'truespend_app') then
    create role truespend_app with
      nosuperuser
      nocreatedb
      nocreaterole
      noinherit
      login
      nobypassrls
      <REDACTED_ROTATE_ME> '<REDACTED_ROTATE_ME>';
    raise notice 'Created role truespend_app';
  else
    raise notice 'Role truespend_app already exists — skipping CREATE';
  end if;
end $$;

-- Verify: must not be superuser
do $$
declare r record;
begin
  select rolsuper, rolbypassrls, rolcanlogin into r
  from pg_roles where rolname = 'truespend_app';
  if r.rolsuper     then raise exception 'FAIL: truespend_app is superuser'; end if;
  if r.rolbypassrls then raise exception 'FAIL: truespend_app bypasses RLS'; end if;
  if not r.rolcanlogin then raise exception 'FAIL: truespend_app cannot login'; end if;
  raise notice '1 OK — truespend_app is nosuperuser, norls, can login';
end $$;


-- =============================================================================
-- 2. Schema access
-- =============================================================================
grant usage on schema public to truespend_app;
grant usage, select on all sequences in schema public to truespend_app;


-- =============================================================================
-- 3. Table privileges — read-only tables
-- =============================================================================
grant select on
  branches,
  budget_buckets,
  budget_pools,
  catalog_items,
  contract_clauses,
  cost_centers,
  decisions,
  document_embeddings,
  legal_documents,
  license_assignments,
  license_entitlements,
  llm_api_keys,
  managers,
  po_sequences,
  rag_policies,
  rag_search_log,
  trust_settings,
  users,
  vendor_pricing_benchmarks
to truespend_app;


-- =============================================================================
-- 4. Table privileges — full CRUD
-- =============================================================================
grant select, insert, update, delete on
  asset_depreciation_log,
  assets,
  budget_positions,
  budget_reallocations,
  compliance_checks,
  contract_changes,
  contracts,
  erp_sync_queue,
  hyperscaler_positions,
  invoices,
  llm_consumption,
  payment_instructions,
  purchase_orders,
  supplier_emails,
  suppliers,
  trace_log,
  workflow_runs
to truespend_app;


-- =============================================================================
-- 5. tickets — SELECT + INSERT + column-restricted UPDATE
--    Explicitly withheld: UPDATE(status), UPDATE(po_id)
--    All status transitions MUST go through SECURITY DEFINER RPCs.
-- =============================================================================
grant select, insert on tickets to truespend_app;

grant update (
  title, description, category, branch_id, cost_center_id,
  supplier_id, contract_id, requested_by, owner_id,
  amount, amount_eur, value_eur, currency,
  jira_key, jira_url, target_close, closed_at, updated_at,
  submitted_by, submitted_by_email, supplier_name,
  recommendation, brief, confidence, review_notes, review_type,
  pdf_url, supplier_compliance, ticket_type, disposition,
  po_number
) on tickets to truespend_app;
-- status and po_id are NOT in this list — withheld intentionally.


-- =============================================================================
-- 6. Views (PostgREST exposes these as read endpoints)
-- =============================================================================
grant select on
  open_tickets_board,
  contracts_expiring,
  po_analytics,
  invoice_analytics,
  spend_trend,
  savings_tracking,
  supplier_performance,
  approval_velocity
to truespend_app;


-- =============================================================================
-- 7. RPC execute grants — all money functions + helpers
-- =============================================================================
grant execute on function
  approve_and_commit(uuid, uuid, text, uuid, spend_category, text, uuid, uuid, text, numeric, text, numeric, uuid, date, jsonb)
to truespend_app;

grant execute on function
  reject_ticket(uuid, uuid, uuid, spend_category, text, numeric)
to truespend_app;

grant execute on function
  close_ticket(uuid)
to truespend_app;

grant execute on function
  commit_budget(uuid, uuid, spend_category, text, numeric)
to truespend_app;

grant execute on function
  release_budget(uuid, uuid, spend_category, text, numeric)
to truespend_app;

grant execute on function
  record_spend(uuid, uuid, spend_category, text, numeric, numeric)
to truespend_app;

grant execute on function
  next_po_number(uuid, text)
to truespend_app;

grant execute on function
  confirm_delivery(uuid, text)
to truespend_app;

grant execute on function
  match_invoice(uuid)
to truespend_app;

grant execute on function
  create_payment_instruction(uuid, date)
to truespend_app;


-- =============================================================================
-- 8. Boundary verification
-- =============================================================================
do $$
declare
  has_super          boolean;
  has_login          boolean;
  has_status_update  boolean;
  has_table_update   boolean;
  has_rpc_approve    boolean;
  has_tickets_select boolean;
begin
  select rolsuper, rolcanlogin
  into has_super, has_login
  from pg_roles where rolname = 'truespend_app';

  -- Must NOT be superuser (the whole point)
  if has_super then
    raise exception 'BOUNDARY BROKEN: truespend_app is superuser — all grants bypassed';
  end if;
  if not has_login then
    raise exception 'FAIL: truespend_app cannot log in';
  end if;

  -- Must NOT have table-level UPDATE on tickets
  select exists(
    select 1 from information_schema.role_table_grants
    where grantee = 'truespend_app' and table_name = 'tickets'
      and privilege_type = 'UPDATE'
  ) into has_table_update;
  if has_table_update then
    raise exception 'BOUNDARY BROKEN: truespend_app has table-level UPDATE on tickets';
  end if;

  -- Must NOT have column-level UPDATE on status
  select exists(
    select 1 from information_schema.column_privileges
    where grantee = 'truespend_app' and table_name = 'tickets'
      and column_name = 'status' and privilege_type = 'UPDATE'
  ) into has_status_update;
  if has_status_update then
    raise exception 'BOUNDARY BROKEN: truespend_app has UPDATE(status) on tickets';
  end if;

  -- Must have SELECT on tickets
  select exists(
    select 1 from information_schema.role_table_grants
    where grantee = 'truespend_app' and table_name = 'tickets'
      and privilege_type = 'SELECT'
  ) into has_tickets_select;
  if not has_tickets_select then
    raise exception 'FAIL: truespend_app lost SELECT on tickets';
  end if;

  -- Must have EXECUTE on approve_and_commit
  select exists(
    select 1 from information_schema.role_routine_grants
    where grantee = 'truespend_app'
      and routine_name = 'approve_and_commit'
      and privilege_type = 'EXECUTE'
  ) into has_rpc_approve;
  if not has_rpc_approve then
    raise exception 'FAIL: truespend_app cannot execute approve_and_commit';
  end if;

  raise notice '8 OK — truespend_app: nosuperuser, no UPDATE(status), SELECT OK, approve_and_commit OK';
end $$;


-- =============================================================================
-- NEXT STEPS (manual — cannot be done from SQL)
-- =============================================================================
-- After running this migration:
--
-- 1. Update Railway PostgREST env vars:
--    PGRST_DB_URI  = postgres://truespend_app:<REDACTED_ROTATE_ME>@postgres.railway.internal:5432/truespend
--    PGRST_DB_ANON_ROLE = truespend_app
--
-- 2. Update app JWT (in Railway intake service + .env):
--    Generate a new JWT with "role":"truespend_app" signed with PGRST_JWT_SECRET.
--    Update POSTGREST_JWT and VITE_POSTGREST_JWT env vars on the intake service.
--    Update the fallback in intake/src/App.jsx line 5.
--
-- 3. Redeploy PostgREST on Railway.
--
-- 4. Verify: PATCH /tickets {status:...} → 403. PATCH {description:...} → 200.
--    POST /rpc/approve_and_commit → works.
