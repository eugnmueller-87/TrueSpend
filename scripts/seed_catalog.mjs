import { createRequire } from 'module'
const require = createRequire(import.meta.url)
const { Client } = require('pg')
const c = new Client({host:'zephyr.proxy.rlwy.net',port:24934,database:'truespend',user:'truespend',<REDACTED_ROTATE_ME>:'<REDACTED_ROTATE_ME>',ssl:false})
await c.connect()

// Create catalog_items table
await c.query(`
CREATE TABLE IF NOT EXISTS catalog_items (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id  UUID REFERENCES suppliers(id),
  sku          TEXT NOT NULL,
  name         TEXT NOT NULL,
  description  TEXT,
  category     TEXT NOT NULL,
  unit_price   NUMERIC(12,2),
  currency     TEXT DEFAULT 'EUR',
  price_per    TEXT,
  variable     BOOLEAN DEFAULT FALSE,
  active       BOOLEAN DEFAULT TRUE,
  contract_id  UUID REFERENCES contracts(id),
  sort_order   INT DEFAULT 99,
  created_at   TIMESTAMPTZ DEFAULT now()
)`)
console.log('catalog_items table ready')

// Get supplier IDs
const s = await c.query(`SELECT id, name FROM suppliers ORDER BY name`)
const sup = {}
s.rows.forEach(r => { sup[r.name] = r.id })
console.log('Suppliers found:', Object.keys(sup).join(', '))

const items = [
  // Apple
  { supplier: 'Apple', sku: 'APPMBP14M3PRO', name: 'MacBook Pro 14"',           category: 'hardware',      unit_price: 2199,  desc: 'M3 Pro, 18 GB, 512 GB. Standard dev config.' },
  { supplier: 'Apple', sku: 'APPMBP16M3MAX', name: 'MacBook Pro 16"',           category: 'hardware',      unit_price: 2999,  desc: 'M3 Max, 36 GB, 1 TB. Engineering power config.' },
  { supplier: 'Apple', sku: 'APPIPH15P256',  name: 'iPhone 15 Pro',             category: 'hardware',      unit_price: 1199,  desc: '256 GB. Standard corporate mobile.' },
  { supplier: 'Apple', sku: 'APPIPAD11PRO',  name: 'iPad Pro 11"',              category: 'hardware',      unit_price: 1099,  desc: 'M4, 256 GB, Wi-Fi. Field and exec config.' },
  // Dell Technologies
  { supplier: 'Dell Technologies', sku: 'DELLU2723QE', name: 'Dell UltraSharp 27"',  category: 'hardware', unit_price: 549,   desc: '4K USB-C monitor, 90 W PD. Standard desk monitor.' },
  { supplier: 'Dell Technologies', sku: 'DELLU3223QE', name: 'Dell UltraSharp 32"',  category: 'hardware', unit_price: 899,   desc: '4K IPS, USB-C 90W. Extended workspace monitor.' },
  { supplier: 'Dell Technologies', sku: 'DELLDOCK180', name: 'Dell Dock WD19S',      category: 'hardware', unit_price: 199,   desc: '180W USB-C docking station. Standard config.' },
  { supplier: 'Dell Technologies', sku: 'DELLT14S',    name: 'Latitude 14 5440',     category: 'hardware', unit_price: 1349,  desc: 'Core i7, 16 GB, 512 GB. Windows standard laptop.' },
  // Lenovo
  { supplier: 'Lenovo', sku: 'LENT14SAMD', name: 'ThinkPad T14s AMD',   category: 'hardware', unit_price: 1199, desc: 'Ryzen 7, 16 GB, 512 GB. DACH engineering standard.' },
  { supplier: 'Lenovo', sku: 'LENT16I7',   name: 'ThinkPad T16 Intel',  category: 'hardware', unit_price: 1499, desc: 'Core i7, 32 GB, 1 TB. Power user Windows config.' },
  { supplier: 'Lenovo', sku: 'LENP16S',    name: 'ThinkPad P16s',       category: 'hardware', unit_price: 1799, desc: 'Ryzen 9 PRO, 32 GB, 1 TB. Data science workstation.' },
  // Microsoft 365
  { supplier: 'Microsoft 365', sku: 'MS365E3',  name: 'Microsoft 365 E3',   category: 'saas_license', unit_price: 36,  price_per: '/user/mo', desc: 'Teams, Outlook, Office apps, SharePoint, Intune.' },
  { supplier: 'Microsoft 365', sku: 'MS365E5',  name: 'Microsoft 365 E5',   category: 'saas_license', unit_price: 57,  price_per: '/user/mo', desc: 'E3 plus advanced security, compliance, analytics.' },
  { supplier: 'Microsoft 365', sku: 'GHENT',    name: 'GitHub Enterprise',  category: 'saas_license', unit_price: 21,  price_per: '/user/mo', desc: 'Advanced Security plus GHAS. Per active committer.' },
  { supplier: 'Microsoft 365', sku: 'AZDEV',    name: 'Azure DevOps',       category: 'saas_license', unit_price: 6,   price_per: '/user/mo', desc: 'Boards, Repos, Pipelines, Artifacts.' },
  // Salesforce
  { supplier: 'Salesforce', sku: 'SFSCENT',  name: 'Sales Cloud Enterprise',  category: 'saas_license', unit_price: 165, price_per: '/user/mo', desc: 'CRM, forecasting, pipeline management.' },
  { supplier: 'Salesforce', sku: 'SFSLKPRO', name: 'Slack Pro',               category: 'saas_license', unit_price: 8,   price_per: '/user/mo', desc: 'Standard messaging workspace.' },
  { supplier: 'Salesforce', sku: 'SFSLKBIZ', name: 'Slack Business+',         category: 'saas_license', unit_price: 15,  price_per: '/user/mo', desc: 'Advanced admin, data exports, SAML SSO.' },
  // AWS
  { supplier: 'AWS', sku: 'AWS-RI-1Y',  name: 'EC2 Reserved 1yr',    category: 'cloud_compute', unit_price: null, variable: true, desc: 'Variable. Agent checks utilisation before committing.' },
  { supplier: 'AWS', sku: 'AWS-RI-3Y',  name: 'EC2 Reserved 3yr',    category: 'cloud_compute', unit_price: null, variable: true, desc: 'Variable. 3-year commitment, agent reviews TCO.' },
  { supplier: 'AWS', sku: 'AWS-SAV',    name: 'AWS Savings Plan',     category: 'cloud_compute', unit_price: null, variable: true, desc: 'Compute savings plan. Agent verifies spend baseline.' },
  // Google Cloud
  { supplier: 'Google Cloud', sku: 'GCP-CUD-1Y', name: 'GCP Committed Use 1yr', category: 'cloud_compute', unit_price: null, variable: true, desc: 'Variable. Agent checks prior 90-day spend.' },
  { supplier: 'Google Cloud', sku: 'GCP-CUD-3Y', name: 'GCP Committed Use 3yr', category: 'cloud_compute', unit_price: null, variable: true, desc: 'Variable. 3-year CUD, agent models break-even.' },
]

// Clear existing and re-insert
await c.query('DELETE FROM catalog_items')
let inserted = 0
for (const item of items) {
  const sid = sup[item.supplier]
  if (!sid) { console.log('MISSING supplier:', item.supplier); continue }
  await c.query(
    `INSERT INTO catalog_items (supplier_id, sku, name, description, category, unit_price, currency, price_per, variable, active)
     VALUES ($1,$2,$3,$4,$5,$6,'EUR',$7,$8,true)`,
    [sid, item.sku, item.name, item.desc, item.category, item.unit_price ?? null, item.price_per ?? null, item.variable ?? false]
  )
  inserted++
}
console.log(`Inserted ${inserted} items`)

// Create view
await c.query(`
CREATE OR REPLACE VIEW catalog_by_supplier AS
SELECT
  ci.id, ci.sku, ci.name, ci.description, ci.category,
  ci.unit_price, ci.currency, ci.price_per, ci.variable,
  ci.sort_order,
  s.id       AS supplier_id,
  s.name     AS supplier_name,
  s.health   AS supplier_health,
  s.category AS supplier_category
FROM catalog_items ci
JOIN suppliers s ON s.id = ci.supplier_id
WHERE ci.active = true
ORDER BY s.name, ci.category, ci.sort_order, ci.name`)

const chk = await c.query('SELECT supplier_name, count(*) FROM catalog_by_supplier GROUP BY supplier_name ORDER BY supplier_name')
console.log('catalog_by_supplier:')
chk.rows.forEach(r => console.log(` ${r.supplier_name}: ${r.count} items`))

await c.end()
