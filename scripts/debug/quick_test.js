// Quick test using https module directly
const https = require('https')
const fs = require('fs')

const envLines = fs.readFileSync('.env', 'utf8').split('\n')
const getEnv = (key) => envLines.find(l => l.startsWith(key + '='))?.replace(key + '=', '').trim()

const N8N_URL = getEnv('N8N_URL')
const N8N_API_KEY = getEnv('N8N_API_KEY')
const N8N_WEBHOOK = getEnv('N8N_WEBHOOK_BASE')
const POSTGREST_URL = getEnv('POSTGREST_URL')
const JWT = getEnv('POSTGREST_JWT')

function httpsGet(url, headers = {}) {
  return new Promise((resolve, reject) => {
    const u = new URL(url)
    const req = https.request({
      hostname: u.hostname, port: 443,
      path: u.pathname + u.search,
      method: 'GET', headers,
      rejectUnauthorized: false
    }, res => {
      const chunks = []
      res.on('data', c => chunks.push(c))
      res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(chunks).toString() }))
    })
    req.on('error', reject)
    req.end()
  })
}

function httpsPost(url, data, headers = {}) {
  return new Promise((resolve, reject) => {
    const body = typeof data === 'string' ? data : JSON.stringify(data)
    const u = new URL(url)
    const req = https.request({
      hostname: u.hostname, port: 443,
      path: u.pathname + u.search,
      method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body), ...headers },
      rejectUnauthorized: false
    }, res => {
      const chunks = []
      res.on('data', c => chunks.push(c))
      res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(chunks).toString() }))
    })
    req.on('error', reject)
    req.write(body)
    req.end()
  })
}

async function run() {
  // Check workflow status
  const { body: wfBody } = await httpsGet(`${N8N_URL}/api/v1/workflows/tUiEY7LpGe7zOvW8`, { 'X-N8N-API-KEY': N8N_API_KEY })
  const wf = JSON.parse(wfBody)
  console.log(`Workflow: ${wf.name}, active: ${wf.active}`)
  const credNodes = wf.nodes.filter(n => n.credentials)
  console.log(`Credentials on nodes: ${credNodes.map(n => n.name).join(', ')}`)

  // Submit intake
  console.log('\nPosting to webhook...')
  const { status, body } = await httpsPost(`${N8N_WEBHOOK}/intake`, {
    title: 'E2E: Dell Laptops DACH',
    description: '15x Dell Latitude 5540 DACH sales',
    supplier_name: 'Dell Technologies',
    value_eur: 18500, category: 'hardware',
    branch_id: 'b1000000-0000-0000-0000-000000000002',
    submitted_by: 'Procurement Manager (DACH)',
    submitted_by_email: 'procurement.dach@truespend.com',
    ticket_type: 'purchase',
    cost_center_id: 'cc000000-0000-0000-0000-000000000003'
  })
  console.log(`Webhook: ${status} → ${body.substring(0, 200)}`)

  // Wait 20s for Claude
  console.log('Waiting 20s for Claude...')
  await new Promise(r => setTimeout(r, 20000))

  // Check executions
  const { body: execBody } = await httpsGet(`${N8N_URL}/api/v1/executions?workflowId=tUiEY7LpGe7zOvW8&limit=3`, { 'X-N8N-API-KEY': N8N_API_KEY })
  const execs = JSON.parse(execBody)
  console.log('\nRecent executions:')
  for (const e of execs.data || []) {
    console.log(`  ${e.id} ${e.status} ${e.startedAt} → ${e.stoppedAt}`)
  }

  // Get detail of latest
  if (execs.data?.[0]) {
    const lid = execs.data[0].id
    const { body: detailBody } = await httpsGet(`${N8N_URL}/api/v1/executions/${lid}?includeData=true`, { 'X-N8N-API-KEY': N8N_API_KEY })
    const detail = JSON.parse(detailBody)
    const rd = detail.data?.resultData
    if (rd?.runData) {
      const nodes = Object.keys(rd.runData)
      console.log('\nNodes ran:', nodes.join(' → '))
      const last = nodes[nodes.length - 1]
      const lastRun = rd.runData[last]?.[0]
      if (lastRun?.error) console.log(`"${last}" error:`, JSON.stringify(lastRun.error).substring(0, 400))
    }
    if (rd?.error) console.log('Top-level error:', JSON.stringify(rd.error).substring(0, 400))
  }

  // Check newest ticket
  const { body: tBody } = await httpsGet(`${POSTGREST_URL}/tickets?order=created_at.desc&limit=3&select=id,reference,title,status,submitted_by_email,created_at`, { 'Authorization': `Bearer ${JWT}` })
  const tickets = JSON.parse(tBody)
  console.log('\nLatest tickets:')
  tickets.forEach(t => console.log(`  ${t.reference} [${t.status}] "${t.title?.substring(0,45)}" ${t.submitted_by_email}`))
}

run().catch(e => { console.error('Error:', e.message); process.exit(1) })
