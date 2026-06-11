-- migrate:up transaction:false
-- =============================================================================
-- grant_views_to_truespend_app.sql
-- Restore SELECT on 8 views that were never granted to the truespend_app login
-- role after the I-2 security hardening (truespend → truespend_app migration).
--
-- Symptom this fixes: the Ops Board screens (Orders/commitment_register,
-- Budget/budget_command_center, Suppliers/supplier_compliance_summary) returned
-- PostgREST 401 "permission denied for view ..." → empty UI ("0 orders", €0).
--
-- READ-ONLY: grants SELECT only. No write/insert/update — money writes stay on
-- the SECURITY DEFINER RPC path (I-1). Idempotent: GRANT is safe to re-run.
-- =============================================================================

begin;

grant select on public.commitment_register        to truespend_app;
grant select on public.budget_command_center       to truespend_app;
grant select on public.supplier_compliance_summary to truespend_app;
grant select on public.agent_performance            to truespend_app;
grant select on public.license_waste_report          to truespend_app;
grant select on public.llm_cost_by_key               to truespend_app;
grant select on public.po_cycle_time                 to truespend_app;
grant select on public.weekly_digest                 to truespend_app;

commit;

-- migrate:down transaction:false
-- Irreversible / forward-only migration. Roll forward with a new migration
-- per invariant I-8; no automated down path.
select 1;
