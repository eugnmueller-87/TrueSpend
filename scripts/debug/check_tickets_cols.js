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
  const tables = ['tickets', 'purchase_orders', 'contracts']
  for (const t of tables) {
    const { rows } = await client.query(`
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_name = $1
      ORDER BY ordinal_position
    `, [t])
    console.log(`\n${t}:`)
    rows.forEach(r => console.log(`  ${r.column_name}`))
  }
  await client.end()
}
run().catch(e => { console.error(e.message); process.exit(1) })
