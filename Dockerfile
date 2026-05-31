# TrueSpend Operations Board — Railway deployment
# Build context: repo root

# ── Stage 1: build ────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

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

# nginx:alpine entrypoint processes /etc/nginx/templates/*.template via envsubst
# before starting nginx — substitutes $PORT, leaves $uri/$host untouched.
# Cannot be bypassed by any Railway startCommand.
RUN mkdir -p /etc/nginx/templates
COPY intake/nginx.conf /etc/nginx/templates/default.conf.template

ENV PORT=8080
EXPOSE 8080
