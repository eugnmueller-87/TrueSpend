import { createRequire } from 'module'
const require = createRequire(import.meta.url)
const { Client } = require('pg')

const c = new Client({
  host: 'zephyr.proxy.rlwy.net', port: 24934,
  database: 'truespend', user: 'truespend',
  password: '<REDACTED_ROTATE_ME>', ssl: false
})
await c.connect()
console.log('Connected')

// ── Helpers ────────────────────────────────────────────────────
const q  = (sql, p=[]) => c.query(sql, p)
const ok = (label) => console.log('  ✓', label)
// Convert our semantic IDs to valid UUIDs: replace non-hex prefix chars
// le → e1, la → 1a, iv → 4b, pi → 91, as → a5
const uid = (s) => s
  .replace(/^le/,'e1').replace(/^la/,'1a')
  .replace(/^iv/,'4b').replace(/^pi/,'91')
  .replace(/^as/,'a5')

// ── 0. Budget buckets ─────────────────────────────────────────
await q(`
  UPDATE budget_buckets SET
    allocated_eur = CASE category
      WHEN 'hardware'       THEN 480000
      WHEN 'saas_license'   THEN 320000
      WHEN 'hyperscaler'    THEN 260000
      WHEN 'services'       THEN 180000
      WHEN 'ai_consumption' THEN  60000
      WHEN 'telecoms'       THEN  40000
      WHEN 'facilities'     THEN  30000
      ELSE 20000 END,
    committed_eur = CASE category
      WHEN 'hardware'       THEN 310000
      WHEN 'saas_license'   THEN 240000
      WHEN 'hyperscaler'    THEN 195000
      WHEN 'services'       THEN  92000
      WHEN 'ai_consumption' THEN  38000
      WHEN 'telecoms'       THEN  28000
      WHEN 'facilities'     THEN  18000
      ELSE 9000 END,
    spent_eur = CASE category
      WHEN 'hardware'       THEN 205000
      WHEN 'saas_license'   THEN 148000
      WHEN 'hyperscaler'    THEN 142000
      WHEN 'services'       THEN  54000
      WHEN 'ai_consumption' THEN  21000
      WHEN 'telecoms'       THEN  19000
      WHEN 'facilities'     THEN  11000
      ELSE 4000 END
  WHERE fiscal_year = 2026 AND quarter = 2`)
// DACH hardware — near limit (overrun demo)
await q(`UPDATE budget_buckets SET allocated_eur=380000, committed_eur=362000, spent_eur=298000
  WHERE branch_id='b1000000-0000-0000-0000-000000000002' AND category='hardware' AND quarter=2`)
// France SaaS — over-committed (rejection demo)
await q(`UPDATE budget_buckets SET allocated_eur=95000, committed_eur=97400, spent_eur=61000
  WHERE branch_id='b1000000-0000-0000-0000-000000000005' AND category='saas_license' AND quarter=2`)
ok('Budget buckets updated')

// ── 1. License entitlements ────────────────────────────────────
await q(`DELETE FROM license_assignments`)
await q(`DELETE FROM license_entitlements`)
const le = [
  ['e1000001-0000-0000-0000-000000000001','Microsoft 365 E3','f1000000-0000-0000-0000-000000000007','b1000000-0000-0000-0000-000000000002','c1000000-0000-0000-0000-000000000002',320,298,281,22,6.9,22,87.8,72,36.00,138240,'named_user','2025-08-01','2026-07-31'],
  ['e1000001-0000-0000-0000-000000000002','Microsoft 365 E5','f1000000-0000-0000-0000-000000000007','b1000000-0000-0000-0000-000000000003','c1000000-0000-0000-0000-000000000012',500,487,341,146,29.2,13,68.2,38,57.00,342000,'named_user','2025-07-15','2026-07-14'],
  ['e1000001-0000-0000-0000-000000000003','Salesforce Sales Cloud','f1000000-0000-0000-0000-000000000008','b1000000-0000-0000-0000-000000000005','c1000000-0000-0000-0000-000000000007',85,91,88,3,3.5,0,103.5,81,165.00,180180,'named_user','2025-06-30','2026-06-29'],
  ['e1000001-0000-0000-0000-000000000004','Slack Business+','f1000000-0000-0000-0000-000000000011','b1000000-0000-0000-0000-000000000006','c1000000-0000-0000-0000-000000000004',140,128,122,18,12.9,12,87.1,68,15.00,25200,'named_user','2025-08-01','2026-07-31'],
  ['e1000001-0000-0000-0000-000000000005','GitHub Enterprise','f1000000-0000-0000-0000-000000000007','b1000000-0000-0000-0000-000000000001',null,200,167,154,46,23.0,33,77.0,55,21.00,50400,'named_user','2025-09-01','2026-08-31'],
  ['e1000001-0000-0000-0000-000000000006','Workday HCM','f1000000-0000-0000-0000-000000000010','b1000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000013',150,141,138,12,8.0,9,92.0,78,45.00,81000,'named_user','2025-01-01','2026-12-31'],
  ['e1000001-0000-0000-0000-000000000007','Zoom Business','f1000000-0000-0000-0000-000000000012','b1000000-0000-0000-0000-000000000004','c1000000-0000-0000-0000-000000000010',60,44,38,22,36.7,16,63.3,41,14.90,10728,'named_user','2025-07-04','2026-07-03'],
  ['e1000001-0000-0000-0000-000000000008','Azure DevOps','f1000000-0000-0000-0000-000000000006','b1000000-0000-0000-0000-000000000001',null,80,74,71,9,11.25,6,88.75,65,6.00,5760,'named_user','2025-10-01','2026-09-30'],
]
for (const r of le) {
  // r = [id,name,sup,branch,contract,total,assigned,active,shelfware_seats,shelfware_pct,available(skip),util,depth,price,cost,type,start,end]
  // available_seats is a generated column — omit it (index 10)
  const rv = [...r.slice(0,10), ...r.slice(11)]
  await q(`INSERT INTO license_entitlements
    (id,product_name,supplier_id,branch_id,contract_id,total_seats,assigned_seats,active_seats,
     shelfware_seats,shelfware_pct,utilization_pct,avg_feature_usage_depth,
     price_per_seat,price_currency,total_cost_eur,license_type,term_start,term_end,
     true_up_date,true_up_frequency)
    VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,'EUR',$14,$15,$16,$17,$17,'annual')`,
    rv)
}
ok(`License entitlements: ${le.length}`)

// ── 2. License assignments ────────────────────────────────────
const la = [
  // M365 E3 DACH
  ['1a000001-0000-0000-0000-000000000001','e1000001-0000-0000-0000-000000000001','Lena Hoffmann',     180, true,  88, 1],
  ['1a000001-0000-0000-0000-000000000002','e1000001-0000-0000-0000-000000000001','Jonas Weber',       175, true,  72, 2],
  ['1a000001-0000-0000-0000-000000000003','e1000001-0000-0000-0000-000000000001','Anna Schulz',       170, true,  91, 0],
  ['1a000001-0000-0000-0000-000000000004','e1000001-0000-0000-0000-000000000001','Klaus Bauer',       165, true,  34, 12],
  ['1a000001-0000-0000-0000-000000000005','e1000001-0000-0000-0000-000000000001','Petra Fischer',      90, false,  0, 95],
  // M365 E5 UK — shelfware
  ['1a000001-0000-0000-0000-000000000010','e1000001-0000-0000-0000-000000000002','James Harrison',    200, true,  91, 1],
  ['1a000001-0000-0000-0000-000000000011','e1000001-0000-0000-0000-000000000002','Sophie Williams',   198, true,  82, 3],
  ['1a000001-0000-0000-0000-000000000012','e1000001-0000-0000-0000-000000000002','Tom Clarke',        196, false,  8, 87],
  ['1a000001-0000-0000-0000-000000000013','e1000001-0000-0000-0000-000000000002','Rachel Green',      194, false,  3, 102],
  ['1a000001-0000-0000-0000-000000000014','e1000001-0000-0000-0000-000000000002','David Okafor',      192, false,  0, 148],
  // Salesforce France
  ['1a000001-0000-0000-0000-000000000020','e1000001-0000-0000-0000-000000000003','Marie Leclerc',     300, true,  94, 0],
  ['1a000001-0000-0000-0000-000000000021','e1000001-0000-0000-0000-000000000003','Pierre Dubois',     295, true,  88, 0],
  ['1a000001-0000-0000-0000-000000000022','e1000001-0000-0000-0000-000000000003','Claire Moreau',     290, true,  76, 1],
  // GitHub Enterprise — shelfware
  ['1a000001-0000-0000-0000-000000000030','e1000001-0000-0000-0000-000000000005','Alex Chen',         365, true,  95, 0],
  ['1a000001-0000-0000-0000-000000000031','e1000001-0000-0000-0000-000000000005','Nina Patel',        360, true,  88, 0],
  ['1a000001-0000-0000-0000-000000000032','e1000001-0000-0000-0000-000000000005','Sam Torres',        355, false,  2, 180],
  ['1a000001-0000-0000-0000-000000000033','e1000001-0000-0000-0000-000000000005','Jamie Liu',         350, false,  0, 210],
]
for (const r of la) {
  const [id, eid, user, daysAgo, active, depth, lastActiveDays] = r
  await q(`INSERT INTO license_assignments
    (id,entitlement_id,assigned_to_user,assigned_at,active,usage_depth_pct,last_active_at)
    VALUES($1,$2,$3,now()-($4||' days')::interval,$5,$6,now()-($7||' days')::interval)`,
    [id,eid,user,daysAgo,active,depth,lastActiveDays])
}
ok(`License assignments: ${la.length}`)

// ── 3. Assets ─────────────────────────────────────────────────
const assets = [
  ['a5000001-0000-0000-0000-000000000001','MacBook Pro M3 #UK-001',         'b1000000-0000-0000-0000-000000000003','a8000000-0000-0000-0000-000000000003',2199,1832,'2027-06-01','active',180],
  ['a5000001-0000-0000-0000-000000000002','MacBook Pro M3 #UK-002',         'b1000000-0000-0000-0000-000000000003','a8000000-0000-0000-0000-000000000003',2199,1832,'2027-06-01','active',180],
  ['a5000001-0000-0000-0000-000000000003','MacBook Pro M3 #UK-003',         'b1000000-0000-0000-0000-000000000003','a8000000-0000-0000-0000-000000000003',2199,1832,'2027-06-01','active',180],
  ['a5000001-0000-0000-0000-000000000004','ThinkPad T14s #DACH-001',        'b1000000-0000-0000-0000-000000000002','a8000000-0000-0000-0000-000000000002',1199,999, '2028-03-01','active',120],
  ['a5000001-0000-0000-0000-000000000005','ThinkPad T14s #DACH-002',        'b1000000-0000-0000-0000-000000000002','a8000000-0000-0000-0000-000000000002',1199,999, '2028-03-01','active',120],
  ['a5000001-0000-0000-0000-000000000006','Dell UltraSharp 27" #HQ-014',    'b1000000-0000-0000-0000-000000000001',null,549,91,'2026-06-21','active',1095],
  ['a5000001-0000-0000-0000-000000000007','Dell UltraSharp 27" #HQ-015',    'b1000000-0000-0000-0000-000000000001',null,549,91,'2026-06-24','active',1095],
  ['a5000001-0000-0000-0000-000000000008','Dell PowerEdge R640 #DACH-DC-03','b1000000-0000-0000-0000-000000000002',null,18500,1850,'2026-04-15','active',1825],
  ['a5000001-0000-0000-0000-000000000009','HP ProLiant DL380 #HQ-DC-07',    'b1000000-0000-0000-0000-000000000001',null,22000,2200,'2026-03-01','active',1825],
  ['a5000001-0000-0000-0000-000000000010','MacBook Pro 2022 #FR-007',        'b1000000-0000-0000-0000-000000000005',null,2199,198,'2025-12-01','active',1095],
  ['a5000001-0000-0000-0000-000000000011','ThinkPad T14 2021 #BNL-002',      'b1000000-0000-0000-0000-000000000004',null,1299,0,'2024-11-01','decommissioned',1460],
]
for (const r of assets) {
  const [id,name,branch,po,pval,bval,warr,status,daysAgo] = r
  await q(`INSERT INTO assets (id,name,branch_id,po_id,purchase_value,book_value,warranty_expiry,status,created_at)
    VALUES($1,$2,$3,$4,$5,$6,$7,$8,now()-($9||' days')::interval)
    ON CONFLICT (id) DO NOTHING`,
    [id,name,branch,po,pval,bval,warr,status,daysAgo])
}
ok(`Assets: ${assets.length}`)

// ── 4. Asset depreciation log ─────────────────────────────────
const depr = [
  ['a5000001-0000-0000-0000-000000000001','2026-04',61.08,2076.58,60],
  ['a5000001-0000-0000-0000-000000000001','2026-05',61.08,2015.50,30],
  ['a5000001-0000-0000-0000-000000000006','2026-04',12.75,103.75,60],
  ['a5000001-0000-0000-0000-000000000006','2026-05',12.75,91.00,30],
  ['a5000001-0000-0000-0000-000000000008','2026-04',0,1850.00,60],
  ['a5000001-0000-0000-0000-000000000010','2026-04',30.54,228.54,60],
  ['a5000001-0000-0000-0000-000000000010','2026-05',30.54,198.00,30],
]
for (const [aid,period,dep,bva,daysAgo] of depr) {
  await q(`INSERT INTO asset_depreciation_log (asset_id,period,depreciation,book_value_after,created_at)
    VALUES($1,$2,$3,$4,now()-($5||' days')::interval)`,
    [aid,period,dep,bva,daysAgo])
}
ok(`Depreciation entries: ${depr.length}`)

// ── 5. Invoices ───────────────────────────────────────────────
await q(`DELETE FROM erp_sync_queue`)
await q(`DELETE FROM payment_instructions`)
await q(`DELETE FROM invoices`)
const invoices = [
  {id:'4b000001-0000-0000-0000-000000000001', po:'a8000000-0000-0000-0000-000000000005', inv:'SF-INV-2026-04892',  sup:'f1000000-0000-0000-0000-000000000008', amt:72000,  status:'approved', recv:18, matched:17, result:{result:'matched',po_amount:72000,invoice_amount:72000,delta_pct:0,within_tolerance:true}, cur:'EUR',raw:72000,rcur:'EUR',vat:13680,terms:30},
  {id:'4b000001-0000-0000-0000-000000000002', po:'a8000000-0000-0000-0000-000000000004', inv:'AWS-INV-2026-88412', sup:'f1000000-0000-0000-0000-000000000004', amt:89820,  status:'approved', recv:10, matched:9,  result:{result:'matched',po_amount:89000,invoice_amount:89820,delta_pct:0.92,within_tolerance:true,note:'FX variance on USD billing'}, cur:'EUR',raw:97850,rcur:'USD',vat:0,terms:30},
  {id:'4b000001-0000-0000-0000-000000000003', po:'a8000000-0000-0000-0000-000000000003', inv:'APL-INV-2026-20041', sup:'f1000000-0000-0000-0000-000000000003', amt:131400, status:'pending',  recv:3,  matched:null,result:{result:'mismatch',po_amount:126108,invoice_amount:131400,delta_pct:4.2,within_tolerance:false,note:'AppleCare+ charges not in PO'}, cur:'EUR',raw:131400,rcur:'EUR',vat:24966,terms:30},
  {id:'4b000001-0000-0000-0000-000000000004', po:'a8000000-0000-0000-0000-000000000001', inv:'DELL-INV-2026-77341',sup:'f1000000-0000-0000-0000-000000000001', amt:284400, status:'pending',  recv:1,  matched:null,result:{result:'pending_delivery',po_amount:284400,note:'PO not yet marked delivered'}, cur:'EUR',raw:284400,rcur:'EUR',vat:54036,terms:45},
]
for (const r of invoices) {
  const matchedAt = r.matched == null ? null : new Date(Date.now() - r.matched * 86400000)
  const receivedAt = new Date(Date.now() - r.recv * 86400000)
  const dueDate = new Date(receivedAt.getTime() + r.terms * 86400000)
  await q(`INSERT INTO invoices (id,po_id,invoice_number,supplier_id,amount_eur,status,received_at,matched_at,match_result,currency,raw_amount,raw_currency,vat_amount,payment_terms_days,due_date,created_at)
    VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb,$10,$11,$12,$13,$14,$15,$7)`,
    [r.id,r.po,r.inv,r.sup,r.amt,r.status,receivedAt,matchedAt,JSON.stringify(r.result),r.cur,r.raw,r.rcur,r.vat,r.terms,dueDate])
}
ok(`Invoices: ${invoices.length}`)

// ── 6. Payment instructions ───────────────────────────────────
await q(`INSERT INTO payment_instructions (id,invoice_id,amount_eur,due_date,status,created_at) VALUES
  ('91000001-0000-0000-0000-000000000001','4b000001-0000-0000-0000-000000000001',72000, now()+interval'12 days','pending',now()-interval'17 days'),
  ('91000001-0000-0000-0000-000000000002','4b000001-0000-0000-0000-000000000002',89820, now()+interval'20 days','pending',now()-interval'9 days')`)
ok('Payment instructions: 2')

// ── 7. ERP sync queue ─────────────────────────────────────────
await q(`INSERT INTO erp_sync_queue (entity_type,entity_id,payload,status,created_at) VALUES
  ('payment_instruction','91000001-0000-0000-0000-000000000001','{"action":"post_payment","vendor_id":"SF-0892","amount":72000,"currency":"EUR","reference":"SF-INV-2026-04892","cost_center":"CC-FR-SALES"}','pending',now()-interval'17 days'),
  ('payment_instruction','91000001-0000-0000-0000-000000000002','{"action":"post_payment","vendor_id":"AWS-0014","amount":89820,"currency":"EUR","reference":"AWS-INV-2026-88412","cost_center":"CC-HQ-INFRA"}','pending',now()-interval'9 days'),
  ('purchase_order','a8000000-0000-0000-0000-000000000001','{"action":"post_po","vendor_id":"DELL-0001","amount":284400,"currency":"EUR","po_number":"PO-HQ-2026-0041","cost_center":"CC-HQ-IT"}','synced',now()-interval'14 days')`)
ok('ERP sync queue: 3')

// ── 8. Tickets ────────────────────────────────────────────────
const tickets = [
  {ref:'TS-2026-0201', src:'intake',     status:'auto_executed',      title:'Figma Organization × 6 seats — DACH Design',                          branch:'b1000000-0000-0000-0000-000000000002', sup:null,                                       owner:'e1000000-0000-0000-0000-000000000003', by:'Lena Hoffmann',  email:'lena.hoffmann@company.com',  val:270,    disp:'auto_execute', conf:0.97, rec:'Auto-approved. Figma Org €45/seat. Budget 38% headroom. No conflict.', mins:300},
  {ref:'TS-2026-0202', src:'automatic',  status:'auto_executed',      title:'Dell Dock WD19S × 8 — Nordics reorder',                               branch:'b1000000-0000-0000-0000-000000000006', sup:'f1000000-0000-0000-0000-000000000001', owner:'e1000000-0000-0000-0000-000000000004', by:'Erik Lindqvist', email:'erik.lindqvist@company.com', val:1592,   disp:'auto_execute', conf:0.99, rec:'Auto-approved. Dell contract active. Price confirmed.', mins:180},
  {ref:'TS-2026-0203', src:'intake',     status:'pending_review',     title:'Notion Team × 12 seats — UK Product',                                 branch:'b1000000-0000-0000-0000-000000000003', sup:null,                                       owner:'e1000000-0000-0000-0000-000000000004', by:'Erik Lindqvist', email:'erik.lindqvist@company.com', val:1584,   disp:'one_touch',    conf:0.71, rec:'One-touch. No Notion contract. Capability overlap with Confluence.', mins:120},
  {ref:'TS-2026-0204', src:'intake',     status:'pending_review',     title:'Salesforce Sales Cloud — 5 additional seats France',                   branch:'b1000000-0000-0000-0000-000000000005', sup:'f1000000-0000-0000-0000-000000000008', owner:'e1000000-0000-0000-0000-000000000002', by:'Marc Dupont',    email:'marc.dupont@company.com',    val:9900,   disp:'one_touch',    conf:0.68, rec:'One-touch. France SaaS 102% committed. Entitlement already 6 over quota.', mins:90},
  {ref:'TS-2026-0205', src:'intake',     status:'escalated',          title:'McKinsey — Digital Operations Assessment €220k',                       branch:'b1000000-0000-0000-0000-000000000001', sup:null,                                       owner:'e1000000-0000-0000-0000-000000000001', by:'Sarah Brennan',  email:'sarah.brennan@company.com',  val:220000, disp:'escalate',     conf:0.91, rec:'Escalated. >€100k, new supplier, SOW overlap with Accenture.', mins:45, jira:'PROC-2205'},
  {ref:'TS-2026-0206', src:'intake',     status:'signature_required', title:'NDA — Databricks EMEA Ltd — AI Data Platform evaluation',              branch:'b1000000-0000-0000-0000-000000000001', sup:null,                                       owner:'e1000000-0000-0000-0000-000000000001', by:'Sarah Brennan',  email:'sarah.brennan@company.com',  val:0,      disp:'one_touch',    conf:0.88, rec:'NDA prepared. GDPR DPA required. InfoSec 82/100. Signature needed.', mins:30},
  {ref:'TS-2026-0207', src:'intake',     status:'pending_confirm',    title:'Apple iPhone 15 Pro × 4 — Italy sales team',                          branch:'b1000000-0000-0000-0000-000000000008', sup:'f1000000-0000-0000-0000-000000000003', owner:'e1000000-0000-0000-0000-000000000005', by:'Priya Nair',     email:'priya.nair@company.com',     val:4796,   disp:'one_touch',    conf:0.94, rec:'Catalogue item. Apple contract active. Budget available. One-touch.', mins:15},
  {ref:'TS-2026-0208', src:'renewal',    status:'auto_executed',      title:'Auto-renewed: Dell Hardware Framework — Global HQ',                    branch:'b1000000-0000-0000-0000-000000000001', sup:'f1000000-0000-0000-0000-000000000001', owner:'e1000000-0000-0000-0000-000000000001', by:'Sarah Brennan',  email:'sarah.brennan@company.com',  val:480000, disp:'auto_execute', conf:0.96, rec:'Auto-renewed. Clean terms. Extended 12mo to 2027-07-10.', mins:2880},
  {ref:'TS-2026-0209', src:'renewal',    status:'pending_review',     title:'Renewal: Salesforce Sales Cloud France — 8% price increase',           branch:'b1000000-0000-0000-0000-000000000005', sup:'f1000000-0000-0000-0000-000000000008', owner:'e1000000-0000-0000-0000-000000000002', by:'Marc Dupont',    email:'marc.dupont@company.com',    val:181764, disp:'one_touch',    conf:0.83, rec:'Counter at 3% + right-size to 79 seats. Market benchmark 4-5%.', mins:1440},
  {ref:'TS-2026-0210', src:'monitoring', status:'pending_review',     title:'AWS spend anomaly — Global HQ 3.4× spike vs 7-day avg',               branch:'b1000000-0000-0000-0000-000000000001', sup:'f1000000-0000-0000-0000-000000000004', owner:'e1000000-0000-0000-0000-000000000001', by:'Sarah Brennan',  email:'sarah.brennan@company.com',  val:48200,  disp:'one_touch',    conf:0.87, rec:'Anomaly 3.4× baseline. RI util 61% vs normal 89%. Review instances.', mins:360},
]
for (const t of tickets) {
  await q(`INSERT INTO tickets (reference,source,status,title,branch_id,supplier_id,owner_id,submitted_by,submitted_by_email,value_eur,amount_eur,disposition,recommendation,confidence,jira_key,jira_url,created_at)
    VALUES($1,$2::ticket_source,$3::ticket_status,$4,$5,$6,$7,$8,$9,$10,$10,$11::disposition,$12,$13,$14,$15,now()-($16||' minutes')::interval)
    ON CONFLICT (reference) DO NOTHING`,
    [t.ref,t.src,t.status,t.title,t.branch,t.sup||null,t.owner,t.by,t.email,t.val,t.disp,t.rec,t.conf,
     t.jira||null, t.jira ? `https://truespend.atlassian.net/browse/${t.jira}` : null, t.mins])
}
ok(`Tickets: ${tickets.length}`)

// ── 9. Decisions + trace signals ──────────────────────────────
const decisionsData = [
  { ref:'TS-2026-0201', disp:'auto_execute', conf:0.97, mins:300,
    reasoning:'All 5 signals green. Contract: catalogue price €45/seat confirmed. Budget: DACH SaaS Q2 38% headroom. Supplier: Figma health green, DPA on file. Request: normal expansion, within delegated authority €50k. Policy: no compliance blocker.',
    rec:'Auto-approve. Commit €270 to DACH SaaS Q2. Issue PO.',
    signals:[
      ['contract',    0.95, 0.20, true,  'No existing Figma contract. Catalogue price €45/seat confirmed. Standard terms.'],
      ['consumption', 0.98, 0.25, true,  'DACH SaaS Q2: €320k allocated, €240k committed. 38% headroom. This commit: €270.'],
      ['supplier',    0.97, 0.20, true,  'Figma Inc: health green. No open disputes. GDPR DPA on file. ISO 27001 certified.'],
      ['request',     0.99, 0.20, true,  'Normal seat expansion. Lena Hoffmann authority €50k. No duplicate capability.'],
      ['policy',      0.96, 0.15, true,  'No compliance blocker. Standard SaaS onboarding. No LkSG flag.'],
    ]},
  { ref:'TS-2026-0203', disp:'one_touch', conf:0.71, mins:120,
    reasoning:'Mixed signals. No Notion contract, no catalogue entry. Capability overlap with Confluence active in UK. New supplier — no DPA, no ISO 27001 evidence. Budget headroom OK but not a decision-maker here.',
    rec:'Route to review. Check Confluence utilisation first. If approved, trigger Notion Labs supplier onboarding.',
    signals:[
      ['contract',    0.40, 0.20, false, 'No Notion contract. Not in catalogue. New supplier engagement required.'],
      ['consumption', 0.78, 0.25, true,  'UK SaaS Q2 has headroom. €1,584 not a budget blocker.'],
      ['supplier',    0.35, 0.20, false, 'Notion Labs: no compliance check, no DPA, no ISO 27001. GDPR assessment required.'],
      ['request',     0.60, 0.20, false, 'Confluence already licensed for UK. Duplicate documentation tool detected.'],
      ['policy',      0.55, 0.15, false, 'New SaaS supplier — GDPR onboarding mandatory before approval.'],
    ]},
  { ref:'TS-2026-0205', disp:'escalate', conf:0.91, mins:45,
    reasoning:'Mandatory escalation. €220k exceeds €100k threshold. McKinsey not in supplier register — no contract, no compliance, no NDA. SOW scope overlaps active Accenture engagement TS-2026-0122. Legal review required.',
    rec:'Escalate to CFO + Legal. Jira PROC-2205 created. Require: NDA, SOW legal review, conflict check vs Accenture before any commitment.',
    signals:[
      ['contract',    0.10, 0.20, false, 'No McKinsey contract. No NDA. No MSA. Full supplier onboarding required.'],
      ['consumption', 0.72, 0.25, true,  'Global HQ services Q2 has capacity. Not a budget blocker.'],
      ['supplier',    0.15, 0.20, false, 'McKinsey not in supplier register. No compliance assessment. No GDPR DPA.'],
      ['request',     0.65, 0.20, false, 'SOW scope overlap with active Accenture engagement (TS-2026-0122). Duplication risk.'],
      ['policy',      0.10, 0.15, false, 'Value €220k — mandatory escalation threshold is €100k. CFO approval required.'],
    ]},
  { ref:'TS-2026-0209', disp:'one_touch', conf:0.83, mins:1440,
    reasoning:'Price increase 8% exceeds market benchmark 4-5%. Entitlement already 6 seats over quota — true-up exposure at renewal. Counter-offer built: 3% uplift + right-size to 79 seats = net saving vs trajectory.',
    rec:'Counter at 3% + reduce to 79 seats. Walk-away: no 8% on 85 seats. Proposed renewal: €168,876 vs trajectory €196,000+.',
    signals:[
      ['contract',    0.55, 0.20, false, 'Expiry 2026-06-29 — 31 days. 8% uplift proposed. Market benchmark: 4-5%.'],
      ['consumption', 0.70, 0.25, true,  'France SaaS Q2 at 102% committed. Restructure creates headroom.'],
      ['supplier',    0.85, 0.20, true,  'Salesforce health green. Renewal relationship established. Leverage: 6-seat overage.'],
      ['request',     0.88, 0.20, true,  'Renewal is expected. Marc Dupont authority covers this amount.'],
      ['policy',      0.82, 0.15, true,  'No compliance blocker. Standard renewal. Counter-offer within policy.'],
    ]},
  { ref:'TS-2026-0210', disp:'one_touch', conf:0.87, mins:360,
    reasoning:'Spend 3.4× above 7-day average. RI utilisation dropped from 89% to 61% — on-demand instances spinning up. Pattern: batch migration job not terminated. Cannot auto-remediate without human confirmation.',
    rec:'Review EC2 instances in us-east-1 and eu-west-1. Terminate batch job if confirmed complete. Saving: ~€34k/week at current rate.',
    signals:[
      ['contract',    0.90, 0.20, true,  'AWS EDP contract active. Spend within committed framework. No breach.'],
      ['consumption', 0.15, 0.25, false, '3.4× spike vs 7-day avg. RI util 61% vs normal 89%. On-demand surge.'],
      ['supplier',    0.95, 0.20, true,  'AWS health green. No service disruption. Normal API responses.'],
      ['request',     0.85, 0.20, true,  'Monitoring-triggered. Auto-analysis on threshold breach.'],
      ['policy',      0.80, 0.15, true,  'Anomaly detection policy triggered correctly. Cannot auto-terminate without confirmation.'],
    ]},
]

for (const d of decisionsData) {
  const tRes = await q(`SELECT id FROM tickets WHERE reference=$1`, [d.ref])
  if (!tRes.rows[0]) { console.log('  ⚠ ticket not found:', d.ref); continue }
  const tid = tRes.rows[0].id
  const dRes = await q(`INSERT INTO decisions (ticket_id,disposition,confidence,reasoning,recommendation,model_used,created_at)
    VALUES($1,$2::disposition,$3,$4,$5,'claude-sonnet-4-6',now()-($6||' minutes')::interval)
    RETURNING id`,
    [tid,d.disp,d.conf,d.reasoning,d.rec,d.mins])
  const did = dRes.rows[0].id
  for (const [sig,val,wt,green,notes] of d.signals) {
    await q(`INSERT INTO trace_log (decision_id,signal,value,weight,green,notes,created_at)
      VALUES($1,$2::signal_type,$3::text,$4,$5,$6,now()-($7||' minutes')::interval)`,
      [did,sig,String(val),wt,green,notes,d.mins])
  }
}
ok(`Decisions + trace signals: ${decisionsData.length} decisions, ${decisionsData.length*5} signals`)

// ── 10. Contract changes ───────────────────────────────────────
await q(`INSERT INTO contract_changes (contract_id,change_type,previous_value,proposed_value,delta_pct,delta_eur,market_rate_pct,agent_assessment,recommended_position,walk_away_value,accepted,detected_at)
  VALUES
  ('c1000000-0000-0000-0000-000000000007','price_increase','165.00','178.20',8.0,13464,4.5,
   'Salesforce proposing 8% uplift. Market benchmark Q2 2026: 4-5%. Entitlement over-committed by 6 seats.',
   'Counter at 3% + right-size to 79 seats. Net saving: €8,640/yr vs current.',
   '169.95',false,now()-interval'8 days'),
  ('c1000000-0000-0000-0000-000000000008','volume_change','1200','1350',12.5,87000,0,
   'SAP proposing +150 users in true-up. Access logs show 1,180 active users. Over-count by 170.',
   'Dispute true-up. Submit access log evidence. Negotiate to 1,200 + 50 buffer.',
   null,false,now()-interval'15 days'),
  ('c1000000-0000-0000-0000-000000000002','price_increase','36.00','36.00',0.0,0,0,
   'Microsoft EA renewal at same per-seat price. No escalation clause triggered. Volume unchanged.',
   'Auto-renew recommended. No negotiation needed.',
   null,true,now()-interval'30 days')
  ON CONFLICT DO NOTHING`)
ok('Contract changes: 3')

// ── 11. Workflow runs ──────────────────────────────────────────
const runs = [
  ['intake_receiver','success',300,298],['intake_receiver','success',180,178],['intake_receiver','success',120,118],
  ['intake_receiver','success',90,88],['intake_receiver','success',45,43],['intake_receiver','success',30,28],['intake_receiver','success',15,13],
  ['contract_watcher','success',1320,1318],['contract_watcher','success',2760,2758],
  ['hyperscaler_monitor','success',1080,1078],['hyperscaler_monitor','success',2520,2518],
  ['supplier_onboarding','success',4320,4316],
  ['invoice_processor','success',25920,25918],['invoice_processor','success',14400,14398],['invoice_processor','success',4320,4317],
  ['reorder_trigger','success',183,180],
  ['supplier_reply_handler','success',240,239],
]
for (const [name,status,startMins,endMins] of runs) {
  await q(`INSERT INTO workflow_runs (workflow_name,status,started_at,ended_at)
    VALUES($1,$2,now()-($3||' minutes')::interval,now()-($4||' minutes')::interval)`,
    [name,status,startMins,endMins])
}
ok(`Workflow runs: ${runs.length}`)

// ── Final summary ──────────────────────────────────────────────
console.log('\n── Verification ──────────────────────────────────────')
for (const t of ['tickets','decisions','trace_log','license_entitlements','license_assignments',
  'assets','invoices','payment_instructions','erp_sync_queue','contract_changes','workflow_runs']) {
  const r = await q(`SELECT count(*) FROM ${t}`)
  console.log(' ', t.padEnd(25), r.rows[0].count)
}
const bb = await q(`SELECT category, sum(allocated_eur) a, sum(spent_eur) s FROM budget_buckets WHERE quarter=2 GROUP BY category ORDER BY category`)
console.log('\nBudget Q2:')
bb.rows.forEach(r => console.log(' ', r.category.padEnd(15), 'alloc:', Number(r.a).toLocaleString(), '| spent:', Number(r.s).toLocaleString()))

await c.end()
console.log('\n✅ Executive demo seed complete')
