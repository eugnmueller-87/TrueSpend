# TrueSpend — Product Roadmap
**Last updated:** 2026-05-27  
**Status:** Core infrastructure built. P2I and controlling layer next.

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
  managers.spend_authority
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

**What this means for the schema:**
- `budget_positions` already exists with the right structure (branch, period, category, budget, committed, spent, available)
- Need to add: `budget_buckets` table — annual plan broken into Q buckets per category per branch, owned by Controlling
- Need to add: `fiscal_year_plan` — Controlling uploads once, agent reads all year
- Need to add: `spend_authority_matrix` — maps org level to EUR threshold (already partially in `managers.spend_authority`)

---

## P2I — Purchase to Invoice Automation

**What P2I means in TrueSpend context:**

```
Purchase Request  →  Budget approval  →  PO creation  →  Goods receipt  →  Invoice matching  →  Payment release
```

TrueSpend owns the first three steps fully. The last two connect to ERP (SAP/Oracle/Coupa) via API.

**P2I workflow design:**

### Step 1 — Purchase Request (already built: intake_receiver)
Stakeholder submits via Operations Board form. Agent enriches with supplier, contract, and budget context.

### Step 2 — Budget Pre-Approval (to build)
Agent checks all three budget tiers. Writes approval decision to `decisions` table with budget snapshot at time of decision. Updates `budget_positions.committed` immediately on approval.

This is critical: **committed must move at approval, not at invoice.** Controlling needs to know what's encumbered before the spend happens.

### Step 3 — PO Generation (to build — simulation first, ERP later)
On auto_execute: agent generates PO reference, logs to `purchase_orders` table (new), sends order to supplier via email (already built in reorder workflow). PO reference tied to ticket, contract, and budget position.

### Step 4 — Goods Receipt / Service Confirmation (to build)
Stakeholder confirms receipt on Operations Board (simple button: "Confirm delivery"). Agent updates PO status. If SLA breach detected (delivery overdue), supplier health flagged.

### Step 5 — Invoice Matching (to build — 3-way match)
When invoice arrives (email):
- Match to PO reference (amount, supplier, line items)
- Match to goods receipt confirmation
- If all three match within tolerance → release to ERP for payment
- If mismatch → one-touch ticket with discrepancy highlighted

### Step 6 — Payment Release (ERP handoff)
TrueSpend creates payment instruction record. ERP picks up via API. TrueSpend does not hold payment data — it creates the instruction and closes the loop.

---

## What Controlling Gets

Controlling has historically been reactive — they see what was spent after the fact. TrueSpend makes them prospective:

| What they have today | What TrueSpend gives them |
|----------------------|---------------------------|
| Month-end spend reports | Real-time committed + spent by bucket |
| Manual budget tracking in Excel | `budget_positions` updated on every approval |
| Quarterly forecast based on guesswork | Agent-projected spend based on contract renewal pipeline |
| Surprise invoices | 3-way match with automatic flag before payment |
| Year-end budget rush | Underspend alerts in Q3 (preventing license waste) |
| Manual accruals process | PO table gives Controlling accrual basis automatically |

**Controlling-specific views to build:**
- `controlling_dashboard` — branch × category × period heat map. Green/amber/red.
- `commitment_register` — all approved, uncommitted POs. The accrual list.
- `budget_variance_report` — plan vs actual vs committed, per bucket, per period.
- `approval_audit_trail` — every decision, who took it (agent or human), budget state at time of decision. Immutable.

---

## The Full Build — Phase Map

### ✅ DONE — Core Infrastructure

**Database**
- Schema: branches, suppliers, contracts, tickets, decisions, trace_log, budget_positions, supplier_emails, hyperscaler_positions
- Compliance extensions: legal_documents, compliance_checks, ALTER TABLE suppliers + tickets
- Views: contracts_expiring, weekly_digest, agent_performance, open_tickets_board, supplier_compliance_summary
- Templates: NDA (mutual, German law), DPA (Art. 28 GDPR)

**Workflows (6, all Slack-free)**
- `intake_receiver` — intake → Claude → auto/one-touch/escalate
- `supplier_reply_handler` — IMAP → Claude → reply or route to board
- `contract_watcher` — daily → expiry check → auto-renew or reason
- `reorder_trigger` — daily → reorder candidates → place or escalate
- `hyperscaler_monitor` — daily → cloud spend → anomaly detection
- `supplier_onboarding` — webhook → 4 parallel agents → compliance docs

**Operations Board (React)**
- Two-tab UI: Submit Request + Operations Board
- Board fetches open_tickets_board directly from PostgREST
- Auto-refresh 30s, Approve/Reject/Sign/Acknowledge via PATCH
- No Slack anywhere

**Authentication**
- PostgREST JWT generated (HS256, role=truespend, 10yr expiry)
- n8n Header Auth credential: "Authorization-TrueSpend"

---

### ✅ PHASE A — Budget & Controlling Layer
**Status: Built — ready to wire in n8n**

**Schema additions:**
- `budget_buckets` table — annual budget plan per branch × category × fiscal year, maintained by Controlling. This is the source of truth for budget authority.
- `fiscal_years` table — fiscal year definition (not always Jan–Dec), owned by Controlling
- `purchase_orders` table — PO number, ticket_id, supplier_id, contract_id, amount, currency, status (draft/sent/acknowledged/delivered/invoiced/closed), po_date, expected_delivery
- `invoices` table — supplier_id, po_id, invoice_number, invoice_date, amount, currency, status (received/matched/disputed/approved/paid), match_result

**Budget check workflow additions:**
- Budget pre-check node in `intake_receiver`: query `budget_buckets` for branch × category × current quarter
- Three-tier evaluation: bucket available → branch headroom → manager authority
- On approval: PATCH `budget_buckets.committed += amount`
- On rejection/closed: PATCH `budget_buckets.committed -= amount` (release)

**Controlling views:**
- `budget_utilization` — bucket × period: plan / committed / spent / available / % consumed
- `commitment_register` — all open POs not yet invoiced (accrual list for Controlling)
- `approval_audit_trail` — immutable log of every approval decision with budget state snapshot

**Operations Board additions:**
- Controlling tab (read-only): budget utilization heat map per branch × category
- Commitment register: open POs pending delivery/invoice

---

### ✅ PHASE B — P2I Full Loop
**Status: Built — ready to wire in n8n**

**PO Generation:**
- On `auto_execute`: agent generates PO (reference format: PO-{year}-{branch_code}-{seq}), creates `purchase_orders` row, sends order email to supplier (extend existing email workflow)
- On `one_touch` approval: same, triggered by Approve button on board
- PO template: plain text, legally sufficient, includes: TrueSpend entity, supplier legal name, contract reference, line items, delivery address, payment terms

**Goods Receipt:**
- Stakeholder clicks "Confirm Delivery" on Operations Board ticket
- Agent checks: delivery within SLA? If late → flag supplier health
- PO status → `delivered`, triggers invoice matching readiness

**Invoice Matching (3-way):**
- New workflow: `invoice_processor.json`
- IMAP polls for invoices (PDF attachments from known supplier emails)
- Claude reads invoice PDF (extract: supplier, amount, PO reference, line items, VAT)
- 3-way match: invoice vs PO vs goods receipt
- Match tolerance: ±2% or €50 (configurable)
- On match: PATCH invoice status → `approved`, create payment instruction record
- On mismatch: one-touch ticket with discrepancy highlighted on board

**ERP Handoff (stub → real):**
- `payment_instructions` table: amount, supplier bank details reference, invoice_id, po_id, instruction_date, status
- Phase B: stub (record created, manual ERP entry)
- Phase C: REST API call to SAP/Oracle/Coupa

---

### 🔲 PHASE C — Controlling Intelligence
**Priority: Medium**  
**Effort: 1 week**

**Budget forecasting:**
- New workflow: `budget_forecast.json` — weekly run
- Agent reads: YTD spend by bucket, open POs (committed), contract renewal pipeline (coming spend), reorder patterns
- Produces: projected year-end spend per bucket vs budget
- If projection > budget: alert on Operations Board (Controlling view)
- If projection < 85% of budget by Q3: underspend alert (use-it-or-lose-it warning, or reallocation opportunity)

**Accruals automation:**
- Controlling can export `commitment_register` as CSV (period-end)
- Agent generates accrual entries: for every open PO with no invoice, accrue expected amount
- This is the input to the month-end close process

**Budget variance report:**
- Monthly auto-generation: plan vs actual vs committed, by branch × category
- Agent writes narrative: "DACH SaaS is 73% consumed in Q2 with 6 renewals pending — projected overrun of €45k in Q3. Recommend reallocation from underspent Facilities bucket."

**Budget reallocation workflow:**
- CFO/Controlling submits reallocation request via Operations Board
- Agent checks: does source bucket have sufficient slack? Does receiving bucket make sense given pipeline?
- Auto-approves if pure reallocation within branch. Escalates if cross-branch.

---

### 🔲 PHASE D — ERP Integration
**Priority: Medium — client-specific**  
**Effort: 2–3 weeks per ERP**

**Supported targets (in priority order):**
1. SAP S/4HANA — BAPI/RFC or OData API
2. Oracle Fusion — REST API
3. Coupa — REST API (procurement-native, easiest)
4. NetSuite — REST API
5. Dynamics 365 — REST API

**What TrueSpend pushes to ERP:**
- Approved purchase orders → create PO in ERP
- Matched invoices → release for payment in ERP
- New supplier → create vendor master in ERP
- Budget consumption → update cost center actual in ERP

**What TrueSpend pulls from ERP:**
- Payment confirmation → close PO in TrueSpend
- GL account mapping → map category to cost element
- Cost center hierarchy → validate branch/CC mapping

**Philosophy:** TrueSpend is the reasoning layer. ERP is the book of record. We push decisions in, pull confirmations back. We don't replicate ERP data structures.

---

### 🔲 PHASE E — Accounting & Month-End
**Priority: Medium**  
**Effort: 1 week**

**What month-end means for TrueSpend:**

```
Day 1–28:   Every approved PO commits budget in real-time
Day 28:     Controlling exports commitment register (open accruals)
Day 30:     All matched invoices flagged as "ready to post"
Day 31:     Agent generates period summary: spend vs budget vs forecast
            Exceptions highlighted: invoices unmatched, POs undelivered,
            budget lines overrun, supplier disputes unresolved
```

**Journal entry preparation (simulation):**
- Agent generates suggested journal entries for Controlling review
- Format: GL account / cost center / amount / description / supporting document reference
- Not a replacement for the accounting system — a pre-prepared input that eliminates the manual entry step

**VAT handling:**
- Agent extracts VAT from invoice parsing
- Flags reverse charge situations (cross-border services)
- Notes applicable rate per jurisdiction
- Controlling reviews and posts — agent does not make tax decisions

---

### 🔲 PHASE F — Compliance Hardening
**Priority: Medium**  
**Effort: 1 week**

**Current state:** Supplier onboarding compliance workflow built (NDA/DPA/InfoSec/LkSG agents). Schema extended. Templates ready.

**What needs hardening:**
- Apply schema migrations to Railway database (pending — see CLAUDE.md)
- NDA/DPA e-signature integration (DocuSign or HelloSign API — currently simulation)
- Automated compliance expiry tracking: DPA expires with contract, NDA tracks term
- LkSG annual re-certification workflow: trigger on contract anniversary
- Compliance dashboard on Operations Board: supplier × doc status matrix

**GDPR-specific:**
- Data subject request workflow: stakeholder submits via intake, agent routes to correct processor
- Breach notification timer: 48h GDPR clock, auto-escalate at 44h if not resolved
- Processing register: auto-maintained from supplier DPA data

---

### 🔲 PHASE G — Hyperscaler FinOps Intelligence
**Priority: Low — builds on existing monitor**  
**Effort: 1 week**

**Current state:** Daily monitor built. Anomaly detection working. Slack removed.

**Extensions:**
- Reservation optimization agent: weekly, evaluates all reservations approaching expiry
- Commitment amendment workflow: agent drafts amendment request when EDP/CUD needs adjustment
- Cross-cloud arbitrage: if workload is portable, agent notes cost differential across clouds
- RI/SP coverage dashboard on Operations Board: utilization by provider × account
- Cost allocation: map hyperscaler spend to branch/cost center (currently unlinked)

---

### 🔲 PHASE H — Trust Expansion Engine
**Priority: Low — go-live first**  
**Effort: 1 week**

**The autonomy dial:**

```
Week 1–4:   Threshold €10k. Human reviews sample weekly.
Week 5–8:   Show the log. X transactions, Y auto-closed, Z errors.
Month 3:    Threshold moves to €50k.
Month 6:    Threshold moves to €250k.
Month 12:   Agent handles 80%+ of volume autonomously.
```

**Mechanics:**
- `trust_settings` table: current threshold, escalation rate, accuracy rate, last reviewed
- Weekly report: auto-generated, shows accuracy metrics for the period
- Threshold change request: submitted by Controlling/CPO on board, agent executes
- Accuracy tracking: every auto_execute decision tracked, flagged if later reversed by human

---

## Go-Live Checklist

### Before first use
- [ ] Apply schema migrations to Railway PostgreSQL (`psql` the compliance additions)
- [ ] Set `VITE_POSTGREST_URL` + `VITE_POSTGREST_JWT` on Railway intake service
- [ ] Re-import all 6 workflows to n8n (delete old, import new JSONs)
- [ ] Assign "Authorization-TrueSpend" Header Auth to all PostgREST nodes in n8n
- [ ] Assign Anthropic credential to all Claude nodes
- [ ] Import `supplier_onboarding.json` to n8n

### Before P2I goes live (Phase A + B)
- [ ] Budget buckets populated by Controlling (annual plan → quarterly buckets)
- [ ] Fiscal year defined in `fiscal_years` table
- [ ] Manager spend authority matrix confirmed in `managers.spend_authority`
- [ ] PO number sequence agreed (format: PO-2026-{BRANCH}-{SEQ})
- [ ] Invoice matching tolerance agreed (±2% or €50 recommended)

### Before ERP integration (Phase D)
- [ ] ERP system confirmed (SAP/Oracle/Coupa/other)
- [ ] API credentials provisioned
- [ ] GL account mapping: TrueSpend category → ERP cost element
- [ ] Cost center mapping: TrueSpend branch → ERP CC

---

## Known Issues (from audit 2026-05-27)

### Open
- **H1** — `hyperscaler_positions` schema uses `projected_eur`/`committed_eur`/`reservation_util` but `hyperscaler_monitor.json` `check_flags` node references `projected_spend_eur`/`committed_spend_eur`/`reservation_utilization` — field name mismatch
- **H3** — RLS policies only on 5 of 12 tables
- **H4** — `contracts_expiring` view uses strict `>` — misses same-day expiries, should be `>=`
- **M1** — `manual_required` contracts skip Claude reasoning, go straight to Jira with no brief
- **M2** — `supplier_reply_handler.json` urgency routing fans all outputs simultaneously
- **M3** — `intake_receiver.json` writes 1 trace_log row for all 5 signals (should be 5)
- **L1** — auto-renew decision in `contract_watcher.json` has no ticket FK

### Fixed
- **M4** ✓ — branch_id sends UUIDs not display names
- **M5** ✓ — `reorder_trigger.json` uses `renewal_state` not `status`
- **H2** ✓ — `order_reference` column added to `supplier_emails`
- **L2** ✓ — `hyperscaler_monitor.json` trace signal is `consumption`
- **Slack** ✓ — zero Slack nodes in all 6 workflows

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
