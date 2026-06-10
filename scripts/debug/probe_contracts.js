// One-off prod probe: why does the Contract register show 0 when 88 contracts exist?
// Reads POSTGREST_URL/JWT from .env. Read-only.
const fs = require('fs')
const env = fs.readFileSync(require('path').resolve(__dirname, '../../.env'), 'utf8').replace(/^﻿/, '').split('\n')
const get = k => { const l = env.find(x => x.startsWith(k + '=')); return l ? l.slice(k.length + 1).trim() : null }
const URL = get('POSTGREST_URL') || 'https://postgrest-production-7960.up.railway.app'
const JWT = get('POSTGREST_JWT')
const H = { Authorization: 'Bearer ' + JWT, Accept: 'application/json' }

async function hit(label, path) {
  try {
    const r = await fetch(URL + path, { headers: H })
    const body = await r.text()
    console.log(`[${label}] HTTP ${r.status}  ${body.slice(0, 350)}`)
  } catch (e) { console.log(`[${label}] FETCH-ERR ${e.message}`) }
}

async function rows(path) {
  const r = await fetch(URL + path, { headers: H })
  const b = await r.json().catch(() => null)
  return { status: r.status, rows: Array.isArray(b) ? b : b }
}

;(async () => {
  // The FIXED register query (contract_number removed)
  const fixed = 'id,name,supplier_id,category,value_eur,expiry_date,auto_renew,renewal_state,start_date'
  const res = await rows('/contracts?order=expiry_date.asc&limit=200&select=' + fixed)
  console.log('[fixed register] HTTP', res.status, 'rows:', Array.isArray(res.rows) ? res.rows.length : res.rows)
  if (Array.isArray(res.rows) && res.rows.length) {
    const today = new Date('2026-06-10')
    const days = c => (new Date(c.expiry_date) - today) / 86400000
    const expired = res.rows.filter(c => days(c) < 0).length
    const s30 = res.rows.filter(c => days(c) >= 0 && days(c) <= 30).length
    const s90 = res.rows.filter(c => days(c) >= 0 && days(c) <= 90).length
    const ar = res.rows.filter(c => c.auto_renew).length
    console.log(`  STAT CARDS -> Total ${res.rows.length} | Expired ${expired} | <30d ${s30} | <90d ${s90} | Auto-renew ${ar}`)
    console.log('  sample:', res.rows.slice(0, 3).map(c => `${c.name} (${c.expiry_date})`).join(' | '))
  }
})()
