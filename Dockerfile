# TrueSpend Operations Board — Railway deployment
# Build context: repo root

# ── Stage 1: build ────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Accept build-time env vars for Vite
ARG VITE_POSTGREST_URL
ARG VITE_POSTGREST_JWT
ARG VITE_N8N_WEBHOOK_URL

ENV VITE_POSTGREST_URL=$VITE_POSTGREST_URL
ENV VITE_POSTGREST_JWT=$VITE_POSTGREST_JWT
ENV VITE_N8N_WEBHOOK_URL=$VITE_N8N_WEBHOOK_URL

COPY intake/package.json intake/package-lock.json* ./
RUN npm ci

COPY intake/ .
RUN npm run build

# ── Stage 2: serve ────────────────────────────────────────────
FROM nginx:1.27-alpine

COPY --from=builder /app/dist /usr/share/nginx/html
COPY intake/nginx.conf /etc/nginx/conf.d/default.conf.template
COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN rm -f /etc/nginx/conf.d/default.conf \
 && apk add --no-cache gettext \
 && chmod +x /docker-entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]
