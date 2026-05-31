-- =============================================================================
-- TrueSpend RAG Layer — Fallback Schema (no pgvector extension required)
-- Uses text column for embeddings (stored as JSON array string)
-- Full-text search via PostgreSQL tsvector — works without pgvector
-- When pgvector becomes available on Railway, run rag_schema.sql to migrate
-- =============================================================================

-- =============================================================================
-- DOCUMENT EMBEDDINGS TABLE (pgvector-free version)
-- embedding stored as text (JSON array) — not searchable by cosine similarity
-- but full-text search via search_documents_text() works fully
-- =============================================================================

create table if not exists document_embeddings (
  id              uuid primary key default uuid_generate_v4(),
  doc_type        text not null,
  source_id       uuid not null,
  supplier_id     uuid references suppliers(id) on delete cascade,
  chunk_index     int  not null default 0,
  chunk_text      text not null,
  embedding       text,   -- JSON array string e.g. "[0.12, -0.34, ...]" — upgrade to vector(1536) when pgvector available
  meta_title      text,
  meta_category   text,
  meta_status     text,
  meta_tags       text[],
  created_at      timestamptz default now(),
  indexed_at      timestamptz default now()
);

-- Filtering indexes
create index if not exists idx_doc_embeddings_doc_type   on document_embeddings(doc_type);
create index if not exists idx_doc_embeddings_supplier   on document_embeddings(supplier_id);
create index if not exists idx_doc_embeddings_source     on document_embeddings(source_id);

-- Full-text search index
create index if not exists idx_doc_embeddings_fts
  on document_embeddings
  using gin(to_tsvector('english', chunk_text || ' ' || coalesce(meta_title,'') || ' ' || coalesce(meta_category,'')));

-- =============================================================================
-- POLICY DOCUMENTS TABLE
-- =============================================================================

create table if not exists rag_policies (
  id          uuid primary key default uuid_generate_v4(),
  title       text not null,
  category    text not null,
  content     text not null,
  version     text not null default '1.0',
  effective   date not null default current_date,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

-- =============================================================================
-- SEARCH LOG TABLE
-- =============================================================================

create table if not exists rag_search_log (
  id          uuid primary key default uuid_generate_v4(),
  query_text  text not null,
  doc_type    text,
  result_ids  uuid[],
  user_email  text,
  clicked_id  uuid,
  created_at  timestamptz default now()
);

-- =============================================================================
-- FULL-TEXT SEARCH FUNCTION (works without pgvector)
-- =============================================================================

create or replace function search_documents_text(
  query_text      text,
  filter_doc_type text default null,
  filter_supplier uuid default null,
  result_limit    int  default 10
)
returns table (
  id           uuid,
  doc_type     text,
  source_id    uuid,
  supplier_id  uuid,
  chunk_text   text,
  meta_title   text,
  meta_category text,
  meta_status  text,
  meta_tags    text[],
  rank         float
)
language sql stable
as $$
  select
    de.id,
    de.doc_type,
    de.source_id,
    de.supplier_id,
    de.chunk_text,
    de.meta_title,
    de.meta_category,
    de.meta_status,
    de.meta_tags,
    ts_rank(
      to_tsvector('english', de.chunk_text || ' ' || coalesce(de.meta_title,'') || ' ' || coalesce(de.meta_category,'')),
      plainto_tsquery('english', query_text)
    )::float as rank
  from document_embeddings de
  where
    (filter_doc_type is null or de.doc_type = filter_doc_type)
    and (filter_supplier is null or de.supplier_id = filter_supplier)
    and to_tsvector('english', de.chunk_text || ' ' || coalesce(de.meta_title,'') || ' ' || coalesce(de.meta_category,''))
        @@ plainto_tsquery('english', query_text)
  order by rank desc
  limit result_limit;
$$;

-- Stub for semantic search (returns empty until pgvector available)
-- When pgvector is available, drop and recreate from rag_schema.sql
create or replace function search_documents(
  query_embedding  text,     -- text placeholder until vector type available
  filter_doc_type  text    default null,
  filter_supplier  uuid    default null,
  result_limit     int     default 10
)
returns table (
  id           uuid,
  doc_type     text,
  source_id    uuid,
  supplier_id  uuid,
  chunk_text   text,
  meta_title   text,
  meta_category text,
  meta_status  text,
  meta_tags    text[],
  similarity   float
)
language sql stable
as $$
  select
    de.id, de.doc_type, de.source_id, de.supplier_id,
    de.chunk_text, de.meta_title, de.meta_category, de.meta_status, de.meta_tags,
    0.0::float as similarity
  from document_embeddings de
  where false;  -- stub: returns empty until pgvector available
$$;

-- =============================================================================
-- GRANT ACCESS
-- =============================================================================

grant select, insert, update on document_embeddings to truespend;
grant select on rag_policies to truespend;
grant select, insert, update on rag_search_log to truespend;
grant execute on function search_documents_text to truespend;
grant execute on function search_documents to truespend;

-- =============================================================================
-- POLICY SEED DATA
-- =============================================================================

insert into rag_policies (id, title, category, content, version, effective) values

('a0000000-0000-0000-0000-000000000001',
 'Spend Authority Thresholds', 'spend_authority',
 'TrueSpend Spend Authority Policy v3.2 (effective 2026-01-01)

APPROVAL THRESHOLDS BY ROLE:
- Requester: €0 — no approval authority. All requests go to Operations Board.
- IT Manager: up to €50,000 per transaction for saas_license, ai_consumption, hardware in DACH branch only.
- Ops Manager / Category Manager: up to €100,000 per transaction across all categories.
- Head of Procurement: up to €500,000 per transaction. All categories, DACH + UK + HQ.
- CFO: unlimited authority. Pool draw authority across all branches.

ESCALATION RULES:
- Any single transaction ≥€100,000: Jira ticket created. Head of Procurement notified.
- Any single transaction ≥€500,000: CFO approval required. Board must be informed.
- Any hyperscaler commitment ≥€1,000,000: Jira + CFO review required.
- Contract renewals with price increase >10%: must be escalated regardless of value.

BUDGET PRE-CHECK:
- Agent checks three tiers: category bucket → branch annual → manager authority.
- If committed + new request > budget bucket: escalate to CFO pool draw.
- No spend authority is valid without an active budget bucket for the category.', '3.2', '2026-01-01'),

('a0000000-0000-0000-0000-000000000002',
 'Supplier Approval Policy', 'supplier_policy',
 'TrueSpend Supplier Approval Policy v2.1 (effective 2026-01-01)

MINIMUM REQUIREMENTS FOR NEW SUPPLIERS:
1. Compliance status must be green before any purchase can be committed.
2. NDA required for: any supplier where proprietary information will be shared.
3. DPA required for: any supplier that will process personal data on behalf of TrueSpend.
4. LkSG declaration required for: suppliers with direct manufacturing, contract value >€5M annually.
5. COC required for: all suppliers in services category.

GDPR DATA PROCESSING:
- All new SaaS and cloud suppliers must sign TrueSpend standard DPA before go-live.
- EU data residency is the default requirement. Exceptions require CISO approval.
- Standard Contractual Clauses (2021) required for any transfer outside the EEA.
- No adequacy decision exists for: USA, Canada (except specific cases), Israel, India, China, Brazil.

SUPPLIER HEALTH ESCALATION:
- Green: normal operations.
- Watch: procurement team notified. Monthly review cadence.
- Red: no new purchase orders. Escalation to Head of Procurement and CFO within 24 hours.

COMPLIANCE AMBER RULES:
- Amber: can continue existing contracts but no new commitments until issue resolved.
- Amber DPA: new data processing scope requires DPA update before proceeding.
- Amber LkSG: declaration required within 60 days or supplier moved to red.', '2.1', '2026-01-01'),

('a0000000-0000-0000-0000-000000000003',
 'Contract Renewal Policy', 'approval_thresholds',
 'TrueSpend Contract Renewal Policy v2.0 (effective 2026-01-01)

AUTOMATIC RENEWAL (auto_execute):
- Contracts with renewal_state = clean AND value <€500,000 AND compliance_status = green: agent auto-renews.
- Alert sent to contract owner at 90, 60, and 30 days before expiry.

ONE-TOUCH RENEWAL (pending_confirm on Operations Board):
- Price increase ≤10% AND contract value <€250,000: one-touch approval by Category Manager.
- Volume change ≤20%: one-touch approval.
- Scope change (minor, no new data categories): one-touch approval.

ESCALATION TO JIRA:
- Price increase >10%: escalate to Head of Procurement.
- Contract value ≥€500,000: escalate regardless of renewal state.
- manual_required state: always escalate to Jira PROC project.
- Compliance issues (amber/red): block renewal, escalate to Jira.

NOTICE PERIODS:
- Standard: 30 days before expiry.
- Strategic contracts: 60 or 90 days as specified in contract.
- Agent sends notice to supplier upon auto-renew confirmation.
- If no action by notice deadline: escalate to Head of Procurement immediately.', '2.0', '2026-01-01'),

('a0000000-0000-0000-0000-000000000004',
 'GDPR & Data Protection Policy', 'gdpr',
 'TrueSpend Data Protection Policy v1.5 (effective 2026-01-01)

BASIS FOR PROCESSING:
- All personal data processing by TrueSpend must have a lawful basis under GDPR Art. 6.
- Employee data: contract performance Art. 6(1)(b) or legitimate interest Art. 6(1)(f).
- Customer data: consent or contract.
- Supplier contact data: legitimate interest.

DATA RESIDENCY STANDARD:
- All personal data must be processed within the EEA by default.
- US transfers: require EU-US DPF participation OR 2021 SCCs.
- Other third countries: require either adequacy decision OR 2021 SCCs with TIA.
- No transfer to China, Russia, or Belarus under any circumstances.

DPA REQUIREMENTS:
- Any supplier acting as data processor must sign TrueSpend standard Art. 28 DPA.
- DPA must be in place BEFORE any personal data is shared.
- DPA must specify: data categories, processing purposes, retention periods, sub-processor list.
- DPA must include TOM Annex (Annex 2) with technical and organisational measures.

DPIA TRIGGERS:
- New technology processing sensitive data (health, biometric, financial).
- Large-scale employee monitoring.
- New AI/ML systems processing personal data.
- Any cloud migration involving personal data.

BREACH NOTIFICATION:
- Internal: CISO notified within 1 hour of discovery.
- DPA authority (BfDI in Germany): within 72 hours if risk to individuals.
- Individuals: without undue delay if high risk.', '1.5', '2026-01-01'),

('a0000000-0000-0000-0000-000000000005',
 'AI & LLM Consumption Policy', 'general',
 'TrueSpend AI Consumption Policy v1.0 (effective 2026-01-01)

APPROVED AI PROVIDERS:
- Anthropic (Claude API): approved. Zero-data-training for commercial API. DPA signed.
- OpenAI (GPT-4o API): approved. ZDR policy elected. DPA signed.
- Mistral AI: approved. EU-native, CNIL registered, no third-country transfers.
- Google Vertex AI: approved for GCP committed spend customers.

RESTRICTED PROVIDERS (pending compliance sign-off):
- Cohere: DPA pending — no new production use cases until DPA signed.
- Stability AI: financial stability concerns — procurement monitoring.

PROHIBITED:
- No personal data (employee data, customer data, financial data) in prompts to any LLM.
- No confidential contract terms or M&A information in prompts unless using on-premise deployment.
- No prompt injection testing on production systems.

BUDGET TRACKING:
- All LLM API keys registered in llm_api_keys table.
- Daily consumption tracked via llm_consumption workflow (automated).
- Anomaly threshold: >3x 7-day rolling average triggers alert ticket.
- Monthly chargeback to branch budget bucket (category: other/ai_consumption).

APPROVAL THRESHOLDS FOR AI TOOLS:
- New AI SaaS tool <€25,000/year: IT Manager approval.
- New AI SaaS tool €25,000 to €100,000/year: Head of Procurement approval.
- New AI SaaS tool >€100,000/year: CFO approval + Jira PROC ticket.
- Any AI tool processing employee or HR data: CISO review required regardless of value.', '1.0', '2026-01-01')

on conflict (id) do update set
  content    = excluded.content,
  updated_at = now();

-- =============================================================================
-- SEED document_embeddings with full-text-searchable entries from legal_documents
-- (No actual vector embeddings — just text chunks for keyword search)
-- =============================================================================

insert into document_embeddings (doc_type, source_id, supplier_id, chunk_index, chunk_text, meta_title, meta_category, meta_status, meta_tags)
select
  'legal_document'          as doc_type,
  ld.id                     as source_id,
  ld.supplier_id,
  0                         as chunk_index,
  ld.content                as chunk_text,
  s.name || ' — ' || ld.doc_type  as meta_title,
  ld.doc_type               as meta_category,
  ld.status                 as meta_status,
  ARRAY[ld.doc_type, ld.status, s.category]  as meta_tags
from legal_documents ld
join suppliers s on s.id = ld.supplier_id
where ld.content is not null and length(ld.content) > 10
on conflict do nothing;

insert into document_embeddings (doc_type, source_id, supplier_id, chunk_index, chunk_text, meta_title, meta_category, meta_status, meta_tags)
select
  'contract'              as doc_type,
  c.id                    as source_id,
  c.supplier_id,
  0                       as chunk_index,
  c.name || '. Category: ' || c.category::text || '. Value: ' || c.value::text || ' ' || c.currency || '. Expiry: ' || c.expiry_date::text || '. Renewal state: ' || c.renewal_state::text || '. Terms: ' || coalesce(c.terms_summary, '')   as chunk_text,
  c.name                  as meta_title,
  c.category::text        as meta_category,
  c.renewal_state::text   as meta_status,
  ARRAY[c.category::text, c.renewal_state::text, c.currency]  as meta_tags
from contracts c
where c.terms_summary is not null
on conflict do nothing;

insert into document_embeddings (doc_type, source_id, supplier_id, chunk_index, chunk_text, meta_title, meta_category, meta_status, meta_tags)
select
  'policy'        as doc_type,
  p.id            as source_id,
  null            as supplier_id,
  0               as chunk_index,
  p.title || '. ' || p.content    as chunk_text,
  p.title         as meta_title,
  p.category      as meta_category,
  'active'        as meta_status,
  ARRAY[p.category, 'policy']     as meta_tags
from rag_policies p
on conflict do nothing;
