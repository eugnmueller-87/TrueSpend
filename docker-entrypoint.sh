#!/bin/sh
set -e

# ── Runtime config injection ──────────────────────────────────
# Writes /etc/nginx/conf.d/config.js from env vars at container start.
# SPA reads window.__CONFIG__ — no token baked into the JS bundle.
# Set POSTGREST_JWT in Railway service Variables to inject the token.
# Rotating credentials = env change + redeploy, no rebuild needed.

if [ -z "${POSTGREST_JWT:-}" ]; then
  echo "[entrypoint] WARNING: POSTGREST_JWT env var not set — app will use JS fallback"
fi

cat > /etc/nginx/conf.d/config.js <<EOF
window.__CONFIG__ = {
  POSTGREST_URL: "${POSTGREST_URL:-https://postgrest-production-7960.up.railway.app}",
  POSTGREST_JWT: "${POSTGREST_JWT:-}",
  N8N_WEBHOOK_URL: "${N8N_WEBHOOK_URL:-https://n8n-n3xl.eugenmueller.tech/webhook/intake}",
  N8N_WEBHOOK_BASE: "${N8N_WEBHOOK_BASE:-https://n8n-n3xl.eugenmueller.tech/webhook}"
};
EOF

echo "[entrypoint] config.js written (POSTGREST_JWT set: $([ -n "${POSTGREST_JWT:-}" ] && echo yes || echo NO))"

# Hand off to official nginx entrypoint (runs envsubst on templates/, starts nginx)
exec /nginx-entrypoint.sh "$@"
