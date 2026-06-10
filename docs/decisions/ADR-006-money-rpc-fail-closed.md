# ADR-006: Money RPCs go fail-closed; money writes leave the browser

Date: 2026-06-10
Status: Proposed (pending the prerequisites in "Consequences" — apply is gated)

> Naming note (post-ADR-007): the migration referenced below as
> `step12_money_rpcs_fail_closed.sql` was renamed to
> `000015_money_rpcs_fail_closed.sql`, and `step2_rpc_boundary.sql` to
> `000002_rpc_boundary.sql`, by the Phase 3 dbmate renumbering. Read every
> `stepN_*` reference here as its `0000NN_*` equivalent.

## Context

The SPA ships a single static JWT (`role=truespend_app`, **no `app_role` claim**)
and uses it for *every* call — including the money RPCs (`approve_and_commit`,
`reject_ticket`, `confirm_delivery`, `match_invoice`,
`create_payment_instruction`) called directly from the browser
(`intake/src/App.jsx`). Anyone with DevTools can extract that token and approve
POs, create payments, set budgets, or edit user roles with arbitrary parameters.

The RPC role guards added in `step2_rpc_boundary.sql` were deliberately **dormant**:
`if app_role is not null and app_role not in (...)` — a NULL claim (today's token)
is a no-op. The guard auto-arms only once SSO issues `app_role`. This honored
invariant **I-2** in spirit but left the hole open in practice: the boundary is
"enforced by Postgres RLS" only after SSO, which is not yet live.

Two facts make "just flip it on" unsafe as a one-liner:

1. **Nothing mints `app_role` today.** Flip the guard and the *browser* is blocked
   (good) — but so is *every other caller using the same claim-less token*,
   including the n8n automation (invoice→payment chain) and the board's own
   approve/reject. It hard-bricks the product, not just the attacker.
2. **Nested SECURITY DEFINER calls inherit the caller's claim.** `release_budget`
   /`record_spend` run via `PERFORM` inside `reject_ticket` /
   `create_payment_instruction`; `request.jwt.claims` is not reset across the
   definer boundary, so a privileged entry propagates the privileged claim down,
   and a claim-less entry is already blocked at the top.

## Decision

**Re-route money writes off the browser first, then flip the guards fail-closed.**

1. **Single server-side entry point** — `workflows/stakeholder/board_action.json`
   (`POST /webhook/board-action`). The SPA posts `{action, ...ids}` with **no
   money-capable token**; the workflow re-fetches authoritative ticket/PO fields
   server-side and calls the right SECURITY DEFINER RPC using the server-held
   PostgREST credential. The browser never sends amounts/categories that steer a
   money move — only intent + ids. This mirrors the DocuSign/chat
   stored-credential pattern.

2. **Client seam** — `intake/src/api/client.js` `boardAction()` + the
   `routeMoneyThroughN8n` switch (`VITE_ROUTE_MONEY_VIA_N8N`). While off, the SPA
   calls the RPC directly (legacy, unchanged). When on, every money/budget/user
   write goes through `/webhook/board-action`. This is the one place that flips.

3. **Fail-closed flip** — `step12_money_rpcs_fail_closed.sql` changes every money
   guard from `is not null AND not in(...)` to **`is null OR not in(...)`**, adds
   the guard to the previously-unguarded `release_budget` / `record_spend` /
   `create_payment_instruction`, and adds `upsert_budget_position` (a
   SECURITY DEFINER replacement for the browser's raw `/budget_positions`
   POST/PATCH — closing an I-1 raw-money-write gap). `payments` allow
   `controlling` in addition to `procurement`/`admin`.

4. **Interim privileged token** — the n8n service credential gets an `app_role`
   of `procurement` (and `controlling` for the payment path) baked in, until
   per-user SSO (ADR-005) issues real per-user claims. This is the token
   `board_action.json` / `invoice_processor.json` / delivery automation use.

This satisfies the original requirement — *the browser-held token cannot approve a
PO or move money* — without bricking, because by the time the guard goes strict
the legitimate callers (n8n) carry the claim and the browser no longer calls the
RPCs at all.

## Consequences

**Invariant impact (I-2):** this flips I-2's dormant guard to **enforcing**. The
"client-side-role only" caveat in I-2's note is removed for money RPCs: a
claim-less token is now physically rejected (42501 → HTTP 403), not merely
unable-by-convention.

**Prerequisites before applying `step12` (gated — do NOT apply first):**
1. The n8n service token carries `app_role IN ('procurement','admin'[,'controlling'])`.
2. The SPA is deployed with `VITE_ROUTE_MONEY_VIA_N8N=true` and
   `board_action.json` is imported + active in n8n.
3. Decode the live tokens (`scripts/repro_money_rpc_exposure.js --decode`):
   confirm the **browser** token has no `app_role` (so it's blocked) and the
   **n8n** token has a privileged `app_role` (so it keeps working).

**Apply procedure (I-8):** `step12` is a NEW migration — run via
`scripts/db-migrate.sh`, confirm it lands in `schema_migrations`, then
`NOTIFY pgrst, 'reload schema'` (PostgREST 404s the recreated RPCs until cache
refresh). Do not edit `step2_rpc_boundary.sql` in place.

**schema.sql drift:** `step2`'s guards live only in the migration; schema.sql's
copies are stale (no guard) and `release_budget`/`record_spend`/
`create_payment_instruction` have no guard anywhere in schema.sql. Rather than
hand-edit schema.sql (which Phase 3 will regenerate as a pg_dump snapshot), the
authoritative bodies are in `step12`; schema.sql parity comes from the Phase 3
regeneration.

**step2 self-test inversion:** step2's DO-block Test 2 asserts a NULL `app_role`
is a NO-OP. That is now intentionally false. `step12` ships its own self-tests
(Test A: null is blocked; B: procurement passes; C: viewer blocked). If step2 is
ever re-run against a DB that already has step12, its Test 2 will fail — which is
correct; do not re-run step2 post-step12.

**Reversibility:** the flip is reversible by re-creating the RPCs with the dormant
guard, but the re-route (board_action + client seam) is the durable improvement
and should stay regardless.

## Alternatives considered

- **Flip guards now, accept breakage** — rejected: bricks the board + automation
  with no migration path until SSO.
- **Wait for SSO to flip** — rejected: leaves the live exploit open indefinitely;
  SSO has no committed date.
- **Per-RPC separate webhooks** — rejected in favor of one `/webhook/board-action`
  switch: less surface, one stored credential, one chokepoint.
