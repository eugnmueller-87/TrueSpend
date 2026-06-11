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
    SELECT t.typname AS enum_name, e.enumlabel AS enum_value
    FROM pg_type t
    JOIN pg_enum e ON e.enumtypid = t.oid
    WHERE t.typname IN ('compliance_status', 'ticket_status', 'disposition_type')
    ORDER BY t.typname, e.enumsortorder
  `)
  const enums = {}
  rows.forEach(r => {
    if (!enums[r.enum_name]) enums[r.enum_name] = []
    enums[r.enum_name].push(r.enum_value)
  })
  console.log(JSON.stringify(enums, null, 2))
  await client.end()
}
run().catch(e => { console.error(e.message); process.exit(1) })
