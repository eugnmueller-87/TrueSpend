#!/usr/bin/env node
// =============================================================================
// mint_postgrest_jwt.js — mint a PostgREST HS256 JWT for rotation.
//
// Usage:
//   node scripts/mint_postgrest_jwt.js <SECRET> [role] [expiryDays] [app_role]
//
//   <SECRET>      the PGRST_JWT_SECRET PostgREST validates against (REQUIRED).
//                 Pass it on the CLI or via env PGRST_JWT_SECRET. Never commit it.
//   role          PostgREST `role` claim. Default: truespend_app.
//   expiryDays    token lifetime in days. Default: 365. Use a SHORT life for the
//                 browser token (it is publicly readable in /config.js) — a year,
//                 not a decade. The old leaked token was 10 years; don't repeat that.
//   app_role      optional `app_role` claim (e.g. procurement) — set this for the
//                 n8n service token ONCE the ADR-006 fail-closed cutover is live,
//                 so it can call the money RPCs. Leave empty for the browser token.
//
// The secret is read from argv/env only; it is never written anywhere. Run locally.
//
// Examples:
//   node scripts/mint_postgrest_jwt.js "$(cat /tmp/newsecret)"                  # browser token, 1yr
//   node scripts/mint_postgrest_jwt.js "$SECRET" truespend_app 365 procurement  # privileged n8n token
// =============================================================================
'use strict'
const crypto = require('crypto')

const args = process.argv.slice(2)
if (args[0] === '--help' || args[0] === '-h') {
  console.log(require('fs').readFileSync(__filename, 'utf8').split('// ===')[1])
  process.exit(0)
}

const SECRET = args[0] || process.env.PGRST_JWT_SECRET
const role = args[1] || 'truespend_app'
const expiryDays = parseInt(args[2] || '365', 10)
const appRole = args[3] || null

if (!SECRET) {
  console.error('ERROR: provide PGRST_JWT_SECRET as arg 1 or env. See --help.')
  process.exit(1)
}
if (!Number.isFinite(expiryDays) || expiryDays <= 0) {
  console.error('ERROR: expiryDays must be a positive integer.')
  process.exit(1)
}

const b64url = buf => Buffer.from(buf).toString('base64')
  .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

const now = Math.floor(Date.now() / 1000)
const header = { alg: 'HS256', typ: 'JWT' }
const payload = { role, iat: now, exp: now + expiryDays * 86400 }
if (appRole) payload.app_role = appRole

const headerB64 = b64url(JSON.stringify(header))
const payloadB64 = b64url(JSON.stringify(payload))
const signingInput = `${headerB64}.${payloadB64}`
const sig = b64url(crypto.createHmac('sha256', SECRET).update(signingInput).digest())
const token = `${signingInput}.${sig}`

console.log('\nclaims:', JSON.stringify(payload))
console.log('expires:', new Date(payload.exp * 1000).toISOString(), `(${expiryDays} days)`)
console.log('\ntoken:\n' + token + '\n')
console.error('(token printed to stdout; secret was NOT stored. Paste the token into ' +
  'the Railway service var / n8n .env per scripts/rotate_postgrest_jwt.md)')
