-- RAG data seeding — run AFTER all source tables are populated
-- Populates: rag_policies, document_embeddings (from legal_documents + contracts)

-- ─── Policies ────────────────────────────────────────────────────────────────
insert into rag_policies (id, title, category, content, version, effective) values

('a0000000-0000-0000-0000-000000000001',
 'Spend Authority Thresholds', 'spend_authority',
 'TrueSpend Spend Authority Policy v3.2 (effective 2026-01-01)

APPROVAL THRESHOLDS BY ROLE:
- Requester: 0 EUR. No approval authority. All requests go to Operations Board.
- IT Manager: up to 50000 EUR per transaction for saas_license, ai_consumption, hardware in DACH branch only.
- Ops Manager and Category Manager: up to 100000 EUR per transaction across all categories.
- Head of Procurement: up to 500000 EUR per transaction. All categories, DACH plus UK plus HQ.
- CFO: unlimited authority. Pool draw authority across all branches.

ESCALATION RULES:
- Any single transaction 100000 EUR or more: Jira ticket created. Head of Procurement notified.
- Any single transaction 500000 EUR or more: CFO approval required. Board must be informed.
- Any hyperscaler commitment 1000000 EUR or more: Jira plus CFO review required.
- Contract renewals with price increase over 10 percent: must be escalated regardless of value.

BUDGET PRE-CHECK:
- Agent checks three tiers: category bucket then branch annual then manager authority.
- If committed plus new request exceeds budget bucket: escalate to CFO pool draw.
- No spend authority is valid without an active budget bucket for the category.', '3.2', '2026-01-01'),

('a0000000-0000-0000-0000-000000000002',
 'Supplier Approval Policy', 'supplier_policy',
 'TrueSpend Supplier Approval Policy v2.1 (effective 2026-01-01)

MINIMUM REQUIREMENTS FOR NEW SUPPLIERS:
1. Compliance status must be green before any purchase can be committed.
2. NDA required for: any supplier where proprietary information will be shared (pricing, roadmaps, architecture).
3. DPA required for: any supplier that will process personal data on behalf of TrueSpend (GDPR Art. 28).
4. LkSG declaration required for: any supplier with direct manufacturing or labour-intensive services, contract value over 5M EUR annually.
5. COC required for: all suppliers in services category.

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
- Amber LkSG: declaration required within 60 days or supplier moved to red.', '2.1', '2026-01-01'),

('a0000000-0000-0000-0000-000000000003',
 'Contract Renewal Policy', 'approval_thresholds',
 'TrueSpend Contract Renewal Policy v2.0 (effective 2026-01-01)

AUTOMATIC RENEWAL (auto_execute):
- Contracts with renewal_state clean AND value under 500000 EUR AND compliance_status green: agent auto-renews.
- Alert sent to contract owner at 90, 60, and 30 days before expiry.

ONE-TOUCH RENEWAL (pending_confirm on Operations Board):
- Price increase 10 percent or less AND contract value under 250000 EUR: one-touch approval by Category Manager.
- Volume change 20 percent or less: one-touch approval.
- Scope change (minor, no new data categories): one-touch approval.

ESCALATION TO JIRA:
- Price increase over 10 percent: escalate to Head of Procurement.
- Contract value 500000 EUR or more: escalate regardless of renewal state.
- manual_required state: always escalate to Jira PROC project.
- Compliance issues (amber/red): block renewal, escalate to Jira.

NOTICE PERIODS:
- Standard: 30 days before expiry.
- Strategic contracts: 60 or 90 days as specified in contract.
- Agent sends notice to supplier upon auto-renew confirmation.
- If no action by notice deadline: escalate to Head of Procurement immediately.', '2.0', '2026-01-01'),

('a0000000-0000-0000-0000-000000000004',
 'GDPR and Data Protection Policy', 'gdpr',
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
- Any supplier acting as data processor must sign TrueSpend standard Art. 28 DPA before go-live.
- DPA must specify: data categories, processing purposes, retention periods, sub-processor list.
- DPA must include TOM Annex (Annex 2) with technical and organisational measures.

DPIA TRIGGERS:
- New technology processing sensitive data (health, biometric, financial).
- Large-scale employee monitoring.
- New AI and ML systems processing personal data.
- Any cloud migration involving personal data.

BREACH NOTIFICATION:
- Internal: CISO notified within 1 hour of discovery.
- German supervisory authority BfDI: within 72 hours if risk to individuals.
- Individuals: without undue delay if high risk.', '1.5', '2026-01-01'),

('a0000000-0000-0000-0000-000000000005',
 'AI and LLM Consumption Policy', 'general',
 'TrueSpend AI Consumption Policy v1.0 (effective 2026-01-01)

APPROVED AI PROVIDERS:
- Anthropic (Claude API): approved. Zero-data-training for commercial API. DPA signed.
- OpenAI (GPT-4o API): approved. ZDR policy elected. DPA signed.
- Mistral AI: approved. EU-native, CNIL registered, no third-country transfers.
- Google Vertex AI: approved for GCP committed spend customers.

RESTRICTED PROVIDERS (pending compliance sign-off):
- Cohere: DPA pending. No new production use cases until DPA signed.
- Stability AI: financial stability concerns. Procurement monitoring.

PROHIBITED USE:
- No personal data (employee data, customer data, financial data) in prompts to any LLM.
- No confidential contract terms or M&A information in prompts unless using on-premise deployment.
- No prompt injection testing on production systems.

BUDGET TRACKING:
- All LLM API keys registered in llm_api_keys table.
- Daily consumption tracked via llm_consumption workflow (automated).
- Anomaly threshold: more than 3x 7-day rolling average triggers alert ticket.
- Monthly chargeback to branch budget bucket (category: other or ai_consumption).

APPROVAL THRESHOLDS FOR AI TOOLS:
- New AI SaaS tool under 25000 EUR per year: IT Manager approval.
- New AI SaaS tool 25000 to 100000 EUR per year: Head of Procurement approval.
- New AI SaaS tool over 100000 EUR per year: CFO approval plus Jira PROC ticket.
- Any AI tool processing employee or HR data: CISO review required regardless of value.', '1.0', '2026-01-01')

on conflict (id) do update set content = excluded.content, updated_at = now();

-- ─── Seed document_embeddings from legal_documents ────────────────────────────
insert into document_embeddings (doc_type, source_id, supplier_id, chunk_index, chunk_text, meta_title, meta_category, meta_status, meta_tags)
select
  'legal_document',
  ld.id,
  ld.supplier_id,
  0,
  ld.content,
  s.name || ' - ' || ld.doc_type,
  ld.doc_type,
  ld.status,
  ARRAY[ld.doc_type, ld.status, s.category::text]
from legal_documents ld
join suppliers s on s.id = ld.supplier_id
where ld.content is not null and length(ld.content) > 10
on conflict do nothing;

-- ─── Seed document_embeddings from contracts ──────────────────────────────────
insert into document_embeddings (doc_type, source_id, supplier_id, chunk_index, chunk_text, meta_title, meta_category, meta_status, meta_tags)
select
  'contract',
  c.id,
  c.supplier_id,
  0,
  c.name || '. Category: ' || c.category::text || '. Value: ' || c.value::text || ' ' || c.currency || '. Expiry: ' || c.expiry_date::text || '. Renewal state: ' || c.renewal_state::text || '. Terms: ' || coalesce(c.terms_summary, ''),
  c.name,
  c.category::text,
  c.renewal_state::text,
  ARRAY[c.category::text, c.renewal_state::text, c.currency]
from contracts c
where c.terms_summary is not null
on conflict do nothing;

-- ─── Seed document_embeddings from rag_policies ───────────────────────────────
insert into document_embeddings (doc_type, source_id, supplier_id, chunk_index, chunk_text, meta_title, meta_category, meta_status, meta_tags)
select
  'policy',
  p.id,
  null,
  0,
  p.title || '. ' || p.content,
  p.title,
  p.category,
  'active',
  ARRAY[p.category, 'policy']
from rag_policies p
on conflict do nothing;
