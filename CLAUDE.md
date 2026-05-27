# TrueSpend — Claude Code Intelligence

## What this is
Agentic procurement operating system. n8n orchestrates Claude (Sonnet) + PostgreSQL + Email/Jira.
Slack has been deliberately removed — one clean Operations Board is the only human interface.
Pre-build. Architecture defined and built as config/code — no Python runtime yet.

## Stack
| Layer | Tech | URL |
|---|---|---|
| Orchestration | n8n self-hosted | https://n8n-n3xl.eugenmueller.tech |
| Database | PostgreSQL on Railway | zephyr.proxy.rlwy.net:24934 |
| REST API | PostgREST on Railway | https://postgrest-production-7960.up.railway.app |
| AI reasoning | Claude claude-sonnet-4-6 via Anthropic API | — |
| Intake UI + Ops Board | React + Vite + Tailwind → nginx Docker → Railway | — |
| Observability | Grafana on Railway | https://grafana-production-49fc.up.railway.app |
| Notifications | Jira (PROC project, ≥€100k only), Email (IMAP/SMTP) | — |

## Key files
- `db/schema.sql` — single source of truth for all tables, enums, views, indexes, RLS
- `db/seed/` — 7 SQL files, load in order 01–07
- `db/templates/nda_mutual_de.txt` — mutual NDA template (German law, TrueSpend GmbH)
- `db/templates/dpa_de.txt` — Art. 28 GDPR DPA template with TOM annex
- `workflows/` — 6 n8n workflow JSONs (import via n8n UI or REST API)
- `intake/` — standalone Vite app, deploys as Docker to Railway
- `infra/docker-compose.yml` — runs n8n + Grafana locally
- `.env.example` — all required env vars

## Workflows (6 total)
- `workflows/stakeholder/intake_receiver.json` — intake webhook → Claude → auto/one-touch/escalate
- `workflows/communication/supplier_reply_handler.json` — IMAP → Claude → reply or escalate
- `workflows/automatic/contract_watcher.json` — daily 07:00 → expiring contracts → auto-renew or reason
- `workflows/automatic/reorder_trigger.json` — daily → reorder candidates → agent places or escalates
- `workflows/automatic/hyperscaler_monitor.json` — daily 06:00 → cloud spend → anomaly detection
- `workflows/automatic/supplier_onboarding.json` — webhook → 4 parallel compliance agents → docs + ticket

## PostgREST authentication
All workflow httpRequest nodes use `Authorization: Bearer $env.POSTGREST_JWT` (Header Auth credential named "Authorization-TrueSpend" in n8n). JWT role=truespend, 10-year expiry, stored in `.env` as `POSTGREST_JWT`.

## Operations Board (intake UI)
`intake/src/App.jsx` has two tabs:
1. **Submit Request** — original intake form → POST `/api/intake` → n8n webhook
2. **Operations Board** — fetches `open_tickets_board` view from PostgREST directly.
   Auto-refreshes 30s. Tickets grouped by status (signature_required first).
   Approve/Reject/Sign/Acknowledge buttons PATCH PostgREST directly.
   Requires env vars on Railway: `VITE_POSTGREST_URL` and `VITE_POSTGREST_JWT`.

## Compliance stack (supplier onboarding)
Triggered at webhook `/webhook/supplier-onboarding` with `{ supplier_id }`.
4 Claude agents run in parallel:
- **Lawyer agent** — NDA generation, legal risk score, blockers
- **GDPR agent** — DPA content, data residency, SCC requirement
- **InfoSec agent** — infosec_score 0-100, TOMs for DPA Annex 2, ISO 27001 gap
- **LkSG/Ethics agent** — supply chain risk, sanctions check, COC requirement

Results saved to `compliance_checks` + `legal_documents` tables.
Supplier status updated on `suppliers` table.
If docs needed → `signature_required` ticket created (visible on Ops Board).
Templates in `db/templates/` are filled with agent-generated content.

## Agent philosophy
- Agent acts silently on everything it's confident about.
- One-touch: ticket appears on Operations Board. No push notification.
- Only contracts/decisions ≥€100k create Jira tickets.
- No Slack. Zero Slack nodes in any workflow.

## Three-signal disposition model
Every agent call returns: `{ disposition, confidence, reasoning, ... }`
- `auto_execute` — high confidence, all signals green → agent acts, closes ticket
- `one_touch` — one signal uncertain → ticket on Operations Board with Approve/Reject
- `escalate` — ≥€100k or legal/compliance blocker → Jira PROC ticket, full brief attached

## Railway deployment
- `railway.json` at root → builds `intake/Dockerfile` → nginx serving static SPA
- Set `N8N_WEBHOOK_URL`, `VITE_POSTGREST_URL`, `VITE_POSTGREST_JWT` on the Railway intake service
- n8n deploys as a separate Railway service from `infra/docker-compose.yml` or standalone Docker
- Grafana deploys as a separate Railway service

## Pending before go-live
1. Apply schema migration: new tables/enums/views appended to `db/schema.sql` need `psql` run against Railway DB
2. Set `VITE_POSTGREST_URL` + `VITE_POSTGREST_JWT` on Railway intake service (Ops Board needs these)
3. Re-import all 6 workflows to n8n (delete old imports, import updated JSONs)
4. Assign "Authorization-TrueSpend" Header Auth to all PostgREST nodes in n8n after import
5. Assign Anthropic credential to all Claude (httpRequest to api.anthropic.com) nodes

## Quality gate
Run before every push:
```bash
bash scripts/quality-gate.sh
```
Checks: JSON validity, schema field names vs workflow references, branch_id UUIDs, signal_type enum values, .env.example coverage, Vite build.

## Known schema/workflow field gaps (from audit 2026-05-27)
### OPEN (not yet fixed)
- **H1** — `hyperscaler_positions` schema uses `projected_eur`/`committed_eur`/`reservation_util` but `hyperscaler_monitor.json` `check_flags` node references `projected_spend_eur`/`committed_spend_eur`/`reservation_utilization` — one of the two needs to change
- **H3** — RLS policies only on 5 of 12 tables; missing for `trace_log`, `supplier_emails`, `managers`, `branches`, `hyperscaler_positions`, `contract_changes`, `budget_positions`
- **H4** — `contracts_expiring` view uses `expiry_date > current_date` (strict), misses same-day expiries — should be `>=`
- **M1** — `manual_required` contracts skip Claude reasoning, go straight to Jira escalation with no brief
- **M2** — `supplier_reply_handler.json` urgency routing fans all outputs to all notification nodes simultaneously (both trace nodes fire)
- **M3** — `intake_receiver.json` writes only 1 trace_log row for all 5 signals (should be 5 rows)
- **L1** — auto-renew decision in `contract_watcher.json` has no ticket FK (decision is orphaned)

### FIXED
- **M4** ✓ — branch_id in intake UI now sends UUIDs not display names
- **M5** ✓ — `reorder_trigger.json` no longer filters on `status` (uses `renewal_state`)
- **H2** ✓ — `order_reference` column added to `supplier_emails`
- **L2** ✓ — `hyperscaler_monitor.json` trace signal changed from `hyperscaler_monitor` to `consumption`
- **Slack** ✓ — all Slack nodes removed from all 6 workflows; replaced with trace_log writes

## Never build (from STORY.md)
Commodity taxonomy, SRM workflows, complex scorecards, 47-field onboarding, CC approval chains, category strategy frameworks.
