# Runbook — n8n box (srv1684424 / 187.127.87.206)

> This box hosts TrueSpend's n8n. The OTHER VPS (srv1638260 / 187.124.14.81) is the
> trading/"pantheon" box — never deploy TrueSpend there.

## What runs here

| Path | What | Supervision |
|---|---|---|
| `/docker/n8n-n3xl/` | n8n (SQLite) + Traefik routing | `docker compose`, `restart: unless-stopped` |
| `/docker/traefik/` | Traefik reverse proxy (TLS) | compose |
| `/docker/dispatch-drain/` | dispatch_queue drainer (node:20-alpine) | compose, `restart: unless-stopped`, loops 30s |
| `/opt/n8n-watchdog/` | healthz watchdog → auto-restart n8n | cron `* * * * *` |

## The 2026-06-01 stability hardening (three independent guardrails)

n8n had been OOM-crash-looping: SQLite bloated to 1.58 GB from 125k orphaned executions,
and the box had **no swap**, so a memory spike = instant exit-137 kill → restart loop.

1. **Swap** — 2 GB swapfile (`/swapfile`, in `/etc/fstab`), `vm.swappiness=10`
   (`/etc/sysctl.conf`). A spike now degrades to slow, not dead.
2. **Execution caps** — in `/docker/n8n-n3xl/docker-compose.yml`:
   `EXECUTIONS_DATA_PRUNE=true`, `MAX_AGE=168` (7d), `PRUNE_MAX_COUNT=10000`,
   `SAVE_ON_SUCCESS=none`, `SAVE_ON_ERROR=all`. Stops the DB rebloating.
3. **Watchdog** — `/opt/n8n-watchdog/watchdog.sh` every minute: 3 failed `/healthz`
   → `docker compose up -d` + logs `n8n_auto_restart` to `trace_log` (shows on Ops Board).

Backup of the pre-prune SQLite (1.5 GB, integrity ok): `/root/n8n_backup/` on the box.

## Common operations

```bash
# health
curl -s -o /dev/null -w '%{http_code}\n' https://n8n-n3xl.eugenmueller.tech/healthz

# n8n logs / restart
cd /docker/n8n-n3xl && docker compose logs --tail 50 && docker compose up -d

# drain status (should print a loop line + periodic "drained:" lines)
cd /docker/dispatch-drain && docker compose logs --tail 20

# watchdog log
journalctl -t n8n-watchdog --no-pager | tail

# DB size sanity (should stay small, low-MB)
docker run --rm -v n8n-n3xl_n8n_data:/d alpine ls -lh /d/database.sqlite
```

## The drainer

Drains `dispatch_queue` (the durable outbox money RPCs write to). Per event:
`claim_dispatch_batch` → deliver → `mark_dispatch_sent` / `mark_dispatch_failed`
(exp backoff, dead-letter at 5). `delivered` events call the delivery-confirmation
webhook **if** `N8N_WEBHOOK_USER`/`N8N_WEBHOOK_PASS` are set in
`/docker/dispatch-drain/.env`; otherwise they fall back to a `trace_log` audit row
(so they never dead-letter on the webhook's basic-auth). Source of truth:
`scripts/drain_dispatch.js` in the repo.

To update the drainer: copy the new `scripts/drain_dispatch.js` to
`/docker/dispatch-drain/drain_dispatch.js` and `docker compose restart`.
