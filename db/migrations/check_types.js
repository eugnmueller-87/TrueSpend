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
    SELECT table_name, column_name, data_type, udt_name
    FROM information_schema.columns
    WHERE table_name IN ('tickets','budget_positions') AND column_name='category'
    ORDER BY table_name
  `)
  console.log('Category column types:', JSON.stringify(rows, null, 2))
  await client.end()
}
run().catch(e => { console.error(e.message); process.exit(1) })
