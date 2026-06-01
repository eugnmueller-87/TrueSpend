#!/usr/bin/env node
// =============================================================================
// drain_dispatch.js — drain the dispatch_queue outbox (Handover Task 2).
//
// Why a Node script and not (only) an n8n workflow: n8n is the flaky component
// this whole outbox exists to insulate against. A standalone drainer keeps
// notifications flowing even while n8n is down, and can run from cron, a
// Railway cron service, or `node scripts/drain_dispatch.js` by hand.
//
// Flow per tick:
//   1. claim_dispatch_batch(N)  — atomically grab up to N due rows (SKIP LOCKED,
//      bumps attempts) so concurrent drainers never double-send.
//   2. For each row, perform the downstream side-effect (here: write a trace_log
//      entry — the system's audit/notification substrate; swap for Slack/ERP as
//      those integrations come online).
//   3. mark_dispatch_sent(id) on success, else mark_dispatch_failed(id, err)
//      which applies exponential backoff and dead-letters after 5 attempts.
//
// Usage:
//   node scripts/drain_dispatch.js            # one drain pass, exits
//   node scripts/drain_dispatch.js --loop     # drain every 30s until killed
//   node scripts/drain_dispatch.js --limit 50 # batch size (default 20)
//
// Env (read from .env, falls back to process.env):
//   DATABASE_URL, POSTGREST_URL, POSTGREST_JWT
// =============================================================================
const { Client } = require('pg')
const fs = require('fs')
const path = require('path')

const repoRoot = path.resolve(__dirname, '..')
function loadEnv(k) {
  if (process.env[k]) return process.env[k]
  try {
    const lines = fs.readFileSync(path.join(repoRoot, '.env'), 'utf8').replace(/^﻿/, '').split('\n')
    const l = lines.find(x => x.startsWith(k + '='))
    return l ? l.replace(k + '=', '').trim() : null
  } catch { return null }
}

const DATABASE_URL = loadEnv('DATABASE_URL')
const POSTGREST_URL = loadEnv('POSTGREST_URL')
const POSTGREST_JWT = loadEnv('POSTGREST_JWT')
const N8N_WEBHOOK_BASE = loadEnv('N8N_WEBHOOK_BASE')
const N8N_WEBHOOK_USER = loadEnv('N8N_WEBHOOK_USER')  // optional: basic-auth for delivery webhook
const N8N_WEBHOOK_PASS = loadEnv('N8N_WEBHOOK_PASS')

const args = process.argv.slice(2)
const LOOP = args.includes('--loop')
const limitIdx = args.indexOf('--limit')
const LIMIT = limitIdx >= 0 ? parseInt(args[limitIdx + 1], 10) || 20 : 20
const INTERVAL_MS = 30000

// ── Downstream side-effect for one dispatched event ──────────────────────────
// Writes a trace_log row via PostgREST. Throws on any non-2xx so the row is
// retried with backoff. Replace/extend this with Slack/ERP calls as needed.
async function deliver(row) {
  const { event_type, payload } = row

  // Delivery events fan out to the delivery-confirmation workflow (invoice
  // match, SLA flagging) — the durable replacement for OrdersBoard's old
  // browser fire-and-forget webhook. That webhook requires HTTP Basic auth
  // (WWW-Authenticate: Basic realm="Webhook"). If creds are configured
  // (N8N_WEBHOOK_USER/PASS) we call it; otherwise we fall back to a trace_log
  // audit row so the event still delivers durably instead of 401-looping to
  // dead-letter. (The old browser fetch sent no auth and was silently 401'd —
  // this path is strictly more reliable.)
  if (event_type === 'delivered' && N8N_WEBHOOK_BASE && N8N_WEBHOOK_USER && N8N_WEBHOOK_PASS) {
    const auth = Buffer.from(`${N8N_WEBHOOK_USER}:${N8N_WEBHOOK_PASS}`).toString('base64')
    const r = await fetch(`${N8N_WEBHOOK_BASE}/delivery-confirmation`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Basic ${auth}` },
      body: JSON.stringify({
        po_id: payload.po_id,
        po_number: payload.po_number,
        delivered_at: payload.delivered_at,
        confirmed_by: payload.confirmed_by,
      }),
    })
    if (!r.ok) {
      const txt = await r.text().catch(() => '')
      throw new Error(`delivery-confirmation webhook ${r.status}: ${txt.slice(0, 200)}`)
    }
    return
  }
  // else: fall through to the trace_log audit write below (covers 'delivered'
  // when webhook creds are absent, plus approved/rejected/closed).

  const verb = event_type === 'approved'  ? 'PO approved & committed'
             : event_type === 'rejected'  ? 'Request rejected, budget released'
             : event_type === 'delivered' ? 'Delivery confirmed'
             : 'Request closed'
  // trace_log schema: signal + value are NOT NULL; notes is free text.
  // (No ticket_id FK on trace_log — see CLAUDE.md. We embed it in notes.)
  const body = {
    signal: 'contract',
    value: `dispatch_${event_type}`,
    notes: `${verb} — ${JSON.stringify(payload)}`,
    created_at: new Date().toISOString(),
  }
  const r = await fetch(`${POSTGREST_URL}/trace_log`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${POSTGREST_JWT}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  })
  if (!r.ok) {
    const txt = await r.text().catch(() => '')
    throw new Error(`trace_log POST ${r.status}: ${txt.slice(0, 200)}`)
  }
}

async function drainOnce(client) {
  const { rows } = await client.query('SELECT * FROM claim_dispatch_batch($1)', [LIMIT])
  if (!rows.length) return { claimed: 0, sent: 0, failed: 0 }
  let sent = 0, failed = 0
  for (const row of rows) {
    try {
      await deliver(row)
      await client.query('SELECT mark_dispatch_sent($1)', [row.id])
      sent++
    } catch (e) {
      await client.query('SELECT mark_dispatch_failed($1,$2)', [row.id, String(e.message || e).slice(0, 500)])
      failed++
    }
  }
  return { claimed: rows.length, sent, failed }
}

;(async () => {
  if (!DATABASE_URL) { console.error('DATABASE_URL not set'); process.exit(1) }
  const client = new Client({ connectionString: DATABASE_URL, ssl: false })
  await client.connect()

  const tick = async () => {
    const r = await drainOnce(client)
    if (r.claimed) console.log(`[${new Date().toISOString()}] drained: claimed=${r.claimed} sent=${r.sent} failed=${r.failed}`)
  }

  if (LOOP) {
    console.log(`drain_dispatch: looping every ${INTERVAL_MS / 1000}s (limit ${LIMIT}). Ctrl-C to stop.`)
    await tick()
    setInterval(tick, INTERVAL_MS)
  } else {
    await tick()
    await client.end()
  }
})().catch(e => { console.error('FATAL:', e.message); process.exit(1) })
