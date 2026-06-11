const fs = require('fs')

const envLines = fs.readFileSync('.env', 'utf8').split('\n')
const getEnv = (key) => envLines.find(l => l.startsWith(key + '='))?.replace(key + '=', '').trim()

const N8N_URL = getEnv('N8N_URL')
const N8N_API_KEY = getEnv('N8N_API_KEY')
const WORKFLOW_ID = 'tUiEY7LpGe7zOvW8'

async function run() {
  const res = await fetch(`${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}`, {
    headers: { 'X-N8N-API-KEY': N8N_API_KEY }
  })
  const w = await res.json()

  console.log('=== Nodes with credentials in live workflow ===')
  w.nodes.forEach(n => {
    if (n.credentials) console.log(`  "${n.name}" -> ${JSON.stringify(n.credentials)}`)
  })

  console.log('\n=== All node names in live workflow ===')
  w.nodes.forEach(n => console.log(`  "${n.name}" [${n.type}]`))

  console.log('\n=== Local workflow node names that need credentials ===')
  const local = JSON.parse(fs.readFileSync('workflows/stakeholder/intake_receiver.json', 'utf8').replace(/^﻿/, ''))
  local.nodes.forEach(n => {
    // Types that require credentials
    if (n.type.includes('EmailSend') || n.type.includes('jira') || n.type.includes('smtp') || n.type.includes('Smtp') || n.type.includes('Jira')) {
      console.log(`  "${n.name}" [${n.type}] creds: ${JSON.stringify(n.credentials)}`)
    }
  })
}
run().catch(e => { console.error(e.message); process.exit(1) })
