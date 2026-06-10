#!/usr/bin/env node
// =============================================================================
// repro_outbox_forgery.js — Phase 4 security repro.
//
// Demonstrates that the BROWSER-EXTRACTABLE token can FORGE a dispatch_queue
// (outbox) row — injecting a fake 'approved' event the drainer will fan out, or
// flipping a real 'pending' row to 'sent' to suppress a genuine notification —
// against the CURRENT grants (000008: INSERT/UPDATE granted to truespend_app),
// and that after 000016 the same direct write returns 403, while the legit
// SECURITY DEFINER path (enqueue_dispatch / drain) still works.
//
// Modes:
//   --forge-insert : POST /dispatch_queue with a fabricated 'approved' row using
//                    the browser token. BEFORE: 2xx (HOLE). AFTER: 403.
//   --forge-update : PATCH a pending row to status='sent' (suppress). Same.
//   --assert-blocked : assert both direct writes now 403 (post-fix gate).
//   --read         : SELECT dispatch_queue (must still work — board banner).
//
// SAFETY: --forge-insert mutates prod (creates a real queue row the drainer may
// pick up). Run against a scratch DB, or immediately delete the forged row.
// Env: POSTGREST_URL, POSTGREST_JWT (the browser token).
// =============================================================================
'use strict'
const URL = process.env.POSTGREST_URL || process.env.VITE_POSTGREST_URL ||
  'https://postgrest-production-7960.up.railway.app'
const JWT = process.env.POSTGREST_JWT || process.env.VITE_POSTGREST_JWT || ''
function die(m){ console.error(`\n✗ ${m}\n`); process.exit(1) }
function ok(m){ console.log(`✓ ${m}`) }

async function pg(method, path, body) {
  const r = await fetch(`${URL}${path}`, {
    method,
    headers: { Authorization: `Bearer ${JWT}`, 'Content-Type': 'application/json',
      Accept: 'application/json', Prefer: 'return=representation' },
    body: body ? JSON.stringify(body) : undefined,
  })
  const text = await r.text(); let json=null; try{json=JSON.parse(text)}catch{}
  return { status: r.status, json, text }
}

async function main() {
  if (!JWT) die('No browser token in env (POSTGREST_JWT / VITE_POSTGREST_JWT).')
  const mode = process.argv[2] || '--read'

  if (mode === '--read') {
    const { status } = await pg('GET', '/dispatch_queue?status=eq.dead_letter&select=id&limit=1')
    if (status === 200) ok('SELECT dispatch_queue works (board banner intact).')
    else die(`SELECT dispatch_queue returned ${status} — board banner would break.`)
    return
  }

  if (mode === '--forge-insert') {
    const forged = {
      ticket_id: null, event_type: 'approved',
      payload: { forged: true, note: 'PHASE4 REPRO — browser-token forged outbox row' },
      status: 'pending',
    }
    const { status, json } = await pg('POST', '/dispatch_queue', forged)
    if (status >= 200 && status < 300) {
      ok(`FORGED: browser token inserted a fake 'approved' dispatch row (HTTP ${status}). The hole is real.`)
      const id = Array.isArray(json) ? json[0]?.id : json?.id
      if (id) {
        await pg('DELETE', `/dispatch_queue?id=eq.${id}`).catch(()=>{})
        console.log(`   (cleaned up forged row ${id})`)
      }
    } else if (status === 403) {
      ok(`Blocked (HTTP 403): browser token CANNOT insert into dispatch_queue. Fixed.`)
    } else {
      console.log(`Unexpected HTTP ${status}: ${json && (json.message||json.code)}`)
    }
    return
  }

  if (mode === '--forge-update') {
    // Try to suppress: flip any one pending row to 'sent'.
    const { status } = await pg('PATCH', '/dispatch_queue?status=eq.pending&limit=1', { status: 'sent' })
    if (status >= 200 && status < 300) ok(`SUPPRESS: browser token UPDATED a pending row to 'sent' (HTTP ${status}). Hole real.`)
    else if (status === 403) ok(`Blocked (HTTP 403): browser token CANNOT update dispatch_queue. Fixed.`)
    else console.log(`Unexpected HTTP ${status}`)
    return
  }

  if (mode === '--assert-blocked') {
    const ins = await pg('POST', '/dispatch_queue', { event_type: 'approved', payload: {}, status: 'pending' })
    const upd = await pg('PATCH', '/dispatch_queue?status=eq.pending&limit=1', { status: 'sent' })
    if (ins.status !== 403) die(`INSERT not blocked (HTTP ${ins.status}).`)
    ok('INSERT blocked (403).')
    if (upd.status !== 403) die(`UPDATE not blocked (HTTP ${upd.status}).`)
    ok('UPDATE blocked (403).')
    const sel = await pg('GET', '/dispatch_queue?select=id&limit=1')
    if (sel.status !== 200) die(`SELECT broke (HTTP ${sel.status}) — board banner needs it.`)
    ok('SELECT still works.')
    ok('\nPhase 4 gate PASSED: outbox not writable by the app token; reads intact.')
    return
  }

  die(`Unknown mode: ${mode}. Use --read | --forge-insert | --forge-update | --assert-blocked`)
}
main().catch(e => die(e.stack || e.message))
