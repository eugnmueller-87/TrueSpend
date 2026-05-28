-- Seed 02 fix — upsert users (ON CONFLICT on existing data)
INSERT INTO users (id, name, email, role, branch_ids, spend_authority, spend_authority_by_category)
VALUES
  (
    'e1000000-0000-0000-0000-000000000000',
    'Klaus Weber',
    'klaus.weber@company.com',
    'cfo',
    ARRAY['b1000000-0000-0000-0000-000000000001'::uuid],
    99999999.00,
    NULL
  ),
  (
    'e1000000-0000-0000-0000-000000000001',
    'Sarah Brennan',
    'sarah.brennan@company.com',
    'head_of_procurement',
    ARRAY[
      'b1000000-0000-0000-0000-000000000001'::uuid,
      'b1000000-0000-0000-0000-000000000002'::uuid,
      'b1000000-0000-0000-0000-000000000003'::uuid
    ],
    500000.00,
    '{"hardware": 500000, "saas_license": 500000, "hyperscaler": 500000}'::jsonb
  ),
  (
    'e1000000-0000-0000-0000-000000000002',
    'Marc Dupont',
    'marc.dupont@company.com',
    'category_manager',
    ARRAY[
      'b1000000-0000-0000-0000-000000000005'::uuid,
      'b1000000-0000-0000-0000-000000000007'::uuid,
      'b1000000-0000-0000-0000-000000000008'::uuid
    ],
    250000.00,
    '{"saas_license": 100000, "hardware": 250000}'::jsonb
  ),
  (
    'e1000000-0000-0000-0000-000000000003',
    'Lena Hoffmann',
    'lena.hoffmann@company.com',
    'category_manager',
    ARRAY[
      'b1000000-0000-0000-0000-000000000002'::uuid,
      'b1000000-0000-0000-0000-000000000004'::uuid,
      'b1000000-0000-0000-0000-000000000009'::uuid
    ],
    250000.00,
    '{"saas_license": 100000, "hardware": 250000, "ai_consumption": 50000}'::jsonb
  ),
  (
    'e1000000-0000-0000-0000-000000000004',
    'Erik Lindqvist',
    'erik.lindqvist@company.com',
    'category_manager',
    ARRAY[
      'b1000000-0000-0000-0000-000000000006'::uuid,
      'b1000000-0000-0000-0000-000000000010'::uuid
    ],
    200000.00,
    NULL
  ),
  (
    'e1000000-0000-0000-0000-000000000005',
    'Priya Nair',
    'priya.nair@company.com',
    'ops_manager',
    ARRAY[
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
    NULL
  ),
  (
    'e1000000-0000-0000-0000-000000000006',
    'Thomas Mueller',
    'thomas.mueller@company.com',
    'it_manager',
    ARRAY['b1000000-0000-0000-0000-000000000002'::uuid],
    50000.00,
    '{"saas_license": 50000, "ai_consumption": 25000, "hardware": 50000}'::jsonb
  ),
  (
    'e1000000-0000-0000-0000-000000000007',
    'Jana Schmidt',
    'jana.schmidt@company.com',
    'requester',
    ARRAY['b1000000-0000-0000-0000-000000000002'::uuid],
    0.00,
    NULL
  )
ON CONFLICT (id) DO UPDATE SET
  branch_ids                  = EXCLUDED.branch_ids,
  spend_authority_by_category = EXCLUDED.spend_authority_by_category,
  updated_at                  = now();

SELECT 'users seeded: ' || count(*) AS status FROM users;
