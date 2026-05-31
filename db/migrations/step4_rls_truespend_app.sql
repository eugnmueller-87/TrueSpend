-- TrueSpend — Step 4: Extend RLS policies to truespend_app + catalog_by_supplier view
-- Migration: 2026-05-31
--
-- ROOT CAUSE: All RLS `app_role_all` policies in schema.sql are `TO truespend` only.
-- truespend_app (the new NOSUPERUSER PostgREST login role from step2d) has SELECT
-- grants but hits RLS on every protected table → PostgREST returns 403.
-- JWT, PGRST_DB_URI, and PGRST_DB_ANON_ROLE are all correctly set to truespend_app.
-- The fix: add truespend_app policies (using(true), for all) to every RLS-enabled table,
-- and create the catalog_by_supplier view (used by CatalogScreen but missing from schema).
--
-- Run with: psql $DATABASE_URL -f db/migrations/step4_rls_truespend_app.sql
-- (run as truespend superuser — truespend_app lacks CREATE POLICY)

-- =============================================================================
-- 1. Add truespend_app RLS policies on all protected tables (idempotent)
-- =============================================================================
do $$
declare
  t text;
  tables text[] := array[
    'contracts', 'tickets', 'decisions', 'suppliers',
    'budget_positions', 'budget_buckets', 'budget_pools', 'budget_reallocations',
    'purchase_orders', 'invoices', 'assets',
    'license_entitlements', 'license_assignments',
    'llm_consumption', 'legal_documents', 'compliance_checks',
    'workflow_runs'
  ];
begin
  foreach t in array tables loop
    -- Drop existing policy if present (idempotent re-run)
    execute format('drop policy if exists "app_role_all_app" on %I', t);
    execute format(
      'create policy "app_role_all_app" on %I for all to truespend_app using (true) with check (true)',
      t
    );
    raise notice '1 OK — RLS policy app_role_all_app created on %', t;
  end loop;
end $$;


-- =============================================================================
-- 2. Create catalog_by_supplier view
-- =============================================================================
-- Used by CatalogScreen: /catalog_by_supplier?order=supplier_name.asc,sort_order.asc,name.asc
-- Returns catalog_items joined with supplier name/health/category for grouping.

-- NOTE: DROP first — CREATE OR REPLACE cannot change column order on an existing view.
drop view if exists catalog_by_supplier cascade;

create view catalog_by_supplier as
select
  ci.id,
  ci.name,
  ci.description,
  ci.unit_price,
  ci.currency,
  ci.price_per,
  ci.variable,
  ci.category,
  ci.sku,
  ci.contract_id,
  ci.active,
  coalesce(ci.sort_order, 999)  as sort_order,
  ci.created_at,

  -- Supplier fields for grouping
  s.id                          as supplier_id,
  s.name                        as supplier_name,
  s.category                    as supplier_category,
  s.health                      as supplier_health,
  s.compliance_status           as supplier_compliance,
  s.strategic_tier              as supplier_tier
from catalog_items ci
join suppliers s on s.id = ci.supplier_id
where ci.active = true;

do $$ begin raise notice '2 OK — catalog_by_supplier view created'; end $$;


-- =============================================================================
-- 3. Grant SELECT on catalog_by_supplier to truespend_app
-- =============================================================================
grant select on catalog_by_supplier to truespend_app;

do $$ begin raise notice '3 OK — SELECT on catalog_by_supplier granted to truespend_app'; end $$;


-- =============================================================================
-- 4. Verification — assert truespend_app can SELECT every app-read relation
-- =============================================================================
do $$
declare
  rel    text;
  has_it boolean;
  tables_and_views text[] := array[
    -- Tables
    'tickets', 'users', 'suppliers', 'contracts', 'cost_centers',
    'budget_positions', 'purchase_orders', 'invoices', 'assets',
    'decisions', 'compliance_checks', 'catalog_items',
    'branches', 'managers', 'license_entitlements', 'license_assignments',
    'llm_consumption', 'legal_documents', 'budget_buckets', 'budget_pools',
    'budget_reallocations', 'workflow_runs',
    -- Views
    'open_tickets_board', 'purchase_orders_board', 'catalog_by_supplier',
    'contracts_expiring', 'po_analytics', 'invoice_analytics',
    'spend_trend', 'savings_tracking', 'supplier_performance', 'approval_velocity'
  ];
begin
  foreach rel in array tables_and_views loop
    select exists(
      select 1 from information_schema.role_table_grants
      where grantee = 'truespend_app'
        and table_name = rel
        and privilege_type = 'SELECT'
    ) into has_it;
    if not has_it then
      raise exception 'FAIL: truespend_app cannot SELECT % — grant missing', rel;
    end if;
  end loop;
  raise notice '4 OK — truespend_app can SELECT all % app-read relations', array_length(tables_and_views, 1);
end $$;

-- Assert tickets.status still NOT directly updatable by truespend_app
do $$
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
  raise notice '5 OK — tickets.status still RPC-only (no direct UPDATE)';
end $$;

-- Assert approve_and_commit still executable
do $$
declare has_rpc boolean;
begin
  select exists(
    select 1 from information_schema.role_routine_grants
    where grantee = 'truespend_app'
      and routine_name = 'approve_and_commit'
      and privilege_type = 'EXECUTE'
  ) into has_rpc;
  if not has_rpc then
    raise exception 'FAIL: truespend_app cannot execute approve_and_commit';
  end if;
  raise notice '6 OK — approve_and_commit executable';
end $$;
