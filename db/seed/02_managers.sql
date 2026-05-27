-- TrueSpend Simulation Seed — Users (procurement team)
-- 5 procurement managers + 1 CFO + sample requesters
-- seed_02 now inserts into users table (unified model)

insert into users (id, name, email, role, branch_ids, spend_authority, spend_authority_by_category) values

  -- CFO — full budget visibility, pool draw authority
  (
    'e1000000-0000-0000-0000-000000000000',
    'Klaus Weber',
    'klaus.weber@company.com',
    'cfo',
    array[
      'b1000000-0000-0000-0000-000000000001'::uuid  -- Global HQ
    ],
    99999999.00,
    null
  ),

  -- Head of Procurement — full authority across DACH, UK, HQ
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
    500000.00,
    '{"hardware": 500000, "saas_license": 500000, "hyperscaler": 500000}'::jsonb
  ),

  -- Category Manager — Southern Europe
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
    250000.00,
    '{"saas_license": 100000, "hardware": 250000}'::jsonb
  ),

  -- Category Manager — DACH, Benelux, CEE
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
    250000.00,
    '{"saas_license": 100000, "hardware": 250000, "ai_consumption": 50000}'::jsonb
  ),

  -- Category Manager — Nordics
  (
    'e1000000-0000-0000-0000-000000000004',
    'Erik Lindqvist',
    'erik.lindqvist@company.com',
    'category_manager',
    array[
      'b1000000-0000-0000-0000-000000000006'::uuid,  -- Nordics
      'b1000000-0000-0000-0000-000000000010'::uuid   -- Nordics East
    ],
    200000.00,
    null
  ),

  -- Ops Manager — all branches, routine approvals
  (
    'e1000000-0000-0000-0000-000000000005',
    'Priya Nair',
    'priya.nair@company.com',
    'ops_manager',
    array[
      'b1000000-0000-0000-0000-000000000001'::uuid,
      'b1000000-0000-0000-0000-000000000002'::uuid,
      'b1000000-0000-0000-0000-000000000003'::uuid,
      'b1000000-0000-0000-0000-000000000004'::uuid,
      'b1000000-0000-0000-0000-000000000005'::uuid,
      'b1000000-0000-0000-0000-000000000006'::uuid,
      'b1000000-0000-0000-0000-000000000007'::uuid,
      'b1000000-0000-0000-0000-000000000008'::uuid,
      'b1000000-0000-0000-0000-000000000009'::uuid,
      'b1000000-0000-0000-0000-000000000010'::uuid
    ],
    100000.00,
    null
  ),

  -- IT Manager — DACH, license and asset authority
  (
    'e1000000-0000-0000-0000-000000000006',
    'Thomas Müller',
    'thomas.mueller@company.com',
    'it_manager',
    array[
      'b1000000-0000-0000-0000-000000000002'::uuid   -- DACH
    ],
    50000.00,
    '{"saas_license": 50000, "ai_consumption": 25000, "hardware": 50000}'::jsonb
  ),

  -- Sample requester — DACH Sales
  (
    'e1000000-0000-0000-0000-000000000007',
    'Jana Schmidt',
    'jana.schmidt@company.com',
    'requester',
    array[
      'b1000000-0000-0000-0000-000000000002'::uuid
    ],
    0.00,
    null
  );
