-- migrate:up transaction:false
-- =============================================================================
-- 000016_dispatch_queue_revoke_direct_dml.sql   ── Phase 4 ──
--
-- Close the forgeable-outbox hole. step6 (000008) granted SELECT, INSERT, UPDATE
-- on dispatch_queue to BOTH truespend_app and truespend with RLS USING(true).
-- Combined with the browser-held truespend_app token (Phase 2), anyone with
-- DevTools could:
--   - INSERT a fake 'approved'/'rejected' dispatch row -> the drainer fans it out
--     (forged supplier email / ERP entry / Slack), or
--   - UPDATE a real 'pending' row to 'sent' -> suppress a genuine notification.
--
-- The outbox is only ever LEGITIMATELY written by SECURITY DEFINER functions,
-- which run as the function owner and BYPASS table grants entirely:
--   write:  enqueue_dispatch            (000008, appended inside approve/reject)
--   drain:  claim_dispatch_batch / mark_dispatch_sent / mark_dispatch_failed (000009)
-- Verified no app/workflow does direct INSERT/UPDATE:
--   - intake/src/App.jsx:1279-1281 — SELECT only (dead_letter / stale-pending banner)
--   - workflows/automatic/dispatch_drain.json — calls the 3 RPCs only
--   - scripts/drain_dispatch.js — calls the 3 functions only (and connects as a
--     privileged role anyway)
--   - scripts/reconcile.js — SELECT only
--
-- FIX: revoke INSERT/UPDATE/DELETE from both app roles; KEEP SELECT (the Ops
-- Board banner reads pending/dead_letter rows directly). The definer functions
-- are unaffected. Reversible: re-grant if a future direct-write need appears
-- (it should not — route writes through a definer fn instead).
--
-- Idempotent: REVOKE is safe to re-run.
-- =============================================================================

revoke insert, update, delete on dispatch_queue from truespend_app;
revoke insert, update, delete on dispatch_queue from truespend;

-- Keep SELECT explicit (re-grant is idempotent; documents intent).
grant select on dispatch_queue to truespend_app;
grant select on dispatch_queue to truespend;

-- The RLS policies (dispatch_queue_app_all / _role_all, USING(true) WITH CHECK(true))
-- from 000008 remain, but with no INSERT/UPDATE privilege the WITH CHECK(true) is
-- moot for the app roles — RLS only filters privileges the role actually holds.
-- (Tightening the policy to FOR SELECT is possible but unnecessary once the
-- table-level write grant is gone; left as-is to minimize blast radius.)

-- ── Self-test: assert the app roles can no longer write the outbox ───────────
do $$
declare can_insert boolean; can_update boolean; can_select boolean;
begin
  select has_table_privilege('truespend_app', 'dispatch_queue', 'INSERT') into can_insert;
  select has_table_privilege('truespend_app', 'dispatch_queue', 'UPDATE') into can_update;
  select has_table_privilege('truespend_app', 'dispatch_queue', 'SELECT') into can_select;
  if can_insert then raise exception 'FAIL: truespend_app still has INSERT on dispatch_queue'; end if;
  if can_update then raise exception 'FAIL: truespend_app still has UPDATE on dispatch_queue'; end if;
  if not can_select then raise exception 'FAIL: truespend_app lost SELECT on dispatch_queue (board banner needs it)'; end if;
  raise notice 'OK — truespend_app: no INSERT/UPDATE on dispatch_queue, SELECT intact';
end $$;

-- migrate:down transaction:false
-- Reversible: restore the (insecure) direct write grants.
grant insert, update on dispatch_queue to truespend_app;
grant insert, update on dispatch_queue to truespend;
