# TrueSpend — Claude Code Intelligence

Agentic procurement OS: n8n orchestrates Claude Sonnet 4.6 + PostgreSQL. One Operations Board is the only human interface.

> Read `SECURITY.md` before touching credentials or workflows.
> Run `bash scripts/quality-gate.sh` before every push.

## Architecture

| Layer | Tech | URL / Location |
|---|---|---|
| Orchestration | n8n self-hosted (VPS 187.127.87.206) | https://n8n-n3xl.eugenmueller.tech |
| Database | PostgreSQL on Railway (db=truespend) | zephyr.proxy.rlwy.net:24934 |
| REST API | PostgREST on Railway | https://postgrest-production-7960.up.railway.app |
| AI reasoning | Claude Sonnet 4.6 via Anthropic API | — |
| Intake UI + Ops Board | React + Vite + nginx → Railway | https://intake-production-84a0.up.railway.app |
| Observability | Grafana on Railway | https://grafana-production-49fc.up.railway.app |
| e-Signature | DocuSign JWT Grant (sandbox) | account-d.docusign.com |
| Email | IMAP + SMTP via GMX | truespend.ops@gmx.de |
| Escalations | Jira PROC project (≥€100k only) | — |

## Key Files

| File | Purpose |
|---|---|
| `db/schema.sql` | ⚠️ STALE hand-written schema — NOT source of truth (ADR-007). Canonical = the migration chain; this becomes a generated `dbmate dump` snapshot. |
| `db/migrations/NNNNNN_*.sql` | Ordered dbmate migrations (the canonical schema). Run via `scripts/db-migrate.sh`. |
| `db/seed/[0-9]*.sql` | Load in order. Applied to Railway DB. |
| `intake/src/App.jsx` | Full Ops Board: roles, board, submit, catalog, budget, suppliers, search |
| `workflows/stakeholder/intake_receiver.json` | Main intake path — webhook → Claude → dispose |
| `workflows/stakeholder/chat_assistant.json` | Ask assistant — `/webhook/chat` → scope gate → pre-fetch bundle → Claude (read-only, I-9) |
| `workflows/stakeholder/docusign_sign.json` | Sign button → DocuSign JWT → embedded URL |
| `workflows/stakeholder/board_action.json` | Phase 2 — `/webhook/board-action`: server-side money/budget/user writes off the browser token (privileged JWT) |
| `intake/src/api/client.js` | Phase 2 — single API-client chokepoint (pgFetch/pgPost/pgPatch/pgRpc + webhook helpers + `routeMoneyThroughN8n` seam) |
| `workflows/automatic/contract_watcher.json` | Daily 07:00 — expiring contracts |
| `workflows/automatic/reorder_trigger.json` | Daily — reorder candidates |
| `workflows/automatic/hyperscaler_monitor.json` | Daily 06:00 — cloud spend anomaly |
| `workflows/automatic/invoice_processor.json` | IMAP invoices → 3-way match → ERP queue |
| `workflows/automatic/supplier_onboarding.json` | Webhook → 4 parallel compliance agents |
| `workflows/automatic/delivery_confirmation.json` | Webhook — confirm_delivery RPC |
| `workflows/automatic/asset_depreciation.json` | Monthly 1st 06:00 — depreciation + alerts |
| `workflows/automatic/llm_consumption.json` | Daily 06:30 — AI spend tracking |
| `workflows/automatic/rag_embedder.json` | Every 6h — OpenAI embeddings → document_embeddings |
| `workflows/communication/supplier_reply_handler.json` | IMAP → Claude → reply or route |
| `infra/docker-compose.yml` | Local n8n + Grafana |
| `Dockerfile` | Root Dockerfile — builds intake SPA for Railway |
| `railway.json` | Railway build config — DOCKERFILE builder |
| `scripts/quality-gate.sh` | Pre-push checks — run this |
| `.env.example` | All required env vars |

## INVARIANTS

**I-1 — Money writes only through SECURITY DEFINER RPCs.**
Status→approved, PO creation, budget commit go ONLY through `approve_and_commit`, `commit_budget`, `release_budget`, `record_spend`, `create_payment_instruction`. NEVER a raw PATCH/UPDATE from client. Prevents forged approvals.
See: `db/schema.sql:1613–1994`, `docs/auth-and-rls.md`

**I-2 — Auth comes from the JWT `app_role` claim, enforced by Postgres RLS.**
NEVER trust a client-side role/user object for access. The `truespend` role in the JWT is what PostgREST checks. Prevents the localStorage-role hole.
See: `db/schema.sql:1529–1600`, `docs/auth-and-rls.md`

**I-3 — ONE category taxonomy (`NR_CATEGORIES` in App.jsx + `spend_category` enum in schema). ONE status enum.**
Never fork a second list per form. Never add a parallel status system.
See: `intake/src/App.jsx:1219–1227`, `db/schema.sql:41–50`, `docs/conventions.md`

**I-4 — Two surfaces stay separate: requester intake vs procurement ops console.**
Do not merge them back into one screen.
See: `intake/src/App.jsx:1016–1207` (board), `intake/src/App.jsx:1209–1600+` (new request)

**I-5 — Routing logic has ONE source of truth.**
The Pre-Check Gate + Claude prompt in `intake_receiver.json` is the canonical routing logic. The `buildApprovalPath()` in `App.jsx:1241` is a UI preview only — it does NOT override agent decisions.
See: `docs/routing-engine.md`

**I-6 — No secrets in code — env only.**
The pre-commit hook (`scripts/quality-gate.sh`) blocks hardcoded JWTs and private keys at commit time. Never use `--no-verify`.
See: `scripts/quality-gate.sh:30–73`

**I-7 — Definition of done = quality-gate.sh green + touched invariant's doc still true.**
If a change alters an invariant, write an ADR in `docs/decisions/` first.
See: `docs/decisions/`

**I-8 — A db/migrations change is only "done" once applied to prod and recorded in schema_migrations.**
Migrations are ordered `db/migrations/NNNNNN_slug.sql` files run by **dbmate** (ADR-007), tracked by
`version` in `schema_migrations`. Writing a SQL file and pushing it is NOT done — it must be applied via
`scripts/db-migrate.sh` (= `dbmate up`) against `$DATABASE_URL` and appear in `schema_migrations`. CI
(`.github/workflows/db-migrate.yml`) does this on push when migration files change. For manual apply:
```bash
DATABASE_URL=postgresql://truespend:...@zephyr.proxy.rlwy.net:24934/truespend \
  bash scripts/db-migrate.sh
```
Never re-edit an applied migration to "fix" something — add a new migration instead (dbmate treats files
as immutable). `db/schema.sql` is NO LONGER the source of truth — it is a generated `dbmate dump` snapshot;
the migration chain is canonical. First-time cutover: run `db/reconcile_dbmate_ledger.sql` once (gated).
See: `scripts/db-migrate.sh`, `db/dbmate.yml`, `docs/decisions/ADR-007-dbmate-and-generated-schema.md`

**I-9 — The Ask assistant answers ONLY from TrueSpend data — never external knowledge.**
The `chat_assistant.json` workflow pre-fetches scoped DB rows and Claude answers from that
bundle only; if the data lacks the answer it says "I don't have that in TrueSpend." It is
read-only (no RPC, no PATCH). v1 access is fail-closed to procurement/admin/controlling only;
scope follows the role→capability→scope matrix in ADR-005 (the spec for post-SSO RLS). The UI
bubble gate and the n8n Scope Gate must stay in sync.
See: `workflows/stakeholder/chat_assistant.json`, `intake/src/App.jsx` (AskAssistant),
`docs/decisions/ADR-005-ask-assistant.md`, `docs/ask-assistant.md`

## Commands

```bash
# Quality gate (run before every push)
bash scripts/quality-gate.sh

# Apply pending DB migrations to prod (dbmate; requires DATABASE_URL + dbmate installed)
bash scripts/db-migrate.sh           # = dbmate up
bash scripts/db-migrate.sh --status  # = dbmate status (applied vs pending)
bash scripts/db-migrate.sh --dry-run # = dbmate status (plan only)

# Migrations live in db/migrations/ as ordered NNNNNN_slug.sql (dbmate, ADR-007).
# FIRST-TIME cutover from the old runner: run db/reconcile_dbmate_ledger.sql ONCE
# against prod BEFORE the first `dbmate up` (or dbmate re-runs everything).

# Regenerate the schema snapshot from prod (GENERATED artifact, replaces the
# stale hand-written db/schema.sql). Gated — needs prod creds + pg_dump:
dbmate dump   # writes db/schema.sql with a GENERATED header

# Local dev
cd intake && npm run dev

# Build intake (Vite)
cd intake && npm run build

# Apply seeds (db/seed/ — numbered, data not schema)
for f in db/seed/[0-9]*.sql; do psql $DATABASE_URL -f $f; done

# Local infra (n8n + Grafana)
cd infra && docker compose up -d
```

## Read Before Touching

- Auth / RLS changes → read `docs/auth-and-rls.md` first
- Routing / disposition logic → read `docs/routing-engine.md` first
- Schema changes → read `docs/data-model.md` first
- New roles or UI surfaces → read `docs/decisions/ADR-001-six-role-system.md` first
- DocuSign changes → read `docs/decisions/ADR-004-docusign-integration.md` first

## Known Violations / Open Issues

- **Hygiene: hardcoded prod URLs + placeholder sender — FIXED (2026-06-10, Phase 5)**: 3 live workflows sent from the placeholder `procurement@company.com` (SPF/DMARC fail) and 2 from a hardcoded `truespend.ops@gmx.de`; ~94 bare `postgrest-production-7960…` URL literals across 11 live workflows had no env indirection. Fix: all `fromEmail` now `={{ $env.PROCUREMENT_FROM_EMAIL }}` (fail-loud, no fallback); all prod URLs now `={{ $env.POSTGREST_URL || '...' }}` (the already-blessed fallback pattern, per the policy decision — keeps a working default but is env-overridable). Test fixtures (`workflows/__tests__/fixtures/_pre_fix_*`) intentionally retain the old literals (frozen regression baseline). Guarded by a new `quality-gate.sh` check (no placeholder sender, all prod URLs env-guarded). **n8n box `.env` must contain `POSTGREST_URL` and `PROCUREMENT_FROM_EMAIL`** (alongside the existing `POSTGREST_JWT`/`ANTHROPIC_API_KEY`) or the `$env` expressions resolve empty — `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` is already set on the box so `$env` in expressions works.
- **Outbox forgeable by the app token — FIX LANDED, MIGRATION PENDING (2026-06-10, Phase 4)**: `000008_dispatch_queue.sql` granted `INSERT,UPDATE` on `dispatch_queue` to both app roles (RLS `using(true)`), so the browser `truespend_app` token could forge a fake `approved` dispatch row (drainer fans out a forged email/ERP/Slack) or flip a real `pending` row to `sent` (suppress a notification). The outbox is only legitimately written by SECURITY DEFINER fns (`enqueue_dispatch` to write; `claim_dispatch_batch`/`mark_dispatch_sent`/`mark_dispatch_failed` to drain) which bypass grants — verified no app/workflow does direct DML (App.jsx SELECTs only; drainer + `drain_dispatch.js` + n8n use the RPCs only). Fix: `db/migrations/000016_dispatch_queue_revoke_direct_dml.sql` revokes INSERT/UPDATE/DELETE from both app roles, keeps SELECT (Ops Board banner). Repro: `node scripts/repro_outbox_forgery.js --forge-insert|--forge-update|--assert-blocked|--read`. **PENDING (I-8):** gated, apply via `scripts/db-migrate.sh` (dbmate).
- **Browser JWT could call money RPCs — FIX LANDED, MIGRATION + CUTOVER PENDING (2026-06-10, Phase 2)**: The SPA shipped a single static `truespend_app` JWT (no `app_role` claim) and called money RPCs (`approve_and_commit`, `reject_ticket`, `confirm_delivery`, `match_invoice`, `create_payment_instruction`) AND raw `/budget_positions` + `/users{role}` writes directly from the browser; the RPC role guard was dormant (`is not null AND` → NULL claim is a no-op). Fix: (1) extracted the API client to `intake/src/api/client.js` (single chokepoint) with a `routeMoneyThroughN8n` seam (`VITE_ROUTE_MONEY_VIA_N8N`); (2) new `workflows/stakeholder/board_action.json` (`POST /webhook/board-action`) carries every money/budget/user write server-side with a privileged token, re-fetching authoritative fields (browser sends only intent+ids); (3) `db/migrations/000015_money_rpcs_fail_closed.sql` (was `step12_*` pre-Phase-3 rename) flips all money RPCs fail-closed (`is null OR`), guards the previously-unguarded `release_budget`/`record_spend`/`create_payment_instruction`, and adds `upsert_budget_position` (closes the raw-budget-write I-1 gap). Repro: `node scripts/repro_money_rpc_exposure.js --decode|--probe|--exploit|--assert-blocked`. ADR: `docs/decisions/ADR-006-money-rpc-fail-closed.md` (flips I-2's dormant guard, I-7). **PENDING CUTOVER (do in this order or the board bricks — see ADR-006):** mint an n8n service token with `app_role:'procurement'`(+`controlling` for payments) → import+activate `board_action.json` → deploy SPA with `VITE_ROUTE_MONEY_VIA_N8N=true` → apply `000015` via `scripts/db-migrate.sh` (dbmate) + `NOTIFY pgrst,'reload schema'`. All gated. Until cutover, the seam defaults OFF and the browser still calls RPCs directly (unchanged behavior).
- **Prompt-injection in supplier_reply_handler / invoice_processor — FIX LANDED, MIGRATION PENDING (2026-06-10, Phase 1)**: Raw inbound email bodies fed Claude, whose JSON then drove actions directly (auto-send a supplier reply, PATCH-close a model-chosen ticket, steer an invoice onto a model-chosen PO + the money branch). Fix enforces "LLM advises, deterministic code decides": new Code-node guards (`workflows/lib/{reply_guard,invoice_guard}.js`, embedded via `scripts/sync-workflow-guards.js`) validate model JSON against a strict schema + allowlist, DERIVE `related_ticket_id`/`po_id` deterministically (never from the model), force model-authored auto-send off (replies go to the board as `pending_review` via `queue_supplier_reply_review`; only a FIXED-TEMPLATE ack may auto-send), and make the `match_invoice` RPC the authoritative money gate. Repro: `node workflows/__tests__/phase1_repro.test.js` (proves holes on frozen pre-fix snapshots, inert after). **PENDING (I-8):** `db/migrations/000014_supplier_email_threading.sql` (was `step11_*` pre-Phase-3 rename; adds `supplier_emails.message_id/in_reply_to/ticket_id` + `queue_supplier_reply_review` RPC) is written + tested locally but NOT yet applied to prod — gated, apply separately. The two workflows are committed but must be re-imported/activated in n8n after the migration is live (the `Resolve Thread Parent` + board RPC nodes 404 until then).
- **H3**: RLS enabled on 16 tables; `trace_log`, `supplier_emails`, `branches`, `hyperscaler_positions`, `contract_changes` have no explicit policies — covered by `app_role_all` pattern (using(true)) but not enumerated individually. (`db/schema.sql:1529–1600`)
- **UX**: No "Mark Delivered" button on Ops Board. Delivery confirmation webhook exists at `/webhook/delivery-confirmation` but no UI trigger.
- **I-1 RESOLVED (2026-05-31)**: Approve/confirm call `approve_and_commit` RPC; reject calls `reject_ticket` RPC; ack calls `close_ticket` RPC. No raw status PATCH in the UI.
- **I-2 RESOLVED (2026-05-31)**: `truespend_app` (NOSUPERUSER) is now the PostgREST login role. `PGRST_DB_URI` points to `truespend_app`. No superuser in any data-operation session. `PATCH /tickets {status:...}` returns 403. Status transitions are physically enforced through SECURITY DEFINER RPCs only. Dormant `app_role` claim check in all money RPCs auto-arms when SSO is live (TODO: drop `IS NOT NULL` guard). SSO is the next milestone — see `docs/decisions/` for ADR when started.
- **Schema divergence**: Live DB `contract_category` enum has no `ai_consumption` value (use `other`). `trace_log` has no `ticket_id` FK — uses `decision_id` only. `managers` table still exists with 5 rows; `tickets.owner_id` FK points there.
- **pgvector**: Not available on Railway standard plan. `document_embeddings` uses text column for embeddings. Full vector search is in `db/migrations/rag_schema.sql` for future use.
- **n8n instability**: Container may crash on workflow activation failure. If down: `ssh root@187.127.87.206 "cd /docker/n8n-n3xl && docker compose up -d"`.
- **n8n $env blocked in nodes (2026-06-03)**: This n8n version defaults `N8N_BLOCK_ENV_ACCESS_IN_NODE=true` — `$env.X` is denied in Code nodes AND expressions AND httpRequest headers. Set `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` in `/docker/n8n-n3xl/docker-compose.yml` (done) so workflows reading `$env.POSTGREST_JWT`/`ANTHROPIC_API_KEY` work. Box `.env` must contain those keys (env_file). Alternative pattern: stored credentials (used by `chat_assistant.json`).
- **Duplicate intake workflows in n8n (2026-06-03)**: THREE "TrueSpend — Intake Receiver" workflows share `/webhook/intake`. The CANONICAL, fixed one is `tUiEY7LpGe7zOvW8` (has Config node, RPC write-backs, no `$env`). The others (`IyVDbrvH0OmBSx7G`, `vH3Q5qftisZkBR3M`) are stale/broken — keep them DEACTIVATED or they steal the webhook path. Only one workflow may own a webhook path at a time.
- **Intake routing always picks approve branch (KNOWN BUG, 2026-06-03)**: "Route by Disposition" sends every ticket to `RPC — Approve & Create PO` regardless of disposition — a €250k request did NOT escalate. So `set_ticket_pending_review`/`escalate_ticket` RPCs are never reached. Pre-existing; not yet fixed. See `docs/routing-engine.md`.
- **Intake approve path 500s (KNOWN BUG, 2026-06-03)**: `approve_and_commit` rejects with "current status is reasoning" because the auto-execute branch calls it before transitioning the ticket out of `reasoning`; the ticket also has null `cost_center_id`/`amount_eur` from intake. Pre-existing approve-branch gap. The decision/trace/status RPC write-backs themselves work (verified green).
- **Intake write-back RPCs (2026-06-03)**: `intake_receiver.json` now routes ALL writes through SECURITY DEFINER RPCs (`record_decision`, `record_trace_signals`, `set_ticket_pending_review`, `escalate_ticket`, `complete_ticket_auto` — see `db/migrations/000012_intake_status_rpcs.sql`, `000013_status_rpcs_carry_fields.sql`; were `step9_*`/`step10_*` pre-Phase-3 rename). `truespend_app` has NO direct DML on `decisions`. NOTE: after creating new RPCs, run `NOTIFY pgrst, 'reload schema'` or PostgREST returns 404 on `/rpc/<new_fn>` until its cache refreshes.
