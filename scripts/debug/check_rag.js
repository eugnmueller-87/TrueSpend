const { Client } = require('pg')
const fs = require('fs')
const env = fs.readFileSync('.env','utf8').replace(/^﻿/,'').split('\n')
const get = k => { const l = env.find(l => l.startsWith(k+'=')); return l ? l.replace(k+'=','').trim() : null }
const client = new Client({ connectionString: get('DATABASE_URL'), ssl: false })
client.connect().then(async () => {
  // Check if tables exist
  const r1 = await client.query("SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename")
  console.log('All tables:', r1.rows.map(r=>r.tablename).join(', '))

  // Check contracts count
  const r2 = await client.query('SELECT COUNT(*) FROM contracts')
  console.log('Contracts:', r2.rows[0].count)

  const r3 = await client.query("SELECT column_name, udt_name FROM information_schema.columns WHERE table_name='suppliers' ORDER BY ordinal_position")
  console.log('suppliers columns:', r3.rows.map(r=>r.column_name+':'+r.udt_name).join(', '))

  // Try to run a single RAG insert to see exact error
  try {
    const r4 = await client.query("SELECT doc_type, source_id, supplier_id, chunk_index, chunk_text, meta_title, meta_category, meta_status, meta_tags FROM document_embeddings LIMIT 1")
    console.log('document_embeddings exists, rows:', r4.rowCount)
  } catch(e) {
    console.log('document_embeddings error:', e.message)
  }

  // Test the problematic query directly
  try {
    const r5 = await client.query("SELECT ARRAY[ld.doc_type, ld.status, s.category] FROM legal_documents ld JOIN suppliers s ON s.id = ld.supplier_id LIMIT 1")
    console.log('Legal doc array test OK:', r5.rows[0])
  } catch(e) {
    console.log('Legal doc array test ERROR:', e.message)
  }

  try {
    const r6 = await client.query("SELECT ARRAY[c.category::text, c.renewal_state::text, c.currency] FROM contracts c LIMIT 1")
    console.log('Contract array test OK:', r6.rows[0])
  } catch(e) {
    console.log('Contract array test ERROR:', e.message)
  }

  await client.end()
}).catch(e => { console.error(e.message); process.exit(1) })
