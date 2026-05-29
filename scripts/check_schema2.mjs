import { createRequire } from 'module'
const require = createRequire(import.meta.url)
const { Client } = require('pg')
const client = new Client({ host:'zephyr.proxy.rlwy.net', port:24934, database:'truespend', user:'truespend', password:'<REDACTED_ROTATE_ME>', ssl:false })
await client.connect()
for (const t of ['llm_consumption','workflow_runs','decisions']) {
  const r = await client.query(`SELECT column_name, data_type FROM information_schema.columns WHERE table_name=$1 ORDER BY ordinal_position`, [t])
  console.log(`\n=== ${t} ===`)
  r.rows.forEach(c => console.log(`  ${c.column_name}`))
}
await client.end()
