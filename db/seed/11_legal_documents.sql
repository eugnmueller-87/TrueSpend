-- TrueSpend Seed — Legal Documents (NDA + DPA per key supplier)
-- Live DB columns: id, supplier_id, doc_type (text), content (text), status (text), created_at

insert into legal_documents (id, supplier_id, doc_type, status, content, created_at) values

-- ── Dell Technologies ──────────────────────────────────────────────────────────
('d1100001-0000-0000-0000-000000000001',
 'f1000000-0000-0000-0000-000000000001', 'nda', 'signed',
 'Mutual NDA — TrueSpend GmbH & Dell Technologies GmbH | German law | Signed | Expires 2027-07-11 | Covers hardware procurement discussions, technical specs, and volume pricing. Confidentiality period: 3 years.',
 now() - interval '2 years'),

('d1100001-0000-0000-0000-000000000002',
 'f1000000-0000-0000-0000-000000000001', 'dpa', 'signed',
 'Art. 28 GDPR DPA — TrueSpend GmbH (Controller) & Dell Technologies GmbH (Processor) | German law | Signed | Expires 2027-07-11 | Dell processes warranty and support data. ISO 27001 certified. EU data residency.',
 now() - interval '2 years'),

-- ── Microsoft 365 ─────────────────────────────────────────────────────────────
('d1100007-0000-0000-0000-000000000001',
 'f1000000-0000-0000-0000-000000000007', 'dpa', 'signed',
 'Microsoft GDPR Addendum (DPA) — TrueSpend GmbH & Microsoft Ireland Operations Ltd | Irish law (EU) | Signed | Expires 2027-08-06 | EU SCCs (2021) attached. EU data residency elected. Sub-processors at trust.microsoft.com.',
 now() - interval '18 months'),

-- ── AWS ───────────────────────────────────────────────────────────────────────
('d1100004-0000-0000-0000-000000000001',
 'f1000000-0000-0000-0000-000000000004', 'dpa', 'signed',
 'AWS GDPR Data Processing Addendum — TrueSpend GmbH & Amazon Web Services EMEA SARL | Luxembourg law | Signed | Expires 2027-11-26 | SCCs included. eu-central-1 (Frankfurt) data processing. AWS acts as processor for S3, RDS, Lambda.',
 now() - interval '3 years'),

-- ── Google Cloud ──────────────────────────────────────────────────────────────
('d1100005-0000-0000-0000-000000000001',
 'f1000000-0000-0000-0000-000000000005', 'dpa', 'signed',
 'Google Cloud DPST — TrueSpend GmbH & Google Cloud EMEA Limited | Irish law (EU) | Signed | Expires 2027-10-26 | EU SCCs 2021. EU processing region. Sub-processor: Google LLC (infrastructure).',
 now() - interval '14 months'),

-- ── SAP ───────────────────────────────────────────────────────────────────────
('d1100009-0000-0000-0000-000000000001',
 'f1000000-0000-0000-0000-000000000009', 'nda', 'signed',
 'Bilateral NDA — TrueSpend GmbH & SAP SE | German law | Signed | Expires 2027-07-12 | Covers S/4HANA roadmap, implementation specs, custom development, and pricing.',
 now() - interval '3 years'),

('d1100009-0000-0000-0000-000000000002',
 'f1000000-0000-0000-0000-000000000009', 'dpa', 'signed',
 'Art. 28 GDPR DPA — TrueSpend GmbH & SAP SE | German law | Signed | Expires 2027-07-12 | SAP processes HR and Finance data via S/4HANA Cloud. EU data centers only. ISO 27001 + SOC 2 Type II.',
 now() - interval '2 years'),

-- ── Salesforce ────────────────────────────────────────────────────────────────
('d1100008-0000-0000-0000-000000000001',
 'f1000000-0000-0000-0000-000000000008', 'dpa', 'signed',
 'Salesforce DPA — TrueSpend GmbH & Salesforce EMEA Ltd | Irish law (EU) | Signed | Expires 2026-06-30 ⚠ Expiring soon | EU SCCs 2021. Hyperforce EU. Sub-processors: Salesforce Sub-Processor Directory.',
 now() - interval '20 months'),

-- ── Accenture ─────────────────────────────────────────────────────────────────
('d1100013-0000-0000-0000-000000000001',
 'f1000000-0000-0000-0000-000000000013', 'nda', 'signed',
 'NDA — TrueSpend GmbH & Accenture GmbH | German law | Signed | Expires 2026-07-14 ⚠ Expiring soon | Covers internal process docs, system architecture, and strategic roadmap shared during transformation project.',
 now() - interval '11 months'),

('d1100013-0000-0000-0000-000000000002',
 'f1000000-0000-0000-0000-000000000013', 'dpa', 'signed',
 'Art. 28 GDPR DPA — TrueSpend GmbH & Accenture GmbH | German law | Signed | Expires 2026-07-14 ⚠ Expiring soon | Accenture processes employee and process data during transformation. ISO 27001 certified.',
 now() - interval '10 months'),

-- ── Apple ─────────────────────────────────────────────────────────────────────
('d1100003-0000-0000-0000-000000000001',
 'f1000000-0000-0000-0000-000000000003', 'nda', 'signed',
 'Apple Standard Vendor NDA — TrueSpend GmbH & Apple Distribution International Ltd | Irish law (EU) | Signed | Expired 2026-05-28 ❌ | Covers device roadmap, volume pricing, beta program participation. RENEWAL REQUIRED.',
 now() - interval '2 years'),

('d1100003-0000-0000-0000-000000000002',
 'f1000000-0000-0000-0000-000000000003', 'dpa', 'draft',
 'DPA DRAFT — TrueSpend GmbH & Apple Distribution International Ltd | Irish law (EU) | Status: Under legal review | Apple MDM and device management processes employee device identifiers. SCCs required for transfers to Apple Inc. (US). Awaiting Apple legal response.',
 now() - interval '3 days'),

-- ── Workday ───────────────────────────────────────────────────────────────────
('d1100010-0000-0000-0000-000000000001',
 'f1000000-0000-0000-0000-000000000010', 'dpa', 'signed',
 'Workday GDPR DPA — TrueSpend GmbH & Workday Software Ltd | Irish law (EU) | Signed | Expires 2027-08-11 | HCM + Finance modules. EU data center (Dublin + Amsterdam). Sub-processors: AWS, Google (infrastructure). SOC 2 Type II.',
 now() - interval '22 months'),

-- ── Lenovo ────────────────────────────────────────────────────────────────────
('d1100002-0000-0000-0000-000000000001',
 'f1000000-0000-0000-0000-000000000002', 'nda', 'signed',
 'Mutual NDA — TrueSpend GmbH & Lenovo Germany GmbH | German law | Signed | Expires 2027-07-31 | Device fleet procurement. Covers volume pricing, product roadmap, beta device program.',
 now() - interval '2 years'),

-- ── Microsoft Azure ───────────────────────────────────────────────────────────
('d1100006-0000-0000-0000-000000000001',
 'f1000000-0000-0000-0000-000000000006', 'dpa', 'signed',
 'Microsoft Azure DPA — TrueSpend GmbH & Microsoft Ireland Operations Ltd | Irish law (EU) | Signed | Expires 2027-12-06 | Same Microsoft GDPR Addendum. Azure Reserved Instances. EU region (West Europe). 2021 SCCs.',
 now() - interval '16 months')

on conflict (id) do update set
  status  = excluded.status,
  content = excluded.content;
