-- ============================================================
-- TrueSpend Executive Demo Seed  (10_executive_demo.sql)
-- Covers every procurement use case for live demo / testing
-- Run once against production Railway DB
-- ============================================================

-- ── 0. Budget buckets — give every branch real allocations ───
UPDATE budget_buckets SET
  allocated_eur = CASE category
    WHEN 'hardware'      THEN 480000
    WHEN 'saas_license'  THEN 320000
    WHEN 'hyperscaler'   THEN 260000
    WHEN 'services'      THEN 180000
    WHEN 'ai_consumption'THEN  60000
    WHEN 'telecoms'      THEN  40000
    WHEN 'facilities'    THEN  30000
    ELSE 20000
  END,
  committed_eur = CASE category
    WHEN 'hardware'      THEN 310000
    WHEN 'saas_license'  THEN 240000
    WHEN 'hyperscaler'   THEN 195000
    WHEN 'services'      THEN  92000
    WHEN 'ai_consumption'THEN  38000
    WHEN 'telecoms'      THEN  28000
    WHEN 'facilities'    THEN  18000
    ELSE 9000
  END,
  spent_eur = CASE category
    WHEN 'hardware'      THEN 205000
    WHEN 'saas_license'  THEN 148000
    WHEN 'hyperscaler'   THEN 142000
    WHEN 'services'      THEN  54000
    WHEN 'ai_consumption'THEN  21000
    WHEN 'telecoms'      THEN  19000
    WHEN 'facilities'    THEN  11000
    ELSE 4000
  END
WHERE fiscal_year = 2026 AND quarter = 2;

-- DACH hardware bucket intentionally near limit (demo: overrun scenario)
UPDATE budget_buckets
SET allocated_eur = 380000, committed_eur = 362000, spent_eur = 298000
WHERE branch_id = 'b1000000-0000-0000-0000-000000000002'
  AND category = 'hardware' AND quarter = 2;

-- France SaaS bucket intentionally over-committed (demo: rejection scenario)
UPDATE budget_buckets
SET allocated_eur = 95000, committed_eur = 97400, spent_eur = 61000
WHERE branch_id = 'b1000000-0000-0000-0000-000000000005'
  AND category = 'saas_license' AND quarter = 2;


-- ── 1. License entitlements — realistic seat counts ──────────
-- Clear existing and rebuild
DELETE FROM license_assignments;
DELETE FROM license_entitlements;

INSERT INTO license_entitlements (id, product_name, supplier_id, branch_id, contract_id,
  total_seats, assigned_seats, active_seats, shelfware_seats, shelfware_pct,
  available_seats, utilization_pct, avg_feature_usage_depth,
  price_per_seat, price_currency, total_cost_eur,
  license_type, term_start, term_end, true_up_date, true_up_frequency, active)
VALUES
  -- Microsoft 365 E3 — DACH (healthy utilisation)
  ('le000001-0000-0000-0000-000000000001',
   'Microsoft 365 E3', 'f1000000-0000-0000-0000-000000000007',
   'b1000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000002',
   320, 298, 281, 22, 6.9, 22, 87.8, 72,
   36.00, 'EUR', 138240, 'subscription',
   '2025-08-01', '2026-07-31', '2026-07-31', 'annual', true),

  -- Microsoft 365 E5 — UK (high shelfware — demo: waste detection)
  ('le000001-0000-0000-0000-000000000002',
   'Microsoft 365 E5', 'f1000000-0000-0000-0000-000000000007',
   'b1000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000012',
   500, 487, 341, 146, 29.2, 13, 68.2, 38,
   57.00, 'EUR', 342000, 'subscription',
   '2025-07-15', '2026-07-14', '2026-07-14', 'annual', true),

  -- Salesforce Sales Cloud — France (true-up risk)
  ('le000001-0000-0000-0000-000000000003',
   'Salesforce Sales Cloud', 'f1000000-0000-0000-0000-000000000008',
   'b1000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000007',
   85, 91, 88, 3, 3.5, 0, 103.5, 81,
   165.00, 'EUR', 180180, 'subscription',
   '2025-06-30', '2026-06-29', '2026-06-29', 'annual', true),

  -- Slack Business+ — Nordics (clean)
  ('le000001-0000-0000-0000-000000000004',
   'Slack Business+', 'f1000000-0000-0000-0000-000000000008',
   'b1000000-0000-0000-0000-000000000006', 'c1000000-0000-0000-0000-000000000004',
   140, 128, 122, 18, 12.9, 12, 87.1, 68,
   15.00, 'EUR', 25200, 'subscription',
   '2025-08-01', '2026-07-31', '2026-07-31', 'annual', true),

  -- GitHub Enterprise — Global HQ
  ('le000001-0000-0000-0000-000000000005',
   'GitHub Enterprise', 'f1000000-0000-0000-0000-000000000007',
   'b1000000-0000-0000-0000-000000000001', null,
   200, 167, 154, 46, 23.0, 33, 77.0, 55,
   21.00, 'EUR', 50400, 'subscription',
   '2025-09-01', '2026-08-31', '2026-08-31', 'annual', true),

  -- Workday HCM — Global (available seats for self-service demo)
  ('le000001-0000-0000-0000-000000000006',
   'Workday HCM', 'f1000000-0000-0000-0000-000000000010',
   'b1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000013',
   150, 141, 138, 12, 8.0, 9, 92.0, 78,
   45.00, 'EUR', 81000, 'subscription',
   '2025-01-01', '2026-12-31', '2026-12-31', 'annual', true),

  -- Zoom Business — Benelux (low usage, renewal coming up)
  ('le000001-0000-0000-0000-000000000007',
   'Zoom Business', null,
   'b1000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000010',
   60, 44, 38, 22, 36.7, 16, 63.3, 41,
   14.90, 'EUR', 10728, 'subscription',
   '2025-07-04', '2026-07-03', '2026-07-03', 'annual', true),

  -- Azure DevOps — Global (healthy)
  ('le000001-0000-0000-0000-000000000008',
   'Azure DevOps', 'f1000000-0000-0000-0000-000000000006',
   'b1000000-0000-0000-0000-000000000001', null,
   80, 74, 71, 9, 11.25, 6, 88.75, 65,
   6.00, 'EUR', 5760, 'subscription',
   '2025-10-01', '2026-09-30', '2026-09-30', 'annual', true);


-- ── 2. License assignments — realistic user assignments ───────
INSERT INTO license_assignments
  (id, entitlement_id, assigned_to_user, assigned_at, active, usage_depth_pct, last_active_at)
VALUES
  -- M365 E3 DACH — 5 sample users
  ('la000001-0000-0000-0000-000000000001','le000001-0000-0000-0000-000000000001','Lena Hoffmann',      now()-interval'180 days', true,  88, now()-interval'1 day'),
  ('la000001-0000-0000-0000-000000000002','le000001-0000-0000-0000-000000000001','Jonas Weber',        now()-interval'175 days', true,  72, now()-interval'2 days'),
  ('la000001-0000-0000-0000-000000000003','le000001-0000-0000-0000-000000000001','Anna Schulz',        now()-interval'170 days', true,  91, now()-interval'4 hours'),
  ('la000001-0000-0000-0000-000000000004','le000001-0000-0000-0000-000000000001','Klaus Bauer',        now()-interval'165 days', true,  34, now()-interval'12 days'),
  ('la000001-0000-0000-0000-000000000005','le000001-0000-0000-0000-000000000001','Petra Fischer',      now()-interval'90 days',  false,  0, now()-interval'95 days'),

  -- M365 E5 UK — shelfware users (never logged in / low activity)
  ('la000001-0000-0000-0000-000000000010','le000001-0000-0000-0000-000000000002','James Harrison',     now()-interval'200 days', true,  91, now()-interval'1 day'),
  ('la000001-0000-0000-0000-000000000011','le000001-0000-0000-0000-000000000002','Sophie Williams',    now()-interval'198 days', true,  82, now()-interval'3 days'),
  ('la000001-0000-0000-0000-000000000012','le000001-0000-0000-0000-000000000002','Tom Clarke',         now()-interval'196 days', false,  8, now()-interval'87 days'),
  ('la000001-0000-0000-0000-000000000013','le000001-0000-0000-0000-000000000002','Rachel Green',       now()-interval'194 days', false,  3, now()-interval'102 days'),
  ('la000001-0000-0000-0000-000000000014','le000001-0000-0000-0000-000000000002','David Okafor',       now()-interval'192 days', false,  0, now()-interval'148 days'),

  -- Salesforce France — overage users
  ('la000001-0000-0000-0000-000000000020','le000001-0000-0000-0000-000000000003','Marie Leclerc',      now()-interval'300 days', true,  94, now()-interval'2 hours'),
  ('la000001-0000-0000-0000-000000000021','le000001-0000-0000-0000-000000000003','Pierre Dubois',      now()-interval'295 days', true,  88, now()-interval'6 hours'),
  ('la000001-0000-0000-0000-000000000022','le000001-0000-0000-0000-000000000003','Claire Moreau',      now()-interval'290 days', true,  76, now()-interval'1 day'),

  -- GitHub Enterprise — shelfware
  ('la000001-0000-0000-0000-000000000030','le000001-0000-0000-0000-000000000005','Alex Chen',          now()-interval'365 days', true,  95, now()-interval'1 hour'),
  ('la000001-0000-0000-0000-000000000031','le000001-0000-0000-0000-000000000005','Nina Patel',         now()-interval'360 days', true,  88, now()-interval'3 hours'),
  ('la000001-0000-0000-0000-000000000032','le000001-0000-0000-0000-000000000005','Sam Torres',         now()-interval'355 days', false,  2, now()-interval'180 days'),
  ('la000001-0000-0000-0000-000000000033','le000001-0000-0000-0000-000000000005','Jamie Liu',          now()-interval'350 days', false,  0, now()-interval'210 days');


-- ── 3. Assets — hardware register ────────────────────────────
INSERT INTO assets (id, name, branch_id, po_id, purchase_value, book_value, warranty_expiry, status, created_at)
VALUES
  -- Healthy fleet
  ('as000001-0000-0000-0000-000000000001', 'MacBook Pro M3 #UK-001', 'b1000000-0000-0000-0000-000000000003', 'a8000000-0000-0000-0000-000000000003', 2199, 1832, '2027-06-01', 'active', now()-interval'180 days'),
  ('as000001-0000-0000-0000-000000000002', 'MacBook Pro M3 #UK-002', 'b1000000-0000-0000-0000-000000000003', 'a8000000-0000-0000-0000-000000000003', 2199, 1832, '2027-06-01', 'active', now()-interval'180 days'),
  ('as000001-0000-0000-0000-000000000003', 'MacBook Pro M3 #UK-003', 'b1000000-0000-0000-0000-000000000003', 'a8000000-0000-0000-0000-000000000003', 2199, 1832, '2027-06-01', 'active', now()-interval'180 days'),
  ('as000001-0000-0000-0000-000000000004', 'ThinkPad T14s #DACH-001', 'b1000000-0000-0000-0000-000000000002', 'a8000000-0000-0000-0000-000000000002', 1199, 999,  '2028-03-01', 'active', now()-interval'120 days'),
  ('as000001-0000-0000-0000-000000000005', 'ThinkPad T14s #DACH-002', 'b1000000-0000-0000-0000-000000000002', 'a8000000-0000-0000-0000-000000000002', 1199, 999,  '2028-03-01', 'active', now()-interval'120 days'),
  -- Warranty expiring soon (demo: 30-day alert)
  ('as000001-0000-0000-0000-000000000006', 'Dell UltraSharp 27" #HQ-014', 'b1000000-0000-0000-0000-000000000001', null, 549, 91, '2026-06-21', 'active', now()-interval'1095 days'),
  ('as000001-0000-0000-0000-000000000007', 'Dell UltraSharp 27" #HQ-015', 'b1000000-0000-0000-0000-000000000001', null, 549, 91, '2026-06-24', 'active', now()-interval'1095 days'),
  -- Warranty already expired (demo: replace now)
  ('as000001-0000-0000-0000-000000000008', 'Dell PowerEdge R640 #DACH-DC-03', 'b1000000-0000-0000-0000-000000000002', null, 18500, 1850, '2026-04-15', 'active', now()-interval'1825 days'),
  ('as000001-0000-0000-0000-000000000009', 'HP ProLiant DL380 #HQ-DC-07',     'b1000000-0000-0000-0000-000000000001', null, 22000, 2200, '2026-03-01', 'active', now()-interval'1825 days'),
  -- Near end-of-life book value < 10% (demo: depreciation lifecycle)
  ('as000001-0000-0000-0000-000000000010', 'MacBook Pro 2022 #FR-007', 'b1000000-0000-0000-0000-000000000005', null, 2199, 198, '2025-12-01', 'active', now()-interval'1095 days'),
  -- Decommissioned
  ('as000001-0000-0000-0000-000000000011', 'Lenovo ThinkPad T14 2021 #BNL-002', 'b1000000-0000-0000-0000-000000000004', null, 1299, 0, '2024-11-01', 'decommissioned', now()-interval'1460 days');


-- ── 4. Asset depreciation log ─────────────────────────────────
INSERT INTO asset_depreciation_log (asset_id, period, depreciation, book_value_after, created_at)
VALUES
  ('as000001-0000-0000-0000-000000000001', '2026-04', 61.08, 2076.58, now()-interval'60 days'),
  ('as000001-0000-0000-0000-000000000001', '2026-05', 61.08, 2015.50, now()-interval'30 days'),
  ('as000001-0000-0000-0000-000000000006', '2026-04', 12.75,  103.75, now()-interval'60 days'),
  ('as000001-0000-0000-0000-000000000006', '2026-05', 12.75,   91.00, now()-interval'30 days'),
  ('as000001-0000-0000-0000-000000000008', '2026-04', 0,     1850.00, now()-interval'60 days'),
  ('as000001-0000-0000-0000-000000000010', '2026-04', 30.54,  228.54, now()-interval'60 days'),
  ('as000001-0000-0000-0000-000000000010', '2026-05', 30.54,  198.00, now()-interval'30 days');


-- ── 5. Invoices — full 3-way match lifecycle ─────────────────
INSERT INTO invoices (id, po_id, invoice_number, supplier_id, amount_eur, status,
  received_at, matched_at, match_result, currency, raw_amount, raw_currency,
  vat_amount, payment_terms_days, due_date, created_at)
VALUES
  -- Invoice matched cleanly against PO-FR-2026-0015 (Salesforce)
  ('iv000001-0000-0000-0000-000000000001',
   'a8000000-0000-0000-0000-000000000005',
   'SF-INV-2026-04892', 'f1000000-0000-0000-0000-000000000008',
   72000, 'approved',
   now()-interval'18 days', now()-interval'17 days',
   '{"result":"matched","po_amount":72000,"invoice_amount":72000,"delta_pct":0,"within_tolerance":true}',
   'EUR', 72000, 'EUR', 13680, 30, now()-interval'18 days'+interval'30 days',
   now()-interval'18 days'),

  -- Invoice with minor variance (within 2% tolerance) — auto-approved
  ('iv000001-0000-0000-0000-000000000002',
   'a8000000-0000-0000-0000-000000000004',
   'AWS-INV-2026-88412', 'f1000000-0000-0000-0000-000000000004',
   89820, 'approved',
   now()-interval'10 days', now()-interval'9 days',
   '{"result":"matched","po_amount":89000,"invoice_amount":89820,"delta_pct":0.92,"within_tolerance":true,"note":"FX variance on USD billing"}',
   'EUR', 97850, 'USD', 0, 30, now()-interval'10 days'+interval'30 days',
   now()-interval'10 days'),

  -- Invoice with 4.2% overage — flagged, pending review
  ('iv000001-0000-0000-0000-000000000003',
   'a8000000-0000-0000-0000-000000000003',
   'APL-INV-2026-20041', 'f1000000-0000-0000-0000-000000000003',
   131400, 'pending',
   now()-interval'3 days', null,
   '{"result":"mismatch","po_amount":126108,"invoice_amount":131400,"delta_pct":4.2,"within_tolerance":false,"note":"Invoice includes AppleCare+ charges not in PO"}',
   'EUR', 131400, 'EUR', 24966, 30, now()-interval'3 days'+interval'30 days',
   now()-interval'3 days'),

  -- Invoice for large Dell PO — awaiting delivery confirmation first
  ('iv000001-0000-0000-0000-000000000004',
   'a8000000-0000-0000-0000-000000000001',
   'DELL-INV-2026-77341', 'f1000000-0000-0000-0000-000000000001',
   284400, 'pending',
   now()-interval'1 day', null,
   '{"result":"pending_delivery","po_amount":284400,"note":"PO not yet marked delivered — 3-way match blocked"}',
   'EUR', 284400, 'EUR', 54036, 45, now()-interval'1 day'+interval'45 days',
   now()-interval'1 day');


-- ── 6. Payment instructions ───────────────────────────────────
INSERT INTO payment_instructions (id, invoice_id, amount_eur, due_date, status, created_at)
VALUES
  ('pi000001-0000-0000-0000-000000000001', 'iv000001-0000-0000-0000-000000000001', 72000,  now()+interval'12 days', 'pending', now()-interval'17 days'),
  ('pi000001-0000-0000-0000-000000000002', 'iv000001-0000-0000-0000-000000000002', 89820,  now()+interval'20 days', 'pending', now()-interval'9 days');


-- ── 7. ERP sync queue ─────────────────────────────────────────
INSERT INTO erp_sync_queue (entity_type, entity_id, payload, status, created_at)
VALUES
  ('payment_instruction', 'pi000001-0000-0000-0000-000000000001',
   '{"action":"post_payment","vendor_id":"SF-0892","amount":72000,"currency":"EUR","reference":"SF-INV-2026-04892","cost_center":"CC-FR-SALES"}',
   'pending', now()-interval'17 days'),
  ('payment_instruction', 'pi000001-0000-0000-0000-000000000002',
   '{"action":"post_payment","vendor_id":"AWS-0014","amount":89820,"currency":"EUR","reference":"AWS-INV-2026-88412","cost_center":"CC-HQ-INFRA"}',
   'pending', now()-interval'9 days'),
  ('purchase_order', 'a8000000-0000-0000-0000-000000000001',
   '{"action":"post_po","vendor_id":"DELL-0001","amount":284400,"currency":"EUR","po_number":"PO-HQ-2026-0041","cost_center":"CC-HQ-IT"}',
   'synced', now()-interval'14 days');


-- ── 8. Tickets — complete set of every status + scenario ──────

-- 8a. AUTO_EXECUTE: Figma seats × 6 — within budget, known product, catalogue item
INSERT INTO tickets (reference, source, status, title, description,
  branch_id, supplier_id, owner_id, submitted_by, submitted_by_email,
  value_eur, amount_eur, disposition, recommendation, confidence, created_at)
VALUES ('TS-2026-0201', 'intake', 'auto_executed',
  'Figma Organization × 6 seats — DACH Design',
  'Design team expanding. 6 additional Figma Organization seats needed for Q2 sprint ramp.',
  'b1000000-0000-0000-0000-000000000002', null,
  'e1000000-0000-0000-0000-000000000003',
  'Lena Hoffmann', 'lena.hoffmann@company.com',
  270, 270, 'auto_execute',
  'Auto-approved. Figma Organization at €45/seat/mo. Budget headroom 38%. No contract conflict. Catalogue price confirmed.',
  0.97, now()-interval'5 hours');

-- 8b. AUTO_EXECUTE: Dell dock reorder — catalog item, delivery due
INSERT INTO tickets (reference, source, status, title, description,
  branch_id, supplier_id, owner_id, submitted_by, submitted_by_email,
  value_eur, amount_eur, disposition, recommendation, confidence, created_at)
VALUES ('TS-2026-0202', 'automatic', 'auto_executed',
  'Dell Dock WD19S × 8 — Nordics reorder',
  'Automatic reorder triggered. Stock at 2 units, threshold 5. 8 units ordered.',
  'b1000000-0000-0000-0000-000000000006', 'f1000000-0000-0000-0000-000000000001',
  'e1000000-0000-0000-0000-000000000004',
  'Erik Lindqvist', 'erik.lindqvist@company.com',
  1592, 1592, 'auto_execute',
  'Reorder auto-approved. Dell Hardware Framework contract active. Unit price €199 confirmed. Budget available.',
  0.99, now()-interval'3 hours');

-- 8c. PENDING_REVIEW: New SaaS tool — no existing contract, unknown supplier
INSERT INTO tickets (reference, source, status, title, description,
  branch_id, supplier_id, owner_id, submitted_by, submitted_by_email,
  value_eur, amount_eur, disposition, recommendation, confidence, created_at)
VALUES ('TS-2026-0203', 'intake', 'pending_review',
  'Notion Team × 12 seats — UK Product',
  'Product team requesting Notion Team for documentation and roadmap management. No existing contract.',
  'b1000000-0000-0000-0000-000000000003', null,
  'e1000000-0000-0000-0000-000000000004',
  'Erik Lindqvist', 'erik.lindqvist@company.com',
  1584, 1584, 'one_touch',
  'One-touch recommended. No existing Notion contract. Capability overlap with Confluence (already licensed). Recommend review before committing.',
  0.71, now()-interval'2 hours');

-- 8d. PENDING_REVIEW: Licence top-up — France Salesforce already over quota
INSERT INTO tickets (reference, source, status, title, description,
  branch_id, supplier_id, owner_id, submitted_by, submitted_by_email,
  value_eur, amount_eur, disposition, recommendation, confidence, created_at)
VALUES ('TS-2026-0204', 'intake', 'pending_review',
  'Salesforce Sales Cloud — 5 additional seats France',
  'France sales team needs 5 more seats. Current entitlement already over-committed by 6 seats.',
  'b1000000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000008',
  'e1000000-0000-0000-0000-000000000002',
  'Marc Dupont', 'marc.dupont@company.com',
  9900, 9900, 'one_touch',
  'One-touch. France SaaS budget 102% committed. Salesforce entitlement already 6 seats over quota — true-up risk at renewal. Human review required before expansion.',
  0.68, now()-interval'90 minutes');

-- 8e. ESCALATED: Large professional services SOW
INSERT INTO tickets (reference, source, status, title, description,
  branch_id, supplier_id, owner_id, submitted_by, submitted_by_email,
  value_eur, amount_eur, jira_key, jira_url, disposition, recommendation, confidence, created_at)
VALUES ('TS-2026-0205', 'intake', 'escalated',
  'McKinsey — Digital Operations Assessment €220k',
  'CFO office requesting McKinsey engagement for digital operations assessment. 3-month SOW.',
  'b1000000-0000-0000-0000-000000000001', null,
  'e1000000-0000-0000-0000-000000000001',
  'Sarah Brennan', 'sarah.brennan@company.com',
  220000, 220000,
  'PROC-2205', 'https://truespend.atlassian.net/browse/PROC-2205',
  'escalate',
  'Escalated. Exceeds €100k threshold. New supplier — no contract, no compliance check. SOW scope requires legal review. Jira PROC-2205 created.',
  0.91, now()-interval'45 minutes');

-- 8f. SIGNATURE_REQUIRED: NDA with new data vendor
INSERT INTO tickets (reference, source, status, title, description,
  branch_id, supplier_id, owner_id, submitted_by, submitted_by_email,
  value_eur, amount_eur, disposition, recommendation, confidence, created_at)
VALUES ('TS-2026-0206', 'intake', 'signature_required',
  'NDA — Databricks EMEA Ltd — AI Data Platform evaluation',
  'Compliance assessment complete. Mutual NDA prepared. Requires CPO signature before data sharing begins.',
  'b1000000-0000-0000-0000-000000000001', null,
  'e1000000-0000-0000-0000-000000000001',
  'Sarah Brennan', 'sarah.brennan@company.com',
  0, 0, 'one_touch',
  'Agent prepared mutual NDA (German law, TrueSpend GmbH). GDPR DPA required — data residency EU confirmed. InfoSec score 82/100. Signature required to proceed.',
  0.88, now()-interval'30 minutes');

-- 8g. PENDING_CONFIRM: Standard catalogue order — quick confirm path
INSERT INTO tickets (reference, source, status, title, description,
  branch_id, supplier_id, owner_id, submitted_by, submitted_by_email,
  value_eur, amount_eur, disposition, recommendation, confidence, created_at)
VALUES ('TS-2026-0207', 'intake', 'pending_confirm',
  'Apple iPhone 15 Pro × 4 — Italy sales team',
  'Italy sales team requesting 4 × iPhone 15 Pro 256GB from Apple catalogue.',
  'b1000000-0000-0000-0000-000000000008', 'f1000000-0000-0000-0000-000000000003',
  'e1000000-0000-0000-0000-000000000005',
  'Priya Nair', 'priya.nair@company.com',
  4796, 4796, 'one_touch',
  'Catalogue item confirmed. Apple contract active. Budget available. One-touch confirm to release PO.',
  0.94, now()-interval'15 minutes');

-- 8h. CONTRACT RENEWAL — auto-renew clean (watcher output)
INSERT INTO tickets (reference, source, status, title, description,
  branch_id, supplier_id, owner_id, submitted_by, submitted_by_email,
  value_eur, amount_eur, disposition, recommendation, confidence, created_at)
VALUES ('TS-2026-0208', 'renewal', 'auto_executed',
  'Auto-renewed: Dell Hardware Framework — Global HQ',
  'Contract watcher triggered at 60-day mark. Terms clean. Agent auto-renewed at same terms.',
  'b1000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001',
  'e1000000-0000-0000-0000-000000000001',
  'Sarah Brennan', 'sarah.brennan@company.com',
  480000, 480000, 'auto_execute',
  'Auto-renewed. No price escalation clause triggered. Volume unchanged. Contract extended 12 months to 2027-07-10. Supplier health: green.',
  0.96, now()-interval'2 days');

-- 8i. CONTRACT RENEWAL — price increase, needs human decision
INSERT INTO tickets (reference, source, status, title, description,
  branch_id, supplier_id, owner_id, submitted_by, submitted_by_email,
  value_eur, amount_eur, disposition, recommendation, confidence, created_at)
VALUES ('TS-2026-0209', 'renewal', 'pending_review',
  'Renewal: Salesforce Sales Cloud France — 8% price increase',
  'Salesforce proposing 8% uplift on renewal. Current: €165/seat/mo × 85 seats. Proposed: €178.20. Contract expires 2026-06-29.',
  'b1000000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000008',
  'e1000000-0000-0000-0000-000000000002',
  'Marc Dupont', 'marc.dupont@company.com',
  181764, 181764, 'one_touch',
  'One-touch. Market benchmark is 4-5% for Salesforce renewals. 8% exceeds benchmark. Agent recommendation: counter at 3% or restructure to remove 6 unused seats and accept 5%. Brief prepared.',
  0.83, now()-interval'1 day');

-- 8j. HYPERSCALER ALERT — AWS anomaly
INSERT INTO tickets (reference, source, status, title, description,
  branch_id, supplier_id, owner_id, submitted_by, submitted_by_email,
  value_eur, amount_eur, disposition, recommendation, confidence, created_at)
VALUES ('TS-2026-0210', 'monitoring', 'pending_review',
  'AWS spend anomaly — Global HQ 3.4× spike vs 7-day avg',
  'AWS EC2 + RDS spend: €48,200 this week vs €14,100 prior 7-day average. Likely cause: data migration job left running.',
  'b1000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000004',
  'e1000000-0000-0000-0000-000000000001',
  'Sarah Brennan', 'sarah.brennan@company.com',
  48200, 48200, 'one_touch',
  'Anomaly detected. 3.4× above 7-day baseline. Reserved Instance utilisation dropped to 61% (normal: 89%). Probable: batch job or migration left running. Review and terminate if confirmed.',
  0.87, now()-interval'6 hours');


-- ── 9. Decisions + trace signals for the key tickets ─────────

-- Decision for TS-2026-0201 (auto_execute Figma)
WITH t AS (SELECT id FROM tickets WHERE reference='TS-2026-0201')
INSERT INTO decisions (ticket_id, disposition, confidence, reasoning, recommendation, model_used, created_at)
SELECT t.id, 'auto_execute', 0.97,
  'All 5 signals green. Contract: no existing Figma contract but catalogue price confirmed at €45/seat. Budget: DACH SaaS Q2 bucket 38% headroom. Supplier: Figma Inc health green, no open disputes. Request: normal seat expansion pattern, 6 seats within delegated authority. Policy: no compliance blocker, standard SaaS onboarding.',
  'Auto-approve. Commit €270 to DACH SaaS Q2. Issue PO to Figma.',
  'claude-sonnet-4-6', now()-interval'5 hours'
FROM t;

WITH d AS (SELECT d.id FROM decisions d JOIN tickets t ON t.id=d.ticket_id WHERE t.reference='TS-2026-0201')
INSERT INTO trace_log (decision_id, signal, value, weight, green, notes, created_at)
SELECT d.id, s.signal, s.value, s.weight, s.green, s.notes, now()-interval'5 hours' FROM d,
(VALUES
  ('contract',    '0.95', 0.20, true,  'No existing Figma contract. Catalogue price €45/seat confirmed. Standard terms.'),
  ('consumption', '0.98', 0.25, true,  'DACH SaaS Q2: €240k allocated, €148k spent, €38k committed. 38% headroom. This commit: €270.'),
  ('supplier',    '0.97', 0.20, true,  'Figma Inc: health green. No open disputes. GDPR DPA on file. ISO 27001 certified.'),
  ('request',     '0.99', 0.20, true,  'Normal seat expansion. Lena Hoffmann authority: €50k. €270 well within limit. No duplicate capability detected.'),
  ('policy',      '0.96', 0.15, true,  'No compliance blocker. SaaS onboarding standard process. No LkSG flag.')
) AS s(signal, value, weight, green, notes) FROM d;

-- Decision for TS-2026-0203 (one_touch Notion)
WITH t AS (SELECT id FROM tickets WHERE reference='TS-2026-0203')
INSERT INTO decisions (ticket_id, disposition, confidence, reasoning, recommendation, model_used, created_at)
SELECT t.id, 'one_touch', 0.71,
  'Signal mixed. Contract: no Notion contract, no catalogue entry. Budget: UK hardware Q2 87% committed — tight. Supplier: Notion Labs unassessed, no DPA on file. Request: capability overlap with Confluence (active license, UK branch). Policy: new SaaS supplier requires GDPR assessment before approval.',
  'Route to one-touch review. Recommend checking Confluence utilisation before adding Notion. If approved, trigger supplier onboarding for Notion Labs.',
  'claude-sonnet-4-6', now()-interval'2 hours'
FROM t;

WITH d AS (SELECT d.id FROM decisions d JOIN tickets t ON t.id=d.ticket_id WHERE t.reference='TS-2026-0203')
INSERT INTO trace_log (decision_id, signal, value, weight, green, notes, created_at)
SELECT d.id, s.signal, s.value, s.weight, s.green, s.notes, now()-interval'2 hours' FROM d,
(VALUES
  ('contract',    '0.40', 0.20, false, 'No Notion contract. Not in catalogue. New supplier engagement required.'),
  ('consumption', '0.78', 0.25, true,  'UK SaaS Q2 bucket has headroom. €1,584 within budget. Not a blocker.'),
  ('supplier',    '0.35', 0.20, false, 'Notion Labs: no compliance check, no DPA, no ISO 27001 evidence. GDPR assessment required.'),
  ('request',     '0.60', 0.20, false, 'Confluence already licensed for UK. Duplicate documentation capability detected.'),
  ('policy',      '0.55', 0.15, false, 'New SaaS supplier — GDPR onboarding mandatory before approval. Policy blocker.')
) AS s(signal, value, weight, green, notes) FROM d;

-- Decision for TS-2026-0205 (escalate McKinsey)
WITH t AS (SELECT id FROM tickets WHERE reference='TS-2026-0205')
INSERT INTO decisions (ticket_id, disposition, confidence, reasoning, recommendation, model_used, created_at)
SELECT t.id, 'escalate', 0.91,
  'Escalation mandatory. Value €220k exceeds €100k threshold. McKinsey not in supplier register — no contract, no compliance check, no NDA. SOW scope (digital operations) overlaps with active Accenture engagement (TS-2026-0122). Legal review required for SOW terms before commitment.',
  'Escalate to CFO + Legal. Jira PROC-2205 created. Require: supplier onboarding, NDA, SOW legal review, conflict check vs Accenture engagement before any commitment.',
  'claude-sonnet-4-6', now()-interval'45 minutes'
FROM t;

WITH d AS (SELECT d.id FROM decisions d JOIN tickets t ON t.id=d.ticket_id WHERE t.reference='TS-2026-0205')
INSERT INTO trace_log (decision_id, signal, value, weight, green, notes, created_at)
SELECT d.id, s.signal, s.value, s.weight, s.green, s.notes, now()-interval'45 minutes' FROM d,
(VALUES
  ('contract',    '0.10', 0.20, false, 'No McKinsey contract. No NDA. No MSA. New supplier — full onboarding required.'),
  ('consumption', '0.72', 0.25, true,  'Global HQ services Q2 bucket has capacity. Not a blocker at this stage.'),
  ('supplier',    '0.15', 0.20, false, 'McKinsey not in supplier register. No compliance assessment. No GDPR DPA.'),
  ('request',     '0.65', 0.20, false, 'Scope overlap with active Accenture SOW (TS-2026-0122). Duplication risk.'),
  ('policy',      '0.10', 0.15, false, 'Value €220k — mandatory escalation threshold is €100k. CFO approval required.')
) AS s(signal, value, weight, green, notes) FROM d;

-- Decision for TS-2026-0209 (Salesforce renewal)
WITH t AS (SELECT id FROM tickets WHERE reference='TS-2026-0209')
INSERT INTO decisions (ticket_id, disposition, confidence, reasoning, recommendation, model_used, created_at)
SELECT t.id, 'one_touch', 0.83,
  'Price increase 8% exceeds market benchmark 4-5%. Current entitlement already 6 seats over quota — true-up exposure at renewal. Agent built counter-offer: accept 3% + restructure to 79 seats (removes over-quota risk) = net saving vs current trajectory.',
  'Counter at 3% uplift + reduce to 79 seats. Walk-away: do not accept 8% on current 85 seats — true-up will add further cost. Proposed renewal value: €168,876 vs current trajectory €196,000+.',
  'claude-sonnet-4-6', now()-interval'1 day'
FROM t;

WITH d AS (SELECT d.id FROM decisions d JOIN tickets t ON t.id=d.ticket_id WHERE t.reference='TS-2026-0209')
INSERT INTO trace_log (decision_id, signal, value, weight, green, notes, created_at)
SELECT d.id, s.signal, s.value, s.weight, s.green, s.notes, now()-interval'1 day' FROM d,
(VALUES
  ('contract',    '0.55', 0.20, false, 'Expiry 2026-06-29 — 31 days. Escalation clause: 8% proposed. Market benchmark: 4-5%. Above benchmark.'),
  ('consumption', '0.70', 0.25, true,  'France SaaS Q2 at 102% committed. Renewal at current cost is a blocker. Restructure creates headroom.'),
  ('supplier',    '0.85', 0.20, true,  'Salesforce health: green. No open disputes. Renewal relationship established. Leverage: 6 seat overage they know about.'),
  ('request',     '0.88', 0.20, true,  'Renewal is expected. Marc Dupont authority covers this. Normal renewal cycle.'),
  ('policy',      '0.82', 0.15, true,  'No compliance blocker. Standard renewal process. Counter-offer within policy.')
) AS s(signal, value, weight, green, notes) FROM d;

-- Decision for TS-2026-0210 (AWS anomaly)
WITH t AS (SELECT id FROM tickets WHERE reference='TS-2026-0210')
INSERT INTO decisions (ticket_id, disposition, confidence, reasoning, recommendation, model_used, created_at)
SELECT t.id, 'one_touch', 0.87,
  'Spend 3.4× above 7-day average. RI utilisation dropped from 89% to 61% — on-demand instances spinning up. Pattern consistent with batch migration job not terminated. Cannot auto-remediate without human confirmation that job is safe to stop.',
  'Review EC2 running instances in us-east-1 and eu-west-1. Terminate batch migration if confirmed complete. Expected saving on termination: ~€34k/week at current rate.',
  'claude-sonnet-4-6', now()-interval'6 hours'
FROM t;

WITH d AS (SELECT d.id FROM decisions d JOIN tickets t ON t.id=d.ticket_id WHERE t.reference='TS-2026-0210')
INSERT INTO trace_log (decision_id, signal, value, weight, green, notes, created_at)
SELECT d.id, s.signal, s.value, s.weight, s.green, s.notes, now()-interval'6 hours' FROM d,
(VALUES
  ('contract',    '0.90', 0.20, true,  'AWS EDP contract active. Spend within committed framework. No contract breach.'),
  ('consumption', '0.15', 0.25, false, '3.4× spike vs 7-day avg. RI utilisation 61% vs normal 89%. On-demand surge detected.'),
  ('supplier',    '0.95', 0.20, true,  'AWS health: green. No service disruption. Normal API responses.'),
  ('request',     '0.85', 0.20, true,  'Monitoring-triggered. Not a user request. Auto-analysis triggered on threshold breach.'),
  ('policy',      '0.80', 0.15, true,  'Anomaly detection policy triggered correctly. Cannot auto-terminate without confirmation.')
) AS s(signal, value, weight, green, notes) FROM d;


-- ── 10. Contract changes — negotiation intelligence ──────────
INSERT INTO contract_changes (contract_id, change_type, previous_value, proposed_value,
  delta_pct, delta_eur, market_rate_pct, agent_assessment, recommended_position,
  walk_away_value, accepted, detected_at)
VALUES
  -- Salesforce France renewal — price increase flagged
  ('c1000000-0000-0000-0000-000000000007',
   'price_increase', '165.00', '178.20',
   8.0, 13464, 4.5,
   'Salesforce proposing 8% uplift. Market benchmark Q2 2026: 4-5% for Sales Cloud renewals at this seat count. Entitlement already over-committed by 6 seats — vendor has leverage but so do we (true-up exposure).',
   'Counter at 3% + right-size to 79 seats. Net annual impact: -€8,640 vs current. Walk-away: accept max 5% on reduced seat count.',
   '169.95', false, now()-interval'8 days'),

  -- SAP — volume change
  ('c1000000-0000-0000-0000-000000000008',
   'volume_change', '1200', '1350',
   12.5, 87000, 0,
   'SAP proposing +150 users in true-up. Actual active users per access logs: 1,180. Over-count by 170 users. Agent recommends audit before accepting.',
   'Dispute true-up. Submit access log evidence showing 1,180 active. Negotiate down to 1,200 + 50 buffer.',
   null, false, now()-interval'15 days'),

  -- Microsoft 365 DACH — clean renewal
  ('c1000000-0000-0000-0000-000000000002',
   'price_increase', '36.00', '36.00',
   0.0, 0, 0,
   'Microsoft EA renewal at same per-seat price. No escalation clause triggered. Volume unchanged.',
   'Auto-renew recommended. No negotiation needed.',
   null, true, now()-interval'30 days');


-- ── 11. Workflow runs — show agent activity history ───────────
INSERT INTO workflow_runs (workflow_name, status, started_at, ended_at, error_message)
VALUES
  ('intake_receiver',       'success', now()-interval'5 hours 2 min',  now()-interval'5 hours',      null),
  ('intake_receiver',       'success', now()-interval'3 hours 1 min',  now()-interval'3 hours',      null),
  ('intake_receiver',       'success', now()-interval'2 hours 1 min',  now()-interval'2 hours',      null),
  ('intake_receiver',       'success', now()-interval'90 minutes 45s', now()-interval'90 minutes',   null),
  ('intake_receiver',       'success', now()-interval'45 minutes 38s', now()-interval'45 minutes',   null),
  ('intake_receiver',       'success', now()-interval'30 minutes 41s', now()-interval'30 minutes',   null),
  ('intake_receiver',       'success', now()-interval'15 minutes 36s', now()-interval'15 minutes',   null),
  ('contract_watcher',      'success', now()-interval'22 hours',       now()-interval'21 hours 58 min', null),
  ('contract_watcher',      'success', now()-interval'46 hours',       now()-interval'45 hours 57 min', null),
  ('hyperscaler_monitor',   'success', now()-interval'18 hours',       now()-interval'17 hours 59 min', null),
  ('hyperscaler_monitor',   'success', now()-interval'42 hours',       now()-interval'41 hours 58 min', null),
  ('supplier_onboarding',   'success', now()-interval'3 days',         now()-interval'3 days'+interval'4 minutes', null),
  ('invoice_processor',     'success', now()-interval'18 days',        now()-interval'18 days'+interval'2 minutes', null),
  ('invoice_processor',     'success', now()-interval'10 days',        now()-interval'10 days'+interval'1 minute', null),
  ('invoice_processor',     'success', now()-interval'3 days',         now()-interval'3 days'+interval'3 minutes', null),
  ('reorder_trigger',       'success', now()-interval'3 hours 3 min',  now()-interval'3 hours',      null),
  ('supplier_reply_handler','success', now()-interval'4 hours',        now()-interval'4 hours'+interval'30s', null);


-- ── Done ──────────────────────────────────────────────────────
-- Summary of what was seeded:
-- Budget buckets:       realistic allocations across all branches + 2 edge cases
-- License entitlements: 8 products, 3 scenarios (healthy / shelfware / overage)
-- License assignments:  17 users across 4 products
-- Assets:               11 items — active, warranty-expiring, expired, EOL, decomm
-- Asset depreciation:   7 monthly entries
-- Invoices:             4 — matched, minor variance, mismatch, pending delivery
-- Payment instructions: 2 pending
-- ERP sync queue:       3 entries
-- Tickets:              10 new — every status + scenario covered
-- Decisions:            5 with full reasoning
-- Trace signals:        25 signal rows (5 per decision)
-- Contract changes:     3 — price increase (disputed), volume change, clean renewal
-- Workflow runs:        17 entries showing agent activity history
