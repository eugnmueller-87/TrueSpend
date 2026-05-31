const { Client } = require('pg')
const fs = require('fs')

const dbUrl = fs.readFileSync('.env', 'utf8')
  .split('\n')
  .find(l => l.startsWith('DATABASE_URL='))
  ?.replace('DATABASE_URL=', '')
  ?.trim()

const client = new Client({ connectionString: dbUrl })

async function run() {
  await client.connect()
  const { rows } = await client.query(`
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_name = 'decisions'
    ORDER BY ordinal_position
  `)
  console.log('decisions columns:')
  rows.forEach(r => console.log(`  ${r.column_name}: ${r.data_type}`))
  await client.end()
}
run().catch(e => { console.error(e.message); process.exit(1) })
