# ── Stage 1: build ────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci --prefer-offline

COPY . .
RUN npm run build

# ── Stage 2: serve ────────────────────────────────────────────
FROM nginx:1.27-alpine

# Copy built assets
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx config — replaces default
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Remove default nginx config that would conflict
RUN rm -f /etc/nginx/conf.d/default.conf.default

# nginx needs envsubst to inject N8N_WEBHOOK_URL at container start
RUN apk add --no-cache gettext

# Startup: substitute env vars into nginx config then launch
CMD ["/bin/sh", "-c", "envsubst '${N8N_WEBHOOK_URL}' < /etc/nginx/conf.d/default.conf > /tmp/default.conf && mv /tmp/default.conf /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]

EXPOSE 80
