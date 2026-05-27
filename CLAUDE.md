# TrueSpend — Claude Code Intelligence

## What this is
Agentic procurement operating system. n8n orchestrates Claude (Sonnet) + Supabase + Slack/Jira/Email.
Pre-build. Architecture defined and built as config/code — no Python runtime yet.

## Stack
| Layer | Tech | URL |
|---|---|---|
| Orchestration | n8n self-hosted | https://n8n-n3xl.eugenmueller.tech |
| Database | PostgreSQL on Railway | zephyr.proxy.rlwy.net:24934 |
| REST API | PostgREST on Railway | https://postgrest-production-7960.up.railway.app |
| AI reasoning | Claude claude-sonnet-4-6 via Anthropic API | — |
| Intake UI | React + Vite + Tailwind → nginx Docker → Railway | — |
| Observability | Grafana on Railway | https://grafana-production-49fc.up.railway.app |
| Notifications | Slack (blocks), Jira (PROC project), Email (IMAP/SMTP) | — |

## Key files
- `db/schema.sql` — single source of truth for all tables, enums, views, indexes, RLS
- `db/seed/` — 7 SQL files, load in order 01–07
- `workflows/` — 4 n8n workflow JSONs (import via n8n UI or REST API)
- `intake/` — standalone Vite app, deploys as Docker to Railway
- `infra/docker-compose.yml` — runs n8n + Grafana locally
- `.env.example` — all required env vars

## Railway deployment
- `railway.json` at root → builds `intake/Dockerfile` → nginx serving static SPA
- Set `N8N_WEBHOOK_URL` env var on the Railway intake service (points to n8n Railway service)
- n8n deploys as a separate Railway service from `infra/docker-compose.yml` or standalone Docker
- Grafana deploys as a separate Railway service

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
- **M2** — `supplier_reply_handler.json` urgency routing fans all outputs to all notification nodes simultaneously
- **M3** — `intake_receiver.json` writes only 1 trace_log row for all 5 signals (should be 5 rows)
- **L1** — auto-renew decision in `contract_watcher.json` has no ticket FK (decision is orphaned)

### FIXED
- **M4** ✓ — branch_id in intake UI now sends UUIDs not display names
- **M5** ✓ — `reorder_trigger.json` no longer filters on `status` (uses `renewal_state`)
- **H2** ✓ — `order_reference` column added to `supplier_emails`
- **L2** ✓ — `hyperscaler_monitor.json` trace signal changed from `hyperscaler_monitor` to `consumption`

## Three-signal disposition model
Every agent call returns: `{ disposition, confidence, reasoning, ... }`
- `auto_execute` — high confidence, all signals green → agent acts, closes ticket
- `one_touch` — one signal uncertain → Slack block to owner with Approve/Reject
- `escalate` → Jira PROC ticket, full brief attached

## Intake form → workflow path
`intake/src/App.jsx` → POST `/api/intake` → nginx proxies to `$N8N_WEBHOOK_URL/webhook/truespend-intake` → `intake_receiver.json` webhook trigger

## Never build (from STORY.md)
Commodity taxonomy, SRM workflows, complex scorecards, 47-field onboarding, CC approval chains, category strategy frameworks.
