-- =============================================================================
-- TrueSpend — 12_big_mock_data.sql  (live-schema edition)
-- Mapped to actual column names from the live Railway DB.
-- Safe to re-run (ON CONFLICT DO NOTHING / DO UPDATE).
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. COST CENTERS
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
-- 2. BUDGET POOLS  (live: no name col, total_amount → reserve_eur)
-- ─────────────────────────────────────────────────────────────────────────────
insert into budget_pools (id, branch_id, fiscal_year, reserve_eur, committed, draw_authority, notes) values
  ('00000000-0000-0000-0000-000000000b01', 'b1000000-0000-0000-0000-000000000001', 2026,
   2500000.00, 400000.00, 'cfo',
   'HQ Strategic Reserve 2026. Last draw: €400k Accenture Phase 3.'),
  ('00000000-0000-0000-0000-000000000b02', 'b1000000-0000-0000-0000-000000000002', 2026,
   800000.00,  0.00,      'head_of_procurement',
   'DACH Flex Pool 2026.'),
  ('00000000-0000-0000-0000-000000000b03', 'b1000000-0000-0000-0000-000000000006', 2026,
   350000.00, 120000.00,  'head_of_procurement',
   'Nordics Growth Reserve 2026.')
on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. BUDGET POSITIONS
-- ─────────────────────────────────────────────────────────────────────────────
insert into budget_positions (id, branch_id, cost_center_id, category, period, budget, committed, spent) values
  ('00000000-0000-0000-0000-00000p000001', 'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001', 'hardware',       '2026-Q2', 8000000.00,  284400.00, 1420000.00),
  ('00000000-0000-0000-0000-00000p000002', 'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001', 'hyperscaler',    '2026-Q2', 4000000.00,   89000.00, 2180000.00),
  ('00000000-0000-0000-0000-00000p000003', 'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001', 'saas_license',   '2026-Q2', 3200000.00,  180000.00, 1960000.00),
  ('00000000-0000-0000-0000-00000p000004', 'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000002', 'services',       '2026-Q2', 2400000.00,  180000.00,  840000.00),
  ('00000000-0000-0000-0000-00000p000005', 'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001', 'ai_consumption', '2026-Q2',  420000.00,   48000.00,  210600.00),
  ('00000000-0000-0000-0000-00000p000006', 'b1000000-0000-0000-0000-000000000002', 'cc000000-0000-0000-0000-000000000003', 'hardware',       '2026-Q2', 5000000.00,  205000.00, 2340000.00),
  ('00000000-0000-0000-0000-00000p000007', 'b1000000-0000-0000-0000-000000000002', 'cc000000-0000-0000-0000-000000000003', 'saas_license',   '2026-Q2', 1400000.00,   72000.00,  940000.00),
  ('00000000-0000-0000-0000-00000p000008', 'b1000000-0000-0000-0000-000000000002', 'cc000000-0000-0000-0000-000000000010', 'ai_consumption', '2026-Q2',  180000.00,   24000.00,   71610.00),
  ('00000000-0000-0000-0000-00000p000009', 'b1000000-0000-0000-0000-000000000003', 'cc000000-0000-0000-0000-000000000005', 'hardware',       '2026-Q2', 2200000.00,  109200.00,  680000.00),
  ('00000000-0000-0000-0000-00000p000010', 'b1000000-0000-0000-0000-000000000005', 'cc000000-0000-0000-0000-000000000007', 'saas_license',   '2026-Q2',  900000.00,   72000.00,  730000.00),
  ('00000000-0000-0000-0000-00000p000011', 'b1000000-0000-0000-0000-000000000005', 'cc000000-0000-0000-0000-000000000013', 'ai_consumption', '2026-Q2',   62000.00,   18000.00,   59520.00),
  ('00000000-0000-0000-0000-00000p000012', 'b1000000-0000-0000-0000-000000000006', 'cc000000-0000-0000-0000-000000000011', 'hardware',       '2026-Q2',  480000.00,  120000.00,  190000.00),
  ('00000000-0000-0000-0000-00000p000013', 'b1000000-0000-0000-0000-000000000004', 'cc000000-0000-0000-0000-000000000014', 'saas_license',   '2026-Q2',  240000.00,    0.00,     155000.00),
  ('00000000-0000-0000-0000-00000p000014', 'b1000000-0000-0000-0000-000000000009', 'cc000000-0000-0000-0000-000000000012', 'hardware',       '2026-Q2',  290000.00,    0.00,     140000.00)
on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. ASSETS  (live: id, name, branch_id, po_id, purchase_value, book_value,
--                   warranty_expiry, status)
-- ─────────────────────────────────────────────────────────────────────────────
insert into assets (id, name, branch_id, po_id, purchase_value, book_value, warranty_expiry, status) values
  ('00000000-0000-0000-0000-000000000a01', 'DACH-LT-0001 — Lenovo ThinkPad T14s Gen4 (jana.schmidt)',
   'b1000000-0000-0000-0000-000000000002', 'a8000000-0000-0000-0000-000000000002',
   1890.00, 840.00, '2027-09-01', 'active'),

  ('00000000-0000-0000-0000-000000000a02', 'DACH-LT-0002 — Lenovo ThinkPad T14s Gen4 (lena.hoffmann)',
   'b1000000-0000-0000-0000-000000000002', 'a8000000-0000-0000-0000-000000000002',
   1890.00, 840.00, '2027-09-01', 'active'),

  ('00000000-0000-0000-0000-000000000a03', 'DACH-LT-0003 — Lenovo ThinkPad T14s Gen3 — WARRANTY EXPIRED',
   'b1000000-0000-0000-0000-000000000002', null,
   1650.00, 412.50, '2026-03-10', 'active'),

  ('00000000-0000-0000-0000-000000000a04', 'HQ-SRV-0001 — Dell PowerEdge R750',
   'b1000000-0000-0000-0000-000000000001', 'a8000000-0000-0000-0000-000000000001',
   23700.00, 23226.00, '2029-05-12', 'active'),

  ('00000000-0000-0000-0000-000000000a05', 'HQ-SRV-0002 — Dell PowerEdge R750',
   'b1000000-0000-0000-0000-000000000001', 'a8000000-0000-0000-0000-000000000001',
   23700.00, 23226.00, '2029-05-12', 'active'),

  ('00000000-0000-0000-0000-000000000a06', 'UK-LT-0041 — Apple MacBook Pro 14" M3 Pro',
   'b1000000-0000-0000-0000-000000000003', 'a8000000-0000-0000-0000-000000000003',
   4503.00, 4377.92, '2028-05-25', 'active'),

  ('00000000-0000-0000-0000-000000000a07', 'DACH-LT-0007 — Lenovo ThinkPad T490 — EOL (book value 5.6%)',
   'b1000000-0000-0000-0000-000000000002', null,
   1400.00, 77.78, '2026-03-01', 'active'),

  ('00000000-0000-0000-0000-000000000a08', 'NORD-LT-0001 — Lenovo ThinkPad T14s Gen3',
   'b1000000-0000-0000-0000-000000000006', null,
   1720.00, 430.00, '2026-09-15', 'active'),

  ('00000000-0000-0000-0000-000000000a09', 'CEE-LT-0001 — Lenovo ThinkPad E14 Gen4',
   'b1000000-0000-0000-0000-000000000009', null,
   980.00, 571.67, '2027-01-10', 'active'),

  ('00000000-0000-0000-0000-000000000a10', 'HQ-MON-0012 — Dell UltraSharp U2722D — WARRANTY EXPIRED',
   'b1000000-0000-0000-0000-000000000001', null,
   680.00, 250.00, '2025-11-01', 'active')

on conflict (id) do update set
  book_value = excluded.book_value;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. ASSET DEPRECIATION LOG  (live: depreciation not depreciation_amount,
--                                   no book_value_before, no method_used etc.)
-- ─────────────────────────────────────────────────────────────────────────────
insert into asset_depreciation_log (id, asset_id, period, depreciation, book_value_after) values
  ('00000000-0000-0000-0000-000000000d01', '00000000-0000-0000-0000-000000000a01', '2026-04', 52.50,  840.00),
  ('00000000-0000-0000-0000-000000000d02', '00000000-0000-0000-0000-000000000a02', '2026-04', 52.50,  840.00),
  ('00000000-0000-0000-0000-000000000d03', '00000000-0000-0000-0000-000000000a03', '2026-04', 45.83,  412.50),
  ('00000000-0000-0000-0000-000000000d04', '00000000-0000-0000-0000-000000000a07', '2026-04', 38.89,  116.67),
  ('00000000-0000-0000-0000-000000000d05', '00000000-0000-0000-0000-000000000a08', '2026-04', 47.78,  430.00),
  ('00000000-0000-0000-0000-000000000d06', '00000000-0000-0000-0000-000000000a09', '2026-04', 27.22,  571.67),
  ('00000000-0000-0000-0000-000000000d07', '00000000-0000-0000-0000-000000000a10', '2026-04', 10.50,  250.00),
  ('00000000-0000-0000-0000-000000000d08', '00000000-0000-0000-0000-000000000a01', '2026-05', 52.50,  787.50),
  ('00000000-0000-0000-0000-000000000d09', '00000000-0000-0000-0000-000000000a02', '2026-05', 52.50,  787.50),
  ('00000000-0000-0000-0000-000000000d10', '00000000-0000-0000-0000-000000000a03', '2026-05', 45.83,  366.67),
  ('00000000-0000-0000-0000-000000000d11', '00000000-0000-0000-0000-000000000a07', '2026-05', 38.89,   77.78),
  ('00000000-0000-0000-0000-000000000d12', '00000000-0000-0000-0000-000000000a08', '2026-05', 47.78,  382.22),
  ('00000000-0000-0000-0000-000000000d13', '00000000-0000-0000-0000-000000000a09', '2026-05', 27.22,  544.45),
  ('00000000-0000-0000-0000-000000000d14', '00000000-0000-0000-0000-000000000a10', '2026-05', 10.50,  239.50)
on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. LICENSE ASSIGNMENTS  (live: no usage_depth_pct FK issue — omit)
-- ─────────────────────────────────────────────────────────────────────────────
insert into license_assignments (
  id, entitlement_id, assigned_to_user, assigned_to_asset_id,
  cost_center_id, ticket_id, last_active_at, active, assigned_at
) values
  ('00000000-0000-0000-0000-000000000l01',
   'ae000000-0000-0000-0000-000000000001',
   'thomas.mueller@company.com', null,
   'cc000000-0000-0000-0000-000000000003',
   'a9000000-0000-0000-0000-000000000006',
   now() - interval '1 hour', true, now() - interval '18 months'),

  ('00000000-0000-0000-0000-000000000l02',
   'ae000000-0000-0000-0000-000000000001',
   'jana.schmidt@company.com', null,
   'cc000000-0000-0000-0000-000000000004',
   null,
   now() - interval '2 hours', true, now() - interval '24 months'),

  ('00000000-0000-0000-0000-000000000l03',
   'ae000000-0000-0000-0000-000000000001',
   'lena.hoffmann@company.com', null,
   'cc000000-0000-0000-0000-000000000003',
   null,
   now() - interval '30 minutes', true, now() - interval '18 months'),

  ('00000000-0000-0000-0000-000000000l04',
   'ae000000-0000-0000-0000-000000000002',
   'former.employee.uk@company.com', null,
   'cc000000-0000-0000-0000-000000000005',
   null,
   now() - interval '95 days', true, now() - interval '10 months'),

  ('00000000-0000-0000-0000-000000000l05',
   'ae000000-0000-0000-0000-000000000003',
   'marc.dupont@company.com', null,
   'cc000000-0000-0000-0000-000000000007',
   null,
   now() - interval '45 minutes', true, now() - interval '12 months'),

  ('00000000-0000-0000-0000-000000000l06',
   'ae000000-0000-0000-0000-000000000004',
   'erik.lindqvist@company.com', null,
   'cc000000-0000-0000-0000-000000000011',
   null,
   now() - interval '20 minutes', true, now() - interval '9 months'),

  ('00000000-0000-0000-0000-000000000l07',
   'ae000000-0000-0000-0000-000000000004',
   'inactive.nordic@company.com', null,
   null, null,
   now() - interval '60 days', true, now() - interval '9 months')

on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. INVOICES  (live: no invoice_date col — use received_at)
-- ─────────────────────────────────────────────────────────────────────────────
insert into invoices (
  id, po_id, supplier_id, invoice_number,
  amount_eur, currency, raw_amount, raw_currency, vat_amount,
  match_result, status, received_at, matched_at
) values
  ('00000000-0000-0000-0000-000000000i01',
   'a8000000-0000-0000-0000-000000000001',
   'f1000000-0000-0000-0000-000000000001',
   'DELL-INV-2026-08841',
   284400.00, 'EUR', 284400.00, 'EUR', 54036.00,
   'matched', 'approved',
   now() - interval '15 days', now() - interval '15 days'),

  ('00000000-0000-0000-0000-000000000i02',
   'a8000000-0000-0000-0000-000000000004',
   'f1000000-0000-0000-0000-000000000004',
   'AWS-2026-04-EMEA-0049182',
   89000.00, 'EUR', 89000.00, 'EUR', 0.00,
   'matched', 'approved',
   now() - interval '29 days', now() - interval '29 days'),

  ('00000000-0000-0000-0000-000000000i03',
   'a8000000-0000-0000-0000-000000000005',
   'f1000000-0000-0000-0000-000000000008',
   'SF-FR-2026-INV-04421',
   74016.00, 'EUR', 74016.00, 'EUR', 0.00,
   'amount_mismatch', 'pending',
   now() - interval '2 days', now() - interval '2 days')

on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. PAYMENT INSTRUCTIONS  (live: id, invoice_id, amount_eur, due_date, status)
-- ─────────────────────────────────────────────────────────────────────────────
insert into payment_instructions (id, invoice_id, amount_eur, due_date, status) values
  ('00000000-0000-0000-0000-000000000pi1',
   '00000000-0000-0000-0000-000000000i01',
   338436.00, '2026-06-14', 'paid'),

  ('00000000-0000-0000-0000-000000000pi2',
   '00000000-0000-0000-0000-000000000i02',
   89000.00, '2026-05-30', 'paid')

on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. ERP SYNC QUEUE  (live: id, entity_type, entity_id, payload, status)
-- ─────────────────────────────────────────────────────────────────────────────
insert into erp_sync_queue (id, entity_type, entity_id, payload, status) values
  ('00000000-0000-0000-0000-000000000e01',
   'payment_instructions', '00000000-0000-0000-0000-000000000pi1',
   '{"po_number":"PO-HQ-2026-0041","supplier":"Dell Technologies","amount_eur":284400,"payment_ref":"TS-PAY-2026-0041"}'::jsonb,
   'synced'),

  ('00000000-0000-0000-0000-000000000e02',
   'payment_instructions', '00000000-0000-0000-0000-000000000pi2',
   '{"po_number":"PO-HQ-2026-0039","supplier":"AWS EMEA SARL","amount_eur":89000,"reverse_charge":true}'::jsonb,
   'synced')

on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. HYPERSCALER POSITIONS  (live: no flag_overrun — use overshoot_risk)
-- ─────────────────────────────────────────────────────────────────────────────
insert into hyperscaler_positions (
  id, branch_id, provider, account_id, service_name, period, contract_id,
  committed_eur, commitment_type, commitment_end,
  mtd_spend_eur, daily_burn_eur, projected_eur,
  reservation_util, idle_resources_eur,
  overshoot_risk, undershoot_risk, snapshot_date
) values
  ('00000000-0000-0000-0000-000000000h01',
   'b1000000-0000-0000-0000-000000000001', 'AWS', '123456789012', 'EC2/S3/RDS', '2026-05',
   'c1000000-0000-0000-0000-000000000014',
   1000000.00, 'EDP', '2026-11-26',
   841200.00, 33648.00, 1008000.00,
   0.84, 12400.00, true, false, '2026-05-30'),

  ('00000000-0000-0000-0000-000000000h02',
   'b1000000-0000-0000-0000-000000000002', 'GCP', 'truespend-dach-prod', 'Compute Engine', '2026-05',
   'c1000000-0000-0000-0000-000000000015',
   400000.00, 'CUD', '2026-10-26',
   376000.00, 14960.00, 393000.00,
   0.94, 3200.00, false, false, '2026-05-30'),

  ('00000000-0000-0000-0000-000000000h03',
   'b1000000-0000-0000-0000-000000000003', 'Azure', 'truespend-uk-prod', 'Virtual Machines', '2026-05',
   'c1000000-0000-0000-0000-000000000016',
   258333.00, 'Reservation', '2026-12-06',
   173220.00, 6929.00, 208000.00,
   0.67, 28400.00, false, true, '2026-05-30'),

  ('00000000-0000-0000-0000-000000000h04',
   'b1000000-0000-0000-0000-000000000001', 'AWS', '123456789012', 'EC2/S3/RDS', '2026-04',
   'c1000000-0000-0000-0000-000000000014',
   1000000.00, 'EDP', '2026-11-26',
   987000.00, null, null,
   0.81, 9800.00, false, false, '2026-04-30'),

  ('00000000-0000-0000-0000-000000000h05',
   'b1000000-0000-0000-0000-000000000001', 'AWS', '123456789012', 'EC2/S3/RDS', '2026-03',
   'c1000000-0000-0000-0000-000000000014',
   1000000.00, 'EDP', '2026-11-26',
   924000.00, null, null,
   0.79, 11200.00, false, false, '2026-03-31')

on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. LLM API KEYS + CONSUMPTION (supplement existing)
-- ─────────────────────────────────────────────────────────────────────────────
insert into llm_api_keys (
  id, provider, key_ref, owner_user_id, team_name,
  branch_id, cost_center_id, monthly_budget_eur
) values
  ('a5000000-0000-0000-0000-000000000004',
   'anthropic', 'sk-ant-...nord', 'e1000000-0000-0000-0000-000000000004', 'Nordics Product',
   'b1000000-0000-0000-0000-000000000006', 'cc000000-0000-0000-0000-000000000011',
   930.00)
on conflict (id) do nothing;

insert into llm_consumption (
  id, api_key_id, provider, model, period,
  branch_id, cost_center_id,
  input_tokens, output_tokens, cost_usd, cost_eur
) values
  ('a6000000-0000-0000-0000-000000000005',
   'a5000000-0000-0000-0000-000000000001', 'anthropic', 'claude-sonnet-4-6', '2026-03',
   'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001',
   9200000, 2100000, 1920.00, 1785.60),

  ('a6000000-0000-0000-0000-000000000006',
   'a5000000-0000-0000-0000-000000000001', 'anthropic', 'claude-sonnet-4-6', '2026-02',
   'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001',
   8100000, 1900000, 1698.00, 1579.14),

  ('a6000000-0000-0000-0000-000000000007',
   'a5000000-0000-0000-0000-000000000002', 'anthropic', 'claude-sonnet-4-6', '2026-04',
   'b1000000-0000-0000-0000-000000000002', 'cc000000-0000-0000-0000-000000000003',
   5800000, 1400000, 1218.00, 1132.74),

  ('a6000000-0000-0000-0000-000000000008',
   'a5000000-0000-0000-0000-000000000002', 'anthropic', 'claude-sonnet-4-6', '2026-03',
   'b1000000-0000-0000-0000-000000000002', 'cc000000-0000-0000-0000-000000000003',
   4900000, 1100000, 1008.00, 937.44),

  ('a6000000-0000-0000-0000-000000000009',
   'a5000000-0000-0000-0000-000000000003', 'openai', 'gpt-4o', '2026-04',
   'b1000000-0000-0000-0000-000000000005', 'cc000000-0000-0000-0000-000000000007',
   3400000, 800000, 1060.00, 985.80),

  ('a6000000-0000-0000-0000-000000000010',
   'a5000000-0000-0000-0000-000000000004', 'anthropic', 'claude-sonnet-4-6', '2026-05',
   'b1000000-0000-0000-0000-000000000006', 'cc000000-0000-0000-0000-000000000011',
   2100000, 480000, 444.00, 412.92),

  -- Anomaly spike — HQ key 3.2× daily avg on 2026-05-28
  ('a6000000-0000-0000-0000-000000000011',
   'a5000000-0000-0000-0000-000000000001', 'anthropic', 'claude-sonnet-4-6', '2026-05-28',
   'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001',
   7200000, 1800000, 268.80, 249.98)

on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 12. TICKETS  (live schema — uses value_eur not amount_eur for display,
--               status enum includes open/pending_confirm/pending_review etc.)
-- ─────────────────────────────────────────────────────────────────────────────
insert into tickets (
  id, reference, source, status, title, description,
  category, amount, amount_eur, value_eur, currency,
  supplier_id, branch_id, cost_center_id, owner_id,
  review_type, review_notes, jira_key, pdf_url,
  created_at, target_close
) values

  ('00000000-0000-0000-0000-000000000t01',
   'TS-2026-0201', 'jira', 'pending_confirm',
   'M365 E5 seat — Lisa Kerr (UK Sales)',
   'New hire Lisa Kerr joins UK Sales 2026-06-15. Manager pre-approved M365 E5. Jira REQ-2201.',
   'saas_license', 2000.00, 2000.00, 2000.00, 'EUR',
   'f1000000-0000-0000-0000-000000000007', 'b1000000-0000-0000-0000-000000000003',
   'cc000000-0000-0000-0000-000000000005', 'e1000000-0000-0000-0000-000000000006',
   'budget_check', 'UK saas bucket 69% committed. 115 shelfware E5 seats available. No PO needed.',
   null, null,
   now() - interval '3 hours', now() + interval '1 day'),

  ('00000000-0000-0000-0000-000000000t02',
   'TS-2026-0202', 'automatic', 'pending_review',
   'Invoice mismatch — Salesforce France +€2,016 over PO',
   'Invoice SF-FR-2026-INV-04421 for €74,016 vs PO €72,000. Delta 2.8% exceeds 2% tolerance.',
   'saas_license', 74016.00, 74016.00, 74016.00, 'EUR',
   'f1000000-0000-0000-0000-000000000008', 'b1000000-0000-0000-0000-000000000005',
   'cc000000-0000-0000-0000-000000000007', 'e1000000-0000-0000-0000-000000000002',
   'budget_overrun', 'Variance 2.8% > 2% tolerance. Salesforce billing overlap explanation plausible.',
   null, null,
   now() - interval '2 days', now() + interval '2 days'),

  ('00000000-0000-0000-0000-000000000t03',
   'TS-2026-0203', 'automatic', 'pending_confirm',
   'Reorder: Lenovo ThinkPad T14s x15 — DACH Engineering',
   'DACH laptop pool at 8 available. Reorder point 10. 3 onboarding requests queued for Q3. PO for 15 units at €1,890 = €28,350.',
   'hardware', 28350.00, 28350.00, 28350.00, 'EUR',
   'f1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000002',
   'cc000000-0000-0000-0000-000000000010', 'e1000000-0000-0000-0000-000000000003',
   null, 'Reorder confidence 91%. Contract active, within volume tier. Budget available.',
   null, null,
   now() - interval '6 hours', now() + interval '1 day'),

  ('00000000-0000-0000-0000-000000000t04',
   'TS-2026-0204', 'compliance', 'signature_required',
   'DPA — Anthropic Inc. — Art. 28 GDPR — signature required',
   'LLM API usage confirmed. Art. 28 GDPR DPA required before production data sent to API.',
   'ai_consumption', null, null, null, 'EUR',
   null, 'b1000000-0000-0000-0000-000000000001',
   'cc000000-0000-0000-0000-000000000008', 'e1000000-0000-0000-0000-000000000001',
   'legal', 'DPA includes SCC Module 2 (EU→US). TOM Annex validated. Ready for CPO/DPO signature.',
   null, 'https://docs.truespend.internal/dpa/anthropic-2026-05-dpa.pdf',
   now() - interval '4 hours', now() + interval '3 days'),

  ('00000000-0000-0000-0000-000000000t05',
   'TS-2026-0205', 'automatic', 'pending_confirm',
   'Asset EOL — DACH-LT-0007 (ThinkPad T490) — replacement PO',
   'Book value €77.78 (5.6% of cost). Warranty expired 2026-03-01. 4 incidents in L6M.',
   'hardware', 1890.00, 1890.00, 1890.00, 'EUR',
   'f1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000002',
   'cc000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000006',
   null, 'EOL criteria met. Lenovo T14s Gen4 replacement at €1,890. Decommission on delivery.',
   null, null,
   now() - interval '1 hour', now() + interval '2 days'),

  ('00000000-0000-0000-0000-000000000t06',
   'TS-2026-0206', 'compliance', 'pending_review',
   'Supplier onboarding — Mistral AI S.A. — compliance review',
   'New AI supplier: Mistral AI S.A. (Paris). 4 compliance agents completed. InfoSec gap: SOC 2 Type I only.',
   null, null, null, null, 'EUR',
   null, 'b1000000-0000-0000-0000-000000000001',
   'cc000000-0000-0000-0000-000000000008', 'e1000000-0000-0000-0000-000000000001',
   'compliance_flag', 'BLOCKER: SOC 2 Type II required before production. NDA generated. GDPR clean. LkSG clean.',
   null, null,
   now() - interval '8 hours', now() + interval '5 days'),

  ('00000000-0000-0000-0000-000000000t07',
   'TS-2026-0207', 'intake', 'pending_confirm',
   '4K monitors x4 — DACH Engineering team expansion',
   'Engineering growing by 4 in June 2026. Dell UltraSharp 27" 4K at €680 each = €2,720.',
   'hardware', 2720.00, 2720.00, 2720.00, 'EUR',
   'f1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002',
   'cc000000-0000-0000-0000-000000000010', 'e1000000-0000-0000-0000-000000000007',
   null, 'All signals green. Dell preferred vendor. Budget available. One_touch: Q2 at 51% committed.',
   null, null,
   now() - interval '30 minutes', now() + interval '1 day'),

  ('00000000-0000-0000-0000-000000000t08',
   'TS-2026-0208', 'renewal', 'escalated',
   'SAP S/4HANA Global License — renewal €6.85M + 7% increase',
   'SAP proposing 7% increase: €6.4M → €6.85M (+€448k/year). Expires 2026-07-12. Jira PROC-452.',
   'saas_license', 6848000.00, 6848000.00, 6848000.00, 'EUR',
   'f1000000-0000-0000-0000-000000000009', 'b1000000-0000-0000-0000-000000000001',
   'cc000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000000',
   'major_contract', '€6.85M > €100k threshold. 3 open P2 support tickets = negotiation leverage.',
   'PROC-452', null,
   now() - interval '12 hours', now() + interval '7 days'),

  ('00000000-0000-0000-0000-000000000t09',
   'TS-2026-0209', 'monitoring', 'pending_confirm',
   'VPS — Load spike 7.3 avg — dockerd accumulation suspected',
   'Load avg 1m: 7.27 (threshold 3.0). dockerd 48% CPU. All containers running.',
   null, null, null, null, 'EUR',
   null, 'b1000000-0000-0000-0000-000000000001',
   'cc000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000005',
   'infrastructure', 'Action: systemctl restart docker. Steal time 72% = Hostinger baseline, not actionable.',
   null, null,
   now() - interval '43 minutes', now() + interval '4 hours'),

  ('00000000-0000-0000-0000-000000000t10',
   'TS-2026-0210', 'renewal', 'pending_review',
   'Accenture SOW Phase 3 — penalty clause negotiation required',
   'Legal reviewing penalty clause and IP ownership terms. Joint IP ownership in draft is a blocker.',
   'services', 180000.00, 180000.00, 180000.00, 'EUR',
   'f1000000-0000-0000-0000-000000000013', 'b1000000-0000-0000-0000-000000000001',
   'cc000000-0000-0000-0000-000000000008', 'e1000000-0000-0000-0000-000000000001',
   'legal', 'IP must be TrueSpend sole ownership. Penalty cap needs raising to 15%. Sub-processor list required.',
   'PROC-441', null,
   now() - interval '18 hours', now() + interval '3 days'),

  ('00000000-0000-0000-0000-000000000t11',
   'TS-2026-0211', 'automatic', 'pending_confirm',
   'LLM spend anomaly — HQ Anthropic key — 3.2× daily average',
   'Daily spike 2026-05-28: €249.98 vs 7-day avg €78.12 (3.2×). Key: sk-ant-...hq (IT Platform).',
   'ai_consumption', 249.98, 249.98, 249.98, 'EUR',
   null, 'b1000000-0000-0000-0000-000000000001',
   'cc000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
   null, '9M tokens in one day (10× typical). Investigate before May budget close.',
   null, null,
   now() - interval '2 hours', now() + interval '1 day'),

  ('00000000-0000-0000-0000-000000000t12',
   'TS-2026-0212', 'intake', 'open',
   'Lenovo ThinkPad x40 — delivery confirmation pending',
   'PO-DACH-2026-0087 sent. 40× ThinkPad T14s. Expected delivery 2026-06-14.',
   'hardware', 205000.00, 205000.00, 205000.00, 'EUR',
   'f1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000002',
   'cc000000-0000-0000-0000-000000000010', 'e1000000-0000-0000-0000-000000000003',
   null, null, null, null,
   now() - interval '27 days', now() + interval '15 days')

on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 13. SUPPLIER EMAILS
-- ─────────────────────────────────────────────────────────────────────────────
insert into supplier_emails (
  id, supplier_id, contract_id, direction, subject, body_summary,
  commitments, order_reference, flagged, flag_reason, received_at
) values
  ('00000000-0000-0000-0000-000000000s01',
   'f1000000-0000-0000-0000-000000000003',
   'c1000000-0000-0000-0000-000000000006',
   'inbound', 'Re: Apple Device Program UK — Contract Renewal Discussion',
   'Apple confirms 9% increase. 3-year lock at 7% available. MacBook backlog clearing July 2026.',
   ARRAY['3-year lock at 7%','Backlog clearing July 2026'],
   null, false, null, now() - interval '5 days'),

  ('00000000-0000-0000-0000-000000000s02',
   'f1000000-0000-0000-0000-000000000008',
   'c1000000-0000-0000-0000-000000000007',
   'inbound', 'Invoice SF-FR-2026-INV-04421 — Billing Adjustment Explanation',
   'One-day billing overlap. One-time adjustment. Case SF-2026-FR-08821 created.',
   ARRAY['One-time, no future impact'],
   'PO-FR-2026-0015', false, null, now() - interval '2 days'),

  ('00000000-0000-0000-0000-000000000s03',
   'f1000000-0000-0000-0000-000000000013',
   'c1000000-0000-0000-0000-000000000017',
   'inbound', 'Phase 3 SOW Extension Proposal — Accenture Digital Transformation',
   '6-week extension at €30k/week for ETL + hyperscaler migration.',
   ARRAY['6-week extension at €30k/week'],
   null, true, 'Rate 36% above benchmark. IP ownership clause unacceptable.',
   now() - interval '3 days'),

  ('00000000-0000-0000-0000-000000000s04',
   'f1000000-0000-0000-0000-000000000002',
   'c1000000-0000-0000-0000-000000000011',
   'outbound', 'PO-DACH-2026-0087 — Order Confirmation Request',
   'PO for 40× ThinkPad T14s Gen4. Confirm against contract price €1,890/unit.',
   ARRAY['Awaiting delivery confirmation'],
   'PO-DACH-2026-0087', false, null, now() - interval '27 days'),

  ('00000000-0000-0000-0000-000000000s05',
   'f1000000-0000-0000-0000-000000000002',
   'c1000000-0000-0000-0000-000000000011',
   'inbound', 'Re: PO-DACH-2026-0087 — Shipment Confirmed',
   '40 units despatched 2026-05-10. Delivery 2026-06-14. DHL 1Z999AA10123456784.',
   ARRAY['Delivery 2026-06-14','Invoice within 5 days of delivery'],
   'PO-DACH-2026-0087', false, null, now() - interval '20 days'),

  ('00000000-0000-0000-0000-000000000s06',
   'f1000000-0000-0000-0000-000000000017',
   'c1000000-0000-0000-0000-000000000009',
   'inbound', 'Network Incident Report — February 2026 Outage — Vodafone Italy',
   '18-hour outage Feb 2026. €4,200 SLA credit on Q3 invoice. Report delayed 90+ days.',
   ARRAY['€4,200 SLA credit Q3'],
   null, true, 'SLA breach not formally invoked. 15% price increase requested on same contract.',
   now() - interval '4 days')

on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 14. LEGAL DOCUMENTS  (live: doc_type not document_type, content not summary)
-- ─────────────────────────────────────────────────────────────────────────────
insert into legal_documents (id, supplier_id, doc_type, content, status) values
  ('00000000-0000-0000-0000-000000000ld1',
   null, 'nda',
   'Mutual NDA — TrueSpend GmbH ↔ Databricks EMEA Ltd. German law. 5-year term. Auto-generated 2026-05-30.',
   'draft'),

  ('00000000-0000-0000-0000-000000000ld2',
   null, 'dpa',
   'Art. 28 GDPR DPA — TrueSpend GmbH (Controller) ↔ Anthropic Inc. (Processor). SCC Module 2 (EU→US). TOM Annex. Generated 2026-05-30.',
   'draft'),

  ('00000000-0000-0000-0000-000000000ld3',
   'f1000000-0000-0000-0000-000000000013', 'dpa',
   'Art. 28 GDPR DPA with Accenture GmbH. Covers all active SOWs. Sub-processor list update due 2026-06-01.',
   'active'),

  ('00000000-0000-0000-0000-000000000ld4',
   null, 'nda',
   'Mutual NDA — TrueSpend GmbH ↔ Mistral AI S.A. French/German law crossover. 3-year term. Generated 2026-05-30.',
   'draft'),

  ('00000000-0000-0000-0000-000000000ld5',
   'f1000000-0000-0000-0000-000000000017', 'dpa',
   'Art. 28 GDPR DPA with Vodafone GmbH. Covers mobile fleet Italy + telecoms. Penalty clause cross-reference missing.',
   'active')

on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 15. WORKFLOW RUNS
-- ─────────────────────────────────────────────────────────────────────────────
insert into workflow_runs (id, workflow_name, status, started_at, ended_at) values
  ('a7000000-0000-0000-0000-000000000010', 'vps_monitor',           'success', now() - interval '43 minutes',  now() - interval '43 minutes'  + interval '8 seconds'),
  ('a7000000-0000-0000-0000-000000000011', 'vps_monitor',           'success', now() - interval '48 minutes',  now() - interval '48 minutes'  + interval '7 seconds'),
  ('a7000000-0000-0000-0000-000000000012', 'vps_monitor',           'success', now() - interval '53 minutes',  now() - interval '53 minutes'  + interval '6 seconds'),
  ('a7000000-0000-0000-0000-000000000013', 'invoice_processor',     'success', now() - interval '2 days',      now() - interval '2 days'      + interval '22 seconds'),
  ('a7000000-0000-0000-0000-000000000014', 'invoice_processor',     'success', now() - interval '29 days',     now() - interval '29 days'     + interval '19 seconds'),
  ('a7000000-0000-0000-0000-000000000015', 'supplier_onboarding',   'success', now() - interval '8 hours',     now() - interval '8 hours'     + interval '41 seconds'),
  ('a7000000-0000-0000-0000-000000000016', 'hyperscaler_monitor',   'success', now() - interval '23 hours',    now() - interval '23 hours'    + interval '12 seconds'),
  ('a7000000-0000-0000-0000-000000000017', 'reorder_trigger',       'success', now() - interval '23 hours'   + interval '5 minutes', now() - interval '23 hours' + interval '5 minutes 9 seconds'),
  ('a7000000-0000-0000-0000-000000000018', 'llm_consumption',       'success', now() - interval '2 hours',     now() - interval '2 hours'     + interval '14 seconds'),
  ('a7000000-0000-0000-0000-000000000019', 'asset_depreciation',    'success', now() - interval '1 hour',      now() - interval '1 hour'      + interval '31 seconds'),
  ('a7000000-0000-0000-0000-000000000020', 'delivery_confirmation', 'success', now() - interval '20 days',     now() - interval '20 days'     + interval '6 seconds'),
  ('a7000000-0000-0000-0000-000000000021', 'intake_receiver',       'success', now() - interval '30 minutes',  now() - interval '30 minutes'  + interval '14 seconds')
on conflict (id) do nothing;

-- =============================================================================
-- END 12_big_mock_data.sql
-- =============================================================================
