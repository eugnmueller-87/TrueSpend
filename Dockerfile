# TrueSpend Operations Board — Railway deployment
# Build context: repo root

# ── Stage 1: build ────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Accept build-time env vars for Vite (baked into the JS bundle at build time)
ARG VITE_POSTGREST_URL
ARG VITE_POSTGREST_JWT
ARG VITE_N8N_WEBHOOK_URL
ARG VITE_N8N_WEBHOOK_BASE

ENV VITE_POSTGREST_URL=$VITE_POSTGREST_URL
ENV VITE_POSTGREST_JWT=$VITE_POSTGREST_JWT
ENV VITE_N8N_WEBHOOK_URL=$VITE_N8N_WEBHOOK_URL
ENV VITE_N8N_WEBHOOK_BASE=$VITE_N8N_WEBHOOK_BASE

COPY intake/package.json intake/package-lock.json* ./
RUN npm ci

COPY intake/ .
RUN npm run build

# ── Stage 2: serve ────────────────────────────────────────────
FROM nginx:1.27-alpine

COPY --from=builder /app/dist /usr/share/nginx/html

# Place config in /etc/nginx/templates/ — the official nginx:alpine entrypoint
# runs envsubst on every *.template file here into /etc/nginx/conf.d/ on boot,
# BEFORE nginx starts. This cannot be bypassed by any startCommand override.
COPY intake/nginx.conf /etc/nginx/templates/default.conf.template

# Default PORT for local Docker runs; Railway overrides this at runtime.
ENV PORT=8080

EXPOSE 8080
