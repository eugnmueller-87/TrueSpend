#!/usr/bin/env python3
"""Generate /tmp/mock_remaining.sql on the VPS.
All IDs use only valid hex chars (0-9, a-f).
Mapped to live DB column names.
"""

sql = """\
-- ============================================================
-- TrueSpend -- Remaining Mock Data (v3, 2026-05-30)
-- ============================================================

-- license_assignments: user_id (UUID FK to users), active (bool), assigned_to_user (text)
INSERT INTO license_assignments (id, entitlement_id, user_id, assigned_to_user, assigned_at, active, cost_center_id)
VALUES
  ('a1000000-0000-0000-0000-000000000001','e1000001-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Klaus Weber','2026-01-10 09:00:00+00',true,'cc000000-0000-0000-0000-000000000001'),
  ('a1000000-0000-0000-0000-000000000002','e1000001-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000003','Lena Hoffmann','2026-01-15 11:00:00+00',true,'cc000000-0000-0000-0000-000000000002'),
  ('a1000000-0000-0000-0000-000000000003','e1000001-0000-0000-0000-000000000002','e1000000-0000-0000-0000-000000000002','Marc Dupont','2026-02-01 08:30:00+00',true,'cc000000-0000-0000-0000-000000000003'),
  ('a1000000-0000-0000-0000-000000000004','e1000001-0000-0000-0000-000000000003','e1000000-0000-0000-0000-000000000004','Erik Lindqvist','2026-02-14 14:00:00+00',true,'cc000000-0000-0000-0000-000000000001'),
  ('a1000000-0000-0000-0000-000000000005','e1000001-0000-0000-0000-000000000004','e1000000-0000-0000-0000-000000000005','Priya Nair','2026-03-01 10:00:00+00',true,'cc000000-0000-0000-0000-000000000002'),
  ('a1000000-0000-0000-0000-000000000006','e1000001-0000-0000-0000-000000000005','e1000000-0000-0000-0000-000000000006','Thomas Mueller','2026-03-15 09:00:00+00',true,'cc000000-0000-0000-0000-000000000003'),
  ('a1000000-0000-0000-0000-000000000007','e1000001-0000-0000-0000-000000000006','e1000000-0000-0000-0000-000000000007','Jana Schmidt','2026-04-01 11:00:00+00',true,'cc000000-0000-0000-0000-000000000001'),
  ('a1000000-0000-0000-0000-000000000008','e1000001-0000-0000-0000-000000000007','e1000000-0000-0000-0000-000000000001','Klaus Weber','2026-04-10 08:00:00+00',true,'cc000000-0000-0000-0000-000000000002'),
  ('a1000000-0000-0000-0000-000000000009','e1000001-0000-0000-0000-000000000008','e1000000-0000-0000-0000-000000000002','Marc Dupont','2026-04-20 15:30:00+00',false,'cc000000-0000-0000-0000-000000000003')
ON CONFLICT (id) DO NOTHING;

-- supplier_emails (IDs using only valid hex)
INSERT INTO supplier_emails (id, supplier_id, contract_id, direction, subject, body_summary, commitments, order_reference, flagged, flag_reason, received_at)
VALUES
  (
    'e0000001-0000-0000-0000-000000000001',
    'f1000000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001',
    'inbound',
    $$Re: PO-2026-0042 Delivery Confirmation$$,
    $$Dell confirms shipment of 50x OptiPlex 7090 desktops. Expected delivery 2026-06-05. Tracking: DHL-9823741.$$,
    ARRAY[$$Deliver by 2026-06-05$$,$$Provide tracking updates$$],
    'PO-2026-0042',
    false,
    null,
    '2026-05-28 10:15:00+00'
  ),
  (
    'e0000001-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000004',
    'c1000000-0000-0000-0000-000000000002',
    'inbound',
    $$AWS Reserved Instance Pricing Update Q3 2026$$,
    $$AWS is updating reserved instance pricing for EC2 M-series. New rates effective 2026-07-01. Existing commitments honoured until contract end.$$,
    ARRAY[$$Honour existing pricing until contract end$$],
    null,
    true,
    $$Pricing change may impact Q3 budget by up to 8%$$,
    '2026-05-27 14:30:00+00'
  ),
  (
    'e0000001-0000-0000-0000-000000000003',
    'f1000000-0000-0000-0000-000000000005',
    'c1000000-0000-0000-0000-000000000003',
    'outbound',
    $$TrueSpend: Request for GCP Committed Use Discount Terms$$,
    $$We are evaluating our Google Cloud commitment for H2 2026. Please provide updated CUD pricing for BigQuery and GKE workloads in eu-west1.$$,
    ARRAY[$$Provide CUD pricing by 2026-06-10$$],
    null,
    false,
    null,
    '2026-05-29 09:00:00+00'
  ),
  (
    'e0000001-0000-0000-0000-000000000004',
    'f1000000-0000-0000-0000-000000000002',
    null,
    'inbound',
    $$Lenovo ThinkPad X1 Carbon -- EOL Notice$$,
    $$Lenovo announces end-of-life for ThinkPad X1 Carbon Gen 9. Last order date 2026-09-30. Recommend transition to Gen 11 or IdeaPad Pro.$$,
    ARRAY[$$Last order date 2026-09-30$$,$$Offer migration pricing$$],
    null,
    true,
    $$EOL affects 34 devices in current asset register$$,
    '2026-05-26 16:45:00+00'
  ),
  (
    'e0000001-0000-0000-0000-000000000005',
    'f1000000-0000-0000-0000-000000000003',
    'c1000000-0000-0000-0000-000000000004',
    'inbound',
    $$Apple Business Manager -- Volume License Renewal$$,
    $$Your Apple Business Manager volume license expires 2026-08-15. Auto-renewal is enabled. Renewal invoice EUR 47,200 will be issued 30 days prior.$$,
    ARRAY[$$Auto-renew on 2026-08-15$$,$$Invoice 30 days prior$$],
    null,
    false,
    null,
    '2026-05-25 11:00:00+00'
  )
ON CONFLICT (id) DO NOTHING;

-- legal_documents (IDs using only valid hex: d + digits/a-f)
INSERT INTO legal_documents (id, supplier_id, doc_type, content, status)
VALUES
  (
    'd0000001-0000-0000-0000-000000000020',
    'f1000000-0000-0000-0000-000000000004',
    'dpa',
    $$Data Processing Agreement between TrueSpend GmbH and Amazon Web Services EMEA SARL. AWS acts as data processor for infrastructure services. Sub-processors listed in Annex 1. Data residency: EU-WEST-1 (Ireland). Standard Contractual Clauses (EU) 2021/914 incorporated by reference. Effective 2025-01-01.$$,
    'signed'
  ),
  (
    'd0000001-0000-0000-0000-000000000021',
    'f1000000-0000-0000-0000-000000000005',
    'nda',
    $$Mutual Non-Disclosure Agreement between TrueSpend GmbH and Google LLC. Confidential information includes pricing, architecture, and roadmap discussions. Term: 3 years from 2025-03-15. Governed by German law, courts of Munich.$$,
    'signed'
  ),
  (
    'd0000001-0000-0000-0000-000000000022',
    'f1000000-0000-0000-0000-000000000001',
    'nda',
    $$Mutual NDA between TrueSpend GmbH and Dell Technologies GmbH. Covers enterprise hardware pricing, tender responses, and configuration details. Auto-renews annually. Signed 2024-11-01.$$,
    'signed'
  ),
  (
    'd0000001-0000-0000-0000-000000000023',
    'f1000000-0000-0000-0000-000000000006',
    'dpa',
    $$Article 28 GDPR Data Processing Agreement with Microsoft Ireland Operations Ltd for Microsoft 365 services. Data subjects: TrueSpend employees. Retention periods per Microsoft DPA schedule. Processing locations: EU datacentres. Signed 2025-06-01.$$,
    'signed'
  ),
  (
    'd0000001-0000-0000-0000-000000000024',
    'f1000000-0000-0000-0000-000000000003',
    'coc',
    $$Apple Inc. Supplier Code of Conduct acknowledgement. TrueSpend confirms compliance with Apple Supply Chain Responsibility standards including labour practices, environmental requirements, and anti-corruption policies. Annual certification 2026.$$,
    'signed'
  )
ON CONFLICT (id) DO NOTHING;

-- tickets (all 8 user profiles, all key scenarios, valid hex IDs)
INSERT INTO tickets (id, reference, source, status, title, description, branch_id, supplier_id, owner_id, amount_eur, category, recommendation, confidence, review_notes, disposition, review_type, requested_by)
VALUES
  (
    'f0000001-0000-0000-0000-000000000101','TS-2026-0101','intake','pending_confirm',
    $$Budget Reallocation: Hyperscaler Q2 Overspend$$,
    $$DACH Operations projected to exceed hyperscaler budget by EUR 23,000 in Q2. CFO approval required to release pool reserves. AWS cost driver: ML workload expansion for demand forecasting project.$$,
    'b1000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000004','e1000000-0000-0000-0000-000000000001',
    23000.00,'hyperscaler',
    $$Approve reallocation from pool. Workload growth aligns with approved ML initiative. Recommend quarterly review of cloud forecasting accuracy.$$,
    0.87,$$Pool has EUR 45,000 available. Reallocation within CFO authority.$$,
    'one_touch','budget_check','Sarah Brennan'
  ),
  (
    'f0000001-0000-0000-0000-000000000102','TS-2026-0102','automatic','signature_required',
    $$Supplier Onboarding: Cloudflare Germany GmbH -- NDA Signature Required$$,
    $$Compliance agents completed onboarding for Cloudflare Germany GmbH. Legal risk: LOW. GDPR: SCC required (US parent). InfoSec score: 82/100. LkSG: Compliant. NDA ready for signature.$$,
    'b1000000-0000-0000-0000-000000000001',null,'e1000000-0000-0000-0000-000000000002',
    0.00,'services',
    $$Proceed with onboarding. Attach signed NDA before first PO. SCC addendum required to DPA within 30 days.$$,
    0.91,$$4/4 compliance agents returned green. SCC is standard for US-HQ suppliers.$$,
    'one_touch','compliance','Sarah Brennan'
  ),
  (
    'f0000001-0000-0000-0000-000000000103','TS-2026-0103','intake','pending_confirm',
    $$Hardware Refresh: 15x MacBook Pro M4 for France Engineering$$,
    $$France branch engineering team requesting MacBook Pro M4 replacement for EOL Intel devices. Unit price EUR 2,499. Total EUR 37,485. Budget bucket: hardware Q2 2026.$$,
    'b1000000-0000-0000-0000-000000000005','f1000000-0000-0000-0000-000000000003','e1000000-0000-0000-0000-000000000003',
    37485.00,'hardware',
    $$Approve. Devices are 4 years old, warranty expired. M4 performance uplift justified for engineering workloads. Apple Business Manager available for bulk pricing.$$,
    0.93,$$Budget available: EUR 41,200 in hardware Q2. Supplier compliance: signed NDA + DPA.$$,
    'one_touch','budget_check','Marc Dupont'
  ),
  (
    'f0000001-0000-0000-0000-000000000104','TS-2026-0104','automatic','pending_review',
    $$3-Way Match Failed: Invoice INV-2026-0831 vs PO-2026-0039$$,
    $$Invoice from Lenovo GmbH (EUR 18,750) exceeds PO-2026-0039 (EUR 18,200) by EUR 550 (3.02%). Tolerance threshold 2%. Delivery confirmed 2026-05-22. Finance review required.$$,
    'b1000000-0000-0000-0000-000000000002','f1000000-0000-0000-0000-000000000002','e1000000-0000-0000-0000-000000000004',
    18750.00,'hardware',
    $$Request credit note for EUR 550 or obtain amended PO from procurement before releasing payment.$$,
    0.88,$$3.02% variance exceeds 2% tolerance. Likely freight surcharge not in original PO scope.$$,
    'one_touch','invoice_match',null
  ),
  (
    'f0000001-0000-0000-0000-000000000105','TS-2026-0105','renewal','pending_confirm',
    $$Contract Renewal: AWS Enterprise Support -- Price Increase 12%$$,
    $$AWS Enterprise Support contract expires 2026-06-30. Auto-renewal triggers 12% price increase (EUR 84,000 to EUR 94,080 annually). LkSG clause addendum requested by Legal.$$,
    'b1000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000004','e1000000-0000-0000-0000-000000000005',
    94080.00,'hyperscaler',
    $$Counter-offer: request 8% increase cap citing 3-year relationship and committed spend. Attach LkSG addendum as condition of renewal.$$,
    0.82,$$12% uplift is above CPI. Legal review flagged SCC gap in current contract.$$,
    'one_touch','contract_review',null
  ),
  (
    'f0000001-0000-0000-0000-000000000106','TS-2026-0106','automatic','open',
    $$Late Delivery: PO-2026-0044 -- Dell OptiPlex 9 Days Overdue$$,
    $$PO-2026-0044 (Dell Technologies, 30x OptiPlex 7090) was due 2026-05-20. As of 2026-05-29 delivery not confirmed. 9 days late. SLA penalty clause applicable at 7 days.$$,
    'b1000000-0000-0000-0000-000000000003','f1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000006',
    15600.00,'hardware',
    $$Issue formal delay notice. Request confirmed delivery date. Evaluate SLA penalty: EUR 780/day after day 7 per contract clause 8.3.$$,
    0.95,$$9 days late. Penalty clause triggered at day 7. Operations to log formal notice.$$,
    'auto_execute',null,null
  ),
  (
    'f0000001-0000-0000-0000-000000000107','TS-2026-0107','intake','auto_executed',
    $$License Assignment: Figma Professional -- Jana Schmidt$$,
    $$Request to assign Figma Professional seat to Jana Schmidt (Design, DACH). Entitlement pool has 3 available seats. Budget committed. License assigned automatically.$$,
    'b1000000-0000-0000-0000-000000000002',null,'e1000000-0000-0000-0000-000000000007',
    840.00,'saas_license',
    $$Assigned. Seat allocated from existing entitlement. No new procurement required.$$,
    0.99,$$Pool available: 3 seats. Manager authority: confirmed. Budget: EUR 1,200 headroom.$$,
    'auto_execute',null,'Jana Schmidt'
  ),
  (
    'f0000001-0000-0000-0000-000000000108','TS-2026-0108','intake','pending_confirm',
    $$New SaaS: Miro Enterprise -- DACH Design Team (12 seats)$$,
    $$DACH Design team requesting Miro Enterprise for collaborative whiteboarding. 12 seats x EUR 16/seat/month = EUR 2,304/year. No existing entitlement. Vendor compliance check pending.$$,
    'b1000000-0000-0000-0000-000000000002',null,'e1000000-0000-0000-0000-000000000001',
    2304.00,'saas_license',
    $$Initiate supplier onboarding for Miro Inc. GDPR assessment needed (US company, EU data residency unclear). Approve provisionally pending compliance.$$,
    0.78,$$No existing supplier record for Miro. GDPR risk: medium (US HQ). Budget available.$$,
    'one_touch','compliance','Jana Schmidt'
  ),
  (
    'f0000001-0000-0000-0000-000000000109','TS-2026-0109','automatic','open',
    $$LLM Cost Anomaly: Anthropic API spend 4.2x above 7-day average$$,
    $$Global HQ Anthropic API key consumed EUR 1,840 on 2026-05-28 vs 7-day daily average of EUR 438. Spike factor: 4.2x. Threshold: 3x. Likely cause: intake_receiver batch processing large RFP documents.$$,
    'b1000000-0000-0000-0000-000000000001',null,'e1000000-0000-0000-0000-000000000003',
    1840.00,'other',
    $$Review API key usage logs. Confirm batch job was authorised. Consider per-request cost caps for intake workflow.$$,
    0.84,$$4.2x spike exceeds 3x anomaly threshold. Budget impact within monthly allocation.$$,
    'one_touch',null,null
  ),
  (
    'f0000001-0000-0000-0000-000000000110','TS-2026-0110','automatic','pending_confirm',
    $$Asset EOL: 6x Devices Flagged for Replacement (DACH)$$,
    $$Monthly depreciation run identified 6 assets with book value below 10% AND warranty expired. Estimated replacement budget: EUR 14,400 (6x mid-range laptops at EUR 2,400).$$,
    'b1000000-0000-0000-0000-000000000002',null,'e1000000-0000-0000-0000-000000000003',
    14400.00,'hardware',
    $$Create replacement PO. Decommission flagged assets. Return any associated SaaS licenses to pool.$$,
    0.91,$$6 assets: book value 3-8% of original. All warranties expired 6-18 months ago.$$,
    'one_touch','budget_check',null
  ),
  (
    'f0000001-0000-0000-0000-000000000111','TS-2026-0111','monitoring','open',
    $$Cloud Spend Alert: GCP Nordics Region 31% Over Committed Budget$$,
    $$Google Cloud Platform spend in Nordics reached EUR 68,900 committed vs EUR 52,600 budget Q2. Overshoot: EUR 16,300 (31%). BigQuery on-demand queries are primary driver.$$,
    'b1000000-0000-0000-0000-000000000006','f1000000-0000-0000-0000-000000000005','e1000000-0000-0000-0000-000000000004',
    16300.00,'hyperscaler',
    $$Switch BigQuery workloads to flat-rate slots. Estimated saving EUR 12,000/quarter.$$,
    0.89,$$31% over budget. On-demand pricing 3x flat-rate for sustained workloads.$$,
    'one_touch',null,null
  ),
  (
    'f0000001-0000-0000-0000-000000000112','TS-2026-0112','renewal','escalated',
    $$Contract Expiry: Microsoft EA -- EUR 210,000 Annual Renewal (Jira PROC-0089)$$,
    $$Microsoft Enterprise Agreement expires 2026-07-15. Annual value EUR 210,000. Exceeds EUR 100,000 escalation threshold. Jira ticket PROC-0089 created. CFO and Legal sign-off required.$$,
    'b1000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000006','e1000000-0000-0000-0000-000000000001',
    210000.00,'saas_license',
    $$Escalated to Jira. Negotiate 3-year ELA with 5% annual cap. Include Power Platform licensing in scope.$$,
    0.96,$$EUR 210k exceeds escalation threshold. Microsoft EA specialist engaged. Renewal deadline 2026-07-15.$$,
    'escalate','contract_review',null
  )
ON CONFLICT (id) DO NOTHING;

-- hyperscaler_positions (use service_name not service)
INSERT INTO hyperscaler_positions (id, branch_id, provider, service_name, committed_eur, projected_eur, reservation_util, overshoot_risk, undershoot_risk, period, snapshot_date)
VALUES
  ('b0a00001-0000-0000-0000-000000000010','b1000000-0000-0000-0000-000000000006','gcp','BigQuery',52600,68900,0.61,true,false,'2026-Q2','2026-05-30'),
  ('b0a00001-0000-0000-0000-000000000011','b1000000-0000-0000-0000-000000000002','aws','EC2',45000,47200,0.88,false,false,'2026-Q2','2026-05-30'),
  ('b0a00001-0000-0000-0000-000000000012','b1000000-0000-0000-0000-000000000001','azure','M365',95000,94100,0.99,false,true,'2026-Q2','2026-05-30'),
  ('b0a00001-0000-0000-0000-000000000013','b1000000-0000-0000-0000-000000000003','aws','RDS',18000,16200,0.90,false,true,'2026-Q2','2026-05-30')
ON CONFLICT (id) DO NOTHING;

-- llm_api_keys (valid hex IDs)
INSERT INTO llm_api_keys (id, provider, key_ref, branch_id, cost_center_id, team_name, monthly_budget_eur)
VALUES
  ('b0b00001-0000-0000-0000-000000000010','anthropic','sk-ant-ref-hq-procurement','b1000000-0000-0000-0000-000000000001','cc000000-0000-0000-0000-000000000001','Procurement Automation',2500.00),
  ('b0b00001-0000-0000-0000-000000000011','anthropic','sk-ant-ref-dach-ops','b1000000-0000-0000-0000-000000000002','cc000000-0000-0000-0000-000000000002','DACH Operations AI',1800.00),
  ('b0b00001-0000-0000-0000-000000000012','openai','sk-openai-ref-nordics','b1000000-0000-0000-0000-000000000006','cc000000-0000-0000-0000-000000000003','Nordics Data Science',1200.00)
ON CONFLICT (id) DO NOTHING;

-- llm_consumption (7-day history + anomaly day, valid hex IDs)
INSERT INTO llm_consumption (id, api_key_id, period_date, input_tokens, output_tokens, cost_usd, cost_eur, provider, model, branch_id, cost_center_id, anomaly_detected)
VALUES
  ('b0c00001-0000-0000-0000-000000000010','b0b00001-0000-0000-0000-000000000010','2026-05-22',180000,42000,12.60,11.72,'anthropic','claude-sonnet-4-6','b1000000-0000-0000-0000-000000000001','cc000000-0000-0000-0000-000000000001',false),
  ('b0c00001-0000-0000-0000-000000000011','b0b00001-0000-0000-0000-000000000010','2026-05-23',195000,48000,13.70,12.74,'anthropic','claude-sonnet-4-6','b1000000-0000-0000-0000-000000000001','cc000000-0000-0000-0000-000000000001',false),
  ('b0c00001-0000-0000-0000-000000000012','b0b00001-0000-0000-0000-000000000010','2026-05-24',172000,39000,11.90,11.07,'anthropic','claude-sonnet-4-6','b1000000-0000-0000-0000-000000000001','cc000000-0000-0000-0000-000000000001',false),
  ('b0c00001-0000-0000-0000-000000000013','b0b00001-0000-0000-0000-000000000010','2026-05-25',168000,37000,11.40,10.60,'anthropic','claude-sonnet-4-6','b1000000-0000-0000-0000-000000000001','cc000000-0000-0000-0000-000000000001',false),
  ('b0c00001-0000-0000-0000-000000000014','b0b00001-0000-0000-0000-000000000010','2026-05-26',182000,44000,12.80,11.91,'anthropic','claude-sonnet-4-6','b1000000-0000-0000-0000-000000000001','cc000000-0000-0000-0000-000000000001',false),
  ('b0c00001-0000-0000-0000-000000000015','b0b00001-0000-0000-0000-000000000010','2026-05-27',190000,46000,13.30,12.37,'anthropic','claude-sonnet-4-6','b1000000-0000-0000-0000-000000000001','cc000000-0000-0000-0000-000000000001',false),
  ('b0c00001-0000-0000-0000-000000000016','b0b00001-0000-0000-0000-000000000010','2026-05-28',820000,198000,56.10,52.19,'anthropic','claude-sonnet-4-6','b1000000-0000-0000-0000-000000000001','cc000000-0000-0000-0000-000000000001',true),
  ('b0c00001-0000-0000-0000-000000000020','b0b00001-0000-0000-0000-000000000011','2026-05-25',95000,22000,6.70,6.23,'anthropic','claude-sonnet-4-6','b1000000-0000-0000-0000-000000000002','cc000000-0000-0000-0000-000000000002',false),
  ('b0c00001-0000-0000-0000-000000000021','b0b00001-0000-0000-0000-000000000011','2026-05-26',102000,25000,7.20,6.70,'anthropic','claude-sonnet-4-6','b1000000-0000-0000-0000-000000000002','cc000000-0000-0000-0000-000000000002',false),
  ('b0c00001-0000-0000-0000-000000000022','b0b00001-0000-0000-0000-000000000011','2026-05-27',98000,23000,6.90,6.42,'anthropic','claude-sonnet-4-6','b1000000-0000-0000-0000-000000000002','cc000000-0000-0000-0000-000000000002',false),
  ('b0c00001-0000-0000-0000-000000000023','b0b00001-0000-0000-0000-000000000011','2026-05-28',101000,24000,7.10,6.60,'anthropic','claude-sonnet-4-6','b1000000-0000-0000-0000-000000000002','cc000000-0000-0000-0000-000000000002',false)
ON CONFLICT (id) DO NOTHING;
"""

with open('/tmp/mock_remaining.sql', 'w') as f:
    f.write(sql)
print('Written', len(sql), 'bytes to /tmp/mock_remaining.sql')
