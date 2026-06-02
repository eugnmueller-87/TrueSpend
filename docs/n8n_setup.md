# n8n Setup — TrueSpend

## What you need
- Docker installed (for local) or an n8n Cloud account
- `.env` file filled in (see [SETUP.md](../SETUP.md))
- Supabase already set up (see [supabase_setup.md](supabase_setup.md))

---

## Option A — Local with Docker (recommended for testing)

```bash
cd TrueSpend
cp .env.example .env        # fill in your values
cd infra
docker compose up -d n8n
```

n8n is now at **http://localhost:5678**

Create your admin account on first visit.

---

## Option B — n8n Cloud

1. Sign up at [n8n.io](https://n8n.io)
2. Skip Docker — import workflows directly in the UI
3. Set credentials in n8n UI instead of `.env`

---

## Credentials to configure in n8n

Go to **Settings → Credentials → New**. Create one credential per row:

| Credential Name | Type | Fields |
|---|---|---|
| `Anthropic API` | HTTP Header Auth | Header: `x-api-key`, Value: your `ANTHROPIC_API_KEY` |
| `Supabase` | HTTP Header Auth | Header: `apikey`, Value: `SUPABASE_SERVICE_ROLE_KEY`; also set base URL |
| `Slack Bot` | Slack OAuth2 | Bot token: `SLACK_BOT_TOKEN` |
| `Jira` | Jira API | Base URL, email, API token |
| `Email IMAP` | IMAP | Host, port, user, <REDACTED_ROTATE_ME> (use App Password for Gmail) |
| `Email SMTP` | SMTP | Host, port, user, <REDACTED_ROTATE_ME> |

> **Supabase HTTP credential:** Set the base URL to `SUPABASE_URL/rest/v1` so
> all Supabase nodes can use relative paths like `/contracts?select=*`

---

## Workflow import order

Import workflows in this order — later workflows depend on data created by earlier ones.

```
1. workflows/automatic/contract_watcher.json
2. workflows/stakeholder/intake_receiver.json
3. workflows/communication/supplier_reply_handler.json
4. workflows/automatic/reorder_trigger.json
5. workflows/automatic/hyperscaler_monitor.json
```

**How to import:**
- n8n sidebar → **Workflows** → **Import from file**
- Select the JSON file
- Open the workflow and assign credentials to each node that needs them (nodes with a ⚠️ icon)

---

## Credential mapping per workflow

### 1. contract_watcher.json
| Node | Credential |
|---|---|
| Fetch Expiring Contracts | Supabase |
| Claude API | Anthropic API |
| Write Decision | Supabase |
| Write Trace | Supabase |
| Slack — One Touch | Slack Bot |
| Jira — Escalate | Jira |
| Update Contract | Supabase |

### 2. intake_receiver.json
| Node | Credential |
|---|---|
| Webhook | *(none — public endpoint)* |
| Create Ticket | Supabase |
| Fetch Supplier Context | Supabase |
| Fetch Contract Context | Supabase |
| Fetch Budget Position | Supabase |
| Fetch Manager | Supabase |
| Claude API | Anthropic API |
| Write Decision | Supabase |
| Write Trace | Supabase |
| Send Supplier Email | Email SMTP |
| Slack — One Touch | Slack Bot |
| Jira — Escalate | Jira |
| Close Ticket | Supabase |

### 3. supplier_reply_handler.json
| Node | Credential |
|---|---|
| IMAP Trigger | Email IMAP |
| Match Supplier | Supabase |
| Flag Unknown — Slack | Slack Bot |
| Fetch Open Tickets | Supabase |
| Fetch Email History | Supabase |
| Fetch Contracts | Supabase |
| Claude API | Anthropic API |
| Update Email Record | Supabase |
| Send Reply | Email SMTP |
| Log Outbound Email | Supabase |
| Close Ticket | Supabase |
| Slack — Urgent | Slack Bot |
| Slack — Ops | Slack Bot |
| Jira — Escalate | Jira |

### 4. reorder_trigger.json
| Node | Credential |
|---|---|
| Fetch Consumption Signals | Supabase |
| Fetch Supplier Health | Supabase |
| Fetch Contract Terms | Supabase |
| Fetch Budget Position | Supabase |
| Claude API | Anthropic API |
| Send Supplier Email | Email SMTP |
| Log PO | Supabase |
| Close Ticket | Supabase |
| Slack — One Touch | Slack Bot |
| Jira — Escalate | Jira |

### 5. hyperscaler_monitor.json
| Node | Credential |
|---|---|
| Fetch Hyperscaler Positions | Supabase |
| Fetch Hyperscaler Account Team Email | Supabase |
| Send Account Team Email | Email SMTP |
| Post to #procurement-cloud | Slack Bot |
| Daily MTD Summary | Slack Bot |

---

## Webhook URL for intake UI

After importing `intake_receiver.json`, activate it and copy the webhook URL.

It will look like:
```
http://localhost:5678/webhook/truespend-intake
```

This is already what `intake/vite.config.js` proxies to. No change needed for local dev.

For production, update `WEBHOOK_URL` in `.env` to your public n8n URL.

---

## Activate all workflows

In n8n, open each workflow and click the toggle to **Active**.

Schedule-based workflows (contract_watcher, reorder_trigger, hyperscaler_monitor)
will start running at their configured times.

The IMAP trigger (supplier_reply_handler) will start polling immediately on activation.

---

## Test the intake webhook

```bash
curl -X POST http://localhost:5678/webhook/truespend-intake \
  -H "Content-Type: application/json" \
  -d '{
    "type": "approve_purchase",
    "submitter_name": "Test User",
    "submitter_email": "test@company.com",
    "branch": "DACH",
    "supplier": "Dell",
    "description": "100x additional laptops for Q3 expansion",
    "amount": 120000,
    "currency": "EUR",
    "urgency": "normal"
  }'
```

Expected response within 2s:
```json
{ "reference": "TS-2026-XXXX", "status": "received" }
```

Then check Supabase → `tickets` table for the new row.

---

Next: **[Grafana Setup →](grafana_setup.md)**
