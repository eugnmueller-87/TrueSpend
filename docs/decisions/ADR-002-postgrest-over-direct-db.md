# ADR-002: PostgREST Over Direct Postgres from Frontend
Date: 2026-05-27
Status: Accepted

## Context

The Operations Board (React SPA) and the n8n workflows both need read/write access to the PostgreSQL database. Options considered:
1. Direct Postgres connection from the browser (not possible — browser cannot open TCP connections)
2. Custom REST API layer (Node.js/Express or similar)
3. PostgREST — auto-generated REST API from PostgreSQL schema

## Decision

Use PostgREST. No custom REST API layer.

PostgREST on Railway (`https://postgrest-production-7960.up.railway.app`) auto-generates:
- `GET /table` → `SELECT * FROM table` with filter support (`?col=eq.val`, `?col=ilike.*text*`)
- `POST /table` → `INSERT INTO table`
- `PATCH /table?filter` → `UPDATE table WHERE filter`
- `POST /rpc/function_name` → `SELECT function_name(...)` (for SECURITY DEFINER RPCs)

The JWT `role=truespend` claim maps directly to a PostgreSQL role. PostgREST enforces RLS automatically — no separate auth layer needed.

n8n workflows use the same PostgREST endpoint with the same JWT. This means n8n and the frontend share the same auth model.

## Consequences

- No custom server to maintain, deploy, or debug
- Schema changes (add column, add table) are immediately reflected in the REST API
- All money-touching operations must go through SECURITY DEFINER RPCs (not raw PATCH) — PostgREST exposes these at `/rpc/function_name`
- RLS policies in PostgreSQL are the security boundary — PostgREST does not add its own auth layer
- The `POSTGREST_JWT` is the single credential for all DB access. It has a 10-year expiry (set at creation). Rotation requires updating Railway env vars and all n8n credentials.
- PostgREST does not support `SELECT FOR UPDATE` or transactions spanning multiple requests — all multi-step atomic operations must be written as SECURITY DEFINER PL/pgSQL functions
- VERIFY: PostgREST version on Railway. Some features (computed columns, function calls) depend on version.

## Invariants Affected

- I-1: All money writes must go through `/rpc/` endpoints — not direct `/table` PATCH. PostgREST exposes both paths; the invariant is enforced by discipline and code review, not by PostgREST itself.
- I-2: JWT auth claim is the only auth mechanism. PostgREST trusts the `role` claim in the JWT.
