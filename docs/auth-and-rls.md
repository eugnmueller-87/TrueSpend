# Auth and RLS

## INVARIANT (I-1)
Money-touching writes (status→approved, PO issue, budget commit) go ONLY through guarded SECURITY DEFINER RPCs that check the JWT app_role claim. NEVER a raw PATCH/UPDATE from the client. Prevents forged approvals.
RPCs: `approve_and_commit`, `commit_budget`, `release_budget`, `record_spend`, `create_payment_instruction` (`db/schema.sql:1613–1994`)

## INVARIANT (I-2)
Authorisation comes from the JWT `app_role` claim, enforced by Postgres RLS. NEVER trust a client-side role/user object for access. Prevents the localStorage-role hole.

## JWT Structure

```json
{
  "role": "truespend",
  "iat": 1780163487,
  "exp": 2095739487
}
```

- Algorithm: HS256
- Expiry: 10-year (expires ~2036)
- Role claim: `truespend` — this is the PostgreSQL role PostgREST uses
- Stored in `.env` as `POSTGREST_JWT`
- n8n credential: "Authorization-TrueSpend" (Header Auth, name=Authorization, value=Bearer {JWT})
- Frontend: `VITE_POSTGREST_JWT` env var baked into Vite build at Docker build time (`Dockerfile:11–16`)

KNOWN VIOLATION: The JWT is also hardcoded as fallback in `App.jsx:5` — the `|| 'eyJ...'` fallback means the app works even without the env var set. The quality gate catches JWTs in workflow files but not in App.jsx. This is intentional for demo use but is a security gap in production.

## PostgREST Auth Flow

1. Frontend sends `Authorization: Bearer {POSTGREST_JWT}` on every request (`App.jsx:48–53` `pgFetch`, `App.jsx:55–63` `pgPatch`)
2. PostgREST validates HS256 signature against `PGRST_JWT_SECRET` env var (set on Railway PostgREST service)
3. PostgREST sets `role = truespend` for the DB session (from JWT `role` claim)
4. PostgreSQL evaluates RLS policies for role `truespend`
5. All current policies: `USING (true) WITH CHECK (true)` — any authenticated `truespend` session can read/write all rows

n8n workflows use same JWT pattern: `Bearer {{ $env.POSTGREST_JWT }}` in Authorization header on all httpRequest nodes.

## Frontend Auth (Role Switching)

The frontend has NO real auth. Role selection is a demo convenience — not a security boundary.

1. App loads, reads `localStorage` for saved user (`App.jsx:useLocalStorage`)
2. If none, shows role selector (fetches `/users?active=eq.true`)
3. User object (`{id, name, email, role, branchId, costCenterId}`) stored in localStorage
4. `ROLE_GROUP` map (`App.jsx:195–207`) normalises DB role strings to canonical groups (procurement/it/user/controlling/admin)
5. Nav items, board filters, and action buttons are filtered by `roleGroup` — but all these are client-side checks only
6. The PostgREST JWT is the same regardless of role — there is no per-user token

KNOWN VIOLATION of I-2: The role shown in the UI is read from localStorage and from the `/users` table. A user could switch to any persona in the demo. The RLS policies are currently `USING (true)` — they do not filter by branch or role. Branch-scoping of the Operations Board is done client-side only (`App.jsx:1031–1033`).

## Tables with RLS Enabled (schema.sql:1529–1600)

RLS is enabled (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY`) on these 16 tables:

| Table | Policy Created |
|---|---|
| contracts | app_role_all |
| tickets | app_role_all |
| decisions | app_role_all |
| suppliers | app_role_all |
| budget_positions | app_role_all |
| budget_buckets | app_role_all |
| purchase_orders | app_role_all |
| invoices | app_role_all |
| assets | app_role_all |
| license_entitlements | app_role_all |
| license_assignments | app_role_all |
| llm_consumption | app_role_all |
| legal_documents | app_role_all |
| compliance_checks | app_role_all |
| budget_reallocations | app_role_all |
| budget_pools | app_role_all |
| workflow_runs | app_role_all |

All policies use `USING (true) WITH CHECK (true)` for the `truespend` role — any valid JWT bearer can read/write any row. The schema includes a Supabase branch (`if exists (auth schema)`) that would use `service_role` policies instead.

## Tables WITHOUT Explicit RLS Policies (H3 — open issue)

These tables have RLS **not enabled** — they are not listed in the `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` block:

- `trace_log`
- `supplier_emails`
- `branches`
- `hyperscaler_positions`
- `contract_changes`
- `users`
- `cost_centers`
- `contract_clauses`
- `po_sequences`
- `vendor_pricing_benchmarks`
- `trust_settings`
- `llm_api_keys`
- `asset_depreciation_log`
- `erp_sync_queue`
- `payment_instructions`

These are accessible to any bearer of the `truespend` JWT without row-level restriction. For the current single-tenant demo this is acceptable. Before multi-tenant use, add explicit policies.

## SECURITY DEFINER RPCs

All 7 money-touching functions are declared `SECURITY DEFINER` (`db/schema.sql`):
- `commit_budget` (schema.sql:1619)
- `release_budget` (schema.sql:1661)
- `record_spend` (schema.sql:1700)
- `next_po_number` (schema.sql:1743)
- `approve_and_commit` (schema.sql:1780)
- `confirm_delivery` (schema.sql:1818)
- `match_invoice` (schema.sql:1866)
- `create_payment_instruction` (schema.sql:1924)

`SECURITY DEFINER` means these functions execute with the privileges of the function owner (postgres superuser), not the caller. They are the only path through which budget mutations are allowed. They use `FOR UPDATE` row-level locking to prevent race conditions.

Grant: `GRANT EXECUTE ON FUNCTION ... TO truespend` — so the application role can call them via PostgREST `/rpc/`.
