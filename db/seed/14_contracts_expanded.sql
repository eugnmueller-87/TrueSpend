-- TrueSpend Seed — Expanded Contracts Register
-- 50 new contracts using the 83 new suppliers (f2000000-... series)
-- Spreads across all 10 branches, all renewal states, realistic value/expiry distribution
-- Contract IDs: c2000000-0000-0000-0000-0000000000XX (01–50)
-- Branch IDs: b1000000-0000-0000-0000-00000000000X (1–10)
-- Owner IDs: e1000000-0000-0000-0000-00000000000X (0–7)

insert into contracts (
  id, supplier_id, branch_id, owner_id, name, category,
  value, currency, start_date, expiry_date, notice_days,
  auto_renew, renewal_state, terms_summary,
  price_per_unit, unit_type, volume,
  alert_90_sent, alert_60_sent, alert_30_sent
) values

-- ============================================================
-- HARDWARE CONTRACTS
-- ============================================================

-- HP Inc. — Global HQ — €14.2M — expires 2026-08-15 — CLEAN
('c2000000-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'HP Hardware Framework — Global HQ', 'hardware',
 14200000.00, 'EUR', '2024-08-15', '2026-08-15', 60,
 true, 'clean',
 'Global HP workstation and print fleet. Covers EliteBook, ZBook, and LaserJet series. Volume pricing tier 3 locked.',
 NULL, NULL, NULL,
 true, false, false),

-- HP Inc. — DACH — €3.8M — expires 2026-09-30 — VOLUME CHANGE
('c2000000-0000-0000-0000-000000000002',
 'f2000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'e1000000-0000-0000-0000-000000000003',
 'HP EliteBook Fleet — DACH', 'hardware',
 3800000.00, 'EUR', '2025-09-30', '2026-09-30', 45,
 false, 'volume_change',
 '760 EliteBook 840 G10 units. DACH engineering requesting 120 additional for new hires Q4.',
 5000.00, 'device', 760,
 true, false, false),

-- Cisco — Global HQ — €9.1M — expires 2026-10-01 — PRICE INCREASE 6%
('c2000000-0000-0000-0000-000000000003',
 'f2000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'Cisco Network Infrastructure — Global', 'hardware',
 9100000.00, 'EUR', '2024-10-01', '2026-10-01', 60,
 false, 'price_increase',
 'Core switching, routing, and wireless LAN across all sites. Cisco EA agreement. 6% price increase proposed citing SmartNet cost increase.',
 NULL, NULL, NULL,
 true, false, false),

-- Samsung — UK — £2.2M — expires 2027-01-15 — CLEAN
('c2000000-0000-0000-0000-000000000004',
 'f2000000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000001',
 'Samsung Display & Mobile — UK & Ireland', 'hardware',
 2200000.00, 'GBP', '2025-01-15', '2027-01-15', 30,
 true, 'clean',
 'Galaxy Tab S10 fleet + display signage. 800 tablets, 120 large-format displays for meeting rooms.',
 NULL, NULL, NULL,
 false, false, false),

-- Fujitsu — CEE — €1.4M — expires 2026-06-30 — MANUAL REQUIRED
('c2000000-0000-0000-0000-000000000005',
 'f2000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000009', 'e1000000-0000-0000-0000-000000000003',
 'Fujitsu Server Infrastructure — CEE', 'hardware',
 1400000.00, 'EUR', '2024-06-30', '2026-06-30', 45,
 false, 'manual_required',
 'PRIMERGY server refresh CEE datacentre. Fujitsu announcing product line changes — manual review required before renewal.',
 NULL, NULL, NULL,
 true, true, true),

-- Logitech — France — €380k — expires 2026-11-30 — CLEAN
('c2000000-0000-0000-0000-000000000006',
 'f2000000-0000-0000-0000-000000000005', 'b1000000-0000-0000-0000-000000000005', 'e1000000-0000-0000-0000-000000000002',
 'Logitech Peripherals — France', 'hardware',
 380000.00, 'EUR', '2025-11-30', '2026-11-30', 30,
 true, 'clean',
 'MX Keys + MX Master bundle for all France offices. Auto-renewal program.',
 95.00, 'unit', 4000,
 false, false, false),

-- Computacenter — UK — £5.5M — expires 2027-03-31 — CLEAN
('c2000000-0000-0000-0000-000000000007',
 'f2000000-0000-0000-0000-000000000071', 'b1000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000001',
 'Computacenter IT Reseller Framework — UK', 'hardware',
 5500000.00, 'GBP', '2025-03-31', '2027-03-31', 60,
 true, 'clean',
 'Multi-vendor IT procurement framework. Dell, HP, Cisco, Lenovo at pre-negotiated rates. 48h SLA on orders.',
 NULL, NULL, NULL,
 false, false, false),

-- ============================================================
-- HYPERSCALER CONTRACTS
-- ============================================================

-- Oracle Cloud — Global HQ — €4.2M — expires 2026-12-31 — CLEAN
('c2000000-0000-0000-0000-000000000008',
 'f2000000-0000-0000-0000-000000000009', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'Oracle Cloud Infrastructure — Global', 'hyperscaler',
 4200000.00, 'EUR', '2025-01-01', '2026-12-31', 90,
 false, 'price_increase',
 'OCI commitment. Oracle Exadata Cloud, Autonomous Database. 8% price increase proposed for 2027 renewal.',
 NULL, NULL, NULL,
 false, false, false),

-- IBM Cloud — DACH — €1.8M — expires 2026-07-31 — SCOPE CHANGE
('c2000000-0000-0000-0000-000000000009',
 'f2000000-0000-0000-0000-000000000010', 'b1000000-0000-0000-0000-000000000002', 'e1000000-0000-0000-0000-000000000003',
 'IBM Cloud — DACH Legacy Workloads', 'hyperscaler',
 1800000.00, 'EUR', '2024-07-31', '2026-07-31', 60,
 false, 'scope_change',
 'IBM zSystems cloud for legacy banking workloads. Scope change proposal: migrate 3 workloads to IBM Hybrid Cloud architecture.',
 NULL, NULL, NULL,
 true, true, false),

-- Hetzner — Germany (DACH) — €240k — expires 2027-06-30 — CLEAN
('c2000000-0000-0000-0000-000000000010',
 'f2000000-0000-0000-0000-000000000011', 'b1000000-0000-0000-0000-000000000002', 'e1000000-0000-0000-0000-000000000003',
 'Hetzner Dedicated Server Pool — DACH', 'hyperscaler',
 240000.00, 'EUR', '2025-07-01', '2027-06-30', 30,
 true, 'clean',
 '24x AX101 dedicated servers. CI/CD and staging environments. EU data residency (Nuremberg + Falkenstein).',
 10000.00, 'server', 24,
 false, false, false),

-- OVHcloud — France — €560k — expires 2026-09-15 — CLEAN
('c2000000-0000-0000-0000-000000000011',
 'f2000000-0000-0000-0000-000000000012', 'b1000000-0000-0000-0000-000000000005', 'e1000000-0000-0000-0000-000000000002',
 'OVHcloud Public Cloud — France', 'hyperscaler',
 560000.00, 'EUR', '2025-09-15', '2026-09-15', 30,
 true, 'clean',
 'France compliance workloads. SecNumCloud certified. Sovereign cloud for regulated data processing.',
 NULL, NULL, NULL,
 false, false, false),

-- Equinix — Global HQ — €3.6M — expires 2028-12-31 — CLEAN (long-term)
('c2000000-0000-0000-0000-000000000012',
 'f2000000-0000-0000-0000-000000000013', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'Equinix Colocation — Frankfurt FR5', 'hyperscaler',
 3600000.00, 'EUR', '2024-01-01', '2028-12-31', 180,
 true, 'clean',
 'Primary data centre colocation. 12 racks, cross-connects to AWS, GCP, Azure. 180-day exit notice.',
 NULL, NULL, NULL,
 false, false, false),

-- ============================================================
-- SAAS LICENSE CONTRACTS
-- ============================================================

-- ServiceNow — Global HQ — €2.9M — expires 2026-08-31 — VOLUME CHANGE
('c2000000-0000-0000-0000-000000000013',
 'f2000000-0000-0000-0000-000000000015', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'ServiceNow ITSM Platform — Global', 'saas_license',
 2900000.00, 'EUR', '2024-08-31', '2026-08-31', 60,
 false, 'volume_change',
 'ServiceNow ITSM + CSM modules. 1,200 fulfillers + 8,000 portal users. IT requesting HR Service Delivery module — adds €280k.',
 NULL, NULL, NULL,
 true, false, false),

-- HubSpot — France — €620k — expires 2026-07-31 — PRICE INCREASE 11%
('c2000000-0000-0000-0000-000000000014',
 'f2000000-0000-0000-0000-000000000016', 'b1000000-0000-0000-0000-000000000005', 'e1000000-0000-0000-0000-000000000002',
 'HubSpot Marketing & Sales Hub — France', 'saas_license',
 620000.00, 'EUR', '2025-07-31', '2026-07-31', 30,
 false, 'price_increase',
 '180 Sales Hub Professional + 80 Marketing Hub seats. 11% price increase proposed by HubSpot for 2027.',
 2380.00, 'seat', 260,
 true, true, false),

-- Atlassian — Global HQ — €1.7M — expires 2026-10-15 — CLEAN
('c2000000-0000-0000-0000-000000000015',
 'f2000000-0000-0000-0000-000000000017', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'Atlassian Cloud Enterprise — Global', 'saas_license',
 1700000.00, 'EUR', '2025-10-15', '2026-10-15', 30,
 true, 'clean',
 'Jira Software + Confluence + Jira Service Management. 2,800 seats. Enterprise plan with Atlassian Guard.',
 607.00, 'seat', 2800,
 false, false, false),

-- Zendesk — UK — £480k — expires 2026-09-30 — CLEAN
('c2000000-0000-0000-0000-000000000016',
 'f2000000-0000-0000-0000-000000000018', 'b1000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000001',
 'Zendesk Suite Professional — UK & Ireland', 'saas_license',
 480000.00, 'GBP', '2025-09-30', '2026-09-30', 30,
 true, 'clean',
 '120 agent seats. Customer support platform for UK operations. GDPR DPA signed.',
 4000.00, 'seat', 120,
 false, false, false),

-- Adobe Creative Cloud — Global — €890k — expires 2026-11-30 — VOLUME CHANGE
('c2000000-0000-0000-0000-000000000017',
 'f2000000-0000-0000-0000-000000000020', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'Adobe Creative Cloud — Global', 'saas_license',
 890000.00, 'EUR', '2025-11-30', '2026-11-30', 30,
 false, 'volume_change',
 '420 Creative Cloud All Apps licenses. Marketing requesting 80 additional for new design team in DACH.',
 2120.00, 'seat', 420,
 false, false, false),

-- GitHub Enterprise — Global — €740k — expires 2026-08-01 — CLEAN
('c2000000-0000-0000-0000-000000000018',
 'f2000000-0000-0000-0000-000000000021', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'GitHub Enterprise Cloud — Global', 'saas_license',
 740000.00, 'EUR', '2025-08-01', '2026-08-01', 30,
 true, 'clean',
 '2,100 developer seats. GitHub Actions + Advanced Security included. Copilot Business add-on for 400 senior engineers.',
 352.00, 'seat', 2100,
 true, false, false),

-- CrowdStrike Falcon — Global — €1.4M — expires 2026-12-31 — PRICE INCREASE 9%
('c2000000-0000-0000-0000-000000000019',
 'f2000000-0000-0000-0000-000000000031', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'CrowdStrike Falcon Complete — Global', 'saas_license',
 1400000.00, 'EUR', '2025-01-01', '2026-12-31', 30,
 false, 'price_increase',
 'EDR + MDR for 4,200 endpoints globally. Falcon Complete managed service. 9% renewal increase proposed.',
 333.00, 'seat', 4200,
 false, false, false),

-- Okta Identity — Global — €980k — expires 2027-02-28 — CLEAN
('c2000000-0000-0000-0000-000000000020',
 'f2000000-0000-0000-0000-000000000032', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'Okta Workforce Identity — Global', 'saas_license',
 980000.00, 'EUR', '2025-03-01', '2027-02-28', 30,
 true, 'clean',
 'SSO + MFA for 3,200 users. Includes Okta Privileged Access. SCIM provisioning active for all major apps.',
 306.00, 'seat', 3200,
 false, false, false),

-- Datadog — Global — €820k — expires 2026-09-01 — VOLUME CHANGE
('c2000000-0000-0000-0000-000000000021',
 'f2000000-0000-0000-0000-000000000034', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'Datadog APM & Logs — Global', 'saas_license',
 820000.00, 'EUR', '2025-09-01', '2026-09-01', 30,
 false, 'volume_change',
 'APM, Logs, and Infrastructure monitoring. 40 hosts committed. Engineering requesting scale to 65 hosts for EMEA expansion.',
 20500.00, 'host', 40,
 false, false, false),

-- Splunk SIEM — CEE — €640k — expires 2026-06-30 — SCOPE CHANGE
('c2000000-0000-0000-0000-000000000022',
 'f2000000-0000-0000-0000-000000000033', 'b1000000-0000-0000-0000-000000000009', 'e1000000-0000-0000-0000-000000000003',
 'Splunk SIEM — CEE Security Operations', 'saas_license',
 640000.00, 'EUR', '2024-06-30', '2026-06-30', 60,
 false, 'scope_change',
 'Splunk Enterprise Security, 50GB/day ingest. Cisco acquisition triggered contract novation — new entity must sign.',
 NULL, NULL, NULL,
 true, true, true),

-- 1Password — Global — €180k — expires 2026-10-31 — CLEAN
('c2000000-0000-0000-0000-000000000023',
 'f2000000-0000-0000-0000-000000000030', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 '1Password Business — Global', 'saas_license',
 180000.00, 'EUR', '2025-10-31', '2026-10-31', 30,
 true, 'clean',
 'Password manager for all 3,200 employees. Business plan with admin console and SSO integration.',
 56.00, 'seat', 3200,
 false, false, false),

-- Monday.com — Benelux — €290k — expires 2026-07-15 — MANUAL REQUIRED
('c2000000-0000-0000-0000-000000000024',
 'f2000000-0000-0000-0000-000000000026', 'b1000000-0000-0000-0000-000000000004', 'e1000000-0000-0000-0000-000000000003',
 'Monday.com Enterprise — Benelux', 'saas_license',
 290000.00, 'EUR', '2025-07-15', '2026-07-15', 30,
 false, 'manual_required',
 '600 seats Enterprise. Legal reviewing GDPR transfer mechanism for data processed in Israel. Cannot auto-renew until DPA resolved.',
 483.00, 'seat', 600,
 true, true, true),

-- Asana — Nordics — €210k — expires 2026-11-30 — CLEAN
('c2000000-0000-0000-0000-000000000025',
 'f2000000-0000-0000-0000-000000000027', 'b1000000-0000-0000-0000-000000000006', 'e1000000-0000-0000-0000-000000000004',
 'Asana Business — Nordics', 'saas_license',
 210000.00, 'EUR', '2025-11-30', '2026-11-30', 30,
 true, 'clean',
 '480 seats Business plan. Project management for Nordics operations team.',
 437.00, 'seat', 480,
 false, false, false),

-- SHI International — UK — £340k — expires 2027-06-30 — CLEAN
('c2000000-0000-0000-0000-000000000026',
 'f2000000-0000-0000-0000-000000000072', 'b1000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000001',
 'SHI Software License Management — UK', 'saas_license',
 340000.00, 'GBP', '2025-07-01', '2027-06-30', 60,
 true, 'clean',
 'SAM and license management service. Covers Microsoft, Adobe, Autodesk. Annual true-up mechanism.',
 NULL, NULL, NULL,
 false, false, false),

-- Comarch ERP — CEE — €480k — expires 2026-08-31 — CLEAN
('c2000000-0000-0000-0000-000000000027',
 'f2000000-0000-0000-0000-000000000081', 'b1000000-0000-0000-0000-000000000009', 'e1000000-0000-0000-0000-000000000003',
 'Comarch ERP Modules — CEE', 'saas_license',
 480000.00, 'EUR', '2025-09-01', '2026-08-31', 30,
 true, 'clean',
 'Comarch ERP XT for CEE subsidiary operations. Finance + WMS modules. Local regulatory compliance maintained.',
 NULL, NULL, NULL,
 false, false, false),

-- ============================================================
-- SERVICES CONTRACTS
-- ============================================================

-- Deloitte — Global HQ — €3.2M — expires 2026-09-30 — CLEAN
('c2000000-0000-0000-0000-000000000028',
 'f2000000-0000-0000-0000-000000000036', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'Deloitte Tax Advisory — Global', 'services',
 3200000.00, 'EUR', '2024-09-30', '2026-09-30', 60,
 false, 'clean',
 'Transfer pricing, tax advisory, and regulatory reporting. Annual retainer + project fees. Audit separation maintained.',
 NULL, NULL, NULL,
 false, false, false),

-- PwC — Global HQ — €2.1M — expires 2026-12-31 — CLEAN
('c2000000-0000-0000-0000-000000000029',
 'f2000000-0000-0000-0000-000000000037', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'PwC CFO Advisory — Global', 'services',
 2100000.00, 'EUR', '2025-01-01', '2026-12-31', 60,
 false, 'clean',
 'CFO strategy and finance transformation. Fixed fee per milestone. Quarterly steering committee.',
 NULL, NULL, NULL,
 false, false, false),

-- McKinsey — Global HQ — €4.8M — expires 2026-08-31 — PRICE INCREASE 15%
('c2000000-0000-0000-0000-000000000030',
 'f2000000-0000-0000-0000-000000000038', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'McKinsey Digital Strategy — Global', 'services',
 4800000.00, 'EUR', '2024-08-31', '2026-08-31', 60,
 false, 'price_increase',
 'Digital procurement transformation. 15% daily rate increase proposed by McKinsey. Board must approve over €5M threshold.',
 NULL, NULL, NULL,
 true, false, false),

-- Capgemini — DACH — €6.2M — expires 2026-10-31 — VOLUME CHANGE
('c2000000-0000-0000-0000-000000000031',
 'f2000000-0000-0000-0000-000000000040', 'b1000000-0000-0000-0000-000000000002', 'e1000000-0000-0000-0000-000000000003',
 'Capgemini IT Transformation — DACH', 'services',
 6200000.00, 'EUR', '2024-10-31', '2026-10-31', 90,
 false, 'volume_change',
 'SAP S/4HANA implementation DACH. Phase 2 scope expansion requested — adds €1.1M and 6-month extension.',
 NULL, NULL, NULL,
 true, false, false),

-- TCS — UK — £3.9M — expires 2027-03-31 — CLEAN
('c2000000-0000-0000-0000-000000000032',
 'f2000000-0000-0000-0000-000000000041', 'b1000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000001',
 'TCS Application Managed Services — UK', 'services',
 3900000.00, 'GBP', '2025-04-01', '2027-03-31', 90,
 true, 'clean',
 '24/7 application support for core banking and ERP. SLA: 99.2% uptime, P1 response 15 min. 3-year term.',
 NULL, NULL, NULL,
 false, false, false),

-- EY — Global HQ — €1.6M — expires 2026-11-30 — CLEAN
('c2000000-0000-0000-0000-000000000033',
 'f2000000-0000-0000-0000-000000000044', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'EY Internal Audit Co-Sourcing — Global', 'services',
 1600000.00, 'EUR', '2025-12-01', '2026-11-30', 60,
 true, 'clean',
 'Co-sourced internal audit for IT and finance. 3 EY seniors embedded in audit team. Annual plan agreed with Audit Committee.',
 NULL, NULL, NULL,
 false, false, false),

-- Linklaters — DACH — €940k — expires 2026-06-30 — SCOPE CHANGE
('c2000000-0000-0000-0000-000000000034',
 'f2000000-0000-0000-0000-000000000045', 'b1000000-0000-0000-0000-000000000002', 'e1000000-0000-0000-0000-000000000003',
 'Linklaters M&A Legal Advisory — DACH', 'services',
 940000.00, 'EUR', '2024-07-01', '2026-06-30', 30,
 false, 'scope_change',
 'M&A advisory retainer. Target acquisition in Austria added — scope change requires new engagement letter and budget approval.',
 NULL, NULL, NULL,
 true, true, true),

-- Hays Staffing — Global HQ — €2.8M — expires 2027-12-31 — CLEAN
('c2000000-0000-0000-0000-000000000035',
 'f2000000-0000-0000-0000-000000000048', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'Hays IT Staffing Framework — Global', 'services',
 2800000.00, 'EUR', '2026-01-01', '2027-12-31', 90,
 true, 'clean',
 'Preferred supplier framework for IT contractor sourcing. Rate cards for 42 skill profiles. 48h time-to-profile SLA.',
 NULL, NULL, NULL,
 false, false, false),

-- NTT Data Spain — Iberia — €780k — expires 2026-09-30 — CLEAN
('c2000000-0000-0000-0000-000000000036',
 'f2000000-0000-0000-0000-000000000078', 'b1000000-0000-0000-0000-000000000007', 'e1000000-0000-0000-0000-000000000002',
 'NTT Data SAP Support — Iberia', 'services',
 780000.00, 'EUR', '2025-10-01', '2026-09-30', 30,
 true, 'clean',
 'SAP ECC support and basis services for Iberia subsidiary. Local language support included.',
 NULL, NULL, NULL,
 false, false, false),

-- Almaviva BPO — Italy — €1.2M — expires 2026-12-31 — PRICE INCREASE 7%
('c2000000-0000-0000-0000-000000000037',
 'f2000000-0000-0000-0000-000000000080', 'b1000000-0000-0000-0000-000000000008', 'e1000000-0000-0000-0000-000000000002',
 'Almaviva BPO Contact Centre — Italy', 'services',
 1200000.00, 'EUR', '2024-12-31', '2026-12-31', 60,
 false, 'price_increase',
 'Customer support BPO Italy. 7% FTE cost increase proposed reflecting Italian national wage agreement.',
 NULL, NULL, NULL,
 false, false, false),

-- ============================================================
-- FACILITIES CONTRACTS
-- ============================================================

-- CBRE — Global HQ — €5.8M — expires 2028-12-31 — CLEAN (long-term)
('c2000000-0000-0000-0000-000000000038',
 'f2000000-0000-0000-0000-000000000051', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000005',
 'CBRE Facility Management — Global HQ', 'facilities',
 5800000.00, 'EUR', '2024-01-01', '2028-12-31', 180,
 true, 'clean',
 'Integrated FM for Global HQ and 4 major offices. Hard FM, soft FM, space management. 5-year strategic partnership.',
 NULL, NULL, NULL,
 false, false, false),

-- ISS — DACH — €2.1M — expires 2026-10-31 — PRICE INCREASE 5%
('c2000000-0000-0000-0000-000000000039',
 'f2000000-0000-0000-0000-000000000052', 'b1000000-0000-0000-0000-000000000002', 'e1000000-0000-0000-0000-000000000005',
 'ISS Cleaning & Catering — DACH', 'facilities',
 2100000.00, 'EUR', '2024-10-31', '2026-10-31', 30,
 false, 'price_increase',
 'Office cleaning and staff catering 3 DACH sites. 5% annual CPI increase at renewal.',
 NULL, NULL, NULL,
 true, false, false),

-- DHL — Global HQ — €1.4M — expires 2026-08-31 — CLEAN
('c2000000-0000-0000-0000-000000000040',
 'f2000000-0000-0000-0000-000000000054', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000005',
 'DHL Express & Courier — Global', 'facilities',
 1400000.00, 'EUR', '2025-09-01', '2026-08-31', 30,
 true, 'clean',
 'Global parcel and express courier framework. Next-day DACH, 48h EU, standard international.',
 NULL, NULL, NULL,
 false, false, false),

-- DB Schenker — Global HQ — €3.2M — expires 2027-06-30 — CLEAN
('c2000000-0000-0000-0000-000000000041',
 'f2000000-0000-0000-0000-000000000056', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000005',
 'DB Schenker Freight & Logistics — Global', 'facilities',
 3200000.00, 'EUR', '2025-07-01', '2027-06-30', 90,
 true, 'clean',
 'Air, ocean, and road freight framework. Preferred supplier for EMEA cross-border logistics.',
 NULL, NULL, NULL,
 false, false, false),

-- Bilfinger Technical FM — CEE — €880k — expires 2026-07-31 — CLEAN
('c2000000-0000-0000-0000-000000000042',
 'f2000000-0000-0000-0000-000000000058', 'b1000000-0000-0000-0000-000000000009', 'e1000000-0000-0000-0000-000000000005',
 'Bilfinger Technical FM — CEE', 'facilities',
 880000.00, 'EUR', '2024-07-31', '2026-07-31', 30,
 true, 'clean',
 'HVAC, electrical, and critical systems maintenance for CEE offices.',
 NULL, NULL, NULL,
 true, true, false),

-- ============================================================
-- TELECOMS CONTRACTS
-- ============================================================

-- O2 Telefónica — DACH — €1.1M — expires 2026-09-30 — PRICE INCREASE 8%
('c2000000-0000-0000-0000-000000000043',
 'f2000000-0000-0000-0000-000000000061', 'b1000000-0000-0000-0000-000000000002', 'e1000000-0000-0000-0000-000000000003',
 'O2 Mobile Fleet — DACH', 'telecoms',
 1100000.00, 'EUR', '2024-09-30', '2026-09-30', 30,
 false, 'price_increase',
 '1,400 SIMs DACH mobile fleet. 5G enterprise tariff. 8% increase proposed at renewal.',
 786.00, 'sim', 1400,
 true, false, false),

-- Orange Business — Global — €2.8M — expires 2027-04-30 — CLEAN
('c2000000-0000-0000-0000-000000000044',
 'f2000000-0000-0000-0000-000000000062', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'Orange Business MPLS — Global', 'telecoms',
 2800000.00, 'EUR', '2025-05-01', '2027-04-30', 90,
 true, 'clean',
 'MPLS backbone 22 sites across EMEA. SLA 99.7%. SD-WAN overlay upgrade included in new term.',
 NULL, NULL, NULL,
 false, false, false),

-- Tele2 — Nordics — SEK 4.8M — expires 2026-10-31 — CLEAN
('c2000000-0000-0000-0000-000000000045',
 'f2000000-0000-0000-0000-000000000063', 'b1000000-0000-0000-0000-000000000006', 'e1000000-0000-0000-0000-000000000004',
 'Tele2 Mobile & Fixed — Nordics', 'telecoms',
 4800000.00, 'SEK', '2025-10-31', '2026-10-31', 30,
 true, 'clean',
 '680 SIM mobile fleet + fixed office broadband 6 Nordics offices.',
 NULL, NULL, NULL,
 false, false, false),

-- KPN — Benelux — €680k — expires 2026-08-31 — CLEAN
('c2000000-0000-0000-0000-000000000046',
 'f2000000-0000-0000-0000-000000000075', 'b1000000-0000-0000-0000-000000000004', 'e1000000-0000-0000-0000-000000000003',
 'KPN Enterprise Connectivity — Benelux', 'telecoms',
 680000.00, 'EUR', '2025-09-01', '2026-08-31', 30,
 true, 'clean',
 'Fibre internet + voice Benelux offices. SLA 99.9% availability.',
 NULL, NULL, NULL,
 false, false, false),

-- Telefónica España — Iberia — €590k — expires 2027-01-31 — CLEAN
('c2000000-0000-0000-0000-000000000047',
 'f2000000-0000-0000-0000-000000000077', 'b1000000-0000-0000-0000-000000000007', 'e1000000-0000-0000-0000-000000000002',
 'Telefónica Spain Mobile & Broadband — Iberia', 'telecoms',
 590000.00, 'EUR', '2026-02-01', '2027-01-31', 30,
 true, 'clean',
 'Spain + Portugal mobile fleet 380 SIMs + office connectivity 3 sites.',
 NULL, NULL, NULL,
 false, false, false),

-- Colt SD-WAN — Global — €1.6M — expires 2026-07-31 — SCOPE CHANGE
('c2000000-0000-0000-0000-000000000048',
 'f2000000-0000-0000-0000-000000000065', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'Colt SD-WAN Pilot — Global', 'telecoms',
 1600000.00, 'EUR', '2025-07-31', '2026-07-31', 30,
 false, 'scope_change',
 'SD-WAN pilot 5 sites. IT proposing full rollout to 22 sites — scope change adds €4.2M over 3 years.',
 NULL, NULL, NULL,
 true, true, false),

-- Elisa — Nordics East — €280k — expires 2026-11-30 — CLEAN
('c2000000-0000-0000-0000-000000000049',
 'f2000000-0000-0000-0000-000000000082', 'b1000000-0000-0000-0000-000000000010', 'e1000000-0000-0000-0000-000000000004',
 'Elisa Enterprise — Nordics East', 'telecoms',
 280000.00, 'EUR', '2025-12-01', '2026-11-30', 30,
 true, 'clean',
 'Finland mobile fleet 180 SIMs + Helsinki HQ broadband. SLA 99.8%.',
 NULL, NULL, NULL,
 false, false, false),

-- ============================================================
-- AI / LLM CONSUMPTION CONTRACTS
-- ============================================================

-- Anthropic — Global — €960k — expires 2026-12-31 — VOLUME CHANGE
('c2000000-0000-0000-0000-000000000050',
 'f2000000-0000-0000-0000-000000000066', 'b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
 'Anthropic Claude API — Global', 'other',
 960000.00, 'EUR', '2026-01-01', '2026-12-31', 30,
 false, 'volume_change',
 'Claude API committed spend tier. Current: €80k/month. TrueSpend procAI expansion and new use cases require uplift to €140k/month.',
 NULL, NULL, NULL,
 false, false, false)

on conflict (id) do update set
  name          = excluded.name,
  category      = excluded.category,
  value         = excluded.value,
  expiry_date   = excluded.expiry_date,
  renewal_state = excluded.renewal_state,
  terms_summary = excluded.terms_summary;
