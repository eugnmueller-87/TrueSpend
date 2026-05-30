-- =============================================================================
-- TrueSpend — 12_big_mock_data.sql
-- Comprehensive test data for end-to-end testing across ALL user profiles.
-- Run AFTER 01–11 seeds. Safe to re-run (ON CONFLICT DO NOTHING / DO UPDATE).
--
-- USER PROFILES COVERED:
--   Klaus Weber     (e1000000-...000000)  CFO — budget, approvals, escalations
--   Sarah Brennan   (e1000000-...000001)  Head of Procurement — full board
--   Marc Dupont     (e1000000-...000002)  Category Manager — Southern Europe
--   Lena Hoffmann   (e1000000-...000003)  Category Manager — DACH/Benelux/CEE
--   Erik Lindqvist  (e1000000-...000004)  Category Manager — Nordics
--   Priya Nair      (e1000000-...000005)  Ops Manager — routine approvals
--   Thomas Müller   (e1000000-...000006)  IT Manager — licenses + assets
--   Jana Schmidt    (e1000000-...000007)  Requester — intake form submissions
--
-- PROCESSES COVERED END-TO-END:
--   P2I:          Request → PO → delivery → invoice → payment → ERP queue
--   Assets:       Acquisition → assignment → depreciation → EOL alert
--   Licenses:     Entitlement → assignment → shelfware → reclaim
--   Hyperscaler:  Commitment → monthly burn → anomaly
--   Compliance:   Onboarding → NDA → DPA → InfoSec → LkSG
--   Contracts:    Expiring → price increase → manual → auto-renew
--   LLM:          API keys → daily consumption → anomaly → budget charge
--   Monitoring:   VPS alerts → duplicate suppression → resolution
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. ADDITIONAL COST CENTERS (extend existing 7)
-- ─────────────────────────────────────────────────────────────────────────────
insert into cost_centers (id, code, name, branch_id) values
  ('cc000000-0000-0000-0000-000000000008', 'LEGAL-HQ',  'Legal & Compliance HQ',  'b1000000-0000-0000-0000-000000000001'),
  ('cc000000-0000-0000-0000-000000000009', 'HR-HQ',     'Human Resources HQ',     'b1000000-0000-0000-0000-000000000001'),
  ('cc000000-0000-0000-0000-000000000010', 'ENG-DACH',  'Engineering DACH',       'b1000000-0000-0000-0000-000000000002'),
  ('cc000000-0000-0000-0000-000000000011', 'OPS-NORD',  'Operations Nordics',     'b1000000-0000-0000-0000-000000000006'),
  ('cc000000-0000-0000-0000-000000000012', 'IT-CEE',    'IT CEE',                 'b1000000-0000-0000-0000-000000000009'),
  ('cc000000-0000-0000-0000-000000000013', 'SALES-FR',  'Sales France',           'b1000000-0000-0000-0000-000000000005'),
  ('cc000000-0000-0000-0000-000000000014', 'IT-BNL',    'IT Benelux',             'b1000000-0000-0000-0000-000000000004')
on conflict (id) do update set code = excluded.code, name = excluded.name;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. BUDGET POOLS (CFO lever — reserve funds)
-- ─────────────────────────────────────────────────────────────────────────────
insert into budget_pools (id, name, branch_id, fiscal_year, total_amount, committed, draw_authority, notes) values
  ('bp000000-0000-0000-0000-000000000001',
   'HQ Strategic Reserve 2026', 'b1000000-0000-0000-0000-000000000001', 2026,
   2500000.00, 400000.00, 'cfo',
   'Emergency + strategic spend. CFO draw only. Last draw: €400k for Accenture Phase 3.'),
  ('bp000000-0000-0000-0000-000000000002',
   'DACH Flex Pool 2026', 'b1000000-0000-0000-0000-000000000002', 2026,
   800000.00, 0.00, 'head_of_procurement',
   'DACH uncommitted reserve for Q3/Q4 catch-up. Head of Procurement authority.'),
  ('bp000000-0000-0000-0000-000000000003',
   'Nordics Growth Reserve 2026', 'b1000000-0000-0000-0000-000000000006', 2026,
   350000.00, 120000.00, 'head_of_procurement',
   'Nordics expansion headroom. €120k committed for pending hardware order.')
on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. BUDGET POSITIONS (running ledger — all active periods)
--    Covers all branches with realistic committed/spent ratios
-- ─────────────────────────────────────────────────────────────────────────────
insert into budget_positions (id, branch_id, cost_center_id, category, period, budget, committed, spent) values
  -- Global HQ 2026-Q2
  ('bpos0000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001', 'hardware',            '2026-Q2', 8000000.00,  284400.00,  1420000.00),
  ('bpos0000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001', 'hyperscaler',         '2026-Q2', 4000000.00,   89000.00,  2180000.00),
  ('bpos0000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001', 'saas_license',        '2026-Q2', 3200000.00,  180000.00,  1960000.00),
  ('bpos0000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000002', 'services',            '2026-Q2', 2400000.00,  180000.00,   840000.00),
  ('bpos0000-0000-0000-0000-000000000005', 'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001', 'ai_consumption',      '2026-Q2',  420000.00,   48000.00,   210600.00),
  ('bpos0000-0000-0000-0000-000000000006', 'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000008', 'legal',               '2026-Q2',  280000.00,    0.00,       95000.00),
  -- DACH 2026-Q2
  ('bpos0000-0000-0000-0000-000000000007', 'b1000000-0000-0000-0000-000000000002', 'cc000000-0000-0000-0000-000000000003', 'hardware',            '2026-Q2', 5000000.00,  205000.00,  2340000.00),
  ('bpos0000-0000-0000-0000-000000000008', 'b1000000-0000-0000-0000-000000000002', 'cc000000-0000-0000-0000-000000000003', 'saas_license',        '2026-Q2', 1400000.00,   72000.00,   940000.00),
  ('bpos0000-0000-0000-0000-000000000009', 'b1000000-0000-0000-0000-000000000002', 'cc000000-0000-0000-0000-000000000010', 'ai_consumption',      '2026-Q2',  180000.00,   24000.00,    71610.00),
  ('bpos0000-0000-0000-0000-000000000010', 'b1000000-0000-0000-0000-000000000002', 'cc000000-0000-0000-0000-000000000003', 'facilities',          '2026-Q2',  120000.00,    0.00,       80000.00),
  -- UK 2026-Q2
  ('bpos0000-0000-0000-0000-000000000011', 'b1000000-0000-0000-0000-000000000003', 'cc000000-0000-0000-0000-000000000005', 'hardware',            '2026-Q2', 2200000.00,  109200.00,   680000.00),
  ('bpos0000-0000-0000-0000-000000000012', 'b1000000-0000-0000-0000-000000000003', 'cc000000-0000-0000-0000-000000000005', 'saas_license',        '2026-Q2',  900000.00,    0.00,      620000.00),
  -- France 2026-Q2
  ('bpos0000-0000-0000-0000-000000000013', 'b1000000-0000-0000-0000-000000000005', 'cc000000-0000-0000-0000-000000000007', 'saas_license',        '2026-Q2',  900000.00,   72000.00,   730000.00),
  ('bpos0000-0000-0000-0000-000000000014', 'b1000000-0000-0000-0000-000000000005', 'cc000000-0000-0000-0000-000000000013', 'ai_consumption',      '2026-Q2',   62000.00,   18000.00,    59520.00),
  -- Nordics 2026-Q2
  ('bpos0000-0000-0000-0000-000000000015', 'b1000000-0000-0000-0000-000000000006', 'cc000000-0000-0000-0000-000000000011', 'hardware',            '2026-Q2',  480000.00,  120000.00,   190000.00),
  ('bpos0000-0000-0000-0000-000000000016', 'b1000000-0000-0000-0000-000000000006', 'cc000000-0000-0000-0000-000000000011', 'saas_license',        '2026-Q2',  310000.00,    0.00,      210000.00),
  -- Benelux 2026-Q2
  ('bpos0000-0000-0000-0000-000000000017', 'b1000000-0000-0000-0000-000000000004', 'cc000000-0000-0000-0000-000000000014', 'saas_license',        '2026-Q2',  240000.00,    0.00,      155000.00),
  ('bpos0000-0000-0000-0000-000000000018', 'b1000000-0000-0000-0000-000000000004', 'cc000000-0000-0000-0000-000000000006', 'hardware',            '2026-Q2',  380000.00,    0.00,      220000.00),
  -- CEE 2026-Q2
  ('bpos0000-0000-0000-0000-000000000019', 'b1000000-0000-0000-0000-000000000009', 'cc000000-0000-0000-0000-000000000012', 'hardware',            '2026-Q2',  290000.00,    0.00,      140000.00),
  ('bpos0000-0000-0000-0000-000000000020', 'b1000000-0000-0000-0000-000000000009', 'cc000000-0000-0000-0000-000000000012', 'telecoms',            '2026-Q2',  180000.00,    0.00,      125000.00)
on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. ASSETS — Hardware register with depreciation state
--    Covers: active laptops, servers with accumulated depreciation,
--            warranty alerts (90 + 30 day), near-EOL assets
-- ─────────────────────────────────────────────────────────────────────────────
insert into assets (
  id, asset_tag, category, make, model, serial_number, specs,
  po_id, purchase_date, purchase_cost, currency, purchase_cost_eur,
  depreciation_method, useful_life_months, residual_value,
  accumulated_depreciation, current_book_value,
  warranty_expiry, warranty_tier, warranty_provider,
  branch_id, cost_center_id, assigned_user, assigned_at,
  last_active_date, incident_count, status
) values

  -- ── DACH Engineering Laptops (Lenovo ThinkPad T14s) ──
  ('as000000-0000-0000-0000-000000000001', 'DACH-LT-0001', 'laptop',
   'Lenovo', 'ThinkPad T14s Gen4', 'SN-LNV-DACH-0001',
   '{"cpu":"AMD Ryzen 7 7730U","ram_gb":16,"storage_gb":512,"os":"Windows 11 Pro"}'::jsonb,
   'a8000000-0000-0000-0000-000000000002', '2024-09-01', 1890.00, 'EUR', 1890.00,
   'straight_line', 36, 0.00,
   1050.00, 840.00,
   '2027-09-01', 'premium', 'Lenovo On-Site',
   'b1000000-0000-0000-0000-000000000002', 'cc000000-0000-0000-0000-000000000010',
   'thomas.mueller@company.com', '2024-09-15',
   '2026-05-29', 0, 'active'),

  ('as000000-0000-0000-0000-000000000002', 'DACH-LT-0002', 'laptop',
   'Lenovo', 'ThinkPad T14s Gen4', 'SN-LNV-DACH-0002',
   '{"cpu":"AMD Ryzen 7 7730U","ram_gb":16,"storage_gb":512,"os":"Windows 11 Pro"}'::jsonb,
   'a8000000-0000-0000-0000-000000000002', '2024-09-01', 1890.00, 'EUR', 1890.00,
   'straight_line', 36, 0.00,
   1050.00, 840.00,
   '2027-09-01', 'premium', 'Lenovo On-Site',
   'b1000000-0000-0000-0000-000000000002', 'cc000000-0000-0000-0000-000000000010',
   'jana.schmidt@company.com', '2024-09-15',
   '2026-05-28', 1, 'active'),

  ('as000000-0000-0000-0000-000000000003', 'DACH-LT-0003', 'laptop',
   'Lenovo', 'ThinkPad T14s Gen3', 'SN-LNV-DACH-0003',
   '{"cpu":"Intel Core i7-1265U","ram_gb":16,"storage_gb":256,"os":"Windows 11 Pro"}'::jsonb,
   null, '2023-03-10', 1650.00, 'EUR', 1650.00,
   'straight_line', 36, 0.00,
   1237.50, 412.50,
   '2026-03-10', 'basic', 'Lenovo Mail-In',  -- WARRANTY EXPIRED 80 days ago
   'b1000000-0000-0000-0000-000000000002', 'cc000000-0000-0000-0000-000000000003',
   'jana.schmidt@company.com', '2023-03-20',
   '2026-04-15', 3, 'active'),

  -- ── HQ Servers (Dell PowerEdge — from PO-HQ-2026-0041) ──
  ('as000000-0000-0000-0000-000000000004', 'HQ-SRV-0001', 'server',
   'Dell', 'PowerEdge R750', 'SN-DELL-HQ-0001',
   '{"cpu":"Intel Xeon Gold 6338","ram_gb":256,"storage_gb":7680,"os":"VMware ESXi 8.0"}'::jsonb,
   'a8000000-0000-0000-0000-000000000001', '2026-05-12', 23700.00, 'EUR', 23700.00,
   'straight_line', 60, 1000.00,
   474.00, 23226.00,
   '2029-05-12', 'onsite_next_day', 'Dell ProSupport',
   'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001',
   null, null,
   null, 0, 'active'),

  ('as000000-0000-0000-0000-000000000005', 'HQ-SRV-0002', 'server',
   'Dell', 'PowerEdge R750', 'SN-DELL-HQ-0002',
   '{"cpu":"Intel Xeon Gold 6338","ram_gb":256,"storage_gb":7680,"os":"VMware ESXi 8.0"}'::jsonb,
   'a8000000-0000-0000-0000-000000000001', '2026-05-12', 23700.00, 'EUR', 23700.00,
   'straight_line', 60, 1000.00,
   474.00, 23226.00,
   '2029-05-12', 'onsite_next_day', 'Dell ProSupport',
   'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001',
   null, null,
   null, 0, 'active'),

  -- ── UK MacBook Pros (Apple — draft PO) ──
  ('as000000-0000-0000-0000-000000000006', 'UK-LT-0041', 'laptop',
   'Apple', 'MacBook Pro 14" M3 Pro', 'SN-AAPL-UK-0041',
   '{"cpu":"Apple M3 Pro","ram_gb":18,"storage_gb":512,"os":"macOS Sonoma"}'::jsonb,
   'a8000000-0000-0000-0000-000000000003', '2026-05-25', 3900.00, 'GBP', 4503.00,
   'straight_line', 36, 0.00,
   125.08, 4377.92,
   '2028-05-25', 'premium', 'AppleCare+ for Enterprise',
   'b1000000-0000-0000-0000-000000000003', 'cc000000-0000-0000-0000-000000000005',
   null, null,
   null, 0, 'active'),

  -- ── Near-EOL asset — 33 months old, book value 8%, warranty expired ──
  ('as000000-0000-0000-0000-000000000007', 'DACH-LT-0007', 'laptop',
   'Lenovo', 'ThinkPad T490', 'SN-LNV-OLD-0007',
   '{"cpu":"Intel Core i7-8565U","ram_gb":16,"storage_gb":256,"os":"Windows 10 Pro"}'::jsonb,
   null, '2023-03-01', 1400.00, 'EUR', 1400.00,
   'straight_line', 36, 0.00,
   1283.33, 116.67,   -- book value 8.3% → EOL alert should fire
   '2026-03-01', 'basic', 'Lenovo Mail-In',  -- WARRANTY EXPIRED
   'b1000000-0000-0000-0000-000000000002', 'cc000000-0000-0000-0000-000000000003',
   'jana.schmidt@company.com', '2023-03-10',
   '2026-05-20', 4, 'active'),

  -- ── Nordics assets ──
  ('as000000-0000-0000-0000-000000000008', 'NORD-LT-0001', 'laptop',
   'Lenovo', 'ThinkPad T14s Gen3', 'SN-LNV-NORD-0001',
   '{"cpu":"Intel Core i7-1260P","ram_gb":16,"storage_gb":512,"os":"Windows 11 Pro"}'::jsonb,
   null, '2023-06-15', 1720.00, 'EUR', 1720.00,
   'straight_line', 36, 0.00,
   1290.00, 430.00,
   '2026-09-15', 'premium', 'Lenovo On-Site',
   'b1000000-0000-0000-0000-000000000006', 'cc000000-0000-0000-0000-000000000011',
   'erik.lindqvist@company.com', '2023-06-20',
   '2026-05-29', 0, 'active'),

  -- ── CEE IT asset ──
  ('as000000-0000-0000-0000-000000000009', 'CEE-LT-0001', 'laptop',
   'Lenovo', 'ThinkPad E14 Gen4', 'SN-LNV-CEE-0001',
   '{"cpu":"Intel Core i5-1235U","ram_gb":8,"storage_gb":256,"os":"Windows 11 Home"}'::jsonb,
   null, '2024-01-10', 980.00, 'EUR', 980.00,
   'straight_line', 36, 0.00,
   408.33, 571.67,
   '2027-01-10', 'basic', 'Lenovo Mail-In',
   'b1000000-0000-0000-0000-000000000009', 'cc000000-0000-0000-0000-000000000012',
   null, null,
   '2026-05-25', 0, 'active'),

  -- ── HQ Monitor (longer useful life) ──
  ('as000000-0000-0000-0000-000000000010', 'HQ-MON-0012', 'monitor',
   'Dell', 'UltraSharp U2722D', 'SN-DELL-MON-0012',
   '{"size_inch":27,"resolution":"4K","panel":"IPS","ports":["USB-C","HDMI","DP"]}'::jsonb,
   null, '2022-11-01', 680.00, 'EUR', 680.00,
   'straight_line', 60, 50.00,
   430.00, 250.00,
   '2025-11-01', 'basic', 'Dell',  -- WARRANTY EXPIRED 6 months ago
   'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001',
   'sarah.brennan@company.com', '2022-11-05',
   '2026-05-29', 1, 'active')

on conflict (id) do update set
  accumulated_depreciation = excluded.accumulated_depreciation,
  current_book_value       = excluded.current_book_value,
  last_active_date         = excluded.last_active_date,
  incident_count           = excluded.incident_count;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. ASSET DEPRECIATION LOG (historical — Apr + May 2026)
--    Feeds Controlling month-end view and Grafana dashboard
-- ─────────────────────────────────────────────────────────────────────────────
insert into asset_depreciation_log (
  id, asset_id, period, depreciation_amount, book_value_before, book_value_after,
  method_used, gl_account, cost_center_code, posted, created_at
) values
  -- Apr 2026
  ('adl00000-0000-0000-0000-000000000001', 'as000000-0000-0000-0000-000000000001', '2026-04', 52.50, 892.50, 840.00, 'straight_line', '6820', 'ENG-DACH', true,  now() - interval '30 days'),
  ('adl00000-0000-0000-0000-000000000002', 'as000000-0000-0000-0000-000000000002', '2026-04', 52.50, 892.50, 840.00, 'straight_line', '6820', 'ENG-DACH', true,  now() - interval '30 days'),
  ('adl00000-0000-0000-0000-000000000003', 'as000000-0000-0000-0000-000000000003', '2026-04', 45.83, 458.33, 412.50, 'straight_line', '6820', 'IT-DACH',  true,  now() - interval '30 days'),
  ('adl00000-0000-0000-0000-000000000004', 'as000000-0000-0000-0000-000000000007', '2026-04', 38.89, 155.56, 116.67, 'straight_line', '6820', 'IT-DACH',  true,  now() - interval '30 days'),
  ('adl00000-0000-0000-0000-000000000005', 'as000000-0000-0000-0000-000000000008', '2026-04', 47.78, 477.78, 430.00, 'straight_line', '6820', 'OPS-NORD', true,  now() - interval '30 days'),
  ('adl00000-0000-0000-0000-000000000006', 'as000000-0000-0000-0000-000000000009', '2026-04', 27.22, 598.89, 571.67, 'straight_line', '6820', 'IT-CEE',   true,  now() - interval '30 days'),
  ('adl00000-0000-0000-0000-000000000007', 'as000000-0000-0000-0000-000000000010', '2026-04', 10.50, 260.50, 250.00, 'straight_line', '6820', 'IT-HQ',    true,  now() - interval '30 days'),
  -- May 2026 — not yet posted (workflow runs monthly, generates these)
  ('adl00000-0000-0000-0000-000000000008', 'as000000-0000-0000-0000-000000000001', '2026-05', 52.50, 840.00, 787.50, 'straight_line', '6820', 'ENG-DACH', false, now() - interval '1 hour'),
  ('adl00000-0000-0000-0000-000000000009', 'as000000-0000-0000-0000-000000000002', '2026-05', 52.50, 840.00, 787.50, 'straight_line', '6820', 'ENG-DACH', false, now() - interval '1 hour'),
  ('adl00000-0000-0000-0000-000000000010', 'as000000-0000-0000-0000-000000000003', '2026-05', 45.83, 412.50, 366.67, 'straight_line', '6820', 'IT-DACH',  false, now() - interval '1 hour'),
  ('adl00000-0000-0000-0000-000000000011', 'as000000-0000-0000-0000-000000000007', '2026-05', 38.89, 116.67,  77.78, 'straight_line', '6820', 'IT-DACH',  false, now() - interval '1 hour'),
  ('adl00000-0000-0000-0000-000000000012', 'as000000-0000-0000-0000-000000000008', '2026-05', 47.78, 430.00, 382.22, 'straight_line', '6820', 'OPS-NORD', false, now() - interval '1 hour'),
  ('adl00000-0000-0000-0000-000000000013', 'as000000-0000-0000-0000-000000000009', '2026-05', 27.22, 571.67, 544.45, 'straight_line', '6820', 'IT-CEE',   false, now() - interval '1 hour'),
  ('adl00000-0000-0000-0000-000000000014', 'as000000-0000-0000-0000-000000000010', '2026-05', 10.50, 250.00, 239.50, 'straight_line', '6820', 'IT-HQ',    false, now() - interval '1 hour')
on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. ADDITIONAL LICENSE ASSIGNMENTS (feeds license waste + self-service flow)
-- ─────────────────────────────────────────────────────────────────────────────
insert into license_assignments (
  id, entitlement_id, assigned_to_user, assigned_to_asset_id,
  cost_center_id, ticket_id, last_active_at, active, usage_depth_pct, assigned_at
) values
  -- M365 E3 DACH — Thomas Müller (IT manager uses it)
  ('la000000-0000-0000-0000-000000000001',
   'ae000000-0000-0000-0000-000000000001',
   'thomas.mueller@company.com', null,
   'cc000000-0000-0000-0000-000000000003',
   'a9000000-0000-0000-0000-000000000006',
   now() - interval '1 hour', true, 78.0,
   '2024-09-01'),

  -- M365 E3 DACH — Jana Schmidt
  ('la000000-0000-0000-0000-000000000002',
   'ae000000-0000-0000-0000-000000000001',
   'jana.schmidt@company.com', null,
   'cc000000-0000-0000-0000-000000000004',
   null,
   now() - interval '2 hours', true, 54.0,
   '2024-06-15'),

  -- M365 E3 DACH — Lena Hoffmann
  ('la000000-0000-0000-0000-000000000003',
   'ae000000-0000-0000-0000-000000000001',
   'lena.hoffmann@company.com', null,
   'cc000000-0000-0000-0000-000000000003',
   null,
   now() - interval '30 minutes', true, 88.0,
   '2024-09-01'),

  -- M365 E5 UK — inactive user (shelfware example, last active 95 days ago)
  ('la000000-0000-0000-0000-000000000004',
   'ae000000-0000-0000-0000-000000000002',
   'former.employee.uk@company.com', null,
   'cc000000-0000-0000-0000-000000000005',
   null,
   now() - interval '95 days', true, 12.0,   -- shelfware candidate
   '2025-08-01'),

  -- Salesforce France — Marc Dupont
  ('la000000-0000-0000-0000-000000000005',
   'ae000000-0000-0000-0000-000000000003',
   'marc.dupont@company.com', null,
   'cc000000-0000-0000-0000-000000000007',
   null,
   now() - interval '45 minutes', true, 82.0,
   '2025-06-01'),

  -- Slack Nordics — Erik Lindqvist
  ('la000000-0000-0000-0000-000000000006',
   'ae000000-0000-0000-0000-000000000004',
   'erik.lindqvist@company.com', null,
   'cc000000-0000-0000-0000-000000000011',
   null,
   now() - interval '20 minutes', true, 65.0,
   '2025-09-01'),

  -- Slack Nordics — inactive (shelfware, last active 60 days ago)
  ('la000000-0000-0000-0000-000000000007',
   'ae000000-0000-0000-0000-000000000004',
   'inactive.nordic@company.com', null,
   null,
   null,
   now() - interval '60 days', true, 8.0,   -- 170 shelfware seats in pool
   '2025-09-01'),

  -- Zoom Benelux — recently reclaimed
  ('la000000-0000-0000-0000-000000000008',
   'ae000000-0000-0000-0000-000000000005',
   'former.benelux@company.com', null,
   'cc000000-0000-0000-0000-000000000006',
   null,
   now() - interval '120 days', false, 5.0,   -- reclaimed
   '2025-07-01')
on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. FULL P2I LIFECYCLE — Request → PO → Invoice → Payment → ERP
--    Three complete cycles at different stages
-- ─────────────────────────────────────────────────────────────────────────────

-- === CYCLE A: COMPLETED — Dell servers (HQ) ===
-- PO already in 09_mock_data (a8000000-...000001 — delivered)
-- Invoice received, matched, payment instruction created

insert into invoices (
  id, po_id, supplier_id, invoice_number, invoice_date,
  amount, vat_amount, currency, amount_eur,
  vat_rate, vat_number, reverse_charge,
  match_result, match_delta_eur,
  status, received_at, matched_at, approved_at,
  parsed_by_model, notes
) values
  -- Invoice for Dell PowerEdge x12
  ('inv00000-0000-0000-0000-000000000001',
   'a8000000-0000-0000-0000-000000000001',
   'f1000000-0000-0000-0000-000000000001',
   'DELL-INV-2026-08841', '2026-05-14',
   284400.00, 54036.00, 'EUR', 284400.00,
   0.19, 'DE123456789', false,
   'matched', 0.00,
   'approved', now() - interval '15 days', now() - interval '15 days', now() - interval '14 days',
   'claude-sonnet-4-6',
   '3-way match: PO €284,400 = Invoice €284,400 = Delivery confirmed. VAT 19% standard rate. Auto-approved.')
on conflict (id) do nothing;

insert into payment_instructions (
  id, invoice_id, po_id, supplier_id,
  amount, currency, payment_ref, due_date,
  erp_posted, erp_reference, erp_posted_at,
  status, created_at
) values
  ('pi000000-0000-0000-0000-000000000001',
   'inv00000-0000-0000-0000-000000000001',
   'a8000000-0000-0000-0000-000000000001',
   'f1000000-0000-0000-0000-000000000001',
   338436.00, 'EUR', 'TS-PAY-2026-0041', '2026-06-14',
   true, 'SAP-FI-2026-88421', now() - interval '13 days',
   'paid', now() - interval '14 days')
on conflict (id) do nothing;

insert into erp_sync_queue (
  id, event_type, entity_type, entity_id, payload,
  erp_system, status, attempts, created_at, synced_at
) values
  ('erp00000-0000-0000-0000-000000000001',
   'payment_instruction', 'payment_instructions', 'pi000000-0000-0000-0000-000000000001',
   '{"po_number":"PO-HQ-2026-0041","supplier":"Dell Technologies","amount_eur":284400,"vat_eur":54036,"total":338436,"payment_ref":"TS-PAY-2026-0041","gl_account":"6300","cost_center":"IT-HQ"}'::jsonb,
   'sap', 'synced', 1, now() - interval '14 days', now() - interval '13 days')
on conflict (id) do nothing;

-- === CYCLE B: IN FLIGHT — Lenovo ThinkPad x40 (DACH) ===
-- PO sent (a8000000-...000002), delivery expected 2026-06-14
-- Invoice not yet received — awaiting delivery confirmation

-- (no invoice yet — delivery_confirmation workflow will trigger match)

-- === CYCLE C: FULL LIFECYCLE — AWS burst compute ===
-- PO already invoiced (a8000000-...000004 — status: invoiced)

insert into invoices (
  id, po_id, supplier_id, invoice_number, invoice_date,
  amount, vat_amount, currency, amount_eur,
  vat_rate, vat_number, reverse_charge,
  match_result, match_delta_eur,
  status, received_at, matched_at, approved_at,
  parsed_by_model, notes
) values
  -- AWS compute invoice — reverse charge (B2B Luxembourg → Germany)
  ('inv00000-0000-0000-0000-000000000002',
   'a8000000-0000-0000-0000-000000000004',
   'f1000000-0000-0000-0000-000000000004',
   'AWS-2026-04-EMEA-0049182', '2026-04-30',
   89000.00, 0.00, 'EUR', 89000.00,
   0.00, 'LU987654321', true,    -- reverse charge
   'matched', 0.00,
   'approved', now() - interval '29 days', now() - interval '29 days', now() - interval '28 days',
   'claude-sonnet-4-6',
   '3-way match: PO €89,000 = Invoice €89,000. Reverse charge (Luxembourg entity). No VAT charged. Auto-approved.')
on conflict (id) do nothing;

insert into payment_instructions (
  id, invoice_id, po_id, supplier_id,
  amount, currency, payment_ref, due_date,
  erp_posted, erp_reference, erp_posted_at,
  status, created_at
) values
  ('pi000000-0000-0000-0000-000000000002',
   'inv00000-0000-0000-0000-000000000002',
   'a8000000-0000-0000-0000-000000000004',
   'f1000000-0000-0000-0000-000000000004',
   89000.00, 'EUR', 'TS-PAY-2026-0039', '2026-05-30',
   true, 'SAP-FI-2026-84319', now() - interval '27 days',
   'paid', now() - interval '28 days')
on conflict (id) do nothing;

insert into erp_sync_queue (
  id, event_type, entity_type, entity_id, payload,
  erp_system, status, attempts, created_at, synced_at
) values
  ('erp00000-0000-0000-0000-000000000002',
   'payment_instruction', 'payment_instructions', 'pi000000-0000-0000-0000-000000000002',
   '{"po_number":"PO-HQ-2026-0039","supplier":"AWS EMEA SARL","amount_eur":89000,"vat_eur":0,"total":89000,"reverse_charge":true,"payment_ref":"TS-PAY-2026-0039","gl_account":"6350","cost_center":"IT-HQ"}'::jsonb,
   'sap', 'synced', 1, now() - interval '28 days', now() - interval '27 days')
on conflict (id) do nothing;

-- === CYCLE D: MISMATCH — Salesforce France seats ===
-- PO sent, invoice received with 2.8% variance — triggers one_touch review

insert into invoices (
  id, po_id, supplier_id, invoice_number, invoice_date,
  amount, vat_amount, currency, amount_eur,
  vat_rate, vat_number, reverse_charge,
  match_result, match_delta_eur,
  status, received_at, matched_at,
  parsed_by_model, notes
) values
  ('inv00000-0000-0000-0000-000000000003',
   'a8000000-0000-0000-0000-000000000005',
   'f1000000-0000-0000-0000-000000000008',
   'SF-FR-2026-INV-04421', '2026-05-28',
   74016.00, 0.00, 'EUR', 74016.00,   -- €2,016 more than PO €72,000 → 2.8% over tolerance
   0.00, 'FR12345678901', true,         -- reverse charge
   'amount_mismatch', 2016.00,
   'pending_review', now() - interval '2 days', now() - interval '2 days',
   'claude-sonnet-4-6',
   'MISMATCH: Invoice €74,016 vs PO €72,000. Delta €2,016 (2.8%) exceeds 2% tolerance. Salesforce citing pro-rata adjustment for 1-day billing overlap. Requires manual approval.')
on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. HYPERSCALER POSITIONS (May 2026 — feeds anomaly monitor)
-- ─────────────────────────────────────────────────────────────────────────────
insert into hyperscaler_positions (
  id, branch_id, provider, account_id, service_name, period, contract_id,
  committed_eur, commitment_type, commitment_end,
  mtd_spend_eur, daily_burn_eur, projected_eur,
  reservation_util, idle_resources_eur,
  flag_overrun, flag_idle, flag_anomaly
) values
  -- AWS Global HQ — EDP (healthy utilization)
  ('hp000000-0000-0000-0000-000000000001',
   'b1000000-0000-0000-0000-000000000001', 'AWS', '123456789012', 'EC2/S3/RDS', '2026-05',
   'c1000000-0000-0000-0000-000000000014',
   1000000.00, 'EDP', '2026-11-26',
   841200.00, 33648.00, 1008000.00,   -- projected €1.008M vs €1M commit → slight over
   0.84, 12400.00,
   false, false, false),

  -- GCP DACH — CUD (excellent utilization)
  ('hp000000-0000-0000-0000-000000000002',
   'b1000000-0000-0000-0000-000000000002', 'GCP', 'truespend-dach-prod', 'Compute Engine', '2026-05',
   'c1000000-0000-0000-0000-000000000015',
   400000.00, 'CUD', '2026-10-26',
   376000.00, 14960.00, 393000.00,
   0.94, 3200.00,
   false, false, false),

  -- Azure UK — Reservations (LOW utilization — anomaly flag)
  ('hp000000-0000-0000-0000-000000000003',
   'b1000000-0000-0000-0000-000000000003', 'Azure', 'truespend-uk-prod', 'Virtual Machines', '2026-05',
   'c1000000-0000-0000-0000-000000000016',
   258333.00, 'Reservation', '2026-12-06',
   173220.00, 6929.00, 208000.00,    -- projected 81% utilization — improved from 67%
   0.67, 28400.00,                    -- still idle €28k this month
   false, true, false),              -- flag_idle = true

  -- AWS HQ — April data (trend)
  ('hp000000-0000-0000-0000-000000000004',
   'b1000000-0000-0000-0000-000000000001', 'AWS', '123456789012', 'EC2/S3/RDS', '2026-04',
   'c1000000-0000-0000-0000-000000000014',
   1000000.00, 'EDP', '2026-11-26',
   987000.00, null, null,
   0.81, 9800.00,
   false, false, false),

  -- AWS HQ — March data (trend)
  ('hp000000-0000-0000-0000-000000000005',
   'b1000000-0000-0000-0000-000000000001', 'AWS', '123456789012', 'EC2/S3/RDS', '2026-03',
   'c1000000-0000-0000-0000-000000000014',
   1000000.00, 'EDP', '2026-11-26',
   924000.00, null, null,
   0.79, 11200.00,
   false, false, false)
on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. LLM API KEYS + CONSUMPTION HISTORY (anomaly detection test data)
--    Extra months of history so the 7-day average calc has real data
-- ─────────────────────────────────────────────────────────────────────────────

-- Additional API key (Nordics team added in Q2)
insert into llm_api_keys (
  id, provider, key_ref, owner_user_id, team_name,
  branch_id, cost_center_id, monthly_budget_eur
) values
  ('a5000000-0000-0000-0000-000000000004',
   'anthropic', 'sk-ant-...nord', 'e1000000-0000-0000-0000-000000000004', 'Nordics Product',
   'b1000000-0000-0000-0000-000000000006', 'cc000000-0000-0000-0000-000000000011',
   930.00)
on conflict (id) do nothing;

-- Monthly consumption history (March + April supplement, plus daily May data)
insert into llm_consumption (
  id, api_key_id, provider, model, period,
  branch_id, cost_center_id,
  input_tokens, output_tokens, cost_usd, cost_eur
) values
  -- HQ platform — March 2026
  ('a6000000-0000-0000-0000-000000000005',
   'a5000000-0000-0000-0000-000000000001', 'anthropic', 'claude-sonnet-4-6', '2026-03',
   'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001',
   9200000, 2100000, 1920.00, 1785.60),

  -- HQ platform — February 2026
  ('a6000000-0000-0000-0000-000000000006',
   'a5000000-0000-0000-0000-000000000001', 'anthropic', 'claude-sonnet-4-6', '2026-02',
   'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001',
   8100000, 1900000, 1698.00, 1579.14),

  -- DACH engineering — April 2026
  ('a6000000-0000-0000-0000-000000000007',
   'a5000000-0000-0000-0000-000000000002', 'anthropic', 'claude-sonnet-4-6', '2026-04',
   'b1000000-0000-0000-0000-000000000002', 'cc000000-0000-0000-0000-000000000003',
   5800000, 1400000, 1218.00, 1132.74),

  -- DACH engineering — March 2026
  ('a6000000-0000-0000-0000-000000000008',
   'a5000000-0000-0000-0000-000000000002', 'anthropic', 'claude-sonnet-4-6', '2026-03',
   'b1000000-0000-0000-0000-000000000002', 'cc000000-0000-0000-0000-000000000003',
   4900000, 1100000, 1008.00, 937.44),

  -- France sales AI — April 2026
  ('a6000000-0000-0000-0000-000000000009',
   'a5000000-0000-0000-0000-000000000003', 'openai', 'gpt-4o', '2026-04',
   'b1000000-0000-0000-0000-000000000005', 'cc000000-0000-0000-0000-000000000007',
   3400000, 800000, 1060.00, 985.80),

  -- Nordics product — May 2026 (new team, first month — baseline low)
  ('a6000000-0000-0000-0000-000000000010',
   'a5000000-0000-0000-0000-000000000004', 'anthropic', 'claude-sonnet-4-6', '2026-05',
   'b1000000-0000-0000-0000-000000000006', 'cc000000-0000-0000-0000-000000000011',
   2100000, 480000, 444.00, 412.92),

  -- HQ platform — ANOMALY: May week showing spike (3.2× April daily avg)
  -- April avg/day = €2343.60/30 = €78.12/day → spike day = €249.98 (3.2×)
  ('a6000000-0000-0000-0000-000000000011',
   'a5000000-0000-0000-0000-000000000001', 'anthropic', 'claude-sonnet-4-6', '2026-05-28',
   'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001',
   7200000, 1800000, 268.80, 249.98)  -- single day — anomaly trigger

on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. OPERATIONS BOARD TICKETS — Complete set for every user profile
--     Covers: pending_confirm, pending_review, signature_required, approved,
--             escalated, reasoning — all sources and categories
-- ─────────────────────────────────────────────────────────────────────────────

insert into tickets (
  id, reference, source, status, title, description,
  category, amount, amount_eur, currency,
  supplier_id, branch_id, cost_center_id, owner_id,
  review_type, review_notes, jira_key, pdf_url,
  created_at, target_close
) values

  -- ── T01: IT MANAGER — License self-service (one_touch, catalog item) ──
  ('t9000000-0000-0000-0000-000000000001',
   'TS-2026-0201', 'jira', 'pending_confirm',
   'M365 E5 seat — Lisa Kerr (UK Sales)',
   'New hire Lisa Kerr joins UK Sales 2026-06-15. Manager pre-approved M365 E5. Jira REQ-2201.',
   'saas_license', 2000.00, 2000.00, 'EUR',
   'f1000000-0000-0000-0000-000000000007', 'b1000000-0000-0000-0000-000000000003',
   'cc000000-0000-0000-0000-000000000005', 'e1000000-0000-0000-0000-000000000006',
   'budget_check', 'UK saas budget 69% committed. Shelfware check: 115 unassigned E5 seats. Provision from pool — no PO. Budget impact: €2k (0.2% of available). Auto-approve confidence 89% — routed for IT manager confirm.',
   null, null,
   now() - interval '3 hours', now() + interval '1 day'),

  -- ── T02: CONTROLLING / CFO — Invoice mismatch (Salesforce France) ──
  ('t9000000-0000-0000-0000-000000000002',
   'TS-2026-0202', 'automatic', 'pending_review',
   'Invoice mismatch — Salesforce France +€2,016 over PO',
   'Invoice SF-FR-2026-INV-04421 for €74,016 vs PO €72,000. Delta 2.8% exceeds 2% tolerance. Salesforce claims billing overlap adjustment.',
   'saas_license', 74016.00, 74016.00, 'EUR',
   'f1000000-0000-0000-0000-000000000008', 'b1000000-0000-0000-0000-000000000005',
   'cc000000-0000-0000-0000-000000000007', 'e1000000-0000-0000-0000-000000000002',
   'budget_overrun', 'Variance 2.8% > 2% tolerance — manual approval required. Salesforce explanation: billing cycle overlap from quarterly to monthly transition. Precedent: similar adjustment accepted Feb 2025 for €1,400. Recommend accept with formal vendor note.',
   null, null,
   now() - interval '2 days', now() + interval '2 days'),

  -- ── T03: HEAD OF PROCUREMENT — Reorder trigger (auto, one_touch) ──
  ('t9000000-0000-0000-0000-000000000003',
   'TS-2026-0203', 'automatic', 'pending_confirm',
   'Reorder: Lenovo ThinkPad T14s x15 — DACH Engineering',
   'Stock monitoring: DACH laptop pool at 8 available. Reorder point 10. 3 onboarding requests queued for Q3. Recommend: PO for 15 units to Lenovo DACH at contract price €1,890/unit = €28,350.',
   'hardware', 28350.00, 28350.00, 'EUR',
   'f1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000002',
   'cc000000-0000-0000-0000-000000000010', 'e1000000-0000-0000-0000-000000000003',
   null, 'Reorder confidence 91%. Contract c1000000-...000011 active, within volume tier. DACH hardware Q2 budget available €2.455M. Lenovo health green. Standard replenishment — one_touch due to Q2 budget already at 51% committed.',
   null, null,
   now() - interval '6 hours', now() + interval '1 day'),

  -- ── T04: LEGAL — DPA review for new supplier (signature_required) ──
  ('t9000000-0000-0000-0000-000000000004',
   'TS-2026-0204', 'compliance', 'signature_required',
   'DPA — Anthropic Inc. — Art. 28 GDPR — signature required',
   'LLM API usage via Anthropic confirmed. Art. 28 GDPR Data Processing Agreement required before production data may be sent to API. DPA generated by legal agent.',
   'ai_consumption', null, null, 'EUR',
   null, 'b1000000-0000-0000-0000-000000000001',
   'cc000000-0000-0000-0000-000000000008', 'e1000000-0000-0000-0000-000000000001',
   'legal', 'DPA includes: Art. 28 GDPR recitals, SCCs (controller-processor, EU-US transfer), TOM Annex 2 with InfoSec requirements. Anthropic US-based processor — SCC Module 2 required. Data residency: US/EU. Sub-processor list reviewed — OpenAI not listed (correct). Ready for CPO/DPO signature.',
   null, 'https://docs.truespend.internal/dpa/anthropic-2026-05-dpa.pdf',
   now() - interval '4 hours', now() + interval '3 days'),

  -- ── T05: IT MANAGER — Asset EOL replacement (one_touch) ──
  ('t9000000-0000-0000-0000-000000000005',
   'TS-2026-0205', 'automatic', 'pending_confirm',
   'Asset EOL — DACH-LT-0007 (ThinkPad T490) — replacement PO',
   'Asset DACH-LT-0007 has reached end-of-life: book value €77.78 (5.6% of cost), warranty expired 2026-03-01, 4 incidents in L6M. Assigned to jana.schmidt@company.com.',
   'hardware', 1890.00, 1890.00, 'EUR',
   'f1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000002',
   'cc000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000006',
   null, 'EOL criteria met: book_value < 10% AND warranty_expired AND incident_count > 3. Lenovo T14s Gen4 replacement at contract price €1,890. DACH hardware budget available. Recommend approve — decommission DACH-LT-0007 on delivery.',
   null, null,
   now() - interval '1 hour', now() + interval '2 days'),

  -- ── T06: OPS MANAGER — Supplier onboarding (compliance flow) ──
  ('t9000000-0000-0000-0000-000000000006',
   'TS-2026-0206', 'compliance', 'pending_review',
   'Supplier onboarding — Mistral AI S.A. — compliance review',
   'New AI supplier: Mistral AI S.A. (Paris). Onboarding triggered for LLM API evaluation. 4 compliance agents completed.',
   null, null, null, 'EUR',
   null, 'b1000000-0000-0000-0000-000000000001',
   'cc000000-0000-0000-0000-000000000008', 'e1000000-0000-0000-0000-000000000001',
   'compliance_flag', 'Lawyer: NDA generated, legal risk LOW, no blockers. GDPR: DPA content valid, EU processor (France), no SCC needed. InfoSec: score 74/100 — ISO 27001 pending (expected Q3 2026), SOC 2 Type I only. BLOCKER: request SOC 2 Type II before production use. LkSG: clean, COC accepted. Routing for procurement review of InfoSec gap.',
   null, null,
   now() - interval '8 hours', now() + interval '5 days'),

  -- ── T07: REQUESTER VIEW — Intake request by Jana Schmidt ──
  ('t9000000-0000-0000-0000-000000000007',
   'TS-2026-0207', 'intake', 'pending_confirm',
   '4K monitors x4 — DACH Engineering team expansion',
   'Engineering team growing by 4 in June 2026. Need 4× Dell UltraSharp 27" 4K monitors. Estimated €680 each = €2,720 total.',
   'hardware', 2720.00, 2720.00, 'EUR',
   'f1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002',
   'cc000000-0000-0000-0000-000000000010', 'e1000000-0000-0000-0000-000000000007',
   null, 'All signals green. Amount €2,720 within DACH hardware budget (available €2.455M). Dell preferred vendor, green health. Lena Hoffmann spend authority €250k covers this. Standard catalog item. Confidence 94% — routed one_touch (Q2 bucket already 51% committed per policy).',
   null, null,
   now() - interval '30 minutes', now() + interval '1 day'),

  -- ── T08: CFO — Large contract renewal (escalated) ──
  ('t9000000-0000-0000-0000-000000000008',
   'TS-2026-0208', 'renewal', 'escalated',
   'SAP S/4HANA Global License — renewal €6.4M + 7% increase',
   'Annual SAP S/4HANA enterprise license renewal. SAP proposing 7% increase: €6.4M → €6.85M (+€448k/year). Contract expires 2026-07-12. Jira PROC-452 created.',
   'saas_license', 6848000.00, 6848000.00, 'EUR',
   'f1000000-0000-0000-0000-000000000009', 'b1000000-0000-0000-0000-000000000001',
   'cc000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000000',
   'major_contract', 'Escalation: amount €6.85M > €100k threshold. Increase 7% vs CPI 3.1% = 3.9% real. SAP support ticket backlog (3 open P2s) provides negotiation leverage. Market check: no viable substitute for global S/4HANA footprint. Recommend: accept with 3-year lock + performance SLA penalties for P2 backlog resolution.',
   'PROC-452', null,
   now() - interval '12 hours', now() + interval '7 days'),

  -- ── T09: OPS MANAGER — VPS monitoring alert ──
  ('t9000000-0000-0000-0000-000000000009',
   'TS-2026-0209', 'monitoring', 'pending_confirm',
   'VPS — Load spike 7.3 avg — dockerd 48% CPU',
   'VPS health check 2026-05-30 09:47 UTC. Load avg 1m: 7.27 (threshold 3.0). dockerd accumulation suspected after 4-day uptime. Containers: all running.',
   null, null, null, 'EUR',
   null, 'b1000000-0000-0000-0000-000000000001',
   'cc000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000005',
   'infrastructure', 'Diagnosis: load 7.27 is sustained (not cold-start — ibgateway/kafka last started >2h ago). dockerd at 48% CPU suggests daemon accumulation. Steal time 72% (Hostinger infra — not actionable). Recommendation: systemctl restart docker on VPS. Not a Jira escalation — routine one_touch.',
   null, null,
   now() - interval '43 minutes', now() + interval '4 hours'),

  -- ── T10: LEGAL — Contract clause review (legal review_type) ──
  ('t9000000-0000-0000-0000-000000000010',
   'TS-2026-0210', 'renewal', 'pending_review',
   'Accenture SOW Phase 3 — penalty clause negotiation required',
   'Accenture Phase 3 SOW extension. Legal reviewing penalty clause and IP ownership terms before signature. Jira PROC-441 updated.',
   'services', 180000.00, 180000.00, 'EUR',
   'f1000000-0000-0000-0000-000000000013', 'b1000000-0000-0000-0000-000000000001',
   'cc000000-0000-0000-0000-000000000008', 'e1000000-0000-0000-0000-000000000001',
   'legal', 'Legal review requested: (1) IP ownership clause for custom deliverables — current draft gives Accenture joint ownership. Must be TrueSpend sole ownership. (2) Penalty clause: current 5% cap on fees. Request 15% + right to offset against disputed invoices. (3) Sub-contractor disclosure: must name all sub-processors per Art. 28 GDPR.',
   'PROC-441', null,
   now() - interval '18 hours', now() + interval '3 days'),

  -- ── T11: HEAD OF PROCUREMENT — LLM anomaly (ai_consumption) ──
  ('t9000000-0000-0000-0000-000000000011',
   'TS-2026-0211', 'automatic', 'pending_confirm',
   'LLM spend anomaly — HQ Anthropic key — 3.2× daily average',
   'Daily LLM spend spike detected: 2026-05-28 HQ Anthropic key consumed €249.98 vs 7-day avg €78.12 (3.2×). Threshold: 3×.',
   'ai_consumption', 249.98, 249.98, 'EUR',
   null, 'b1000000-0000-0000-0000-000000000001',
   'cc000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
   null, 'Anomaly detected: 2026-05-28 single-day spend €249.98 vs 7-day rolling avg €78.12 = 3.2× (threshold 3×). Key: sk-ant-...hq (IT Platform, Thomas Müller). Model: claude-sonnet-4-6. Input tokens: 7.2M, Output: 1.8M. Possible causes: batch job, runaway loop, new use case. Recommend: review with Thomas Müller before budget charge for May.',
   null, null,
   now() - interval '2 hours', now() + interval '1 day'),

  -- ── T12: REQUESTER — Awaiting delivery confirmation ──
  ('t9000000-0000-0000-0000-000000000012',
   'TS-2026-0212', 'intake', 'approved',
   'Lenovo ThinkPad x40 — delivery confirmation pending',
   'PO-DACH-2026-0087 sent to Lenovo. 40× ThinkPad T14s for DACH engineering. Expected delivery 2026-06-14. Awaiting delivery confirmation to trigger invoice matching.',
   'hardware', 205000.00, 205000.00, 'EUR',
   'f1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000002',
   'cc000000-0000-0000-0000-000000000010', 'e1000000-0000-0000-0000-000000000003',
   null, null,
   null, null,
   now() - interval '27 days', now() + interval '15 days')

on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. DECISIONS + TRACE LOG for new tickets above
-- ─────────────────────────────────────────────────────────────────────────────

insert into decisions (
  id, ticket_id, disposition, confidence, recommendation, reasoning, created_at
) values
  ('d9000000-0000-0000-0000-000000000001',
   't9000000-0000-0000-0000-000000000001', 'one_touch', 0.8900,
   'Provision M365 E5 from shelfware pool — confirm before committing',
   '3 signals green (shelfware available, budget headroom, requester validated). 2 signals yellow (entitlement approaching 100% utilization, budget 69% committed). Routing to IT Manager for confirm.',
   now() - interval '3 hours'),

  ('d9000000-0000-0000-0000-000000000002',
   't9000000-0000-0000-0000-000000000002', 'one_touch', 0.6200,
   'Invoice variance within plausible range — accept with vendor note',
   'Amount delta €2,016 (2.8%) exceeds 2% tolerance. Salesforce billing overlap explanation is plausible and was accepted in February 2025 precedent. Risk of disputing: French court jurisdiction, relationship impact on 12% renewal increase negotiation. Recommend accept.',
   now() - interval '2 days'),

  ('d9000000-0000-0000-0000-000000000003',
   't9000000-0000-0000-0000-000000000003', 'one_touch', 0.9100,
   'Approve reorder — standard replenishment within contract',
   'Reorder point breached. Contract active, volume tier covers 15 units at €1,890. Budget available. Routing for confirm because Q2 budget already at 51% committed — alerting head of procurement.',
   now() - interval '6 hours'),

  ('d9000000-0000-0000-0000-000000000004',
   't9000000-0000-0000-0000-000000000004', 'one_touch', 0.9700,
   'DPA generated — all compliance checks passed — route for signature',
   'Anthropic US processor. SCC Module 2 required (EU controller → US processor). TOM Annex validated against InfoSec score 88/100. Sub-processor list reviewed. DPA is legally valid. Routing for CPO/DPO signature.',
   now() - interval '4 hours'),

  ('d9000000-0000-0000-0000-000000000005',
   't9000000-0000-0000-0000-000000000005', 'one_touch', 0.9500,
   'Approve EOL replacement — decommission on delivery',
   'All EOL criteria met: book_value 5.6% < 10% threshold, warranty expired, incident_count 4 > 3 threshold. Replacement cost €1,890 within DACH hardware budget. Straightforward — one_touch because asset decommission requires IT manager confirm.',
   now() - interval '1 hour'),

  ('d9000000-0000-0000-0000-000000000006',
   't9000000-0000-0000-0000-000000000006', 'one_touch', 0.7400,
   'InfoSec gap: accept Mistral with SOC 2 Type II requirement before production',
   '3/4 compliance agents passed. InfoSec score 74/100 — SOC 2 Type I only. Blocker for production data use. Can proceed with sandbox/evaluation. Routing for procurement decision on conditional onboarding.',
   now() - interval '8 hours'),

  ('d9000000-0000-0000-0000-000000000007',
   't9000000-0000-0000-0000-000000000007', 'one_touch', 0.9400,
   'Approve monitor purchase — all signals green except Q2 commitment level',
   'All 5 signals green. €2,720 well within DACH hardware budget. Dell preferred vendor. Routing one_touch because Q2 budget commitment now at 51% — alerting per policy for spend visibility.',
   now() - interval '30 minutes'),

  ('d9000000-0000-0000-0000-000000000008',
   't9000000-0000-0000-0000-000000000008', 'escalate', 0.9800,
   'Escalate — SAP renewal €6.85M > €100k threshold — CPO + CFO review required',
   '2 escalation triggers: (1) Value €6.85M >> €100k threshold. (2) Multi-year strategic dependency — cannot switch ERP mid-year. SAP support debt (3 open P2s) is negotiation lever. 3-year lock recommended to stabilize cost. Jira PROC-452 created.',
   now() - interval '12 hours'),

  ('d9000000-0000-0000-0000-000000000009',
   't9000000-0000-0000-0000-000000000009', 'one_touch', 0.8300,
   'Restart docker daemon on VPS — load should normalize within 5 minutes',
   'Load 7.27 is sustained (>1h since last container start). dockerd 48% CPU is consistent with daemon accumulation pattern (restart cycle every 4-5 days observed). Steal time 72% is Hostinger baseline — not actionable. One_touch for ops team to execute restart.',
   now() - interval '43 minutes'),

  ('d9000000-0000-0000-0000-000000000010',
   't9000000-0000-0000-0000-000000000010', 'one_touch', 0.8800,
   'Hold SOW pending legal clause changes — IP and penalty terms unacceptable',
   'Current draft: joint IP ownership is a blocker (TrueSpend must own custom deliverables). 5% penalty cap is insufficient given €180k value and delivery risk. Route to Legal for redline before Accenture counter-sign.',
   now() - interval '18 hours'),

  ('d9000000-0000-0000-0000-000000000011',
   't9000000-0000-0000-0000-000000000011', 'one_touch', 0.8700,
   'LLM spike flagged — investigate before May budget close',
   '3.2× daily average on 2026-05-28. Not attributable to known workflow runs (procurement workflows avg 12k tokens each, this is 9M total). Likely: a test run or new integration consuming tokens at scale. Route for IT Manager investigation before billing cycle close.',
   now() - interval '2 hours')

on conflict (id) do nothing;

-- Trace log for new tickets (5 signals each, abbreviated for key ones)
insert into trace_log (id, decision_id, signal, value, weight, green, notes, created_at) values

  -- T01: M365 E5 seat
  ('tl000000-0000-0000-0000-000000000001', 'd9000000-0000-0000-0000-000000000001', 'consumption', '{"shelfware_seats":115,"pool_sufficient":true}', 1.0000, true,  'E5 UK pool: 115 shelfware seats. No PO needed.', now() - interval '3 hours'),
  ('tl000000-0000-0000-0000-000000000002', 'd9000000-0000-0000-0000-000000000001', 'policy',      '{"committed_pct":69,"available":280000}', 0.8500, true,  'UK saas bucket 69% committed — budget OK.', now() - interval '3 hours'),
  ('tl000000-0000-0000-0000-000000000003', 'd9000000-0000-0000-0000-000000000001', 'supplier',    '{"health":"green","gdpr":true}', 1.0000, true,  'Microsoft 365 — green, DPA signed.', now() - interval '3 hours'),
  ('tl000000-0000-0000-0000-000000000004', 'd9000000-0000-0000-0000-000000000001', 'request',     '{"new_hire":true,"start_date":"2026-06-15","manager_ok":true}', 1.0000, true, 'New hire confirmed, line manager approved.', now() - interval '3 hours'),
  ('tl000000-0000-0000-0000-000000000005', 'd9000000-0000-0000-0000-000000000001', 'contract',    '{"utilization_approaching_100pct":true}', 0.5500, false, 'Entitlement approaching full utilization — flag for renewal.', now() - interval '3 hours'),

  -- T05: Asset EOL
  ('tl000000-0000-0000-0000-000000000006', 'd9000000-0000-0000-0000-000000000005', 'policy',      '{"book_value_pct":5.6,"threshold":10.0}', 1.0000, false, 'Book value 5.6% < 10% EOL threshold.', now() - interval '1 hour'),
  ('tl000000-0000-0000-0000-000000000007', 'd9000000-0000-0000-0000-000000000005', 'policy',      '{"warranty_expired":true,"expired_days":90}', 1.0000, false, 'Warranty expired 2026-03-01 — 90 days ago.', now() - interval '1 hour'),
  ('tl000000-0000-0000-0000-000000000008', 'd9000000-0000-0000-0000-000000000005', 'supplier',    '{"health":"green","contract_active":true,"price":1890}', 1.0000, true,  'Lenovo contract active, price locked €1,890/unit.', now() - interval '1 hour'),
  ('tl000000-0000-0000-0000-000000000009', 'd9000000-0000-0000-0000-000000000005', 'policy',      '{"available":2455000,"cost":1890}', 1.0000, true,  'DACH hardware budget: €2.455M available.', now() - interval '1 hour'),
  ('tl000000-0000-0000-0000-000000000010', 'd9000000-0000-0000-0000-000000000005', 'request',     '{"incident_count":4,"threshold":3,"assigned_user":"jana.schmidt@company.com"}', 1.0000, false, '4 incidents in L6M > 3 threshold. EOL confirmed.', now() - interval '1 hour'),

  -- T09: VPS alert
  ('tl000000-0000-0000-0000-000000000011', 'd9000000-0000-0000-0000-000000000009', 'policy',      '{"load_1min":7.27,"threshold":3.0,"sustained":true}', 0.2000, false, 'Load 7.27 sustained > threshold 3.0.', now() - interval '43 minutes'),
  ('tl000000-0000-0000-0000-000000000012', 'd9000000-0000-0000-0000-000000000009', 'policy',      '{"dockerd_cpu":48,"cold_start":false}', 0.3000, false, 'dockerd 48% CPU — not cold-start. Daemon accumulation.', now() - interval '43 minutes'),
  ('tl000000-0000-0000-0000-000000000013', 'd9000000-0000-0000-0000-000000000009', 'policy',      '{"steal_time":72,"hostinger_baseline":true}', 1.0000, true,  'Steal 72% is Hostinger baseline — not actionable.', now() - interval '43 minutes'),
  ('tl000000-0000-0000-0000-000000000014', 'd9000000-0000-0000-0000-000000000009', 'policy',      '{"containers_healthy":true,"stopped_containers":0}', 1.0000, true,  'All containers running. No stopped/dead containers.', now() - interval '43 minutes'),
  ('tl000000-0000-0000-0000-000000000015', 'd9000000-0000-0000-0000-000000000009', 'policy',      '{"action":"systemctl restart docker","eta_minutes":5}', 0.8000, true,  'Docker restart will resolve. ETA 5 minutes.', now() - interval '43 minutes'),

  -- T11: LLM anomaly
  ('tl000000-0000-0000-0000-000000000016', 'd9000000-0000-0000-0000-000000000011', 'consumption', '{"daily_spend":249.98,"7day_avg":78.12,"ratio":3.2,"threshold":3.0}', 0.1000, false, 'Spike 3.2× 7-day average on 2026-05-28.', now() - interval '2 hours'),
  ('tl000000-0000-0000-0000-000000000017', 'd9000000-0000-0000-0000-000000000011', 'consumption', '{"input_tokens":7200000,"output_tokens":1800000,"model":"claude-sonnet-4-6"}', 0.2000, false, '9M total tokens in one day — 10× typical workflow day.', now() - interval '2 hours'),
  ('tl000000-0000-0000-0000-000000000018', 'd9000000-0000-0000-0000-000000000011', 'policy',      '{"budget_remaining_eur":171.02,"monthly_budget":420000}', 0.9000, true,  'Monthly budget not exceeded — anomaly alert only.', now() - interval '2 hours')

on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 12. SUPPLIER EMAILS (institutional memory for supplier_reply_handler)
-- ─────────────────────────────────────────────────────────────────────────────
insert into supplier_emails (
  id, supplier_id, contract_id, direction, subject, body_summary,
  commitments, order_reference, flagged, flag_reason,
  received_at, created_at
) values
  -- Apple — inbound, price increase justification
  ('se000000-0000-0000-0000-000000000001',
   'f1000000-0000-0000-0000-000000000003',
   'c1000000-0000-0000-0000-000000000006',
   'inbound',
   'Re: Apple Device Program UK — Contract Renewal Discussion',
   'Apple account manager confirms 9% price increase citing component cost inflation (M-series chip supply constraints) and extended warranty support costs. Offers 3-year lock-in at 7% vs 9% for 1-year. MacBook Pro backlog expected to clear by July 2026.',
   ARRAY['3-year lock at 7% available', 'Backlog clearing July 2026'],
   null, false, null,
   now() - interval '5 days', now() - interval '5 days'),

  -- Salesforce — inbound, invoice explanation
  ('se000000-0000-0000-0000-000000000002',
   'f1000000-0000-0000-0000-000000000008',
   'c1000000-0000-0000-0000-000000000007',
   'inbound',
   'Invoice SF-FR-2026-INV-04421 — Billing Adjustment Explanation',
   'Salesforce billing team explains €2,016 overage: monthly billing cycle started 2026-05-01 but annual contract runs to 2026-06-30, creating 1-day overlap in billing systems. Adjustment is one-time. Formally documented in Case SF-2026-FR-08821.',
   ARRAY['One-time adjustment, no future impact', 'Case SF-2026-FR-08821 created'],
   'PO-FR-2026-0015', false, null,
   now() - interval '2 days', now() - interval '2 days'),

  -- Accenture — inbound, scope proposal
  ('se000000-0000-0000-0000-000000000003',
   'f1000000-0000-0000-0000-000000000013',
   'c1000000-0000-0000-0000-000000000017',
   'inbound',
   'Phase 3 SOW Extension Proposal — Accenture Digital Transformation',
   'Accenture delivery lead proposes 6-week Phase 3 extension for data migration workstream. Rate: €30k/week. Scope: ETL pipeline completion and hyperscaler migration validation. Cites technical complexity discovered during Phase 2 as justification.',
   ARRAY['6-week extension at €30k/week', 'ETL + hyperscaler migration scope'],
   null, true, 'Rate 36% above benchmark. IP ownership clause unacceptable in attached draft.',
   now() - interval '3 days', now() - interval '3 days'),

  -- Lenovo — outbound, PO acknowledgement
  ('se000000-0000-0000-0000-000000000004',
   'f1000000-0000-0000-0000-000000000002',
   'c1000000-0000-0000-0000-000000000011',
   'outbound',
   'PO-DACH-2026-0087 — Order Confirmation Request',
   'Procurement sent PO for 40× ThinkPad T14s Gen4. Requested delivery confirmation and expected ship date. Asked Lenovo to confirm against contract pricing at €1,890/unit.',
   ARRAY['Awaiting delivery confirmation by 2026-05-10'],
   'PO-DACH-2026-0087', false, null,
   now() - interval '27 days', now() - interval '27 days'),

  -- Lenovo — inbound, delivery confirmed
  ('se000000-0000-0000-0000-000000000005',
   'f1000000-0000-0000-0000-000000000002',
   'c1000000-0000-0000-0000-000000000011',
   'inbound',
   'Re: PO-DACH-2026-0087 — Shipment Confirmed',
   'Lenovo logistics confirms 40-unit shipment despatched 2026-05-10. Expected delivery 2026-06-14. Tracking DHL Express 1Z999AA10123456784. Invoice to follow within 5 business days of delivery.',
   ARRAY['Delivery: 2026-06-14', 'Invoice within 5 days of delivery'],
   'PO-DACH-2026-0087', false, null,
   now() - interval '20 days', now() - interval '20 days'),

  -- Vodafone — inbound, SLA breach notification (flagged)
  ('se000000-0000-0000-0000-000000000006',
   'f1000000-0000-0000-0000-000000000017',
   'c1000000-0000-0000-0000-000000000009',
   'inbound',
   'Network Incident Report — February 2026 Outage — Vodafone Italy',
   'Vodafone Italy customer relations sends belated incident report for Feb 2026 outage (18-hour downtime). Root cause: backbone routing failure Milan PoP. SLA credit offered: €4,200 (1.4% of monthly contract). Proposes to offset against Q3 invoice.',
   ARRAY['€4,200 SLA credit on Q3 invoice', 'Incident report delivered late (90+ days)'],
   null, true, 'SLA breach not formally invoked. Late incident report. 15% price increase requested on same contract. Legal should review penalty clause.',
   now() - interval '4 days', now() - interval '4 days')

on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 13. COMPLIANCE CHECKS — Additional suppliers for testing
-- ─────────────────────────────────────────────────────────────────────────────
insert into compliance_checks (
  id, supplier_id, check_type, status, score, notes
) values
  -- Mistral AI — InfoSec gap (only SOC 2 Type I)
  ('a4000000-0000-0000-0000-000000000008',
   null,  -- new supplier not yet in suppliers table
   'infosec', 'review_required', 74,
   'ISO 27001 certification pending (expected Q3 2026). SOC 2 Type I only — Type II required before production data. Sub-processor list provided and reviewed. Penetration test 2025-Q4 available.'),

  ('a4000000-0000-0000-0000-000000000009',
   null,
   'gdpr', 'compliant', 91,
   'EU processor (France). No SCCs required. DPA content compliant with Art. 28. Sub-processor list includes OVH Cloud (EU) only.'),

  -- Vodafone Italy — SLA + legal
  ('a4000000-0000-0000-0000-000000000010',
   'f1000000-0000-0000-0000-000000000017',
   'lksg', 'compliant', 88,
   'LkSG supply chain declaration on file. COC signed. No forced labor risk. Annual audit planned Q4 2026.'),

  -- Anthropic — for DPA ticket T04
  ('a4000000-0000-0000-0000-000000000011',
   null,
   'infosec', 'compliant', 88,
   'SOC 2 Type II current (2025 audit). ISO 27001 certified. Enterprise data isolation confirmed — no training on customer data. Sub-processors: AWS (EU/US), Cloudflare.'),

  ('a4000000-0000-0000-0000-000000000012',
   null,
   'gdpr', 'review_required', 75,
   'BLOCKER: DPA not yet signed. US-based processor — SCC Module 2 required. Standard SCC template generated — pending TrueSpend DPO signature. Data residency: US primary, EU available via enterprise tier.')

on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 14. LEGAL DOCUMENTS (feeds legal role view + signature flow)
-- ─────────────────────────────────────────────────────────────────────────────
insert into legal_documents (
  id, supplier_id, document_type, status,
  generated_at, signed_by_us_at,
  content_summary, storage_url, version
) values
  -- DataBricks NDA (from 09_mock_data ticket T04) — generated, awaiting signature
  ('ld000000-0000-0000-0000-000000000001',
   null,
   'nda', 'generated',
   now() - interval '6 hours', null,
   'Mutual NDA between TrueSpend GmbH (DE) and Databricks EMEA Ltd (IE). German law. 5-year confidentiality term. Exclusions: public domain, independently developed. Auto-generated by legal agent based on db/templates/nda_mutual_de.txt.',
   'https://docs.truespend.internal/nda/databricks-2026-05-nda.pdf', 1),

  -- Anthropic DPA — generated, awaiting signature
  ('ld000000-0000-0000-0000-000000000002',
   null,
   'dpa', 'generated',
   now() - interval '4 hours', null,
   'Art. 28 GDPR Data Processing Agreement between TrueSpend GmbH (Controller) and Anthropic Inc. (Processor). Includes SCC Module 2 (EU→US transfer). TOM Annex 2 with InfoSec controls. Sub-processor list: AWS, Cloudflare. Processing purpose: LLM inference for procurement workflows.',
   'https://docs.truespend.internal/dpa/anthropic-2026-05-dpa.pdf', 1),

  -- Accenture DPA — signed (existing relationship)
  ('ld000000-0000-0000-0000-000000000003',
   'f1000000-0000-0000-0000-000000000013',
   'dpa', 'signed_both',
   '2025-06-01', '2025-06-03',
   'Art. 28 GDPR DPA with Accenture GmbH. German law. Covers all active SOWs. Sub-processor list requires update (new sub-processors added in Phase 3). Annual review due 2026-06-01.',
   'https://docs.truespend.internal/dpa/accenture-2025-06-dpa.pdf', 2),

  -- Mistral AI NDA — generated for evaluation
  ('ld000000-0000-0000-0000-000000000004',
   null,
   'nda', 'generated',
   now() - interval '8 hours', null,
   'Mutual NDA between TrueSpend GmbH (DE) and Mistral AI S.A. (FR). French/German law crossover. 3-year term. Generated by legal agent during supplier onboarding workflow.',
   'https://docs.truespend.internal/nda/mistral-2026-05-nda.pdf', 1),

  -- Vodafone DPA — signed but under review (SLA breach context)
  ('ld000000-0000-0000-0000-000000000005',
   'f1000000-0000-0000-0000-000000000017',
   'dpa', 'signed_both',
   '2024-06-01', '2024-06-05',
   'Art. 28 GDPR DPA with Vodafone GmbH. Covers mobile fleet Italy + telecoms. Requires review: SLA breach clause not referenced in DPA. Legal team to add penalty clause cross-reference in next version.',
   'https://docs.truespend.internal/dpa/vodafone-2024-06-dpa.pdf', 1)

on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 15. ADDITIONAL WORKFLOW RUNS (adds history for new workflows)
-- ─────────────────────────────────────────────────────────────────────────────
insert into workflow_runs (
  id, workflow_name, status, started_at, ended_at, error_message
) values
  ('a7000000-0000-0000-0000-000000000010',
   'vps_monitor', 'success',
   now() - interval '43 minutes', now() - interval '42 minutes' + interval '8 seconds', null),
  ('a7000000-0000-0000-0000-000000000011',
   'vps_monitor', 'success',
   now() - interval '48 minutes', now() - interval '47 minutes' + interval '7 seconds', null),
  ('a7000000-0000-0000-0000-000000000012',
   'vps_monitor', 'success',
   now() - interval '53 minutes', now() - interval '52 minutes' + interval '6 seconds', null),
  ('a7000000-0000-0000-0000-000000000013',
   'invoice_processor', 'success',
   now() - interval '2 days', now() - interval '2 days' + interval '22 seconds', null),
  ('a7000000-0000-0000-0000-000000000014',
   'invoice_processor', 'success',
   now() - interval '29 days', now() - interval '29 days' + interval '19 seconds', null),
  ('a7000000-0000-0000-0000-000000000015',
   'supplier_onboarding', 'success',
   now() - interval '8 hours', now() - interval '8 hours' + interval '41 seconds', null),
  ('a7000000-0000-0000-0000-000000000016',
   'hyperscaler_monitor', 'success',
   now() - interval '23 hours', now() - interval '23 hours' + interval '12 seconds', null),
  ('a7000000-0000-0000-0000-000000000017',
   'reorder_trigger', 'success',
   now() - interval '23 hours' + interval '5 minutes', now() - interval '23 hours' + interval '5 minutes 9 seconds', null),
  ('a7000000-0000-0000-0000-000000000018',
   'llm_consumption', 'success',
   now() - interval '2 hours', now() - interval '2 hours' + interval '14 seconds', null),
  ('a7000000-0000-0000-0000-000000000019',
   'asset_depreciation', 'success',
   now() - interval '1 hour', now() - interval '1 hour' + interval '31 seconds', null),
  ('a7000000-0000-0000-0000-000000000020',
   'delivery_confirmation', 'success',
   now() - interval '20 days', now() - interval '20 days' + interval '6 seconds', null),
  ('a7000000-0000-0000-0000-000000000021',
   'intake_receiver', 'success',
   now() - interval '30 minutes', now() - interval '30 minutes' + interval '14 seconds', null)

on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- END — 12_big_mock_data.sql
-- Covers all 28 tables, all 8 user profiles, all major process flows.
-- ─────────────────────────────────────────────────────────────────────────────
