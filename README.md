# TRUESPEND — The Fall of Procurement

![TrueSpend](screenshots/hero.png)

<p align="center">
  <img src="https://img.shields.io/badge/status-live%20on%20Railway-brightgreen?style=flat-square" alt="Status" />
  <img src="https://img.shields.io/badge/AI-Claude%20Sonnet%204.6-5A67D8?style=flat-square&logo=anthropic&logoColor=white" alt="Claude" />
  <img src="https://img.shields.io/badge/orchestration-n8n-EA4B71?style=flat-square&logo=n8n&logoColor=white" alt="n8n" />
  <img src="https://img.shields.io/badge/database-PostgreSQL-4169E1?style=flat-square&logo=postgresql&logoColor=white" alt="PostgreSQL" />
  <img src="https://img.shields.io/badge/frontend-React%20%2B%20Vite-61DAFB?style=flat-square&logo=react&logoColor=black" alt="React" />
  <img src="https://img.shields.io/badge/deploy-Railway-0B0D0E?style=flat-square&logo=railway&logoColor=white" alt="Railway" />
  <img src="https://img.shields.io/badge/quality%20gate-20%2F20-success?style=flat-square" alt="Quality Gate" />
</p>

<p align="center">
  <strong>Procurement doesn't need to be faster. It needs to not exist.</strong>
</p>

---

TrueSpend is an agentic procurement operating system. It reasons across contracts, consumption, supplier health, request patterns, and policy — and closes transactions without human touch. The humans in the loop focus on the strategic supplier relationships where judgment actually matters.

> *"Three things need you this week. Everything else, the agent closed."*

---

## What's Running

| Service | URL | Purpose |
|---|---|---|
| n8n | [n8n-n3xl.eugenmueller.tech](https://n8n-n3xl.eugenmueller.tech) | Workflow orchestration |
| Grafana | [grafana-production-49fc.up.railway.app](https://grafana-production-49fc.up.railway.app) | Live dashboard |
| PostgREST | [postgrest-production-7960.up.railway.app](https://postgrest-production-7960.up.railway.app) | REST API over PostgreSQL |
| PostgreSQL | `zephyr.proxy.rlwy.net:24934` | Primary database (Railway) |

---

## What It Does

### Contract Renewal Engine
Watches every contract expiry across all branches. Runs every weekday at 07:00. Routes each contract by its renewal state:

- **Clean + auto-renew** → executes automatically, logs decision, notifies owner
- **Price increase / volume change / scope change** → Claude reasons across contract terms, budget position, and market rate. Produces a disposition: auto-execute, one-touch Slack confirm, or Jira escalation with full brief
- **Manual required** → escalates immediately with agent brief

Renewal timeline the agent tracks silently:
```
18 months  →  consumption tracking begins
12 months  →  owner notified
 6 months  →  full renewal brief produced
 3 months  →  human-led negotiation, agent provides live data
```

### Stakeholder Intake
React + Vite form deployed on Railway. Every procurement request — renew, purchase, onboard, other — hits a webhook and goes through the five-signal reasoning loop:

| Signal | What the agent reads |
|---|---|
| Contract | Existing terms, volume tiers, pricing, notice clauses |
| Consumption | MTD spend vs budget, spend pattern, anomalies |
| Supplier | Health status, SLA performance, open disputes |
| Request | Requester history, quantity, known project match |
| Policy | Delegated authority, category holds, approval rules |

Output: `auto_execute` → closed silently · `one_touch` → Slack block to manager · `escalate` → Jira ticket with full brief

### Hyperscaler Monitoring
Runs every weekday at 06:00. Reads daily positions for AWS, GCP, and Azure. Flags:
- Overshoot risk (projected > committed)
- Undershoot waste (projected < 80% of committed)
- Idle resources (> €5k)
- Low reservation utilisation (< 75%)

For each anomaly: Claude reasons, drafts a communication to the account team, posts to `#procurement-cloud`. Daily summary to `#procurement-ops`.

### Automatic Reorder
Runs every 6 hours. Detects when hardware or SaaS volume needs replenishing against existing framework contracts. If all signals green → places order via supplier email automatically. One signal uncertain → Slack confirm. Above threshold → Jira.

### Supplier Reply Handler
Catches all inbound supplier emails. Agent reads, reasons against open tickets + email history + active contracts, and either replies directly or routes to a human with a complete draft. The human never starts from scratch.

---

## Architecture

```
TrueSpend (Railway)
│
├── PostgreSQL                    ← contracts, tickets, decisions, trace_log
├── PostgREST                     ← REST API over the database
├── n8n                           ← all workflow orchestration
│   ├── workflows/automatic/      ← contract_watcher, reorder_trigger, hyperscaler_monitor
│   ├── workflows/stakeholder/    ← intake_receiver
│   └── workflows/communication/  ← supplier_reply_handler
├── intake/ (React + Vite)        ← stakeholder submission UI → nginx → Railway
└── grafana/                      ← live dashboards connected to PostgreSQL
```

**Every agent call returns:**
```json
{
  "disposition": "auto_execute | one_touch | escalate",
  "confidence": 0.00–1.00,
  "reasoning": "full chain of thought",
  "recommendation": "what to do",
  "brief": "pre-written for humans"
}
```

Every decision is stored in `decisions` + `trace_log` — the audit trail is the agent's thought process.

---

## Database

30 contracts · 10 branches · 17 suppliers · 5 managers — full simulation seed loaded.

Key tables: `contracts` · `suppliers` · `branches` · `managers` · `tickets` · `decisions` · `trace_log` · `budget_positions` · `hyperscaler_positions` · `supplier_emails` · `contract_changes`

Key views: `contracts_expiring` · `weekly_digest` · `agent_performance`

---

## Trust-Building Mechanism

The agent earns its own authority expansion through demonstrated accuracy — not promises.

```
Week 1–4    transactions under €10k · 95%+ confidence threshold · every decision logged
Month 2     show the numbers: X closed, Y escalated, Z errors
Month 3     threshold moves to €50k — based on evidence
Month 6     €250k
Month 12    80%+ of volume handled autonomously
```

---

## Quality Gate

Run before every push:

```bash
bash scripts/quality-gate.sh
```

20 checks: JSON validity · schema field audit · workflow filter correctness · signal enum values · branch UUID integrity · `.env.example` coverage · Vite build.

---

## Local Setup

```bash
# 1. Clone and configure
cp .env.example .env
# fill in ANTHROPIC_API_KEY, SUPABASE_*, SLACK_*, JIRA_*, IMAP/SMTP

# 2. Start n8n + Grafana
cd infra && docker compose up -d

# 3. Apply schema + seed data (run in Supabase SQL editor or psql)
psql $DATABASE_URL < db/schema.sql
psql $DATABASE_URL < db/seed/01_branches.sql
# ... 02 through 07

# 4. Import workflows into n8n
# n8n UI → Workflows → Import from file → select each JSON under workflows/

# 5. Run the intake UI locally
cd intake && npm install && npm run dev
# Proxies /api/intake → localhost:5678/webhook/truespend-intake
```

---

## What We Are Not Building

| Area | Decision |
|---|---|
| Commodity taxonomy | Agent categorizes from text. Taxonomy is optional enrichment, not infrastructure. |
| SRM workflows | Replaced by AI-derived health signal. You don't schedule attention. |
| Complex supplier scorecards | Three signals: green / watch / red. |
| 47-field onboarding forms | Five legal fields + agent due diligence. |
| CC approval chains | One owner per decision. Full stop. |
| QBR templates | Agent surfaces exceptions. You don't meet about what isn't broken. |

---

## Principles

- Every feature answers one of three questions: *Should we buy this? Are suppliers delivering? What leverage do we have?*
- Nothing gets built that doesn't change a human action
- One owner per decision — no CC chains, no committees
- The audit trail is the agent's thought process
- The agent earns its own authority expansion through demonstrated accuracy

---

## Further Reading

- [ROADMAP.md](ROADMAP.md) — full build plan, phase by phase
- [STORY.md](STORY.md) — the thinking behind the product, the IONOS conversation, what we killed and why
