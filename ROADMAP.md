# TrueSpend — Roadmap
**Last updated:** 2026-05-27  
**Status:** Pre-build. Architecture defined. First client conversation: IONOS.

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

---

## Architecture

```
TrueSpend
│
├── core/
│   ├── agent.py              ← The reasoning loop. Reads context, weighs signals, reaches disposition.
│   ├── confidence.py         ← Confidence scoring. Maps score to action: auto / confirm / escalate.
│   └── trace_log.py          ← Every decision stored with full reasoning chain. The audit trail IS the thought process.
│
├── connectors/
│   ├── jira.py               ← Incoming ticket webhook. Every procurement request enters here.
│   ├── contracts.py          ← Contract database. Expiry tracking. Renewal engine.
│   ├── hyperscaler.py        ← AWS / GCP / Azure cost APIs. Daily burn vs commitment.
│   └── email.py              ← Supplier email threading. Institutional memory.
│
├── intelligence/
│   ├── icarus.py             ← Market signals. RSS + Claude. Carried from SpendLens.
│   └── due_diligence.py      ← Onboarding checks. OpenCorporates, sanctions, GDPR, financial health.
│
├── api/
│   └── main.py               ← FastAPI. TrueSpend exposes endpoints. ERP integration lands here.
│
├── frontend/
│   └── ...                   ← Clean UI. Entry point: "X things need you this week."
│
└── db/
    └── schema.sql            ← Contracts, tickets, decisions, suppliers, traces.
```

**Philosophy:** SpendLens is a tool you open. TrueSpend is infrastructure that runs. The interface isn't a dashboard you check — it's a brief that arrives when you're needed. Mostly you're not needed.

---

## The Reasoning Model

Every transaction the agent handles runs the same five-signal check simultaneously. Not sequentially. Not as a checklist. As a holistic judgment.

```
Signal 1 — Contract context
  Not just "does a contract exist" but: what are the actual terms,
  what is the pricing at this volume tier, are there conditions on this order type.

Signal 2 — Consumption context  
  What has this team already spent this period. Where does this purchase
  land them vs budget. Does the spend pattern look normal or anomalous.

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

The confidence threshold is a policy dial the organization controls. It starts conservative and widens as the agent builds a track record.

---

## Trust-Building Mechanism

The agent earns autonomy through demonstrated accuracy. Not promises.

```
Week 1–4:   Agent handles transactions under €10k. 95%+ confidence threshold.
            Every decision logged. Weekly review of sample.

Week 5–8:   Show the numbers. X transactions, Y auto-closed, Z errors.
            Organization ratifies what's already working.

Month 3:    Threshold moves to €50k. Same mechanism.
Month 6:    Threshold moves to €250k.
Month 12:   Agent handles 80%+ of transaction volume autonomously.
```

This is not AI being cautious. It's a deliberate governance mechanism. The organization is never asked to trust blindly — they're shown evidence and asked to ratify what they can already see is working.

---

## Build Phases

### Phase 0 — Foundation
**Effort:** 1 week  
**Goal:** Clean repo, schema defined, API skeleton running.

- [ ] Initialize TrueSpend as standalone repo — no SpendLens dependency
- [ ] Database schema: contracts, suppliers, tickets, decisions, trace_log
- [ ] FastAPI skeleton — health check, basic endpoints
- [ ] Carry over from SpendLens: `icarus.py`, `flag_engine.py`, `hermes_client.py`
- [ ] Dev environment: Docker, env vars, run script

---

### Phase 1 — Contract Renewal Engine
**Effort:** 1 week  
**Value:** Where the €70M lives. Most demonstrable win for IONOS.  
**Story beat:** *"Your €70M in hardware renewals. Handled."*

The agent watches every contract expiry. Drives the renewal process without human involvement until a genuine decision is required.

- [ ] Contract database: supplier, value, expiry, owner, category, currency, terms summary
- [ ] Expiry tracking: 90 / 60 / 30 day alert logic, runs daily
- [ ] Renewal brief generator: consumption vs commitment, market benchmark, recommended position
- [ ] Automated supplier outreach: agent drafts email, one-touch send
- [ ] Strategic supplier calendar: top 10 suppliers, renewal timeline view

**Renewal timeline:**
```
18 months out  →  Consumption tracking begins silently
12 months out  →  Owner notified (awareness, no action needed)
 6 months out  →  Full renewal brief produced by agent
 3 months out  →  Human-led negotiation begins, agent supports with live data
 Signed        →  Agent picks up monitoring for next cycle
```

---

### Phase 2 — Jira Intake + Agent Reasoning Loop
**Effort:** 1–2 weeks  
**Value:** Routine transactions close without human touch. Audit trail builds trust.  
**Story beat:** *"847 transactions processed this month. You touched 3."*

- [ ] Jira webhook — incoming tickets arrive in TrueSpend
- [ ] Agent reasoning loop — reads full ticket text, not just fields
- [ ] Five-signal context pull: contract / budget / supplier / request / policy
- [ ] Confidence scoring + disposition engine
- [ ] Reasoning trace log — every decision stored with full chain
- [ ] Ticket types: contract renewal / bulk order / new supplier / policy exception / general approval

---

### Phase 3 — Hyperscaler Monitoring
**Effort:** 1 week  
**Value:** AWS/GCP/Azure managed as a continuous commercial position, not a monthly surprise.  
**Story beat:** *"We don't just manage what you buy. We manage what you consume."*

- [ ] AWS Cost Explorer connector
- [ ] GCP Billing API connector
- [ ] Azure Cost Management connector
- [ ] Daily burn rate vs commitment tracking: EDP, CUD, reservation utilization
- [ ] Overshoot / undershoot alerts: flagged 90 days before commitment period ends
- [ ] Idle resource detection: unattached volumes, unused reservations, expired savings plans
- [ ] Reservation right-sizing: exchange / renew / let expire recommendations
- [ ] MTD position widget: one line per hyperscaler, weekly trajectory

---

### Phase 4 — Supplier Onboarding as One Checkpoint
**Effort:** 1 week  
**Value:** Weeks of process collapsed to one human decision on a pre-assembled brief.  
**Story beat:** *"New supplier. Due diligence done. One person. One decision. Done."*

- [ ] Onboarding ticket type in Jira — triggers agent automatically
- [ ] OpenCorporates: entity verification, ownership structure, jurisdiction
- [ ] Sanctions screening: OFAC, EU consolidated list, UN list
- [ ] Financial health: public data, credit signals where available
- [ ] GDPR classification: what data shared, legal basis, DPA required?
- [ ] Existing relationship check: have we worked with them before?
- [ ] Risk score + one-page brief: green / yellow / red with specific flags
- [ ] Minimal legal data capture: 5–6 fields only
- [ ] Vendor master creation: automated on green or approved yellow

---

### Phase 5 — Email Threading + SLA Signal
**Effort:** 3–4 days  
**Value:** Institutional memory that survives personnel changes. Performance signal with zero manual updates.  
**Story beat:** *"They said they'd hold pricing through Q3. Here's the email. Two years ago."*

- [ ] Gmail / Outlook API connector: per-supplier email threading
- [ ] Agent summarization: reads every email, surfaces only exceptions
- [ ] SLA monitoring: delivery performance vs contract terms, green / watch / red
- [ ] Informal commitment extraction: price holds, scope promises, informal agreements — surfaced at renewal
- [ ] Supplier communication log: full thread visible, searchable, never lost

---

### Phase 6 — The Interface
**Effort:** 1 week  
**Value:** "Nothing else needs you today" is the goal state.  
**Story beat:** *"Three things need you this week. Everything else, the agent closed."*

```
┌─────────────────────────────────────────────────────┐
│  3 things need you this week                         │
│                                                      │
│  → Dell renewal: €18M — brief ready, 28 days left   │
│  → Accenture SOW: scope change flagged              │
│  → New supplier: Corevist GmbH — risk score 74/100  │
│                                                      │
│  847 transactions closed this month                  │
│  €12.3M managed without escalation                  │
│                                                      │
│  [ Nothing else needs you today ]                    │
└─────────────────────────────────────────────────────┘
```

- [ ] Weekly digest: X things need you, nothing else
- [ ] Audit trail: every agent decision, full reasoning, browsable
- [ ] Strategic supplier calendar: top 10, renewal timeline
- [ ] Hyperscaler position: MTD across AWS/GCP/Azure
- [ ] AI spend tracker: shadow AI spend consolidation across teams
- [ ] Mobile / async: Telegram or Slack for on-the-go one-touch confirms

---

## The LinkedIn Story Arc

Six posts. One narrative. Published weekly. No product name until Post 6.

| Post | Hook | What it does |
|------|------|--------------|
| 1 | "I'm building something that will make procurement redundant." | Provocation. Filters the audience. |
| 2 | "Procurement was never supposed to be a department." | Diagnosis. Names what it became vs what it was for. |
| 3 | "Traditional procurement is built on control. There's a different model." | Philosophy shift. Control → confidence. |
| 4 | "When you remove procurement as a processing function, here's what's left." | Answers the "what about people" question honestly. |
| 5 | "Imagine you run procurement for a company spending €70M a year on hardware." | Makes it concrete. Real numbers, real stakes. |
| 6 | "I'm not building a procurement tool." | The invitation. CFOs, CPOs, procurement professionals who see it. |

**Rules:**
- No product name until Post 6
- No feature list in any post
- Each post stands alone but builds the argument
- Posts 1 and 3 will generate friction — don't smooth the edges
- Respond to every comment in the first 2 hours

---

## The IONOS Pitch — One Page

**The problem they have:**
- €70M+ in hardware renewals (Dell, Lenovo, Apple) managed manually
- Hyperscaler spend (AWS/GCP/Azure) visible monthly, managed never
- Supplier onboarding: weeks of manual process
- No consolidated view of what's approved, why, or what's coming

**What TrueSpend does:**
- Contract renewal engine watches every expiry, prepares every brief, drives every renewal until a human decision is genuinely required
- Hyperscaler monitoring: daily burn vs commitment, overshoot flagged 90 days out, idle resources surfaced continuously
- Jira intake: every procurement request reasoned by agent, closed without human touch or escalated with full brief pre-written
- Supplier onboarding: due diligence automated, one checkpoint, one decision

**The number that matters:**
80%+ of transaction volume handled without human touch. The 20% that reaches a human comes with a complete brief. The humans focus on the €50M+ relationships where they actually create value.

**The trust mechanism:**
Start at €10k threshold. Show the log after 4 weeks. Move the threshold based on evidence. The agent earns its own authority expansion through demonstrated accuracy.

**The pitch line:**
> "Three things need you this week. Everything else, the agent closed."

---

## What Remains Human

This is not a headcount elimination pitch. It's a capability transformation pitch.

| Role | What it becomes |
|------|----------------|
| Procurement Ops | Disappears. The processing was the job. The processing is gone. |
| Procurement Excellence | Becomes system governance. Policy ownership. Threshold management. A smaller, more senior function. |
| Strategic Procurement | Becomes what it was always supposed to be. Two conversations a year with Dell. Fully prepared. Completely focused. |

The people who remain are the ones whose judgment is genuinely irreplaceable. Not the ones who were good at managing the process.

---

## International Scale Considerations

Reasoning scales better than rules.

A rule-based system needs a rule for every jurisdiction. The maintenance burden compounds with every new country.

A reasoning system handles Germany, Singapore, and Brazil with the same agent. It understands that a Handelsregister number means something different from a Companies House number. It knows GDPR applies here and PDPA there. You don't configure this — the agent reasons about jurisdiction from context, the same way a senior international procurement professional does.

**What this means for the build:**
- Jurisdiction-aware reasoning baked into the agent prompts from day one
- Multilingual supplier communication (German first, then FR/ES/PT)
- ERP integration via API — SAP, Oracle, Coupa — TrueSpend sits on top, doesn't replace
- No country-specific configuration matrices

---

## The Moat

Not the technology. The technology is available to everyone.

**The reasoning trace corpus.** Every decision TrueSpend makes, logged with full reasoning. After 12 months across multiple enterprise clients, the most comprehensive dataset of procurement reasoning in existence. That trains the next version of the agent to be better than anything a single firm could build internally.

**The calibration knowledge.** What confidence threshold works for what transaction type, in what industry, in what jurisdiction. Institutional knowledge that compounds with every client.

**The change management playbook.** How to land this in a large enterprise without the organizational immune system killing it. That knowledge is as valuable as the software.
