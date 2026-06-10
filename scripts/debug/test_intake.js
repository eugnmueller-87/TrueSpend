// Test intake webhook and check execution status
const https = require('https')
const http = require('http')
const fs = require('fs')

// Polyfill fetch for older node
if (!globalThis.fetch) {
  globalThis.fetch = async (url, options = {}) => {
    return new Promise((resolve, reject) => {
      const urlObj = new URL(url)
      const lib = urlObj.protocol === 'https:' ? https : http
      const req = lib.request({
        hostname: urlObj.hostname,
        port: urlObj.port || (urlObj.protocol === 'https:' ? 443 : 80),
        path: urlObj.pathname + urlObj.search,
        method: options.method || 'GET',
        headers: options.headers || {},
      }, (res) => {
        const chunks = []
        res.on('data', c => chunks.push(c))
        res.on('end', () => {
          const body = Buffer.concat(chunks).toString()
          resolve({
            ok: res.statusCode >= 200 && res.statusCode < 300,
            status: res.statusCode,
            text: () => Promise.resolve(body),
            json: () => Promise.resolve(JSON.parse(body)),
          })
        })
      })
      req.on('error', reject)
      if (options.body) req.write(options.body)
      req.end()
    })
  }
}

const envLines = fs.readFileSync('.env', 'utf8').split('\n')
const getEnv = (key) => envLines.find(l => l.startsWith(key + '='))?.replace(key + '=', '').trim()

const N8N_URL = getEnv('N8N_URL')
const N8N_API_KEY = getEnv('N8N_API_KEY')
const N8N_WEBHOOK = getEnv('N8N_WEBHOOK_BASE')
const POSTGREST_URL = getEnv('POSTGREST_URL')
const JWT = getEnv('POSTGREST_JWT')

async function run() {
  // Check workflow status
  const wfRes = await fetch(`${N8N_URL}/api/v1/workflows/tUiEY7LpGe7zOvW8`, {
    headers: { 'X-N8N-API-KEY': N8N_API_KEY }
  })
  const wf = await wfRes.json()
  console.log(`Workflow: ${wf.name}, active: ${wf.active}`)

  // Count nodes with credentials
  const credNodes = wf.nodes.filter(n => n.credentials)
  console.log(`Nodes with credentials: ${credNodes.map(n => n.name).join(', ')}`)

  // Submit intake request
  console.log('\nSubmitting intake request...')
  const payload = {
    title: 'E2E Test: Dell Laptops DACH Q2',
    description: '15x Dell Latitude 5540 for DACH sales team refresh',
    supplier_name: 'Dell Technologies',
    value_eur: 18500,
    category: 'hardware',
    branch_id: 'b1000000-0000-0000-0000-000000000002',
    submitted_by: 'Procurement Manager (DACH)',
    submitted_by_email: 'procurement.dach@truespend.com',
    ticket_type: 'purchase',
    cost_center_id: 'cc000000-0000-0000-0000-000000000003'
  }

  const submitRes = await fetch(`${N8N_WEBHOOK}/intake`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  })
  console.log(`Webhook response: ${submitRes.status}`)
  const submitBody = await submitRes.text()
  console.log(`Response body: ${submitBody.substring(0, 200)}`)

  // Wait for execution
  console.log('\nWaiting for workflow to process...')
  await new Promise(r => setTimeout(r, 15000))

  // Check executions
  const execRes = await fetch(`${N8N_URL}/api/v1/executions?workflowId=tUiEY7LpGe7zOvW8&limit=3`, {
    headers: { 'X-N8N-API-KEY': N8N_API_KEY }
  })
  const execs = await execRes.json()
  console.log('\nRecent executions:')
  for (const e of execs.data || []) {
    console.log(`  id:${e.id} status:${e.status} started:${e.startedAt} stopped:${e.stoppedAt}`)
  }

  // Get detailed error from latest execution
  if (execs.data?.[0]?.id) {
    const latestId = execs.data[0].id
    const detailRes = await fetch(`${N8N_URL}/api/v1/executions/${latestId}?includeData=true`, {
      headers: { 'X-N8N-API-KEY': N8N_API_KEY }
    })
    const detail = await detailRes.json()
    const rd = detail.data?.resultData
    if (rd?.error) {
      console.log('\nExecution error:')
      console.log(JSON.stringify(rd.error, null, 2).substring(0, 1000))
    }
    if (rd?.runData) {
      const nodes = Object.keys(rd.runData)
      console.log('\nNodes that ran:', nodes.join(' → '))
      const lastNode = nodes[nodes.length - 1]
      const lastRun = rd.runData[lastNode]?.[0]
      if (lastRun?.error) {
        console.log(`\n"${lastNode}" error:`)
        console.log(JSON.stringify(lastRun.error, null, 2).substring(0, 500))
      }
    }
  }

  // Check if new ticket was created
  const ticketsRes = await fetch(`${POSTGREST_URL}/tickets?order=created_at.desc&limit=2&select=id,reference,title,status,submitted_by_email,created_at`, {
    headers: { 'Authorization': `Bearer ${JWT}` }
  })
  const tickets = await ticketsRes.json()
  console.log('\nMost recent tickets:')
  tickets.forEach(t => console.log(`  ${t.reference} [${t.status}] ${t.title} by ${t.submitted_by_email}`))
}

run().catch(e => { console.error('FATAL:', e.message); console.error(e.stack); process.exit(1) })
