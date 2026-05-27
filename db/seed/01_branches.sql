-- TrueSpend Simulation Seed â€” 10 Branches
-- Represents a mid-large enterprise with European + global footprint

insert into branches (id, name, region, country, currency, annual_budget, budget_owner) values
  ('b1000000-0000-0000-0000-000000000001', 'Global HQ',         'GLOBAL_HQ',    'Germany',     'EUR', 25000000.00, 'CFO Office'),
  ('b1000000-0000-0000-0000-000000000002', 'DACH Operations',   'DACH',         'Germany',     'EUR', 18000000.00, 'Regional VP DACH'),
  ('b1000000-0000-0000-0000-000000000003', 'UK & Ireland',      'UK_IE',        'UK',          'GBP',  9500000.00, 'Country Director UK'),
  ('b1000000-0000-0000-0000-000000000004', 'Benelux',           'BENELUX',      'Netherlands', 'EUR',  7200000.00, 'Regional VP Benelux'),
  ('b1000000-0000-0000-0000-000000000005', 'France',            'FRANCE',       'France',      'EUR',  8100000.00, 'Country Director France'),
  ('b1000000-0000-0000-0000-000000000006', 'Nordics',           'NORDICS',      'Sweden',      'SEK',  6400000.00, 'Regional VP Nordics'),
  ('b1000000-0000-0000-0000-000000000007', 'Iberia',            'IBERIA',       'Spain',       'EUR',  4800000.00, 'Country Director Spain'),
  ('b1000000-0000-0000-0000-000000000008', 'Italy',             'ITALY',        'Italy',       'EUR',  5300000.00, 'Country Director Italy'),
  ('b1000000-0000-0000-0000-000000000009', 'CEE',               'CEE',          'Poland',      'PLN',  3900000.00, 'Regional VP CEE'),
  ('b1000000-0000-0000-0000-000000000010', 'Nordics East',      'NORDICS_EAST', 'Finland',     'EUR',  3100000.00, 'Country Director Finland');
