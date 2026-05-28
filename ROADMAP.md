# TrueSpend — Product Roadmap
**Last updated:** 2026-05-28  
**Status:** Core infrastructure + full P2I loop built. Ready for n8n wiring session.

---

## The Thesis

Procurement exists because someone had to manage trust and risk at the intersection of buyer and supplier, at volume, without good information.

The entire apparatus — the departments, the approvals, the scorecards, the taxonomies, the workflows — was built to compensate for the absence of good information and fast reasoning.

Information is now instant. Reasoning is now cheap.

The apparatus is no longer necessary.

TrueSpend doesn't automate procurement. It replaces the need for procurement as a processing function. What remains is the genuinely human layer: strategic supplier relationships, policy governance, and exception judgment. A smaller, senior function doing work that actually matters.

---

## The Three Questions Procurement Was Always For

Everything TrueSpend builds answers one of these:

1. **Should we buy this, from this supplier, on these terms?**
2. **Are our suppliers delivering what they promised?**
3. **What leverage do we have and how do we use it?**

Every feature that doesn't answer one of these three questions doesn't get built.

---

## What We Are Not Building

| Area | Decision | Why |
|------|----------|-----|
| Commodity taxonomy | Never | Agent categorizes from text. Taxonomy is optional enrichment, not infrastructure. |
| SRM workflows | Never | Replaced by AI-derived health signal from live data. |
| Complex supplier scorecards | Never | Three signals only: green / watch / red. |
| Multi-field onboarding forms | Never | 5 legal fields + agent due diligence. |
| CC approval chains | Never | One owner per decision. Full stop. |
| QBR templates | Never | Agent surfaces exceptions. You don't need a meeting to discuss what isn't broken. |
| Spend upload dashboards | Not here | That's SpendLens. Different product, different philosophy. |
| Line-item budget matching | Never | Wrong granularity — see Budget Architecture below. |

---

## The Reasoning Model

Every transaction the agent handles runs the same five-signal check simultaneously. Not sequentially. Not as a checklist. As a holistic judgment.

```
Signal 1 — Contract context
  Not just "does a contract exist" but: what are the actual terms,
  what is the pricing at this volume tier, are there conditions on this order type.

Signal 2 — Consumption context  
  What has this team already spent this period. Where does this purchase
  land them vs budget bucket. Does the spend pattern look normal or anomalous.

Signal 3 — Supplier context
  Is this vendor performing within SLA. Are there open disputes or quality flags.
  Is this the right supplier for this specific sub-category.

Signal 4 — Request context
  Is this a normal request for this requester. Does the quantity make sense.
  Does it match a known project or initiative.

Signal 5 — Policy context
  What is the delegated authority at this spend level. Are there holds or freezes.
  Does this category have special approval rules.
```

Output: confidence score + disposition.

```
High confidence, all signals green  →  Auto-execute. Close ticket. Log reasoning.
One signal uncertain               →  One-touch confirm. Show the uncertainty. One person decides.
Novel or high-risk                 →  Escalate. Full brief pre-written. Human adjudicates.
```

---

## Budget Architecture — The Right Granularity

### The question
Should the approval engine check: (a) the specific budget line for this tool or license, (b) the cost center total, or (c) the category budget bucket?

### The answer: budget bucket, with cost center as guardrail

**Why not line-item:**
- Line-item budgets require a matching budget plan that's maintained in real-time — the moment Controlling hasn't updated it, every approval blocks on stale data.
- They create false precision. A request for Figma seats doesn't stop being valid because the "design tools" line ran out — it's still within the Software/SaaS category and within the branch total.
- In practice, line-item matching creates a process overhead that procurement spends 40% of its time managing. That's what we're eliminating.

**Why not just cost center total:**
- Too loose. A cost center running 85% of annual budget in Q2 is a controlling signal regardless of whether any single request is large.
- Doesn't give the agent the right signal for category-level patterns (overspending on SaaS, underspending on hardware = license waste risk).

**The right model: three-tier budget check**

```
Tier 1 — Category bucket (primary signal)
  branch_id + category + period
  e.g. "DACH / saas_license / 2026-Q2"
  This is what the agent checks first.
  If available_budget >= request_amount → green signal.
  If available_budget < request_amount but within 10% → yellow (one-touch).
  If would exceed → red (escalate to manager + controlling).

Tier 2 — Branch annual total (guardrail)
  branches.annual_budget vs sum of committed + spent YTD
  Catches the case where category bucket looks fine but branch is running hot overall.
  Agent runs this silently on every approval and notes in trace if > 80% consumed.

Tier 3 — Manager spend authority (delegation control)
  users.spend_authority
  If request_amount > spend_authority of the assigned manager → auto-escalate.
  This is the only hard block. Everything else is a signal.
```

**P2I flow with this model:**

```
Request arrives
    ↓
Agent reads: branch, category, amount, requester, supplier
    ↓
Budget check (Tier 1): category bucket available?
    ↓
Branch check (Tier 2): branch YTD headroom > 80%?
    ↓
Authority check (Tier 3): within manager's delegation?
    ↓
All green + contract exists + supplier healthy → auto_execute
One yellow → one_touch ticket on Operations Board
Hard block or ≥€100k → escalate → Jira PROC ticket
```

**What Controlling sees:**
- Every approval logged with budget position at time of approval
- `budget_positions` table updated on every approved spend (committed column)
- Period-end reports: budget consumed vs planned, by branch + category
- No manual reconciliation — every decision is the record

---

## P2I — Purchase to Invoice Automation

```
Purchase Request  →  Budget approval  →  PO creation  →  Goods receipt  →  Invoice matching  →  Payment release
```

TrueSpend owns the full cycle. ERP receives the payment instruction and posts it.

---

## Phase Map

---

### ✅ PHASE 0 — Core Infrastructure
> **Status: Complete**

#### Database
- [x] Schema: branches, suppliers, contracts, tickets, decisions, trace_log, budget_positions, supplier_emails, hyperscaler_positions — 28 tables total
- [x] Compliance extensions: legal_documents, compliance_checks
- [x] P2I tables: purchase_orders, invoices, payment_instructions, erp_sync_queue, po_sequences
- [x] Budget tables: budget_buckets, budget_pools, budget_reallocations
- [x] License tables: license_entitlements, license_assignments
- [x] Asset tables: assets, asset_depreciation_log
- [x] LLM tables: llm_api_keys, llm_consumption
- [x] Monitoring: workflow_runs
- [x] Views (8): contracts_expiring, weekly_digest, agent_performance, open_tickets_board, supplier_compliance_summary, budget_utilization, commitment_register, approval_audit_trail
- [x] Atomic budget functions: commit_budget(), release_budget(), record_spend()
- [x] P2I functions: next_po_number(), approve_and_commit(), confirm_delivery(), match_invoice(), create_payment_instruction()
- [x] Indexes: covering index on budget_positions, partial index on tickets, category index
- [x] RLS policies (15 tables)
- [x] Templates: NDA (mutual, German law), DPA (Art. 28 GDPR with TOM annex)

#### Workflows (7, all Slack-free)
- [x] `intake_receiver` — intake → 5-signal Claude → approve_and_commit RPC → PO email → trace
- [x] `supplier_reply_handler` — IMAP → Claude → reply or route to board
- [x] `contract_watcher` — daily → expiry check → auto-renew or reason
- [x] `reorder_trigger` — daily → reorder candidates → place or escalate
- [x] `hyperscaler_monitor` — daily → cloud spend → anomaly detection
- [x] `supplier_onboarding` — webhook → 4 parallel compliance agents → docs + ticket
- [x] `invoice_processor` — IMAP invoices → Claude parse → 3-way match → payment instruction → ERP queue

#### Operations Board (React + Vite + Tailwind)
- [x] Two-tab UI: Submit Request + Operations Board
- [x] Board fetches open_tickets_board directly from PostgREST
- [x] Auto-refresh 30s
- [x] Approve / Reject / Sign / Acknowledge via PATCH
- [x] Confirm Delivery button (triggers confirm_delivery RPC)
- [x] PO number display on approved tickets
- [x] Awaiting Delivery section

#### Stability
- [x] All 9 Claude nodes: 120s timeout, 3× retry (2s backoff)
- [x] All 45 PostgREST write nodes: 30s timeout, 3× retry (1s backoff)
- [x] Race condition fix: atomic PostgreSQL functions for all budget operations
- [x] Correlated subquery fix: tickets.category denormalized column
- [x] workflow_runs table for Grafana health dashboards

#### Seeds (8 files, load in order)
- [x] 01 — branches (10), cost_centers
- [x] 02 — users (roles, spend authority)
- [x] 03 — suppliers (20+)
- [x] 04 — contracts (active, expiring, manual_required)
- [x] 05 — hyperscaler_positions + llm_api_keys
- [x] 06 — budget_positions (running ledger, incl. over-committed scenarios)
- [x] 07 — tickets + trace_log (simulation scenarios)
- [x] 08 — budget_buckets + po_sequences + trust_settings

---

### ✅ PHASE A — Budget & Controlling Layer
> **Status: Built — ready to wire in n8n**

- [x] `budget_buckets` table — annual plan per branch × category × fiscal year × quarter
- [x] `budget_pools` — CFO-held unallocated reserves per branch
- [x] `budget_reallocations` — immutable audit trail of every budget move
- [x] Three-tier budget check in intake_receiver (bucket → branch → authority)
- [x] `commit_budget()` — atomic lock + increment (called inside approve_and_commit)
- [x] `release_budget()` — atomic lock + decrement (rejection/cancellation path)
- [x] `record_spend()` — releases committed, increments spent (invoice approved)
- [x] `budget_utilization` view — bucket × period: plan / committed / spent / available / % consumed
- [x] `commitment_register` view — open POs not yet invoiced (accrual list)
- [x] `approval_audit_trail` view — immutable log with budget state snapshot
- [x] `trust_settings` table — per-branch + per-category autonomy thresholds
- [x] Seed 08: budget_buckets (10 branches × categories), po_sequences, trust_settings defaults

---

### ✅ PHASE B — P2I Full Loop
> **Status: Built — ready to wire in n8n**

- [x] `purchase_orders` table — PO lifecycle: draft → sent → acknowledged → delivered → invoiced → closed
- [x] `po_sequences` table — branch × year counters for gap-free PO numbering
- [x] `invoices` table — received → matched → disputed → approved → paid
- [x] `payment_instructions` table — PI record per approved invoice
- [x] `erp_sync_queue` table — ERP-agnostic output queue (pending → syncing → synced/failed/skipped)
- [x] `next_po_number()` — atomic, gap-free: PO-2026-DACH-0042 format
- [x] `approve_and_commit()` — single RPC: PO number + budget commit + purchase_orders insert + ticket update
- [x] `confirm_delivery()` — marks delivered, checks SLA, flags supplier health if late
- [x] `match_invoice()` — 3-way match (invoice vs PO vs receipt), ±2% tolerance
- [x] `create_payment_instruction()` — creates PI + erp_sync_queue entry + calls record_spend()
- [x] `invoice_processor.json` — full IMAP → Claude parse → match → payment loop (7th workflow)
- [x] intake_receiver: approve_and_commit RPC on auto_execute path + PO email to supplier
- [x] Operations Board: Confirm Delivery button, PO number display, Awaiting Delivery section

---

### 🔲 PHASE C — Production Deployment & Setup Wizard
> **Priority: High — required before any customer install | Effort: ~1 week**

Current state: installation requires ~100 manual steps across Railway, n8n UI, and terminal. Not repeatable, not auditable, not production-ready.

**Setup wizard (`setup.sh`)**
- [ ] Interactive CLI: prompts for Anthropic key, email (IMAP/SMTP), Jira config, domain name, admin passwords
- [ ] Auto-generates `N8N_ENCRYPTION_KEY` and `POSTGREST_JWT_SECRET` (openssl) — no manual key generation
- [ ] Auto-generates signed `POSTGREST_JWT` (HS256) from secret — no manual JWT encoding
- [ ] Writes `.env` from template — operator never edits a config file manually
- [ ] Runs schema migrations + seeds against local PostgreSQL
- [ ] Health check: connects to each service, verifies all 8 key tables + 7 RPC functions exist
- [ ] Prints per-component status summary (✅/❌) before exiting
- [ ] `--migrate-only` flag for upgrades: applies only new migration files, skips wizard prompts

**Full self-contained `docker-compose.yml`**
- [ ] All 5 services in one file: postgres + postgrest + n8n + grafana + intake
- [ ] Remove dead vars: `SUPABASE_*`, `SLACK_BOT_TOKEN` (neither used in current stack)
- [ ] PostgREST config via `infra/postgrest/postgrest.conf` (not env-var-only)
- [ ] Intake nginx: runtime env injection via `envsubst` so `POSTGREST_JWT` doesn't need to be a build-time Vite var

**n8n provisioning files (zero UI clicking)**
- [ ] `infra/n8n/credentials/anthropic.json` — credential template, secret from `${ANTHROPIC_API_KEY}`
- [ ] `infra/n8n/credentials/postgrest_header_auth.json` — JWT from `${POSTGREST_JWT}`
- [ ] `infra/n8n/credentials/imap_main.json` + `imap_invoices.json` — two mailboxes
- [ ] `infra/n8n/credentials/smtp.json`
- [ ] `infra/n8n/credentials/jira.json` (optional, skipped if not configured)
- [ ] All 7 workflow JSONs reference credentials by name (not ID) — provisioning files and workflows agree at startup
- [ ] n8n auto-imports workflows from mounted `infra/n8n/workflows/` on startup — zero manual imports

**Versioned migrations (replace single schema dump)**
- [ ] `infra/migrations/001_initial_schema.sql`
- [ ] `infra/migrations/002_p2i_tables.sql`
- [ ] `infra/migrations/003_stability_indexes.sql`
- [ ] `infra/migrations/004_atomic_functions.sql`
- [ ] `schema_migrations` tracking table — idempotent re-runs, rollback-safe, ordered
- [ ] Migration runner in setup.sh applies only unapplied files

**Railway one-click option (for PaaS deployments)**
- [ ] `railway.toml` defining all 5 services with correct env var linking between services
- [ ] "Deploy to Railway" button in README

**Quality gate updates**
- [ ] Add `invoice_processor.json` + `supplier_onboarding.json` to JSON validity checks
- [ ] Check provisioning credential files exist and contain no hardcoded secrets
- [ ] Check migration files are sequentially numbered with no gaps

---

### 🔲 PHASE D — Controlling Intelligence
> **Priority: Medium | Effort: ~1 week**

- [ ] `budget_forecast.json` workflow — weekly run, agent projects year-end per bucket
- [ ] Underspend alert: if projection < 85% of budget by Q3 → alert on board (use-it-or-lose-it)
- [ ] Overrun alert: if projection > budget → alert + draft reallocation proposal
- [ ] Accruals automation: commitment_register CSV export + agent-generated journal entry suggestions
- [ ] Budget variance report: monthly, plan vs actual vs committed by branch × category with narrative
- [ ] Budget reallocation workflow: CFO submits on board → agent checks source slack → auto-approve (intra-branch) or escalate (cross-branch)
- [ ] `budget_reallocations` audit trail populated from reallocation workflow
- [ ] Controlling tab on Operations Board: budget utilization heat map

---

### 🔲 PHASE E — ERP Integration
> **Priority: Medium — client-specific | Effort: 2–3 weeks per ERP**

**Supported targets (priority order):**
1. [ ] SAP S/4HANA — BAPI/RFC or OData API
2. [ ] Oracle Fusion — REST API
3. [ ] Coupa — REST API (procurement-native, easiest)
4. [ ] NetSuite — REST API
5. [ ] Dynamics 365 — REST API

**Push to ERP:**
- [ ] Approved POs → create PO in ERP
- [ ] Matched invoices → release for payment in ERP
- [ ] New suppliers → create vendor master in ERP
- [ ] Budget consumption → update cost center actual in ERP

**Pull from ERP:**
- [ ] Payment confirmation → close PO in TrueSpend
- [ ] GL account mapping → map category to cost element
- [ ] Cost center hierarchy → validate branch/CC mapping

> **Philosophy:** TrueSpend is the reasoning layer. ERP is the book of record. Push decisions in, pull confirmations back. Never replicate ERP data structures.

---

### 🔲 PHASE F — Accounting & Month-End
> **Priority: Medium | Effort: ~1 week**

```
Day 1–28:   Every approved PO commits budget in real-time
Day 28:     Controlling exports commitment register (open accruals)
Day 30:     All matched invoices flagged as "ready to post"
Day 31:     Agent generates period summary — spend vs budget vs forecast
            Exceptions highlighted: unmatched invoices, undelivered POs,
            overrun budget lines, unresolved supplier disputes
```

- [ ] Period-end report workflow: auto-generated on last day of month
- [ ] Journal entry preparation: suggested GL entries per open PO (amount / CC / description / doc ref)
- [ ] VAT handling: extract from invoice, flag reverse charge (cross-border services), note applicable rate
- [ ] Month-end close checklist: board view showing outstanding items blocking close

---

### 🔲 PHASE G — Compliance Hardening
> **Priority: Medium | Effort: ~1 week**

**Current state:** Supplier onboarding compliance workflow built (NDA/DPA/InfoSec/LkSG agents). Schema extended. Templates ready.

- [ ] NDA/DPA e-signature integration (DocuSign or HelloSign API — currently simulation)
- [ ] Automated compliance expiry tracking: DPA expires with contract, NDA tracks term
- [ ] LkSG annual re-certification workflow: trigger on contract anniversary
- [ ] Compliance dashboard on Operations Board: supplier × doc status matrix
- [ ] GDPR: data subject request workflow via intake → routes to correct processor
- [ ] GDPR: breach notification timer — 48h clock, auto-escalate at 44h
- [ ] GDPR: processing register auto-maintained from supplier DPA data

---

### 🔲 PHASE H — Hyperscaler FinOps Intelligence
> **Priority: Low — builds on existing monitor | Effort: ~1 week**

**Current state:** Daily monitor built. Anomaly detection working. Slack-free.

- [ ] Reservation optimization agent: weekly evaluation of reservations approaching expiry
- [ ] Commitment amendment workflow: agent drafts amendment request when EDP/CUD needs adjustment
- [ ] Cross-cloud arbitrage: cost differential notes when workload is portable
- [ ] RI/SP coverage dashboard on Operations Board: utilization by provider × account
- [ ] Cost allocation: map hyperscaler spend to branch/cost center (currently unlinked)

---

### 🔲 PHASE I — Trust Expansion Engine
> **Priority: Low — go-live first | Effort: ~1 week**

```
Week 1–4:   Threshold €10k. Human reviews sample weekly.
Week 5–8:   Show the log. X transactions, Y auto-closed, Z errors.
Month 3:    Threshold moves to €50k.
Month 6:    Threshold moves to €250k.
Month 12:   Agent handles 80%+ of volume autonomously.
```

- [ ] Accuracy tracking: every auto_execute decision flagged if later reversed by human
- [ ] Weekly accuracy report: auto-generated, shows confidence vs outcome correlation
- [ ] Threshold change request: submitted by Controlling/CPO on board, agent executes
- [ ] `trust_settings` review workflow: monthly, compares current thresholds vs accuracy data
- [ ] Autonomy audit log: immutable record of every threshold change with rationale

---

## Go-Live Checklist

### Before first use (current — manual, pre-Phase C)
- [ ] Apply schema to Railway PostgreSQL: `psql $DATABASE_URL -f db/schema.sql`
- [ ] Apply all seeds in order: `for f in db/seed/0*.sql; do psql $DATABASE_URL -f $f; done`
- [ ] Import all 7 workflows to n8n (delete old, import new JSONs)
- [ ] Assign "Authorization-TrueSpend" Header Auth to all PostgREST nodes (~45 nodes)
- [ ] Assign Anthropic credential to all Claude nodes (~9 nodes)
- [ ] Set `VITE_POSTGREST_URL` + `VITE_POSTGREST_JWT` on Railway intake service
- [ ] Point `invoice_processor` IMAP trigger at `invoices` mailbox (separate from INBOX)

### Before first use (post-Phase C — wizard handles the above)
- [ ] `git clone` + `bash setup.sh` — wizard prompts for API keys, generates secrets, applies migrations, health-checks the stack
- [ ] `docker compose up -d` — all 5 services start, n8n auto-imports workflows and credentials

### Before P2I goes live
- [ ] Budget buckets confirmed by Controlling (annual plan → quarterly buckets in seed 08)
- [ ] Manager spend authority matrix confirmed in `users.spend_authority`
- [ ] Invoice matching tolerance agreed (±2% default, configurable in match_invoice())
- [ ] PO email template reviewed (plain text, sent to supplier.contact_email)

### Before ERP integration (Phase D)
- [ ] ERP system confirmed (SAP/Oracle/Coupa/other)
- [ ] API credentials provisioned
- [ ] GL account mapping: TrueSpend spend_category → ERP cost element
- [ ] Cost center mapping: TrueSpend branch → ERP CC

---

## Known Issues

### Open
- **H3** — RLS policies: 15 of 28 tables explicitly covered. `trace_log`, `supplier_emails`, `branches`, `hyperscaler_positions`, `contract_changes` covered by `app_role_all` pattern but not individually enumerated. Low priority — not blocking go-live.

### Fixed (2026-05-27)
- **H1** ✓ — `hyperscaler_monitor.json` check_flags already used correct field names (`projected_eur`, `committed_eur`, `reservation_util`)
- **H2** ✓ — `order_reference` column added to `supplier_emails`
- **H4** ✓ — `contracts_expiring` view uses `>=` (catches same-day expiries)
- **M1** ✓ — `manual_required` contracts now route through Claude reasoning before Jira
- **M2** ✓ — `supplier_reply_handler.json` urgency routing: critical→Jira+trace, high/medium/low→trace only
- **M3** ✓ — `intake_receiver.json` writes 5 separate trace_log rows (bulk POST array)
- **M4** ✓ — branch_id sends UUIDs not display names
- **M5** ✓ — `reorder_trigger.json` uses `renewal_state` not `status`
- **L1** ✓ — auto-renew creates a ticket row first; decision has ticket_id FK
- **L2** ✓ — `hyperscaler_monitor.json` trace signal is `consumption`
- **managers→users** ✓ — all workflow references to `/managers` updated to `/users`
- **Slack** ✓ — zero Slack nodes in all 7 workflows

---

## International Scale

Reasoning scales better than rules.

A rule-based system needs a rule for every jurisdiction. A reasoning system handles Germany, Singapore, and Brazil with the same agent. It understands that a Handelsregister number means something different from a Companies House number. It knows GDPR applies here and PDPA there.

**What this means:**
- Jurisdiction-aware reasoning in all agent prompts from day one
- Multilingual supplier communication (German first, then FR/ES/PT)
- ERP integration via API — TrueSpend sits on top, doesn't replace
- No country-specific configuration matrices

---

## The Moat

Not the technology. The technology is available to everyone.

**The reasoning trace corpus.** Every decision TrueSpend makes, logged with full reasoning. After 12 months across multiple enterprise clients, the most comprehensive dataset of procurement reasoning in existence.

**The calibration knowledge.** What confidence threshold works for what transaction type, in what industry, in what jurisdiction.

**The change management playbook.** How to land this in a large enterprise without the organizational immune system killing it.

---

## What Remains Human

| Role | What it becomes |
|------|----------------|
| Procurement Ops | Disappears. The processing was the job. The processing is gone. |
| Procurement Excellence | System governance. Policy ownership. Threshold management. |
| Strategic Procurement | Two conversations a year with Dell. Fully prepared. Completely focused. |
| Controlling | Shifts from reconciliation to governance. They set the policy, agent enforces it. |
| Accounting | Month-end inputs pre-prepared. Review and post, not extract and calculate. |
