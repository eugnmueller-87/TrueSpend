# Ask Assistant

In-app chat bubble that answers questions about orders, budget, suppliers, and
spend **only from inside TrueSpend** — structured DB rows today, RAG/WIKI docs in
v2. No external web access, no model world-knowledge.

Spec: `docs/decisions/ADR-005-ask-assistant.md` (the role→capability→scope matrix).
Governing invariant: **I-9** (CLAUDE.md).

## Flow

```
Chat bubble (App.jsx, full-access roles only)
   │  POST {N8N_WEBHOOK_BASE}/chat
   │  body: { question, role, branchIds, costCenterId, email }
   ▼
n8n: chat_assistant
   1. Scope Gate (Code)   — reject it/user groups in v1; attach scope to context
   2. Fetch bundle        — scoped PostgREST GETs (tickets/budget/supplier/spend)
   3. Claude (Code)       — answer ONLY from bundle; no outside knowledge
   4. Respond to UI       — { answer, sources[] }
```

## The no-external-knowledge guarantee (I-9)

Two mechanisms, both required:

1. **Claude only ever sees TrueSpend rows.** The workflow passes only the
   pre-fetched bundle. No web-search/external tool is wired in.
2. **System prompt hard-bounds the model:**
   > You are TrueSpend's internal assistant. Answer ONLY using the TrueSpend data
   > provided below. Never use outside or general knowledge. If the answer is not
   > in the provided data, say "I don't have that in TrueSpend." Cite which rows
   > you used.

If the data doesn't contain the answer, the correct response is "I don't have
that in TrueSpend" — never a guess.

## Scope (v1)

Ships to `procurement`, `admin`, `controlling` only — roles that already have
full read visibility, so no new leakage. In v1 these roles see **all branches**:
the "own branch" rule in ADR-005 is the v2 RLS target, NOT a v1 boundary. `it` and
`user` groups are hidden in the UI **and** rejected by the Scope Gate (fail-closed:
any unknown/unmapped/no-role request gets no assistant). Requester-facing chat (own
cost center only) waits for SSO / per-user JWTs, per ADR-005.

Note: `suppliers` has no `branch_id`, so supplier visibility cannot be
branch-scoped even in v2 — see ADR-005 §5 for the resolution options.

## Read surfaces by capability

| Capability        | Views / tables queried                                              |
|-------------------|---------------------------------------------------------------------|
| order_status      | `open_tickets_board`, `tickets`, `purchase_orders`, `commitment_register` |
| budget_check      | `budget_command_center`, `budget_positions`                          |
| supplier_info     | `supplier_compliance_summary`, `suppliers`, `contracts`, `contracts_expiring` |
| spend_analytics   | `po_analytics`, `invoice_analytics`, `llm_spend_summary`             |

All reads use the existing `truespend` JWT (read-only GETs). The assistant
**never** writes — no RPC calls, no PATCH. Money writes stay on their guarded
RPC path (I-1).

## v2 (not built yet)

- RAG/WIKI: `search_documents_text` over `document_embeddings` for policy/contract
  document questions.
- Requester + IT chat once SSO issues per-user JWTs and RLS encodes the ADR-005
  scope matrix.
