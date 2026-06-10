// =============================================================================
// api/client.js — the SINGLE chokepoint for every browser->backend call.
//
// Phase 2 extraction (no behavior change in this step): the pgFetch/pgPatch/
// pgRpc helpers and the raw fetch() call sites scattered through App.jsx are
// consolidated here so that the later fail-closed re-routes (money writes ->
// n8n webhook) are a handful of edits in ONE file instead of surgery across
// ~5,400 lines.
//
// Config resolution mirrors App.jsx exactly:
//   window.__CONFIG__ (runtime /config.js) -> import.meta.env.VITE_* -> fallback
//
// SECURITY NOTE (Phase 2): POSTGREST_JWT is the browser-shipped token. After the
// money re-route + fail-closed flip, this token must NOT be able to call a money
// RPC or write /users·/budget_positions directly. Today it still can; the
// `routeMoneyThroughN8n` switch below is the seam that flips that.
// =============================================================================

const __CFG = (typeof window !== 'undefined' && window.__CONFIG__) || {}

export const POSTGREST_URL =
  __CFG.POSTGREST_URL || import.meta.env.VITE_POSTGREST_URL ||
  'https://postgrest-production-7960.up.railway.app'

export const POSTGREST_JWT =
  __CFG.POSTGREST_JWT || import.meta.env.VITE_POSTGREST_JWT || ''

export const N8N_WEBHOOK =
  __CFG.N8N_WEBHOOK_URL || import.meta.env.VITE_N8N_WEBHOOK_URL ||
  'https://n8n-n3xl.eugenmueller.tech/webhook/intake'

export const N8N_WEBHOOK_BASE =
  __CFG.N8N_WEBHOOK_BASE || import.meta.env.VITE_N8N_WEBHOOK_BASE ||
  'https://n8n-n3xl.eugenmueller.tech/webhook'

// ── PostgREST reads/writes (browser token) ──────────────────────────────────

export async function pgFetch(path) {
  const r = await fetch(`${POSTGREST_URL}${path}`, {
    headers: { Authorization: `Bearer ${POSTGREST_JWT}`, Accept: 'application/json' }
  })
  if (!r.ok) throw new Error(`PostgREST ${r.status}`)
  return r.json()
}

export async function pgPost(path, body) {
  const r = await fetch(`${POSTGREST_URL}${path}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${POSTGREST_JWT}`, 'Content-Type': 'application/json', Prefer: 'return=representation' },
    body: JSON.stringify(body),
  })
  if (!r.ok) { const t = await r.text().catch(() => ''); throw new Error(t || `PostgREST POST ${r.status}`) }
  return r.json()
}

export async function pgPatch(path, body) {
  const r = await fetch(`${POSTGREST_URL}${path}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${POSTGREST_JWT}`, 'Content-Type': 'application/json', Prefer: 'return=representation' },
    body: JSON.stringify(body)
  })
  if (!r.ok) throw new Error(`PostgREST PATCH ${r.status}`)
  return r.json()
}

export async function pgRpc(fn, body) {
  const r = await fetch(`${POSTGREST_URL}/rpc/${fn}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${POSTGREST_JWT}`, 'Content-Type': 'application/json', Prefer: 'return=representation' },
    body: JSON.stringify(body),
  })
  const payload = await r.json().catch(() => ({}))
  if (!r.ok) throw new Error(payload?.message || payload?.hint || `RPC ${fn} ${r.status}`)
  return payload
}

// ── n8n webhooks (server holds the privileged JWT; browser carries no creds) ──

// POST to the canonical intake webhook (full URL incl. /intake).
export async function postIntake(body, opts = {}) {
  const r = await fetch(N8N_WEBHOOK, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    ...opts,
  })
  if (!r.ok) throw new Error(`n8n ${r.status}`)
  return r.json().catch(() => ({}))
}

// POST to an arbitrary webhook path under N8N_WEBHOOK_BASE (e.g. '/board-action',
// '/docusign-sign', '/supplier-onboarding', '/chat'). headers/signal pass through.
export async function postWebhook(path, body, opts = {}) {
  const r = await fetch(`${N8N_WEBHOOK_BASE}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(opts.headers || {}) },
    body: JSON.stringify(body),
    ...opts,
  })
  if (!r.ok) throw new Error(`n8n ${path} ${r.status}`)
  return r.json().catch(() => ({}))
}

// =============================================================================
// MONEY-ACTION SEAM (Phase 2)
// -----------------------------------------------------------------------------
// `routeMoneyThroughN8n` is the single switch that flips money writes off the
// browser token and onto the server-side /webhook/board-action workflow. While
// false, boardAction() calls the SECURITY DEFINER RPC directly (legacy path).
// When the n8n board-action workflow + interim privileged token are live, set
// VITE_ROUTE_MONEY_VIA_N8N=true (or window.__CONFIG__.ROUTE_MONEY_VIA_N8N) and
// every money action goes through n8n — the browser token can then be a
// read-only token and the RPC guards can go fail-closed without bricking.
// =============================================================================
export const routeMoneyThroughN8n =
  (__CFG.ROUTE_MONEY_VIA_N8N ?? import.meta.env.VITE_ROUTE_MONEY_VIA_N8N) === true ||
  (__CFG.ROUTE_MONEY_VIA_N8N ?? import.meta.env.VITE_ROUTE_MONEY_VIA_N8N) === 'true'

// boardAction — the ONE entry point for board money/state actions. Either calls
// the RPC directly (legacy) or posts {action, ...} to /webhook/board-action.
// `rpcName` + `rpcBody` describe the direct call; `webhookAction` is the action
// key the board-action workflow switches on.
export async function boardAction({ rpcName, rpcBody, webhookAction, webhookBody }) {
  if (routeMoneyThroughN8n) {
    return postWebhook('/board-action', { action: webhookAction, ...webhookBody })
  }
  return pgRpc(rpcName, rpcBody)
}
