import { createRequire } from 'module'
const require = createRequire(import.meta.url)
const { Client } = require('pg')
const client = new Client({ host:'zephyr.proxy.rlwy.net', port:24934, database:'truespend', user:'truespend', password:'<REDACTED_ROTATE_ME>', ssl:false })
await client.connect()
for (const e of ['ticket_source','ticket_status','disposition','po_status']) {
  const r = await client.query(`SELECT enumlabel FROM pg_enum JOIN pg_type ON pg_type.oid = pg_enum.enumtypid WHERE pg_type.typname = $1 ORDER BY enumsortorder`, [e])
  console.log(`${e}:`, r.rows.map(x=>x.enumlabel).join(', '))
}
await client.end()
