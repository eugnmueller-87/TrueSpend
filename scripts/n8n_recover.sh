#!/usr/bin/env bash
# =============================================================================
# n8n_recover.sh — bring n8n back up on Postgres and load the workflows.
# RUN THIS ON THE VPS:  ssh root@187.127.87.206, then bash this script.
#
# Context (verified 2026-06-01 from the dev machine):
#   • The Railway `n8n` database ALREADY exists and ALREADY has the full n8n
#     schema (93 tables) — n8n was switched to Postgres in a prior session.
#   • BUT workflow_entity / credentials_entity are EMPTY — the old SQLite
#     workflows & credentials were never imported. That is why webhooks 404
#     and the instance looks "down/empty".
#   • n8n HTTP is currently unreachable (000) — container likely stopped.
#
# This script: (1) asserts the Postgres env is set, (2) brings the stack up,
# (3) waits for health, (4) imports every workflow JSON from the repo.
#
# Credentials still need to be re-created in the n8n UI (httpHeaderAuth for
# PostgREST, IMAP/SMTP, DocuSign) — they are NOT in the repo by design (I-6).
# =============================================================================
set -euo pipefail

COMPOSE_DIR="${COMPOSE_DIR:-/docker/n8n-n3xl}"
N8N_URL="${N8N_URL:-https://n8n-n3xl.eugenmueller.tech}"
ENV_FILE="$COMPOSE_DIR/.env"

echo "── 1. Verify Postgres config in $ENV_FILE ───────────────────────────────"
need=(DB_TYPE DB_POSTGRESDB_HOST DB_POSTGRESDB_PORT DB_POSTGRESDB_DATABASE DB_POSTGRESDB_USER DB_POSTGRESDB_PASSWORD)
missing=0
for k in "${need[@]}"; do
  if ! grep -q "^$k=" "$ENV_FILE" 2>/dev/null; then echo "  MISSING: $k"; missing=1; fi
done
if [[ $missing -eq 1 ]]; then
  cat <<'EOF'

  Add the following block to the .env (use the truespend creds OR a dedicated
  n8n_user you create — the n8n DB already exists on Railway):

    DB_TYPE=postgresdb
    DB_POSTGRESDB_HOST=zephyr.proxy.rlwy.net
    DB_POSTGRESDB_PORT=24934
    DB_POSTGRESDB_DATABASE=n8n
    DB_POSTGRESDB_USER=truespend
    DB_POSTGRESDB_PASSWORD=<REDACTED_ROTATE_ME>
    DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false

  Then re-run this script.
EOF
  exit 1
fi
echo "  ✓ Postgres env present."

echo "── 2. Restart the stack ─────────────────────────────────────────────────"
cd "$COMPOSE_DIR"
docker compose down
docker compose up -d
echo "  ✓ compose up issued."

echo "── 3. Wait for n8n health (up to ~90s) ──────────────────────────────────"
for i in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$N8N_URL/healthz" || true)
  if [[ "$code" == "200" ]]; then echo "  ✓ n8n healthy (200)."; break; fi
  echo "  …waiting ($i/30) — got $code"; sleep 3
  if [[ $i -eq 30 ]]; then echo "  ✗ n8n did not become healthy. Check: docker compose logs --tail=100"; exit 1; fi
done

echo "── 4. Import workflows from the repo ────────────────────────────────────"
# Requires the repo present on the VPS at $REPO_DIR, OR scp the workflows/ dir.
REPO_DIR="${REPO_DIR:-/docker/truespend}"
if [[ -d "$REPO_DIR/workflows" ]]; then
  # Import into the running container by copying files in and using the n8n CLI.
  CID=$(docker compose ps -q n8n)
  docker cp "$REPO_DIR/workflows" "$CID:/tmp/workflows"
  docker compose exec -T n8n sh -lc '
    for f in $(find /tmp/workflows -name "*.json"); do
      echo "importing $f"; n8n import:workflow --input="$f" || echo "  (skip $f)";
    done'
  echo "  ✓ workflow import attempted. Open the UI and ACTIVATE each workflow + attach credentials."
else
  echo "  ! Repo not found at $REPO_DIR. Either clone it there or scp workflows/ and re-run step 4."
  echo "    Alternatively import each JSON manually via the n8n UI (Workflows → Import from File)."
fi

echo ""
echo "DONE. Next manual steps in the n8n UI:"
echo "  • Re-create credentials (PostgREST httpHeaderAuth, IMAP/SMTP, DocuSign) — not in repo per I-6."
echo "  • Activate each imported workflow."
echo "  • Confirm webhooks resolve: curl -i $N8N_URL/webhook/delivery-confirmation"
