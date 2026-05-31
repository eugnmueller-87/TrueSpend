-- =============================================================================
-- TrueSpend RAG Layer — pgvector Schema
-- Apply to Railway PostgreSQL after enabling pgvector extension
-- =============================================================================

-- Enable pgvector extension (requires Railway PostgreSQL with pgvector support)
create extension if not exists vector;

-- =============================================================================
-- DOCUMENT EMBEDDINGS TABLE
-- Stores vector embeddings for semantic search across all document types
-- Embedding model: text-embedding-3-small (OpenAI, 1536 dims)
--                  or voyage-3 (Anthropic recommended, 1024 dims)
-- We use 1536 for OpenAI text-embedding-3-small compatibility
-- =============================================================================

create table if not exists document_embeddings (
  id              uuid primary key default uuid_generate_v4(),
  -- Source document reference (one of these will be set)
  doc_type        text not null,  -- 'legal_document' | 'contract' | 'compliance_check' | 'policy' | 'supplier'
  source_id       uuid not null,  -- FK to the source table (legal_documents.id, contracts.id, etc.)
  supplier_id     uuid references suppliers(id) on delete cascade,
  -- The text chunk that was embedded (max ~8k tokens per chunk)
  chunk_index     int  not null default 0,  -- for multi-chunk docs
  chunk_text      text not null,
  -- The embedding vector
  embedding       vector(1536),
  -- Search metadata (stored for filtering, no extra join needed)
  meta_title      text,   -- contract name, NDA title, policy name
  meta_category   text,   -- hardware, saas_license, etc.
  meta_status     text,   -- signed, draft, expired, etc.
  meta_tags       text[],  -- ['gdpr', 'nda', 'expiring'] etc.
  -- Timestamps
  created_at      timestamptz default now(),
  indexed_at      timestamptz default now()
);

-- HNSW index for fast ANN search (cosine similarity)
-- Better for semantic search than IVFFlat — no training needed
create index if not exists idx_doc_embeddings_vector
  on document_embeddings using hnsw (embedding vector_cosine_ops)
  with (m = 16, ef_construction = 64);

-- Filtering indexes
create index if not exists idx_doc_embeddings_doc_type   on document_embeddings(doc_type);
create index if not exists idx_doc_embeddings_supplier   on document_embeddings(supplier_id);
create index if not exists idx_doc_embeddings_source     on document_embeddings(source_id);

-- =============================================================================
-- POLICY DOCUMENTS TABLE
-- Stores procurement policy text for Q&A ("can I approve this without CFO?")
-- =============================================================================

create table if not exists rag_policies (
  id          uuid primary key default uuid_generate_v4(),
  title       text not null,
  category    text not null,  -- 'spend_authority' | 'approval_thresholds' | 'supplier_policy' | 'gdpr' | 'general'
  content     text not null,
  version     text not null default '1.0',
  effective   date not null default current_date,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

-- =============================================================================
-- SEARCH LOG TABLE (for analytics + relevance feedback)
-- =============================================================================

create table if not exists rag_search_log (
  id          uuid primary key default uuid_generate_v4(),
  query_text  text not null,
  doc_type    text,
  result_ids  uuid[],     -- top-k returned IDs
  user_email  text,
  clicked_id  uuid,       -- which result did the user click?
  created_at  timestamptz default now()
);

-- =============================================================================
-- SEARCH FUNCTION — semantic similarity search
-- Called via PostgREST: POST /rpc/search_documents
-- Parameters:
--   query_embedding vector(1536) — the embedded query
--   filter_doc_type text         — optional: 'contract', 'legal_document', etc.
--   filter_supplier uuid         — optional: restrict to one supplier
--   result_limit    int          — default 10
-- =============================================================================

create or replace function search_documents(
  query_embedding  vector(1536),
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
    de.id,
    de.doc_type,
    de.source_id,
    de.supplier_id,
    de.chunk_text,
    de.meta_title,
    de.meta_category,
    de.meta_status,
    de.meta_tags,
    1 - (de.embedding <=> query_embedding) as similarity
  from document_embeddings de
  where
    (filter_doc_type is null or de.doc_type = filter_doc_type)
    and (filter_supplier is null or de.supplier_id = filter_supplier)
    and de.embedding is not null
  order by de.embedding <=> query_embedding
  limit result_limit;
$$;

-- =============================================================================
-- KEYWORD FALLBACK SEARCH (for when no embedding is available — e.g. UI typeahead)
-- Called via PostgREST: POST /rpc/search_documents_text
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
    ) as rank
  from document_embeddings de
  where
    (filter_doc_type is null or de.doc_type = filter_doc_type)
    and (filter_supplier is null or de.supplier_id = filter_supplier)
    and to_tsvector('english', de.chunk_text || ' ' || coalesce(de.meta_title,'') || ' ' || coalesce(de.meta_category,''))
        @@ plainto_tsquery('english', query_text)
  order by rank desc
  limit result_limit;
$$;

-- Full-text index for keyword fallback
create index if not exists idx_doc_embeddings_fts
  on document_embeddings
  using gin(to_tsvector('english', chunk_text || ' ' || coalesce(meta_title,'') || ' ' || coalesce(meta_category,'')));

-- =============================================================================
-- POLICY SEED DATA — core procurement policies for Q&A
-- =============================================================================

insert into rag_policies (id, title, category, content, version, effective) values

('a0000000-0000-0000-0000-000000000001',
 'Spend Authority Thresholds',
 'spend_authority',
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
- No spend authority is valid without an active budget bucket for the category.

MULTI-TRANSACTION RULE:
- Splitting a single purchase into multiple transactions to circumvent limits is prohibited.
- Agent flags purchase pattern anomalies automatically.', '3.2', '2026-01-01'),

('a0000000-0000-0000-0000-000000000002',
 'Supplier Approval Policy',
 'supplier_policy',
 'TrueSpend Supplier Approval Policy v2.1 (effective 2026-01-01)

MINIMUM REQUIREMENTS FOR NEW SUPPLIERS:
1. Compliance status must be "green" before any purchase can be committed.
2. NDA required for: any supplier where proprietary information will be shared (pricing, roadmaps, architecture).
3. DPA required for: any supplier that will process personal data on behalf of TrueSpend (GDPR Art. 28).
4. LkSG declaration required for: any supplier with direct manufacturing or labour-intensive services, contract value >€5M annually.
5. COC (Code of Conduct) required for: all suppliers in services category.

GDPR DATA PROCESSING:
- All new SaaS and cloud suppliers must sign the TrueSpend standard DPA before go-live.
- EU data residency is the default requirement. Exceptions require CISO approval.
- Standard Contractual Clauses (2021) are required for any transfer outside the EEA.
- No adequacy decision exists for: USA, Canada (except specific cases), Israel, India, China, Brazil.

SUPPLIER HEALTH ESCALATION:
- Green: normal operations.
- Watch: procurement team notified. Monthly review cadence.
- Red: no new purchase orders. Escalation to Head of Procurement and CFO within 24 hours.

COMPLIANCE AMBER RULES:
- Amber: can continue existing contracts but no new commitments until issue resolved.
- Amber DPA: new data processing scope requires DPA update before proceeding.
- Amber LkSG: declaration required within 60 days or supplier moved to "red".', '2.1', '2026-01-01'),

('a0000000-0000-0000-0000-000000000003',
 'Contract Renewal Policy',
 'approval_thresholds',
 'TrueSpend Contract Renewal Policy v2.0 (effective 2026-01-01)

AUTOMATIC RENEWAL (auto_execute):
- Contracts with renewal_state = "clean" AND value <€500,000 AND compliance_status = "green": agent auto-renews.
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
- New data processing scope: CISO review required, Jira ticket.

NOTICE PERIODS:
- Standard: 30 days before expiry.
- Strategic contracts: 60 or 90 days (as specified in contract).
- Agent sends notice to supplier upon auto-renew confirmation.
- If no action by notice deadline: escalate to Head of Procurement immediately.

RENEGOTIATION TRIGGERS:
- CPI increase >5% proposed: trigger benchmarking analysis before acceptance.
- Volume increase crossing tier threshold: renegotiate pricing tier.
- New competitor pricing available: trigger bench review clause if present.', '2.0', '2026-01-01'),

('a0000000-0000-0000-0000-000000000004',
 'GDPR & Data Protection Policy',
 'gdpr',
 'TrueSpend Data Protection Policy v1.5 (effective 2026-01-01)

BASIS FOR PROCESSING:
- All personal data processing by TrueSpend must have a lawful basis under GDPR Art. 6.
- Employee data: contract performance (Art. 6(1)(b)) or legitimate interest (Art. 6(1)(f)).
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

DATA SUBJECT RIGHTS:
- Right of access (SARs): 30-day response target.
- Right to erasure: 72-hour acknowledgement, 30-day completion.
- Data portability: provide machine-readable export on request.

BREACH NOTIFICATION:
- Internal: CISO notified within 1 hour of discovery.
- DPA authority (BfDI in Germany): within 72 hours if risk to individuals.
- Individuals: without undue delay if high risk.', '1.5', '2026-01-01'),

('a0000000-0000-0000-0000-000000000005',
 'AI & LLM Consumption Policy',
 'general',
 'TrueSpend AI Consumption Policy v1.0 (effective 2026-01-01)

APPROVED AI PROVIDERS:
- Anthropic (Claude API): approved. Zero-data-training for commercial API. DPA signed.
- OpenAI (GPT-4o API): approved. ZDR policy elected. DPA signed.
- Mistral AI: approved. EU-native, CNIL registered, no third-country transfers.
- Google Vertex AI: approved for GCP committed spend customers. DPA under Microsoft GDPR Addendum.

RESTRICTED PROVIDERS (pending compliance sign-off):
- Cohere: DPA pending — no new production use cases until DPA signed.
- Stability AI: financial stability concerns — procurement monitoring.

PROHIBITED:
- No personal data (employee data, customer data, financial data) in prompts to any LLM.
- No confidential contract terms or M&A information in prompts unless using on-premise or private deployment.
- No prompt injection testing on production systems.

BUDGET TRACKING:
- All LLM API keys registered in llm_api_keys table.
- Daily consumption tracked via llm_consumption workflow (automated).
- Anomaly threshold: >3× 7-day rolling average triggers alert ticket.
- Monthly chargeback to branch budget bucket (category: other/ai_consumption).

APPROVAL THRESHOLDS FOR AI TOOLS:
- New AI SaaS tool <€25,000/year: IT Manager approval.
- New AI SaaS tool €25,000–€100,000/year: Head of Procurement approval.
- New AI SaaS tool >€100,000/year: CFO approval + Jira PROC ticket.
- Any AI tool processing employee or HR data: CISO review required regardless of value.

LLM DATA GOVERNANCE:
- Prompt logs must not be retained longer than 30 days.
- All AI-generated documents must be reviewed by a human before external use.
- Agent reasoning traces stored in trace_log — internal only, not shared externally.', '1.0', '2026-01-01')

on conflict (id) do update set
  content    = excluded.content,
  updated_at = now();

-- Grant access to truespend role
grant select on document_embeddings to truespend;
grant select, insert, update on document_embeddings to truespend;
grant select on rag_policies to truespend;
grant select, insert, update on rag_search_log to truespend;
grant execute on function search_documents to truespend;
grant execute on function search_documents_text to truespend;
