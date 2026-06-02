# Grafana Setup — TrueSpend

## What you need
- Supabase already set up (PostgreSQL connection details in `.env`)
- Docker (local) or a Grafana Cloud account

---

## Option A — Local with Docker (auto-provisioned)

If you already ran `docker compose up -d`, Grafana is at **http://localhost:3000**.

Login: `admin` / value of `GF_SECURITY_ADMIN_PASSWORD` from `.env`

The datasource and dashboard are **auto-provisioned** from:
- `infra/grafana/provisioning/datasources/supabase.yml`
- `infra/grafana/provisioning/dashboards/truespend.yml`
- `grafana/dashboards/truespend_main.json`

Skip to **Step 3 — Verify**.

---

## Option B — Grafana Cloud

1. Sign up at [grafana.com](https://grafana.com)
2. Go to **Connections → Add new connection → PostgreSQL**
3. Fill in:

| Field | Value |
|---|---|
| Host | `SUPABASE_DB_HOST:5432` |
| Database | `postgres` |
| User | `postgres` |
| Password | Your Supabase DB <REDACTED_ROTATE_ME> |
| SSL Mode | `require` |
| Version | `15` |

4. Click **Save & Test** — should show "Database Connection OK"
5. In the datasource settings, note the **UID** — update `truespend_main.json` if it's not `supabase-pg`

---

## Step 2 — Import the dashboard

1. Grafana sidebar → **Dashboards → Import**
2. Upload `grafana/dashboards/truespend_main.json`
3. Select datasource: **Supabase PostgreSQL**
4. Click **Import**

---

## Step 3 — Verify panels are loading

The dashboard has 10 panels:

| Panel | What it shows | Expected with seed data |
|---|---|---|
| Total Transactions | All tickets count | 0 (no live tickets yet) |
| Auto-Executed | disposition = auto_execute | 0 |
| Auto-Execute Rate | % auto | 0% |
| Pending Human Action | pending_confirm + escalated | 0 |
| Contracts Expiring | ≤90 days | 13 contracts |
| Expiring Contracts Table | Name, days, renewal_state | Full list |
| Supplier Health | green/watch/red breakdown | 3 red, ~5 watch |
| Hyperscaler MTD Spend | Bar gauge per provider | AWS €898k, GCP €372k |
| Agent Decisions Timeline | decisions over time | Empty (no decisions yet) |
| Weekly Digest | pending_confirm + escalated | Empty (no decisions yet) |

> Contracts Expiring and Supplier Health panels should populate immediately
> from seed data. Decision-based panels populate once n8n runs.

---

## Step 4 — Set up alerts (optional but recommended)

In Grafana: **Alerting → Alert rules → New alert rule**

Suggested alerts:

```
Name: Contracts Expiring in 14 Days
Query: SELECT count(*) FROM contracts WHERE expiry_date <= current_date + 14
Condition: IS ABOVE 0
Contact: Slack #procurement-alerts

Name: Supplier Health Red
Query: SELECT count(*) FROM suppliers WHERE health = 'red'
Condition: IS ABOVE 0
Contact: Slack #procurement-alerts

Name: Hyperscaler Overshoot Risk
Query: SELECT count(*) FROM hyperscaler_positions WHERE overshoot_risk = true AND snapshot_date = current_date
Condition: IS ABOVE 0
Contact: Slack #procurement-alerts
```

---

## Dashboard auto-refresh

The dashboard is configured to refresh every **5 minutes**.
For real-time monitoring, set to 1 minute in the top-right time picker dropdown.

---

Next: **[Intake UI →](intake_setup.md)**
