const { Client } = require('pg')
const fs = require('fs')
const env = fs.readFileSync('.env', 'utf8').replace(/^﻿/, '').split('\n')
const get = k => { const l = env.find(l => l.startsWith(k + '=')); return l ? l.replace(k + '=', '').trim() : null }
const client = new Client({ connectionString: get('DATABASE_URL'), ssl: false })

client.connect().then(async () => {
  // Check grants on catalog_by_supplier
  const r1 = await client.query(`
    SELECT grantee, privilege_type
    FROM information_schema.role_table_grants
    WHERE table_name = 'catalog_by_supplier'
    ORDER BY grantee, privilege_type
  `)
  console.log('catalog_by_supplier grants:', JSON.stringify(r1.rows))

  // Check grants on catalog_items
  const r2 = await client.query(`
    SELECT grantee, privilege_type
    FROM information_schema.role_table_grants
    WHERE table_name = 'catalog_items'
    ORDER BY grantee, privilege_type
  `)
  console.log('catalog_items grants:', JSON.stringify(r2.rows))

  // Try to query AS the truespend role
  await client.query("SET ROLE truespend")
  const r3 = await client.query('SELECT COUNT(*) FROM catalog_by_supplier')
  console.log('catalog_by_supplier as truespend role:', r3.rows[0].count)

  await client.end()
}).catch(e => { console.error('ERROR:', e.message); process.exit(1) })
