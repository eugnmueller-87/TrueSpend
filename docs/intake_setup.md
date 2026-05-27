# Intake UI Setup — TrueSpend

The intake UI is a React 18 + Vite app. Dark theme, mobile-first, step-based.
Stakeholders submit requests through it — no Jira, no email, no forms to figure out.

## What you need
- Node.js 18+ installed
- n8n running with `intake_receiver.json` active (webhook must be live)

---

## Step 1 — Install dependencies

```bash
cd TrueSpend/intake
npm install
```

---

## Step 2 — Run locally

```bash
npm run dev
```

Open **http://localhost:5173**

The Vite config proxies `/api/intake` → `http://localhost:5678/webhook/truespend-intake`
so it just works locally without CORS issues.

---

## Step 3 — Test the flow

1. Open http://localhost:5173
2. Select a ticket type (e.g. "Approve a purchase")
3. Fill in the form fields
4. Submit
5. You should see:
   - Animated checkmark ✓
   - Reference number (e.g. `TS-2026-0001`)
   - "You can close this tab."
6. In Supabase → SQL Editor, run:
   ```sql
   select reference, status, title, disposition
   from tickets
   order by created_at desc
   limit 5;
   ```
   You should see the new ticket.

---

## Step 4 — Build for production

```bash
npm run build
```

Output is in `intake/dist/`. Deploy to any static host:

| Option | Command / Steps |
|---|---|
| **Vercel** | `cd intake && npx vercel` — free, instant |
| **Netlify** | Drag `intake/dist/` to app.netlify.com |
| **Cloudflare Pages** | Connect repo → build cmd: `npm run build` → output: `dist` |
| **Nginx** | Serve `dist/` as static, proxy `/api/` to n8n URL |

---

## Step 5 — Production: update the API URL

For production, the Vite proxy doesn't apply (it's dev-only).

Edit `intake/vite.config.js` for dev proxy — but for production build,
set the webhook URL directly in `intake/src/App.jsx`:

Find the `handleSubmit` function and update:

```js
// Development (Vite proxy handles it):
const res = await fetch('/api/intake', { ... })

// Production (set your n8n public URL):
const res = await fetch('https://your-n8n-domain.com/webhook/truespend-intake', { ... })
```

Or better — use an environment variable:

```js
const WEBHOOK_URL = import.meta.env.VITE_WEBHOOK_URL || '/api/intake'
const res = await fetch(WEBHOOK_URL, { ... })
```

Then set `VITE_WEBHOOK_URL=https://your-n8n.com/webhook/truespend-intake` in your hosting env.

---

## Supported ticket types

| Type | Fields collected |
|---|---|
| `renew_contract` | Supplier, contract ref, branch, notes |
| `approve_purchase` | Supplier, description, amount, currency, urgency, branch |
| `onboard_supplier` | Supplier name, country, category, use case, estimated value, branch |
| `other` | Free text description, branch |

All types collect: submitter name, submitter email.

---

Done. The intake UI is your front door — stakeholders never need to touch anything else.
