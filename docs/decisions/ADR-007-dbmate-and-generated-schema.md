# ADR-007: dbmate is the migration runner; schema.sql is a generated snapshot

Date: 2026-06-10
Status: Proposed (local repo changes done; the prod ledger reconciliation + first
schema.sql regeneration are GATED on the user)

## Context

`db/schema.sql` was billed as the "single source of truth" but had drifted ~6
months and ~50 objects behind reality: `dispatch_queue` and `action_ledger`
(whole tables), the `truespend_app` login role, 13 RPCs, 6 RLS policies, 5
indexes, 6 CHECK constraints, and the entire column-level `tickets` grant model
were all defined only in `db/migrations/stepN_*.sql`, never in `schema.sql`. A
fresh `psql -f db/schema.sql` builds a database missing exactly the I-1/I-2
hardening.

The migration tooling had also fragmented:
- `scripts/db-migrate.sh` carried a hand-maintained `MIGRATION_ORDER` array that
  **stopped at step8** — step9–12 and `grant_views` were invisible to it.
- Those later migrations were applied out-of-band via `db/migrations/apply_one.js`,
  which records into the *same* `schema_migrations` table but keyed by **bare
  filename**.
- `db/migrations/` mixed 15 real migrations with 19 forensic `.js` scripts,
  several seeds, and 4 RAG SQL variants (only one ever applied).

## Decision

1. **dbmate is the canonical runner.** SQL-first, `schema_migrations`-backed,
   immutable version-ordered files — which *is* invariant I-8 ("never edit an
   applied migration; add a new one") enforced by convention. Rejected
   graphile-migrate: its mutable `current.sql` model contradicts I-8 and offers
   no clean way to adopt 15 already-applied out-of-band files.

2. **Renumber to true apply order.** The 15 tracked migrations become
   `000001_…` … `000015_…` ordered by **git landing order** (from
   `git log --diff-filter=A`), NOT the old `stepN` labels. Notably
   `grant_views` (commit 6e73980) landed before step9/10 (070b7b3), so it is
   `000011`, before `000012_intake_status_rpcs`. The `2c`/`2d` suffixes collapse
   into linear `000003`/`000004`. Each file gets `-- migrate:up transaction:false`
   (the bodies manage their own `begin/commit` or are idempotent DDL) and an
   explicit forward-only `-- migrate:down` note (money/grant changes are not
   auto-reversible; roll forward per I-8).

3. **schema.sql is demoted to a GENERATED snapshot.** The migration chain is
   canonical. `db/schema.sql` becomes the output of `dbmate dump`
   (`pg_dump --schema-only`) with a `GENERATED — do not hand-edit` header.
   `db/dbmate.yml` sets `no-dump-schema: true` so CI does not require pg_dump on
   every run; the snapshot is regenerated explicitly.

4. **db/migrations/ contains only ordered migrations.** Forensics → `scripts/debug/`,
   n8n tooling → `scripts/n8n/`, seeds → `db/seed/` (numbered 17–19 after the
   existing 01–16), unapplied pgvector RAG + the two ambiguous RAG variants →
   `db/migrations/_future/` (unnumbered, pending prod verification of which ran).

## The cutover (one-time) — GATED

dbmate keys the ledger by `version` (`000012`); the legacy rows are keyed by
bare filename (`step9_…sql`). If dbmate runs against the legacy ledger it sees an
empty ledger *by its own definition* and **re-runs all 15 migrations** against a
DB that already has them — destructive (ADR-006: re-running `000015`/`000002`
self-tests is designed to fail).

`db/reconcile_dbmate_ledger.sql` (run ONCE against prod, by the user) handles
this safely:
1. renames the bespoke `schema_migrations` → `schema_migrations_legacy` (preserves
   names + checksums for audit);
2. creates dbmate's `schema_migrations(version)`;
3. back-fills a version **only if** its old bare filename is present in the legacy
   ledger — so genuinely-unapplied migrations (e.g. `000014`/`000015`, authored
   but gated this session) are *not* back-filled and dbmate applies them live.

Pre-flight (read-only): `select name, applied_at from schema_migrations order by applied_at;`
to confirm which old files are recorded, then run the reconcile script, then
`dbmate status` → `dbmate up`.

## Consequences

- **I-8 mechanism change** — the "how" of I-8 moves from `db-migrate.sh` to dbmate.
  `db-migrate.sh` is kept as a thin dbmate wrapper so CI and the documented CLI
  (`--status`, `--dry-run`, no-arg apply) are unchanged. `.github/workflows/
  db-migrate.yml` now installs dbmate.
- **apply_one.js is retired** → moved to `scripts/debug/` (was the Windows-local
  out-of-band runner; dbmate replaces it).
- **Checksum guard is lost** — dbmate does not hash bodies; the immutable-file
  convention replaces it. The legacy checksums survive in `schema_migrations_legacy`.
- **RAG migrations are unresolved** — `rag_*` SQL is parked in `_future/` because
  their applied state predates formal tracking and cannot be confirmed without a
  prod read. They are NOT numbered into the chain until verified.
- **`tickets` denormalized columns** — ~11 columns granted by migrations but
  absent from the old schema.sql (`value_eur`, `submitted_by`, `recommendation`,
  `brief`, `confidence`, `po_number`, `disposition`, …) will be revealed as real
  or stale by the first `dbmate dump`. That dump is the arbiter, not hand-editing.

## What is local vs gated

- **Done locally (this change):** dbmate config, renumbered migrations + markers,
  forensics/seed/RAG reorg, db-migrate.sh wrapper, CI update, the reconcile script,
  this ADR, CLAUDE.md updates.
- **GATED (user runs against prod with DATABASE_URL):** the reconcile script, the
  first `dbmate dump` to regenerate `db/schema.sql`, verifying which RAG file and
  which `tickets` columns are live.
