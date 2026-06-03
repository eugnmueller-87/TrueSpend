#!/bin/sh
set -e

# ── Runtime config injection ──────────────────────────────────
# Writes config.js into the nginx WEB ROOT so it is served as an ordinary static
# file. Earlier this wrote to /etc/nginx/conf.d/config.js and relied on a custom
# `location /config.js { alias ... }` block — but the official nginx entrypoint's
# envsubst pass rewrote the template and dropped that block, so /config.js 404'd
# and the SPA shipped with no PostgREST token. Writing into the web root needs no
# special nginx config and can't be clobbered by envsubst.
# SPA reads window.__CONFIG__ — no token baked into the JS bundle.
# Set POSTGREST_JWT in Railway service Variables to inject the token.
# Rotating credentials = env change + redeploy, no rebuild needed.

WEBROOT=/usr/share/nginx/html

if [ -z "${POSTGREST_JWT:-}" ]; then
  echo "[entrypoint] WARNING: POSTGREST_JWT env var not set — app will have no token"
fi

cat > "$WEBROOT/config.js" <<EOF
window.__CONFIG__ = {
  POSTGREST_URL: "${POSTGREST_URL:-https://postgrest-production-7960.up.railway.app}",
  POSTGREST_JWT: "${POSTGREST_JWT:-}",
  N8N_WEBHOOK_URL: "${N8N_WEBHOOK_URL:-https://n8n-n3xl.eugenmueller.tech/webhook/intake}",
  N8N_WEBHOOK_BASE: "${N8N_WEBHOOK_BASE:-https://n8n-n3xl.eugenmueller.tech/webhook}"
};
EOF

echo "[entrypoint] config.js written to $WEBROOT (POSTGREST_JWT set: $([ -n "${POSTGREST_JWT:-}" ] && echo yes || echo NO))"

# Hand off to official nginx entrypoint (runs envsubst on templates/, starts nginx)
exec /nginx-entrypoint.sh "$@"
