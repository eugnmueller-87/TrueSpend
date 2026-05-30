# TrueSpend — Claude Code Intelligence

> ⚠️ **Security protocol:** Read [`SECURITY.md`](SECURITY.md) before modifying workflows, credentials, or infrastructure.
> Credentials live in Railway env vars and n8n encrypted store — **never in source files.**
> Run `bash scripts/quality-gate.sh` before every push. Hook blocks hardcoded secrets at commit time.

## What this is
Agentic procurement operating system. n8n orchestrates Claude (Sonnet 4.6) + PostgreSQL + Email/Jira.
No Slack. One clean Operations Board is the only human interface.
**Live and fully seeded.** All 12 workflows active, all 28 tables populated with 41 mock tickets.

## Stack
| Layer | Tech | URL |
|---|---|---|
| Orchestration | n8n self-hosted (187.127.87.206) | https://n8n-n3xl.eugenmueller.tech |
| Database | PostgreSQL on Railway (db=truespend, user=truespend) | zephyr.proxy.rlwy.net:24934 |
| REST API | PostgREST on Railway | https://postgrest-production-7960.up.railway.app |
| AI reasoning | Claude Sonnet 4.6 via Anthropic API | — |
| Intake UI + Ops Board | React + Vite + Tailwind → nginx → Railway | https://intake-production-84a0.up.railway.app |
| Observability | Grafana on Railway | https://grafana-production-49fc.up.railway.app |
| Escalations | Jira (PROC project, ≥€100k only) | — |
| Email | IMAP (inbound) + SMTP (outbound) via GMX | truespend.ops@gmx.de |
| e-Signature | DocuSign eSignature (sandbox) | account-d.docusign.com |

## Key files
- `db/schema.sql` — single source of truth, all 28 tables + P2I functions, 8 views, indexes, RLS
- `db/seed/` — 12 SQL files, load in order 01–12. All applied to Railway DB.
- `db/seed/mock_remaining_gen.py` — Python generator for remaining mock data (was used to seed live DB)
- `db/templates/nda_mutual_de.txt` — mutual NDA (German law, TrueSpend GmbH)
- `db/templates/dpa_de.txt` — Art. 28 GDPR DPA with TOM annex
- `workflows/` — 12 n8n workflow JSONs (all active on n8n-n3xl)
- `intake/` — React + Vite Operations Board, deployed to Railway
- `intake/src/App.jsx` — full Ops Board: submit + board tabs, DocuSign sign button wired
- `infra/docker-compose.yml` — local n8n + Grafana
- `.env.example` — all required env vars

## Workflows (12 total — all active)
- `workflows/stakeholder/intake_receiver.json` — webhook → 5-signal Claude → approve_and_commit RPC → PO email → trace
- `workflows/stakeholder/docusign_sign.json` — POST /docusign-sign → DocuSign JWT → create envelope → embedded signing URL → trace
- `workflows/communication/supplier_reply_handler.json` — IMAP → Claude → reply or route to board
- `workflows/automatic/contract_watcher.json` — daily 07:00 → expiring contracts → auto-renew or reason
- `workflows/automatic/reorder_trigger.json` — daily → reorder candidates → place or escalate
- `workflows/automatic/hyperscaler_monitor.json` — daily 06:00 → cloud spend → anomaly detection
- `workflows/automatic/supplier_onboarding.json` — webhook → 4 parallel compliance agents → docs + ticket
- `workflows/automatic/invoice_processor.json` — IMAP invoices → Claude parse → 3-way match → payment instruction → ERP queue
- `workflows/automatic/delivery_confirmation.json` — webhook → confirm_delivery RPC → 3-way match trigger → late delivery ticket
- `workflows/automatic/asset_depreciation.json` — monthly 1st 06:00 → depreciation calc → log insert → warranty/EOL alerts → tickets
- `workflows/automatic/llm_consumption.json` — daily 06:30 → Anthropic/OpenAI usage API → insert consumption → charge budget → anomaly ticket
- `Truespend Docusign Received` (n8n ID: Xq8MYxC2CCvdLd5v) — DocuSign event webhook → callback handler

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

Live schema divergences from design doc (already applied in seed scripts):
- `contract_category` enum: `{hardware,hyperscaler,saas_license,services,facilities,telecoms,other}` — no `ai_consumption` (use `other`)
- `license_assignments`: columns are `user_id` (UUID FK), `active` (boolean), `assigned_to_user` (text) — no `assigned_to` or `status`
- `hyperscaler_positions`: column is `service_name` not `service`
- `trace_log`: no `ticket_id` FK — uses `decision_id` only (signal/value/green/weight/notes columns)
- `legal_documents`: no `ticket_id` column — linked via `supplier_id`
- `managers` table still exists in live DB (5 rows, IDs 1-5) — `tickets.owner_id` FK points here

## PostgREST authentication
All workflow httpRequest nodes use `Authorization: Bearer $env.POSTGREST_JWT`.
Header Auth credential in n8n named "Authorization-TrueSpend".
JWT: role=truespend, HS256, 10-year expiry. Stored in `.env` as `POSTGREST_JWT`.

## Operations Board (intake UI)
`intake/src/App.jsx` — two tabs:
1. **Submit Request** — intake form → POST `/api/intake` → n8n webhook
2. **Operations Board** — fetches `open_tickets_board` from PostgREST directly.
   Auto-refreshes 30s. Grouped by status priority. Approve/Reject/Sign/Acknowledge via PATCH.
   **Sign button**: POST `/docusign-sign` → n8n → DocuSign → opens embedded signing URL in new tab.
   Requires: `VITE_POSTGREST_URL`, `VITE_POSTGREST_JWT`, `N8N_WEBHOOK_URL` on Railway intake service.

## DocuSign integration
- Integration: JWT Grant (server-to-server, no popup). Sandbox: `account-d.docusign.com`.
- Env vars required on n8n server: `DOCUSIGN_INTEGRATION_KEY`, `DOCUSIGN_USER_ID`, `DOCUSIGN_ACCOUNT_ID`, `DOCUSIGN_RSA_PRIVATE_KEY`, `DOCUSIGN_BASE_URL`, `DOCUSIGN_OAUTH_URL`
- RSA private key in env: single-line with `\n` escaped as `\\n` — workflow unescapes at runtime
- JWT consent: already granted at `https://account-d.docusign.com/oauth/auth?...` for the registered app
- Redirect URI registered: `https://intake-production-84a0.up.railway.app`
- Sign flow: Ops Board Sign button → POST `/webhook/docusign-sign` → n8n workflow `D4aWf18qlGfxL4Qm` → DocuSign envelope created → embedded signing URL returned → `window.open()` in new tab
- After signing: DocuSign fires callback to `Truespend Docusign Received` workflow (ID: Xq8MYxC2CCvdLd5v)

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
Supplier status updated. If docs needed → `signature_required` ticket on Ops Board → Sign button → DocuSign.

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
Allocated to branch + cost_center → charged to `ai_consumption` budget bucket (stored as `other` in live enum).
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
- n8n runs on VPS 187.127.87.206, Docker container `n8n-n3xl-n8n-1`, data at `/var/lib/docker/volumes/n8n-n3xl_n8n_data/_data/`
- n8n SQLite DB: `/var/lib/docker/volumes/n8n-n3xl_n8n_data/_data/database.sqlite`

## Go-live status (2026-05-30) ✓
1. ✅ Schema applied: `db/schema.sql` — 28 tables, all RPCs, views, indexes
2. ✅ Seeds applied: all 12 SQL files + `mock_remaining_gen.py` output → 41 tickets live
3. ✅ `VITE_POSTGREST_URL` + `VITE_POSTGREST_JWT` on Railway intake service
4. ✅ All 12 workflows active on n8n (https://n8n-n3xl.eugenmueller.tech)
5. ✅ "Authorization-TrueSpend" Header Auth assigned to PostgREST nodes
6. ✅ Anthropic credential assigned to all Claude nodes
7. ✅ DocuSign: JWT consent granted, RSA key in env, Sign workflow active (ID: D4aWf18qlGfxL4Qm)
8. ⏳ invoice_processor IMAP: should point at `INVOICES` folder (separate from supplier_reply_handler)
9. ⏳ "Mark Delivered" button on Operations Board (no UI button yet — delivery_confirmation webhook exists)
10. ⏳ H3: RLS policies for `trace_log`, `supplier_emails`, `branches`, `hyperscaler_positions`, `contract_changes`

## P2I RPCs (PostgREST /rpc/ endpoints — all ready)
- `approve_and_commit` — atomic: generates PO number + commits budget + creates PO + updates ticket
- `confirm_delivery`   — marks PO delivered, flags supplier health if late
- `match_invoice`      — 3-way match logic, sets invoice status, advances PO to invoiced
- `create_payment_instruction` — creates PI + writes erp_sync_queue + calls record_spend
- `commit_budget`      — lock + increment committed (used inside approve_and_commit)
- `release_budget`     — lock + decrement committed (rejection/cancellation path)
- `record_spend`       — lock + release committed + increment spent (invoice approved)

## Quality gate
```bash
bash scripts/quality-gate.sh
```

## Known issues
### Open
- **H3** — RLS policies: 15 tables covered. `trace_log`, `supplier_emails`, `branches`,
  `hyperscaler_positions`, `contract_changes` covered by `app_role_all` pattern but not enumerated
- **UX** — No "Mark Delivered" button on Ops Board (delivery_confirmation webhook at `/webhook/delivery-confirmation` works, just no button yet)

### Fixed
- **H1** ✓ — `hyperscaler_monitor.json` check_flags already used correct field names
- **M1** ✓ — `manual_required` contracts route through Claude reasoning before Jira
- **M2** ✓ — `supplier_reply_handler.json` urgency routing: critical→Jira+trace, high/medium/low→trace only
- **M3** ✓ — `intake_receiver.json` writes 5 separate trace_log rows — one per signal
- **L1** ✓ — `contract_watcher.json` auto-renew creates ticket first; decision has ticket_id FK
- **managers→users** ✓ — all workflow references to `/managers` updated to `/users`
- **M4** ✓ — branch_id sends UUIDs not display names
- **M5** ✓ — `reorder_trigger.json` uses `renewal_state` not `status`
- **H2** ✓ — `order_reference` column on `supplier_emails`
- **L2** ✓ — `hyperscaler_monitor.json` trace signal is `consumption`
- **H4** ✓ — `contracts_expiring` view uses `>=` (catches same-day expiries)
- **Slack** ✓ — zero Slack nodes in all workflows
- **DocuSign IF node** ✓ — `$env.VAR` doesn't evaluate in IF node conditions; removed IF node, made straight-line flow
- **Webhook conflict** ✓ — old `womQsMmOTTD78LYq` workflow deleted; `docusign-sign` path now owned by `D4aWf18qlGfxL4Qm`
- **Mock data** ✓ — all 28 tables seeded; 41 tickets including `signature_required` tickets for DocuSign testing

## Stability improvements (2026-05-27)
- All 9 Claude httpRequest nodes: 120,000ms timeout, retry 3× with 2s backoff
- All 45 PostgREST write nodes: 30,000ms timeout, retry 3× with 1s backoff
- `tickets.category` column added — eliminates correlated subquery in `open_tickets_board`
- Covering index on `budget_positions(branch_id, category, period)` — budget check answered from index
- Partial index on `tickets(status, created_at)` — Operations Board query uses index-only scan
- `commit_budget()`, `release_budget()`, `record_spend()` PostgreSQL functions — atomic budget ops, no race conditions
- `workflow_runs` table — every workflow writes start/end/status for Grafana health dashboards

## Never build
Commodity taxonomy, SRM workflows, complex scorecards, 47-field onboarding,
CC approval chains, category strategy frameworks, line-item budget matching.
