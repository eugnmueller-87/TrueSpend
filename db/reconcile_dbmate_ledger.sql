-- =============================================================================
-- reconcile_dbmate_ledger.sql   ── GATED: run ONCE against prod, by the user ──
--
-- Phase 3 cutover from the bespoke runner (db-migrate.sh / apply_one.js, which
-- key schema_migrations by BARE FILENAME) to dbmate (which keys by VERSION).
--
-- WITHOUT this, dbmate sees an empty ledger by ITS definition and re-runs all 15
-- migrations against a DB that already has them — destructive (ADR-006: re-running
-- 000015/000002 self-tests is designed to fail). This back-fills dbmate's ledger
-- with exactly the versions whose OLD filename is already recorded as applied, so
-- dbmate treats them as done and runs only genuinely-pending ones (e.g. 000014/
-- 000015 if they were never applied).
--
-- SAFE BY CONSTRUCTION: a version is back-filled ONLY IF its legacy bare-filename
-- row exists. Migrations written-but-not-yet-applied (step11/step12 were authored
-- this session and are GATED) will NOT be back-filled, so dbmate will apply them
-- live — which is the correct behavior.
--
-- PRE-FLIGHT (read-only, run first and eyeball):
--   select name, applied_at from schema_migrations order by applied_at;
-- Confirm which old stepN files are actually recorded. Then run this script.
-- =============================================================================

begin;

-- 1. Preserve the legacy ledger (names + checksums) for audit. Idempotent-ish:
--    only rename if the legacy table doesn't already exist.
do $$
begin
  if exists (select 1 from information_schema.tables
             where table_name = 'schema_migrations'
               and table_schema = 'public')
     and not exists (select 1 from information_schema.tables
             where table_name = 'schema_migrations_legacy'
               and table_schema = 'public')
     and exists (select 1 from information_schema.columns
             where table_name = 'schema_migrations' and column_name = 'checksum') then
    -- only rename the BESPOKE table (it has a checksum column); a dbmate table
    -- (version-only) is left alone.
    execute 'alter table schema_migrations rename to schema_migrations_legacy';
    raise notice 'Renamed bespoke schema_migrations -> schema_migrations_legacy';
  else
    raise notice 'No bespoke schema_migrations to rename (already migrated or absent)';
  end if;
end $$;

-- 2. Create dbmate's ledger (version-keyed) if absent.
create table if not exists schema_migrations (
  version varchar(255) primary key
);

-- 3. Back-fill: map each old bare filename -> dbmate version, but ONLY for files
--    actually present in the legacy ledger. Uses a lookup table so the mapping is
--    auditable and a missing legacy row simply skips that version.
do $$
declare
  m record;
  legacy_present boolean;
begin
  for m in
    select * from (values
      ('cost_centers_seed.sql',              '000001'),
      ('step2_rpc_boundary.sql',             '000002'),
      ('step2c_demote_truespend.sql',        '000003'),
      ('step2d_truespend_app_role.sql',      '000004'),
      ('step3_invoice_rpc_grants.sql',       '000005'),
      ('step4_rls_truespend_app.sql',        '000006'),
      ('step5_action_ledger.sql',            '000007'),
      ('step6_dispatch_queue.sql',           '000008'),
      ('step7_dispatch_drain_rpc.sql',       '000009'),
      ('step8_delivery_dispatch.sql',        '000010'),
      ('grant_views_to_truespend_app.sql',   '000011'),
      ('step9_intake_status_rpcs.sql',       '000012'),
      ('step10_status_rpcs_carry_fields.sql','000013'),
      ('step11_supplier_email_threading.sql','000014'),
      ('step12_money_rpcs_fail_closed.sql',  '000015')
    ) as t(old_name, version)
  loop
    -- is the old name recorded as applied in the legacy ledger?
    execute format(
      'select exists(select 1 from schema_migrations_legacy where name = %L)', m.old_name
    ) into legacy_present;

    if legacy_present then
      insert into schema_migrations (version) values (m.version)
      on conflict (version) do nothing;
      raise notice 'back-filled % (was %)', m.version, m.old_name;
    else
      raise notice 'SKIP % (% not in legacy ledger — dbmate will apply it live)', m.version, m.old_name;
    end if;
  end loop;
end $$;

-- 4. Report the resulting state for the operator to verify.
\echo '--- dbmate ledger after back-fill (applied) ---'
-- (psql meta-command; harmless if run via a driver that ignores it)

commit;

-- AFTER this script:
--   dbmate status        # should show back-filled versions as applied, the rest pending
--   dbmate up            # applies ONLY genuinely-pending migrations
--   NOTIFY pgrst, 'reload schema';   # if any new RPCs were applied
