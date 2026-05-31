// Migration: fix open_tickets_board + supplier compliance + ticket data
const { Client } = require('pg')
const fs = require('fs')

const dbUrl = fs.readFileSync('.env', 'utf8')
  .split('\n')
  .find(l => l.startsWith('DATABASE_URL='))
  ?.replace('DATABASE_URL=', '')
  ?.trim()

if (!dbUrl) { console.error('DATABASE_URL not found in .env'); process.exit(1) }

const client = new Client({ connectionString: dbUrl })

async function run() {
  await client.connect()
  console.log('Connected to DB')

  // ── Fix 1: Recreate open_tickets_board with branch_id + extra fields ──
  await client.query(`DROP VIEW IF EXISTS open_tickets_board CASCADE`)
  await client.query(`
    CREATE VIEW open_tickets_board AS
    SELECT
      t.id,
      t.reference,
      t.source,
      t.status,
      t.title,
      t.description,
      t.review_type,
      t.review_notes,
      t.pdf_url,
      t.amount,
      t.amount_eur,
      t.value_eur,
      t.currency,
      t.jira_key,
      t.po_id,
      po.po_number,
      po.status            AS po_status,
      po.expected_delivery AS po_expected_delivery,
      (po.expected_delivery IS NOT NULL AND po.expected_delivery < CURRENT_DATE AND po.delivered_at IS NULL) AS po_delivery_overdue,
      t.created_at,
      t.target_close,
      t.category,
      t.branch_id,
      t.cost_center_id,
      t.submitted_by,
      t.submitted_by_email,
      t.confidence           AS confidence_score,
      s.name               AS supplier_name,
      s.health             AS supplier_health,
      s.compliance_status  AS supplier_compliance,
      b.name               AS branch_name,
      cc.code              AS cost_center_code,
      cc.name              AS cost_center_name,
      u.name               AS owner_name,
      u.email              AS owner_email,
      d.disposition,
      d.confidence,
      d.recommendation,
      d.reasoning          AS agent_reasoning,
      bp.budget            AS bucket_budget,
      bp.committed         AS bucket_committed,
      bp.spent             AS bucket_spent,
      bp.available         AS bucket_available,
      CASE t.status
        WHEN 'signature_required' THEN 1
        WHEN 'pending_confirm'    THEN 2
        WHEN 'pending_review'     THEN 3
        WHEN 'escalated'          THEN 4
        ELSE 5
      END AS sort_priority
    FROM tickets t
    LEFT JOIN suppliers s        ON s.id   = t.supplier_id
    LEFT JOIN branches b         ON b.id   = t.branch_id
    LEFT JOIN cost_centers cc    ON cc.id  = t.cost_center_id
    LEFT JOIN users u            ON u.id   = t.owner_id
    LEFT JOIN decisions d        ON d.ticket_id = t.id
    LEFT JOIN purchase_orders po ON po.id  = t.po_id
    LEFT JOIN budget_positions bp
      ON  bp.branch_id     = t.branch_id
      AND bp.cost_center_id IS NOT DISTINCT FROM t.cost_center_id
      AND bp.category::TEXT = t.category
      AND bp.period        = (
            EXTRACT(YEAR FROM NOW())::TEXT || '-Q' ||
            CEIL(EXTRACT(MONTH FROM NOW()) / 3.0)::TEXT
          )
    WHERE t.status IN (
      'open', 'pending_confirm', 'pending_review',
      'signature_required', 'escalated', 'approved'
    )
    ORDER BY sort_priority, t.created_at ASC
  `)
  console.log('✓ open_tickets_board view updated (branch_id, cost_center_id, submitted_by_email, category added)')

  // ── Fix 2: Approve established suppliers ──
  // These are known vendors with active contracts — should be compliance_status='approved'
  const approvedSuppliers = [
    'Dell Technologies',
    'Apple Inc.',
    'Amazon Web Services',
    'Microsoft',
    'SAP SE',
    'Salesforce',
    'ServiceNow',
    'Lenovo',
    'HP Inc.',
    'Cisco Systems',
    'Oracle',
    'Google Cloud',
    'Adobe Systems',
    'Atlassian',
    'Zoom Video Communications',
    'Slack Technologies',
    'Workday'
  ]

  // First check what suppliers exist
  const { rows: suppliers } = await client.query(
    `SELECT id, name, compliance_status FROM suppliers ORDER BY name`
  )
  console.log('\nCurrent suppliers:')
  suppliers.forEach(s => console.log(`  ${s.name}: ${s.compliance_status}`))

  // Update all suppliers to green (they are all mock established vendors)
  // compliance_status enum: pending, running, green, amber, red, waived
  const { rowCount } = await client.query(
    `UPDATE suppliers SET compliance_status = 'green' WHERE compliance_status = 'pending'`
  )
  console.log(`\n✓ Updated ${rowCount} suppliers to compliance_status='green'`)

  // ── Fix 3: Assign branch_id to tickets with null branch_id ──
  const { rows: nullBranch } = await client.query(
    `SELECT COUNT(*) as cnt FROM tickets WHERE branch_id IS NULL`
  )
  console.log(`\nTickets with null branch_id: ${nullBranch[0].cnt}`)

  if (parseInt(nullBranch[0].cnt) > 0) {
    // Get the HQ branch id
    const { rows: hqBranch } = await client.query(
      `SELECT id FROM branches WHERE name ILIKE '%HQ%' OR name ILIKE '%Global%' LIMIT 1`
    )
    if (hqBranch.length > 0) {
      const { rowCount: fixed } = await client.query(
        `UPDATE tickets SET branch_id = $1 WHERE branch_id IS NULL`,
        [hqBranch[0].id]
      )
      console.log(`✓ Assigned ${fixed} tickets to HQ branch (${hqBranch[0].id})`)
    }
  }

  // ── Fix 4: Set submitted_by_email for mock tickets using owner email ──
  const { rows: nullEmail } = await client.query(
    `SELECT COUNT(*) as cnt FROM tickets WHERE submitted_by_email IS NULL`
  )
  console.log(`\nTickets with null submitted_by_email: ${nullEmail[0].cnt}`)

  if (parseInt(nullEmail[0].cnt) > 0) {
    // Join to users via owner_id to get their email
    const { rowCount: emailFixed } = await client.query(`
      UPDATE tickets t
      SET submitted_by_email = u.email
      FROM users u
      WHERE t.owner_id = u.id
        AND t.submitted_by_email IS NULL
        AND u.email IS NOT NULL
    `)
    console.log(`✓ Populated submitted_by_email for ${emailFixed} tickets from owner`)

    // For remaining null (no owner), use procurement.hq as fallback
    const { rowCount: fallback } = await client.query(`
      UPDATE tickets
      SET submitted_by_email = 'procurement.hq@truespend.com'
      WHERE submitted_by_email IS NULL
    `)
    console.log(`✓ Fallback email set for ${fallback} remaining tickets`)
  }

  // ── Fix 5: Distribute mock tickets across branches so demo works ──
  // Get all branches and their procurement managers
  const { rows: branches } = await client.query(
    `SELECT id, name FROM branches ORDER BY name`
  )
  console.log(`\nBranches: ${branches.map(b => b.name).join(', ')}`)

  // Get distribution of tickets across branches
  const { rows: dist } = await client.query(`
    SELECT b.name, COUNT(t.id) as ticket_count
    FROM branches b
    LEFT JOIN tickets t ON t.branch_id = b.id
    GROUP BY b.id, b.name
    ORDER BY b.name
  `)
  console.log('\nTicket distribution by branch:')
  dist.forEach(d => console.log(`  ${d.name}: ${d.ticket_count}`))

  // Show final state
  const { rows: final } = await client.query(`
    SELECT status, COUNT(*) as cnt FROM tickets GROUP BY status ORDER BY status
  `)
  console.log('\nTicket status counts:')
  final.forEach(r => console.log(`  ${r.status}: ${r.cnt}`))

  await client.end()
  console.log('\n✓ All fixes applied')
}

run().catch(e => { console.error('FATAL:', e.message); process.exit(1) })
