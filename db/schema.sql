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

alter table contracts enable row level security;
alter table tickets enable row level security;
alter table decisions enable row level security;
alter table suppliers enable row level security;
alter table budget_positions enable row level security;

-- Service role bypass (n8n uses service role key)
create policy "service_role_all" on contracts for all using (auth.role() = 'service_role');
create policy "service_role_all" on tickets for all using (auth.role() = 'service_role');
create policy "service_role_all" on decisions for all using (auth.role() = 'service_role');
create policy "service_role_all" on suppliers for all using (auth.role() = 'service_role');
create policy "service_role_all" on budget_positions for all using (auth.role() = 'service_role');
