# TrueSpend — Claude Code Intelligence

## What this is
Agentic procurement operating system. n8n orchestrates Claude (Sonnet 4.6) + PostgreSQL + Email/Jira.
No Slack. One clean Operations Board is the only human interface.
Pre-production. Full architecture designed and built as config/code.

## Stack
| Layer | Tech | URL |
|---|---|---|
| Orchestration | n8n self-hosted | https://n8n-n3xl.eugenmueller.tech |
| Database | PostgreSQL on Railway | zephyr.proxy.rlwy.net:24934 |
| REST API | PostgREST on Railway | https://postgrest-production-7960.up.railway.app |
| AI reasoning | Claude Sonnet 4.6 via Anthropic API | — |
| Intake UI + Ops Board | React + Vite + Tailwind → nginx → Railway | — |
| Observability | Grafana on Railway | https://grafana-production-49fc.up.railway.app |
| Escalations | Jira (PROC project, ≥€100k only) | — |
| Email | IMAP (inbound) + SMTP (outbound) | — |

## Key files
- `db/schema.sql` — single source of truth, all 28 tables, 7 views, indexes, RLS
- `db/seed/` — 7 SQL files, load in order 01–07
- `db/templates/nda_mutual_de.txt` — mutual NDA (German law, TrueSpend GmbH)
- `db/templates/dpa_de.txt` — Art. 28 GDPR DPA with TOM annex
- `workflows/` — 6 n8n workflow JSONs
- `intake/` — React + Vite Operations Board, deploys as Docker to Railway
- `infra/docker-compose.yml` — local n8n + Grafana
- `.env.example` — all required env vars

## Workflows (6 total)
- `workflows/stakeholder/intake_receiver.json` — webhook → 5-signal Claude → auto/one-touch/escalate
- `workflows/communication/supplier_reply_handler.json` — IMAP → Claude → reply or route to board
- `workflows/automatic/contract_watcher.json` — daily 07:00 → expiring contracts → auto-renew or reason
- `workflows/automatic/reorder_trigger.json` — daily → reorder candidates → place or escalate
- `workflows/automatic/hyperscaler_monitor.json` — daily 06:00 → cloud spend → anomaly detection
- `workflows/automatic/supplier_onboarding.json` — webhook → 4 parallel compliance agents → docs + ticket

## Schema overview (v2.0 — 28 tables)
```
Organization    branches · cost_centers · users
Suppliers       suppliers · legal_documents · compliance_checks
Contracts       contracts · contract_changes · contract_clauses
Budget          budget_buckets · budget_positions · budget_pools · budget_reallocations
P2I             purchase_orders · po_sequences · invoices · payment_instructions · erp_sync_queue
Assets          assets · asset_depreciation_log
Licenses        license_entitlements · license_assignments
Consumption     hyperscaler_positions · llm_api_keys · llm_consumption
Operations      tickets · decisions · trace_log · supplier_emails
Intelligence    vendor_pricing_benchmarks · trust_settings
```

Key enum changes from v1: `contract_category` → `spend_category` (adds `ai_consumption`).
`managers` table → `users` table (unified model for all roles).
`ticket_status` enum now includes `pending_review` and `signature_required` (v2 merged in).

## PostgREST authentication
All workflow httpRequest nodes use `Authorization: Bearer $env.POSTGREST_JWT`.
Header Auth credential in n8n named "Authorization-TrueSpend".
JWT: role=truespend, HS256, 10-year expiry. Stored in `.env` as `POSTGREST_JWT`.

## Operations Board (intake UI)
`intake/src/App.jsx` — two tabs:
1. **Submit Request** — intake form → POST `/api/intake` → n8n webhook
2. **Operations Board** — fetches `open_tickets_board` from PostgREST directly.
   Auto-refreshes 30s. Grouped by status priority. Approve/Reject/Sign/Acknowledge via PATCH.
   Requires: `VITE_POSTGREST_URL` and `VITE_POSTGREST_JWT` on Railway intake service.

## Budget model
- `budget_buckets` — the plan (Controlling sets annually per branch × category × quarter)
- `budget_positions` — the running ledger (committed and spent updated on every approval/invoice)
- `budget_pools` — CFO-held unallocated reserves per branch
- `budget_reallocations` — immutable audit trail of every budget move
- Three-tier approval check: category bucket → branch annual → manager spend authority
- `committed` moves at approval, not at invoice. Released on rejection or cancellation.
- No cost center pocket games: every budget move is visible, requires approval, is logged.

## Agent philosophy
- Agent acts silently on everything it's confident about (auto_execute).
- One-touch: ticket appears on Operations Board. No push notification. No Slack.
- Only ≥€100k or compliance blockers create Jira tickets.
- The audit trail IS the agent's thought process — trace_log stores full reasoning chain.

## Three-signal disposition model
Every agent call returns: `{ disposition, confidence, reasoning, ... }`
- `auto_execute` — all signals green, confidence ≥ threshold → agent acts, closes
- `one_touch` — one signal uncertain → ticket on Operations Board with Approve/Reject
- `escalate` — ≥€100k, compliance blocker, or novel situation → Jira PROC ticket

## Compliance stack (supplier_onboarding workflow)
Webhook: `/webhook/supplier-onboarding` with `{ supplier_id }`
4 Claude agents in parallel:
- **Lawyer** — NDA generation, legal risk score, blockers
- **GDPR** — DPA content, data residency check, SCC requirement
- **InfoSec** — infosec_score 0-100, TOMs for DPA Annex 2, ISO 27001 gap
- **LkSG/Ethics** — supply chain risk, sanctions check, COC requirement
Results → `compliance_checks` + `legal_documents`.
Supplier status updated. If docs needed → `signature_required` ticket on Ops Board.

## P2I flow (Purchase to Invoice)
Request → budget pre-check (3 tiers) → PO created → delivery confirmation →
3-way invoice match (invoice vs PO vs receipt, ±2% tolerance) →
payment instruction record → erp_sync_queue for ERP handoff.

## License self-service via Jira
Jira ticket (type: License Request) → `/webhook/intake` → agent checks:
1. Is this product already in `license_entitlements` with available seats?
2. Budget bucket for `branch × saas_license × quarter` has headroom?
3. Manager spend authority covers this?
→ Provision same day, update `license_assignments`, commit budget, close Jira.

## LLM consumption tracking
Every AI API key registered in `llm_api_keys`.
Daily consumption pulled from provider API → `llm_consumption`.
Allocated to branch + cost_center → charged to `ai_consumption` budget bucket.
Anomaly: > 3× prior 7-day average → alert ticket on board.

## Asset lifecycle
`assets` table: hardware register with depreciation.
Monthly: `asset_depreciation_log` entries generated → Controlling posts journal entries.
Warranty expiry tracked → alert at 90/30 days.
End-of-life: book value < 10% OR warranty expired + rising incidents → replacement PO via P2I.
Decommission: license_assignments detached → seats returned to available pool.

## ERP integration (Phase D)
`erp_sync_queue` — every ERP-relevant event lands here.
Connector workflows read queue and fire ERP-specific API calls.
Supported: SAP S/4HANA, Oracle Fusion, Coupa, NetSuite, Dynamics 365.
If no connector: status = 'skipped', Controlling exports CSV for manual posting.
TrueSpend is the reasoning layer. ERP is the book of record.

## Railway deployment
- `railway.json` → builds `intake/Dockerfile` → nginx serving React SPA
- Separate Railway services: PostgreSQL, PostgREST, n8n, Grafana, intake
- Required env vars on intake service: `VITE_POSTGREST_URL`, `VITE_POSTGREST_JWT`, `N8N_WEBHOOK_URL`

## Go-live checklist (immediate)
1. Apply schema: `psql $DATABASE_URL -f db/schema.sql`
2. Apply seeds: `for f in db/seed/0*.sql; do psql $DATABASE_URL -f $f; done`
3. Set `VITE_POSTGREST_URL` + `VITE_POSTGREST_JWT` on Railway intake service
4. Re-import all 6 workflows to n8n (delete old, import updated JSONs)
5. Assign "Authorization-TrueSpend" Header Auth to all PostgREST nodes
6. Assign Anthropic credential to all Claude nodes

## Quality gate
```bash
bash scripts/quality-gate.sh
```

## Known issues (from audit 2026-05-27)
### Open
- **H1** — `hyperscaler_monitor.json` check_flags node references wrong field names
  Schema: `projected_eur`, `committed_eur`, `reservation_util`
  Workflow references: `projected_spend_eur`, `committed_spend_eur`, `reservation_utilization`
  Fix: update the check_flags IF node expressions in hyperscaler_monitor.json
- **H3** — RLS policies incomplete (only 5 tables covered in v1; v2 schema covers 15)
- **M1** — `manual_required` contracts skip Claude reasoning, go straight to Jira
- **M2** — `supplier_reply_handler.json` urgency routing fans all outputs simultaneously
- **M3** — `intake_receiver.json` writes 1 trace_log row for all 5 signals (should be 5)
- **L1** — auto-renew decision in `contract_watcher.json` has no ticket FK (orphaned decision)

### Fixed
- **M4** ✓ — branch_id sends UUIDs not display names
- **M5** ✓ — `reorder_trigger.json` uses `renewal_state` not `status`
- **H2** ✓ — `order_reference` column on `supplier_emails`
- **L2** ✓ — `hyperscaler_monitor.json` trace signal is `consumption`
- **H4** ✓ — `contracts_expiring` view uses `>=` (catches same-day expiries)
- **Slack** ✓ — zero Slack nodes in all 6 workflows

## Never build
Commodity taxonomy, SRM workflows, complex scorecards, 47-field onboarding,
CC approval chains, category strategy frameworks, line-item budget matching.
