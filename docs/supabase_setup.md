# Supabase Setup — TrueSpend

## What you need
- A Supabase account (free tier works for setup; Pro for production)
- About 10 minutes

---

## Step 1 — Create the project

1. Go to [supabase.com](https://supabase.com) → **New project**
2. Name it `truespend`
3. Set a strong database <REDACTED_ROTATE_ME> — **save it**, you'll need it for Grafana
4. Region: choose closest to your users (Frankfurt for EU)
5. Wait ~2 minutes for provisioning

---

## Step 2 — Get your credentials

Go to **Settings → API**. Copy:

| Variable | Where to find it |
|---|---|
| `SUPABASE_URL` | Project URL (e.g. `https://abcdefgh.supabase.co`) |
| `SUPABASE_SERVICE_ROLE_KEY` | `service_role` key (click "Reveal") |

Go to **Settings → Database**. Copy:

| Variable | Where to find it |
|---|---|
| `SUPABASE_DB_HOST` | Host (e.g. `db.abcdefgh.supabase.co`) |
| `SUPABASE_DB_PASSWORD` | The <REDACTED_ROTATE_ME> you set in Step 1 |

Paste all of these into your `.env` file.

---

## Step 3 — Run the schema

Open the **SQL Editor** in your Supabase dashboard.

Run files **in this exact order** (copy/paste each into the editor):

```
1. db/schema.sql          ← creates all tables, views, indexes, RLS
2. db/seed/01_branches.sql
3. db/seed/02_managers.sql
4. db/seed/03_suppliers.sql
5. db/seed/04_contracts.sql
6. db/seed/05_contract_changes.sql
7. db/seed/06_budget_positions.sql
8. db/seed/07_hyperscaler_positions.sql
```

> **Why this order?** Each seed file references UUIDs from the previous one.
> Running out of order will fail with foreign key constraint errors.

---

## Step 4 — Verify RLS is working

Run this in the SQL Editor to confirm RLS is enabled:

```sql
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in ('contracts','tickets','decisions','suppliers','budget_positions');
```

Expected: all 5 rows show `rowsecurity = true`.

---

## Step 5 — Verify seed data

Quick sanity checks:

```sql
-- Should return 10 branches
select count(*) from branches;

-- Should return 17 suppliers
select count(*) from suppliers;

-- Should return 20 contracts
select count(*) from contracts;

-- Should return contracts expiring in next 90 days
select name, expiry_date, renewal_state, days_remaining
from contracts_expiring
order by days_remaining;

-- Should show one overshoot_risk = true (AWS Global HQ)
select provider, branch_id, overshoot_risk, undershoot_risk
from hyperscaler_positions;
```

---

## Step 6 — Enable pg_net (for webhook calls from Supabase, optional)

Only needed if you want Supabase to push events to n8n directly.

```sql
create extension if not exists pg_net;
```

---

## Done

Your Supabase project is ready. n8n will connect via the service role key.
Grafana will connect directly to the PostgreSQL database.

Next: **[n8n Setup →](n8n_setup.md)**
