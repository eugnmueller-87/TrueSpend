-- =============================================================================
-- TrueSpend Mock Data — 09_mock_data.sql
-- Run AFTER 01–08 seeds. Safe to re-run (ON CONFLICT DO UPDATE / DO NOTHING).
-- Covers: cost_centers, license_entitlements, purchase_orders, tickets,
--         decisions, trace_log, compliance_checks, budget_buckets
-- Purpose: populate every Grafana dashboard + Operations Board with demo data
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. COST CENTERS (needed by budget positions + ticket joins)
-- ─────────────────────────────────────────────────────────────────────────────
insert into cost_centers (id, code, name, branch_id) values
  ('cc000000-0000-0000-0000-000000000001', 'IT-HQ',     'IT Global HQ',        'b1000000-0000-0000-0000-000000000001'),
  ('cc000000-0000-0000-0000-000000000002', 'FIN-HQ',    'Finance Global HQ',   'b1000000-0000-0000-0000-000000000001'),
  ('cc000000-0000-0000-0000-000000000003', 'IT-DACH',   'IT DACH',             'b1000000-0000-0000-0000-000000000002'),
  ('cc000000-0000-0000-0000-000000000004', 'SALES-DACH','Sales DACH',          'b1000000-0000-0000-0000-000000000002'),
  ('cc000000-0000-0000-0000-000000000005', 'IT-UK',     'IT UK & Ireland',     'b1000000-0000-0000-0000-000000000003'),
  ('cc000000-0000-0000-0000-000000000006', 'ENG-BNL',   'Engineering Benelux', 'b1000000-0000-0000-0000-000000000004'),
  ('cc000000-0000-0000-0000-000000000007', 'IT-FR',     'IT France',           'b1000000-0000-0000-0000-000000000005')
on conflict (id) do update set
  code   = excluded.code,
  name   = excluded.name;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. BUDGET BUCKETS (annual plan — Controlling layer)
--    Feeds the Budgets dashboard "plan vs actuals" panels
--    Schema: fiscal_year INT, quarter INT (1-4), planned_amount NUMERIC
-- ─────────────────────────────────────────────────────────────────────────────
insert into budget_buckets (id, branch_id, cost_center_id, category, fiscal_year, quarter, planned_amount, currency, notes) values
  -- Global HQ Q2 2026
  ('bb000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', null, 'hardware',       2026, 2, 8000000,  'EUR', 'Annual plan — hardware refresh cycle'),
  ('bb000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000001', null, 'hyperscaler',    2026, 2, 4000000,  'EUR', 'AWS EDP quarterly allocation'),
  ('bb000000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000001', null, 'saas_license',   2026, 2, 3200000,  'EUR', 'SAP + Workday + M365 global'),
  ('bb000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000001', null, 'services',       2026, 2, 2400000,  'EUR', 'Consulting & audit'),
  ('bb000000-0000-0000-0000-000000000005', 'b1000000-0000-0000-0000-000000000001', null, 'ai_consumption', 2026, 2,  420000,  'EUR', 'LLM API + AI SaaS'),
  -- DACH Q2 2026
  ('bb000000-0000-0000-0000-000000000006', 'b1000000-0000-0000-0000-000000000002', null, 'hardware',       2026, 2, 5000000,  'EUR', 'Lenovo fleet + Dell servers'),
  ('bb000000-0000-0000-0000-000000000007', 'b1000000-0000-0000-0000-000000000002', null, 'saas_license',   2026, 2, 1400000,  'EUR', 'M365 DACH + Slack'),
  ('bb000000-0000-0000-0000-000000000008', 'b1000000-0000-0000-0000-000000000002', null, 'ai_consumption', 2026, 2,  180000,  'EUR', 'AI tooling DACH engineering'),
  -- UK Q2 2026
  ('bb000000-0000-0000-0000-000000000009', 'b1000000-0000-0000-0000-000000000003', null, 'hardware',       2026, 2, 2200000,  'EUR', 'Apple device program UK'),
  ('bb000000-0000-0000-0000-000000000010', 'b1000000-0000-0000-0000-000000000003', null, 'saas_license',   2026, 2,  900000,  'EUR', 'M365 E5 UK'),
  -- France Q2 2026
  ('bb000000-0000-0000-0000-000000000011', 'b1000000-0000-0000-0000-000000000005', null, 'saas_license',   2026, 2,  900000,  'EUR', 'Salesforce France'),
  ('bb000000-0000-0000-0000-000000000012', 'b1000000-0000-0000-0000-000000000005', null, 'ai_consumption', 2026, 2,   62000,  'EUR', 'AI budget France — already over committed')
on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. LICENSE ENTITLEMENTS (feeds Expiring dashboard + license_waste_report)
--    Schema: total_cost_eur (not annual_cost_eur), no branch_id column
-- ─────────────────────────────────────────────────────────────────────────────
insert into license_entitlements (
  id, contract_id, supplier_id, product_name, product_code,
  license_type, total_seats, assigned_seats, active_seats, shelfware_seats, overage_seats,
  price_per_seat, total_cost_eur,
  term_start, term_end,
  utilization_pct, avg_feature_usage_depth,
  default_cost_center_id
) values

  -- Microsoft 365 E3 — DACH — expiring in 69 days (2026-08-06) — healthy
  ('ae000000-0000-0000-0000-000000000001',
   'c1000000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000007',
   'Microsoft 365 E3', 'CFQ7TTC0LH18',
   'named_user', 1400, 1380, 1240, 140, 0,
   1500.00, 2100000.00,
   '2025-08-07', '2026-08-06',
   89.9, 62.4,
   'cc000000-0000-0000-0000-000000000003'),

  -- Microsoft 365 E5 — UK — expiring in 47 days (2026-07-15)
  ('ae000000-0000-0000-0000-000000000002',
   'c1000000-0000-0000-0000-000000000012', 'f1000000-0000-0000-0000-000000000007',
   'Microsoft 365 E5', 'CFQ7TTC0LH19',
   'named_user', 700, 695, 580, 115, 0,
   2000.00, 1400000.00,
   '2025-07-16', '2026-07-15',
   83.5, 41.2,
   'cc000000-0000-0000-0000-000000000005'),

  -- Salesforce Sales Cloud — France — expiring in 32 days (2026-06-30) — CRITICAL
  ('ae000000-0000-0000-0000-000000000003',
   'c1000000-0000-0000-0000-000000000007', 'f1000000-0000-0000-0000-000000000008',
   'Salesforce Sales Cloud Enterprise', 'SF-SCENT-EU',
   'named_user', 300, 312, 298, 0, 12,
   6000.00, 1800000.00,
   '2025-06-01', '2026-06-30',
   95.5, 78.1,
   'cc000000-0000-0000-0000-000000000007'),

  -- Slack Business+ — Nordics — expiring in 85 days (2026-08-23)
  ('ae000000-0000-0000-0000-000000000004',
   'c1000000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000011',
   'Slack Business+', 'SLACK-BIZ-PLUS',
   'named_user', 620, 590, 420, 170, 0,
   500.00, 310000.00,
   '2025-08-24', '2026-08-23',
   71.2, 38.6,
   null),

  -- Zoom Business — Benelux — expiring in 36 days (2026-07-04)
  ('ae000000-0000-0000-0000-000000000005',
   'c1000000-0000-0000-0000-000000000010', 'f1000000-0000-0000-0000-000000000012',
   'Zoom Business', 'ZOOM-BIZ',
   'named_user', 360, 290, 180, 110, 0,
   500.00, 180000.00,
   '2025-06-05', '2026-07-04',
   62.1, 29.3,
   'cc000000-0000-0000-0000-000000000006'),

  -- SAP S/4HANA — Global HQ — expiring in 44 days (2026-07-12) — large value
  ('ae000000-0000-0000-0000-000000000006',
   'c1000000-0000-0000-0000-000000000008', 'f1000000-0000-0000-0000-000000000009',
   'SAP S/4HANA Enterprise', 'SAP-S4-ENT',
   'named_user', null, null, null, 0, 0,
   null, 6400000.00,
   '2024-07-13', '2026-07-12',
   null, null,
   'cc000000-0000-0000-0000-000000000001'),

  -- Workday HCM — Global HQ — expiring in 74 days (2026-08-11)
  ('ae000000-0000-0000-0000-000000000007',
   'c1000000-0000-0000-0000-000000000013', 'f1000000-0000-0000-0000-000000000010',
   'Workday HCM + Finance', 'WD-HCM-FIN',
   'named_user', null, null, null, 0, 0,
   null, 2800000.00,
   '2024-08-12', '2026-08-11',
   null, null,
   'cc000000-0000-0000-0000-000000000001'),

  -- Zoom HQ — shelfware example (not expiring soon — for waste report)
  ('ae000000-0000-0000-0000-000000000008',
   null, 'f1000000-0000-0000-0000-000000000012',
   'Zoom Business (HQ)', 'ZOOM-BIZ',
   'named_user', 200, 200, 62, 138, 0,
   500.00, 100000.00,
   '2025-11-01', '2026-11-01',
   31.0, 18.4,
   'cc000000-0000-0000-0000-000000000002')

on conflict (id) do update set
  utilization_pct        = excluded.utilization_pct,
  active_seats           = excluded.active_seats,
  assigned_seats         = excluded.assigned_seats,
  shelfware_seats        = excluded.shelfware_seats;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. PURCHASE ORDERS (feeds Operations Board + commitment register)
-- ─────────────────────────────────────────────────────────────────────────────
insert into purchase_orders (
  id, po_number, ticket_id, supplier_id, branch_id,
  description, amount, amount_eur, currency,
  status, po_date, expected_delivery
) values
  ('a8000000-0000-0000-0000-000000000001',
   'PO-HQ-2026-0041', null,
   'f1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001',
   'Dell PowerEdge R750 x12 — Data Center Refresh HQ',
   284400.00, 284400.00, 'EUR',
   'delivered', '2026-04-15', '2026-05-10'),

  ('a8000000-0000-0000-0000-000000000002',
   'PO-DACH-2026-0087', null,
   'f1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000002',
   'Lenovo ThinkPad T14s x40 — DACH Engineering Q2',
   205000.00, 205000.00, 'EUR',
   'sent', '2026-05-03', '2026-06-14'),

  ('a8000000-0000-0000-0000-000000000003',
   'PO-UK-2026-0023', null,
   'f1000000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000003',
   'Apple MacBook Pro M3 x28 — UK Sales Team',
   109200.00, 126108.00, 'GBP',
   'draft', '2026-05-20', '2026-06-28'),

  ('a8000000-0000-0000-0000-000000000004',
   'PO-HQ-2026-0039', null,
   'f1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000001',
   'AWS Compute — Additional EC2 capacity Q2 burst',
   89000.00, 89000.00, 'EUR',
   'invoiced', '2026-04-01', '2026-04-01'),

  ('a8000000-0000-0000-0000-000000000005',
   'PO-FR-2026-0015', null,
   'f1000000-0000-0000-0000-000000000008', 'b1000000-0000-0000-0000-000000000005',
   'Salesforce — 12 additional Sales Cloud seats Q2',
   72000.00, 72000.00, 'EUR',
   'sent', '2026-05-10', '2026-06-01')

on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. TICKETS + DECISIONS + TRACE LOG
--    Full approval trail for the Operations Board
--    Mix of: auto_executed (closed), pending_review (open), pending_confirm (open),
--            escalated, signature_required
-- ─────────────────────────────────────────────────────────────────────────────

-- Ticket 1: Auto-executed — small purchase, all signals green
insert into tickets (
  id, reference, source, status, title, description,
  category, amount, amount_eur, currency,
  supplier_id, branch_id, cost_center_id, owner_id,
  created_at, target_close
) values (
  'a9000000-0000-0000-0000-000000000001',
  'TS-2026-0101', 'intake', 'approved',
  'USB-C docking stations x10 — DACH IT',
  'Replacing end-of-life docking stations for DACH engineering team. Lenovo ThinkPad Ultra Dock.',
  'hardware', 4200.00, 4200.00, 'EUR',
  'f1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000002',
  'cc000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000005',
  now() - interval '5 days', now() - interval '4 days 22 hours'
) on conflict (id) do nothing;

insert into decisions (
  id, ticket_id, disposition, confidence,
  recommendation, reasoning,
  created_at
) values (
  'ad000000-0000-0000-0000-000000000001',
  'a9000000-0000-0000-0000-000000000001',
  'auto_execute', 0.9720,
  'Approve and issue PO to Lenovo DACH',
  'All 5 signals green. Amount €4,200 well within DACH hardware budget (available €900k). Lenovo is preferred vendor with green health. No compliance flags. Manager spend authority sufficient. Standard catalog item — no negotiation needed.', now() - interval '4 days 23 hours'
) on conflict (id) do nothing;

insert into trace_log (id, decision_id, signal, value, weight, green, notes, created_at) values
  ('a1000000-0000-0000-0000-000000000001', 'ad000000-0000-0000-0000-000000000001',
   'policy', '{"available": 900000, "committed_pct": 82}', 0.9500, true,
   'Budget available: €900k. Committed 82% of bucket. €4.2k is immaterial.', now() - interval '4 days 23 hours'),
  ('a1000000-0000-0000-0000-000000000002', 'ad000000-0000-0000-0000-000000000001',
   'supplier', '{"health": "green", "sla": "on_track", "disputes": 0}', 1.0000, true,
   'Lenovo DACH — green health, 95% on-time delivery L90D, zero disputes.', now() - interval '4 days 23 hours'),
  ('a1000000-0000-0000-0000-000000000003', 'ad000000-0000-0000-0000-000000000001',
   'policy', '{"gdpr": true, "nda": "signed", "sanctions": "clean"}', 1.0000, true,
   'Lenovo GDPR DPA signed. NDA in place. No sanctions hits.', now() - interval '4 days 23 hours'),
  ('a1000000-0000-0000-0000-000000000004', 'ad000000-0000-0000-0000-000000000001',
   'contract', '{"price_benchmark": "within_5pct", "preferred_vendor": true}', 0.9500, true,
   'Price within 5% of benchmark. Lenovo is preferred vendor for hardware.', now() - interval '4 days 23 hours'),
  ('a1000000-0000-0000-0000-000000000005', 'ad000000-0000-0000-0000-000000000001',
   'request', '{"spend_authority_ok": true, "category_match": true}', 0.9800, true,
   'Manager spend authority €50k covers €4.2k. Category hardware matches cost center profile.', now() - interval '4 days 23 hours')
on conflict (id) do nothing;

-- Ticket 2: One-touch — Salesforce seats above threshold
insert into tickets (
  id, reference, source, status, title, description,
  category, amount, amount_eur, currency,
  supplier_id, branch_id, cost_center_id, owner_id,
  review_type, review_notes,
  created_at, target_close
) values (
  'a9000000-0000-0000-0000-000000000002',
  'TS-2026-0118', 'intake', 'pending_confirm',
  '12 additional Salesforce Sales Cloud seats — France',
  'France sales team grew by 12 FTEs. Need additional Salesforce seats before month-end.',
  'saas_license', 72000.00, 72000.00, 'EUR',
  'f1000000-0000-0000-0000-000000000008', 'b1000000-0000-0000-0000-000000000005',
  'cc000000-0000-0000-0000-000000000007', 'e1000000-0000-0000-0000-000000000002',
  'budget_overrun',
  'France saas_license bucket is 114% committed. Adding €72k triggers manual review threshold. Salesforce contract also shows 12-seat overage — true-up risk at renewal. Recommend approval but flag for Q3 budget reallocation.',
  now() - interval '2 days', now() + interval '1 day'
) on conflict (id) do nothing;

insert into decisions (
  id, ticket_id, disposition, confidence,
  recommendation, reasoning,
  created_at
) values (
  'ad000000-0000-0000-0000-000000000002',
  'a9000000-0000-0000-0000-000000000002',
  'one_touch', 0.7840,
  'One-touch approval required — budget bucket overcommitted',
  'Amount €72k is within Marc Dupont spend authority (€250k). Supplier health green. However France saas_license bucket already at 114% committed — this spend pushes Q2 total to €803k vs €900k budget. Additionally the existing Salesforce entitlement shows 12-seat overage which will trigger true-up at renewal. Human confirmation needed before committing further.', now() - interval '2 days'
) on conflict (id) do nothing;

insert into trace_log (id, decision_id, signal, value, weight, green, notes, created_at) values
  ('a1000000-0000-0000-0000-000000000006', 'ad000000-0000-0000-0000-000000000002',
   'policy', '{"available": 97000, "committed_pct": 114}', 0.4200, false,
   'France saas_license Q2 bucket 114% committed. Available €97k. This purchase would bring to 122%.', now() - interval '2 days'),
  ('a1000000-0000-0000-0000-000000000007', 'ad000000-0000-0000-0000-000000000002',
   'supplier', '{"health": "green", "sla": "on_track", "disputes": 0}', 1.0000, true,
   'Salesforce Germany GmbH — green health, 98% uptime L30D.', now() - interval '2 days'),
  ('a1000000-0000-0000-0000-000000000008', 'ad000000-0000-0000-0000-000000000002',
   'policy', '{"gdpr": true, "nda": "signed", "overage_risk": true}', 0.7000, true,
   'Compliance OK. However entitlement shows 12-seat overage — true-up clause active at renewal.', now() - interval '2 days'),
  ('a1000000-0000-0000-0000-000000000009', 'ad000000-0000-0000-0000-000000000002',
   'contract', '{"renewal_state": "price_increase", "increase_pct": 12}', 0.5500, false,
   'Salesforce France contract in price_increase state — 12% increase proposed. Adding seats now locks in at higher rate.', now() - interval '2 days'),
  ('a1000000-0000-0000-0000-000000000010', 'ad000000-0000-0000-0000-000000000002',
   'request', '{"spend_authority_ok": true, "requester_validated": true}', 0.9500, true,
   'Marc Dupont spend authority €250k covers €72k. Requester identity confirmed.', now() - interval '2 days')
on conflict (id) do nothing;

-- Ticket 3: Escalated — €180k services engagement over threshold
insert into tickets (
  id, reference, source, status, title, description,
  category, amount, amount_eur, currency,
  supplier_id, branch_id, cost_center_id, owner_id,
  jira_key, review_type, review_notes,
  created_at, target_close
) values (
  'a9000000-0000-0000-0000-000000000003',
  'TS-2026-0122', 'intake', 'escalated',
  'Accenture — Phase 3 SOW extension €180k',
  'Digital transformation Phase 3 SOW. Accenture proposing 6-week extension at €30k/week for data migration workstream.',
  'services', 180000.00, 180000.00, 'EUR',
  'f1000000-0000-0000-0000-000000000013', 'b1000000-0000-0000-0000-000000000001',
  'cc000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001',
  'PROC-441',
  'major_contract',
  'Amount €180k exceeds €100k escalation threshold. Accenture current engagement flagged for scope creep (2 open disputes). Jira PROC-441 created for CPO review. Day rate €30k/week is above benchmark of €22k/week for similar engagements in our database.',
  now() - interval '1 day', now() + interval '3 days'
) on conflict (id) do nothing;

insert into decisions (
  id, ticket_id, disposition, confidence,
  recommendation, reasoning,
  created_at
) values (
  'ad000000-0000-0000-0000-000000000003',
  'a9000000-0000-0000-0000-000000000003',
  'escalate', 0.9100,
  'Escalate to CPO — amount exceeds threshold, rate above benchmark, scope creep risk',
  'Three escalation triggers: (1) €180k exceeds €100k hard threshold — auto-escalate. (2) Accenture has 2 open scope-creep disputes on existing engagement — elevated vendor risk. (3) Day rate €30k/week vs €22k/week benchmark = 36% premium. CPO should negotiate or seek competing SOW.', now() - interval '1 day'
) on conflict (id) do nothing;

insert into trace_log (id, decision_id, signal, value, weight, green, notes, created_at) values
  ('a1000000-0000-0000-0000-000000000011', 'ad000000-0000-0000-0000-000000000003',
   'policy', '{"available": 500000, "committed_pct": 79}', 0.7500, true,
   'HQ services bucket available €500k — budget not the issue. But committed 79% at Q2 midpoint.', now() - interval '1 day'),
  ('a1000000-0000-0000-0000-000000000012', 'ad000000-0000-0000-0000-000000000003',
   'supplier', '{"health": "watch", "open_disputes": 2, "scope_creep_flag": true}', 0.3500, false,
   'Accenture health: watch. 2 open disputes — scope creep on current SOW. High re-engagement risk.', now() - interval '1 day'),
  ('a1000000-0000-0000-0000-000000000013', 'ad000000-0000-0000-0000-000000000003',
   'policy', '{"gdpr": true, "nda": "signed", "lksg_declared": true}', 0.9000, true,
   'Compliance clean — DPA signed, NDA in place, LkSG declaration on file.', now() - interval '1 day'),
  ('a1000000-0000-0000-0000-000000000014', 'ad000000-0000-0000-0000-000000000003',
   'contract', '{"rate_vs_benchmark": 1.36, "scope_change_active": true}', 0.2000, false,
   'Day rate 36% above benchmark. Existing contract in scope_change state. Strong negotiation leverage.', now() - interval '1 day'),
  ('a1000000-0000-0000-0000-000000000015', 'ad000000-0000-0000-0000-000000000003',
   'request', '{"amount_exceeds_threshold": true, "threshold": 100000}', 0.1000, false,
   'Hard escalation rule: amount €180k > €100k threshold. Auto-escalate regardless of other signals.', now() - interval '1 day')
on conflict (id) do nothing;

-- Ticket 4: Signature required — NDA for new supplier
insert into tickets (
  id, reference, source, status, title, description,
  category, amount, amount_eur, currency,
  supplier_id, branch_id, owner_id,
  review_type, review_notes, pdf_url,
  created_at, target_close
) values (
  'a9000000-0000-0000-0000-000000000004',
  'TS-2026-0125', 'monitoring', 'signature_required',
  'NDA — DataBricks EMEA Ltd. — signature required',
  'Supplier onboarding compliance: mutual NDA generated. Requires CPO signature before DataBricks can receive tender documents.',
  'saas_license', null, null, 'EUR',
  null, 'b1000000-0000-0000-0000-000000000001',
  'e1000000-0000-0000-0000-000000000001',
  'signature',
  'Mutual NDA (German law, TrueSpend GmbH) generated by legal agent. DataBricks EMEA Ltd — Ireland entity. GDPR DPA and InfoSec review passed (score 81/100). LkSG clean. Ready for signature.',
  'https://docs.truespend.internal/nda/databricks-2026-05-nda.pdf',
  now() - interval '6 hours', now() + interval '2 days'
) on conflict (id) do nothing;

insert into decisions (
  id, ticket_id, disposition, confidence,
  recommendation, reasoning,
  created_at
) values (
  'ad000000-0000-0000-0000-000000000004',
  'a9000000-0000-0000-0000-000000000004',
  'one_touch', 0.9400,
  'NDA ready — all compliance checks passed — route for signature',
  'DataBricks EMEA onboarding: Lawyer agent generated mutual NDA (German law). GDPR DPA content validated — standard SCC clauses needed (non-EU processor). InfoSec score 81/100 — ISO 27001 certified, SOC 2 Type II on file. LkSG/Ethics clean — no sanctions hits, COC accepted. All 4 parallel compliance agents passed. Routing for CPO signature.',
  now() - interval '6 hours'
) on conflict (id) do nothing;

insert into trace_log (id, decision_id, signal, value, weight, green, notes, created_at) values
  ('a1000000-0000-0000-0000-000000000016', 'ad000000-0000-0000-0000-000000000004',
   'policy', '{"infosec_score": 81, "gdpr_dpa": "scc_required", "lksg": "clean", "nda_generated": true}', 0.9400, true,
   'All 4 compliance agents passed. NDA generated, DPA validated, InfoSec 81/100, LkSG clean.', now() - interval '6 hours'),
  ('a1000000-0000-0000-0000-000000000017', 'ad000000-0000-0000-0000-000000000004',
   'supplier', '{"new_supplier": true, "country": "Ireland", "iso27001": true, "soc2": true}', 0.8500, true,
   'New supplier — Ireland entity. ISO 27001 certified, SOC 2 Type II provided.', now() - interval '6 hours')
on conflict (id) do nothing;

-- Ticket 5: Pending review — contract renewal with price increase
insert into tickets (
  id, reference, source, status, title, description,
  category, amount, amount_eur, currency,
  supplier_id, branch_id, owner_id,
  review_type, review_notes,
  created_at, target_close
) values (
  'a9000000-0000-0000-0000-000000000005',
  'TS-2026-0130', 'renewal', 'pending_review',
  'Apple Device Program UK — renewal decision — 9% price increase',
  'Contract expires 2026-05-28 (TOMORROW). Apple proposing 9% increase on £4.2M contract. Notice period: 30 days — deadline already passed.',
  'hardware', 4578000.00, 5541180.00, 'GBP',
  'f1000000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000003',
  'e1000000-0000-0000-0000-000000000001',
  'major_contract',
  'URGENT: Contract expires tomorrow. 30-day notice already passed — auto-renewal not possible without penalty clause. Apple proposing 9% increase (£378k/year). Dell offers competitive hardware at similar spec for 12% less. Recommend: accept increase with 3-year lock-in for volume discount OR switch to Dell for next cycle. CPO decision required today.',
  now() - interval '3 hours', now() + interval '4 hours'
) on conflict (id) do nothing;

insert into decisions (
  id, ticket_id, disposition, confidence,
  recommendation, reasoning,
  created_at
) values (
  'ad000000-0000-0000-0000-000000000005',
  'a9000000-0000-0000-0000-000000000005',
  'one_touch', 0.7100,
  'Urgent review required — contract expires tomorrow, price increase above inflation',
  '5 signals evaluated. Critical time pressure: notice period expired, contract expires 2026-05-28. Price increase 9% vs CPI 3.1% = 5.9% real increase on a £4.2M base = £247k annual excess cost. Competitor benchmark: Dell equivalent spec at 12% below Apple price. Three options surfaced for human decision: (1) Accept 9% for 1 year while dual-sourcing Dell, (2) Accept with 3-year lock for volume discount negotiation, (3) Reject and trigger emergency Dell PO (4-week delivery risk). Confidence 71% — cannot auto-execute contract decisions of this magnitude and urgency.', now() - interval '3 hours'
) on conflict (id) do nothing;

insert into trace_log (id, decision_id, signal, value, weight, green, notes, created_at) values
  ('a1000000-0000-0000-0000-000000000018', 'ad000000-0000-0000-0000-000000000005',
   'contract', '{"days_to_expiry": 1, "notice_expired": true, "increase_pct": 9, "cpi": 3.1}', 0.1500, false,
   'Contract expires tomorrow. 30-day notice passed. 9% increase vs 3.1% CPI = 5.9% real increase.', now() - interval '3 hours'),
  ('a1000000-0000-0000-0000-000000000019', 'ad000000-0000-0000-0000-000000000005',
   'supplier', '{"health": "watch", "backlog_flag": true, "disputes": 1}', 0.5000, false,
   'Apple health: watch. MacBook Pro backlog flagged. 1 open dispute. Supply chain risk.', now() - interval '3 hours'),
  ('a1000000-0000-0000-0000-000000000020', 'ad000000-0000-0000-0000-000000000005',
   'policy', '{"available": 1600000, "eur_equiv": 5541180, "budget_ok": false}', 0.4000, false,
   'UK hardware budget available £1.6M. Contract value £4.2M → €5.5M — exceeds Q2 bucket alone (multi-year).', now() - interval '3 hours'),
  ('a1000000-0000-0000-0000-000000000021', 'ad000000-0000-0000-0000-000000000005',
   'policy', '{"gdpr": true, "nda": "signed", "data_residency": "EU"}', 0.9500, true,
   'Apple compliance clean — DPA signed, EU data residency confirmed.', now() - interval '3 hours'),
  ('a1000000-0000-0000-0000-000000000022', 'ad000000-0000-0000-0000-000000000005',
   'request', '{"amount_eur": 5541180, "exceeds_threshold": true, "competitor_available": true}', 0.3000, false,
   'Amount €5.5M well above €100k threshold. Competitor Dell offers equivalent at 12% lower. Strong negotiation position.', now() - interval '3 hours')
on conflict (id) do nothing;

-- Ticket 6: Auto-executed — license seat provisioning (catalog flow)
insert into tickets (
  id, reference, source, status, title, description,
  category, amount, amount_eur, currency,
  supplier_id, branch_id, owner_id,
  created_at, target_close
) values (
  'a9000000-0000-0000-0000-000000000006',
  'TS-2026-0133', 'intake', 'approved',
  'Microsoft 365 E3 seat — Jonas Weber (DACH)',
  'New hire Jonas Weber joining DACH Engineering 2026-06-01. Needs M365 E3 seat.',
  'saas_license', 1500.00, 1500.00, 'EUR',
  'f1000000-0000-0000-0000-000000000007', 'b1000000-0000-0000-0000-000000000002',
  'e1000000-0000-0000-0000-000000000005',
  now() - interval '4 hours', now() - interval '3 hours 45 minutes'
) on conflict (id) do nothing;

insert into decisions (
  id, ticket_id, disposition, confidence,
  recommendation, reasoning,
  created_at
) values (
  'ad000000-0000-0000-0000-000000000006',
  'a9000000-0000-0000-0000-000000000006',
  'auto_execute', 0.9910,
  'Provision M365 E3 seat immediately — 20 shelfware seats available',
  'Catalog item. M365 E3 entitlement (le000000-0000-0000-0000-000000000001) has 140 shelfware seats — no new purchase needed. DACH saas_license budget available. IT Manager Thomas Müller spend authority covers €1.5k. Provisioning from existing pool — no PO required. Seat assigned instantly.', now() - interval '4 hours'
) on conflict (id) do nothing;

insert into trace_log (id, decision_id, signal, value, weight, green, notes, created_at) values
  ('a1000000-0000-0000-0000-000000000023', 'ad000000-0000-0000-0000-000000000006',
   'consumption', '{"shelfware_seats": 140, "pool_sufficient": true, "no_purchase_needed": true}', 1.0000, true,
   'M365 E3 has 140 shelfware seats in DACH entitlement. Provision from existing pool — zero cost.', now() - interval '4 hours'),
  ('a1000000-0000-0000-0000-000000000024', 'ad000000-0000-0000-0000-000000000006',
   'policy', '{"available": 350000, "cost": 1500, "pct_impact": 0.1}', 1.0000, true,
   'Budget headroom excellent. €1.5k is 0.1% of available €350k DACH saas budget.', now() - interval '4 hours'),
  ('a1000000-0000-0000-0000-000000000025', 'ad000000-0000-0000-0000-000000000006',
   'request', '{"new_hire_confirmed": true, "start_date": "2026-06-01", "manager_approved": true}', 1.0000, true,
   'New hire confirmed in HR system. Start date 2026-06-01. Line manager pre-approved.', now() - interval '4 hours')
on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. COMPLIANCE CHECKS (feeds Supplier dashboard)
--    Live schema: id, supplier_id, check_type, status, score (int), notes
-- ─────────────────────────────────────────────────────────────────────────────
insert into compliance_checks (
  id, supplier_id, check_type, status, score, notes
) values
  ('a4000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001',
   'infosec', 'compliant', 88,
   'SOC 2 Type II current. ISO 27001 certified. Pen test Q1 2026. Annual review of sub-processors recommended.'),
  ('a4000000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000001',
   'gdpr', 'compliant', 92,
   'DPA signed. EU data residency confirmed.'),
  ('a4000000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000004',
   'infosec', 'compliant', 94,
   'ISO 27001. SOC 2 Type II. FedRAMP High. Enable AWS Macie for data classification.'),
  ('a4000000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000004',
   'gdpr', 'compliant', 96,
   'SCCs in place. DPA signed. EU processing via EMEA SARL.'),
  ('a4000000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000013',
   'infosec', 'review_required', 70,
   'BLOCKER: Subcontractor disclosure incomplete for Phase 3. Pen test expired 2024-Q4. Request updated pen test and full sub-processor list.'),
  ('a4000000-0000-0000-0000-000000000006', 'f1000000-0000-0000-0000-000000000013',
   'gdpr', 'compliant', 85,
   'DPA signed. SCCs in place. Update DPA annex with new sub-processors.'),
  ('a4000000-0000-0000-0000-000000000007', 'f1000000-0000-0000-0000-000000000017',
   'infosec', 'review_required', 72,
   'BLOCKER: SLA breach Feb 2026 — penalty clause not invoked. Incident report not filed. Issue formal SLA breach letter, update incident response contacts.')
on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. LLM API KEYS + CONSUMPTION
--    Live schema: key_ref (not key_alias), owner_user_id (uuid, not owner_email),
--                 monthly_budget_eur (not monthly_limit_usd), no status column
-- ─────────────────────────────────────────────────────────────────────────────
insert into llm_api_keys (
  id, provider, key_ref, owner_user_id, team_name,
  branch_id, cost_center_id, monthly_budget_eur
) values
  ('a5000000-0000-0000-0000-000000000001',
   'anthropic', 'sk-ant-...hq', 'e1000000-0000-0000-0000-000000000006', 'IT Platform',
   'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001',
   4650.00),
  ('a5000000-0000-0000-0000-000000000002',
   'anthropic', 'sk-ant-...dach', 'e1000000-0000-0000-0000-000000000003', 'DACH Engineering',
   'b1000000-0000-0000-0000-000000000002', 'cc000000-0000-0000-0000-000000000003',
   1860.00),
  ('a5000000-0000-0000-0000-000000000003',
   'openai', 'sk-...fr-sales', 'e1000000-0000-0000-0000-000000000002', 'France Sales AI',
   'b1000000-0000-0000-0000-000000000005', 'cc000000-0000-0000-0000-000000000007',
   1395.00)
on conflict (id) do nothing;

insert into llm_consumption (
  id, api_key_id, provider, model, period,
  branch_id, cost_center_id,
  input_tokens, output_tokens, cost_usd, cost_eur
) values
  -- HQ platform — May 2026
  ('a6000000-0000-0000-0000-000000000001',
   'a5000000-0000-0000-0000-000000000001', 'anthropic', 'claude-sonnet-4-6', '2026-05',
   'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001',
   18400000, 4200000, 3840.00, 3571.20),
  -- DACH engineering — May 2026
  ('a6000000-0000-0000-0000-000000000002',
   'a5000000-0000-0000-0000-000000000002', 'anthropic', 'claude-sonnet-4-6', '2026-05',
   'b1000000-0000-0000-0000-000000000002', 'cc000000-0000-0000-0000-000000000003',
   7200000, 1800000, 1540.00, 1432.20),
  -- France sales AI — May 2026
  ('a6000000-0000-0000-0000-000000000003',
   'a5000000-0000-0000-0000-000000000003', 'openai', 'gpt-4o', '2026-05',
   'b1000000-0000-0000-0000-000000000005', 'cc000000-0000-0000-0000-000000000007',
   4100000, 980000, 1280.00, 1190.40),
  -- HQ platform — April 2026 (for trend data)
  ('a6000000-0000-0000-0000-000000000004',
   'a5000000-0000-0000-0000-000000000001', 'anthropic', 'claude-sonnet-4-6', '2026-04',
   'b1000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-000000000001',
   12100000, 2800000, 2520.00, 2343.60)
on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. WORKFLOW RUNS (feeds Grafana health dashboard if configured)
--    Live schema: id, workflow_name, status, started_at, ended_at, error_message
-- ─────────────────────────────────────────────────────────────────────────────
insert into workflow_runs (
  id, workflow_name, status, started_at, ended_at
) values
  ('a7000000-0000-0000-0000-000000000001',
   'intake_receiver', 'success',
   now() - interval '5 days', now() - interval '5 days' + interval '12 seconds'),
  ('a7000000-0000-0000-0000-000000000002',
   'intake_receiver', 'success',
   now() - interval '2 days', now() - interval '2 days' + interval '18 seconds'),
  ('a7000000-0000-0000-0000-000000000003',
   'intake_receiver', 'success',
   now() - interval '1 day', now() - interval '1 day' + interval '9 seconds'),
  ('a7000000-0000-0000-0000-000000000004',
   'supplier_onboarding', 'success',
   now() - interval '6 hours', now() - interval '6 hours' + interval '34 seconds'),
  ('a7000000-0000-0000-0000-000000000005',
   'contract_watcher', 'success',
   now() - interval '22 hours', now() - interval '22 hours' + interval '7 seconds'),
  ('a7000000-0000-0000-0000-000000000006',
   'intake_receiver', 'success',
   now() - interval '4 hours', now() - interval '4 hours' + interval '11 seconds'),
  ('a7000000-0000-0000-0000-000000000007',
   'contract_watcher', 'success',
   now() - interval '46 hours', now() - interval '46 hours' + interval '8 seconds')
on conflict (id) do nothing;
