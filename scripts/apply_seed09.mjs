import { createRequire } from 'module'
import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'
import path from 'path'
const __dirname = path.dirname(fileURLToPath(import.meta.url))
const require = createRequire(import.meta.url)
const { Client } = require('pg')
const client = new Client({ host:'zephyr.proxy.rlwy.net', port:24934, database:'truespend', user:'truespend', password:'<REDACTED_ROTATE_ME>', ssl:false })
const sql = readFileSync(path.join(__dirname,'..','db','seed','09_mock_data.sql'),'utf-8').replace(/^﻿/,'')

// Split on section comments and run each block separately
const blocks = sql.split(/\n(?=-- ─)/g)
await client.connect()
console.log(`Running ${blocks.length} blocks...\n`)

for (let i = 0; i < blocks.length; i++) {
  const block = blocks[i].trim()
  if (!block || block.startsWith('--') && !block.includes('insert')) continue
  const label = block.split('\n').find(l => l.startsWith('--')) || `Block ${i}`
  process.stdout.write(`${label.substring(0,70)}... `)
  try {
    await client.query('BEGIN')
    await client.query(block)
    await client.query('COMMIT')
    console.log('✓')
  } catch (err) {
    await client.query('ROLLBACK')
    console.log(`✗  ${err.message}`)
    if (err.detail) console.log('  Detail:', err.detail)
  }
}
await client.end()
