-- TrueSpend — Step 2c: Demote truespend from superuser
-- Migration: 2026-05-31
--
-- WHY: truespend is currently SUPERUSER (rolsuper=t, rolbypassrls=t).
-- Superusers bypass ALL privilege checks — GRANT/REVOKE/RLS/column grants
-- are all no-ops for them. Steps 2a and 2b are architecturally correct but
-- physically inert until this is applied.
--
-- WHAT:
--   1. ALTER ROLE truespend NOSUPERUSER NOBYPASSRLS
--   2. GRANT explicit table-level privileges for all 37 app tables
--   3. GRANT USAGE on schema public + sequences
--   4. Column-level UPDATE restrictions on tickets (status, po_id) become
--      enforceable the moment superuser is revoked
--
-- SAFETY: SECURITY DEFINER RPCs run as their creator (postgres/superuser),
-- not as truespend. They are unaffected by this change.
--
-- Run with: psql $DATABASE_URL -f db/migrations/step2c_demote_truespend.sql
-- MUST be run as postgres (superuser), not as truespend.
-- Run AFTER step2_rpc_boundary.sql.

-- =============================================================================
-- Pre-flight: confirm we're running as a superuser, not truespend
-- =============================================================================
do $$
begin
  if current_user = 'truespend' then
    raise exception 'Run this migration as postgres (superuser), not as truespend';
  end if;
  raise notice 'Pre-flight OK — running as %', current_user;
end $$;

-- =============================================================================
-- 1. Demote truespend
-- =============================================================================
alter role truespend nosuperuser nobypassrls;

-- Verify
do $$
declare r record;
begin
  select rolsuper, rolbypassrls into r from pg_roles where rolname = 'truespend';
  if r.rolsuper then
    raise exception 'Demotion FAILED: truespend is still superuser';
  end if;
  if r.rolbypassrls then
    raise exception 'Demotion FAILED: truespend still bypasses RLS';
  end if;
  raise notice '1 OK — truespend is now a regular role (nosuperuser, norls)';
end $$;

-- =============================================================================
-- 2. Grant explicit table privileges
-- =============================================================================
-- Schema access
grant usage on schema public to truespend;

-- Read-only tables (SELECT only — writes go through RPCs or n8n)
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
to truespend;

-- Full CRUD tables (app reads and writes these directly)
grant select, insert, update, delete on
  asset_depreciation_log,
  assets,
  budget_positions,
  budget_reallocations,
  catalog_items,
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
to truespend;

-- tickets: SELECT + INSERT, and column-restricted UPDATE (NOT status, NOT po_id)
-- This is the key table — the column grants from step2_rpc_boundary.sql apply here.
grant select, insert on tickets to truespend;
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

-- Sequences (needed for INSERT on tables with serial/uuid_generate_v4 defaults)
grant usage, select on all sequences in schema public to truespend;

-- Views (PostgREST exposes these as read endpoints)
grant select on
  open_tickets_board,
  contracts_expiring,
  po_analytics,
  invoice_analytics,
  spend_trend,
  savings_tracking,
  supplier_performance,
  approval_velocity
to truespend;
-- Additional views that may exist
grant select on all tables in schema public to truespend;
-- Note: the above is broad but truespend is no longer superuser, so
-- write restrictions still apply. The view grant doesn't grant writes.

-- =============================================================================
-- 3. Verify the boundary is now real
-- =============================================================================
do $$
declare
  has_table_update  boolean;
  has_status_update boolean;
  has_select        boolean;
  is_super          boolean;
begin
  select rolsuper into is_super from pg_roles where rolname = 'truespend';
  if is_super then
    raise exception 'VERIFY FAILED: truespend is still superuser — grants are still bypassed';
  end if;

  select exists(
    select 1 from information_schema.role_table_grants
    where grantee = 'truespend' and table_name = 'tickets'
      and privilege_type = 'UPDATE'
  ) into has_table_update;

  select exists(
    select 1 from information_schema.column_privileges
    where grantee = 'truespend' and table_name = 'tickets'
      and column_name = 'status' and privilege_type = 'UPDATE'
  ) into has_status_update;

  select exists(
    select 1 from information_schema.role_table_grants
    where grantee = 'truespend' and table_name = 'tickets'
      and privilege_type = 'SELECT'
  ) into has_select;

  if has_table_update then
    raise exception 'VERIFY FAILED: truespend has table-level UPDATE on tickets';
  end if;
  if has_status_update then
    raise exception 'VERIFY FAILED: truespend has UPDATE(status) on tickets';
  end if;
  if not has_select then
    raise exception 'VERIFY FAILED: truespend lost SELECT on tickets';
  end if;

  raise notice '3 OK — boundary is live: no UPDATE(status), SELECT intact, nosuperuser';
end $$;

-- =============================================================================
-- NOTE: After running this migration, redeploy PostgREST so it reloads
-- its schema cache as the now-unprivileged truespend role.
-- The PATCH /tickets {status:...} endpoint will then return 403.
-- =============================================================================
