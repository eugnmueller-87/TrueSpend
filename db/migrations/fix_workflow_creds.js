// Fix missing credentials in intake_receiver workflow nodes
const fs = require('fs')

const envLines = fs.readFileSync('.env', 'utf8').split('\n')
const getEnv = (key) => envLines.find(l => l.startsWith(key + '='))?.replace(key + '=', '').trim()

const N8N_URL = getEnv('N8N_URL')
const N8N_API_KEY = getEnv('N8N_API_KEY')
const WORKFLOW_ID = 'tUiEY7LpGe7zOvW8'

// Credential IDs from n8n credential store
const SMTP_CRED = { id: '4nJqszHi2HtSAqVx', name: 'SMTP-TrueSpend' }
const JIRA_CRED = { id: 'MYydmb8FjLgo9CxM', name: 'Jira TrueSpend' }

async function run() {
  const headers = { 'X-N8N-API-KEY': N8N_API_KEY, 'Content-Type': 'application/json' }

  // Get current workflow
  const res = await fetch(`${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}`, { headers })
  const wf = await res.json()
  console.log(`Got workflow: ${wf.name} (${wf.nodes.length} nodes)`)

  // Assign credentials to matching nodes
  let fixed = 0
  const updatedNodes = wf.nodes.map(node => {
    if (node.type === 'n8n-nodes-base.emailSend') {
      console.log(`  Assigning SMTP cred to: "${node.name}"`)
      fixed++
      return { ...node, credentials: { smtp: SMTP_CRED } }
    }
    if (node.type === 'n8n-nodes-base.jira') {
      console.log(`  Assigning Jira cred to: "${node.name}"`)
      fixed++
      return { ...node, credentials: { jiraSoftwareCloudApi: JIRA_CRED } }
    }
    return node
  })

  console.log(`Fixed ${fixed} nodes`)

  // Deactivate first (to avoid validation on PUT)
  console.log('Deactivating workflow...')
  await fetch(`${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}/deactivate`, { method: 'POST', headers })

  // PUT with credentials
  const putRes = await fetch(`${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}`, {
    method: 'PUT',
    headers,
    body: JSON.stringify({
      name: wf.name,
      nodes: updatedNodes,
      connections: wf.connections,
      settings: { executionOrder: 'v1' },
    })
  })

  if (!putRes.ok) {
    const text = await putRes.text()
    throw new Error(`PUT failed: ${putRes.status} ${text}`)
  }
  const updated = await putRes.json()
  console.log(`✓ Workflow updated with credentials`)

  // Reactivate
  console.log('Reactivating workflow...')
  const activateRes = await fetch(`${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}/activate`, { method: 'POST', headers })
  if (activateRes.ok) {
    console.log('✓ Workflow activated')
  } else {
    const t = await activateRes.text()
    console.log(`⚠ Activate response: ${activateRes.status} ${t}`)
  }

  // Verify nodes have credentials
  const verifyRes = await fetch(`${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}`, { headers })
  const verified = await verifyRes.json()
  console.log('\nVerification — nodes with credentials:')
  verified.nodes.forEach(n => {
    if (n.credentials) console.log(`  "${n.name}" -> ${JSON.stringify(n.credentials)}`)
  })
  console.log(`Active: ${verified.active}`)
}

run().catch(e => { console.error('FATAL:', e.message); process.exit(1) })
