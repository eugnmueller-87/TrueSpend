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

## Commands

```bash
# Quality gate (run before every push)
bash scripts/quality-gate.sh

# Local dev
cd intake && npm run dev

# Build intake (Vite)
cd intake && npm run build

# Apply schema to Railway DB
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
- **I-1 RESOLVED (2026-05-31)**: Approve/confirm now call `approve_and_commit` RPC; reject calls `reject_ticket` RPC; ack calls `close_ticket` RPC. No raw status PATCH remains in the UI.
- **I-2 PARTIAL — Railway platform constraint**: `truespend` is Railway's bootstrap user (`rolsuper=t`). Railway prevents `ALTER ROLE truespend NOSUPERUSER` — "bootstrap user must have SUPERUSER attribute". Column-level REVOKE on `tickets.status` is correctly applied in the DB but is bypassed by the superuser flag at runtime. The `pgPatch` forge path is therefore open at the DB layer despite the grant being revoked. Migration `db/migrations/step2c_demote_truespend.sql` contains the correct fix; applies cleanly when migrated off Railway managed-postgres (VPS, Supabase, self-hosted). The dormant `app_role` claim check in all money RPCs (`step2_rpc_boundary.sql`) auto-arms when SSO issues the claim — that boundary is independent of the superuser issue.
- **Schema divergence**: Live DB `contract_category` enum has no `ai_consumption` value (use `other`). `trace_log` has no `ticket_id` FK — uses `decision_id` only. `managers` table still exists with 5 rows; `tickets.owner_id` FK points there.
- **pgvector**: Not available on Railway standard plan. `document_embeddings` uses text column for embeddings. Full vector search is in `db/migrations/rag_schema.sql` for future use.
- **n8n instability**: Container may crash on workflow activation failure. If down: `ssh root@187.127.87.206 "cd /docker/n8n-n3xl && docker compose up -d"`.
