-- TrueSpend Seed — Expanded Supplier Register
-- 83 new suppliers added to existing 17 = 100 total
-- Covers all 7 spend categories, all 10 regions, realistic mix of health/compliance status
-- Supplier IDs: f2000000-0000-0000-0000-0000000000XX (01–83)

insert into suppliers (
  id, name, legal_name, country, category,
  health, compliance_status, sla_status, open_disputes, last_contact, gdpr_dpa_signed
) values

-- ============================================================
-- HARDWARE (18–25)
-- ============================================================
('f2000000-0000-0000-0000-000000000001', 'HP Inc.',             'HP Inc. Deutschland GmbH',              'Germany',     'hardware',    'green', 'green', 'On track — 96% on-time delivery L90D', 0, '2026-04-10', true),
('f2000000-0000-0000-0000-000000000002', 'Cisco Systems',       'Cisco Systems GmbH',                    'Germany',     'hardware',    'green', 'green', 'On track — network refresh on schedule', 0, '2026-03-28', true),
('f2000000-0000-0000-0000-000000000003', 'Samsung',             'Samsung Electronics GmbH',              'Germany',     'hardware',    'green', 'green', 'Display refresh program on track', 0, '2026-02-15', true),
('f2000000-0000-0000-0000-000000000004', 'Fujitsu',             'Fujitsu Technology Solutions GmbH',     'Germany',     'hardware',    'watch', 'amber', '2 delayed shipments flagged — supply chain disruption', 2, '2026-04-20', true),
('f2000000-0000-0000-0000-000000000005', 'Logitech',            'Logitech Europe S.A.',                  'Switzerland', 'hardware',    'green', 'green', 'Peripherals program stable', 0, '2026-01-30', true),
('f2000000-0000-0000-0000-000000000006', 'Epson',               'Epson Europe B.V.',                     'Netherlands', 'hardware',    'green', 'green', 'Print fleet SLA 98.3%', 0, '2026-03-05', false),
('f2000000-0000-0000-0000-000000000007', 'Ricoh',               'Ricoh Deutschland GmbH',                'Germany',     'hardware',    'green', 'green', 'MFP maintenance SLA 99.1%', 0, '2026-02-20', true),
('f2000000-0000-0000-0000-000000000008', 'APC by Schneider',    'APC by Schneider Electric',             'France',      'hardware',    'green', 'green', 'UPS maintenance contracts current', 0, '2026-01-15', true),

-- ============================================================
-- HYPERSCALER / CLOUD INFRASTRUCTURE (26–33)
-- ============================================================
('f2000000-0000-0000-0000-000000000009', 'Oracle Cloud',        'Oracle Netherlands B.V.',               'Netherlands', 'hyperscaler', 'green', 'green', 'OCI utilization 78% — within commitment', 0, '2026-03-20', true),
('f2000000-0000-0000-0000-000000000010', 'IBM Cloud',           'IBM Deutschland GmbH',                  'Germany',     'hyperscaler', 'watch', 'amber', 'Migration delay — 2 workloads pending', 1, '2026-04-15', true),
('f2000000-0000-0000-0000-000000000011', 'Hetzner',             'Hetzner Online GmbH',                   'Germany',     'hyperscaler', 'green', 'green', 'Bare metal SLA 99.9%', 0, '2026-03-01', true),
('f2000000-0000-0000-0000-000000000012', 'OVHcloud',            'OVH GmbH',                              'Germany',     'hyperscaler', 'green', 'green', 'EU-sovereign cloud, all SLAs met', 0, '2026-02-10', true),
('f2000000-0000-0000-0000-000000000013', 'Equinix',             'Equinix Germany GmbH',                  'Germany',     'hyperscaler', 'green', 'green', 'Colocation SLA 99.999% — no incidents', 0, '2026-01-20', true),
('f2000000-0000-0000-0000-000000000014', 'IONOS',               'IONOS SE',                              'Germany',     'hyperscaler', 'green', 'green', 'Hosting platform SLA met', 0, '2026-02-28', true),

-- ============================================================
-- SAAS LICENSES (34–55)
-- ============================================================
('f2000000-0000-0000-0000-000000000015', 'ServiceNow',          'ServiceNow Netherlands B.V.',           'Netherlands', 'saas_license','green', 'green', 'ITSM platform — no open incidents', 0, '2026-03-18', true),
('f2000000-0000-0000-0000-000000000016', 'HubSpot',             'HubSpot Ireland Limited',               'Ireland',     'saas_license','green', 'green', 'Marketing Hub stable — 99.8% uptime', 0, '2026-02-25', true),
('f2000000-0000-0000-0000-000000000017', 'Atlassian',           'Atlassian Network Services Inc.',       'USA',         'saas_license','green', 'green', 'Jira + Confluence — cloud migration complete', 0, '2026-03-10', true),
('f2000000-0000-0000-0000-000000000018', 'Zendesk',             'Zendesk International Ltd.',            'Ireland',     'saas_license','green', 'green', 'Support platform SLA 99.5%', 0, '2026-01-15', true),
('f2000000-0000-0000-0000-000000000019', 'DocuSign',            'DocuSign International EMEA Ltd.',      'Ireland',     'saas_license','green', 'green', 'eSignature platform — no issues', 0, '2026-04-01', true),
('f2000000-0000-0000-0000-000000000020', 'Adobe',               'Adobe Systems Software Ireland Ltd.',   'Ireland',     'saas_license','green', 'green', 'Creative Cloud — auto-billing stable', 0, '2026-02-12', true),
('f2000000-0000-0000-0000-000000000021', 'GitHub',              'GitHub B.V.',                           'Netherlands', 'saas_license','green', 'green', 'Enterprise — 2,100 active seats', 0, '2026-03-05', true),
('f2000000-0000-0000-0000-000000000022', 'Miro',                'RealtimeBoard Inc. (Miro)',              'USA',         'saas_license','green', 'green', 'Collaboration platform stable', 0, '2026-01-20', false),
('f2000000-0000-0000-0000-000000000023', 'Figma',               'Figma Inc.',                            'USA',         'saas_license','green', 'amber', 'DPA pending — acquired by Adobe, entity review required', 0, '2026-02-18', false),
('f2000000-0000-0000-0000-000000000024', 'Tableau',             'Tableau Software LLC (Salesforce)',     'USA',         'saas_license','green', 'green', 'Analytics platform — no issues', 0, '2026-03-22', true),
('f2000000-0000-0000-0000-000000000025', 'Power BI Premium',    'Microsoft Ireland Operations Ltd.',     'Ireland',     'saas_license','green', 'green', 'Included in M365 E5 — no separate SLA', 0, '2026-01-10', true),
('f2000000-0000-0000-0000-000000000026', 'Monday.com',          'Monday.com Ltd.',                       'Israel',      'saas_license','watch', 'amber', 'GDPR transfer mechanism review pending for Israel', 1, '2026-04-08', false),
('f2000000-0000-0000-0000-000000000027', 'Asana',               'Asana Inc.',                            'USA',         'saas_license','green', 'green', 'Project management — 480 seats stable', 0, '2026-02-05', true),
('f2000000-0000-0000-0000-000000000028', 'Notion',              'Notion Labs Inc.',                      'USA',         'saas_license','green', 'amber', 'Sub-processor list under review for GDPR compliance', 0, '2026-03-15', false),
('f2000000-0000-0000-0000-000000000029', 'Slack (standalone)',  'Salesforce/Slack Technologies Ltd.',    'Ireland',     'saas_license','green', 'green', 'Migrating to Salesforce DPA umbrella', 0, '2026-04-12', true),
('f2000000-0000-0000-0000-000000000030', '1Password',           '1Password (AgileBits Inc.)',             'Canada',      'saas_license','green', 'green', 'Password management — SLA 99.9%', 0, '2026-01-25', true),
('f2000000-0000-0000-0000-000000000031', 'CrowdStrike',         'CrowdStrike Holdings Inc.',             'USA',         'saas_license','green', 'green', 'Falcon EDR — all endpoints covered', 0, '2026-03-30', true),
('f2000000-0000-0000-0000-000000000032', 'Okta',                'Okta EMEA Ltd.',                        'Ireland',     'saas_license','green', 'green', 'IAM platform — no issues', 0, '2026-02-20', true),
('f2000000-0000-0000-0000-000000000033', 'Splunk',              'Splunk Inc.',                           'USA',         'saas_license','watch', 'amber', 'Cisco acquisition — contract novation pending', 1, '2026-04-05', true),
('f2000000-0000-0000-0000-000000000034', 'Datadog',             'Datadog Inc.',                          'USA',         'saas_license','green', 'green', 'Observability platform — all dashboards live', 0, '2026-03-25', true),
('f2000000-0000-0000-0000-000000000035', 'PagerDuty',           'PagerDuty Inc.',                        'USA',         'saas_license','green', 'green', 'Incident management — no escalations', 0, '2026-02-15', true),

-- ============================================================
-- SERVICES — Consulting, Professional, Legal (56–70)
-- ============================================================
('f2000000-0000-0000-0000-000000000036', 'Deloitte',            'Deloitte GmbH Wirtschaftsprüfungsgesellschaft', 'Germany', 'services', 'green', 'green', 'Tax advisory engagement on schedule', 0, '2026-03-20', true),
('f2000000-0000-0000-0000-000000000037', 'PwC',                 'PricewaterhouseCoopers GmbH',           'Germany',   'services',    'green', 'green', 'CFO advisory — no issues', 0, '2026-02-28', true),
('f2000000-0000-0000-0000-000000000038', 'McKinsey',            'McKinsey & Company',                    'Germany',   'services',    'green', 'green', 'Strategy engagement — board report delivered', 0, '2026-04-18', true),
('f2000000-0000-0000-0000-000000000039', 'BCG',                 'Boston Consulting Group GmbH',          'Germany',   'services',    'watch', 'green', 'Cost optimisation engagement — 2 deliverables delayed', 1, '2026-04-22', true),
('f2000000-0000-0000-0000-000000000040', 'Capgemini',           'Capgemini Deutschland GmbH',            'Germany',   'services',    'green', 'green', 'IT transformation SOW on track', 0, '2026-03-15', true),
('f2000000-0000-0000-0000-000000000041', 'TCS',                 'Tata Consultancy Services Deutschland', 'Germany',   'services',    'green', 'green', 'Application support — SLA 99.2%', 0, '2026-02-10', true),
('f2000000-0000-0000-0000-000000000042', 'Infosys',             'Infosys BPM Ltd. (Germany Branch)',     'Germany',   'services',    'green', 'amber', 'LkSG supply chain declaration pending', 0, '2026-03-28', true),
('f2000000-0000-0000-0000-000000000043', 'Wipro',               'Wipro Limited (Germany Branch)',        'Germany',   'services',    'watch', 'amber', 'SOC 2 report overdue — InfoSec amber', 1, '2026-04-10', false),
('f2000000-0000-0000-0000-000000000044', 'EY',                  'Ernst & Young GmbH',                   'Germany',   'services',    'green', 'green', 'Internal audit co-sourcing on track', 0, '2026-03-05', true),
('f2000000-0000-0000-0000-000000000045', 'Linklaters',          'Linklaters LLP',                       'Germany',   'services',    'green', 'green', 'M&A legal advisory — NDA signed', 0, '2026-02-20', true),
('f2000000-0000-0000-0000-000000000046', 'Freshfields',         'Freshfields Bruckhaus Deringer LLP',   'Germany',   'services',    'green', 'green', 'Regulatory counsel — GDPR review complete', 0, '2026-01-30', true),
('f2000000-0000-0000-0000-000000000047', 'Bird & Bird',         'Bird & Bird LLP',                      'Germany',   'services',    'green', 'green', 'IP legal counsel — active engagement', 0, '2026-03-18', true),
('f2000000-0000-0000-0000-000000000048', 'Hays',                'Hays plc (Germany Branch)',             'Germany',   'services',    'green', 'green', 'Staffing framework — 42 active placements', 0, '2026-04-15', true),
('f2000000-0000-0000-0000-000000000049', 'ManpowerGroup',       'ManpowerGroup Deutschland GmbH',        'Germany',   'services',    'green', 'green', 'Temp staffing SLA met', 0, '2026-03-12', true),
('f2000000-0000-0000-0000-000000000050', 'Randstad',            'Randstad Deutschland GmbH & Co. KG',    'Germany',   'services',    'watch', 'green', 'LkSG audit scheduled Q3 — pre-check amber', 0, '2026-04-20', false),

-- ============================================================
-- FACILITIES — Office, Security, Logistics (71–80)
-- ============================================================
('f2000000-0000-0000-0000-000000000051', 'CBRE',                'CBRE GmbH',                             'Germany',   'facilities',  'green', 'green', 'FM contract — all sites operational', 0, '2026-03-10', true),
('f2000000-0000-0000-0000-000000000052', 'ISS Facility Services','ISS Deutschland GmbH',                 'Germany',   'facilities',  'green', 'green', 'Cleaning + catering SLA 98.7%', 0, '2026-02-25', true),
('f2000000-0000-0000-0000-000000000053', 'Sodexo',              'Sodexo Pass GmbH',                     'Germany',   'facilities',  'green', 'green', 'Cafeteria services — satisfaction 4.2/5', 0, '2026-01-20', true),
('f2000000-0000-0000-0000-000000000054', 'DHL',                 'Deutsche Post DHL Group',               'Germany',   'facilities',  'green', 'green', 'Parcel + courier SLA 97.8%', 0, '2026-04-05', true),
('f2000000-0000-0000-0000-000000000055', 'UPS',                 'United Parcel Service Deutschland Inc.','Germany',   'facilities',  'watch', 'green', '1 SLA breach Q1 — root cause addressed', 1, '2026-04-18', true),
('f2000000-0000-0000-0000-000000000056', 'DB Schenker',         'Schenker Deutschland AG',               'Germany',   'facilities',  'green', 'green', 'Freight forwarding — no disruptions', 0, '2026-03-22', true),
('f2000000-0000-0000-0000-000000000057', 'Koenig & Bauer',      'Koenig & Bauer AG (print services)',    'Germany',   'facilities',  'green', 'green', 'Print-on-demand stable', 0, '2026-02-10', false),
('f2000000-0000-0000-0000-000000000058', 'Bilfinger',           'Bilfinger SE (technical FM)',           'Germany',   'facilities',  'green', 'green', 'Technical facility management — SLA 99.3%', 0, '2026-01-15', true),
('f2000000-0000-0000-0000-000000000059', 'G4S',                 'G4S Sicherheitslösungen GmbH',         'Germany',   'facilities',  'watch', 'amber', 'Guards certification renewal pending LkSG', 1, '2026-04-12', false),
('f2000000-0000-0000-0000-000000000060', 'Aramark',             'Aramark GmbH',                         'Germany',   'facilities',  'green', 'green', 'Corporate catering — no issues', 0, '2026-03-08', true),

-- ============================================================
-- TELECOMS (81–86)
-- ============================================================
('f2000000-0000-0000-0000-000000000061', 'O2 Telefónica',       'Telefónica Germany GmbH & Co. OHG',    'Germany',   'telecoms',    'green', 'green', 'Mobile fleet — SLA 99.6%', 0, '2026-03-15', true),
('f2000000-0000-0000-0000-000000000062', 'Orange Business',     'Orange Business Services',              'France',    'telecoms',    'green', 'green', 'MPLS backbone — SLA 99.7% all regions', 0, '2026-02-20', true),
('f2000000-0000-0000-0000-000000000063', 'Tele2',               'Tele2 Sverige AB',                     'Sweden',    'telecoms',    'green', 'green', 'Nordics mobile fleet stable', 0, '2026-01-10', true),
('f2000000-0000-0000-0000-000000000064', 'BT Group',            'British Telecom Group plc',             'UK',        'telecoms',    'watch', 'green', 'MPLS UK — price review Q3 pending', 1, '2026-04-20', true),
('f2000000-0000-0000-0000-000000000065', 'Colt Technology',     'Colt Technology Services Group',        'UK',        'telecoms',    'green', 'green', 'SD-WAN pilot — on track', 0, '2026-03-28', true),

-- ============================================================
-- AI / LLM CONSUMPTION (specialty category)
-- ============================================================
('f2000000-0000-0000-0000-000000000066', 'Anthropic',           'Anthropic PBC',                         'USA',       'other',       'green', 'green', 'Claude API — usage within committed tier', 0, '2026-04-25', true),
('f2000000-0000-0000-0000-000000000067', 'OpenAI',              'OpenAI OpCo LLC',                       'USA',       'other',       'green', 'green', 'GPT-4o API — usage within plan', 0, '2026-04-20', true),
('f2000000-0000-0000-0000-000000000068', 'Cohere',              'Cohere Inc.',                           'Canada',    'other',       'green', 'amber', 'EU data residency confirmation pending', 0, '2026-03-15', false),
('f2000000-0000-0000-0000-000000000069', 'Mistral AI',          'Mistral AI SAS',                        'France',    'other',       'green', 'green', 'EU-native LLM — GDPR compliant', 0, '2026-04-10', true),
('f2000000-0000-0000-0000-000000000070', 'Stability AI',        'Stability AI Ltd.',                     'UK',        'other',       'watch', 'amber', 'Financial stability concerns flagged — monitor', 1, '2026-03-20', false),

-- ============================================================
-- REGIONAL TAIL SPEND — branch-specific long-tail vendors
-- ============================================================

-- UK & Ireland
('f2000000-0000-0000-0000-000000000071', 'Computacenter',       'Computacenter plc',                     'UK',        'hardware',    'green', 'green', 'IT reseller UK — on-time 98%', 0, '2026-03-12', true),
('f2000000-0000-0000-0000-000000000072', 'SHI International',   'SHI International Corp.',               'USA',       'saas_license','green', 'green', 'Software procurement — license tracking active', 0, '2026-02-15', true),

-- France
('f2000000-0000-0000-0000-000000000073', 'OVH Telecom',         'OVH Telecom SAS',                       'France',    'telecoms',    'green', 'green', 'France internet connectivity — SLA 99.8%', 0, '2026-01-28', true),
('f2000000-0000-0000-0000-000000000074', 'Bouygues Telecom',    'Bouygues Telecom SA',                   'France',    'telecoms',    'green', 'green', 'France mobile fleet 240 SIMs', 0, '2026-03-05', true),

-- Benelux
('f2000000-0000-0000-0000-000000000075', 'KPN',                 'KPN B.V.',                              'Netherlands','telecoms',   'green', 'green', 'NL internet + telephony — SLA 99.9%', 0, '2026-02-22', true),
('f2000000-0000-0000-0000-000000000076', 'Proximus',            'Proximus NV',                           'Belgium',   'telecoms',    'green', 'green', 'Belgium connectivity stable', 0, '2026-01-18', true),

-- Iberia
('f2000000-0000-0000-0000-000000000077', 'Telefónica España',   'Telefónica de España S.A.',             'Spain',     'telecoms',    'green', 'green', 'Spain mobile + broadband — no issues', 0, '2026-03-20', true),
('f2000000-0000-0000-0000-000000000078', 'NTT Data Spain',      'NTT Data Spain',                        'Spain',     'services',    'green', 'green', 'SAP support Spain — SLA met', 0, '2026-02-28', true),

-- Italy
('f2000000-0000-0000-0000-000000000079', 'TIM',                 'Telecom Italia S.p.A.',                 'Italy',     'telecoms',    'watch', 'green', 'Fibre rollout behind schedule — 2 sites pending', 1, '2026-04-15', true),
('f2000000-0000-0000-0000-000000000080', 'Almaviva',            'Almaviva S.p.A.',                       'Italy',     'services',    'green', 'green', 'BPO Italy — contact centre SLA 96%', 0, '2026-03-10', true),

-- CEE / Nordics East
('f2000000-0000-0000-0000-000000000081', 'Comarch',             'Comarch SA',                            'Poland',    'saas_license','green', 'green', 'ERP modules CEE — no issues', 0, '2026-02-20', true),
('f2000000-0000-0000-0000-000000000082', 'Elisa',               'Elisa Oyj',                             'Finland',   'telecoms',    'green', 'green', 'Finland connectivity — SLA 99.8%', 0, '2026-01-25', true),
('f2000000-0000-0000-0000-000000000083', 'CGI Group',           'CGI IT UK Ltd. / CGI Deutschland',      'Germany',   'services',    'green', 'amber', 'IT managed services — DPA under review for new scope', 0, '2026-04-08', true)

on conflict (id) do update set
  name              = excluded.name,
  legal_name        = excluded.legal_name,
  country           = excluded.country,
  category          = excluded.category,
  health            = excluded.health,
  compliance_status = excluded.compliance_status,
  sla_status        = excluded.sla_status,
  open_disputes     = excluded.open_disputes,
  last_contact      = excluded.last_contact,
  gdpr_dpa_signed   = excluded.gdpr_dpa_signed;
