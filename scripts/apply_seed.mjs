/**
 * apply_seed.mjs — executes db/seed/09_mock_data.sql against Railway PostgreSQL
 * Uses the 'pg' driver via a one-shot npx import.
 * Run: node scripts/apply_seed.mjs
 */

import { createRequire } from 'module'
import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'
import path from 'path'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

// Try to load pg — install it if missing
let pg
try {
  const require = createRequire(import.meta.url)
  pg = require('pg')
} catch {
  console.log('pg not found — installing...')
  const { execSync } = await import('child_process')
  execSync('npm install pg --no-save', { cwd: path.join(__dirname, '..'), stdio: 'inherit' })
  const require = createRequire(import.meta.url)
  pg = require('pg')
}

const { Client } = pg

const client = new Client({
  host: 'zephyr.proxy.rlwy.net',
  port: 24934,
  database: 'truespend',
  user: 'truespend',
  password: '<REDACTED_ROTATE_ME>',
  ssl: false
})

const sqlFile = path.join(__dirname, '..', 'db', 'seed', '09_mock_data.sql')
const sql = readFileSync(sqlFile, 'utf-8')

await client.connect()
console.log('Connected to Railway PostgreSQL')

try {
  await client.query('BEGIN')
  await client.query(sql)
  await client.query('COMMIT')
  console.log('✓ Mock data applied successfully')
} catch (err) {
  await client.query('ROLLBACK')
  console.error('✗ Error — rolled back:', err.message)
  // Show the failing statement context
  if (err.position) {
    const pos = parseInt(err.position)
    console.error('Near:', sql.substring(Math.max(0, pos - 100), pos + 100))
  }
  process.exit(1)
} finally {
  await client.end()
}
