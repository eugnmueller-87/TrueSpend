# Architecture

## System Topology

```
Requester (browser)
    │
    │  POST /webhook/intake
    ▼
n8n (VPS 187.127.87.206, container n8n-n3xl-n8n-1)
    │  httpRequest nodes → Bearer $env.POSTGREST_JWT
    ▼
PostgREST (Railway)  ──────────────────────────────► PostgreSQL (Railway)
    │  /rpc/approve_and_commit etc.                   zephyr.proxy.rlwy.net:24934
    │
    │  Anthropic API (claude-sonnet-4-6)
    │
    ▼
Operations Board (React SPA, nginx, Railway)
    │  VITE_POSTGREST_URL → GET /open_tickets_board
    │  VITE_N8N_WEBHOOK_BASE → POST /webhook/docusign-sign
    ▼
DocuSign (sandbox, account-d.docusign.com)
    └─ callback → n8n webhook "Truespend Docusign Received" (ID: Xq8MYxC2CCvdLd5v)

Grafana (Railway) ───────────────────────────────────► PostgreSQL (direct, read-only)
```

## Data Flow: Intake → Board → Close

1. User fills the New Request form (`App.jsx:1274`), submits to `N8N_WEBHOOK` (`/webhook/intake`).
2. `intake_receiver.json` webhook node receives POST. Creates ticket row via PostgREST, status=`reasoning`. Responds immediately to UI with reference number.
3. Workflow fetches parallel context: supplier, contracts, budget_positions, users (manager).
4. Pre-Check Gate (`intake_receiver.json` node `pre_check_gate`) runs sync checks: amount>€100k → force escalate; amount > manager authority → force one_touch; CC budget overrun → force one_touch; supplier compliance_status != green → compliance flag.
5. Claude node (`call_claude`) builds 5-signal prompt, calls `claude-sonnet-4-6`, parses JSON response. Pre-check override enforced post-Claude.
6. Decision written to `decisions` table. 5 trace_log rows written (one per signal).
7. Switch node routes on `disposition`:
   - `auto_execute` → `approve_and_commit` RPC → close ticket → send PO email via SMTP → notify submitter
   - `one_touch` → PATCH ticket status=`pending_review` → appears on Ops Board
   - `escalate` → PATCH ticket status=`escalated` → Jira issue created → appears on Ops Board
8. Procurement Manager sees ticket on board (auto-refresh 30s). Clicks Approve/Reject.
   - Approve: `pgPatch('/tickets?id=eq.{id}', {status:'approved'})` — VERIFY: budget commit happens in `approve_and_commit` RPC called by n8n, not by this PATCH.
   - Sign: `n8nPost('/docusign-sign', {ticket_id})` → DocuSign JWT flow → embedded signing URL → `window.open()`
9. DocuSign callback workflow (`Xq8MYxC2CCvdLd5v`) fires on signing event, updates ticket status.

## All 12 Workflows

### stakeholder/intake_receiver.json
- **Trigger**: POST `/webhook/intake`
- **ID**: `tUiEY7LpGe7zOvW8` (active)
- **What it does**: 5-signal Claude reasoning on procurement requests
- **Key nodes**: Pre-Check Gate (sync budget/authority check), Claude Reason on Intake (claude-sonnet-4-6, max_tokens 1500), Route by Disposition (switch), RPC Approve & Create PO
- **PostgREST writes**: `POST /tickets`, `POST /decisions`, `POST /trace_log` (bulk 5 rows), `POST /rpc/approve_and_commit`, `PATCH /tickets?id=eq.{id}`
- **SMTP**: PO email to supplier + confirmation to submitter on auto_execute
- **Jira**: Creates PROC issue on escalate

### stakeholder/docusign_sign.json
- **Trigger**: POST `/webhook/docusign-sign`
- **ID**: `D4aWf18qlGfxL4Qm` (active)
- **What it does**: JWT Grant auth → DocuSign envelope → embedded signing URL
- **Key nodes**: Get DocuSign Token (RS256 JWT, scope: signature impersonation), Create Envelope & Get Signing URL (creates envelope with sign/date tabs, returns view URL)
- **PostgREST writes**: `POST /trace_log`
- **Returns**: `{signing_url, envelope_id, ticket_id}` to UI

### DocuSign Callback (n8n ID: Xq8MYxC2CCvdLd5v)
- **Trigger**: DocuSign event webhook
- **What it does**: Receives signing completion/decline events, updates ticket status
- VERIFY: exact PostgREST writes — not inspected in detail

### automatic/contract_watcher.json
- **Trigger**: Schedule `0 7 * * 1-5` (Mon–Fri 07:00)
- **What it does**: Fetches `contracts_expiring` view (≤90 days). For each: `clean` → auto-renew; `price_increase`/`volume_change`/`scope_change` → Claude reasons → auto-execute or one_touch ticket; `manual_required` → Claude reasons then Jira escalation
- **PostgREST reads**: `GET /contracts_expiring`
- **PostgREST writes**: `POST /tickets`, `POST /decisions`, `PATCH /contracts`

### automatic/reorder_trigger.json
- **Trigger**: Schedule (daily)
- **What it does**: Finds reorder candidates, places orders or escalates. Filters on `renewal_state` not `status` (fixed M5).
- **PostgREST writes**: `POST /tickets`, `POST /rpc/approve_and_commit` (on auto-place)

### automatic/hyperscaler_monitor.json
- **Trigger**: Schedule `0 6 * * 1-5` (Mon–Fri 06:00)
- **What it does**: Fetches `hyperscaler_positions` (last 7 days). Detects: overshoot risk (`projected_eur > committed_eur`), undershoot (`projected < 80%`), idle (`idle_resources_eur > 5000`), low reservation utilisation (`reservation_util < 0.75`). Claude reasons per anomaly.
- **PostgREST reads**: `GET /hyperscaler_positions?snapshot_date=gte.{7 days ago}`
- **PostgREST writes**: `POST /tickets`, `POST /decisions`, `POST /trace_log`

### automatic/invoice_processor.json
- **Trigger**: IMAP poll — `INVOICES` mailbox, UNSEEN emails
- **What it does**: Claude extracts invoice data from email/attachment. Calls `match_invoice` RPC (3-way match: invoice vs PO vs delivery, ±2% tolerance). Matched → `create_payment_instruction` RPC → `erp_sync_queue`. Mismatch → one_touch ticket.
- **PostgREST writes**: `POST /invoices`, `POST /rpc/match_invoice`, `POST /rpc/create_payment_instruction`, `POST /workflow_runs`

### automatic/supplier_onboarding.json
- **Trigger**: POST `/webhook/supplier-onboarding` with `{supplier_id}`
- **What it does**: 4 Claude agents in parallel — Lawyer (NDA + legal risk), GDPR (DPA + data residency + SCC), InfoSec (infosec_score 0-100, TOMs, ISO 27001 gap), LkSG/Ethics (supply chain risk, sanctions, COC). Results → `compliance_checks` + `legal_documents`. If docs needed → `signature_required` ticket.
- **PostgREST reads**: `GET /suppliers?id=eq.{id}`
- **PostgREST writes**: `POST /compliance_checks`, `POST /legal_documents`, `PATCH /suppliers`, `POST /tickets`

### automatic/delivery_confirmation.json
- **Trigger**: POST `/webhook/delivery-confirmation` (Basic Auth: truespend/DELIVERY_WEBHOOK_SECRET)
- **What it does**: Calls `confirm_delivery(p_po_id, p_confirmed_by)` RPC. Updates PO status → delivered. If late, flags supplier health `green → watch`. Triggers 3-way match check.
- **PostgREST writes**: `POST /rpc/confirm_delivery`

### automatic/asset_depreciation.json
- **Trigger**: Schedule — monthly 1st 06:00
- **What it does**: Calculates monthly depreciation for all active assets. Inserts `asset_depreciation_log` rows. Fires alerts at 90/30-day warranty expiry and EOL (book value < 10% or warranty expired + rising incidents).
- **PostgREST writes**: `POST /asset_depreciation_log`, `PATCH /assets`, `POST /tickets`

### automatic/llm_consumption.json
- **Trigger**: Schedule daily 06:30
- **What it does**: Calls Anthropic + OpenAI usage APIs per registered key. Inserts `llm_consumption` rows. Charges `ai_consumption` budget bucket (stored as `other` in live enum). Anomaly: > 3× prior 7-day average → alert ticket.
- **PostgREST writes**: `POST /llm_consumption`, `POST /tickets`

### automatic/rag_embedder.json
- **Trigger**: Schedule every 6h
- **What it does**: Calls OpenAI `text-embedding-3-small` on unembedded documents. Stores in `document_embeddings`. Requires `OPENAI_API_KEY` on n8n server.
- **PostgREST writes**: `PATCH /document_embeddings`

### communication/supplier_reply_handler.json
- **Trigger**: IMAP poll — INBOX, UNSEEN emails
- **What it does**: Claude reads inbound supplier email, reasons on urgency and intent, replies directly if it can resolve. critical → Jira + trace; high/medium/low → trace only.
- **PostgREST writes**: `POST /supplier_emails`, `POST /trace_log`

## Docker / Railway Deployment Topology

### Production (live)

```
Railway
├── PostgreSQL service (truespend DB)
├── PostgREST service → connects to PostgreSQL
├── Grafana service → reads PostgreSQL directly
└── intake service
      Dockerfile (repo root)
      Stage 1: node:20-alpine → npm ci → vite build (VITE_* vars baked in at build time)
      Stage 2: nginx:1.27-alpine → serves /app/dist
      CMD: envsubst $PORT → nginx -g 'daemon off;'

VPS 187.127.87.206
└── Docker container: n8n-n3xl-n8n-1
      /docker/n8n-n3xl/docker-compose.yml (with Traefik)
      COMPOSE_PROJECT_NAME=n8n-n3xl, TRAEFIK_HOST=eugenmueller.tech
      SQLite DB: /var/lib/docker/volumes/n8n-n3xl_n8n_data/_data/database.sqlite
```

### Local Development

```
infra/docker-compose.yml (infra/docker-compose.yml:1)
├── n8n → localhost:5678
└── grafana → localhost:3000
PostgreSQL + PostgREST → Railway cloud (no local replica)
```

File:line citations:
- Dockerfile: `Dockerfile:1–37`
- railway.json build config: `railway.json:1–14`
- docker-compose.yml services: `infra/docker-compose.yml:13–91`
- CLAUDE.md VPS notes: `CLAUDE.md:192–199`
