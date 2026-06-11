# Routing Engine

## INVARIANT (I-5)
The routing/approval logic has ONE source of truth shared by UI preview and the agent. Don't reimplement it in a second place.

The canonical source: `workflows/stakeholder/intake_receiver.json` nodes `pre_check_gate` + `call_claude`.
The UI preview: `App.jsx:1241` `buildApprovalPath()` — for display only, does NOT override agent decisions.

## Three-Signal Disposition Model

Every agent call produces one of three dispositions (`db/schema.sql:62–67`):

| Disposition | Meaning | Action |
|---|---|---|
| `auto_execute` | All signals green, confidence ≥ threshold | Agent acts, creates PO, closes ticket silently |
| `one_touch` | One signal uncertain, confidence < threshold | Ticket on Operations Board with Approve/Reject |
| `escalate` | ≥€100k, compliance blocker, or novel situation | Jira PROC ticket created |

## Where Routing Logic Lives

The routing has two stages, both in `intake_receiver.json`:

### Stage 1: Pre-Check Gate (sync, deterministic)
Node: `pre_check_gate` (`intake_receiver.json` node id: `pre_check_gate`)

Runs synchronously before Claude. Forces disposition before the LLM call:
- `amount > 100000` → `forceDisposition = 'escalate'`
- `amount > managerAuthority` → `forceDisposition = 'one_touch'`
- CC budget position not found for cost_center + category → `forceDisposition = 'one_touch'`, `budgetWarning` set
- CC budget remaining < amount → `forceDisposition = 'one_touch'`, `budgetWarning` set
- `supplier.compliance_status !== 'green'` → `needsCompliance = true` (Claude told to downgrade auto_execute → one_touch if this flag set)

If `forceDisposition` is set, Claude is told to return this disposition. After Claude responds, `forceDisposition` is enforced again:
```js
if (preCheck.forceDisposition && result.disposition !== preCheck.forceDisposition) {
  result.disposition = preCheck.forceDisposition;
}
```
(`intake_receiver.json` node `call_claude`, post-parse block)

### Stage 2: Claude Five-Signal Reasoning (probabilistic)
Node: `call_claude` (`intake_receiver.json` node id: `call_claude`)

Claude receives a structured prompt with 5 signals and returns:
```json
{
  "disposition": "auto_execute|one_touch|escalate",
  "confidence": 0.0–1.0,
  "reasoning": "...",
  "recommendation": "...",
  "brief": "...",
  "signals": [...]
}
```

Model: `claude-sonnet-4-6`, max_tokens: 1500

## The 5 Signals

Defined in the Claude prompt (`intake_receiver.json` node `call_claude`):

| Signal | Data Source | What it checks |
|---|---|---|
| `contract` | `GET /contracts?supplier_id=eq.{id}&branch_id=eq.{id}` | Existing contract coverage, category match |
| `budget` | `GET /budget_positions?branch_id=...&period=...` | Available budget vs requested amount |
| `supplier` | `GET /suppliers?name=ilike.*{name}*` | Compliance status, health, supplier history |
| `request` | Form body | Request type, amount, submitter, category |
| `policy` | Hardcoded in prompt | Catalog items → always auto_execute if budget available; auto_execute rules; escalation thresholds |

Signal weights are determined by Claude per call — they are not hardcoded. Each signal in the response has a `weight` field (0.0–1.0) representing how much it influenced the disposition. These weights are stored in `trace_log.weight` (`db/schema.sql:1015`).

## Confidence Score

- Claude returns `confidence` as a float 0.0–1.0
- Stored in `decisions.confidence` (`db/schema.sql:988`)
- Also stored in `tickets.confidence` (not visible in schema — VERIFY: tickets table has no `confidence` column in schema; `open_tickets_board` view aliases `t.confidence as confidence_score` — VERIFY this column exists on tickets)
- Threshold for `auto_execute`: confidence ≥ 0.85 (from prompt) or ≥ 0.95 (from `trust_settings.min_confidence_auto`)
- UI displays confidence bar (`App.jsx:885–896` `ConfBar`): green ≥ 90%, amber ≥ 75%, red < 75%

KNOWN VIOLATION: `trust_settings` table is defined but not actively read by any workflow at runtime (no workflow fetches from `/trust_settings`). The thresholds in the Claude prompt are hardcoded strings.

## Routing After Disposition

Switch node `route_disposition` (`intake_receiver.json` node id: `route_disposition`) routes on `disposition` value to 3 output branches:

- Output 0 (`auto_execute`): → `approve_and_commit` RPC → close ticket (`status='auto_executed'`) → send PO email → notify submitter
- Output 1 (`one_touch`): → PATCH `tickets.status = 'pending_review'` → ticket lands on Ops Board
- Output 2 (`escalate`): → PATCH `tickets.status = 'escalated'` → create Jira PROC issue

## Ops Board Actions (client-side routing)

After agent routing, humans interact via Ops Board. Handled in `App.jsx:1054–1095` `handleAction`:

| Action | Trigger | Result |
|---|---|---|
| Approve | Button on `pending_review` ticket | `pgPatch('/tickets', {status: 'approved'})` — VERIFY: budget was already committed by n8n |
| Reject | Button on `pending_review` ticket | `pgPatch('/tickets', {status: 'rejected'})` |
| Sign | Button on `signature_required` ticket | `n8nPost('/docusign-sign', {ticket_id})` → DocuSign embedded signing |
| Decline | Button on `signature_required` ticket | `pgPatch('/tickets', {status: 'rejected'})` |
| Confirm | Button on `pending_confirm` ticket | `pgPatch('/tickets', {status: 'approved'})` |
| Acknowledge | Button on `escalated` ticket | `pgPatch('/tickets', {status: 'closed'})` |

KNOWN VIOLATION of I-1: The Approve/Reject buttons use raw `pgPatch` directly on the `tickets` table, not an RPC. Budget commit was already handled by `approve_and_commit` in the n8n workflow. The raw PATCH only updates the status label. This is a gap in the guard — a forged Approve PATCH from the client cannot re-commit budget (it's already committed), but it can change ticket status without any budget check.

## UI Preview: buildApprovalPath()

`App.jsx:1241–1272` `buildApprovalPath(amountEur, category, hasPersonalData, existingSupplier)` — purely presentational, runs client-side with no DB query:

| Threshold | Approver added |
|---|---|
| Any request | AI Agent (auto, < 2 min) |
| ≥ €1k OR has_personal_data | Procurement Manager (4h SLA) |
| saas_license + has_personal_data | IT Security (1 day) |
| new supplier OR services category | Legal (NDA/DPA or SOW, DocuSign, 2 days) |
| ≥ €100k | CFO (1 day) |
| ≥ €50k | Head of Procurement (4h) |

This is for display only. Actual approval path is determined by agent.
