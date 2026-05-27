-- TrueSpend Simulation Seed â€” Suppliers
-- Mix of strategic (big spend), operational, and tail spend vendors

insert into suppliers (id, name, legal_name, country, category, health, sla_status, open_disputes, last_contact, gdpr_dpa_signed) values

  -- Hardware
  ('f1000000-0000-0000-0000-000000000001', 'Dell Technologies',  'Dell Technologies Inc.',           'USA',         'hardware',      'green', 'On track â€” 97% on-time delivery L90D',  0, '2026-03-15', true),
  ('f1000000-0000-0000-0000-000000000002', 'Lenovo',             'Lenovo (Germany) GmbH',            'Germany',     'hardware',      'green', 'On track â€” 95% on-time delivery L90D',  0, '2026-02-20', true),
  ('f1000000-0000-0000-0000-000000000003', 'Apple',              'Apple Distribution International', 'Ireland',     'hardware',      'watch', '1 delay flagged â€” MacBook Pro backlog', 1, '2026-04-01', true),

  -- Hyperscalers
  ('f1000000-0000-0000-0000-000000000004', 'AWS',                'Amazon Web Services EMEA SARL',    'Luxembourg',  'hyperscaler',   'green', 'EDP utilization 71% â€” within range',    0, '2026-04-10', true),
  ('f1000000-0000-0000-0000-000000000005', 'Google Cloud',       'Google Cloud EMEA Ltd.',           'Ireland',     'hyperscaler',   'green', 'CUD utilization 94% â€” healthy',         0, '2026-03-22', true),
  ('f1000000-0000-0000-0000-000000000006', 'Microsoft Azure',    'Microsoft Ireland Operations Ltd', 'Ireland',     'hyperscaler',   'watch', 'Reservation utilization 67% â€” low',     0, '2026-04-05', true),

  -- SaaS
  ('f1000000-0000-0000-0000-000000000007', 'Microsoft 365',      'Microsoft Ireland Operations Ltd', 'Ireland',     'saas_license',  'green', 'No issues â€” auto-billing stable',       0, '2026-01-10', true),
  ('f1000000-0000-0000-0000-000000000008', 'Salesforce',         'Salesforce Germany GmbH',          'Germany',     'saas_license',  'green', 'No issues â€” 98% uptime L30D',           0, '2026-02-14', true),
  ('f1000000-0000-0000-0000-000000000009', 'SAP',                'SAP SE',                           'Germany',     'saas_license',  'watch', 'Support ticket backlog â€” 3 open P2s',   1, '2026-04-18', true),
  ('f1000000-0000-0000-0000-000000000010', 'Workday',            'Workday Limited',                  'Ireland',     'saas_license',  'green', 'No issues',                             0, '2026-03-01', true),
  ('f1000000-0000-0000-0000-000000000011', 'Slack',              'Slack Technologies Ltd.',          'Ireland',     'saas_license',  'green', 'No issues',                             0, '2026-01-20', true),
  ('f1000000-0000-0000-0000-000000000012', 'Zoom',               'Zoom Video Communications Inc.',   'USA',         'saas_license',  'green', 'No issues',                             0, '2025-12-01', true),

  -- Services
  ('f1000000-0000-0000-0000-000000000013', 'Accenture',          'Accenture GmbH',                   'Germany',     'services',      'watch', 'Scope creep flagged on 2 projects',     2, '2026-04-22', true),
  ('f1000000-0000-0000-0000-000000000014', 'KPMG',               'KPMG AG',                          'Germany',     'services',      'green', 'Audit engagement on track',             0, '2026-03-10', true),
  ('f1000000-0000-0000-0000-000000000015', 'Securitas',          'Securitas Deutschland GmbH',       'Germany',     'facilities',    'green', 'No issues â€” SLA 99.1%',                 0, '2026-02-28', true),

  -- Telecoms
  ('f1000000-0000-0000-0000-000000000016', 'Deutsche Telekom',   'Deutsche Telekom AG',              'Germany',     'telecoms',      'green', 'Connectivity SLA 99.8%',                0, '2026-01-15', true),
  ('f1000000-0000-0000-0000-000000000017', 'Vodafone',           'Vodafone GmbH',                    'Germany',     'telecoms',      'red',   'Outage incident Feb â€” SLA breach',       1, '2026-04-25', true);
