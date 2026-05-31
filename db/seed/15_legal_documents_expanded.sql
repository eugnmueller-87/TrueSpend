-- TrueSpend Seed — Expanded Legal Documents
-- NDA + DPA coverage for new suppliers (f2000000-... series)
-- Prioritises strategic, high-spend, and GDPR-sensitive suppliers
-- doc IDs: d2XXXXXX-0000-0000-0000-YYYYYYYYYYY (supplier prefix + seq)

insert into legal_documents (id, supplier_id, doc_type, status, content, created_at) values

-- ============================================================
-- HP INC.
-- ============================================================
('d2100001-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000001', 'nda', 'signed',
 'Mutual NDA — TrueSpend GmbH & HP Inc. Deutschland GmbH | German law | Signed 2024-08-01 | Expires 2026-08-01 | Covers hardware roadmap, volume pricing, exclusive beta program, warranty terms, and supply chain specifications. Confidentiality period: 3 years post-expiry. Governing court: Frankfurt am Main.',
 now() - interval '21 months'),

('d2100001-0000-0000-0000-000000000002',
 'f2000000-0000-0000-0000-000000000001', 'dpa', 'signed',
 'Art. 28 GDPR DPA — TrueSpend GmbH (Controller) & HP Inc. Deutschland GmbH (Processor) | German law | Signed 2024-08-01 | Expires 2026-08-01 | HP processes warranty registration data and support ticket data. EU data residency (Frankfurt). ISO 27001 certified. Sub-processors: HP Inc. (USA) — EU-US DPF framework applies. Data retention: 24 months post-warranty.',
 now() - interval '21 months'),

-- ============================================================
-- CISCO SYSTEMS
-- ============================================================
('d2100002-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000002', 'nda', 'signed',
 'Bilateral NDA — TrueSpend GmbH & Cisco Systems GmbH | German law | Signed 2024-10-01 | Expires 2028-10-01 | Covers Cisco network architecture, enterprise license agreement terms, Smart Licensing data, security vulnerability disclosures, and pricing matrices. 4-year term. Mutual obligations.',
 now() - interval '19 months'),

('d2100002-0000-0000-0000-000000000002',
 'f2000000-0000-0000-0000-000000000002', 'dpa', 'signed',
 'Art. 28 GDPR DPA — TrueSpend GmbH & Cisco Systems GmbH | German law | Signed 2024-10-01 | Expires 2028-10-01 | Cisco processes network telemetry and Smart Account data. Cisco Cloud Services data residency: EU (Amsterdam). ISO 27001, SOC 2 Type II. Sub-processors: Cisco Systems Inc. (USA) — EU-US DPF. CIAM integration for TAC support tickets.',
 now() - interval '19 months'),

-- ============================================================
-- SAMSUNG
-- ============================================================
('d2100003-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000003', 'nda', 'signed',
 'Standard Vendor NDA — TrueSpend GmbH & Samsung Electronics GmbH | German law | Signed 2025-01-15 | Expires 2027-01-15 | Covers device fleet roadmap, MDM integration specs, volume pricing tiers, beta device program. Samsung Knox Enterprise terms included.',
 now() - interval '16 months'),

('d2100003-0000-0000-0000-000000000002',
 'f2000000-0000-0000-0000-000000000003', 'dpa', 'signed',
 'Art. 28 GDPR DPA — TrueSpend GmbH & Samsung Electronics GmbH | German law | Signed 2025-01-15 | Expires 2027-01-15 | Samsung processes Knox MDM data, device identifiers, and enterprise app deployment logs. EU data residency (Dublin + Frankfurt). Samsung Knox Vault for key management. No transfer to Samsung HQ (Korea) without explicit SCCs.',
 now() - interval '16 months'),

-- ============================================================
-- FUJITSU
-- ============================================================
('d2100004-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000004', 'nda', 'signed',
 'Mutual NDA — TrueSpend GmbH & Fujitsu Technology Solutions GmbH | German law | Signed 2024-06-30 | Expires 2026-06-30 | Covers server infrastructure roadmap, PRIMERGY specifications, on-site maintenance procedures, datacenter access requirements.',
 now() - interval '23 months'),

('d2100004-0000-0000-0000-000000000002',
 'f2000000-0000-0000-0000-000000000004', 'dpa', 'signed',
 'Art. 28 GDPR DPA — TrueSpend GmbH & Fujitsu Technology Solutions GmbH | German law | Signed 2024-06-30 | Expires 2026-06-30 ⚠ Expiring — renewal required | Fujitsu processes hardware diagnostics and support data. EU processing only. ISO 27001. Note: Fujitsu undergoing corporate restructuring — new legal entity must be confirmed at renewal.',
 now() - interval '23 months'),

-- ============================================================
-- ORACLE CLOUD
-- ============================================================
('d2100009-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000009', 'nda', 'signed',
 'Oracle Mutual NDA — TrueSpend GmbH & Oracle Netherlands B.V. | Netherlands law | Signed 2025-01-01 | Expires 2028-01-01 | Covers OCI architecture design, Exadata roadmap, custom pricing schedules, and Oracle sales strategy discussions.',
 now() - interval '16 months'),

('d2100009-0000-0000-0000-000000000002',
 'f2000000-0000-0000-0000-000000000009', 'dpa', 'signed',
 'Oracle Cloud GDPR DPA — TrueSpend GmbH & Oracle Netherlands B.V. | EU law (GDPR Art. 28) | Signed 2025-01-01 | Expires 2028-01-01 | OCI processes application data and database content. EU region: eu-frankfurt-1 and eu-amsterdam-1. Oracle DPIA completed. ISO 27001, SOC 2 Type II, CSA STAR Level 2. EU-US DPF for Oracle HQ sub-processing. Data residency guarantee in DPA schedule.',
 now() - interval '16 months'),

-- ============================================================
-- IBM CLOUD
-- ============================================================
('d2100010-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000010', 'nda', 'signed',
 'IBM Mutual NDA — TrueSpend GmbH & IBM Deutschland GmbH | German law | Signed 2024-07-31 | Expires 2026-07-31 | Covers IBM zSystems architecture, Cloud Pak specifications, migration planning documents, and IBM Research collaboration.',
 now() - interval '22 months'),

('d2100010-0000-0000-0000-000000000002',
 'f2000000-0000-0000-0000-000000000010', 'dpa', 'signed',
 'IBM Cloud GDPR DPA — TrueSpend GmbH & IBM Deutschland GmbH | German law | Signed 2024-07-31 | Expires 2026-07-31 ⚠ Expiring soon | IBM processes legacy workload data on zSystems cloud. EU region (Frankfurt). IBM Data Security and Privacy Principles compliance. SOC 2 Type II, ISO 27001. Sub-processor list maintained at ibm.com/privacy/gdpr.',
 now() - interval '22 months'),

-- ============================================================
-- SERVICENOW
-- ============================================================
('d2100015-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000015', 'nda', 'signed',
 'ServiceNow NDA — TrueSpend GmbH & ServiceNow Netherlands B.V. | Dutch law | Signed 2024-08-31 | Expires 2026-08-31 | Covers ITSM configuration architecture, custom workflows, roadmap briefings, and Now Platform technical specifications.',
 now() - interval '21 months'),

('d2100015-0000-0000-0000-000000000002',
 'f2000000-0000-0000-0000-000000000015', 'dpa', 'signed',
 'Art. 28 GDPR DPA — TrueSpend GmbH & ServiceNow Netherlands B.V. | Dutch law | Signed 2024-08-31 | Expires 2026-08-31 | ServiceNow processes IT service request data, employee HR tickets, and asset inventory. EU data center (Amsterdam + Dublin). FedRAMP equivalent controls. ISO 27001 certified. 2021 SCCs for sub-processors. Data retention per record type defined in Schedule B.',
 now() - interval '21 months'),

-- ============================================================
-- HUBSPOT
-- ============================================================
('d2100016-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000016', 'dpa', 'signed',
 'HubSpot GDPR DPA — TrueSpend GmbH & HubSpot Ireland Limited | Irish law | Signed 2025-07-31 | Expires 2026-07-31 ⚠ Expiring — renewal in progress | HubSpot processes marketing contact data, CRM records, and email campaign analytics. EU data residency (Ireland). Sub-processors: AWS eu-west-1. 2021 SCCs for HubSpot Inc. (US). DPIA reference #HS-2025-042.',
 now() - interval '10 months'),

-- ============================================================
-- ATLASSIAN
-- ============================================================
('d2100017-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000017', 'dpa', 'signed',
 'Atlassian GDPR DPA — TrueSpend GmbH & Atlassian Network Services Inc. | Irish law (EU) | Signed 2025-10-15 | Expires 2026-10-15 | Atlassian processes project management data, source code, and IT service tickets. Atlassian Cloud EU residency elected (Ireland + Germany). 2021 SCCs for Atlassian Corp Pty Ltd (Australia). Sub-processors listed at atlassian.com/trust/privacy/subprocessors.',
 now() - interval '7 months'),

-- ============================================================
-- DOCUSIGN
-- ============================================================
('d2100019-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000019', 'dpa', 'signed',
 'DocuSign GDPR DPA — TrueSpend GmbH & DocuSign International EMEA Ltd. | Irish law | Signed 2026-01-01 | Expires 2028-01-01 | DocuSign processes contract signature data, signatory identity, and audit trail records. EU data residency (Ireland + Germany). ISO 27001, SOC 2 Type II, eIDAS qualified. Sub-processor: DocuSign Inc. (USA) — EU-US DPF framework. Data retention: 10 years per eIDAS requirements.',
 now() - interval '5 months'),

-- ============================================================
-- ADOBE
-- ============================================================
('d2100020-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000020', 'dpa', 'signed',
 'Adobe GDPR DPA — TrueSpend GmbH & Adobe Systems Software Ireland Ltd. | Irish law | Signed 2025-11-30 | Expires 2026-11-30 | Adobe processes Creative Cloud usage data, asset storage, and collaboration data. EU data residency (Ireland + Netherlands). Adobe Trust Center: adobe.com/privacy/gdpr. 2021 SCCs for Adobe Inc. (USA). Sub-processors: AWS, Microsoft Azure (EU regions only).',
 now() - interval '6 months'),

-- ============================================================
-- GITHUB
-- ============================================================
('d2100021-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000021', 'dpa', 'signed',
 'GitHub (Microsoft) GDPR DPA — TrueSpend GmbH & GitHub B.V. | Dutch law | Signed 2025-08-01 | Expires 2026-08-01 | GitHub processes source code, CI/CD pipelines, and developer activity data. EU data residency via GitHub Enterprise Cloud data residency add-on (Netherlands). Microsoft GDPR Addendum applies. Sub-processor: Microsoft Azure (EU regions). Advanced Security telemetry — EU only.',
 now() - interval '10 months'),

-- ============================================================
-- CROWDSTRIKE
-- ============================================================
('d2100031-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000031', 'dpa', 'signed',
 'CrowdStrike GDPR DPA — TrueSpend GmbH & CrowdStrike Holdings Inc. | Delaware law + EU GDPR addendum | Signed 2025-01-01 | Expires 2026-12-31 | CrowdStrike Falcon processes endpoint telemetry (process metadata, network connections, file activity) from 4,200 endpoints. EU GovCloud region for data storage. ISO 27001, FedRAMP High authorized. EU-US DPF and 2021 SCCs. Threat intelligence feeds: anonymised before sharing.',
 now() - interval '5 months'),

-- ============================================================
-- OKTA
-- ============================================================
('d2100032-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000032', 'dpa', 'signed',
 'Okta GDPR DPA — TrueSpend GmbH & Okta EMEA Ltd. | Irish law | Signed 2025-03-01 | Expires 2027-02-28 | Okta processes authentication events, MFA challenges, and session data for 3,200 users. EU cell (eu.okta.com) — Ireland + Germany. ISO 27001, SOC 2 Type II. Sub-processors at trust.okta.com. Data retention: 90-day log purge, exception for security events (1 year). SCIM provisioning data: deleted within 7 days of off-boarding.',
 now() - interval '15 months'),

-- ============================================================
-- DATADOG
-- ============================================================
('d2100034-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000034', 'dpa', 'signed',
 'Datadog GDPR DPA — TrueSpend GmbH & Datadog Inc. | New York law + EU GDPR addendum | Signed 2025-09-01 | Expires 2026-09-01 | Datadog processes application performance metrics, logs, and traces. EU region (AWS eu-west-1 + eu-central-1). 2021 SCCs for US→EU transfers. Sub-processor list at datadoghq.com/legal/sub-processors. PII scrubbing pipeline enabled — no sensitive data in traces.',
 now() - interval '9 months'),

-- ============================================================
-- DELOITTE
-- ============================================================
('d2100036-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000036', 'nda', 'signed',
 'Mutual NDA — TrueSpend GmbH & Deloitte GmbH | German law | Signed 2024-09-30 | Expires 2026-09-30 | Covers transfer pricing strategies, CFO reporting models, internal financial data, regulatory filing approaches, and M&A target analysis.',
 now() - interval '20 months'),

('d2100036-0000-0000-0000-000000000002',
 'f2000000-0000-0000-0000-000000000036', 'dpa', 'signed',
 'Art. 28 GDPR DPA — TrueSpend GmbH & Deloitte GmbH | German law | Signed 2024-09-30 | Expires 2026-09-30 | Deloitte processes financial records, payroll summaries, and tax data on behalf of TrueSpend. EU processing only (Frankfurt data centre). Deloitte ISO 27001 certified. No transfers outside EEA. Data retention: 10 years per German commercial law (HGB §257).',
 now() - interval '20 months'),

-- ============================================================
-- PWC
-- ============================================================
('d2100037-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000037', 'nda', 'signed',
 'PwC Confidentiality Agreement — TrueSpend GmbH & PricewaterhouseCoopers GmbH | German law | Signed 2025-01-01 | Expires 2027-01-01 | Covers CFO strategy materials, board presentations, M&A pipeline, and internal restructuring plans.',
 now() - interval '17 months'),

('d2100037-0000-0000-0000-000000000002',
 'f2000000-0000-0000-0000-000000000037', 'dpa', 'signed',
 'Art. 28 GDPR DPA — TrueSpend GmbH & PricewaterhouseCoopers GmbH | German law | Signed 2025-01-01 | Expires 2026-12-31 | PwC processes financial and strategic data. PwC uses PwC Private Cloud (Germany) for client data. No US transfer. ISO 27001. Data deletion within 30 days of engagement close.',
 now() - interval '17 months'),

-- ============================================================
-- MCKINSEY
-- ============================================================
('d2100038-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000038', 'nda', 'signed',
 'McKinsey Mutual NDA — TrueSpend GmbH & McKinsey & Company | German law | Signed 2024-08-31 | Expires 2026-08-31 | Covers digital procurement strategy, operating model designs, technology vendor assessments, and financial performance benchmarking data.',
 now() - interval '21 months'),

-- ============================================================
-- CAPGEMINI
-- ============================================================
('d2100040-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000040', 'nda', 'signed',
 'Mutual NDA — TrueSpend GmbH & Capgemini Deutschland GmbH | German law | Signed 2024-10-31 | Expires 2026-10-31 | Covers S/4HANA implementation architecture, business process designs, data migration strategies, and TrueSpend internal system specifications.',
 now() - interval '19 months'),

('d2100040-0000-0000-0000-000000000002',
 'f2000000-0000-0000-0000-000000000040', 'dpa', 'signed',
 'Art. 28 GDPR DPA — TrueSpend GmbH & Capgemini Deutschland GmbH | German law | Signed 2024-10-31 | Expires 2026-10-31 | Capgemini processes HR, finance, and operational data during SAP implementation. Onshore Germany delivery team only. ISO 27001 + BSI C5. Data handling procedures in Exhibit A. No offshore processing without prior written approval.',
 now() - interval '19 months'),

-- ============================================================
-- TCS
-- ============================================================
('d2100041-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000041', 'nda', 'signed',
 'TCS Mutual NDA — TrueSpend GmbH & Tata Consultancy Services Deutschland GmbH | German law | Signed 2025-04-01 | Expires 2027-03-31 | Covers application architecture, proprietary business logic, and TrueSpend internal data processed during managed services delivery.',
 now() - interval '14 months'),

('d2100041-0000-0000-0000-000000000002',
 'f2000000-0000-0000-0000-000000000041', 'dpa', 'signed',
 'Art. 28 GDPR DPA — TrueSpend GmbH & Tata Consultancy Services Deutschland GmbH | German law | Signed 2025-04-01 | Expires 2027-03-31 | TCS processes application data in managed services scope. Hybrid delivery: Germany onshore team + TCS Secure Zone (India) for non-EU data only. 2021 SCCs for India transfers. ISO 27001, SOC 2 Type II. DPIA completed — reference #TCS-DPIA-2025-112.',
 now() - interval '14 months'),

-- ============================================================
-- INFOSYS (amber — LkSG pending)
-- ============================================================
('d2100042-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000042', 'nda', 'signed',
 'Infosys NDA — TrueSpend GmbH & Infosys BPM Ltd. (Germany Branch) | German law | Signed 2025-03-15 | Expires 2027-03-15 | Covers BPO process designs, automation specs, and client data handling procedures.',
 now() - interval '14 months'),

('d2100042-0000-0000-0000-000000000002',
 'f2000000-0000-0000-0000-000000000042', 'lksg', 'generated',
 'LkSG Supply Chain Act Declaration — TrueSpend GmbH & Infosys BPM Ltd. | German law (LkSG §5) | Generated 2026-05-20 | Status: Pending supplier signature | Infosys to confirm: no child labour, no forced labour, compliance with local wage laws in India delivery centres. Supplier audit report from 2024 attached as Exhibit. AWAITING SIGNATURE.',
 now() - interval '11 days'),

-- ============================================================
-- LINKLATERS
-- ============================================================
('d2100045-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000045', 'nda', 'signed',
 'Linklaters Mutual NDA — TrueSpend GmbH & Linklaters LLP | German law | Signed 2024-07-01 | Expires 2026-06-30 ⚠ Expiring — renewal scheduled | Covers M&A targets, deal structures, valuations, and board-level strategic discussions.',
 now() - interval '23 months'),

-- ============================================================
-- ORANGE BUSINESS (MPLS)
-- ============================================================
('d2100062-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000062', 'nda', 'signed',
 'Orange Business NDA — TrueSpend GmbH & Orange Business Services | French law | Signed 2025-05-01 | Expires 2027-04-30 | Covers MPLS network architecture, SD-WAN pilot specifications, and pricing strategy for global rollout.',
 now() - interval '13 months'),

('d2100062-0000-0000-0000-000000000002',
 'f2000000-0000-0000-0000-000000000062', 'dpa', 'signed',
 'Art. 28 GDPR DPA — TrueSpend GmbH & Orange Business Services | French law (EU GDPR) | Signed 2025-05-01 | Expires 2027-04-30 | Orange processes network metadata and traffic logs. EU data residency (France + Netherlands). Orange is a qualified operator under French NIS regulation. No data transfer outside EEA. ENISA-compliant incident response procedures.',
 now() - interval '13 months'),

-- ============================================================
-- ANTHROPIC (AI consumption)
-- ============================================================
('d2100066-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000066', 'dpa', 'signed',
 'Anthropic Data Processing Addendum — TrueSpend GmbH & Anthropic PBC | California law + EU GDPR addendum | Signed 2026-01-01 | Expires 2026-12-31 | Anthropic processes API prompt and completion data. Data not used for model training (API usage). No persistent storage of prompts beyond 30 days. 2021 SCCs for EU→US transfer. Anthropic Trust Portal: trust.anthropic.com. EU-US DPF participation confirmed.',
 now() - interval '5 months'),

-- ============================================================
-- OPENAI
-- ============================================================
('d2100067-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000067', 'dpa', 'signed',
 'OpenAI Data Processing Agreement — TrueSpend GmbH & OpenAI OpCo LLC | California law + EU GDPR addendum | Signed 2026-02-01 | Expires 2027-01-31 | OpenAI API processes prompt data for internal tools. Zero Data Retention (ZDR) policy elected — no 30-day retention. 2021 SCCs for EU→US. Sub-processor: Microsoft Azure (US regions for inference). DPIA completed — reference #OAIDPA-2026-089.',
 now() - interval '4 months'),

-- ============================================================
-- MISTRAL AI
-- ============================================================
('d2100069-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000069', 'dpa', 'signed',
 'Mistral AI DPA — TrueSpend GmbH & Mistral AI SAS | French law (GDPR Art. 28) | Signed 2026-03-01 | Expires 2027-02-28 | Mistral processes API inference data. EU-native provider — data processed exclusively in France (OVH infrastructure). No SCCs required (intra-EU). CNIL registration confirmed. No data retained post-session. Competitive advantage: EU AI Act compliance roadmap already published.',
 now() - interval '3 months'),

-- ============================================================
-- MONDAY.COM (amber — GDPR transfer pending)
-- ============================================================
('d2100026-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000026', 'dpa', 'generated',
 'DPA DRAFT — TrueSpend GmbH & Monday.com Ltd. | Israeli law + GDPR addendum | Status: Under legal review | Monday.com processes project and task data for Benelux team. Data stored in EU (AWS eu-west-1). ISSUE: Israel not on EU adequacy list — SCCs required for Monday.com Ltd. (Israel) as controller. Legal team reviewing whether EU SCCs version 2021 covers this transfer mechanism adequately. CONTRACT CANNOT AUTO-RENEW UNTIL RESOLVED.',
 now() - interval '45 days'),

-- ============================================================
-- FIGMA (amber — entity change)
-- ============================================================
('d2100023-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000023', 'dpa', 'generated',
 'DPA DRAFT — TrueSpend GmbH & Figma Inc. | California law + EU GDPR addendum | Status: Pending legal review following Adobe acquisition | Original DPA signed with Figma Inc. (Delaware). Following partial Adobe integration, data processing entity review required. EU data residency commitment: AWS eu-central-1 (Frankfurt). Awaiting confirmation of new DPA entity and updated sub-processor list from Adobe/Figma legal team.',
 now() - interval '30 days'),

-- ============================================================
-- G4S (amber — LkSG)
-- ============================================================
('d2100059-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000059', 'lksg', 'sent',
 'LkSG Supply Chain Act Declaration — TrueSpend GmbH & G4S Sicherheitslösungen GmbH | German law (LkSG §5) | Sent to supplier 2026-04-28 | Status: Awaiting signature | G4S to confirm compliance with German minimum wage law for all security guards, no forced labour in G4S global supply chain, and annual audit rights for TrueSpend. G4S UK parent company audit report (2023) provided as reference. GUARDS CERTIFICATION RENEWAL BLOCKED PENDING SIGNATURE.',
 now() - interval '33 days'),

-- ============================================================
-- CGI GROUP (amber — DPA scope expansion)
-- ============================================================
('d2100083-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000083', 'dpa', 'generated',
 'DPA AMENDMENT DRAFT — TrueSpend GmbH & CGI IT UK Ltd. (Germany Branch) | German law | Original DPA signed 2024-06-01 | Amendment required for new scope: CGI to begin processing HR data under extended managed services scope. New data categories (employee performance data, payroll inputs) require DPA amendment and fresh DPIA. CGI ISO 27001 certificate valid until 2027. Awaiting CGI legal sign-off on amended Schedule C.',
 now() - interval '23 days')

on conflict (id) do update set
  status  = excluded.status,
  content = excluded.content;
