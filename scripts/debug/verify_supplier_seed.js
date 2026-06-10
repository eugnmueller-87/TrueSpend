const { Client } = require('pg')
const fs = require('fs'); const path = require('path')
const repoRoot = path.resolve(__dirname, '..', '..')
const env = fs.readFileSync(path.join(repoRoot, '.env'), 'utf8').replace(/^﻿/, '').split('\n')
const get = k => { const l = env.find(l => l.startsWith(k + '=')); return l ? l.replace(k + '=', '').trim() : null }
const client = new Client({ connectionString: get('DATABASE_URL'), ssl: false })
const q = async (s, p) => (await client.query(s, p)).rows
;(async () => {
  await client.connect()
  console.log('================ ROW COUNTS (source=demo) ================')
  for (const t of ['suppliers','contracts','purchase_orders','invoices','budget_positions']) {
    const r = await q(`select count(*)::int n from ${t} where source='demo'`)
    console.log(`  ${t.padEnd(18)} ${r[0].n}`)
  }
  const gap = await q("select count(*)::int n from suppliers where source='demo' and id::text like 'd5000000-%'")
  const enr = await q("select count(*)::int n from suppliers where source='demo' and id::text not like 'd5000000-%'")
  console.log(`  └ of which gap-inserted=${gap[0].n}, enriched-existing=${enr[0].n}`)

  console.log('\n================ RISK SPREAD (demo suppliers) ================')
  console.log((await q("select health, count(*)::int n from suppliers where source='demo' group by health order by health")).map(r=>`  health=${r.health}: ${r.n}`).join('\n'))
  console.log((await q("select strategic_tier, count(*)::int n from suppliers where source='demo' group by strategic_tier order by strategic_tier")).map(r=>`  tier=${r.strategic_tier}: ${r.n}`).join('\n'))

  console.log('\n================ CONTRACTS EXPIRING < 60 DAYS (from 2026-06-01) ================')
  const exp = await q("select c.name, s.name sup, c.expiry_date, (c.expiry_date - date '2026-06-01') days from contracts c join suppliers s on s.id=c.supplier_id where c.source='demo' and c.expiry_date < date '2026-06-01' + 60 order by c.expiry_date")
  console.log(exp.map(r=>`  ${r.expiry_date.toISOString().slice(0,10)} (+${r.days}d) ${r.sup} — ${r.name}`).join('\n'))
  console.log(`  → ${exp.length} contracts expiring within 60 days`)

  console.log('\n================ RECONCILIATION ================')
  // total: sum of demo invoices vs sum of demo budget_positions.spent
  const totInv = (await q("select coalesce(sum(amount_eur),0)::numeric t from invoices where source='demo'"))[0].t
  const totSpent = (await q("select coalesce(sum(spent),0)::numeric t from budget_positions where source='demo'"))[0].t
  console.log(`  TOTAL  invoices=${totInv}  budget.spent=${totSpent}  ${totInv===totSpent?'✓ TIE':'✗ MISMATCH'}`)

  // by (branch, cost_center, category): invoice rollup vs budget_positions.spent
  console.log('\n  By (cost_center, category) — invoice rollup vs budget.spent:')
  const recon = await q(`
    with inv_roll as (
      select po.branch_id, po.cost_center_id, po.category::text cat, sum(inv.amount_eur) inv_sum
      from invoices inv join purchase_orders po on po.id=inv.po_id
      where inv.source='demo' and po.source='demo'
      group by po.branch_id, po.cost_center_id, po.category
    ),
    bud as (
      select branch_id, cost_center_id, category::text cat, spent
      from budget_positions where source='demo'
    )
    select coalesce(i.cost_center_id,b.cost_center_id) cc, coalesce(i.cat,b.cat) cat,
           coalesce(i.inv_sum,0) inv_sum, coalesce(b.spent,0) spent,
           (coalesce(i.inv_sum,0)=coalesce(b.spent,0)) ok
    from inv_roll i full outer join bud b
      on i.branch_id=b.branch_id and i.cost_center_id=b.cost_center_id and i.cat=b.cat
    order by cat`)
  let allok = true
  for (const r of recon) { if(!r.ok) allok=false; console.log(`    ${String(r.cat).padEnd(13)} cc=${String(r.cc).slice(0,8)} inv=${r.inv_sum} spent=${r.spent} ${r.ok?'✓':'✗ MISMATCH'}`) }
  console.log(`  → per-bucket reconciliation: ${allok?'✓ ALL TIE':'✗ MISMATCHES PRESENT'}`)

  console.log('\n================ SPEND BY SUPPLIER (demo, top 10) ================')
  const bysup = await q(`select s.name, sum(inv.amount_eur)::numeric spend from invoices inv join suppliers s on s.id=inv.supplier_id where inv.source='demo' group by s.name order by spend desc limit 10`)
  console.log(bysup.map(r=>`  ${r.name.padEnd(20)} €${Number(r.spend).toLocaleString()}`).join('\n'))

  console.log('\n================ TOTAL SUPPLIER MASTER ================')
  console.log('  all suppliers:', (await q('select count(*)::int n from suppliers'))[0].n, '(demo-tagged + real)')
  await client.end()
  process.exit(allok && totInv===totSpent ? 0 : 2)
})().catch(e => { console.error('ERR', e.message); process.exit(1) })
