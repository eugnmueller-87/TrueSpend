// Redistribute mock tickets so all branches have demo-visible tickets
const { Client } = require('pg')
const fs = require('fs')

const dbUrl = fs.readFileSync('.env', 'utf8')
  .split('\n')
  .find(l => l.startsWith('DATABASE_URL='))
  ?.replace('DATABASE_URL=', '')
  ?.trim()

const client = new Client({ connectionString: dbUrl })

async function run() {
  await client.connect()

  // Get branches
  const { rows: branches } = await client.query(
    `SELECT id, name FROM branches ORDER BY name`
  )
  const branchMap = Object.fromEntries(branches.map(b => [b.name, b.id]))

  // Get procurement managers per branch (to use as submitted_by_email)
  const { rows: procUsers } = await client.query(`
    SELECT u.email, u.branch_id FROM users u
    WHERE u.role = 'procurement_manager'
    ORDER BY u.email
  `)
  const procByBranch = Object.fromEntries(procUsers.map(u => [u.branch_id, u.email]))

  // Get branches with 0 tickets in open states
  const { rows: empty } = await client.query(`
    SELECT b.id, b.name
    FROM branches b
    LEFT JOIN tickets t ON t.branch_id = b.id
      AND t.status IN ('open','pending_confirm','pending_review','signature_required','escalated','approved')
    GROUP BY b.id, b.name
    HAVING COUNT(t.id) = 0
  `)
  console.log('Branches with no open tickets:', empty.map(b => b.name))

  // Get a pool of HQ tickets in non-critical states to reassign
  const { rows: hqTickets } = await client.query(`
    SELECT t.id, t.status, t.reference
    FROM tickets t
    JOIN branches b ON b.id = t.branch_id
    WHERE b.name = 'Global HQ'
      AND t.status IN ('pending_review', 'approved', 'escalated')
    LIMIT 10
  `)
  console.log(`HQ tickets available for redistribution: ${hqTickets.length}`)

  let idx = 0
  for (const branch of empty) {
    if (idx >= hqTickets.length) break
    const ticket = hqTickets[idx++]
    const email = procByBranch[branch.id] || 'procurement.hq@truespend.com'
    await client.query(`
      UPDATE tickets
      SET branch_id = $1, submitted_by_email = $2
      WHERE id = $3
    `, [branch.id, email, ticket.id])
    console.log(`✓ Moved ticket ${ticket.reference} (${ticket.status}) to ${branch.name}`)
  }

  // Also update cost_center_id for moved tickets to NULL (no specific CC for those branches)
  // to avoid budget join issues

  // Final distribution
  const { rows: finalDist } = await client.query(`
    SELECT b.name, COUNT(t.id) FILTER (WHERE t.status IN ('open','pending_confirm','pending_review','signature_required','escalated','approved')) as open_count, COUNT(t.id) as total
    FROM branches b
    LEFT JOIN tickets t ON t.branch_id = b.id
    GROUP BY b.id, b.name
    ORDER BY b.name
  `)
  console.log('\nFinal ticket distribution:')
  finalDist.forEach(d => console.log(`  ${d.name}: ${d.open_count} open / ${d.total} total`))

  await client.end()
  console.log('\n✓ Redistribution complete')
}

run().catch(e => { console.error('FATAL:', e.message); process.exit(1) })
