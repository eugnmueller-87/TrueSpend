-- TrueSpend Simulation Seed — Contracts
-- 30 contracts across 10 branches
-- Deliberately spread across all 3 renewal states and all alert thresholds
-- Today = 2026-05-27

insert into contracts (
  id, supplier_id, branch_id, owner_id, name, category,
  value, currency, start_date, expiry_date, notice_days,
  auto_renew, renewal_state, terms_summary,
  price_per_unit, unit_type, volume,
  alert_90_sent, alert_60_sent, alert_30_sent
) values

-- ============================================================
-- CLEAN RENEWALS — auto-renew eligible, nothing changed
-- ============================================================

  -- Dell — Global HQ — €18M — expiring in 45 days — CLEAN
  ('c1000000-0000-0000-0000-000000000001',
   's1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'm1000000-0000-0000-0000-000000000001',
   'Dell Hardware Framework — Global HQ', 'hardware',
   18000000.00, 'EUR', '2024-07-12', '2026-07-11', 60,
   true, 'clean',
   'Global framework agreement — workstations, laptops, servers. Volume pricing locked through contract period. 60-day notice for cancellation.',
   NULL, NULL, NULL,
   true, true, false),

  -- Microsoft 365 — DACH — €2.1M — expiring in 72 days — CLEAN
  ('c1000000-0000-0000-0000-000000000002',
   's1000000-0000-0000-0000-000000000007', 'b1000000-0000-0000-0000-000000000002', 'm1000000-0000-0000-0000-000000000003',
   'Microsoft 365 E3 — DACH', 'saas_license',
   2100000.00, 'EUR', '2025-08-07', '2026-08-06', 30,
   true, 'clean',
   '1,400 seats E3 license. Auto-renewal unless cancelled 30 days prior. Price locked per seat.',
   1500.00, 'seat', 1400,
   true, false, false),

  -- Securitas — Germany — €480k — expiring in 85 days — CLEAN
  ('c1000000-0000-0000-0000-000000000003',
   's1000000-0000-0000-0000-000000000015', 'b1000000-0000-0000-0000-000000000002', 'm1000000-0000-0000-0000-000000000005',
   'Securitas Security Services — DACH HQ', 'facilities',
   480000.00, 'EUR', '2024-08-20', '2026-08-19', 30,
   true, 'clean',
   'Security guarding services, DACH HQ and warehouse. Fixed monthly rate. Annual CPI escalation capped at 3%.',
   NULL, NULL, NULL,
   true, false, false),

  -- Slack — Nordics — €310k — expiring in 88 days — CLEAN
  ('c1000000-0000-0000-0000-000000000004',
   's1000000-0000-0000-0000-000000000011', 'b1000000-0000-0000-0000-000000000006', 'm1000000-0000-0000-0000-000000000004',
   'Slack Business+ — Nordics', 'saas_license',
   310000.00, 'EUR', '2025-08-24', '2026-08-23', 30,
   true, 'clean',
   '620 seats Business+ plan. 30-day cancellation notice.',
   500.00, 'seat', 620,
   true, false, false),

  -- Deutsche Telekom — CEE — €720k — expiring in 62 days — CLEAN
  ('c1000000-0000-0000-0000-000000000005',
   's1000000-0000-0000-0000-000000000016', 'b1000000-0000-0000-0000-000000000009', 'm1000000-0000-0000-0000-000000000003',
   'Deutsche Telekom Connectivity — CEE', 'telecoms',
   720000.00, 'EUR', '2024-07-26', '2026-07-25', 45,
   true, 'clean',
   'MPLS connectivity across 8 CEE sites. SLA 99.5% uptime. Bandwidth upgrades at contract rate.',
   NULL, NULL, NULL,
   true, true, false),

-- ============================================================
-- PRICE INCREASES — supplier proposed increase, agent must reason
-- ============================================================

  -- Apple — UK — £4.2M — expiring in 28 days — PRICE INCREASE 9%
  ('c1000000-0000-0000-0000-000000000006',
   's1000000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000003', 'm1000000-0000-0000-0000-000000000001',
   'Apple Device Program — UK & Ireland', 'hardware',
   4200000.00, 'GBP', '2024-05-29', '2026-05-28', 30,
   false, 'price_increase',
   'MacBook Pro, iPad, iPhone fleet for UK operations. Volume tier 500+ devices.',
   NULL, NULL, NULL,
   true, true, true),

  -- Salesforce — France — €1.8M — expiring in 35 days — PRICE INCREASE 12%
  ('c1000000-0000-0000-0000-000000000007',
   's1000000-0000-0000-0000-000000000008', 'b1000000-0000-0000-0000-000000000005', 'm1000000-0000-0000-0000-000000000002',
   'Salesforce Sales Cloud — France', 'saas_license',
   1800000.00, 'EUR', '2025-06-01', '2026-06-30', 30,
   false, 'price_increase',
   '300 Sales Cloud Enterprise seats. Annual renewal. Price increase proposed for 2026.',
   6000.00, 'seat', 300,
   true, true, true),

  -- SAP — Global HQ — €6.4M — expiring in 55 days — PRICE INCREASE 7%
  ('c1000000-0000-0000-0000-000000000008',
   's1000000-0000-0000-0000-000000000009', 'b1000000-0000-0000-0000-000000000001', 'm1000000-0000-0000-0000-000000000001',
   'SAP S/4HANA Enterprise License — Global', 'saas_license',
   6400000.00, 'EUR', '2024-07-13', '2026-07-12', 60,
   false, 'price_increase',
   'Global S/4HANA license. Includes all modules. 7% increase proposed citing CPI + development costs.',
   NULL, NULL, NULL,
   true, true, false),

  -- Vodafone — Italy — €290k — expiring in 18 days — PRICE INCREASE 15% + SLA RED
  ('c1000000-0000-0000-0000-000000000009',
   's1000000-0000-0000-0000-000000000017', 'b1000000-0000-0000-0000-000000000008', 'm1000000-0000-0000-0000-000000000002',
   'Vodafone Mobile Fleet — Italy', 'telecoms',
   290000.00, 'EUR', '2024-05-27', '2026-06-14', 30,
   false, 'manual_required',
   'Mobile fleet Italy — 180 SIMs. 15% increase proposed. Supplier currently in SLA breach (Feb outage).',
   NULL, NULL, NULL,
   true, true, true),

  -- Zoom — Benelux — €180k — expiring in 40 days — PRICE INCREASE 8%
  ('c1000000-0000-0000-0000-000000000010',
   's1000000-0000-0000-0000-000000000012', 'b1000000-0000-0000-0000-000000000004', 'm1000000-0000-0000-0000-000000000003',
   'Zoom Business — Benelux', 'saas_license',
   180000.00, 'EUR', '2025-06-05', '2026-07-04', 30,
   false, 'price_increase',
   '360 Zoom Business seats. Annual renewal. 8% increase proposed.',
   500.00, 'seat', 360,
   true, true, false),

-- ============================================================
-- VOLUME CHANGES — additional licenses or units requested
-- ============================================================

  -- Lenovo — DACH — €8.2M — expiring in 66 days — VOLUME INCREASE +200 devices
  ('c1000000-0000-0000-0000-000000000011',
   's1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000002', 'm1000000-0000-0000-0000-000000000003',
   'Lenovo ThinkPad Fleet — DACH', 'hardware',
   8200000.00, 'EUR', '2024-08-01', '2026-07-31', 45,
   false, 'volume_change',
   'ThinkPad T-series fleet for DACH. 1,600 devices contracted. Engineering requesting 200 additional — triggers next volume tier.',
   5125.00, 'device', 1600,
   true, true, false),

  -- Microsoft 365 — UK — £1.4M — expiring in 50 days — VOLUME INCREASE +300 seats
  ('c1000000-0000-0000-0000-000000000012',
   's1000000-0000-0000-0000-000000000007', 'b1000000-0000-0000-0000-000000000003', 'm1000000-0000-0000-0000-000000000001',
   'Microsoft 365 E5 — UK & Ireland', 'saas_license',
   1400000.00, 'GBP', '2025-07-16', '2026-07-15', 30,
   false, 'volume_change',
   '700 seats E5. HR requesting 300 more for new hires Q3. 1,000 seat threshold triggers renegotiation clause.',
   2000.00, 'seat', 700,
   true, true, false),

  -- Workday — Global HQ — €2.8M — expiring in 75 days — VOLUME CHANGE (new modules)
  ('c1000000-0000-0000-0000-000000000013',
   's1000000-0000-0000-0000-000000000010', 'b1000000-0000-0000-0000-000000000001', 'm1000000-0000-0000-0000-000000000001',
   'Workday HCM + Finance — Global', 'saas_license',
   2800000.00, 'EUR', '2024-08-12', '2026-08-11', 60,
   false, 'volume_change',
   'HCM + Finance modules. IT requesting Workday Extend module addition at renewal — adds €340k annually.',
   NULL, NULL, NULL,
   true, false, false),

-- ============================================================
-- HYPERSCALER CONTRACTS — commitment-based, monitored separately
-- ============================================================

  -- AWS EDP — Global HQ — €12M/year — expiring in 180 days
  ('c1000000-0000-0000-0000-000000000014',
   's1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000001', 'm1000000-0000-0000-0000-000000000001',
   'AWS Enterprise Discount Program — Global', 'hyperscaler',
   12000000.00, 'EUR', '2025-11-27', '2026-11-26', 90,
   false, 'clean',
   'AWS EDP — €12M annual commit. 18% discount vs list price. Usage review quarterly.',
   NULL, NULL, NULL,
   false, false, false),

  -- GCP CUD — DACH — €4.8M/year — expiring in 210 days
  ('c1000000-0000-0000-0000-000000000015',
   's1000000-0000-0000-0000-000000000005', 'b1000000-0000-0000-0000-000000000002', 'm1000000-0000-0000-0000-000000000003',
   'GCP Committed Use — DACH Engineering', 'hyperscaler',
   4800000.00, 'EUR', '2025-10-27', '2026-10-26', 90,
   false, 'clean',
   'GCP 1-year CUD for compute. n2-standard-32 family. 37% discount vs on-demand.',
   NULL, NULL, NULL,
   false, false, false),

  -- Azure — UK — £3.1M/year — expiring in 160 days — LOW UTILIZATION
  ('c1000000-0000-0000-0000-000000000016',
   's1000000-0000-0000-0000-000000000006', 'b1000000-0000-0000-0000-000000000003', 'm1000000-0000-0000-0000-000000000001',
   'Azure Reserved Instances — UK', 'hyperscaler',
   3100000.00, 'GBP', '2025-12-07', '2026-12-06', 90,
   false, 'clean',
   'Azure 1-year reservations — D-series and E-series VMs. Current utilization 67% — below 80% target.',
   NULL, NULL, NULL,
   false, false, false),

-- ============================================================
-- SERVICES — consulting and professional services
-- ============================================================

  -- Accenture — Global HQ — €3.6M — expiring in 48 days — SCOPE CHANGE
  ('c1000000-0000-0000-0000-000000000017',
   's1000000-0000-0000-0000-000000000013', 'b1000000-0000-0000-0000-000000000001', 'm1000000-0000-0000-0000-000000000001',
   'Accenture Digital Transformation SOW', 'services',
   3600000.00, 'EUR', '2025-06-02', '2026-07-14', 60,
   false, 'scope_change',
   'Digital transformation program — 3 workstreams. SOW renewal with 2 additional workstreams proposed by Accenture. Represents 40% scope increase.',
   NULL, NULL, NULL,
   true, true, false),

  -- KPMG — Global HQ — €920k — expiring in 92 days — CLEAN
  ('c1000000-0000-0000-0000-000000000018',
   's1000000-0000-0000-0000-000000000014', 'b1000000-0000-0000-0000-000000000001', 'm1000000-0000-0000-0000-000000000001',
   'KPMG Annual Audit — Global', 'services',
   920000.00, 'EUR', '2025-08-27', '2026-08-26', 60,
   true, 'clean',
   'Annual statutory audit engagement. Same scope as prior year. Fee agreed.',
   NULL, NULL, NULL,
   true, false, false),

-- ============================================================
-- LONGER HORIZON — not yet in alert window but tracked
-- ============================================================

  -- Dell — DACH — €6.4M — expiring in 240 days
  ('c1000000-0000-0000-0000-000000000019',
   's1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'm1000000-0000-0000-0000-000000000003',
   'Dell Server Infrastructure — DACH DC', 'hardware',
   6400000.00, 'EUR', '2025-01-26', '2027-01-25', 60,
   false, 'clean',
   'Data center server refresh — PowerEdge fleet. 3-year contract. Hardware refresh cycle.',
   NULL, NULL, NULL,
   false, false, false),

  -- Lenovo — Nordics — €1.9M — expiring in 310 days
  ('c1000000-0000-0000-0000-000000000020',
   's1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000006', 'm1000000-0000-0000-0000-000000000004',
   'Lenovo Device Fleet — Nordics', 'hardware',
   1900000.00, 'EUR', '2025-07-01', '2027-03-31', 45,
   false, 'clean',
   '370 ThinkPad devices. 2-year contract.',
   NULL, NULL, NULL,
   false, false, false);
