import { createRequire } from 'module'
import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'
import path from 'path'
const __dirname = path.dirname(fileURLToPath(import.meta.url))
const require = createRequire(import.meta.url)
const { Client } = require('pg')
const client = new Client({ host:'zephyr.proxy.rlwy.net', port:24934, database:'truespend', user:'truespend', password:'<REDACTED_ROTATE_ME>', ssl:false })
await client.connect()

const sql = readFileSync(path.join(__dirname,'..','db','seed','09_mock_data.sql'),'utf-8')
// Extract all trace_log insert blocks
const regex = /insert into trace_log[^;]+;/gs
const matches = [...sql.matchAll(regex)]

for (const [i, match] of matches.entries()) {
  const block = match[0]
  // Split into individual rows
  const rows = block.split('\n').filter(l => l.trim().startsWith("('a1"))
  for (const row of rows) {
    // Extract the weight value
    const wMatch = row.match(/, ([\d.]+), (true|false),/)
    if (wMatch) {
      const w = parseFloat(wMatch[1])
      if (w >= 10) console.log(`OVERFLOW in block ${i}: weight=${w} row: ${row.substring(0,80)}`)
    }
  }
}

// Also try inserting one row at a time to find the bad one
const rows = [...sql.matchAll(/\('a1000000[^)]+\)/g)]
console.log(`Total trace rows: ${rows.length}`)
for (const r of rows.slice(0,5)) {
  console.log(r[0].substring(0,120))
}

await client.end()
