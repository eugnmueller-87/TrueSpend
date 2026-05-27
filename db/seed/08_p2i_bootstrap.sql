-- TrueSpend Simulation Seed — P2I Bootstrap
-- Seed 08: budget_buckets (annual plan) + po_sequences (PO numbering) + trust_settings
-- Run after seeds 01–07.

-- =============================================================================
-- BUDGET BUCKETS — the annual plan owned by Controlling
-- One row per: branch × category × fiscal_year × quarter
-- budget_positions (seed 06) is the running ledger.
-- budget_buckets is the plan. Controlling sets it once.
-- =============================================================================

insert into budget_buckets (branch_id, cost_center_id, category, fiscal_year, quarter, planned_amount, currency, notes)
values

  -- ── Global HQ ──────────────────────────────────────────────────────────────
  ('b1000000-0000-0000-0000-000000000001', null, 'hardware',       2026, 2,  8000000, 'EUR', 'HQ hardware Q2'),
  ('b1000000-0000-0000-0000-000000000001', null, 'hyperscaler',    2026, 2,  4000000, 'EUR', 'HQ cloud Q2'),
  ('b1000000-0000-0000-0000-000000000001', null, 'saas_license',   2026, 2,  3200000, 'EUR', 'HQ SaaS Q2'),
  ('b1000000-0000-0000-0000-000000000001', null, 'services',       2026, 2,  2400000, 'EUR', 'HQ services Q2'),
  ('b1000000-0000-0000-0000-000000000001', null, 'ai_consumption', 2026, 2,   420000, 'EUR', 'HQ AI spend Q2'),

  -- ── DACH ────────────────────────────────────────────────────────────────────
  ('b1000000-0000-0000-0000-000000000002', null, 'hardware',       2026, 2,  5000000, 'EUR', 'DACH hardware Q2'),
  ('b1000000-0000-0000-0000-000000000002', null, 'hyperscaler',    2026, 2,  1800000, 'EUR', 'DACH cloud Q2'),
  ('b1000000-0000-0000-0000-000000000002', null, 'saas_license',   2026, 2,  1400000, 'EUR', 'DACH SaaS Q2'),
  ('b1000000-0000-0000-0000-000000000002', null, 'facilities',     2026, 2,   480000, 'EUR', 'DACH facilities Q2'),
  ('b1000000-0000-0000-0000-000000000002', null, 'ai_consumption', 2026, 2,   180000, 'EUR', 'DACH AI spend Q2'),

  -- ── UK & Ireland ────────────────────────────────────────────────────────────
  ('b1000000-0000-0000-0000-000000000003', null, 'hardware',       2026, 2,  2200000, 'EUR', 'UKI hardware Q2'),
  ('b1000000-0000-0000-0000-000000000003', null, 'hyperscaler',    2026, 2,  1100000, 'EUR', 'UKI cloud Q2'),
  ('b1000000-0000-0000-0000-000000000003', null, 'saas_license',   2026, 2,   900000, 'EUR', 'UKI SaaS Q2'),
  ('b1000000-0000-0000-0000-000000000003', null, 'ai_consumption', 2026, 2,    95000, 'EUR', 'UKI AI spend Q2'),

  -- ── Benelux ─────────────────────────────────────────────────────────────────
  ('b1000000-0000-0000-0000-000000000004', null, 'hardware',       2026, 2,  1800000, 'EUR', 'BNL hardware Q2'),
  ('b1000000-0000-0000-0000-000000000004', null, 'saas_license',   2026, 2,   700000, 'EUR', 'BNL SaaS Q2'),
  ('b1000000-0000-0000-0000-000000000004', null, 'ai_consumption', 2026, 2,    55000, 'EUR', 'BNL AI spend Q2'),

  -- ── France ──────────────────────────────────────────────────────────────────
  ('b1000000-0000-0000-0000-000000000005', null, 'hardware',       2026, 2,  1600000, 'EUR', 'FR hardware Q2'),
  ('b1000000-0000-0000-0000-000000000005', null, 'saas_license',   2026, 2,   900000, 'EUR', 'FR SaaS Q2'),
  ('b1000000-0000-0000-0000-000000000005', null, 'ai_consumption', 2026, 2,    62000, 'EUR', 'FR AI spend Q2 — NOTE: already over-committed in positions, see seed 06'),

  -- ── Nordics ─────────────────────────────────────────────────────────────────
  ('b1000000-0000-0000-0000-000000000006', null, 'hardware',       2026, 2,  1200000, 'EUR', 'Nordics hardware Q2'),
  ('b1000000-0000-0000-0000-000000000006', null, 'saas_license',   2026, 2,   600000, 'EUR', 'Nordics SaaS Q2'),
  ('b1000000-0000-0000-0000-000000000006', null, 'telecoms',       2026, 2,   280000, 'EUR', 'Nordics telecoms Q2'),

  -- ── Iberia ──────────────────────────────────────────────────────────────────
  ('b1000000-0000-0000-0000-000000000007', null, 'hardware',       2026, 2,   900000, 'EUR', 'Iberia hardware Q2'),
  ('b1000000-0000-0000-0000-000000000007', null, 'saas_license',   2026, 2,   440000, 'EUR', 'Iberia SaaS Q2'),

  -- ── Italy ───────────────────────────────────────────────────────────────────
  ('b1000000-0000-0000-0000-000000000008', null, 'hardware',       2026, 2,  1100000, 'EUR', 'Italy hardware Q2'),
  ('b1000000-0000-0000-0000-000000000008', null, 'telecoms',       2026, 2,   290000, 'EUR', 'Italy telecoms Q2'),

  -- ── CEE ─────────────────────────────────────────────────────────────────────
  ('b1000000-0000-0000-0000-000000000009', null, 'hardware',       2026, 2,   800000, 'EUR', 'CEE hardware Q2'),
  ('b1000000-0000-0000-0000-000000000009', null, 'telecoms',       2026, 2,   720000, 'EUR', 'CEE telecoms Q2'),

  -- ── Nordics East ────────────────────────────────────────────────────────────
  ('b1000000-0000-0000-0000-000000000010', null, 'hardware',       2026, 2,   600000, 'EUR', 'NE hardware Q2'),
  ('b1000000-0000-0000-0000-000000000010', null, 'saas_license',   2026, 2,   280000, 'EUR', 'NE SaaS Q2');


-- =============================================================================
-- PO SEQUENCES — starting counters per branch for 2026
-- =============================================================================

insert into po_sequences (branch_id, fiscal_year, last_seq) values
  ('b1000000-0000-0000-0000-000000000001', 2026, 0),   -- Global HQ   → PO-2026-HQ-0001
  ('b1000000-0000-0000-0000-000000000002', 2026, 0),   -- DACH        → PO-2026-DACH-0001
  ('b1000000-0000-0000-0000-000000000003', 2026, 0),   -- UK & Ireland → PO-2026-UKI-0001
  ('b1000000-0000-0000-0000-000000000004', 2026, 0),   -- Benelux     → PO-2026-BNL-0001
  ('b1000000-0000-0000-0000-000000000005', 2026, 0),   -- France      → PO-2026-FR-0001
  ('b1000000-0000-0000-0000-000000000006', 2026, 0),   -- Nordics     → PO-2026-NOR-0001
  ('b1000000-0000-0000-0000-000000000007', 2026, 0),   -- Iberia      → PO-2026-IB-0001
  ('b1000000-0000-0000-0000-000000000008', 2026, 0),   -- Italy       → PO-2026-IT-0001
  ('b1000000-0000-0000-0000-000000000009', 2026, 0),   -- CEE         → PO-2026-CEE-0001
  ('b1000000-0000-0000-0000-000000000010', 2026, 0);   -- Nordics East → PO-2026-NE-0001


-- =============================================================================
-- TRUST SETTINGS — org-wide defaults for agent autonomy
-- Week 1–4: sub-€10k auto, sub-€100k one-touch, ≥€100k always escalate
-- =============================================================================

insert into trust_settings (branch_id, category, auto_execute_threshold_eur, one_touch_threshold_eur, min_confidence_auto, notes)
values
  -- Org-wide default
  (null, null, 10000.00, 100000.00, 0.9500, 'Default. Review after first 30 days, expand based on accuracy.'),

  -- Hardware: slightly higher threshold — physical delivery adds risk
  (null, 'hardware',       15000.00, 100000.00, 0.9500, 'Hardware default. Physical delivery SLA adds uncertainty.'),

  -- SaaS licenses: lower threshold — fast, clean, reversible
  (null, 'saas_license',    5000.00, 100000.00, 0.9200, 'SaaS default. Most license requests are low-risk same-day provisioning.'),

  -- AI consumption: aggressive auto-execute — all signals easy to check
  (null, 'ai_consumption',  2500.00,  50000.00, 0.9000, 'AI spend default. Key register + budget bucket check is deterministic.'),

  -- Hyperscaler: higher bar — commitment amendments have financial consequences
  (null, 'hyperscaler',    10000.00, 100000.00, 0.9700, 'Cloud default. Commitment changes require high confidence.');
