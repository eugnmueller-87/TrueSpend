# TrueSpend — Agent Handover (2026-05-31)

Read `CLAUDE.md` and `SECURITY.md` before touching anything.
Run `bash scripts/quality-gate.sh` before every push.

---

## Verified Live State (as of this handover)

### DB migrations — all applied to prod, recorded in `schema_migrations`

| Migration | Status |
|---|---|
| cost_centers_seed.sql | ✅ applied |
| step2_rpc_boundary.sql | ✅ applied |
| step2c_demote_truespend.sql | ✅ applied |
| step2d_truespend_app_role.sql | ✅ applied |
| step3_invoice_rpc_grants.sql | ✅ applied |
| step4_rls_truespend_app.sql | ✅ applied |
| step5_action_ledger.sql | ✅ applied (this session) |

### What step5 added to the live DB

**`action_ledger` table** — `UNIQUE(ticket_id, action)` is the idempotency gate:
- First `approve_and_commit` call: INSERT succeeds → proceeds normally
- Client retry / second concurrent approver: INSERT hits constraint → returns prior PO, zero side-effects
- RLS enabled, `truespend_app` + `truespend` policies added
- Doubles as the full audit trail (who / what / when / outcome / po_id)

**`approve_and_commit` — rewritten** (same 15-param signature, drop-in replacement):
1. `SELECT ticket FOR UPDATE` — serialises concurrent approvers at ticket level
2. Precondition check: raises `55000` if ticket not in `{pending_confirm, pending_review, signature_required, escalated}`
3. Action ledger INSERT claims the slot — `23505` on duplicate returns prior PO immediately
4. All original steps unchanged: `commit_budget` → PO insert → ticket status update

**`reject_ticket` — same hardening**: row lock + precondition + idempotent on duplicate

**DB constraints** (independent of UI — last line of defence):
- `purchase_orders`: `CHECK (amount > 0)`, `CHECK (amount_eur > 0)`
- `budget_positions`: `CHECK (budget >= 0)`, `CHECK (committed >= 0)`, `CHECK (spent >= 0)`

### Invariants — current status
- **I-1** ✅ RESOLVED: approve/reject/close all go through SECURITY DEFINER RPCs. `tickets.status` UPDATE grant = 0 for `truespend_app`. Verified by query.
- **I-2** ✅ RESOLVED: `truespend_app` (NOSUPERUSER) is the PostgREST login role. RLS policies cover all 17 protected tables.
- **I-8** ✅ ACTIVE: `scripts/db-migrate.sh` is the delivery mechanism. A migration file in git is NOT done until it appears in `schema_migrations`.

### PostgREST / intake app
- Runtime: `https://intake-production-84a0.up.railway.app` — ACTIVE
- JWT injected at container start via `/config.js` (not baked into bundle)
- Railway service source: `ghcr.io/eugnmueller-87/truespend-intake:latest` (image-only, not repo-connected)
- GitHub Actions builds the image on push and triggers Railway deploy via API

### n8n
- URL: `https://n8n-n3xl.eugenmueller.tech` — UP (fixed Bad Gateway this session)
- VPS: `root@187.127.87.206`, compose at `/docker/n8n-n3xl/`
- **KNOWN ISSUE — SLOW**: n8n is running on **SQLite** (default). No `DB_TYPE` set in `.env`.
  SQLite on Docker volume = high latency, no connection pooling, slow execution history queries.
- **Fix ready to apply** (see Task 1 below): migrate to Railway Postgres

---

## Tasks — in priority order

### Task 1 — n8n SQLite → Postgres (fixes slowness) 🔴 HIGH

**Root cause confirmed**: `/docker/n8n-n3xl/.env` has no `DB_TYPE` → n8n uses SQLite at `/home/node/.n8n/database.sqlite`. Every UI load hits that file.

**Fix**:
1. Create a dedicated `n8n` database on the Railway Postgres instance (separate from `truespend`):
   ```sql
   CREATE DATABASE n8n;
   CREATE USER n8n_user WITH PASSWORD '...';
   GRANT ALL ON DATABASE n8n TO n8n_user;
   ```
2. Add to `/docker/n8n-n3xl/.env`:
   ```
   DB_TYPE=postgresdb
   DB_POSTGRESDB_HOST=zephyr.proxy.rlwy.net
   DB_POSTGRESDB_PORT=24934
   DB_POSTGRESDB_DATABASE=n8n
   DB_POSTGRESDB_USER=n8n_user
   DB_POSTGRESDB_PASSWORD=...
   DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false
   ```
3. `docker compose down && docker compose up -d` on the VPS
4. n8n auto-migrates its schema on first boot — existing workflows/credentials are in the volume and will be re-imported, OR export first via n8n API before switching.

**WARNING**: Switching DB loses execution history from SQLite. Export workflows via n8n UI (Settings → Export) before the switch if history matters.

---

### Task 2 — Step 4: Graceful n8n degradation 🔴 HIGH

**Problem**: `App.jsx onAction` calls `n8nPost(...)` directly after `approve_and_commit` RPC. If n8n is down (as it was today), the approval **succeeds** (PO created in DB) but the UI throws an error — the user doesn't know if it worked.

**Plan**:

1. **`dispatch_queue` table** (new migration `step6_dispatch_queue.sql`):
   ```sql
   CREATE TABLE dispatch_queue (
     id           uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
     ticket_id    uuid REFERENCES tickets(id),
     event_type   text NOT NULL,   -- 'approved' | 'rejected' | 'closed'
     payload      jsonb NOT NULL,
     status       text NOT NULL DEFAULT 'pending',  -- pending | sent | failed | dead_letter
     attempts     int  NOT NULL DEFAULT 0,
     last_error   text,
     next_retry_at timestamptz,
     created_at   timestamptz NOT NULL DEFAULT now(),
     sent_at      timestamptz
   );
   ```

2. **Insert into `dispatch_queue` inside `approve_and_commit`** (after PO created, same transaction) — so if n8n is down, the row is queued and the RPC still returns success.

3. **`App.jsx` change**: after `pgRpc('approve_and_commit', ...)` succeeds, stop calling `n8nPost` directly. Show "Approved — notification queued" instead of trying n8n synchronously.

4. **n8n drains the queue**: a webhook or polling workflow reads `dispatch_queue WHERE status='pending'`, processes, marks `sent`. On failure: increment `attempts`, set `next_retry_at = now() + interval '2^attempts minutes'`. After 5 attempts: mark `dead_letter`.

5. **Ops Board alert**: if any `dispatch_queue` row is `dead_letter` or `pending` for >2 hours, show a banner on the board.

---

### Task 3 — Step 5: Reconciliation job 🟡 MEDIUM

A schedulable Node.js script (`scripts/reconcile.sh` or n8n workflow) that asserts:

1. `SUM(budget_positions.committed)` per branch/period = `SUM(purchase_orders.amount_eur)` for approved tickets in that period
2. Every ticket with `status='approved'` has a non-null `po_id` pointing to a real PO row
3. Every `action_ledger` row with `outcome='committed'` has a corresponding PO
4. No `dispatch_queue` row has been `pending` for more than N hours
5. Output: clean discrepancy report; optionally auto-heal simple cases (null po_id where PO exists)

---

### Task 4 — Demo readiness (open UX issues) 🟡 MEDIUM

Known broken screens (will crash if navigated to):
- **ContractsScreen** — referenced in routing (`App.jsx ~5407`) but component not defined
- **SearchScreen** — referenced in routing (`App.jsx ~5408`) but component not defined

Other UX gaps:
- No "Mark Delivered" button on Ops Board (webhook exists at `/webhook/delivery-confirmation` but no UI trigger)
- OrdersBoard column grid: header and row `gridTemplateColumns` are mismatched
- BudgetScreen issues (unverified since role-switcher fix)

---

## Key Credentials (all in `.env` — do not hardcode)

| What | Where |
|---|---|
| `DATABASE_URL` | `.env` — Railway Postgres at `zephyr.proxy.rlwy.net:24934` |
| `POSTGREST_JWT` | Railway intake service Variables + `.env` — `truespend_app` role token |
| n8n VPS | `root@187.127.87.206` — SSH key or password in your session |
| n8n `.env` | `/docker/n8n-n3xl/.env` on VPS |
| Traefik compose | `/docker/traefik/docker-compose.yml` on VPS |

## How to apply a new migration

```bash
# Add file to db/migrations/
# Add name to MIGRATION_ORDER in scripts/db-migrate.sh
# Then:
DATABASE_URL=postgresql://truespend:<REDACTED_ROTATE_ME>@zephyr.proxy.rlwy.net:24934/truespend \
  bash scripts/db-migrate.sh
```

Definition of done: file appears in `schema_migrations` table. Committed to git ≠ applied.

## How to deploy intake changes

```bash
# Push to main → GitHub Actions builds image → pushes to ghcr.io → triggers Railway deploy
git push origin main
# Monitor: https://github.com/eugnmueller-87/truespend → Actions tab
```

## Quick health checks

```bash
# PostgREST alive
curl -s https://postgrest-production-7960.up.railway.app/ | head -1

# n8n alive
curl -s -o /dev/null -w '%{http_code}' https://n8n-n3xl.eugenmueller.tech/healthz

# n8n down — restart:
ssh root@187.127.87.206 "cd /docker/n8n-n3xl && docker compose up -d"

# Migration status
DATABASE_URL=... bash scripts/db-migrate.sh --status
```
