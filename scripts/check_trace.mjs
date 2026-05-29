import { createRequire } from 'module'
const require = createRequire(import.meta.url)
const { Client } = require('pg')
const client = new Client({ host:'zephyr.proxy.rlwy.net', port:24934, database:'truespend', user:'truespend', password:'<REDACTED_ROTATE_ME>', ssl:false })
await client.connect()
const r = await client.query(`SELECT column_name, data_type, numeric_precision, numeric_scale FROM information_schema.columns WHERE table_name='trace_log' ORDER BY ordinal_position`)
console.table(r.rows)
await client.end()
