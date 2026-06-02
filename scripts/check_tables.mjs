import { createRequire } from 'module'
const require = createRequire(import.meta.url)
const { Client } = require('pg')
const client = new Client({ host:'zephyr.proxy.rlwy.net', port:24934, database:'truespend', user:'truespend', <REDACTED_ROTATE_ME>:'<REDACTED_ROTATE_ME>', ssl:false })
await client.connect()
const r = await client.query("SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name")
console.log('Tables:', r.rows.map(x=>x.table_name).join(', '))

// Check FK on tickets.owner_id
const fk = await client.query(`
  SELECT tc.constraint_name, ccu.table_name as references_table
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
  JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
  WHERE tc.table_name='tickets' AND kcu.column_name='owner_id' AND tc.constraint_type='FOREIGN KEY'
`)
console.log('\ntickets.owner_id FK:', fk.rows)

// Check managers table if it exists
try {
  const m = await client.query("SELECT id, name FROM managers LIMIT 5")
  console.log('\nmanagers table:', m.rows)
} catch(e) {
  console.log('\nNo managers table:', e.message)
}
await client.end()
