// Patch just the Pre-Check Gate node code in the live n8n workflow
// Approach: GET workflow, modify node, PATCH inactive copy, activate
const fs = require('fs')

const envLines = fs.readFileSync('.env', 'utf8').split('\n')
const getEnv = (key) => envLines.find(l => l.startsWith(key + '='))?.replace(key + '=', '').trim()

const N8N_URL = getEnv('N8N_URL')
const N8N_API_KEY = getEnv('N8N_API_KEY')
const ACTIVE_ID = 'tUiEY7LpGe7zOvW8'
const INACTIVE_ID = 'vH3Q5qftisZkBR3M'

async function run() {
  const headers = { 'X-N8N-API-KEY': N8N_API_KEY, 'Content-Type': 'application/json' }

  // Step 1: Get the active workflow
  const getRes = await fetch(`${N8N_URL}/api/v1/workflows/${ACTIVE_ID}`, { headers })
  const active = await getRes.json()
  console.log(`Got active workflow: ${active.name} (${active.nodes.length} nodes)`)

  // Step 2: Find and patch the Pre-Check Gate node
  const preCheckNode = active.nodes.find(n => n.name === 'Pre-Check Gate')
  if (!preCheckNode) throw new Error('Pre-Check Gate node not found')

  const oldCode = preCheckNode.parameters?.jsCode || ''
  if (oldCode.includes("compliance_status === 'green'")) {
    console.log(`✓ Pre-Check Gate already uses compliance_status === 'green' in active workflow`)
    return
  }

  const newCode = oldCode.replace(
    "compliance_status === 'approved'",
    "compliance_status === 'green'"
  )

  if (newCode === oldCode) {
    console.log('⚠ No change needed — pattern not found in Pre-Check Gate code')
    console.log('Current code snippet:', oldCode.slice(oldCode.indexOf('compliance_status') - 20, oldCode.indexOf('compliance_status') + 50))
    return
  }

  preCheckNode.parameters.jsCode = newCode
  console.log(`✓ Updated Pre-Check Gate: 'approved' → 'green'`)

  // Step 3: Try to update the INACTIVE workflow (less validation sometimes)
  // First get inactive to see its structure
  const getInactiveRes = await fetch(`${N8N_URL}/api/v1/workflows/${INACTIVE_ID}`, { headers })
  const inactive = await getInactiveRes.json()
  console.log(`Got inactive workflow: ${inactive.name}`)

  // Update inactive with the fixed nodes from active
  const updateBody = {
    name: inactive.name,
    nodes: active.nodes, // use patched nodes from active
    connections: active.connections,
    settings: { executionOrder: 'v1' },
  }

  const putRes = await fetch(`${N8N_URL}/api/v1/workflows/${INACTIVE_ID}`, {
    method: 'PUT',
    headers,
    body: JSON.stringify(updateBody)
  })
  if (!putRes.ok) {
    const text = await putRes.text()
    console.log(`PUT inactive failed: ${putRes.status} ${text}`)
    console.log('\nFalling back: saving patched workflow locally for manual import...')

    // Save a clean copy for manual import via n8n UI
    const exportable = {
      ...active,
      nodes: active.nodes,
      connections: active.connections,
    }
    // Remove runtime-only fields
    delete exportable.id
    delete exportable.createdAt
    delete exportable.updatedAt
    delete exportable.staticData
    fs.writeFileSync('workflows/stakeholder/intake_receiver_patched.json', JSON.stringify(exportable, null, 2))
    console.log('✓ Saved patched workflow to workflows/stakeholder/intake_receiver_patched.json')
    console.log('  Import this file via n8n UI → Settings → Import')
    return
  }

  const updated = await putRes.json()
  console.log(`✓ Updated inactive workflow: ${updated.name}`)

  // Activate inactive, deactivate active
  console.log('Swapping active/inactive...')
  await fetch(`${N8N_URL}/api/v1/workflows/${ACTIVE_ID}/deactivate`, { method: 'POST', headers })
  await fetch(`${N8N_URL}/api/v1/workflows/${INACTIVE_ID}/activate`, { method: 'POST', headers })
  console.log(`✓ ${ACTIVE_ID} deactivated, ${INACTIVE_ID} activated`)
}

run().catch(e => { console.error('FATAL:', e.message); process.exit(1) })
