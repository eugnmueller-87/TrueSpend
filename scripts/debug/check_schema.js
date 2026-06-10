const { Client } = require('pg')
const fs = require('fs')
const env = fs.readFileSync('.env','utf8').replace(/^﻿/,'').split('\n')
const get = k => { const l = env.find(l => l.startsWith(k+'=')); return l ? l.replace(k+'=','').trim() : null }
const client = new Client({ connectionString: get('DATABASE_URL'), ssl: false })
client.connect().then(async () => {
  const r1 = await client.query("SELECT column_name, data_type FROM information_schema.columns WHERE table_name='compliance_checks' ORDER BY ordinal_position")
  console.log('compliance_checks:', r1.rows.map(r => r.column_name + ':' + r.data_type).join(', '))
  const r2 = await client.query("SELECT column_name, data_type, udt_name FROM information_schema.columns WHERE table_name='contracts' ORDER BY ordinal_position")
  console.log('contracts:', r2.rows.map(r => r.column_name + ':' + r.udt_name).join(', '))
  const r3 = await client.query("SELECT tablename FROM pg_tables WHERE schemaname='public' AND (tablename LIKE 'rag%' OR tablename='document_embeddings') ORDER BY tablename")
  console.log('RAG tables:', r3.rows.map(r => r.tablename).join(', ') || 'none')
  await client.end()
}).catch(e => { console.error(e.message); process.exit(1) })
