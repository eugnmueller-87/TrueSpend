// Apply expanded seed data + RAG schema to Railway PostgreSQL
// Run from project root: node db/migrations/apply_expanded_seed.js
//
// Applies in order:
//   1. db/migrations/rag_schema.sql       — pgvector, document_embeddings, rag_policies, search RPCs
//   2. db/seed/13_suppliers_expanded.sql   — 83 new suppliers (total 100)
//   3. db/seed/14_contracts_expanded.sql   — 50 new contracts (total ~80)
//   4. db/seed/15_legal_documents_expanded.sql — NDA + DPA for new suppliers
//   5. db/seed/16_compliance_checks_expanded.sql — 4 compliance checks per new supplier

const { Client } = require('pg')
const fs = require('fs')
const path = require('path')

// Load .env
const envLines = fs.readFileSync('.env', 'utf8').replace(/^﻿/, '').split('\n')
const getEnv = (key) => {
  const line = envLines.find(l => l.startsWith(key + '='))
  return line ? line.replace(key + '=', '').trim() : null
}

const DATABASE_URL = getEnv('DATABASE_URL')
if (!DATABASE_URL) {
  console.error('ERROR: DATABASE_URL not found in .env')
  process.exit(1)
}

const FILES = [
  'db/migrations/rag_tables_only.sql',        // Create RAG tables first (no data — no enum cast issues)
  'db/seed/13_suppliers_expanded.sql',         // 83 new suppliers
  'db/seed/14_contracts_expanded.sql',         // 50 new contracts
  'db/seed/15_legal_documents_expanded.sql',   // NDA + DPA docs
  'db/seed/16_compliance_checks_expanded.sql', // 4 checks per supplier
  'db/migrations/rag_seed_data.sql',           // Seed document_embeddings + policies (after all source tables populated)
]

async function run() {
  const client = new Client({
    connectionString: DATABASE_URL,
    ssl: false
  })
  await client.connect()
  console.log('Connected to Railway PostgreSQL\n')

  for (const file of FILES) {
    const fullPath = path.join(process.cwd(), file)
    if (!fs.existsSync(fullPath)) {
      console.error(`  ✗ File not found: ${file}`)
      continue
    }
    const sql = fs.readFileSync(fullPath, 'utf8').replace(/^﻿/, '')
    console.log(`Applying: ${file}`)
    try {
      await client.query(sql)
      console.log(`  ✓ Done\n`)
    } catch (e) {
      console.error(`  ✗ ERROR: ${e.message}\n`)
      // Continue to next file — don't abort on non-critical errors
      if (e.message.includes('already exists') || e.message.includes('duplicate key') || e.message.includes('on conflict')) {
        console.log('  (conflict/duplicate — treated as OK)\n')
      } else {
        console.error('  DETAILS:', e.message)
      }
    }
  }

  // Verify counts
  console.log('\n── Verification ──────────────────────────────')
  const checks = [
    { label: 'Suppliers total',         q: 'SELECT COUNT(*) FROM suppliers' },
    { label: 'Contracts total',          q: 'SELECT COUNT(*) FROM contracts' },
    { label: 'Legal documents total',    q: 'SELECT COUNT(*) FROM legal_documents' },
    { label: 'Compliance checks total',  q: 'SELECT COUNT(*) FROM compliance_checks' },
    { label: 'RAG policies',             q: 'SELECT COUNT(*) FROM rag_policies' },
    { label: 'document_embeddings',      q: 'SELECT COUNT(*) FROM document_embeddings' },
    { label: 'Suppliers by category', q: `
      SELECT category, COUNT(*) as count,
             SUM(CASE WHEN compliance_status='green' THEN 1 ELSE 0 END) as green,
             SUM(CASE WHEN compliance_status='amber' THEN 1 ELSE 0 END) as amber
      FROM suppliers GROUP BY category ORDER BY count DESC` },
    { label: 'Contracts by renewal_state', q: `
      SELECT renewal_state, COUNT(*) as count FROM contracts GROUP BY renewal_state ORDER BY count DESC` },
    { label: 'Legal docs by status', q: `
      SELECT status, COUNT(*) as count FROM legal_documents GROUP BY status ORDER BY count DESC` },
  ]

  for (const { label, q } of checks) {
    try {
      const res = await client.query(q)
      if (res.rows.length === 1 && res.rows[0].count !== undefined) {
        console.log(`  ${label}: ${res.rows[0].count}`)
      } else {
        console.log(`\n  ${label}:`)
        res.rows.forEach(r => console.log(`    ${JSON.stringify(r)}`))
      }
    } catch (e) {
      console.log(`  ${label}: ERROR — ${e.message}`)
    }
  }

  await client.end()
  console.log('\n✓ Migration complete\n')
}

run().catch(e => {
  console.error('FATAL:', e.message)
  process.exit(1)
})
