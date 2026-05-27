-- TrueSpend Simulation Seed â€” 5 Procurement Managers
-- 5 people managing the entire procurement load across 10 branches
-- Each has a spend authority threshold â€” agent auto-executes below this

insert into managers (id, name, email, role, branches, spend_authority) values
  (
    'e1000000-0000-0000-0000-000000000001',
    'Sarah Brennan',
    'sarah.brennan@company.com',
    'head_of_procurement',
    array[
      'b1000000-0000-0000-0000-000000000001'::uuid,  -- Global HQ
      'b1000000-0000-0000-0000-000000000002'::uuid,  -- DACH
      'b1000000-0000-0000-0000-000000000003'::uuid   -- UK & Ireland
    ],
    500000.00  -- can auto-approve up to â‚¬500k
  ),
  (
    'e1000000-0000-0000-0000-000000000002',
    'Marc Dupont',
    'marc.dupont@company.com',
    'category_manager',
    array[
      'b1000000-0000-0000-0000-000000000005'::uuid,  -- France
      'b1000000-0000-0000-0000-000000000007'::uuid,  -- Iberia
      'b1000000-0000-0000-0000-000000000008'::uuid   -- Italy
    ],
    250000.00
  ),
  (
    'e1000000-0000-0000-0000-000000000003',
    'Lena Hoffmann',
    'lena.hoffmann@company.com',
    'category_manager',
    array[
      'b1000000-0000-0000-0000-000000000002'::uuid,  -- DACH
      'b1000000-0000-0000-0000-000000000004'::uuid,  -- Benelux
      'b1000000-0000-0000-0000-000000000009'::uuid   -- CEE
    ],
    250000.00
  ),
  (
    'e1000000-0000-0000-0000-000000000004',
    'Erik Lindqvist',
    'erik.lindqvist@company.com',
    'category_manager',
    array[
      'b1000000-0000-0000-0000-000000000006'::uuid,  -- Nordics
      'b1000000-0000-0000-0000-000000000010'::uuid   -- Nordics East
    ],
    200000.00
  ),
  (
    'e1000000-0000-0000-0000-000000000005',
    'Priya Nair',
    'priya.nair@company.com',
    'ops_manager',
    array[
      'b1000000-0000-0000-0000-000000000001'::uuid,  -- Global HQ (ops)
      'b1000000-0000-0000-0000-000000000002'::uuid,  -- DACH
      'b1000000-0000-0000-0000-000000000003'::uuid,  -- UK & Ireland
      'b1000000-0000-0000-0000-000000000004'::uuid,  -- Benelux
      'b1000000-0000-0000-0000-000000000005'::uuid,  -- France
      'b1000000-0000-0000-0000-000000000006'::uuid,  -- Nordics
      'b1000000-0000-0000-0000-000000000007'::uuid,  -- Iberia
      'b1000000-0000-0000-0000-000000000008'::uuid,  -- Italy
      'b1000000-0000-0000-0000-000000000009'::uuid,  -- CEE
      'b1000000-0000-0000-0000-000000000010'::uuid   -- Nordics East
    ],
    100000.00  -- ops handles routine approvals across all branches
  );
