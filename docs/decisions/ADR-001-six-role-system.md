# ADR-001: Six-Role System
Date: 2026-05-27
Status: Accepted

## Context

TrueSpend needs role-based access control across a multi-branch procurement org. Early design had a flat "manager" model (`managers` table). The system grew to cover procurement managers, IT managers, ops managers, requesters, controlling (finance), and admin (platform). Legal was originally included but deactivated — legal works in Jira, not this tool.

The role system drives: navigation (which screens are visible), board filters (IT Manager sees hardware/saas/hyperscaler/telecoms only), action buttons (only `procurement` role can Approve/Reject/Sign), and future RLS row filtering.

## Decision

Six canonical role groups in `App.jsx:186–207`:
- `procurement` — full board, all requests, can approve/sign. Maps DB roles: `procurement_manager`, `head_of_procurement`, `category_manager`
- `it` — board (IT categories only: hardware, saas_license, hyperscaler, other, telecoms), cannot sign. Maps: `it`, `it_manager`
- `user` — submit requests + view own requests only. Maps: `user`, `ops_manager`, `requester`
- `controlling` — read-only board (own branch) + budget + contracts + orders. Maps: `controlling`
- `admin` — board + suppliers + users screen. Maps: `admin`
- `legal` — removed; no tool access. Deactivated in DB. Works in Jira.

DB `users.role` column is a free text field (not enum) supporting: `procurement_manager`, `head_of_procurement`, `category_manager`, `it_manager`, `budget_owner`, `requester`, `controlling`, `admin`, `ops_manager`.

## Consequences

- `ROLE_GROUP` map in `App.jsx:195` is the canonical normalisation. If a new DB role string is added, it must be mapped here or it falls back to `user` group.
- Role switching is a demo convenience only — no real auth. See `docs/auth-and-rls.md`.
- The `spend_authority` field on `users` (`db/schema.sql:294`) is used by the Pre-Check Gate in `intake_receiver.json` to determine forced disposition. If a user's `spend_authority` is 0, any amount > 0 triggers one_touch.
- `cfo` role deactivated — previously had its own nav group. Removed from `ROLE_GROUP` map and nav.

## Invariants Affected

- I-3: `ROLE_GROUP` map is a canonical lookup. Do not add parallel role mappings.
- I-4: `controlling` and `user` roles are read-only — do not add action buttons for these groups without an ADR.
