# TrueSpend — Setup Guide

> **The hard stop:** Everything below can be done without credentials until you hit a 🔑 marker.
> Those are the moments where you need an account or token.

---

## Architecture

```
Supabase (cloud)          ← database, RLS, all state
    ↑ ↓
n8n (local or cloud)      ← orchestration, all workflows
    ↑                     ← stakeholder intake form
Intake UI (React/Vite)
    ↓
Grafana (local or cloud)  ← dashboards, pulled from Supabase PostgreSQL
```

External integrations (all optional but recommended):
- **Slack** — one-touch decisions, alerts, daily digests
- **Jira** — escalation tickets with full brief
- **Email** (IMAP + SMTP) — supplier communication threading

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Docker Desktop | Latest | [docker.com](https://docker.com) |
| Node.js | 18+ | [nodejs.org](https://nodejs.org) |
| Git | Any | Already installed |

---

## Step-by-step setup

### 1. Clone + configure

```bash
git clone https://github.com/eugnmueller-87/TrueSpend.git
cd TrueSpend
cp .env.example .env
```

Open `.env` and fill in values as you complete each step below.

---

### 2. 🔑 Supabase — create project + run schema

**Credentials needed:** Supabase account (free)

→ Full guide: [docs/supabase_setup.md](docs/supabase_setup.md)

**TL;DR:**
1. Create project at supabase.com
2. Copy `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_DB_*` into `.env`
3. Run `db/schema.sql` in SQL Editor
4. Run seed files 01→07 in order

**Checkpoint:** `select count(*) from contracts;` returns 20.

---

### 3. Start local infrastructure

```bash
cd infra
docker compose up -d
```

This starts:
- **n8n** at http://localhost:5678
- **Grafana** at http://localhost:3000

Grafana auto-connects to Supabase using your `.env` values.

---

### 4. 🔑 n8n — configure credentials + import workflows

**Credentials needed:** Anthropic API key (required), Slack/Jira/Email (optional — workflows degrade gracefully)

→ Full guide: [docs/n8n_setup.md](docs/n8n_setup.md)

**TL;DR:**
1. Open http://localhost:5678 → create admin account
2. Add credentials (Settings → Credentials)
3. Import workflows in order: contract_watcher → intake_receiver → supplier_reply_handler → reorder_trigger → hyperscaler_monitor
4. Activate all workflows

**Minimum to get started:** Supabase + Anthropic API. Slack/Jira/Email can come later.

---

### 5. Grafana — verify dashboard

→ Full guide: [docs/grafana_setup.md](docs/grafana_setup.md)

1. Open http://localhost:3000
2. Login: admin / (your `GF_SECURITY_ADMIN_PASSWORD`)
3. Dashboard is auto-loaded: **TrueSpend Main**
4. Contracts Expiring panel should show 13 contracts from seed data

No credentials needed — Grafana reads from Supabase via direct PostgreSQL.

---

### 6. Intake UI — run locally

→ Full guide: [docs/intake_setup.md](docs/intake_setup.md)

```bash
cd intake
npm install
npm run dev
```

Open http://localhost:5173. Submit a test request. Check Supabase `tickets` table.

---

## Minimal viable setup (just Supabase + Anthropic)

If you want to see the agent reason without Slack/Jira/Email:

1. Complete Supabase setup ✓
2. Add only `ANTHROPIC_API_KEY` in n8n credentials ✓
3. Import `contract_watcher.json` and `intake_receiver.json` only ✓
4. Activate both workflows ✓
5. Submit a request via intake UI ✓
6. Watch `decisions` and `trace_log` tables populate in Supabase ✓

Slack/Jira nodes will error but n8n continues — the decision is always written to Supabase first.

---

## What needs credentials (summary)

| Thing | Required | What for |
|---|---|---|
| Supabase account | ✅ Yes | All state, every workflow reads/writes here |
| Anthropic API key | ✅ Yes | Claude reasoning — the brain of every workflow |
| Slack bot token | ⚡ Strongly recommended | One-touch approvals, daily digest, alerts |
| Jira API token | 🔶 Optional | Escalation tickets; can replace with Slack-only |
| Email (IMAP/SMTP) | 🔶 Optional | Supplier reply handler; skip if no shared mailbox |
| Docker | ✅ Yes (local) | Runs n8n + Grafana locally |
| Node.js 18+ | ✅ Yes | Intake UI |

---

## Folder structure

```
TrueSpend/
├── .env.example              ← copy to .env, fill in values
├── SETUP.md                  ← this file
├── ROADMAP.md                ← what we're building and why
├── STORY.md                  ← the philosophy
│
├── db/
│   ├── schema.sql            ← full Supabase schema (run first)
│   └── seed/
│       ├── 01_branches.sql
│       ├── 02_managers.sql
│       ├── 03_suppliers.sql
│       ├── 04_contracts.sql
│       ├── 05_contract_changes.sql
│       ├── 06_budget_positions.sql
│       └── 07_hyperscaler_positions.sql
│
├── workflows/
│   ├── automatic/
│   │   ├── contract_watcher.json       ← runs Mon-Fri 07:00
│   │   ├── reorder_trigger.json        ← runs every 6h
│   │   └── hyperscaler_monitor.json    ← runs weekdays 06:00
│   ├── stakeholder/
│   │   └── intake_receiver.json        ← webhook, always on
│   └── communication/
│       └── supplier_reply_handler.json ← IMAP trigger, always on
│
├── intake/                   ← React 18 + Vite stakeholder UI
│   ├── src/App.jsx
│   ├── vite.config.js
│   └── package.json
│
├── grafana/
│   └── dashboards/
│       └── truespend_main.json         ← 10-panel dashboard
│
├── infra/
│   ├── docker-compose.yml              ← n8n + Grafana
│   └── grafana/
│       └── provisioning/
│           ├── datasources/supabase.yml
│           └── dashboards/truespend.yml
│
├── docs/
│   ├── supabase_setup.md
│   ├── n8n_setup.md
│   ├── grafana_setup.md
│   └── intake_setup.md
│
└── content/
    └── linkedin/
        ├── post_01.md through post_06.md
```

---

## Troubleshooting

**n8n can't connect to Supabase**
→ Check `SUPABASE_URL` has no trailing slash
→ Confirm `SUPABASE_SERVICE_ROLE_KEY` is the `service_role` key, not `anon`

**Grafana "no data" on all panels**
→ Datasource connection failed. Go to Connections → Supabase PostgreSQL → Test
→ Confirm `SUPABASE_DB_HOST` and <REDACTED_ROTATE_ME> are correct
→ Supabase requires SSL — datasource config has `sslmode: require`

**Intake form returns 502**
→ n8n is not running or `intake_receiver` workflow is not activated
→ Check http://localhost:5678 is up

**Seed files fail with foreign key errors**
→ You ran them out of order. Drop all tables (`db/schema.sql` has `create` not `create if not exists`) and start from schema.sql again.

**Supplier reply handler not picking up emails**
→ For Gmail: use an App Password, not your account <REDACTED_ROTATE_ME>
→ Check IMAP is enabled in Gmail settings
→ Confirm IMAP node uses port 993 with SSL
