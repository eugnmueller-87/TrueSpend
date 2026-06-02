/**
 * apply_all_seeds.mjs — runs ALL seed files 01–09 in order
 */

import { createRequire } from 'module'
import { readFileSync, readdirSync } from 'fs'
import { fileURLToPath } from 'url'
import path from 'path'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const require = createRequire(import.meta.url)
const pg = require('pg')
const { Client } = pg

const client = new Client({
  host: 'zephyr.proxy.rlwy.net',
  port: 24934,
  database: 'truespend',
  user: 'truespend',
  <REDACTED_ROTATE_ME>: '<REDACTED_ROTATE_ME>',
  ssl: false
})

const seedDir = path.join(__dirname, '..', 'db', 'seed')
const files = readdirSync(seedDir)
  .filter(f => f.endsWith('.sql'))
  .sort()

await client.connect()
console.log('Connected to Railway PostgreSQL\n')

for (const file of files) {
  const sql = readFileSync(path.join(seedDir, file), 'utf-8').replace(/^﻿/, '')
  process.stdout.write(`  Applying ${file}... `)
  try {
    await client.query('BEGIN')
    await client.query(sql)
    await client.query('COMMIT')
    console.log('✓')
  } catch (err) {
    await client.query('ROLLBACK')
    console.log(`✗  ${err.message}`)
    if (err.position) {
      const pos = parseInt(err.position)
      console.log('  Near:', sql.substring(Math.max(0, pos - 80), pos + 80).replace(/\n/g, ' '))
    }
    // Continue with remaining files
  }
}

await client.end()
console.log('\nDone.')
