-- =============================================================================
-- TrueSpend — Master Schema
-- Version: 2.0
-- Last updated: 2026-05-27
--
-- This is the single source of truth for the entire database.
-- Apply to Railway PostgreSQL with:
--   psql $DATABASE_URL -f db/schema.sql
--
-- Covers:
--   Core: branches, cost_centers, users, suppliers, contracts
--   Finance: budget_pools, budget_buckets, budget_positions, budget_reallocations
--   P2I: purchase_orders, invoices, payment_instructions, erp_sync_queue
--   Assets: assets, asset_depreciation_log
--   Licenses: license_entitlements, license_assignments
--   Intelligence: contract_clauses, vendor_pricing_benchmarks
--   Consumption: hyperscaler_positions, llm_api_keys, llm_consumption
--   Operations: tickets, decisions, trace_log, supplier_emails
--   Compliance: legal_documents, compliance_checks
--   Trust: trust_settings
-- =============================================================================

-- =============================================================================
-- EXTENSIONS
-- =============================================================================

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- =============================================================================
-- ENUMS
-- =============================================================================

-- Geography
create type branch_region as enum (
  'DACH', 'BENELUX', 'NORDICS', 'UK_IE', 'FRANCE',
  'IBERIA', 'ITALY', 'CEE', 'NORDICS_EAST', 'GLOBAL_HQ'
);

-- Spend categories — used across contracts, budget buckets, and entitlements
create type spend_category as enum (
  'hardware',        -- Dell, Lenovo, Apple devices and infrastructure
  'hyperscaler',     -- AWS, GCP, Azure committed spend
  'saas_license',    -- Microsoft 365, Salesforce, Workday, etc.
  'ai_consumption',  -- LLM API spend, AI SaaS tools, GPU compute
  'services',        -- Consulting, professional services, maintenance
  'facilities',      -- Office, security, logistics
  'telecoms',        -- Connectivity, mobile fleet
  'other'
);

-- Contract renewal state
create type renewal_state as enum (
  'clean',           -- Same terms, auto-renew eligible
  'price_increase',  -- Supplier proposed price increase
  'volume_change',   -- License or volume uplift requested
  'scope_change',    -- Terms or scope modified
  'manual_required'  -- Complex — human must review
);

-- Agent disposition — the three outcomes of every reasoning cycle
create type disposition as enum (
  'auto_execute',    -- High confidence, all signals green → agent acts
  'one_touch',       -- One signal uncertain → ticket on Operations Board
  'escalate'         -- Novel, high-risk, or above €100k threshold → Jira
);

-- How a ticket entered the system
create type ticket_source as enum (
  'automatic',       -- Agent-initiated
  'intake',          -- Stakeholder via UI form
  'jira',            -- Inbound from Jira (license request, general request)
  'renewal',         -- Contract renewal workflow
  'monitoring',      -- Detected by a monitoring workflow
  'compliance'       -- Supplier onboarding compliance workflow
);

-- Ticket lifecycle — unified, no v2
create type ticket_status as enum (
  'open',
  'reasoning',         -- Agent is processing
  'pending_confirm',   -- One-touch: waiting for manager on Operations Board
  'pending_review',    -- Needs human eyes (≥€100k, compliance flag)
  'signature_required',-- Contract or legal doc needs signing
  'approved',
  'rejected',
  'escalated',         -- Jira ticket created
  'closed'
);

-- Supplier health — three signals only
create type supplier_health as enum (
  'green',  -- Performing, no flags
  'watch',  -- One concern, monitoring
  'red'     -- Active issue, escalation required
);

-- Trace log signal types
create type signal_type as enum (
  'contract',
  'consumption',
  'supplier',
  'request',
  'policy',
  'budget',
  'compliance',
  'asset',
  'license',
  'intake',
  'reorder',
  'contract_renewal'
);

-- What changed in a contract
create type change_type as enum (
  'price_increase',
  'volume_change',
  'scope_change',
  'term_change',
  'currency_change',
  'clause_addition'
);

-- Legal document types
create type doc_type as enum (
  'nda',    -- Non-Disclosure Agreement
  'dpa',    -- Data Processing Agreement (Art. 28 GDPR)
  'tom',    -- Technical & Organisational Measures annex
  'scc',    -- Standard Contractual Clauses (non-EU suppliers)
  'coc',    -- Code of Conduct
  'lksg'    -- Supply Chain Act declaration
);

-- Legal document lifecycle
create type doc_status as enum (
  'not_required',  -- Not needed for this supplier
  'generating',    -- Agent is generating
  'generated',     -- Generated, not yet sent
  'sent',          -- Sent to supplier, awaiting signature
  'signed',        -- Supplier has signed
  'filed',         -- Signed copy filed
  'rejected',      -- Supplier refused to sign
  'expired'        -- Signed but expired
);

-- Compliance check outcomes
create type compliance_status as enum (
  'pending',   -- Not yet assessed
  'running',   -- Agent currently assessing
  'green',     -- Fully compliant
  'amber',     -- Minor gaps, remediation underway
  'red',       -- Blocking issues, cannot proceed
  'waived'     -- Risk accepted and documented
);

-- Hardware asset lifecycle
create type asset_status as enum (
  'ordered',        -- PO raised, not yet received
  'active',         -- In use
  'in_repair',      -- With service provider
  'decommissioning',-- Being wound down
  'disposed'        -- Removed from register
);

-- Depreciation methods
create type depreciation_method as enum (
  'straight_line',       -- (cost - residual) / useful_life_months
  'declining_balance',   -- book_value × rate per period
  'sum_of_years_digits'  -- accelerated, front-loads depreciation
);

-- Purchase order lifecycle
create type po_status as enum (
  'draft',         -- Generated, not yet sent
  'sent',          -- Sent to supplier
  'acknowledged',  -- Supplier confirmed receipt
  'delivered',     -- Goods/services confirmed received
  'invoiced',      -- Invoice received and matched
  'closed',        -- PO fully settled
  'cancelled'      -- PO cancelled
);

-- Invoice lifecycle
create type invoice_status as enum (
  'received',    -- Invoice arrived, not yet processed
  'parsing',     -- Agent is extracting data
  'matched',     -- 3-way match passed
  'disputed',    -- Match failed, under review
  'approved',    -- Ready for payment
  'paid',        -- Payment instruction sent to ERP
  'rejected'     -- Invoice rejected
);

-- ERP sync queue status
create type erp_sync_status as enum (
  'pending',   -- Queued, not yet attempted
  'syncing',   -- In flight
  'synced',    -- Success
  'failed',    -- Failed — needs manual intervention
  'skipped'    -- No ERP connector configured — manual posting required
);

-- License types
create type license_type as enum (
  'named_user',    -- Tied to a specific person
  'concurrent',    -- N users max simultaneously active
  'device',        -- Tied to a specific asset
  'capacity',      -- CPU, storage, API calls
  'site',          -- Covers all users at a site
  'enterprise'     -- Unlimited users, org-wide
);

-- Contract clause types — for intelligent extraction
create type clause_type as enum (
  'auto_renew',
  'price_escalation',    -- CPI, annual increase
  'true_up',             -- License true-up mechanism
  'audit_rights',        -- Vendor can audit your usage
  'exit_penalty',        -- Costs to terminate early
  'most_favoured_nation',-- You get best pricing offered to anyone
  'bench_review',        -- Right to benchmark pricing
  'data_processing',     -- GDPR / data handling obligations
  'liability_cap',       -- Maximum liability exposure
  'force_majeure',
  'governing_law'
);


-- =============================================================================
-- CORE ORGANIZATIONAL STRUCTURE
-- =============================================================================

-- Branches — the business units
create table branches (
  id              uuid primary key default uuid_generate_v4(),
  name            text not null,
  region          branch_region not null,
  country         text not null,
  currency        text not null default 'EUR',
  -- Budget — top-level annual allocation (set by CFO)
  annual_budget   numeric(15,2),
  pool_reserve    numeric(15,2) default 0, -- CFO-held unallocated reserve
  -- ERP mapping
  erp_company_code text,          -- SAP company code or equivalent
  cost_center_codes jsonb,        -- [{code: "CC-4210", name: "DACH Sales", gl_account: "6100"}]
  -- Ownership
  budget_owner    text,
  created_at      timestamptz default now()
);

-- Cost centers — first-class entities for budget allocation and ERP posting
create table cost_centers (
  id              uuid primary key default uuid_generate_v4(),
  code            text not null unique,   -- CC-4210 — must match ERP
  name            text not null,          -- "DACH Sales"
  branch_id       uuid references branches(id) not null,
  -- ERP
  gl_account      text,                   -- GL account for postings
  erp_reference   text,                   -- SAP/Oracle/Coupa CC code
  -- Ownership
  budget_owner_id uuid,                   -- references users(id) — set after users created
  -- Budget (annual, set by Controlling)
  annual_budget   numeric(15,2),
  active          boolean default true,
  created_at      timestamptz default now()
);

-- Users — unified model for procurement managers, approvers, and requesters
-- Replaces the old managers table. Everyone who touches TrueSpend is a user.
create table users (
  id                  uuid primary key default uuid_generate_v4(),
  email               text not null unique,
  name                text not null,
  -- Role determines what they can do
  role                text not null,
  -- 'cfo'               → full budget visibility, pool draw approval
  -- 'head_of_procurement' → full procurement authority
  -- 'category_manager'  → category-scoped authority
  -- 'ops_manager'       → routine approvals, ops tickets
  -- 'it_manager'        → license requests, asset management
  -- 'budget_owner'      → cost center budget approval
  -- 'requester'         → submits requests only
  -- Scope
  branch_ids          uuid[] default '{}',
  cost_center_ids     uuid[] default '{}',  -- which CCs they own or can approve against
  -- Spend authority — the delegation control tier
  spend_authority     numeric(15,2) not null default 0,
  spend_authority_by_category jsonb,
  -- e.g. {"saas_license": 50000, "hardware": 200000, "ai_consumption": 25000}
  -- If set, overrides spend_authority for specific categories
  -- Integration
  jira_account_id     text,               -- Jira user ID for bidirectional sync
  -- Status
  active              boolean default true,
  created_at          timestamptz default now(),
  updated_at          timestamptz default now()
);

-- Add FK after users created
alter table cost_centers
  add constraint fk_cc_budget_owner foreign key (budget_owner_id) references users(id);


-- =============================================================================
-- SUPPLIERS
-- =============================================================================

create table suppliers (
  id                    uuid primary key default uuid_generate_v4(),
  name                  text not null,
  legal_name            text,
  country               text,
  category              spend_category,
  health                supplier_health not null default 'green',
  sla_status            text,
  open_disputes         int default 0,
  last_contact          date,
  next_contact          date,
  notes                 text,
  -- Contact
  contact_email         text,
  account_team_email    text,           -- Hyperscaler TAM / account team
  -- Due diligence
  opencorporates_id     text,
  sanctions_clear       boolean default true,
  gdpr_dpa_signed       boolean default false,
  -- Compliance fields
  nda_status            doc_status default 'not_required',
  dpa_status            doc_status default 'not_required',
  lksg_compliant        boolean,
  infosec_score         numeric(5,2),   -- 0-100 from InfoSec agent
  compliance_status     compliance_status default 'pending',
  onboarding_complete   boolean default false,
  -- Data processing (for GDPR assessment)
  processes_personal_data boolean default false,
  data_residency        text,           -- 'EU' | 'non-EU' | 'mixed'
  iso27001              boolean default false,
  soc2                  boolean default false,
  -- Vendor pricing intelligence
  strategic_tier        text default 'standard',
  -- 'strategic' (top 10, full attention)
  -- 'preferred'  (approved vendor, managed)
  -- 'standard'   (tactical, transactional)
  -- 'tail'       (one-off, not preferred)
  lock_in_score         numeric(3,1),   -- 0-10: how hard to exit this vendor
  -- Metadata
  created_at            timestamptz default now(),
  updated_at            timestamptz default now()
);


-- =============================================================================
-- CONTRACTS
-- =============================================================================

create table contracts (
  id              uuid primary key default uuid_generate_v4(),
  supplier_id     uuid references suppliers(id),
  branch_id       uuid references branches(id),
  owner_id        uuid references users(id),
  -- Basics
  name            text not null,
  category        spend_category not null,
  value           numeric(15,2) not null,
  value_eur       numeric(15,2),        -- normalised EUR (agent converts at ingestion)
  currency        text not null default 'EUR',
  -- Dates
  start_date      date not null,
  expiry_date     date not null,
  notice_days     int default 30,
  -- Renewal
  auto_renew      boolean default false,
  renewal_state   renewal_state default 'clean',
  renewal_reviewed_at timestamptz,
  -- Terms
  terms_summary   text,
  price_per_unit  numeric(15,4),
  unit_type       text,                 -- 'seat' | 'device' | 'TB' | 'API_call'
  volume          numeric(15,2),
  -- Intelligence fields (populated by contract_intelligence workflow)
  tco_eur         numeric(15,2),        -- total cost of ownership over full term
  tco_calculated_at timestamptz,
  escalation_clause boolean default false,
  escalation_rate  numeric(5,4),        -- e.g. 0.025 = CPI + 2.5%
  lock_in_score   numeric(3,1),         -- 0-10
  audit_rights    boolean default false,
  exit_penalty_eur numeric(15,2),       -- cost to terminate early
  -- Alerts
  alert_90_sent   boolean default false,
  alert_60_sent   boolean default false,
  alert_30_sent   boolean default false,
  -- Metadata
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- Contract changes — what's different at renewal
create table contract_changes (
  id                    uuid primary key default uuid_generate_v4(),
  contract_id           uuid references contracts(id),
  change_type           change_type not null,
  previous_value        text not null,
  proposed_value        text not null,
  delta_pct             numeric(8,4),
  delta_eur             numeric(15,2),
  -- Agent analysis
  market_rate_pct       numeric(8,4),   -- what the market is doing
  agent_assessment      text,
  recommended_position  text,
  walk_away_value       text,
  -- Resolution
  accepted              boolean,
  counter_value         text,
  resolved_at           timestamptz,
  detected_at           timestamptz default now()
);

-- Contract clauses — extracted by contract_intelligence workflow
-- This is what kills vendor lock-in and overpriced packages
create table contract_clauses (
  id              uuid primary key default uuid_generate_v4(),
  contract_id     uuid references contracts(id) not null,
  clause_type     clause_type not null,
  clause_text     text,                 -- verbatim extracted text
  extracted_value text,                 -- structured: "CPI + 2.5% annually"
  financial_impact_eur numeric(15,2),   -- agent-calculated EUR impact over term
  flagged         boolean default false,
  flag_reason     text,                 -- "Annual escalation adds €340k over 3yr term"
  extracted_at    timestamptz default now(),
  extraction_model text default 'claude-sonnet-4-6'
);


-- =============================================================================
-- BUDGET — CENTRALIZED, POOL-BASED
-- =============================================================================

-- Budget buckets — the annual plan, set once by Controlling/CFO
-- This is the source of authority. NOT the running ledger.
-- One row per: branch × cost_center × category × fiscal_year
create table budget_buckets (
  id              uuid primary key default uuid_generate_v4(),
  -- Dimensions
  branch_id       uuid references branches(id) not null,
  cost_center_id  uuid references cost_centers(id),  -- null = branch-level bucket
  category        spend_category not null,
  fiscal_year     int not null,                       -- 2026
  quarter         int,                                -- 1-4, null = annual bucket
  -- The plan
  planned_amount  numeric(15,2) not null,
  currency        text not null default 'EUR',
  -- Ownership
  set_by_user_id  uuid references users(id),
  set_at          timestamptz default now(),
  approved_by     uuid references users(id),
  approved_at     timestamptz,
  -- Notes
  notes           text,
  unique(branch_id, cost_center_id, category, fiscal_year, quarter)
);

-- Budget positions — the running ledger, updated by every approval and invoice
-- Committed = approved but not yet invoiced (encumbrance)
-- Spent = invoiced and approved for payment
create table budget_positions (
  id              uuid primary key default uuid_generate_v4(),
  branch_id       uuid references branches(id) not null,
  cost_center_id  uuid references cost_centers(id),
  category        spend_category not null,
  period          text not null,        -- '2026-Q2' | '2026-05'
  -- Amounts
  budget          numeric(15,2) not null,   -- drawn from budget_bucket
  committed       numeric(15,2) default 0, -- approved POs, not yet invoiced
  spent           numeric(15,2) default 0, -- invoiced + approved for payment
  available       numeric(15,2) generated always as (budget - committed - spent) stored,
  updated_at      timestamptz default now(),
  unique(branch_id, cost_center_id, category, period)
);

-- Branch-level reserve pools — the CFO's lever against budget flush and politics
create table budget_pools (
  id              uuid primary key default uuid_generate_v4(),
  name            text not null,
  branch_id       uuid references branches(id) not null,
  fiscal_year     int not null,
  total_amount    numeric(15,2) not null,
  committed       numeric(15,2) default 0,
  available       numeric(15,2) generated always as (total_amount - committed) stored,
  -- Governance
  draw_authority  text not null default 'head_of_procurement',
  -- 'cfo' | 'head_of_procurement' | 'branch_director'
  notes           text,
  created_at      timestamptz default now()
);

-- Budget reallocations — full audit trail of every budget move
-- When budget moves between cost centers, pools, or branches, it lands here.
-- No budget should ever move without a row in this table.
create table budget_reallocations (
  id              uuid primary key default uuid_generate_v4(),
  -- Source
  from_type       text not null,  -- 'cost_center' | 'pool' | 'branch'
  from_id         uuid not null,
  -- Destination
  to_type         text not null,
  to_id           uuid not null,
  -- The move
  amount          numeric(15,2) not null,
  currency        text default 'EUR',
  reason          text not null,
  -- Who did this
  requested_by    uuid references users(id),
  approved_by     uuid references users(id),
  approved_at     timestamptz,
  ticket_id       uuid,           -- FK added after tickets table
  notes           text,
  created_at      timestamptz default now()
);


-- =============================================================================
-- PURCHASE TO INVOICE (P2I)
-- =============================================================================

-- Purchase orders — the connective tissue between approval and invoice
create table purchase_orders (
  id              uuid primary key default uuid_generate_v4(),
  -- Reference format: PO-{YEAR}-{BRANCH_CODE}-{SEQ}  e.g. PO-2026-DACH-0042
  po_number       text not null unique,
  -- Links
  ticket_id       uuid,                 -- FK added after tickets
  contract_id     uuid references contracts(id),
  supplier_id     uuid references suppliers(id) not null,
  branch_id       uuid references branches(id),
  cost_center_id  uuid references cost_centers(id),
  raised_by       uuid references users(id),
  -- What we're buying
  description     text not null,
  category        spend_category,
  line_items      jsonb,
  -- e.g. [{"description": "MacBook Pro 14", "qty": 10, "unit_price": 2499.00, "total": 24990.00}]
  -- Amounts
  amount          numeric(15,2) not null,
  vat_amount      numeric(15,2) default 0,
  total_amount    numeric(15,2) generated always as (amount + vat_amount) stored,
  currency        text not null default 'EUR',
  amount_eur      numeric(15,2),        -- normalised EUR
  -- Dates
  po_date         date not null default current_date,
  expected_delivery date,
  delivered_at    timestamptz,
  -- State
  status          po_status not null default 'draft',
  -- SLA tracking
  delivery_sla_days int,
  delivery_overdue  boolean generated always as (
    status = 'sent' and expected_delivery < current_date
  ) stored,
  -- Notes
  notes           text,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- PO sequences — per branch, per year
-- Ensures PO numbers are unique within branch and readable
create table po_sequences (
  branch_id       uuid references branches(id) not null,
  fiscal_year     int not null,
  last_seq        int not null default 0,
  primary key (branch_id, fiscal_year)
);

-- Invoices — the supplier's claim for payment
create table invoices (
  id              uuid primary key default uuid_generate_v4(),
  -- Links
  po_id           uuid references purchase_orders(id),
  supplier_id     uuid references suppliers(id) not null,
  -- Invoice data (extracted by Claude from PDF)
  invoice_number  text,
  invoice_date    date,
  -- Amounts
  amount          numeric(15,2) not null,
  vat_amount      numeric(15,2) default 0,
  total_amount    numeric(15,2) generated always as (amount + vat_amount) stored,
  currency        text not null default 'EUR',
  amount_eur      numeric(15,2),
  -- VAT / tax
  vat_rate        numeric(5,4),
  vat_number      text,
  reverse_charge  boolean default false,  -- B2B cross-border reverse charge
  -- 3-way match result
  match_result    text,                   -- 'matched' | 'amount_mismatch' | 'no_po' | 'no_delivery'
  match_tolerance_pct numeric(5,4) default 0.02,  -- 2% tolerance
  match_delta_eur numeric(15,2),          -- difference from PO amount
  -- State
  status          invoice_status not null default 'received',
  received_at     timestamptz default now(),
  matched_at      timestamptz,
  approved_at     timestamptz,
  -- Audit trail
  parsed_by_model text default 'claude-sonnet-4-6',
  raw_extraction  jsonb,                  -- full Claude extraction for audit
  notes           text,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- Payment instructions — TrueSpend's output to ERP/finance
-- TrueSpend does NOT hold payment data. It creates the instruction. ERP executes.
create table payment_instructions (
  id              uuid primary key default uuid_generate_v4(),
  invoice_id      uuid references invoices(id) not null,
  po_id           uuid references purchase_orders(id),
  supplier_id     uuid references suppliers(id) not null,
  -- Payment details (references, not actual bank data)
  amount          numeric(15,2) not null,
  currency        text not null default 'EUR',
  payment_ref     text,                   -- internal reference for ERP
  due_date        date,
  -- ERP handoff
  erp_posted      boolean default false,
  erp_reference   text,                   -- ERP document number on success
  erp_posted_at   timestamptz,
  -- State
  status          text not null default 'pending',
  -- 'pending' | 'sent_to_erp' | 'paid' | 'failed'
  created_at      timestamptz default now()
);

-- ERP sync queue — ERP-agnostic output queue
-- Every TrueSpend event that needs to sync to ERP lands here.
-- Connector workflows read this queue and fire the appropriate ERP API call.
-- If no connector: status stays 'skipped', manual posting required.
create table erp_sync_queue (
  id              uuid primary key default uuid_generate_v4(),
  -- What needs to sync
  event_type      text not null,
  -- 'po_created' | 'invoice_approved' | 'payment_instruction' |
  -- 'vendor_created' | 'budget_update' | 'asset_disposal'
  entity_type     text not null,          -- 'purchase_order' | 'invoice' etc.
  entity_id       uuid not null,
  payload         jsonb not null,         -- normalized TrueSpend payload
  -- ERP target
  erp_system      text,                   -- 'sap' | 'oracle' | 'coupa' | 'netsuite' | null
  erp_endpoint    text,
  -- Status
  status          erp_sync_status not null default 'pending',
  attempts        int default 0,
  last_attempted  timestamptz,
  erp_response    jsonb,                  -- raw ERP response
  erp_reference   text,                  -- ERP document ID on success
  error_message   text,
  created_at      timestamptz default now(),
  synced_at       timestamptz
);


-- =============================================================================
-- ASSETS — HARDWARE LIFECYCLE & DEPRECIATION
-- =============================================================================

create table assets (
  id              uuid primary key default uuid_generate_v4(),
  asset_tag       text not null unique,   -- e.g. DACH-LT-0042
  -- What it is
  category        text not null,
  -- 'laptop' | 'desktop' | 'server' | 'network' | 'mobile' |
  -- 'printer' | 'monitor' | 'storage' | 'other'
  make            text,
  model           text,
  serial_number   text,
  specs           jsonb,
  -- e.g. {"cpu": "Intel i7", "ram_gb": 16, "storage_gb": 512, "os": "Windows 11"}
  -- Acquisition
  po_id           uuid references purchase_orders(id),
  purchase_date   date,
  purchase_cost   numeric(15,2),
  currency        text default 'EUR',
  purchase_cost_eur numeric(15,2),
  -- Depreciation
  depreciation_method depreciation_method not null default 'straight_line',
  useful_life_months  int not null default 36,   -- 3 years default for laptops
  residual_value      numeric(15,2) default 0,
  accumulated_depreciation numeric(15,2) default 0,
  current_book_value  numeric(15,2),
  -- Updated monthly by asset_lifecycle_monitor workflow
  -- Warranty
  warranty_expiry     date,
  warranty_tier       text,              -- 'basic' | 'premium' | 'onsite_next_day'
  warranty_provider   text,
  -- Assignment
  branch_id       uuid references branches(id),
  cost_center_id  uuid references cost_centers(id),
  assigned_user   text,                  -- email of assigned user
  assigned_at     date,
  -- Utilization (from IT integration)
  last_active_date    date,
  incident_count      int default 0,
  -- Lifecycle state
  status          asset_status not null default 'active',
  decommission_reason text,
  -- Disposal
  disposal_date   date,
  disposal_method text,                  -- 'resale' | 'recycling' | 'secure_destruction'
  disposal_value  numeric(15,2),
  disposal_reference text,               -- Certificate number for GDPR data destruction
  -- Metadata
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- Monthly depreciation log — input for Controlling's month-end journal entries
create table asset_depreciation_log (
  id              uuid primary key default uuid_generate_v4(),
  asset_id        uuid references assets(id) not null,
  period          text not null,             -- '2026-05'
  depreciation_amount numeric(15,2) not null,
  book_value_before   numeric(15,2),
  book_value_after    numeric(15,2),
  method_used     depreciation_method,
  -- Controlling fields
  gl_account      text,                      -- debit account (depreciation expense)
  cost_center_code text,                     -- from asset.cost_center_id
  journal_entry_ref text,                    -- ERP journal entry reference once posted
  posted          boolean default false,
  created_at      timestamptz default now()
);


-- =============================================================================
-- LICENSE INTELLIGENCE
-- =============================================================================

-- License entitlements — what the organization owns across all vendors
-- This is the anti-shelfware, anti-duplicate-purchase, anti-true-up-surprise table.
create table license_entitlements (
  id              uuid primary key default uuid_generate_v4(),
  contract_id     uuid references contracts(id),
  supplier_id     uuid references suppliers(id) not null,
  -- What you own
  product_name    text not null,
  product_code    text,                  -- Vendor SKU / product code
  license_type    license_type not null default 'named_user',
  -- Bundle decomposition — if this is part of a bundle, point to the parent
  bundle_parent_id uuid references license_entitlements(id),
  is_bundle       boolean default false,
  bundle_components jsonb,
  -- e.g. [{"product": "Teams", "included": true}, {"product": "SharePoint", "included": true}]
  -- Volume
  total_seats     int,                   -- null for capacity/site/enterprise licenses
  assigned_seats  int default 0,
  active_seats    int default 0,         -- used in last 60 days
  available_seats int generated always as (
    case when total_seats is null then null
    else total_seats - assigned_seats end
  ) stored,
  -- Shelfware detection
  shelfware_seats int default 0,         -- assigned but inactive >90 days
  shelfware_pct   numeric(5,2),          -- shelfware_seats / assigned_seats * 100
  -- True-up risk
  true_up_date    date,
  true_up_frequency text,                -- 'annual' | 'monthly' | 'quarterly'
  overage_seats   int default 0,         -- deployed beyond entitlement
  overage_price_per_seat numeric(15,4),
  -- Pricing
  price_per_seat  numeric(15,4),
  price_currency  text default 'EUR',
  total_cost_eur  numeric(15,2),
  -- Billing
  default_cost_center_id uuid references cost_centers(id),
  billing_split   jsonb,
  -- [{"cost_center_id": "uuid", "pct": 60}, {"cost_center_id": "uuid", "pct": 40}]
  -- Term
  term_start      date,
  term_end        date,
  -- Utilization (updated by license_utilization_monitor workflow)
  utilization_pct           numeric(5,2),    -- active / assigned * 100
  avg_feature_usage_depth   numeric(5,2),    -- what % of features active users use
  utilization_last_checked  date,
  -- Metadata
  notes           text,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- License assignments — who has what seat
-- This is updated every time a seat is provisioned or reclaimed.
create table license_assignments (
  id              uuid primary key default uuid_generate_v4(),
  entitlement_id  uuid references license_entitlements(id) not null,
  -- Who / what
  assigned_to_user  text not null,       -- email of assigned user
  assigned_to_asset_id uuid references assets(id),  -- for device licenses
  -- Budget allocation (who pays for this seat)
  cost_center_id  uuid references cost_centers(id),
  -- Source of the assignment
  ticket_id       uuid,                  -- FK added after tickets
  jira_key        text,                  -- Jira ticket that triggered this
  -- Utilization
  last_active_at  timestamptz,
  active          boolean default true,
  usage_depth_pct numeric(5,2),          -- 0-100: feature utilization depth
  -- Lifecycle
  assigned_at     timestamptz default now(),
  reclaimed_at    timestamptz,           -- when seat was taken back
  reclaim_reason  text,
  created_at      timestamptz default now()
);


-- =============================================================================
-- HYPERSCALER & LLM CONSUMPTION
-- =============================================================================

-- Hyperscaler positions — daily commitment vs burn snapshot
create table hyperscaler_positions (
  id              uuid primary key default uuid_generate_v4(),
  branch_id       uuid references branches(id),
  provider        text not null,         -- 'AWS' | 'GCP' | 'Azure'
  account_id      text,                  -- Cloud account / project ID
  service_name    text,                  -- EC2, BigQuery, etc.
  period          text not null,         -- '2026-05'
  contract_id     uuid references contracts(id),
  -- Commitment
  committed_eur   numeric(15,2),
  commitment_type text,                  -- 'EDP' | 'CUD' | 'Reservation' | 'SavingsPlan'
  commitment_end  date,
  -- Consumption
  mtd_spend_eur   numeric(15,2),
  daily_burn_eur  numeric(15,2),
  projected_eur   numeric(15,2),         -- projected month-end
  actual_spend_eur numeric(15,2),        -- final actual (set at period close)
  -- Utilization
  reservation_util  numeric(5,4),        -- 0.0 to 1.0
  idle_resources_eur numeric(15,2),
  -- Flags (set by hyperscaler_monitor workflow)
  overshoot_risk    boolean default false,
  undershoot_risk   boolean default false,
  alert_type        text,
  alert_severity    text,
  estimated_saving_eur numeric(15,2),
  last_reviewed_at  timestamptz,
  decision_id       uuid,                -- FK added after decisions table
  snapshot_date     date not null default current_date,
  created_at        timestamptz default now()
);

-- LLM API key register — every AI API key in the organization
-- The shadow AI discovery starts here.
create table llm_api_keys (
  id              uuid primary key default uuid_generate_v4(),
  provider        text not null,
  -- 'openai' | 'anthropic' | 'google' | 'aws_bedrock' |
  -- 'azure_openai' | 'cohere' | 'mistral' | 'other'
  key_alias       text not null,         -- last 4 chars only — never store full key
  description     text,                  -- what this key is used for
  -- Ownership
  branch_id       uuid references branches(id),
  cost_center_id  uuid references cost_centers(id),
  owner_email     text not null,
  team_name       text,
  -- Limits
  monthly_limit_usd   numeric(15,2),
  alert_threshold_pct numeric(5,2) default 80.00,  -- alert at 80% of limit
  -- Status
  status          text not null default 'active',
  -- 'active' | 'suspended' | 'decommissioned'
  -- Usage tracking
  last_used_at    timestamptz,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- LLM consumption — daily token usage per key per model
-- The intelligence layer that kills €28k/month in duplicate AI spend
create table llm_consumption (
  id              uuid primary key default uuid_generate_v4(),
  api_key_id      uuid references llm_api_keys(id),
  provider        text not null,
  model           text not null,
  -- e.g. 'gpt-4o' | 'claude-sonnet-4-6' | 'gemini-1.5-pro'
  -- Allocation
  branch_id       uuid references branches(id),
  cost_center_id  uuid references cost_centers(id),
  period          text not null,         -- '2026-05'
  -- Token consumption
  input_tokens    bigint default 0,
  output_tokens   bigint default 0,
  total_tokens    bigint generated always as (input_tokens + output_tokens) stored,
  -- Cost
  cost_usd        numeric(15,6),
  cost_eur        numeric(15,6),         -- converted at daily ECB rate
  fx_rate_used    numeric(10,6),
  -- Pricing snapshot at time of consumption
  price_per_1m_input_usd  numeric(10,6),
  price_per_1m_output_usd numeric(10,6),
  -- Commitment (if on committed tier)
  committed_spend_usd     numeric(15,2),
  committed_tier  text default 'payg',   -- 'payg' | 'committed' | 'enterprise'
  -- Flags
  overshoot_risk      boolean default false,
  anomaly_detected    boolean default false,
  anomaly_reason      text,
  -- Baseline (for anomaly detection)
  prior_7d_avg_cost_usd numeric(15,6),
  snapshot_date   date not null default current_date,
  created_at      timestamptz default now()
);


-- =============================================================================
-- TICKETS, DECISIONS, TRACE LOG
-- =============================================================================

-- Tickets — every request and automated action in the system
create table tickets (
  id              uuid primary key default uuid_generate_v4(),
  reference       text not null unique,  -- TS-2026-XXXX
  source          ticket_source not null,
  status          ticket_status not null default 'open',
  -- What it's about
  title           text not null,
  description     text,
  category        spend_category,        -- denormalized for budget join (avoids correlated subquery)
  branch_id       uuid references branches(id),
  cost_center_id  uuid references cost_centers(id),
  supplier_id     uuid references suppliers(id),
  contract_id     uuid references contracts(id),
  -- Who
  requested_by    text,                  -- email of submitter
  requester_id    uuid references users(id),
  owner_id        uuid references users(id),
  -- Financials
  amount          numeric(15,2),
  amount_eur      numeric(15,2),         -- normalised EUR
  currency        text default 'EUR',
  -- Review fields (for one-touch and signature tickets)
  review_type     text,
  -- 'major_contract' | 'compliance_flag' | 'signature' | 'budget_overrun'
  review_notes    text,                  -- agent summary for reviewer
  pdf_url         text,                  -- contract PDF for signing
  -- Compliance links
  compliance_check_id uuid,              -- FK added after compliance_checks
  legal_doc_id    uuid,                  -- FK added after legal_documents
  -- Jira sync
  jira_key        text,                  -- PROC-1234
  jira_url        text,
  jira_account_id text,                  -- Jira requester account ID
  -- P2I links
  po_id           uuid references purchase_orders(id),
  -- SLA
  target_close    timestamptz,
  -- Timing
  created_at      timestamptz default now(),
  updated_at      timestamptz default now(),
  closed_at       timestamptz
);

-- Back-fill FK now that tickets exists
alter table budget_reallocations
  add constraint fk_reallocation_ticket
  foreign key (ticket_id) references tickets(id);

alter table purchase_orders
  add constraint fk_po_ticket
  foreign key (ticket_id) references tickets(id);

alter table license_assignments
  add constraint fk_assignment_ticket
  foreign key (ticket_id) references tickets(id);

-- Decisions — every agent disposition and its reasoning
create table decisions (
  id              uuid primary key default uuid_generate_v4(),
  ticket_id       uuid references tickets(id),
  contract_id     uuid references contracts(id),
  -- The decision
  disposition     disposition not null,
  confidence      numeric(5,4) not null,  -- 0.0000 to 1.0000
  reasoning       text not null,
  recommendation  text,
  brief           text,                   -- full brief for one-touch / escalate
  -- Budget state at time of decision (snapshot — immutable audit record)
  budget_available_eur  numeric(15,2),
  budget_bucket_pct     numeric(5,2),     -- % of bucket consumed at decision time
  -- Outcome
  outcome         text,
  actioned_by     text,                   -- 'agent' | manager email
  actioned_at     timestamptz,
  -- Metadata
  model_used      text default 'claude-sonnet-4-6',
  created_at      timestamptz default now()
);

-- Back-fill FK on hyperscaler_positions
alter table hyperscaler_positions
  add constraint fk_hpos_decision
  foreign key (decision_id) references decisions(id);

-- Trace log — signal-level detail for every decision
create table trace_log (
  id              uuid primary key default uuid_generate_v4(),
  decision_id     uuid references decisions(id),
  signal          signal_type not null,
  value           text not null,          -- what the signal showed
  weight          numeric(5,4),           -- how much this influenced disposition
  green           boolean,                -- did this signal pass?
  notes           text,
  created_at      timestamptz default now()
);

-- Supplier emails — threaded institutional memory
create table supplier_emails (
  id              uuid primary key default uuid_generate_v4(),
  supplier_id     uuid references suppliers(id),
  contract_id     uuid references contracts(id),
  direction       text not null,          -- 'inbound' | 'outbound'
  subject         text,
  body_summary    text,                   -- agent summary
  commitments     text[],                 -- informal commitments extracted
  order_reference text,                   -- PO reference for auto-reorders
  flagged         boolean default false,
  flag_reason     text,
  received_at     timestamptz,
  created_at      timestamptz default now()
);


-- =============================================================================
-- COMPLIANCE & LEGAL
-- =============================================================================

-- Legal documents — NDA, DPA, TOM, SCC per supplier
create table legal_documents (
  id              uuid primary key default uuid_generate_v4(),
  supplier_id     uuid references suppliers(id) not null,
  doc_type        doc_type not null,
  status          doc_status not null default 'generating',
  -- Content
  content         text,
  content_summary text,
  -- Parties
  company_name    text default 'TrueSpend GmbH',
  supplier_name   text,
  governing_law   text default 'German law',
  -- Dates
  generated_at    timestamptz,
  sent_at         timestamptz,
  signed_at       timestamptz,
  expires_at      date,
  -- Tracking
  sent_to_email   text,
  notes           text,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now(),
  unique(supplier_id, doc_type)
);

-- Compliance checks — per supplier, per agent
create table compliance_checks (
  id              uuid primary key default uuid_generate_v4(),
  supplier_id     uuid references suppliers(id) not null,
  check_type      text not null,
  -- 'lawyer' | 'gdpr' | 'infosec' | 'lksg' | 'ethics'
  status          compliance_status not null default 'pending',
  score           numeric(5,2),           -- 0-100
  passed          boolean,
  findings        text[],
  blockers        text[],
  recommendations text[],
  full_report     text,
  docs_required   doc_type[],
  model_used      text default 'claude-sonnet-4-6',
  checked_at      timestamptz default now(),
  created_at      timestamptz default now()
);

-- Back-fill compliance FKs on tickets
alter table tickets
  add constraint fk_ticket_compliance
  foreign key (compliance_check_id) references compliance_checks(id);

alter table tickets
  add constraint fk_ticket_legal_doc
  foreign key (legal_doc_id) references legal_documents(id);


-- =============================================================================
-- VENDOR PRICING INTELLIGENCE
-- =============================================================================

-- Market benchmark database — grows from transaction history + public sources
-- This is what makes the negotiation position generator possible.
create table vendor_pricing_benchmarks (
  id              uuid primary key default uuid_generate_v4(),
  supplier_id     uuid references suppliers(id),
  product_name    text not null,
  product_code    text,
  -- Pricing intelligence
  list_price      numeric(15,4),
  typical_discount_pct numeric(5,2),     -- what comparable companies actually pay
  floor_price_pct numeric(5,2),          -- agent-derived walk-away floor
  pricing_model   text,
  -- 'per_seat' | 'per_device' | 'capacity' | 'flat' | 'consumption'
  price_currency  text default 'EUR',
  -- Competitor intelligence
  competitor_products jsonb,
  -- [{"vendor": "HubSpot", "product": "Sales Hub Pro",
  --   "price_per_seat": 450, "covers_use_cases": ["CRM", "Pipeline"]}]
  -- Source
  source          text,
  -- 'public_pricing' | 'transaction_history' | 'industry_data' | 'agent_derived'
  valid_from      date,
  valid_to        date,
  notes           text,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- Trust settings — the autonomy dial
-- The agent earns authority expansion through demonstrated accuracy.
create table trust_settings (
  id              uuid primary key default uuid_generate_v4(),
  branch_id       uuid references branches(id),  -- null = org-wide setting
  category        spend_category,                -- null = all categories
  -- Current thresholds
  auto_execute_threshold_eur  numeric(15,2) not null default 10000,
  one_touch_threshold_eur     numeric(15,2) not null default 100000,
  -- Above one_touch_threshold → always escalate to Jira
  -- Confidence floor
  min_confidence_auto  numeric(5,4) default 0.9500,  -- 95%
  -- Performance tracking
  total_decisions      int default 0,
  auto_executed        int default 0,
  escalated            int default 0,
  reversed_by_human    int default 0,   -- agent got it wrong, human corrected
  accuracy_pct         numeric(5,2),
  -- Expansion history
  last_threshold_change timestamptz,
  last_reviewed_by      uuid references users(id),
  notes               text,
  created_at          timestamptz default now(),
  updated_at          timestamptz default now()
);


-- =============================================================================
-- VIEWS
-- =============================================================================

-- Contracts expiring ≤90 days (fixed: >= not >, catches same-day)
create view contracts_expiring as
select
  c.id,
  c.name,
  c.expiry_date,
  c.value,
  c.value_eur,
  c.currency,
  c.renewal_state,
  c.auto_renew,
  c.category,
  c.escalation_clause,
  c.escalation_rate,
  c.tco_eur,
  (c.expiry_date - current_date) as days_remaining,
  s.name          as supplier_name,
  s.health        as supplier_health,
  s.strategic_tier,
  b.name          as branch_name,
  b.region        as branch_region,
  u.name          as owner_name,
  u.email         as owner_email
from contracts c
join suppliers s on s.id = c.supplier_id
join branches b on b.id = c.branch_id
join users u on u.id = c.owner_id
where c.expiry_date >= current_date
  and (c.expiry_date - current_date) <= 90
order by c.expiry_date asc;

-- Operations Board — everything needing human action
create view open_tickets_board as
select
  t.id,
  t.reference,
  t.source,
  t.status,
  t.title,
  t.description,
  t.review_type,
  t.review_notes,
  t.pdf_url,
  t.amount,
  t.amount_eur,
  t.currency,
  t.jira_key,
  t.po_id,
  po.po_number,
  po.status          as po_status,
  po.expected_delivery as po_expected_delivery,
  po.delivery_overdue  as po_delivery_overdue,
  t.created_at,
  t.target_close,
  -- Supplier
  s.name          as supplier_name,
  s.health        as supplier_health,
  s.compliance_status as supplier_compliance,
  -- Branch & cost center
  b.name          as branch_name,
  cc.code         as cost_center_code,
  cc.name         as cost_center_name,
  -- Owner
  u.name          as owner_name,
  u.email         as owner_email,
  -- Latest decision
  d.disposition,
  d.confidence,
  d.recommendation,
  d.reasoning     as agent_reasoning,
  d.budget_available_eur,
  d.budget_bucket_pct,
  -- Budget position context
  bp.budget       as bucket_budget,
  bp.committed    as bucket_committed,
  bp.spent        as bucket_spent,
  bp.available    as bucket_available,
  -- Priority sort: signature_required first, then pending_confirm, then others
  case t.status
    when 'signature_required' then 1
    when 'pending_confirm'    then 2
    when 'pending_review'     then 3
    when 'escalated'          then 4
    else 5
  end as sort_priority
from tickets t
left join suppliers s  on s.id  = t.supplier_id
left join branches b   on b.id  = t.branch_id
left join cost_centers cc on cc.id = t.cost_center_id
left join users u      on u.id  = t.owner_id
left join decisions d  on d.ticket_id = t.id
left join purchase_orders po on po.id = t.po_id
left join budget_positions bp
  on bp.branch_id = t.branch_id
  and bp.cost_center_id is not distinct from t.cost_center_id
  and bp.category = t.category
  and bp.period = (
    extract(year from now())::text || '-Q' ||
    ceil(extract(month from now()) / 3.0)::text
  )
where t.status in (
  'open', 'pending_confirm', 'pending_review',
  'signature_required', 'escalated', 'approved'
)
order by sort_priority, t.created_at asc;

-- Budget command center — CFO and Controlling view
create view budget_command_center as
select
  b.id            as branch_id,
  b.name          as branch_name,
  b.region,
  bp.category,
  bp.period,
  cc.code         as cost_center_code,
  cc.name         as cost_center_name,
  bp.budget,
  bp.committed,
  bp.spent,
  bp.available,
  round(bp.committed / nullif(bp.budget, 0) * 100, 1) as committed_pct,
  round((bp.committed + bp.spent) / nullif(bp.budget, 0) * 100, 1) as consumed_pct,
  case
    when bp.available < 0 then 'overrun'
    when (bp.committed + bp.spent) / nullif(bp.budget, 0) > 0.90 then 'critical'
    when (bp.committed + bp.spent) / nullif(bp.budget, 0) > 0.75 then 'warn'
    else 'healthy'
  end as budget_status
from budget_positions bp
join branches b on b.id = bp.branch_id
left join cost_centers cc on cc.id = bp.cost_center_id
order by
  case
    when bp.available < 0 then 1
    when (bp.committed + bp.spent) / nullif(bp.budget, 0) > 0.90 then 2
    when (bp.committed + bp.spent) / nullif(bp.budget, 0) > 0.75 then 3
    else 4
  end,
  b.name, bp.category;

-- Commitment register — open POs not yet invoiced (Controlling's accrual list)
create view commitment_register as
select
  po.po_number,
  po.description,
  po.amount_eur,
  po.currency,
  po.po_date,
  po.expected_delivery,
  po.status      as po_status,
  s.name         as supplier_name,
  b.name         as branch_name,
  cc.code        as cost_center_code,
  cc.name        as cost_center_name,
  po.category,
  t.reference    as ticket_reference,
  t.jira_key,
  -- Flag overdue deliveries
  case
    when po.expected_delivery < current_date
    and po.status in ('sent', 'acknowledged')
    then true else false
  end as delivery_overdue
from purchase_orders po
join suppliers s on s.id = po.supplier_id
join branches b on b.id = po.branch_id
left join cost_centers cc on cc.id = po.cost_center_id
left join tickets t on t.id = po.ticket_id
where po.status not in ('closed', 'cancelled')
order by po.po_date desc;

-- License waste report — shelfware, overage, bundle waste
create view license_waste_report as
select
  le.id           as entitlement_id,
  le.product_name,
  le.license_type,
  s.name          as supplier_name,
  b.name          as branch_name,
  cc.name         as cost_center_name,
  le.total_seats,
  le.assigned_seats,
  le.active_seats,
  le.shelfware_seats,
  le.overage_seats,
  le.utilization_pct,
  le.price_per_seat,
  round(le.shelfware_seats * le.price_per_seat, 2)  as annual_shelfware_cost,
  round(le.overage_seats * coalesce(le.overage_price_per_seat, le.price_per_seat), 2) as overage_exposure,
  le.term_end,
  (le.term_end - current_date) as days_to_renewal
from license_entitlements le
join suppliers s on s.id = le.supplier_id
left join contracts c on c.id = le.contract_id
left join branches b on b.id = c.branch_id
left join cost_centers cc on cc.id = le.default_cost_center_id
where le.shelfware_seats > 0 or le.overage_seats > 0
order by (le.shelfware_seats * le.price_per_seat) desc nulls last;

-- LLM spend summary — by provider, team, model
create view llm_spend_summary as
select
  lc.provider,
  lc.model,
  lc.period,
  b.name          as branch_name,
  cc.name         as cost_center_name,
  k.owner_email   as key_owner,
  k.team_name,
  sum(lc.input_tokens)   as total_input_tokens,
  sum(lc.output_tokens)  as total_output_tokens,
  sum(lc.cost_usd)       as total_cost_usd,
  sum(lc.cost_eur)       as total_cost_eur,
  count(*) filter (where lc.anomaly_detected) as anomaly_days,
  k.monthly_limit_usd,
  round(sum(lc.cost_usd) / nullif(k.monthly_limit_usd, 0) * 100, 1) as pct_of_limit
from llm_consumption lc
join llm_api_keys k on k.id = lc.api_key_id
left join branches b on b.id = lc.branch_id
left join cost_centers cc on cc.id = lc.cost_center_id
group by
  lc.provider, lc.model, lc.period,
  b.name, cc.name, k.owner_email, k.team_name, k.monthly_limit_usd
order by sum(lc.cost_eur) desc nulls last;

-- Agent performance — trust-building metrics
create view agent_performance as
select
  date_trunc('week', d.created_at)                                 as week,
  count(*)                                                         as total_decisions,
  count(*) filter (where d.disposition = 'auto_execute')           as auto_executed,
  count(*) filter (where d.disposition = 'one_touch')              as one_touch,
  count(*) filter (where d.disposition = 'escalate')               as escalated,
  count(*) filter (where d.reversed_by_human is true)              as reversed,
  round(
    count(*) filter (where d.disposition = 'auto_execute')::numeric
    / nullif(count(*), 0)::numeric * 100, 1
  )                                                                as auto_execute_pct,
  round(avg(d.confidence) * 100, 1)                               as avg_confidence_pct
from (
  select *, actioned_by != 'agent' and disposition = 'auto_execute' as reversed_by_human
  from decisions
) d
group by date_trunc('week', d.created_at)
order by week desc;

-- Supplier compliance summary
create view supplier_compliance_summary as
select
  s.id            as supplier_id,
  s.name          as supplier_name,
  s.compliance_status,
  s.nda_status,
  s.dpa_status,
  s.lksg_compliant,
  s.infosec_score,
  s.onboarding_complete,
  -- Latest check per type
  max(case when cc.check_type = 'lawyer'  then cc.score end)  as lawyer_score,
  max(case when cc.check_type = 'gdpr'    then cc.score end)  as gdpr_score,
  max(case when cc.check_type = 'infosec' then cc.score end)  as infosec_score_check,
  max(case when cc.check_type = 'lksg'    then cc.score end)  as lksg_score,
  -- Blockers across all checks
  array_agg(distinct unnest(cc.blockers)) filter (
    where cc.blockers is not null and array_length(cc.blockers, 1) > 0
  )                                                            as all_blockers,
  -- Document status
  max(case when ld.doc_type = 'nda' then ld.status::text end) as nda_doc_status,
  max(case when ld.doc_type = 'dpa' then ld.status::text end) as dpa_doc_status
from suppliers s
left join compliance_checks cc on cc.supplier_id = s.id
left join legal_documents ld   on ld.supplier_id = s.id
group by s.id, s.name, s.compliance_status, s.nda_status, s.dpa_status,
         s.lksg_compliant, s.infosec_score, s.onboarding_complete;


-- =============================================================================
-- INDEXES
-- =============================================================================

-- Contracts
create index idx_contracts_expiry       on contracts(expiry_date);
create index idx_contracts_supplier     on contracts(supplier_id);
create index idx_contracts_branch       on contracts(branch_id);
create index idx_contracts_renewal      on contracts(renewal_state);
create index idx_contracts_category     on contracts(category);

-- Tickets
create index idx_tickets_status         on tickets(status);
create index idx_tickets_source         on tickets(source);
create index idx_tickets_branch         on tickets(branch_id);
create index idx_tickets_supplier       on tickets(supplier_id);
create index idx_tickets_cost_center    on tickets(cost_center_id);
create index idx_tickets_review_type    on tickets(review_type) where review_type is not null;

-- Decisions & trace
create index idx_decisions_ticket       on decisions(ticket_id);
create index idx_decisions_created      on decisions(created_at);
create index idx_trace_decision         on trace_log(decision_id);
create index idx_trace_signal           on trace_log(signal);

-- Budget
create index idx_budget_buckets_branch  on budget_buckets(branch_id, fiscal_year);
create index idx_budget_pos_branch      on budget_positions(branch_id, period);
create index idx_budget_pos_cc          on budget_positions(cost_center_id, period);
create index idx_reallocations_from     on budget_reallocations(from_id);
create index idx_reallocations_to       on budget_reallocations(to_id);

-- P2I
create index idx_po_supplier            on purchase_orders(supplier_id);
create index idx_po_status              on purchase_orders(status);
create index idx_po_ticket              on purchase_orders(ticket_id);
create index idx_invoices_po            on invoices(po_id);
create index idx_invoices_status        on invoices(status);
create index idx_erp_queue_status       on erp_sync_queue(status);
create index idx_erp_queue_entity       on erp_sync_queue(entity_type, entity_id);

-- Assets
create index idx_assets_branch          on assets(branch_id);
create index idx_assets_status          on assets(status);
create index idx_assets_warranty        on assets(warranty_expiry);
create index idx_depreciation_asset     on asset_depreciation_log(asset_id, period);

-- Licenses
create index idx_entitlements_supplier  on license_entitlements(supplier_id);
create index idx_entitlements_term_end  on license_entitlements(term_end);
create index idx_assignments_user       on license_assignments(assigned_to_user);
create index idx_assignments_active     on license_assignments(entitlement_id) where active = true;

-- Consumption
create index idx_hyperscaler_branch     on hyperscaler_positions(branch_id, period);
create index idx_llm_key_period         on llm_consumption(api_key_id, period);
create index idx_llm_provider_period    on llm_consumption(provider, period);

-- Compliance & legal
create index idx_legal_docs_supplier    on legal_documents(supplier_id);
create index idx_legal_docs_status      on legal_documents(status);
create index idx_compliance_supplier    on compliance_checks(supplier_id);
create index idx_compliance_type        on compliance_checks(check_type);

-- Intelligence
create index idx_clauses_contract       on contract_clauses(contract_id);
create index idx_clauses_type           on contract_clauses(clause_type);
create index idx_benchmarks_supplier    on vendor_pricing_benchmarks(supplier_id);

-- Performance: covering index for 3-tier budget check
-- budget_positions is hit on every approval — index must cover all columns read
create index idx_budget_pos_lookup
  on budget_positions(branch_id, category, period)
  include (budget, committed, spent, available);

-- Performance: partial index for Operations Board
-- Only indexes rows the board actually queries — no overhead for closed tickets
create index idx_tickets_board
  on tickets(status, created_at)
  where status in ('open', 'pending_confirm', 'pending_review',
                   'signature_required', 'escalated');

-- Performance: category lookup on tickets for budget join
create index idx_tickets_category       on tickets(category) where category is not null;


-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

alter table contracts           enable row level security;
alter table tickets              enable row level security;
alter table decisions            enable row level security;
alter table suppliers            enable row level security;
alter table budget_positions     enable row level security;
alter table budget_buckets       enable row level security;
alter table budget_pools         enable row level security;
alter table budget_reallocations enable row level security;
alter table purchase_orders      enable row level security;
alter table invoices             enable row level security;
alter table assets               enable row level security;
alter table license_entitlements enable row level security;
alter table license_assignments  enable row level security;
alter table llm_consumption      enable row level security;
alter table legal_documents      enable row level security;
alter table compliance_checks    enable row level security;

do $$
begin
  if exists (
    select 1 from information_schema.schemata where schema_name = 'auth'
  ) then
    -- Supabase-style policies
    execute 'create policy "service_role_all" on contracts
      for all using (auth.role() = ''service_role'')';
    execute 'create policy "service_role_all" on tickets
      for all using (auth.role() = ''service_role'')';
    execute 'create policy "service_role_all" on decisions
      for all using (auth.role() = ''service_role'')';
    execute 'create policy "service_role_all" on suppliers
      for all using (auth.role() = ''service_role'')';
    execute 'create policy "service_role_all" on budget_positions
      for all using (auth.role() = ''service_role'')';
  else
    -- Railway: allow all for the application role
    execute 'create policy "app_role_all" on contracts
      for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on tickets
      for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on decisions
      for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on suppliers
      for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on budget_positions
      for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on budget_buckets
      for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on purchase_orders
      for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on invoices
      for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on assets
      for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on license_entitlements
      for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on license_assignments
      for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on llm_consumption
      for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on legal_documents
      for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on compliance_checks
      for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on budget_reallocations
      for all to truespend using (true) with check (true)';
    execute 'create policy "app_role_all" on budget_pools
      for all to truespend using (true) with check (true)';
  end if;
end $$;


-- =============================================================================
-- ATOMIC BUDGET FUNCTIONS
-- Race condition fix: concurrent PATCH operations on budget_positions both
-- read-then-write → one write is silently lost. These functions use row-level
-- locking (FOR UPDATE) to serialize concurrent budget mutations.
-- Called via PostgREST RPC: POST /rpc/commit_budget
-- =============================================================================

-- commit_budget — called on approval. Moves amount from available → committed.
-- Returns the updated row. Errors on insufficient budget.
create or replace function commit_budget(
  p_branch_id       uuid,
  p_cost_center_id  uuid,
  p_category        spend_category,
  p_period          text,
  p_amount          numeric
) returns budget_positions language plpgsql security definer as $$
declare
  v_row budget_positions;
begin
  select * into v_row
  from budget_positions
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category
    and period = p_period
  for update;  -- row-level lock serializes concurrent calls

  if not found then
    raise exception 'Budget position not found: % / % / % / %',
      p_branch_id, p_cost_center_id, p_category, p_period;
  end if;

  if (v_row.budget - v_row.committed - v_row.spent) < p_amount then
    raise exception 'Insufficient budget: available=%, requested=%',
      (v_row.budget - v_row.committed - v_row.spent), p_amount;
  end if;

  update budget_positions
  set committed   = committed + p_amount,
      updated_at  = now()
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category
    and period = p_period
  returning * into v_row;

  return v_row;
end $$;

-- release_budget — called on rejection or cancellation.
-- Moves amount from committed back to available.
create or replace function release_budget(
  p_branch_id       uuid,
  p_cost_center_id  uuid,
  p_category        spend_category,
  p_period          text,
  p_amount          numeric
) returns budget_positions language plpgsql security definer as $$
declare
  v_row budget_positions;
begin
  select * into v_row
  from budget_positions
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category
    and period = p_period
  for update;

  if not found then
    raise exception 'Budget position not found: % / % / % / %',
      p_branch_id, p_cost_center_id, p_category, p_period;
  end if;

  update budget_positions
  set committed   = greatest(committed - p_amount, 0),
      updated_at  = now()
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category
    and period = p_period
  returning * into v_row;

  return v_row;
end $$;

-- record_spend — called when invoice is approved for payment.
-- Releases committed amount, increments spent.
-- These should always match: if PO was for €5k, invoice should be ~€5k (±2% tolerance).
create or replace function record_spend(
  p_branch_id       uuid,
  p_cost_center_id  uuid,
  p_category        spend_category,
  p_period          text,
  p_committed_release numeric,   -- amount to release from committed (PO amount)
  p_spend_amount      numeric    -- actual invoice amount to record as spent
) returns budget_positions language plpgsql security definer as $$
declare
  v_row budget_positions;
begin
  select * into v_row
  from budget_positions
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category
    and period = p_period
  for update;

  if not found then
    raise exception 'Budget position not found: % / % / % / %',
      p_branch_id, p_cost_center_id, p_category, p_period;
  end if;

  update budget_positions
  set committed   = greatest(committed - p_committed_release, 0),
      spent       = spent + p_spend_amount,
      updated_at  = now()
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category
    and period = p_period
  returning * into v_row;

  return v_row;
end $$;

-- Grant RPC access to application role
grant execute on function commit_budget  to truespend;
grant execute on function release_budget to truespend;
grant execute on function record_spend   to truespend;


-- =============================================================================
-- PO NUMBER GENERATION
-- Atomic, readable PO numbers. Format: PO-2026-DACH-0042
-- Uses po_sequences table to avoid gaps and collisions.
-- Called via PostgREST RPC: POST /rpc/next_po_number
-- =============================================================================

create or replace function next_po_number(
  p_branch_id   uuid,
  p_branch_code text   -- e.g. 'DACH', 'UKI', 'BNL' — passed in from workflow
) returns text language plpgsql security definer as $$
declare
  v_year  int  := extract(year from current_date);
  v_seq   int;
begin
  insert into po_sequences (branch_id, fiscal_year, last_seq)
  values (p_branch_id, v_year, 1)
  on conflict (branch_id, fiscal_year)
  do update set last_seq = po_sequences.last_seq + 1
  returning last_seq into v_seq;

  return 'PO-' || v_year || '-' || upper(p_branch_code) || '-' || lpad(v_seq::text, 4, '0');
end $$;

-- approve_and_commit — single RPC call from the approval path.
-- Creates a PO, commits budget, updates ticket status.
-- Called via PostgREST RPC: POST /rpc/approve_and_commit
-- Returns the created PO row.
create or replace function approve_and_commit(
  p_ticket_id       uuid,
  p_branch_id       uuid,
  p_branch_code     text,
  p_cost_center_id  uuid,
  p_category        spend_category,
  p_period          text,          -- '2026-Q2'
  p_supplier_id     uuid,
  p_contract_id     uuid,
  p_description     text,
  p_amount          numeric,
  p_currency        text,
  p_amount_eur      numeric,
  p_raised_by       uuid,
  p_expected_delivery date,
  p_line_items      jsonb
) returns purchase_orders language plpgsql security definer as $$
declare
  v_po_number  text;
  v_po         purchase_orders;
begin
  -- Step 1: generate PO number (atomic sequence)
  v_po_number := next_po_number(p_branch_id, p_branch_code);

  -- Step 2: commit budget (row-level lock, raises if insufficient)
  perform commit_budget(
    p_branch_id, p_cost_center_id, p_category, p_period, p_amount_eur
  );

  -- Step 3: create PO row
  insert into purchase_orders (
    po_number, ticket_id, contract_id, supplier_id, branch_id,
    cost_center_id, raised_by, description, category, line_items,
    amount, currency, amount_eur, po_date, expected_delivery, status
  ) values (
    v_po_number, p_ticket_id, p_contract_id, p_supplier_id, p_branch_id,
    p_cost_center_id, p_raised_by, p_description, p_category, p_line_items,
    p_amount, p_currency, p_amount_eur, current_date, p_expected_delivery, 'draft'
  )
  returning * into v_po;

  -- Step 4: update ticket with PO reference and set status to approved
  update tickets
  set status     = 'approved',
      po_id      = v_po.id,
      updated_at = now()
  where id = p_ticket_id;

  return v_po;
end $$;

-- confirm_delivery — called when Operations Board "Confirm Delivery" is clicked.
-- Updates PO to delivered, checks SLA breach, flags supplier health if late.
create or replace function confirm_delivery(
  p_po_id       uuid,
  p_confirmed_by text    -- email of user confirming
) returns purchase_orders language plpgsql security definer as $$
declare
  v_po   purchase_orders;
  v_late boolean;
begin
  select * into v_po from purchase_orders where id = p_po_id for update;

  if not found then
    raise exception 'PO not found: %', p_po_id;
  end if;

  v_late := v_po.expected_delivery is not null
        and current_date > v_po.expected_delivery;

  update purchase_orders
  set status       = 'delivered',
      delivered_at = now(),
      notes        = coalesce(notes, '') ||
                     case when v_late
                     then ' [LATE: delivered ' ||
                          (current_date - v_po.expected_delivery)::text ||
                          ' days after SLA]'
                     else '' end,
      updated_at   = now()
  where id = p_po_id
  returning * into v_po;

  -- Flag supplier health if delivery was late
  if v_late then
    update suppliers
    set health = case
      when health = 'green' then 'watch'::supplier_health
      else health  -- already watch or red — don't downgrade automatically
    end,
    updated_at = now()
    where id = v_po.supplier_id;
  end if;

  return v_po;
end $$;

-- match_invoice — 3-way match logic as a PostgreSQL function.
-- Called by invoice_processor workflow after Claude extracts invoice data.
-- Returns match result: 'matched' | 'amount_mismatch' | 'no_po' | 'no_delivery'
create or replace function match_invoice(
  p_invoice_id     uuid
) returns invoices language plpgsql security definer as $$
declare
  v_inv  invoices;
  v_po   purchase_orders;
  v_tolerance numeric;
  v_delta     numeric;
  v_result    text;
begin
  select * into v_inv from invoices where id = p_invoice_id for update;
  if not found then
    raise exception 'Invoice not found: %', p_invoice_id;
  end if;

  if v_inv.po_id is null then
    update invoices set match_result = 'no_po', status = 'disputed',
      matched_at = now(), updated_at = now()
    where id = p_invoice_id returning * into v_inv;
    return v_inv;
  end if;

  select * into v_po from purchase_orders where id = v_inv.po_id;

  -- Check delivery confirmed
  if v_po.status not in ('delivered', 'invoiced', 'closed') then
    update invoices set match_result = 'no_delivery', status = 'disputed',
      matched_at = now(), updated_at = now()
    where id = p_invoice_id returning * into v_inv;
    return v_inv;
  end if;

  -- Amount match within tolerance
  v_tolerance := v_po.amount * coalesce(v_inv.match_tolerance_pct, 0.02);
  v_delta     := abs(v_inv.amount - v_po.amount);

  if v_delta <= v_tolerance then
    v_result := 'matched';
    -- Advance PO to invoiced
    update purchase_orders set status = 'invoiced', updated_at = now()
    where id = v_po.id;
  else
    v_result := 'amount_mismatch';
  end if;

  update invoices
  set match_result   = v_result,
      match_delta_eur = v_delta,
      status          = case v_result when 'matched' then 'matched' else 'disputed' end,
      matched_at      = now(),
      updated_at      = now()
  where id = p_invoice_id
  returning * into v_inv;

  return v_inv;
end $$;

-- create_payment_instruction — called after 3-way match passes.
-- Creates payment instruction record + writes erp_sync_queue entry.
create or replace function create_payment_instruction(
  p_invoice_id   uuid,
  p_due_date     date
) returns payment_instructions language plpgsql security definer as $$
declare
  v_inv   invoices;
  v_po    purchase_orders;
  v_pi    payment_instructions;
  v_ref   text;
begin
  select * into v_inv from invoices where id = p_invoice_id;
  select * into v_po  from purchase_orders where id = v_inv.po_id;

  v_ref := 'PAY-' || extract(year from current_date)::text ||
           '-' || to_char(now(), 'MM') ||
           '-' || substr(p_invoice_id::text, 1, 8);

  insert into payment_instructions (
    invoice_id, po_id, supplier_id, amount, currency, payment_ref,
    due_date, status
  ) values (
    p_invoice_id, v_inv.po_id, v_inv.supplier_id, v_inv.amount,
    v_inv.currency, v_ref, p_due_date, 'pending'
  )
  returning * into v_pi;

  -- Approve invoice
  update invoices set status = 'approved', approved_at = now(), updated_at = now()
  where id = p_invoice_id;

  -- Write ERP sync queue entry
  insert into erp_sync_queue (
    event_type, entity_type, entity_id, payload, status
  ) values (
    'invoice_approved',
    'invoice',
    p_invoice_id,
    jsonb_build_object(
      'payment_instruction_id', v_pi.id,
      'payment_ref',            v_ref,
      'invoice_id',             p_invoice_id,
      'po_id',                  v_inv.po_id,
      'supplier_id',            v_inv.supplier_id,
      'amount',                 v_inv.amount,
      'currency',               v_inv.currency,
      'due_date',               p_due_date,
      'po_number',              v_po.po_number
    ),
    'pending'
  );

  -- Record spend in budget (release committed, add to spent)
  if v_po.branch_id is not null and v_po.category is not null then
    perform record_spend(
      v_po.branch_id,
      v_po.cost_center_id,
      v_po.category,
      extract(year from current_date)::text || '-Q' ||
        ceil(extract(month from current_date) / 3.0)::int::text,
      v_po.amount_eur,   -- release committed (PO amount)
      v_inv.amount_eur   -- record actual spend (invoice amount)
    );
  end if;

  return v_pi;
end $$;

grant execute on function next_po_number          to truespend;
grant execute on function approve_and_commit      to truespend;
grant execute on function confirm_delivery        to truespend;
grant execute on function match_invoice           to truespend;
grant execute on function create_payment_instruction to truespend;


-- =============================================================================
-- WORKFLOW MONITORING
-- Grafana reads this table. Every workflow run writes a row.
-- Enables: SLA alerting, duration trending, error rate dashboards.
-- =============================================================================

create table workflow_runs (
  id                uuid primary key default uuid_generate_v4(),
  workflow_name     text not null,
  -- 'contract_watcher' | 'hyperscaler_monitor' | 'intake_receiver' |
  -- 'reorder_trigger' | 'supplier_reply_handler' | 'supplier_onboarding'
  n8n_execution_id  text,                    -- n8n's execution ID for deep-link
  -- Timing
  started_at        timestamptz not null,
  completed_at      timestamptz,
  duration_ms       int generated always as (
    case when completed_at is not null
    then extract(epoch from (completed_at - started_at))::int * 1000
    else null end
  ) stored,
  -- Outcome
  status            text not null default 'running',
  -- 'running' | 'success' | 'partial' | 'failed'
  records_processed int default 0,
  records_errored   int default 0,
  -- What happened
  summary           text,                    -- e.g. "12 contracts checked, 2 renewals triggered"
  error_message     text,
  error_node        text,                    -- which n8n node failed
  -- Context (for alerting logic)
  branch_id         uuid references branches(id),  -- null = org-wide workflow
  created_at        timestamptz default now()
);

create index idx_workflow_runs_name   on workflow_runs(workflow_name, started_at desc);
create index idx_workflow_runs_status on workflow_runs(status) where status in ('running', 'failed');

-- RLS for workflow monitoring
alter table workflow_runs enable row level security;
do $$
begin
  if not exists (
    select 1 from information_schema.schemata where schema_name = 'auth'
  ) then
    execute 'create policy "app_role_all" on workflow_runs
      for all to truespend using (true) with check (true)';
  end if;
end $$;
