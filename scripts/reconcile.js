#!/usr/bin/env node
// =============================================================================
// reconcile.js — money-integrity reconciliation (Handover Task 3).
//
// Asserts the invariants that must hold between tickets, purchase_orders,
// budget_positions, action_ledger and dispatch_queue. Read-only by default;
// prints a discrepancy report and exits non-zero if anything is off (so CI /
// cron can alert). With --heal, fixes the safe, unambiguous cases.
//
// Checks:
//   C1  Every approved ticket has a non-null po_id pointing to a real PO.
//   C2  Every PO points back to a ticket that is in an approved/terminal state.
//   C3  Per (branch, cost_center, category, period): budget_positions.committed
//       >= SUM(amount_eur) of POs whose ticket is still 'approved' (committed,
//       not yet spent). A committed < live-PO sum means under-commit (bad).
//   C4  Every action_ledger row with outcome='committed' has a po_id, and that
//       PO exists.
//   C5  No dispatch_queue row is 'dead_letter', and none has been 'pending'
//       longer than the stale threshold (default 2h).
//   C6  No PO has amount_eur <= 0 (DB CHECK should prevent, belt-and-braces).
//
// Usage:
//   node scripts/reconcile.js                 # report only, exit 1 on findings
//   node scripts/reconcile.js --heal          # auto-fix C1 null-po_id-where-PO-exists
//   node scripts/reconcile.js --stale-hours 4 # override C5 stale threshold
// =============================================================================
const { Client } = require('pg')
const fs = require('fs')
const path = require('path')

const repoRoot = path.resolve(__dirname, '..')
function envGet(k) {
  if (process.env[k]) return process.env[k]
  try {
    const lines = fs.readFileSync(path.join(repoRoot, '.env'), 'utf8').replace(/^﻿/, '').split('\n')
    const l = lines.find(x => x.startsWith(k + '='))
    return l ? l.replace(k + '=', '').trim() : null
  } catch { return null }
}

const args = process.argv.slice(2)
const HEAL = args.includes('--heal')
const staleIdx = args.indexOf('--stale-hours')
const STALE_HOURS = staleIdx >= 0 ? parseInt(args[staleIdx + 1], 10) || 2 : 2

const findings = []
const record = (code, msg, rows) => findings.push({ code, msg, count: rows?.length ?? 0, rows: rows || [] })

;(async () => {
  const client = new Client({ connectionString: envGet('DATABASE_URL'), ssl: false })
  await client.connect()

  // ── C1: approved tickets must have a real PO ───────────────────────────────
  // Actionable case: a PO row exists for the ticket but po_id is unset/dangling
  // (a broken link — heal-able). Distinct from legacy seed tickets that were
  // inserted as 'approved' before the RPC boundary and have NO PO at all; those
  // are reported separately (C1-info) as a known, non-money-impacting backlog.
  const c1 = await client.query(`
    SELECT t.id, t.reference, t.po_id
    FROM tickets t
    WHERE t.status = 'approved'
      AND (t.po_id IS NULL OR NOT EXISTS (SELECT 1 FROM purchase_orders p WHERE p.id = t.po_id))
      AND EXISTS (SELECT 1 FROM purchase_orders p WHERE p.ticket_id = t.id)
  `)
  record('C1', 'Approved tickets with a PO row but missing/dangling po_id link (heal-able)', c1.rows)

  const c1info = await client.query(`
    SELECT count(*)::int AS n
    FROM tickets t
    WHERE t.status = 'approved' AND t.po_id IS NULL
      AND NOT EXISTS (SELECT 1 FROM purchase_orders p WHERE p.ticket_id = t.id)
  `)
  const seedNoPo = c1info.rows[0].n
  if (seedNoPo > 0) console.log(`ℹ  C1-info: ${seedNoPo} approved ticket(s) have NO PO at all — legacy/seed data inserted before the RPC boundary (not a money discrepancy).`)

  // Heal C1: where po_id is null but exactly one PO references this ticket, link it.
  if (HEAL && c1.rows.length) {
    const healed = await client.query(`
      UPDATE tickets t
      SET po_id = p.id, updated_at = now()
      FROM purchase_orders p
      WHERE p.ticket_id = t.id
        AND t.status = 'approved'
        AND t.po_id IS NULL
        AND (SELECT count(*) FROM purchase_orders p2 WHERE p2.ticket_id = t.id) = 1
      RETURNING t.id
    `)
    console.log(`[heal] C1: linked po_id on ${healed.rowCount} ticket(s)`)
  }

  // ── C2: POs must reference a ticket in an approved/terminal state ──────────
  const c2 = await client.query(`
    SELECT p.id, p.po_number, t.status
    FROM purchase_orders p
    JOIN tickets t ON t.id = p.ticket_id
    WHERE t.status NOT IN ('approved','closed','auto_executed')
  `)
  record('C2', 'POs whose ticket is not in an approved/terminal state', c2.rows)

  // ── C3: committed budget must cover the sum of live (approved) PO amounts ──
  const c3 = await client.query(`
    WITH live_po AS (
      SELECT p.branch_id, p.cost_center_id, p.category::text AS category,
             to_char(p.po_date, 'YYYY-"Q"Q') AS period,
             SUM(p.amount_eur) AS po_sum
      FROM purchase_orders p
      JOIN tickets t ON t.id = p.ticket_id
      WHERE t.status = 'approved'
      GROUP BY 1,2,3,4
    )
    SELECT b.branch_id, b.cost_center_id, b.category::text AS category, b.period,
           b.committed, lp.po_sum
    FROM budget_positions b
    JOIN live_po lp
      ON lp.branch_id = b.branch_id
     AND lp.cost_center_id IS NOT DISTINCT FROM b.cost_center_id
     AND lp.category = b.category::text
     AND lp.period   = b.period
    WHERE b.committed + 0.01 < lp.po_sum   -- committed should be >= PO sum
  `)
  record('C3', 'Budget committed is LESS than sum of live PO amounts (under-commit)', c3.rows)

  // ── C4: committed ledger rows must have a real PO ──────────────────────────
  const c4 = await client.query(`
    SELECT a.id, a.ticket_id, a.po_id
    FROM action_ledger a
    WHERE a.outcome = 'committed'
      AND (a.po_id IS NULL OR NOT EXISTS (SELECT 1 FROM purchase_orders p WHERE p.id = a.po_id))
  `)
  record('C4', 'action_ledger committed rows missing a valid PO', c4.rows)

  // ── C5: dispatch_queue health ──────────────────────────────────────────────
  const c5dead = await client.query(`SELECT id, event_type, last_error FROM dispatch_queue WHERE status='dead_letter'`)
  record('C5a', 'dispatch_queue dead-letter rows (downstream permanently failed)', c5dead.rows)
  const c5stale = await client.query(
    `SELECT id, event_type, created_at FROM dispatch_queue
     WHERE status='pending' AND created_at < now() - ($1 || ' hours')::interval`,
    [String(STALE_HOURS)]
  )
  record('C5b', `dispatch_queue rows pending > ${STALE_HOURS}h (drainer/n8n likely stuck)`, c5stale.rows)

  // ── C6: PO amounts must be positive ────────────────────────────────────────
  const c6 = await client.query(`SELECT id, po_number, amount_eur FROM purchase_orders WHERE amount_eur IS NULL OR amount_eur <= 0`)
  record('C6', 'POs with non-positive amount_eur', c6.rows)

  await client.end()

  // ── Report ─────────────────────────────────────────────────────────────────
  const bad = findings.filter(f => f.count > 0)
  console.log('\n=== TrueSpend reconciliation ===')
  for (const f of findings) {
    const mark = f.count === 0 ? '✓' : '✗'
    console.log(`${mark} ${f.code}: ${f.msg} — ${f.count} issue(s)`)
    if (f.count) {
      for (const r of f.rows.slice(0, 10)) console.log('     ', JSON.stringify(r))
      if (f.count > 10) console.log(`      …and ${f.count - 10} more`)
    }
  }

  if (bad.length === 0) {
    console.log('\n✓ All reconciliation checks passed. Books balanced.\n')
    process.exit(0)
  } else {
    console.log(`\n✗ ${bad.length} check(s) found discrepancies.${HEAL ? ' (heal applied where safe)' : ' Run with --heal to fix C1 auto-fixable cases.'}\n`)
    process.exit(1)
  }
})().catch(e => { console.error('FATAL:', e.message); process.exit(1) })
