import { createRequire } from 'module'
const require = createRequire(import.meta.url)
const { Client } = require('pg')
const client = new Client({ host:'zephyr.proxy.rlwy.net', port:24934, database:'truespend', user:'truespend', <REDACTED_ROTATE_ME>:'<REDACTED_ROTATE_ME>', ssl:false })
await client.connect()

const tables = ['tickets','compliance_checks','llm_api_keys','workflow_runs','license_entitlements','budget_buckets','purchase_orders']
for (const t of tables) {
  const r = await client.query(`SELECT column_name, data_type FROM information_schema.columns WHERE table_name=$1 ORDER BY ordinal_position`, [t])
  console.log(`\n=== ${t} ===`)
  r.rows.forEach(c => console.log(`  ${c.column_name} (${c.data_type})`))
}
await client.end()
