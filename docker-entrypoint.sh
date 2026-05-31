#!/bin/sh
set -e

# Railway injects $PORT at runtime. Default to 80 for local/Docker Compose.
PORT="${PORT:-80}"
export PORT

echo "[entrypoint] Configuring nginx on port $PORT"

# Substitute only $PORT in the nginx template — leave nginx variables ($uri, $host etc.) untouched
envsubst '$PORT' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

echo "[entrypoint] nginx config written:"
head -3 /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'
