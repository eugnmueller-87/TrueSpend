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

# Write the nginx template directly — avoids COPY path issues and cannot be
# bypassed by any Railway startCommand override. The official nginx:alpine
# entrypoint runs envsubst on /etc/nginx/templates/*.template before starting nginx.
RUN printf 'server {\n\
    listen ${PORT};\n\
    server_name _;\n\
\n\
    root /usr/share/nginx/html;\n\
    index index.html;\n\
\n\
    location / {\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
\n\
    add_header X-Frame-Options "SAMEORIGIN" always;\n\
    add_header X-Content-Type-Options "nosniff" always;\n\
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;\n\
\n\
    location ~* \\.(js|css|png|svg|ico|woff2?)$ {\n\
        expires 1y;\n\
        add_header Cache-Control "public, immutable";\n\
    }\n\
\n\
    gzip on;\n\
    gzip_types text/plain text/css application/javascript application/json;\n\
    gzip_min_length 1024;\n\
}\n' > /etc/nginx/templates/default.conf.template

# Default PORT for local runs; Railway overrides at runtime
ENV PORT=8080

EXPOSE 8080
