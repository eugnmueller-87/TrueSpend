# ── Stage 1: build ────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Build-time env vars — set as Railway build variables (not secrets)
ARG VITE_POSTGREST_URL=https://postgrest-production-7960.up.railway.app
ARG VITE_POSTGREST_JWT
ARG VITE_N8N_WEBHOOK_URL=https://n8n-n3xl.eugenmueller.tech/webhook/intake
ARG VITE_N8N_WEBHOOK_BASE=https://n8n-n3xl.eugenmueller.tech/webhook

ENV VITE_POSTGREST_URL=$VITE_POSTGREST_URL
ENV VITE_POSTGREST_JWT=$VITE_POSTGREST_JWT
ENV VITE_N8N_WEBHOOK_URL=$VITE_N8N_WEBHOOK_URL
ENV VITE_N8N_WEBHOOK_BASE=$VITE_N8N_WEBHOOK_BASE

# Build context is repo root; intake/ contains the app
COPY intake/package.json intake/package-lock.json* ./
RUN npm ci --prefer-offline

COPY intake/ .
RUN npm run build

# ── Stage 2: serve ────────────────────────────────────────────
FROM nginx:1.27-alpine

# Copy built assets
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx config — replaces default
COPY intake/nginx.conf /etc/nginx/conf.d/default.conf

# Remove default nginx config that would conflict
RUN rm -f /etc/nginx/conf.d/default.conf.default

# nginx needs envsubst to inject N8N_WEBHOOK_URL at container start
RUN apk add --no-cache gettext

# Startup: substitute env vars into nginx config then launch
CMD ["/bin/sh", "-c", "envsubst '${N8N_WEBHOOK_URL}' < /etc/nginx/conf.d/default.conf > /tmp/default.conf && mv /tmp/default.conf /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]

EXPOSE 80
