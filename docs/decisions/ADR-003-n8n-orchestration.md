# ADR-003: n8n as Workflow Orchestrator
Date: 2026-05-27
Status: Accepted

## Context

TrueSpend needs to orchestrate: IMAP polling, HTTP calls to PostgREST and Anthropic API, SMTP sending, Jira API, DocuSign API, scheduled jobs (daily/monthly), and branching logic based on agent responses. Options:
1. Custom Node.js application with cron jobs and explicit HTTP calls
2. n8n — low-code workflow platform with built-in triggers, IMAP, SMTP, HTTP, schedule, and code nodes
3. Managed orchestration (Zapier, Make, etc.) — not viable for self-hosted DB + custom RPCs

## Decision

Use n8n self-hosted on a VPS (187.127.87.206), exposed via Traefik at `https://n8n-n3xl.eugenmueller.tech`.

n8n provides:
- Schedule triggers (cron expressions)
- IMAP email triggers with attachment support
- Webhook endpoints (POST triggers for intake, supplier-onboarding, delivery-confirmation, docusign-sign, docusign-callback)
- httpRequest nodes for PostgREST and Anthropic API
- Code nodes (JavaScript, async/await, `this.helpers.httpRequest`)
- Switch nodes for disposition routing
- Credentials management (encrypted — `N8N_ENCRYPTION_KEY`)
- Execution logs at `https://n8n-n3xl.eugenmueller.tech/workflow/{id}/executions`

All 12 active workflows are JSON files in `workflows/` directory and importable into n8n.

## Consequences

- n8n is a single point of failure. If the container crashes, no workflows run. Mitigation: `restart: unless-stopped` in docker-compose; SSH restart procedure documented in `CLAUDE.md:192–199`.
- n8n SQLite DB at `/var/lib/docker/volumes/n8n-n3xl_n8n_data/_data/database.sqlite` contains: workflow definitions, credentials (encrypted), execution history. Must be backed up separately.
- Credentials are stored in n8n's encrypted store — they are NOT visible in workflow JSON files exported to git. Workflow JSON files use `$env.VAR_NAME` references or n8n credential IDs.
- The `$env.VAR_NAME` syntax only works in Code nodes and expression fields. It does NOT work in IF node conditions (`docusign-sign` workflow was fixed by removing IF node for env var check — see CLAUDE.md fixed issues).
- Workflow activation on n8n startup can fail if credentials are missing or invalid. Symptom: container up but workflows inactive. Fix: re-import workflow JSON and reassign credentials.
- IMAP polling: `supplier_reply_handler` polls INBOX; `invoice_processor` polls INVOICES mailbox. Both use UNSEEN filter — mark-as-read on pick-up. VERIFY: IMAP mailbox for invoice_processor must be pointed at `INVOICES` folder (open issue in CLAUDE.md go-live checklist item 8).

## Invariants Affected

- I-6: Secrets live in n8n encrypted credential store and Railway env vars. NEVER in workflow JSON exported to git. Quality gate checks for `Bearer eyJ` and `BEGIN PRIVATE KEY` patterns in tracked files.
