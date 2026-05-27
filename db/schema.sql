-- TrueSpend — Supabase Schema
-- Built for: 10 branches, 5 procurement managers, 3 contract lanes
-- Last updated: 2026-05-27

-- ============================================================
-- EXTENSIONS
-- ============================================================
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ============================================================
-- ENUMS
-- ============================================================

create type branch_region as enum (
  'DACH', 'BENELUX', 'NORDICS', 'UK_IE', 'FRANCE',
  'IBERIA', 'ITALY', 'CEE', 'NORDICS_EAST', 'GLOBAL_HQ'
);

create type contract_category as enum (
  'hardware',        -- Dell, Lenovo, Apple
  'hyperscaler',     -- AWS, GCP, Azure
  'saas_license',    -- Microsoft, Salesforce, etc
  'services',        -- Consulting, maintenance
  'facilities',      -- Office, logistics
  'telecoms',        -- Connectivity, mobile
  'other'
);

create type renewal_state as enum (
  'clean',             -- Same terms, auto-renew eligible
  'price_increase',    -- Supplier proposed price increase
  'volume_change',     -- License/volume uplift requested
  'scope_change',      -- Terms or scope modified
  'manual_required'    -- Complex — human must review
);

create type disposition as enum (
  'auto_execute',    -- High confidence, all signals green
  'one_touch',       -- One signal uncertain, brief shown
  'escalate'         -- Novel, high-risk, or above threshold
);

create type ticket_source as enum (
  'automatic',       -- Agent-initiated, no human trigger
  'intake',          -- Stakeholder submitted via UI
  'renewal',         -- Contract renewal triggered
  'monitoring'       -- Detected by monitoring workflow
);

create type ticket_status as enum (
  'open',
  'reasoning',       -- Agent currently processing
  'pending_confirm', -- Waiting for one-touch confirm
  'approved',
  'rejected',
  'escalated',
  'closed'
);

create type supplier_health as enum (
  'green',   -- Performing, no flags
  'watch',   -- One concern, monitoring
  'red'      -- Active issue, escalation required
);

create type signal_type as enum (
  'contract',
  'consumption',
  'supplier',
  'request',
  'policy'
);

create type change_type as enum (
  'price_increase',
  'volume_change',
  'scope_change',
  'term_change',
  'currency_change'
);

-- ============================================================
-- CORE TABLES
-- ============================================================

-- Branches — the 10 business units
create table branches (
  id              uuid primary key default uuid_generate_v4(),
  name            text not null,
  region          branch_region not null,
  country         text not null,
  currency        text not null default 'EUR',
  annual_budget   numeric(15,2),
  budget_owner    text,
  created_at      timestamptz default now()
);

-- Procurement managers — the 5 people running everything
create table managers (
  id              uuid primary key default uuid_generate_v4(),
  name            text not null,
  email           text not null unique,
  role            text not null, -- 'head_of_procurement' | 'category_manager' | 'ops_manager'
  branches        uuid[] default '{}', -- which branches they cover
  spend_authority numeric(15,2) not null default 50000, -- auto-approve up to this amount
  created_at      timestamptz default now()
);

-- Suppliers — every vendor in the system
create table suppliers (
  id              uuid primary key default uuid_generate_v4(),
  name            text not null,
  legal_name      text,
  country         text,
  category        contract_category,
  health          supplier_health not null default 'green',
  sla_status      text, -- description of current SLA performance
  open_disputes   int default 0,
  last_contact    date,
  next_contact    date,
  notes           text,
  -- Contact
  contact_email     text,             -- primary contact for orders/replies
  account_team_email text,            -- hyperscaler account team (AWS TAM, GCP CE, etc)
  -- Due diligence
  opencorporates_id text,
  sanctions_clear   boolean default true,
  gdpr_dpa_signed   boolean default false,
  -- Metadata
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- Contracts — every agreement in the system
create table contracts (
  id              uuid primary key default uuid_generate_v4(),
  supplier_id     uuid references suppliers(id),
  branch_id       uuid references branches(id),
  owner_id        uuid references managers(id),
  -- Contract basics
  name            text not null,
  category        contract_category not null,
  value           numeric(15,2) not null,
  currency        text not null default 'EUR',
  -- Dates
  start_date      date not null,
  expiry_date     date not null,
  notice_days     int default 30,   -- days notice required to cancel
  -- Renewal state
  auto_renew      boolean default false,
  renewal_state   renewal_state default 'clean',
  renewal_reviewed_at timestamptz,
  -- Terms
  terms_summary   text,
  price_per_unit  numeric(15,4),
  unit_type       text,             -- 'seat' | 'device' | 'TB' | 'API_call'
  volume          numeric(15,2),    -- current contracted volume
  -- Alerts fired
  alert_90_sent   boolean default false,
  alert_60_sent   boolean default false,
  alert_30_sent   boolean default false,
  -- Metadata
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- Contract changes — what's different at renewal
create table contract_changes (
  id                  uuid primary key default uuid_generate_v4(),
  contract_id         uuid references contracts(id),
  change_type         change_type not null,
  -- The change itself
  previous_value      text not null,
  proposed_value      text not null,
  delta_pct           numeric(8,4),   -- percentage change
  delta_eur           numeric(15,2),  -- absolute EUR impact
  -- Agent analysis
  market_rate_pct     numeric(8,4),   -- what market is doing
  agent_assessment    text,           -- agent's reasoning on this change
  recommended_position text,          -- what the agent recommends
  walk_away_value     text,           -- agent's walk-away threshold
  -- Resolution
  accepted            boolean,
  counter_value       text,
  resolved_at         timestamptz,
  -- Metadata
  detected_at         timestamptz default now()
);

-- Tickets — every request in the system (from intake or automatic)
create table tickets (
  id              uuid primary key default uuid_generate_v4(),
  reference       text not null unique, -- TS-2026-XXXX
  source          ticket_source not null,
  status          ticket_status not null default 'open',
  -- What it's about
  title           text not null,
  description     text,
  branch_id       uuid references branches(id),
  supplier_id     uuid references suppliers(id),
  contract_id     uuid references contracts(id),
  requested_by    text,             -- name/email of submitter
  owner_id        uuid references managers(id), -- assigned manager
  -- Financials
  amount          numeric(15,2),
  currency        text default 'EUR',
  -- Jira sync
  jira_key        text,             -- PROC-1234
  jira_url        text,
  -- Timing
  created_at      timestamptz default now(),
  updated_at      timestamptz default now(),
  closed_at       timestamptz,
  -- SLA
  target_close    timestamptz       -- when agent should have this done
);

-- Decisions — every agent disposition
create table decisions (
  id              uuid primary key default uuid_generate_v4(),
  ticket_id       uuid references tickets(id),
  contract_id     uuid references contracts(id),
  -- The decision
  disposition     disposition not null,
  confidence      numeric(5,4) not null, -- 0.0000 to 1.0000
  reasoning       text not null,         -- full agent reasoning
  recommendation  text,                  -- what agent recommends
  brief           text,                  -- full brief for one-touch / escalate
  -- Outcome
  outcome         text,                  -- what actually happened
  actioned_by     text,                  -- 'agent' or manager name
  actioned_at     timestamptz,
  -- Metadata
  model_used      text default 'claude-sonnet-4-6',
  created_at      timestamptz default now()
);

-- Trace log — signal-level detail for every decision
create table trace_log (
  id              uuid primary key default uuid_generate_v4(),
  decision_id     uuid references decisions(id),
  signal          signal_type not null,
  -- What the agent found
  value           text not null,   -- what the signal showed
  weight          numeric(5,4),    -- how much this influenced the decision
  green           boolean,         -- did this signal pass?
  notes           text,            -- agent notes on this signal
  created_at      timestamptz default now()
);

-- Budget positions — per branch, per period
create table budget_positions (
  id              uuid primary key default uuid_generate_v4(),
  branch_id       uuid references branches(id),
  period          text not null,   -- '2026-Q2' | '2026-05'
  category        contract_category,
  budget          numeric(15,2) not null,
  committed       numeric(15,2) default 0,
  spent           numeric(15,2) default 0,
  available       numeric(15,2) generated always as (budget - committed - spent) stored,
  updated_at      timestamptz default now()
);

-- Supplier emails — threaded institutional memory
create table supplier_emails (
  id              uuid primary key default uuid_generate_v4(),
  supplier_id     uuid references suppliers(id),
  contract_id     uuid references contracts(id),
  direction       text not null,   -- 'inbound' | 'outbound'
  subject         text,
  body_summary    text,            -- agent summary, not full body
  commitments     text[],          -- informal commitments extracted by agent
  order_reference text,            -- PO reference when email is an auto-reorder
  flagged         boolean default false,
  flag_reason     text,
  received_at     timestamptz,
  created_at      timestamptz default now()
);

-- Hyperscaler positions — daily snapshot
create table hyperscaler_positions (
  id              uuid primary key default uuid_generate_v4(),
  branch_id       uuid references branches(id),
  provider        text not null,   -- 'AWS' | 'GCP' | 'Azure'
  period          text not null,   -- '2026-05'
  -- Link to contract (optional — hyperscaler EDP/CUD agreements)
  contract_id     uuid references contracts(id),
  -- Commitment
  committed_eur   numeric(15,2),
  commitment_type text,            -- 'EDP' | 'CUD' | 'Reservation'
  commitment_end  date,
  -- Consumption
  mtd_spend_eur   numeric(15,2),
  daily_burn_eur  numeric(15,2),
  projected_eur   numeric(15,2),   -- projected month-end
  -- Utilization
  reservation_util numeric(5,4),  -- 0.0 to 1.0
  idle_resources_eur numeric(15,2),
  -- Flags
  overshoot_risk  boolean default false,
  undershoot_risk boolean default false,
  snapshot_date   date not null default current_date,
  created_at      timestamptz default now()
);

-- ============================================================
-- VIEWS
-- ============================================================

-- Contracts expiring soon with renewal state
create view contracts_expiring as
select
  c.id,
  c.name,
  c.expiry_date,
  c.value,
  c.currency,
  c.renewal_state,
  c.auto_renew,
  (c.expiry_date - current_date) as days_remaining,
  s.name as supplier_name,
  s.health as supplier_health,
  b.name as branch_name,
  b.region as branch_region,
  m.name as owner_name,
  m.email as owner_email
from contracts c
join suppliers s on s.id = c.supplier_id
join branches b on b.id = c.branch_id
join managers m on m.id = c.owner_id
where c.expiry_date > current_date
  and (c.expiry_date - current_date) <= 90
order by c.expiry_date asc;

-- Weekly digest — what needs human attention
create view weekly_digest as
select
  t.reference,
  t.title,
  t.status,
  t.amount,
  t.currency,
  t.source,
  d.disposition,
  d.confidence,
  d.recommendation,
  m.name as owner_name,
  b.name as branch_name,
  t.created_at,
  t.target_close
from tickets t
left join decisions d on d.ticket_id = t.id
left join managers m on m.id = t.owner_id
left join branches b on b.id = t.branch_id
where t.status in ('pending_confirm', 'escalated')
order by t.created_at desc;

-- Agent performance — trust-building metrics
create view agent_performance as
select
  date_trunc('week', d.created_at) as week,
  count(*) as total_decisions,
  count(*) filter (where d.disposition = 'auto_execute') as auto_executed,
  count(*) filter (where d.disposition = 'one_touch') as one_touch,
  count(*) filter (where d.disposition = 'escalate') as escalated,
  round(
    count(*) filter (where d.disposition = 'auto_execute')::numeric
    / count(*)::numeric * 100, 1
  ) as auto_execute_pct,
  round(avg(d.confidence) * 100, 1) as avg_confidence_pct
from decisions d
group by date_trunc('week', d.created_at)
order by week desc;

-- ============================================================
-- INDEXES
-- ============================================================

create index idx_contracts_expiry on contracts(expiry_date);
create index idx_contracts_supplier on contracts(supplier_id);
create index idx_contracts_branch on contracts(branch_id);
create index idx_contracts_renewal_state on contracts(renewal_state);
create index idx_tickets_status on tickets(status);
create index idx_tickets_source on tickets(source);
create index idx_decisions_ticket on decisions(ticket_id);
create index idx_decisions_created on decisions(created_at);
create index idx_trace_log_decision on trace_log(decision_id);
create index idx_hyperscaler_branch_period on hyperscaler_positions(branch_id, period);
create index idx_budget_branch_period on budget_positions(branch_id, period);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
-- On Railway (plain Postgres): RLS is enabled but the truespend role
-- owns all tables and bypasses RLS automatically (owner bypass).
-- On Supabase: the auth.role() policies below apply for anon/service_role.
-- ============================================================

alter table contracts enable row level security;
alter table tickets enable row level security;
alter table decisions enable row level security;
alter table suppliers enable row level security;
alter table budget_positions enable row level security;

-- Allow the table owner (truespend role) full access — works on Railway
-- where there is no Supabase auth schema.
do $$
begin
  -- Only create Supabase-style policies if the auth schema exists
  if exists (select 1 from information_schema.schemata where schema_name = 'auth') then
    execute 'create policy "service_role_all" on contracts for all using (auth.role() = ''service_role'')';
    execute 'create policy "service_role_all" on tickets for all using (auth.role() = ''service_role'')';
    execute 'create policy "service_role_all" on decisions for all using (auth.role() = ''service_role'')';
    execute 'create policy "service_role_all" on suppliers for all using (auth.role() = ''service_role'')';
    execute 'create policy "service_role_all" on budget_positions for all using (auth.role() = ''service_role'')';
  else
    -- Railway: allow all for the application role
    execute 'create policy "app_role_all" on contracts for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on tickets for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on decisions for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on suppliers for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on budget_positions for all to truespend using (true) with check (true)';
  end if;
end $$;

-- ============================================================
-- COMPLIANCE & LEGAL EXTENSIONS
-- Added: supplier onboarding compliance agents
-- ============================================================

-- New enums
create type doc_type as enum (
  'nda',          -- Non-Disclosure Agreement
  'dpa',          -- Data Processing Agreement
  'tom',          -- Technical & Organisational Measures annex
  'scc',          -- Standard Contractual Clauses (non-EU suppliers)
  'coc',          -- Code of Conduct
  'lksg'          -- Supply Chain Act declaration
);

create type doc_status as enum (
  'not_required', -- this doc type not needed for this supplier
  'generating',   -- agent is generating the document
  'generated',    -- document generated, not yet sent
  'sent',         -- sent to supplier awaiting signature
  'signed',       -- supplier has signed
  'filed',        -- signed copy filed in system
  'rejected',     -- supplier refused to sign
  'expired'       -- signed but now expired
);

create type compliance_status as enum (
  'pending',      -- not yet assessed
  'running',      -- agent currently assessing
  'green',        -- fully compliant
  'amber',        -- minor gaps, remediation underway
  'red',          -- blocking issues, cannot proceed
  'waived'        -- risk accepted and documented
);

create type ticket_status_v2 as enum (
  'open',
  'reasoning',
  'pending_confirm',
  'pending_review',       -- needs human eyes (≥€100k or compliance flag)
  'signature_required',   -- contract PDF needs signing
  'approved',
  'rejected',
  'escalated',
  'closed'
);

-- Legal documents — NDA, DPA, TOM, SCC per supplier
create table legal_documents (
  id              uuid primary key default uuid_generate_v4(),
  supplier_id     uuid references suppliers(id) not null,
  doc_type        doc_type not null,
  status          doc_status not null default 'generating',
  -- Document content
  content         text,             -- full generated document text
  content_summary text,             -- agent summary of key terms
  -- Parties
  company_name    text default 'TrueSpend GmbH',
  supplier_name   text,
  governing_law   text default 'German law',
  -- Dates
  generated_at    timestamptz,
  sent_at         timestamptz,
  signed_at       timestamptz,
  expires_at      date,             -- when doc needs renewal
  -- Tracking
  sent_to_email   text,
  notes           text,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now(),
  unique(supplier_id, doc_type)     -- one active doc per type per supplier
);

-- Compliance checks — per supplier, per agent
create table compliance_checks (
  id              uuid primary key default uuid_generate_v4(),
  supplier_id     uuid references suppliers(id) not null,
  -- Which agent ran this check
  check_type      text not null,    -- 'lawyer' | 'gdpr' | 'infosec' | 'lksg' | 'ethics'
  status          compliance_status not null default 'pending',
  -- Results
  score           numeric(5,2),     -- 0-100
  passed          boolean,
  findings        text[],           -- list of findings
  blockers        text[],           -- must-fix before proceeding
  recommendations text[],           -- nice-to-have improvements
  full_report     text,             -- full agent reasoning
  -- Required documents flagged by this check
  docs_required   doc_type[],       -- which docs this check requires
  -- Metadata
  model_used      text default 'claude-sonnet-4-6',
  checked_at      timestamptz default now(),
  created_at      timestamptz default now()
);

-- Extend suppliers table with compliance fields
alter table suppliers
  add column if not exists nda_status       doc_status default 'not_required',
  add column if not exists dpa_status       doc_status default 'not_required',
  add column if not exists lksg_compliant   boolean,
  add column if not exists infosec_score    numeric(5,2),
  add column if not exists compliance_status compliance_status default 'pending',
  add column if not exists onboarding_complete boolean default false,
  add column if not exists processes_personal_data boolean default false,
  add column if not exists data_residency   text,       -- 'EU' | 'non-EU' | 'mixed'
  add column if not exists iso27001         boolean default false,
  add column if not exists soc2             boolean default false;

-- Extend tickets table with new statuses and review fields
alter table tickets
  add column if not exists review_type      text,       -- 'major_contract' | 'compliance_flag' | 'signature'
  add column if not exists review_notes     text,       -- agent summary for reviewer
  add column if not exists pdf_url          text,       -- link to contract PDF
  add column if not exists value_eur        numeric(15,2), -- normalised EUR value for threshold check
  add column if not exists compliance_check_id uuid references compliance_checks(id),
  add column if not exists legal_doc_id     uuid references legal_documents(id);

-- Indexes
create index if not exists idx_legal_docs_supplier on legal_documents(supplier_id);
create index if not exists idx_legal_docs_status on legal_documents(status);
create index if not exists idx_compliance_supplier on compliance_checks(supplier_id);
create index if not exists idx_compliance_type on compliance_checks(check_type);
create index if not exists idx_tickets_review on tickets(review_type) where review_type is not null;

-- View: open tickets needing human action (the Operations Board feed)
create or replace view open_tickets_board as
select
  t.id,
  t.reference,
  t.title,
  t.status,
  t.source,
  t.review_type,
  t.review_notes,
  t.amount,
  t.value_eur,
  t.currency,
  t.pdf_url,
  t.created_at,
  t.target_close,
  s.name  as supplier_name,
  s.health as supplier_health,
  s.compliance_status as supplier_compliance,
  b.name  as branch_name,
  m.name  as owner_name,
  m.email as owner_email,
  d.disposition,
  d.confidence,
  d.recommendation,
  d.brief
from tickets t
left join suppliers  s on s.id = t.supplier_id
left join branches   b on b.id = t.branch_id
left join managers   m on m.id = t.owner_id
left join decisions  d on d.ticket_id = t.id
where t.status in ('pending_review', 'signature_required', 'pending_confirm', 'escalated')
order by
  case t.status
    when 'signature_required' then 1
    when 'pending_review'     then 2
    when 'escalated'          then 3
    when 'pending_confirm'    then 4
  end,
  t.created_at asc;

-- View: supplier compliance summary
create or replace view supplier_compliance_summary as
select
  s.id,
  s.name,
  s.country,
  s.compliance_status,
  s.nda_status,
  s.dpa_status,
  s.lksg_compliant,
  s.infosec_score,
  s.onboarding_complete,
  s.processes_personal_data,
  count(cc.id) as total_checks,
  count(cc.id) filter (where cc.passed = true)  as checks_passed,
  count(cc.id) filter (where cc.passed = false) as checks_failed,
  count(ld.id) filter (where ld.status = 'signed') as docs_signed,
  count(ld.id) filter (where ld.status in ('sent','generated')) as docs_pending
from suppliers s
left join compliance_checks cc on cc.supplier_id = s.id
left join legal_documents   ld on ld.supplier_id = s.id
group by s.id, s.name, s.country, s.compliance_status,
         s.nda_status, s.dpa_status, s.lksg_compliant,
         s.infosec_score, s.onboarding_complete, s.processes_personal_data
order by s.name;
