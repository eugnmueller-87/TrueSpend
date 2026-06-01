-- =============================================================================
-- seed_supplier_master_demo.sql
-- Demo supplier master + coherent contract→PO→invoice→spend story.
--
-- Single source of truth for SPEND = invoices (po_id → supplier). The demo
-- budget_positions rows are DERIVED: spent = exact sum of the demo invoices
-- rolling into each (branch, cost_center, category, period). They reconcile.
--
-- PACKAGING
--   * Every demo row tagged source='demo'.
--   * Idempotent: fixed UUIDs + ON CONFLICT DO UPDATE → re-runnable, no dupes.
--   * Wipeable: see seed_supplier_master_demo_wipe.sql (delete where source='demo').
--
-- NOTE on existing data: the live DB already has 100 real suppliers, 70
-- contracts, etc. This migration does NOT duplicate them. It (a) adds only the
-- truly-missing "gap" vendors, (b) tags+enriches a curated set of EXISTING
-- suppliers as source='demo', and (c) builds the coherence graph on fixed UUIDs.
--   * branches are company-wide on suppliers — suppliers has NO branch_id (by design).
--   * suppliers.category / contracts.category are contract_category (no ai_consumption).
--   * purchase_orders.category / budget_positions.category are spend_category.
--   * budget_positions.available is GENERATED — never inserted.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 0. source column (idempotent add) on every table we touch
-- ---------------------------------------------------------------------------
alter table suppliers        add column if not exists source text;
alter table contracts        add column if not exists source text;
alter table purchase_orders  add column if not exists source text;
alter table invoices         add column if not exists source text;
alter table budget_positions add column if not exists source text;

-- ---------------------------------------------------------------------------
-- 1. GAP vendors — names not already in the master. Deterministic UUIDs d5…
--    source='demo'. Realistic category + risk spread.
-- ---------------------------------------------------------------------------
insert into suppliers (id, name, legal_name, country, category, health,
                       strategic_tier, compliance_status, infosec_score,
                       lock_in_score, processes_personal_data, data_residency,
                       iso27001, soc2, website, source) values
  ('d5000000-0000-0000-0000-000000000001','Snowflake','Snowflake Inc.','USA','hyperscaler','green','strategic','green',88,7.5,true,'EU',true,true,'snowflake.com','demo'),
  ('d5000000-0000-0000-0000-000000000002','Databricks','Databricks Inc.','USA','hyperscaler','green','strategic','green',86,7.0,true,'EU',true,true,'databricks.com','demo'),
  ('d5000000-0000-0000-0000-000000000003','MongoDB Atlas','MongoDB Inc.','USA','hyperscaler','green','preferred','green',84,5.5,true,'EU',true,true,'mongodb.com','demo'),
  ('d5000000-0000-0000-0000-000000000004','Cloudflare','Cloudflare Inc.','USA','hyperscaler','green','preferred','green',90,4.0,false,'mixed',true,true,'cloudflare.com','demo'),
  ('d5000000-0000-0000-0000-000000000005','Vercel','Vercel Inc.','USA','saas_license','green','standard','green',79,3.5,false,'mixed',false,true,'vercel.com','demo'),
  ('d5000000-0000-0000-0000-000000000006','Sentry','Functional Software Inc.','USA','saas_license','green','standard','green',81,2.5,true,'EU',false,true,'sentry.io','demo'),
  ('d5000000-0000-0000-0000-000000000007','Linear','Linear Orbit Inc.','USA','saas_license','green','standard','green',77,2.0,true,'EU',false,true,'linear.app','demo'),
  ('d5000000-0000-0000-0000-000000000008','Intercom','Intercom Inc.','USA','saas_license','watch','standard','amber',72,4.5,true,'non-EU',false,true,'intercom.com','demo'),
  ('d5000000-0000-0000-0000-000000000009','Personio','Personio SE & Co. KG','Germany','saas_license','green','preferred','green',83,5.0,true,'EU',true,true,'personio.com','demo'),
  ('d5000000-0000-0000-0000-000000000010','Google Ads','Google Ireland Ltd.','Ireland','other','green','preferred','green',85,6.0,true,'EU',true,true,'ads.google.com','demo'),
  ('d5000000-0000-0000-0000-000000000011','LinkedIn Ads','LinkedIn Ireland UC','Ireland','other','green','standard','green',82,3.0,true,'EU',true,true,'linkedin.com','demo'),
  ('d5000000-0000-0000-0000-000000000012','Edelman','Edelman GmbH','Germany','services','green','standard','green',70,1.5,false,'EU',false,false,'edelman.com','demo'),
  ('d5000000-0000-0000-0000-000000000013','WeWork','WeWork Germany GmbH','Germany','facilities','watch','tail','amber',55,2.0,false,'EU',false,false,'wework.com','demo')
on conflict (id) do update set
  name=excluded.name, legal_name=excluded.legal_name, country=excluded.country,
  category=excluded.category, health=excluded.health, strategic_tier=excluded.strategic_tier,
  compliance_status=excluded.compliance_status, infosec_score=excluded.infosec_score,
  lock_in_score=excluded.lock_in_score, processes_personal_data=excluded.processes_personal_data,
  data_residency=excluded.data_residency, iso27001=excluded.iso27001, soc2=excluded.soc2,
  website=excluded.website, source='demo';

-- ---------------------------------------------------------------------------
-- 2. ENRICH existing curated suppliers — tag source='demo' + realistic risk
--    spread (mostly green; a handful watch; 1–2 red). Matched by name.
-- ---------------------------------------------------------------------------
-- a) bulk: everything in the curated list → source='demo', sensible defaults
update suppliers set source='demo'
where name in (
  'Slack','Figma','Notion','Atlassian','Salesforce','HubSpot','Zoom','Adobe',
  'DocuSign','Okta','Zendesk','Datadog','PagerDuty','1Password','Miro','Workday',
  'ServiceNow','GitHub','Monday.com','Asana','Tableau','Splunk','CrowdStrike',
  'AWS','Microsoft Azure','Google Cloud','Oracle Cloud','IBM Cloud','OVHcloud','Hetzner',
  'Apple','Dell Technologies','Lenovo','HP Inc.','Logitech','Cisco Systems','Samsung',
  'McKinsey','Deloitte','Accenture','BCG','KPMG','PwC','EY','Capgemini','Randstad','Hays',
  'Sodexo','Aramark','ISS Facility Services','CBRE','Securitas',
  'SAP','Microsoft 365'
);

-- b) risk overlays — a realistic spread so the supplier-risk view shows variety
update suppliers set health='watch', compliance_status='amber'
where source='demo' and name in ('Intercom','Oracle Cloud','Splunk','WeWork','Randstad','Aramark');

update suppliers set health='red', compliance_status='red'
where source='demo' and name in ('Hetzner','Securitas');

update suppliers set strategic_tier='strategic'
where source='demo' and name in ('AWS','Microsoft Azure','Google Cloud','Salesforce','SAP','Microsoft 365','Workday','Snowflake','Databricks');

update suppliers set strategic_tier='preferred'
where source='demo' and name in ('Slack','Atlassian','Adobe','Okta','Datadog','ServiceNow','Apple','Dell Technologies','McKinsey','Deloitte','Accenture');

-- backfill infosec_score / lock_in for enriched rows that are still null,
-- deterministically from the id so values are stable across re-runs
update suppliers set
  infosec_score = coalesce(infosec_score, 70 + (('x'||substr(md5(id::text),1,4))::bit(16)::int % 25)),
  lock_in_score = coalesce(lock_in_score, round((('x'||substr(md5(id::text),5,4))::bit(16)::int % 80)/10.0, 1))
where source='demo';

-- ---------------------------------------------------------------------------
-- 3. COHERENCE LAYER — contracts → POs → invoices on ~18 wired suppliers.
--    All fixed UUIDs, source='demo'. Expiry dates spread; SEVERAL <60 days
--    from 2026-06-01 (expiry_demo flags drive the renewal/expiry demo).
--
--    Convention for the wired set (branch / cost_center / period):
--      HQ  saas_license  → CC-HQ-IT  cc100000-…-001   period 2026-Q2
--      HQ  hyperscaler   → CC-HQ-IT  cc100000-…-001   period 2026-Q2
--      HQ  services      → CC-HQ-FIN cc100000-…-003   period 2026-Q2
--      HQ  hardware      → CC-HQ-IT  cc100000-…-001   period 2026-Q2
--      HQ  other(mkt)    → CC-HQ-MKT cc100000-…-005   period 2026-Q2
--    Keeping the wired set on one branch (HQ) makes the spend rollup trivial
--    to reconcile and read. Each invoice.amount_eur ties to its budget row.
-- ---------------------------------------------------------------------------

-- 3a. CONTRACTS (contract_category; HQ branch; owner = procurement.hq)
--     dates relative to 2026-06-01. Several expiry < 2026-07-31 (<60d).
insert into contracts (id, supplier_id, branch_id, owner_id, name, category,
                       value, value_eur, currency, start_date, expiry_date,
                       notice_days, auto_renew, renewal_state, source) values
  -- expiring <60 days (drive renewal/expiry demo) ----------------------------
  ('dc000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000011','b1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Slack Enterprise Grid','saas_license',48000,48000,'EUR','2025-07-01','2026-06-20',30,true,'price_increase','demo'),
  ('dc000000-0000-0000-0000-000000000002','f2000000-0000-0000-0000-000000000023','b1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Figma Organization','saas_license',22000,22000,'EUR','2025-07-05','2026-06-28',30,true,'clean','demo'),
  ('dc000000-0000-0000-0000-000000000003','f2000000-0000-0000-0000-000000000019','b1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','DocuSign eSignature Business','saas_license',18000,18000,'EUR','2025-07-10','2026-07-12',30,true,'clean','demo'),
  ('dc000000-0000-0000-0000-000000000004','f2000000-0000-0000-0000-000000000034','b1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Datadog Pro Observability','saas_license',64000,64000,'EUR','2025-08-01','2026-07-25',45,true,'volume_change','demo'),
  ('dc000000-0000-0000-0000-000000000005','f2000000-0000-0000-0000-000000000038','b1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','McKinsey Procurement Transformation','services',180000,180000,'EUR','2026-01-15','2026-07-29',60,false,'manual_required','demo'),
  -- expiring 60–180 days -----------------------------------------------------
  ('dc000000-0000-0000-0000-000000000006','f2000000-0000-0000-0000-000000000017','b1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Atlassian Cloud Enterprise','saas_license',56000,56000,'EUR','2025-09-01','2026-08-30',30,true,'clean','demo'),
  ('dc000000-0000-0000-0000-000000000007','f1000000-0000-0000-0000-000000000008','b1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Salesforce Sales Cloud','saas_license',78000,78000,'EUR','2025-10-01','2026-09-30',60,true,'price_increase','demo'),
  ('dc000000-0000-0000-0000-000000000008','f1000000-0000-0000-0000-000000000010','b1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Workday HCM','saas_license',72000,72000,'EUR','2025-11-01','2026-10-31',90,true,'clean','demo'),
  -- cloud / hyperscaler ------------------------------------------------------
  ('dc000000-0000-0000-0000-000000000009','f1000000-0000-0000-0000-000000000004','b1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','AWS Enterprise Agreement','hyperscaler',420000,420000,'EUR','2026-01-01','2026-12-31',90,false,'clean','demo'),
  ('dc000000-0000-0000-0000-000000000010','f1000000-0000-0000-0000-000000000006','b1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Microsoft Azure EA','hyperscaler',310000,310000,'EUR','2026-01-01','2026-12-31',90,false,'clean','demo'),
  ('dc000000-0000-0000-0000-000000000011','d5000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Snowflake Capacity','hyperscaler',150000,150000,'EUR','2026-02-01','2027-01-31',60,false,'clean','demo'),
  -- hardware -----------------------------------------------------------------
  ('dc000000-0000-0000-0000-000000000012','f1000000-0000-0000-0000-000000000003','b1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Apple Business Manager Fleet','hardware',95000,95000,'EUR','2025-07-15','2026-07-20',30,false,'clean','demo'),
  ('dc000000-0000-0000-0000-000000000013','f1000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Dell Workstation Frame Agreement','hardware',60000,60000,'EUR','2025-09-01','2026-08-31',30,false,'clean','demo'),
  -- services -----------------------------------------------------------------
  ('dc000000-0000-0000-0000-000000000014','f1000000-0000-0000-0000-000000000013','b1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Accenture Cloud Migration','services',240000,240000,'EUR','2026-01-01','2026-11-30',60,false,'clean','demo'),
  ('dc000000-0000-0000-0000-000000000015','f2000000-0000-0000-0000-000000000036','b1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Deloitte Tax Advisory','services',85000,85000,'EUR','2026-01-01','2026-09-15',45,false,'clean','demo'),
  -- marketing (other) --------------------------------------------------------
  ('dc000000-0000-0000-0000-000000000016','d5000000-0000-0000-0000-000000000010','b1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Google Ads Annual Spend Commit','other',120000,120000,'EUR','2026-01-01','2026-12-31',30,true,'clean','demo'),
  ('dc000000-0000-0000-0000-000000000017','f2000000-0000-0000-0000-000000000016','b1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','HubSpot Marketing Hub','saas_license',34000,34000,'EUR','2025-08-15','2026-07-18',30,true,'clean','demo'),
  ('dc000000-0000-0000-0000-000000000018','f2000000-0000-0000-0000-000000000015','b1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','ServiceNow ITSM','saas_license',98000,98000,'EUR','2025-12-01','2026-11-30',90,true,'clean','demo')
on conflict (id) do update set
  supplier_id=excluded.supplier_id, branch_id=excluded.branch_id, owner_id=excluded.owner_id,
  name=excluded.name, category=excluded.category, value=excluded.value, value_eur=excluded.value_eur,
  currency=excluded.currency, start_date=excluded.start_date, expiry_date=excluded.expiry_date,
  notice_days=excluded.notice_days, auto_renew=excluded.auto_renew, renewal_state=excluded.renewal_state,
  source='demo';

-- 3b. PURCHASE ORDERS — one per wired contract. status text; category spend_category;
--     amount_eur is the figure invoices match. HQ branch, CC-HQ-IT/FIN/MKT.
insert into purchase_orders (id, po_number, contract_id, supplier_id, branch_id,
                             cost_center_id, raised_by, description, category,
                             amount, amount_eur, currency, po_date, status,
                             delivered_at, source) values
  ('da000000-0000-0000-0000-000000000001','PO-HQ-2026-9001','dc000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000011','b1000000-0000-0000-0000-000000000001','cc100000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Slack Enterprise Grid annual','saas_license',48000,48000,'EUR','2026-04-02','invoiced','2026-04-05','demo'),
  ('da000000-0000-0000-0000-000000000002','PO-HQ-2026-9002','dc000000-0000-0000-0000-000000000002','f2000000-0000-0000-0000-000000000023','b1000000-0000-0000-0000-000000000001','cc100000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Figma Organization annual','saas_license',22000,22000,'EUR','2026-04-10','invoiced','2026-04-12','demo'),
  ('da000000-0000-0000-0000-000000000003','PO-HQ-2026-9003','dc000000-0000-0000-0000-000000000003','f2000000-0000-0000-0000-000000000019','b1000000-0000-0000-0000-000000000001','cc100000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','DocuSign Business annual','saas_license',18000,18000,'EUR','2026-04-15','invoiced','2026-04-16','demo'),
  ('da000000-0000-0000-0000-000000000004','PO-HQ-2026-9004','dc000000-0000-0000-0000-000000000004','f2000000-0000-0000-0000-000000000034','b1000000-0000-0000-0000-000000000001','cc100000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Datadog Pro annual','saas_license',64000,64000,'EUR','2026-04-20','invoiced','2026-04-22','demo'),
  ('da000000-0000-0000-0000-000000000005','PO-HQ-2026-9005','dc000000-0000-0000-0000-000000000005','f2000000-0000-0000-0000-000000000038','b1000000-0000-0000-0000-000000000001','cc100000-0000-0000-0000-000000000003','e1000000-0000-0000-0000-000000000001','McKinsey transformation phase 1','services',180000,180000,'EUR','2026-02-01','invoiced','2026-05-01','demo'),
  ('da000000-0000-0000-0000-000000000006','PO-HQ-2026-9006','dc000000-0000-0000-0000-000000000006','f2000000-0000-0000-0000-000000000017','b1000000-0000-0000-0000-000000000001','cc100000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Atlassian Cloud Enterprise annual','saas_license',56000,56000,'EUR','2026-04-25','invoiced','2026-04-28','demo'),
  ('da000000-0000-0000-0000-000000000007','PO-HQ-2026-9007','dc000000-0000-0000-0000-000000000007','f1000000-0000-0000-0000-000000000008','b1000000-0000-0000-0000-000000000001','cc100000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Salesforce Sales Cloud annual','saas_license',78000,78000,'EUR','2026-05-02','invoiced','2026-05-04','demo'),
  ('da000000-0000-0000-0000-000000000008','PO-HQ-2026-9008','dc000000-0000-0000-0000-000000000008','f1000000-0000-0000-0000-000000000010','b1000000-0000-0000-0000-000000000001','cc100000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Workday HCM annual','saas_license',72000,72000,'EUR','2026-05-05','invoiced','2026-05-07','demo'),
  ('da000000-0000-0000-0000-000000000009','PO-HQ-2026-9009','dc000000-0000-0000-0000-000000000009','f1000000-0000-0000-0000-000000000004','b1000000-0000-0000-0000-000000000001','cc100000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','AWS EA Q2 consumption','hyperscaler',105000,105000,'EUR','2026-04-01','invoiced','2026-05-01','demo'),
  ('da000000-0000-0000-0000-000000000010','PO-HQ-2026-9010','dc000000-0000-0000-0000-000000000010','f1000000-0000-0000-0000-000000000006','b1000000-0000-0000-0000-000000000001','cc100000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Azure EA Q2 consumption','hyperscaler',77500,77500,'EUR','2026-04-01','invoiced','2026-05-01','demo'),
  ('da000000-0000-0000-0000-000000000011','PO-HQ-2026-9011','dc000000-0000-0000-0000-000000000011','d5000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','cc100000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Snowflake Q2 capacity','hyperscaler',37500,37500,'EUR','2026-04-01','invoiced','2026-05-01','demo'),
  ('da000000-0000-0000-0000-000000000012','PO-HQ-2026-9012','dc000000-0000-0000-0000-000000000012','f1000000-0000-0000-0000-000000000003','b1000000-0000-0000-0000-000000000001','cc100000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Apple fleet refresh','hardware',95000,95000,'EUR','2026-03-15','invoiced','2026-04-01','demo'),
  ('da000000-0000-0000-0000-000000000013','PO-HQ-2026-9013','dc000000-0000-0000-0000-000000000013','f1000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','cc100000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Dell workstations batch','hardware',60000,60000,'EUR','2026-03-20','invoiced','2026-04-05','demo'),
  ('da000000-0000-0000-0000-000000000014','PO-HQ-2026-9014','dc000000-0000-0000-0000-000000000014','f1000000-0000-0000-0000-000000000013','b1000000-0000-0000-0000-000000000001','cc100000-0000-0000-0000-000000000003','e1000000-0000-0000-0000-000000000001','Accenture migration milestone 1','services',120000,120000,'EUR','2026-02-15','invoiced','2026-04-30','demo'),
  ('da000000-0000-0000-0000-000000000015','PO-HQ-2026-9015','dc000000-0000-0000-0000-000000000015','f2000000-0000-0000-0000-000000000036','b1000000-0000-0000-0000-000000000001','cc100000-0000-0000-0000-000000000003','e1000000-0000-0000-0000-000000000001','Deloitte tax advisory H1','services',42500,42500,'EUR','2026-03-01','invoiced','2026-05-15','demo'),
  ('da000000-0000-0000-0000-000000000016','PO-HQ-2026-9016','dc000000-0000-0000-0000-000000000016','d5000000-0000-0000-0000-000000000010','b1000000-0000-0000-0000-000000000001','cc100000-0000-0000-0000-000000000005','e1000000-0000-0000-0000-000000000001','Google Ads Q2 spend','other',45000,45000,'EUR','2026-04-01','invoiced','2026-05-01','demo'),
  ('da000000-0000-0000-0000-000000000017','PO-HQ-2026-9017','dc000000-0000-0000-0000-000000000017','f2000000-0000-0000-0000-000000000016','b1000000-0000-0000-0000-000000000001','cc100000-0000-0000-0000-000000000005','e1000000-0000-0000-0000-000000000001','HubSpot Marketing Hub annual','saas_license',34000,34000,'EUR','2026-04-18','invoiced','2026-04-20','demo'),
  ('da000000-0000-0000-0000-000000000018','PO-HQ-2026-9018','dc000000-0000-0000-0000-000000000018','f2000000-0000-0000-0000-000000000015','b1000000-0000-0000-0000-000000000001','cc100000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','ServiceNow ITSM annual','saas_license',98000,98000,'EUR','2026-05-10','invoiced','2026-05-12','demo')
on conflict (id) do update set
  po_number=excluded.po_number, contract_id=excluded.contract_id, supplier_id=excluded.supplier_id,
  branch_id=excluded.branch_id, cost_center_id=excluded.cost_center_id, raised_by=excluded.raised_by,
  description=excluded.description, category=excluded.category, amount=excluded.amount,
  amount_eur=excluded.amount_eur, currency=excluded.currency, po_date=excluded.po_date,
  status=excluded.status, delivered_at=excluded.delivered_at, source='demo';

-- 3c. INVOICES — one per PO, amount_eur = PO amount_eur (matched). SPEND TRUTH.
insert into invoices (id, po_id, supplier_id, invoice_number, amount_eur,
                      raw_amount, raw_currency, currency, status, match_result,
                      received_at, matched_at, source) values
  ('de000000-0000-0000-0000-000000000001','da000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000011','INV-SLK-2026-001',48000,48000,'EUR','EUR','approved','matched','2026-04-06','2026-04-07','demo'),
  ('de000000-0000-0000-0000-000000000002','da000000-0000-0000-0000-000000000002','f2000000-0000-0000-0000-000000000023','INV-FIG-2026-001',22000,22000,'EUR','EUR','approved','matched','2026-04-13','2026-04-14','demo'),
  ('de000000-0000-0000-0000-000000000003','da000000-0000-0000-0000-000000000003','f2000000-0000-0000-0000-000000000019','INV-DSG-2026-001',18000,18000,'EUR','EUR','approved','matched','2026-04-17','2026-04-18','demo'),
  ('de000000-0000-0000-0000-000000000004','da000000-0000-0000-0000-000000000004','f2000000-0000-0000-0000-000000000034','INV-DDG-2026-001',64000,64000,'EUR','EUR','approved','matched','2026-04-23','2026-04-24','demo'),
  ('de000000-0000-0000-0000-000000000005','da000000-0000-0000-0000-000000000005','f2000000-0000-0000-0000-000000000038','INV-MCK-2026-001',180000,180000,'EUR','EUR','approved','matched','2026-05-02','2026-05-03','demo'),
  ('de000000-0000-0000-0000-000000000006','da000000-0000-0000-0000-000000000006','f2000000-0000-0000-0000-000000000017','INV-ATL-2026-001',56000,56000,'EUR','EUR','approved','matched','2026-04-29','2026-04-30','demo'),
  ('de000000-0000-0000-0000-000000000007','da000000-0000-0000-0000-000000000007','f1000000-0000-0000-0000-000000000008','INV-SFD-2026-001',78000,78000,'EUR','EUR','approved','matched','2026-05-05','2026-05-06','demo'),
  ('de000000-0000-0000-0000-000000000008','da000000-0000-0000-0000-000000000008','f1000000-0000-0000-0000-000000000010','INV-WDY-2026-001',72000,72000,'EUR','EUR','approved','matched','2026-05-08','2026-05-09','demo'),
  ('de000000-0000-0000-0000-000000000009','da000000-0000-0000-0000-000000000009','f1000000-0000-0000-0000-000000000004','INV-AWS-2026-Q2',105000,105000,'EUR','EUR','approved','matched','2026-05-02','2026-05-03','demo'),
  ('de000000-0000-0000-0000-000000000010','da000000-0000-0000-0000-000000000010','f1000000-0000-0000-0000-000000000006','INV-AZ-2026-Q2',77500,77500,'EUR','EUR','approved','matched','2026-05-02','2026-05-03','demo'),
  ('de000000-0000-0000-0000-000000000011','da000000-0000-0000-0000-000000000011','d5000000-0000-0000-0000-000000000001','INV-SNW-2026-Q2',37500,37500,'EUR','EUR','approved','matched','2026-05-02','2026-05-03','demo'),
  ('de000000-0000-0000-0000-000000000012','da000000-0000-0000-0000-000000000012','f1000000-0000-0000-0000-000000000003','INV-APL-2026-001',95000,95000,'EUR','EUR','approved','matched','2026-04-02','2026-04-03','demo'),
  ('de000000-0000-0000-0000-000000000013','da000000-0000-0000-0000-000000000013','f1000000-0000-0000-0000-000000000001','INV-DEL-2026-001',60000,60000,'EUR','EUR','approved','matched','2026-04-06','2026-04-07','demo'),
  ('de000000-0000-0000-0000-000000000014','da000000-0000-0000-0000-000000000014','f1000000-0000-0000-0000-000000000013','INV-ACN-2026-001',120000,120000,'EUR','EUR','approved','matched','2026-05-01','2026-05-02','demo'),
  ('de000000-0000-0000-0000-000000000015','da000000-0000-0000-0000-000000000015','f2000000-0000-0000-0000-000000000036','INV-DTT-2026-001',42500,42500,'EUR','EUR','approved','matched','2026-05-16','2026-05-17','demo'),
  ('de000000-0000-0000-0000-000000000016','da000000-0000-0000-0000-000000000016','d5000000-0000-0000-0000-000000000010','INV-GAD-2026-Q2',45000,45000,'EUR','EUR','approved','matched','2026-05-02','2026-05-03','demo'),
  ('de000000-0000-0000-0000-000000000017','da000000-0000-0000-0000-000000000017','f2000000-0000-0000-0000-000000000016','INV-HUB-2026-001',34000,34000,'EUR','EUR','approved','matched','2026-04-21','2026-04-22','demo'),
  ('de000000-0000-0000-0000-000000000018','da000000-0000-0000-0000-000000000018','f2000000-0000-0000-0000-000000000015','INV-SNW-2026-001',98000,98000,'EUR','EUR','approved','matched','2026-05-13','2026-05-14','demo')
on conflict (id) do update set
  po_id=excluded.po_id, supplier_id=excluded.supplier_id, invoice_number=excluded.invoice_number,
  amount_eur=excluded.amount_eur, raw_amount=excluded.raw_amount, raw_currency=excluded.raw_currency,
  currency=excluded.currency, status=excluded.status, match_result=excluded.match_result,
  received_at=excluded.received_at, matched_at=excluded.matched_at, source='demo';

-- 3d. DERIVED budget_positions — spent = EXACT sum of demo invoices rolling into
--     each (branch, cost_center, category, period). Computed, NOT hand-keyed.
--     Demo rows carry cost_center_id (existing rows leave it NULL) → no collision.
--     period = '2026-Q2' for the whole wired set. budget/committed set to give a
--     healthy-but-meaningful headroom; available is GENERATED (not inserted).
--     Idempotent: delete demo budget rows then re-derive in one pass.
delete from budget_positions where source='demo';

insert into budget_positions (id, branch_id, cost_center_id, category, period,
                              budget, committed, spent, source)
select
  ('db000000-0000-0000-0000-0000000000'||lpad((row_number() over (order by cost_center_id, category))::text,2,'0'))::uuid,
  po.branch_id, po.cost_center_id, po.category::text::contract_category, '2026-Q2',
  -- budget: round the spend up to a clean headroom figure (spend ≈ 60-80% used)
  (ceil(sum(inv.amount_eur) * 1.6 / 10000) * 10000),
  round(sum(inv.amount_eur) * 0.25, 2),     -- committed: open commitments ~25%
  sum(inv.amount_eur),                        -- SPENT = exact invoice rollup
  'demo'
from invoices inv
join purchase_orders po on po.id = inv.po_id
where inv.source='demo' and po.source='demo'
group by po.branch_id, po.cost_center_id, po.category;

commit;
