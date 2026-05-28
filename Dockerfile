# TrueSpend Operations Board — Railway deployment
# Build context: repo root

# ── Stage 1: build ────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

COPY intake/package.json intake/package-lock.json* ./
RUN npm ci --prefer-offline

COPY intake/ .
RUN npm run build

# ── Stage 2: serve ────────────────────────────────────────────
FROM nginx:1.27-alpine

COPY --from=builder /app/dist /usr/share/nginx/html
COPY intake/nginx.conf /etc/nginx/conf.d/default.conf

RUN rm -f /etc/nginx/conf.d/default.conf.default
RUN apk add --no-cache gettext

EXPOSE 80

CMD ["/bin/sh", "-c", "envsubst '${N8N_WEBHOOK_URL}' < /etc/nginx/conf.d/default.conf > /tmp/nginx.conf && mv /tmp/nginx.conf /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
