require('dotenv').config()
const { Client } = require('pg')
const client = new Client({ connectionString: process.env.DATABASE_URL })

const migration = `
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS submitted_by       text;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS submitted_by_email text;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS supplier_name      text;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS value_eur          numeric(15,2);
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS category           text;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS recommendation     text;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS brief              text;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS confidence         numeric(4,3);
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS review_notes       text;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS po_id              uuid;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS po_number          text;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS pdf_url            text;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS supplier_compliance text;

CREATE TABLE IF NOT EXISTS users (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  email           text unique,
  role            text not null default 'requester',
  branch_id       uuid references branches(id),
  spend_authority numeric(15,2) default 0,
  created_at      timestamptz default now()
);

CREATE TABLE IF NOT EXISTS cost_centers (
  id              uuid primary key default gen_random_uuid(),
  code            text not null unique,
  name            text not null,
  branch_id       uuid references branches(id),
  gl_account      text,
  created_at      timestamptz default now()
);

CREATE TABLE IF NOT EXISTS purchase_orders (
  id              uuid primary key default gen_random_uuid(),
  po_number       text unique not null,
  ticket_id       uuid references tickets(id),
  supplier_id     uuid references suppliers(id),
  branch_id       uuid references branches(id),
  status          text not null default 'sent',
  total_eur       numeric(15,2),
  currency        text default 'EUR',
  issued_at       timestamptz default now(),
  delivered_at    timestamptz,
  created_at      timestamptz default now()
);

CREATE TABLE IF NOT EXISTS invoices (
  id              uuid primary key default gen_random_uuid(),
  po_id           uuid references purchase_orders(id),
  invoice_number  text,
  supplier_id     uuid references suppliers(id),
  amount_eur      numeric(15,2),
  status          text default 'pending',
  received_at     timestamptz default now(),
  matched_at      timestamptz,
  created_at      timestamptz default now()
);

CREATE TABLE IF NOT EXISTS payment_instructions (
  id              uuid primary key default gen_random_uuid(),
  invoice_id      uuid references invoices(id),
  amount_eur      numeric(15,2),
  due_date        date,
  status          text default 'pending',
  created_at      timestamptz default now()
);

CREATE TABLE IF NOT EXISTS erp_sync_queue (
  id              uuid primary key default gen_random_uuid(),
  entity_type     text not null,
  entity_id       uuid not null,
  payload         jsonb,
  status          text default 'pending',
  created_at      timestamptz default now()
);

CREATE TABLE IF NOT EXISTS budget_buckets (
  id              uuid primary key default gen_random_uuid(),
  branch_id       uuid references branches(id) not null,
  cost_center_id  uuid references cost_centers(id),
  category        text not null,
  fiscal_year     int not null,
  quarter         int,
  allocated_eur   numeric(15,2) default 0,
  committed_eur   numeric(15,2) default 0,
  spent_eur       numeric(15,2) default 0,
  created_at      timestamptz default now(),
  unique(branch_id, cost_center_id, category, fiscal_year, quarter)
);

CREATE TABLE IF NOT EXISTS budget_pools (
  id              uuid primary key default gen_random_uuid(),
  branch_id       uuid references branches(id) not null,
  reserve_eur     numeric(15,2) default 0,
  fiscal_year     int not null,
  created_at      timestamptz default now()
);

CREATE TABLE IF NOT EXISTS budget_reallocations (
  id              uuid primary key default gen_random_uuid(),
  from_bucket_id  uuid,
  to_bucket_id    uuid,
  amount_eur      numeric(15,2),
  reason          text,
  approved_by     text,
  created_at      timestamptz default now()
);

CREATE TABLE IF NOT EXISTS po_sequences (
  branch_id       uuid references branches(id) not null,
  fiscal_year     int not null,
  last_seq        int default 0,
  primary key (branch_id, fiscal_year)
);

CREATE TABLE IF NOT EXISTS legal_documents (
  id              uuid primary key default gen_random_uuid(),
  supplier_id     uuid references suppliers(id),
  doc_type        text,
  content         text,
  status          text default 'draft',
  created_at      timestamptz default now()
);

CREATE TABLE IF NOT EXISTS compliance_checks (
  id              uuid primary key default gen_random_uuid(),
  supplier_id     uuid references suppliers(id),
  check_type      text,
  status          text default 'pending',
  score           int,
  notes           text,
  created_at      timestamptz default now()
);

CREATE TABLE IF NOT EXISTS contract_clauses (
  id              uuid primary key default gen_random_uuid(),
  contract_id     uuid references contracts(id),
  clause_type     text,
  content         text,
  created_at      timestamptz default now()
);

CREATE TABLE IF NOT EXISTS assets (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  branch_id       uuid references branches(id),
  po_id           uuid references purchase_orders(id),
  purchase_value  numeric(15,2),
  book_value      numeric(15,2),
  warranty_expiry date,
  status          text default 'active',
  created_at      timestamptz default now()
);

CREATE TABLE IF NOT EXISTS asset_depreciation_log (
  id              uuid primary key default gen_random_uuid(),
  asset_id        uuid references assets(id),
  period          text,
  depreciation    numeric(15,2),
  book_value_after numeric(15,2),
  created_at      timestamptz default now()
);

CREATE TABLE IF NOT EXISTS license_entitlements (
  id              uuid primary key default gen_random_uuid(),
  product_name    text not null,
  supplier_id     uuid references suppliers(id),
  total_seats     int default 0,
  used_seats      int default 0,
  branch_id       uuid references branches(id),
  created_at      timestamptz default now()
);

CREATE TABLE IF NOT EXISTS license_assignments (
  id              uuid primary key default gen_random_uuid(),
  entitlement_id  uuid references license_entitlements(id),
  user_id         uuid references users(id),
  assigned_at     timestamptz default now()
);

CREATE TABLE IF NOT EXISTS llm_api_keys (
  id              uuid primary key default gen_random_uuid(),
  provider        text not null,
  key_ref         text,
  branch_id       uuid references branches(id),
  created_at      timestamptz default now()
);

CREATE TABLE IF NOT EXISTS llm_consumption (
  id              uuid primary key default gen_random_uuid(),
  api_key_id      uuid references llm_api_keys(id),
  period_date     date,
  tokens_used     bigint default 0,
  cost_eur        numeric(10,4),
  branch_id       uuid references branches(id),
  created_at      timestamptz default now()
);

CREATE TABLE IF NOT EXISTS vendor_pricing_benchmarks (
  id              uuid primary key default gen_random_uuid(),
  supplier_id     uuid references suppliers(id),
  product         text,
  benchmark_price numeric(15,2),
  currency        text default 'EUR',
  source          text,
  created_at      timestamptz default now()
);

CREATE TABLE IF NOT EXISTS trust_settings (
  id              uuid primary key default gen_random_uuid(),
  branch_id       uuid references branches(id),
  auto_execute_threshold numeric(4,3) default 0.85,
  max_auto_amount numeric(15,2) default 10000,
  created_at      timestamptz default now()
);

CREATE TABLE IF NOT EXISTS workflow_runs (
  id              uuid primary key default gen_random_uuid(),
  workflow_name   text not null,
  status          text,
  started_at      timestamptz default now(),
  ended_at        timestamptz,
  error_message   text
);

DROP VIEW IF EXISTS open_tickets_board;
CREATE VIEW open_tickets_board AS
SELECT
  t.id,
  t.reference,
  t.status,
  t.title,
  t.description,
  t.category,
  t.value_eur,
  t.supplier_name,
  t.submitted_by,
  t.submitted_by_email,
  t.recommendation,
  t.brief,
  t.confidence,
  t.review_notes,
  t.po_id,
  t.po_number,
  t.pdf_url,
  t.supplier_compliance,
  t.created_at,
  b.name AS branch_name,
  s.name AS supplier_name_from_db,
  s.health AS supplier_compliance_from_db
FROM tickets t
LEFT JOIN branches b  ON b.id = t.branch_id
LEFT JOIN suppliers s ON s.id = t.supplier_id
WHERE t.status IN (
  'pending_review','pending_confirm','signature_required',
  'escalated','approved','auto_executed'
)
ORDER BY
  CASE t.status
    WHEN 'signature_required' THEN 1
    WHEN 'pending_review'     THEN 2
    WHEN 'escalated'          THEN 3
    WHEN 'pending_confirm'    THEN 4
    WHEN 'approved'           THEN 5
    WHEN 'auto_executed'      THEN 6
    ELSE 7
  END,
  t.created_at DESC;
`

const grants = [
  'GRANT SELECT ON open_tickets_board TO truespend',
  'GRANT SELECT, INSERT, UPDATE ON tickets TO truespend',
  'GRANT SELECT ON branches TO truespend',
  'GRANT SELECT ON suppliers TO truespend',
  'GRANT SELECT, INSERT, UPDATE ON purchase_orders TO truespend',
  'GRANT SELECT, INSERT, UPDATE ON invoices TO truespend',
  'GRANT SELECT, INSERT ON payment_instructions TO truespend',
  'GRANT SELECT, INSERT ON erp_sync_queue TO truespend',
  'GRANT SELECT, INSERT, UPDATE ON budget_buckets TO truespend',
  'GRANT SELECT, INSERT, UPDATE ON budget_positions TO truespend',
  'GRANT SELECT ON budget_pools TO truespend',
  'GRANT SELECT, INSERT ON budget_reallocations TO truespend',
  'GRANT SELECT, INSERT, UPDATE ON po_sequences TO truespend',
  'GRANT SELECT, INSERT, UPDATE ON users TO truespend',
  'GRANT SELECT, INSERT ON compliance_checks TO truespend',
  'GRANT SELECT, INSERT ON legal_documents TO truespend',
  'GRANT SELECT, INSERT ON trace_log TO truespend',
  'GRANT SELECT, INSERT ON decisions TO truespend',
  'GRANT SELECT, INSERT, UPDATE ON supplier_emails TO truespend',
  'GRANT SELECT, INSERT ON workflow_runs TO truespend',
]

async function run() {
  await client.connect()
  console.log('Connected — applying v2 migration...')
  await client.query(migration)
  console.log('Tables + view created.')

  for (const g of grants) {
    try { await client.query(g) } catch (e) { console.log('Grant skip:', e.message) }
  }
  console.log('Grants applied.')

  const tables = await client.query(`SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename`)
  console.log('Tables:', tables.rows.map(r => r.tablename).join(', '))
  const views = await client.query(`SELECT viewname FROM pg_views WHERE schemaname='public'`)
  console.log('Views:', views.rows.map(r => r.viewname).join(', '))
  await client.end()
}

run().catch(e => { console.error('FAILED:', e.message); process.exit(1) })
