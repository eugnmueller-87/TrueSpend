#!/usr/bin/env node
// =============================================================================
// repro_money_rpc_exposure.js — Phase 2 security repro.
//
// Demonstrates that the BROWSER-EXTRACTABLE token (the exact JWT the SPA ships
// in /config.js or VITE_POSTGREST_JWT) can call the money RPCs and create a PO
// against the CURRENT (dormant-guard) backend — and that after the fail-closed
// flip the same call returns 403 / SQLSTATE 42501.
//
// "LLM advises, deterministic code decides" is the Phase-1 principle; Phase 2's
// equivalent is "the browser advises, the server decides" — a browser token must
// not be able to move money. This script is the proof.
//
// SAFETY: the live "before" call actually commits budget + creates a PO, so it
// MUTATES data. Modes:
//   --decode           : decode the token, assert app_role is absent. No network.
//                        (safe, gated-prod-friendly — the heart of the repro.)
//   --probe            : send the money RPC with a deliberately invalid ticket id
//                        and report the HTTP status + SQLSTATE. Does NOT create a
//                        valid PO (the RPC fails on the bad id BEFORE/independent
//                        of the guard); used to read whether the guard is armed.
//   --exploit <ticket> : the full destructive demo — calls approve_and_commit on a
//                        REAL approvable ticket and asserts a PO is created.
//                        Use ONLY against a scratch DB / disposable seed row.
//   --assert-blocked   : assert the money RPC now returns 403/42501 (post-fix gate).
//
// Env: POSTGREST_URL, POSTGREST_JWT (or VITE_*). Reads the SAME values the SPA
// uses. Never commit a real token — pass via env at runtime.
// =============================================================================

'use strict'

const URL = process.env.POSTGREST_URL || process.env.VITE_POSTGREST_URL ||
  'https://postgrest-production-7960.up.railway.app'
const JWT = process.env.POSTGREST_JWT || process.env.VITE_POSTGREST_JWT || ''

function die(msg, code = 1) { console.error(`\n✗ ${msg}\n`); process.exit(code) }
function ok(msg) { console.log(`✓ ${msg}`) }

function decodeJwt(t) {
  const parts = (t || '').split('.')
  if (parts.length !== 3) return null
  try {
    const pad = s => s + '='.repeat((4 - (s.length % 4)) % 4)
    const b64 = s => Buffer.from(pad(s.replace(/-/g, '+').replace(/_/g, '/')), 'base64').toString('utf8')
    return { header: JSON.parse(b64(parts[0])), payload: JSON.parse(b64(parts[1])) }
  } catch { return null }
}

async function callRpc(fn, body) {
  const r = await fetch(`${URL}/rpc/${fn}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${JWT}`, 'Content-Type': 'application/json', Prefer: 'return=representation' },
    body: JSON.stringify(body),
  })
  const text = await r.text()
  let json = null; try { json = JSON.parse(text) } catch {}
  return { status: r.status, json, text }
}

const APPROVE_ARGS = (ticketId) => ({
  p_ticket_id: ticketId,
  p_branch_id: 'b1000000-0000-0000-0000-000000000002',
  p_branch_code: 'DACH',
  p_cost_center_id: null,
  p_category: 'saas_license',
  p_period: '2026-Q2',
  p_supplier_id: null,
  p_contract_id: null,
  p_description: 'PHASE2 REPRO — browser token forged approval',
  p_amount: 1000,
  p_currency: 'EUR',
  p_amount_eur: 1000,
  p_raised_by: null,
  p_expected_delivery: null,
  p_line_items: null,
})

async function main() {
  const mode = process.argv[2] || '--decode'

  // ── --decode: the core, network-free proof ──
  if (mode === '--decode') {
    if (!JWT) die('No token in env (POSTGREST_JWT / VITE_POSTGREST_JWT). The repro needs the browser token.')
    const d = decodeJwt(JWT)
    if (!d) die('Token is not a decodable JWT.')
    console.log('Token header :', JSON.stringify(d.header))
    console.log('Token payload:', JSON.stringify(d.payload))
    const role = d.payload.role
    const appRole = d.payload.app_role
    ok(`PostgREST role claim: ${role}`)
    if (appRole == null) {
      ok('app_role claim is ABSENT — the dormant guard is a NO-OP, so this token CAN call money RPCs today.')
      ok('After the fail-closed flip, the SAME token will be rejected (is null -> 42501).')
    } else {
      console.log(`! app_role present: ${appRole} — breakage analysis differs; re-check the fail-closed spec.`)
    }
    console.log('\n(decode mode is network-free and safe to run against prod creds.)')
    return
  }

  if (!JWT) die('No token in env.')

  // ── --probe: read whether the guard is armed, without creating a valid PO ──
  if (mode === '--probe') {
    // A syntactically-valid but non-existent ticket id. If the guard is DORMANT,
    // the RPC proceeds and fails later (e.g. budget position not found / ticket
    // not found) -> NOT 42501. If the guard is ARMED, it 42501s up front.
    const fakeTicket = '00000000-0000-0000-0000-000000000000'
    const { status, json } = await callRpc('approve_and_commit', APPROVE_ARGS(fakeTicket))
    const code = json && json.code
    console.log(`HTTP ${status}  SQLSTATE ${code || '(none)'}  msg: ${json && (json.message || json.hint)}`)
    if (status === 403 || code === '42501') {
      ok('Guard is ARMED (fail-closed): browser token is rejected before any money move.')
    } else {
      console.log('! Guard appears DORMANT: the token was authorized past the role check (failure is downstream).')
      console.log('  -> This is the LIVE EXPOSURE. Browser token can drive approve_and_commit.')
    }
    return
  }

  // ── --exploit <ticketId>: full destructive demonstration (scratch DB only) ──
  if (mode === '--exploit') {
    const ticketId = process.argv[3]
    if (!ticketId) die('Usage: --exploit <approvable-ticket-uuid>  (SCRATCH DB ONLY — this creates a PO)')
    console.log('!! DESTRUCTIVE: this will commit budget and create a PO using ONLY the browser token.')
    const { status, json } = await callRpc('approve_and_commit', APPROVE_ARGS(ticketId))
    if (status >= 200 && status < 300 && json && json.po_number) {
      ok(`EXPLOITED: browser token created PO ${json.po_number} (status ${status}). The hole is real.`)
      console.log('   -> Clean up the PO/ticket on the scratch DB.')
    } else {
      console.log(`Did not create a PO: HTTP ${status} ${json && (json.message || json.code)}`)
      console.log('   (If 403/42501, the guard is already armed — run --assert-blocked.)')
    }
    return
  }

  // ── --assert-blocked: post-fix gate ──
  if (mode === '--assert-blocked') {
    const fakeTicket = '00000000-0000-0000-0000-000000000000'
    for (const fn of ['approve_and_commit', 'create_payment_instruction']) {
      const body = fn === 'approve_and_commit'
        ? APPROVE_ARGS(fakeTicket)
        : { p_invoice_id: fakeTicket, p_due_date: '2026-12-31' }
      const { status, json } = await callRpc(fn, body)
      const code = json && json.code
      if (status === 403 || code === '42501') {
        ok(`${fn}: blocked (HTTP ${status}, SQLSTATE ${code}) — browser token is powerless.`)
      } else {
        die(`${fn}: NOT blocked (HTTP ${status}, SQLSTATE ${code}). Fail-closed flip is not effective for the browser token.`)
      }
    }
    ok('\nPost-fix gate PASSED: the browser token cannot drive the money RPCs.')
    return
  }

  die(`Unknown mode: ${mode}. Use --decode | --probe | --exploit <ticket> | --assert-blocked`)
}

main().catch(e => die(e.stack || e.message))
