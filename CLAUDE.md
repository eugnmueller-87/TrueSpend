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
| `db/schema.sql` | Single source of truth — 28 tables, RPCs, 8 views + analytics views, indexes, RLS |
| `db/seed/01–12*.sql` | Load in order. Applied to Railway DB. |
| `intake/src/App.jsx` | Full Ops Board: roles, board, submit, catalog, budget, suppliers, search |
| `workflows/stakeholder/intake_receiver.json` | Main intake path — webhook → Claude → dispose |
| `workflows/stakeholder/chat_assistant.json` | Ask assistant — `/webhook/chat` → scope gate → pre-fetch bundle → Claude (read-only, I-9) |
| `workflows/stakeholder/docusign_sign.json` | Sign button → DocuSign JWT → embedded URL |
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
Writing a SQL file and pushing it is NOT done. The file must be run through `scripts/db-migrate.sh`
against `$DATABASE_URL` and appear in the `schema_migrations` table. CI (`.github/workflows/db-migrate.yml`)
does this automatically on push when migration files change. For manual apply:
```bash
DATABASE_URL=postgresql://truespend:...@zephyr.proxy.rlwy.net:24934/truespend \
  bash scripts/db-migrate.sh
```
Never re-edit a migration file to "fix" something — add a new migration instead.
See: `scripts/db-migrate.sh`, `.github/workflows/db-migrate.yml`

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

# Apply pending DB migrations to prod (requires DATABASE_URL in env)
bash scripts/db-migrate.sh

# Check which migrations are applied / pending
bash scripts/db-migrate.sh --status

# Dry run — print plan without applying
bash scripts/db-migrate.sh --dry-run

# Local dev
cd intake && npm run dev

# Build intake (Vite)
cd intake && npm run build

# Apply schema to Railway DB (first-time setup only — use db-migrate.sh for incremental)
psql $DATABASE_URL -f db/schema.sql

# Apply seeds
for f in db/seed/0*.sql; do psql $DATABASE_URL -f $f; done

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
- **Intake write-back RPCs (2026-06-03)**: `intake_receiver.json` now routes ALL writes through SECURITY DEFINER RPCs (`record_decision`, `record_trace_signals`, `set_ticket_pending_review`, `escalate_ticket`, `complete_ticket_auto` — see `db/migrations/step9_*`, `step10_*`). `truespend_app` has NO direct DML on `decisions`. NOTE: after creating new RPCs, run `NOTIFY pgrst, 'reload schema'` or PostgREST returns 404 on `/rpc/<new_fn>` until its cache refreshes.
