# Conventions

## File Naming

- Workflows: `snake_case.json` in `workflows/{stakeholder|automatic|communication}/`
- DB: `snake_case` everywhere — tables, columns, functions
- React: single file `App.jsx`, all components inline
- Seed files: `01_*.sql` through `12_*.sql` — load in order
- Migrations: `db/migrations/` for schema additions post-initial-deploy

## Component Patterns (App.jsx)

### Config constants at top
```js
const POSTGREST_URL = import.meta.env.VITE_POSTGREST_URL || 'fallback'
const POSTGREST_JWT = import.meta.env.VITE_POSTGREST_JWT || 'fallback'
```
(`App.jsx:4–7`)

### Helper functions before components
`pgFetch(path)`, `pgPatch(path, body)`, `n8nPost(path, body)` — all async, all throw on non-OK (`App.jsx:47–73`)

### Icons as inline SVG components
`const IconX = (p) => <Icon {...p}><path.../></Icon>` — Lucide stroke style, 1.5px rounded (`App.jsx:76–116`)

### Screen-level components
`OperationsBoard`, `NewRequestScreen`, `CatalogScreen`, `BudgetScreen`, `SuppliersScreen`, `ContractsScreen`, `OrdersScreen`, `SearchDocsScreen`, `MyRequestsScreen`, `UsersScreen` — each is a standalone function, no sub-files.

### Canonical constants (INVARIANT I-3)
- `NR_CATEGORIES` (`App.jsx:1219`) — THE category list. Matches `spend_category` enum in schema. Do not fork.
- `STATUS` (`App.jsx:118`) — THE status display config. Matches `ticket_status` enum. Do not fork.
- `BRANCHES` (`App.jsx:10`) — fixed UUID list matching seed data. Hard-coded for demo; validated by quality-gate check 7.

### Role system
`ROLE_GROUP` map (`App.jsx:195`) normalises DB `users.role` strings to 5 canonical groups: procurement, it, user, controlling, admin. `NAV_BY_GROUP` (`App.jsx:213`) drives sidebar navigation per group.

### Data fetching pattern
```js
const load = useCallback(async () => {
  const data = await pgFetch('/open_tickets_board?order=created_at.asc')
  setTickets(data)
}, [deps])
useEffect(() => { load() }, [load])
useEffect(() => { const t = setInterval(load, 30000); return () => clearInterval(t) }, [load])
```
Auto-refresh every 30s for Operations Board (`App.jsx:1024–1045`).

## PostgREST Query Patterns

### Filtering
```
/table?column=eq.value
/table?column=ilike.*text*
/table?column=in.(val1,val2)
/table?column=gte.value
```

### Selecting specific columns
```
/table?select=id,name,status
```

### Ordering + pagination
```
/table?order=created_at.desc&limit=8
```

### Prefer header for writes
```
Prefer: return=representation   — returns inserted/updated row
Prefer: return=minimal          — returns nothing (faster)
```

### RPC calls
```
POST /rpc/function_name
Content-Type: application/json
Body: {"p_arg1": "value", ...}
```

### Authentication
All requests: `Authorization: Bearer {POSTGREST_JWT}` header required. Missing header → 401. Wrong role in JWT → RLS denies access.

## n8n Workflow Node Patterns

### Environment variables
Always `$env.POSTGREST_JWT`, `$env.ANTHROPIC_API_KEY` — never hardcoded in workflow JSON. The quality gate checks for `Bearer eyJ` in workflow headers (`scripts/quality-gate.sh:65–73`).

### Code node structure (JavaScript, async)
```js
// Access previous node output
const data = $node['Node Name'].json
const body = $input.first().json.body

// HTTP request helper (n8n built-in)
const result = await this.helpers.httpRequest({
  method: 'POST',
  url: POSTGREST + '/endpoint',
  headers: { 'Authorization': 'Bearer ' + JWT, 'Content-Type': 'application/json' },
  body: JSON.stringify(payload),
  returnFullResponse: true  // only when status code check needed
})

// Return value
return [{ json: { key: value } }]
```

### Error handling in Code nodes
PostgREST calls wrapped in try/catch where appropriate. Claude response: strip markdown fences before JSON.parse:
```js
const clean = text.replace(/^```json\n?/, '').replace(/\n?```$/, '').trim()
const result = JSON.parse(clean)
```

### Timeouts and retries
- All Claude httpRequest nodes: 120,000ms timeout, retry 3× with 2s backoff
- All PostgREST write nodes: 30,000ms timeout, retry 3× with 1s backoff
(`CLAUDE.md:263–264`)

### workflow_runs pattern
Every automatic workflow writes a start row to `workflow_runs` at the beginning and updates status/summary at the end. The `invoice_processor.json` shows this pattern with `log_run_start` and `log_run_end` nodes.

## Env Var Naming Conventions

| Prefix | Purpose | Example |
|---|---|---|
| `VITE_` | Baked into Vite build at Docker build time — exposed to browser | `VITE_POSTGREST_URL` |
| `DATABASE_` | Raw PostgreSQL connection parts (for Grafana) | `DATABASE_HOST`, `DATABASE_PORT` |
| `POSTGREST_` | PostgREST endpoint + auth | `POSTGREST_URL`, `POSTGREST_JWT` |
| `DOCUSIGN_` | DocuSign JWT Grant credentials | `DOCUSIGN_INTEGRATION_KEY`, `DOCUSIGN_RSA_PRIVATE_KEY` |
| `IMAP_` | Email inbound | `IMAP_HOST`, `IMAP_INVOICES_FOLDER` |
| `SMTP_` | Email outbound | `SMTP_HOST`, `SMTP_PORT` |
| `JIRA_` | Jira API | `JIRA_BASE_URL`, `JIRA_API_TOKEN` |
| `N8N_` | n8n server config | `N8N_ENCRYPTION_KEY`, `N8N_HOST` |
| `GF_` | Grafana config | `GF_SECURITY_ADMIN_USER` |
| `DELIVERY_WEBHOOK_` | Basic Auth for delivery confirmation webhook | `DELIVERY_WEBHOOK_SECRET` |

All vars documented in `.env.example`. The quality-gate check 8 verifies `.env.example` covers all `docker-compose.yml` variable references.

## Commit / PR Conventions

No formal commit convention enforced. The quality gate (`scripts/quality-gate.sh`) must pass before pushing. Key checks:
1. No hardcoded JWTs in workflows or source (but App.jsx fallback JWT is known exception)
2. No private keys in tracked files
3. `intake/dist/` not tracked by git
4. No hardcoded Bearer tokens in workflow Authorization headers
5. All checked JSON files are valid
6. Schema field names match expectations
7. View `contracts_expiring` exists
8. `reorder_trigger` not filtering on `status.eq.active`
9. `hyperscaler_monitor` using correct field names
10. trace_log signal values match `signal_type` enum
11. BRANCHES constant uses UUIDs
12. `.env.example` covers docker-compose vars
13. Vite build succeeds
