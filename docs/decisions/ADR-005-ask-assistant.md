# ADR-005: Ask Assistant (in-app chat) — capability/scope matrix

Date: 2026-06-01
Status: Accepted

## Context

Stakeholders want a chat bubble inside the Operations Board where a user can ask
natural-language questions about their orders, budget, suppliers, and spend, and
get answers **only from inside the TrueSpend environment** — structured DB rows
and (later) the RAG/WIKI document store. No external web access, no model
world-knowledge leaking into answers.

Two realities constrain the design:

1. **One shared JWT, RLS = `USING (true)`.** There is no per-user token today
   (see `docs/auth-and-rls.md`). The database cannot distinguish a requester from
   a procurement manager. Any access scoping enforced *only* in the chat layer
   would therefore be a soft boundary, not a security boundary — exactly the
   localStorage-role hole that I-2 forbids relying on.

2. **SSO / per-user JWTs are the planned fix** (the "SSO milestone" noted in
   `CLAUDE.md` and `docs/auth-and-rls.md`). When per-user tokens carry `app_role`
   and `cost_center_id`, Postgres RLS becomes the real enforcement point and the
   bot inherits it for free.

The honest sequencing, therefore: **write the role→capability→scope matrix now as
the single source of truth, ship the assistant only to roles that already have
full visibility, and let requester-facing chat ride in with SSO.** The matrix is
not throwaway — it is the spec the eventual RLS policies will encode in SQL.

## Decision

### 1. The capability/scope matrix (single source of truth)

Capabilities map to read surfaces:

| Capability        | Read surface                                                        |
|-------------------|---------------------------------------------------------------------|
| `order_status`    | `tickets`, `open_tickets_board`, `purchase_orders`, `commitment_register` |
| `budget_check`    | `budget_positions`, `budget_command_center`                          |
| `supplier_info`   | `suppliers`, `contracts`, `supplier_compliance_summary`, `contracts_expiring` |
| `spend_analytics` | `po_analytics`, `invoice_analytics`, `llm_spend_summary`, `budget_command_center` |

**This is the ASSISTANT READ-SCOPE matrix — not the org-wide authorization / DOA
contract.** The assistant is read-only by nature (it never writes, calls no RPC,
issues no PATCH — I-1), so *scope* is the only differentiator between roles; there
is no "read vs write" annotation. Segregation-of-duties and approval thresholds
(who may approve what amount) are a **SEPARATE matrix, still to be written** — this
ADR does not cover them.

**Scope** is the row-filter that, post-SSO, becomes the RLS `USING` clause. The
**ENFORCER** column says where each rule actually lives:
- **v1: assistant/UI (NOT a security boundary)** — asserted by the client and/or
  the n8n Scope Gate. A determined caller with the shared JWT could bypass it.
  Acceptable in v1 *only* because the roles shipped already see everything anyway.
- **v2: RLS via JWT claim** — real enforcement once per-user JWTs exist.

| Role group     | order_status | budget_check | supplier_info | spend_analytics | Scope (future RLS `USING`)                         | ENFORCER                              | v1 |
|----------------|:------------:|:------------:|:-------------:|:---------------:|----------------------------------------------------|---------------------------------------|:--:|
| `procurement`  | ✅           | ✅           | ✅            | ✅              | `branch_id = ANY(jwt.branch_ids)`                  | **v1: assistant/UI (NOT a boundary)** | ✅ |
| `admin`        | ✅           | ✅           | ✅            | ✅              | unrestricted (company-wide)                        | n/a (no restriction)                  | ✅ |
| `controlling`  | ✅           | ✅           | ✅            | ✅              | `branch_id = ANY(jwt.branch_ids)`                  | **v1: assistant/UI (NOT a boundary)** | ✅ |
| `it`           | ✅           | ✅           | ✅            | ✅              | `category IN (hardware, saas_license, hyperscaler, telecoms, other)` | v2: RLS via JWT claim | ❌ |
| `user`         | ✅           | ✅           | ❌            | ❌              | `requested_by = jwt.email` / `cost_center_id = jwt.cost_center_id` | v2: RLS via JWT claim | ❌ |

**Plain statement of v1 reality:** in v1, procurement / admin / controlling
**actually see ALL branches.** The "own branch" rule for procurement and
controlling is *not enforced anywhere in v1* — the shared `truespend` JWT +
`USING(true)` RLS return every row, and the assistant does not (and cannot
reliably) filter by branch server-side. The branch scope is recorded here as the
**v2 RLS target**, not a v1 behaviour. We ship to these three roles precisely
because "see all branches" is already their effective access today, so the
unenforced rule introduces no new leakage.

**Fail-closed default:** any unknown, missing, or unmapped role — and any request
with no role — gets **no assistant access at all**. The Scope Gate denies by
default; access is granted only to the three explicitly-listed v1 roles.

Notes:
- `user` = `requester` + `ops_manager` (per ADR-001 `ROLE_GROUP` map).
- A `user` asking "does **my** cost center have budget for X" must be scoped to
  `cost_center_id = jwt.cost_center_id` and must **not** see another cost center.
  This *requires* a real per-user claim — hence `user` is deferred to SSO, never
  shipped on a soft boundary.

### 2. v1 ships to full-access roles only

`procurement`, `admin`, `controlling`. These roles already have full read
visibility in the UI and under today's `USING(true)` RLS, so the assistant
introduces **no new leakage**. The chat bubble is hidden for `it` and `user`
groups in v1, and the n8n Scope Gate rejects them with a polite "available soon"
message (defence in depth — never rely on the UI hide alone).

### 3. No external knowledge — hard invariant (I-9)

The assistant answers **only** from TrueSpend tool/query results. The Claude
system prompt forbids outside knowledge and instructs it to say "I don't have
that in TrueSpend" when the data is absent. No web-search or external tool is
wired into the workflow. See `docs/ask-assistant.md`.

### 4. Retrieval = pre-fetched context bundle (v1)

The n8n workflow fetches the caller's scoped tickets + budget + supplier +
spend-summary rows up front and passes them to Claude as context. Simpler than a
tool-call loop and adequate for full-access roles in v1. RAG/document retrieval
(`document_embeddings`, `search_documents_text`) is a v2 addition for policy/wiki
questions.

### 5. Branch dimension on data rows — verification (prerequisite for v2 RLS)

The "own branch" Scope rule is only enforceable if `branch_id` exists on the
**data rows** the future RLS would filter — not just on the user record.
Verified against `db/schema.sql` on 2026-06-01:

| Data row            | `branch_id` present? | "own branch" RLS filterable? |
|---------------------|:--------------------:|------------------------------|
| `tickets`           | ✅ (schema.sql:934)  | Yes                          |
| `contracts`         | ✅ (schema.sql:366, nullable) | Yes when set        |
| `budget_positions`  | ✅ (schema.sql:474, NOT NULL) | Yes                 |
| `budget_buckets`    | ✅ (schema.sql:451, NOT NULL) | Yes                 |
| `purchase_orders`   | ✅ (schema.sql:541)  | Yes                          |
| `suppliers`         | ❌ **absent**        | **No — see below**           |

**Prerequisite / gap:** `suppliers` has **no `branch_id`** — suppliers are
company-wide entities (one vendor serves many branches). Therefore "own branch"
is structurally **unenforceable for `supplier_info` even in v2**. Two acceptable
resolutions, to be decided when SSO RLS is written (NOT in this ADR):
(a) treat suppliers as company-wide-readable for all roles that get
`supplier_info` (likely correct — vendor master data is shared); or
(b) scope supplier visibility indirectly via `contracts.branch_id` /
`purchase_orders.branch_id` (a supplier is "yours" if you have a contract/PO with
it). The other five rows carry `branch_id` and are RLS-filterable as written.

## Consequences

- The matrix above is the **spec for RLS**. When SSO lands, each row's Scope
  column becomes a Postgres `CREATE POLICY ... USING (...)` clause, and the n8n
  Scope Gate's hardcoded role check is replaced by reading the JWT `app_role` +
  `cost_center_id` claims. The work done now is not rewritten — it is encoded.
- Until then, the v1 branch scope is **NOT a boundary** (see ENFORCER column) —
  procurement/admin/controlling see all branches. Shipping only to these
  full-access roles keeps it honest: no role can use the bot to see something it
  couldn't already see in the UI.
- Fail-closed: unknown / no-role / unmapped role → no assistant access.
- New invariant **I-9** added (no external knowledge; scope per this matrix).
- `it` / `user` chat is explicitly out of v1 scope and gated server-side.

## Invariants Affected

- **I-2** — This ADR does NOT weaken I-2. It explicitly refuses to treat the
  chat-layer scope as a security boundary, and ships only to roles for which the
  current `USING(true)` RLS is already correct. The matrix is the I-2-compliant
  RLS spec for after SSO.
- **I-9 (new)** — Ask assistant answers only from TrueSpend data; never external
  knowledge. Scope follows the matrix in this ADR.
