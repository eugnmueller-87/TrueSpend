// Push updated intake_receiver.json to n8n via API
const fs = require('fs')

const envLines = fs.readFileSync('.env', 'utf8').split('\n')
const getEnv = (key) => envLines.find(l => l.startsWith(key + '='))?.replace(key + '=', '').trim()

const N8N_URL = getEnv('N8N_URL')
const N8N_API_KEY = getEnv('N8N_API_KEY')
const WORKFLOW_ID = 'tUiEY7LpGe7zOvW8' // active intake receiver

const localWorkflow = JSON.parse(fs.readFileSync('workflows/stakeholder/intake_receiver.json', 'utf8').replace(/^﻿/, ''))

async function run() {
  // Get current workflow from n8n
  const getRes = await fetch(`${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}`, {
    headers: { 'X-N8N-API-KEY': N8N_API_KEY }
  })
  if (!getRes.ok) throw new Error(`GET failed: ${getRes.status} ${await getRes.text()}`)
  const current = await getRes.json()

  // Build a credentials map from current live workflow (node name -> credentials)
  const credMap = {}
  for (const node of current.nodes) {
    if (node.credentials) credMap[node.name] = node.credentials
  }

  // Apply live credentials to local nodes (by node name match)
  const mergedNodes = localWorkflow.nodes.map(node => {
    if (credMap[node.name]) {
      return { ...node, credentials: credMap[node.name] }
    }
    // Try partial name match
    const liveMatch = Object.keys(credMap).find(name =>
      name.includes(node.name.substring(0, 10)) ||
      node.name.includes(name.substring(0, 10))
    )
    if (liveMatch) return { ...node, credentials: credMap[liveMatch] }
    return node
  })

  // n8n API PUT requires: name, nodes, connections, settings (executionOrder only)
  const updated = {
    name: current.name,
    nodes: mergedNodes,
    connections: localWorkflow.connections,
    settings: { executionOrder: 'v1' },
  }

  // PUT the updated workflow
  const putRes = await fetch(`${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}`, {
    method: 'PUT',
    headers: {
      'X-N8N-API-KEY': N8N_API_KEY,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(updated)
  })

  if (!putRes.ok) {
    const text = await putRes.text()
    throw new Error(`PUT failed: ${putRes.status} ${text}`)
  }

  const result = await putRes.json()
  console.log(`✓ Workflow updated: ${result.name} (${result.id})`)
  console.log(`  Active: ${result.active}`)
  console.log(`  Nodes: ${result.nodes.length}`)

  // Verify the compliance_status fix is in place
  const jsCode = JSON.stringify(result.nodes)
  if (jsCode.includes("compliance_status === 'green'")) {
    console.log(`✓ compliance_status check: 'green' ✓`)
  } else if (jsCode.includes("compliance_status === 'approved'")) {
    console.log(`✗ compliance_status still checking 'approved'`)
  } else {
    console.log(`? compliance_status check: pattern not found`)
  }
}

run().catch(e => { console.error('FATAL:', e.message); process.exit(1) })
