// apply_one.js — apply a single migration file via node-pg, mirroring
// scripts/db-migrate.sh: single transaction + record name+sha256 in
// schema_migrations. Used when psql is not available locally (Windows).
//
//   node db/migrations/apply_one.js step6_dispatch_queue.sql
//
const { Client } = require('pg')
const fs = require('fs')
const path = require('path')
const crypto = require('crypto')

const file = process.argv[2]
if (!file) { console.error('usage: node apply_one.js <migration.sql>'); process.exit(1) }

const repoRoot = path.resolve(__dirname, '..', '..')
const envLines = fs.readFileSync(path.join(repoRoot, '.env'), 'utf8').replace(/^﻿/, '').split('\n')
const get = k => { const l = envLines.find(l => l.startsWith(k + '=')); return l ? l.replace(k + '=', '').trim() : null }

const filepath = path.join(__dirname, file)
const sql = fs.readFileSync(filepath, 'utf8')
const checksum = crypto.createHash('sha256').update(fs.readFileSync(filepath)).digest('hex')

const client = new Client({ connectionString: get('DATABASE_URL'), ssl: false })

;(async () => {
  await client.connect()
  await client.query(`create table if not exists schema_migrations (
    name text primary key, applied_at timestamptz not null default now(), checksum text not null)`)

  const { rows } = await client.query('select 1 from schema_migrations where name=$1', [file])
  if (rows.length) { console.log(`[skip] ${file} already applied`); await client.end(); return }

  console.log(`→ Applying ${file} (sha256: ${checksum.slice(0, 12)}…)`)
  try {
    await client.query('BEGIN')
    await client.query(sql)
    await client.query(
      `insert into schema_migrations (name, checksum) values ($1,$2)
       on conflict (name) do update set applied_at=now(), checksum=excluded.checksum`,
      [file, checksum]
    )
    await client.query('COMMIT')
    console.log(`  ✓ ${file} applied and recorded`)
  } catch (e) {
    await client.query('ROLLBACK')
    console.error(`  ✗ ${file} FAILED — rolled back:`, e.message)
    process.exit(1)
  }
  await client.end()
})().catch(e => { console.error('FATAL:', e.message); process.exit(1) })
