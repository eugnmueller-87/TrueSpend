# TrueSpend Operations Board — Railway deployment
# Build context: repo root

# ── Stage 1: build ────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# No VITE_POSTGREST_JWT at build time — token is injected at runtime via /config.js
ARG VITE_POSTGREST_URL
ARG VITE_N8N_WEBHOOK_URL
ARG VITE_N8N_WEBHOOK_BASE

ENV VITE_POSTGREST_URL=$VITE_POSTGREST_URL
ENV VITE_N8N_WEBHOOK_URL=$VITE_N8N_WEBHOOK_URL
ENV VITE_N8N_WEBHOOK_BASE=$VITE_N8N_WEBHOOK_BASE

COPY intake/package.json intake/package-lock.json* ./
RUN npm ci

COPY intake/ .
RUN npm run build

# ── Stage 2: serve ────────────────────────────────────────────
FROM nginx:1.27-alpine

COPY --from=builder /app/dist /usr/share/nginx/html

# Rename the official nginx entrypoint so our wrapper can call it
RUN mv /docker-entrypoint.sh /nginx-entrypoint.sh

# nginx template — /nginx-entrypoint.sh substitutes $PORT before starting nginx
RUN mkdir -p /etc/nginx/templates
COPY intake/nginx.conf /etc/nginx/templates/default.conf.template

# Our entrypoint: writes /etc/nginx/conf.d/config.js from runtime env vars,
# then calls /nginx-entrypoint.sh which runs envsubst on templates and starts nginx.
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
