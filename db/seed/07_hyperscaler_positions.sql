-- TrueSpend Simulation Seed â€” Hyperscaler Positions
-- Daily snapshot for May 2026 â€” shows the monitoring layer in action

insert into hyperscaler_positions (
  branch_id, contract_id, provider, period,
  committed_eur, commitment_type, commitment_end,
  mtd_spend_eur, daily_burn_eur, projected_eur,
  reservation_util, idle_resources_eur,
  overshoot_risk, undershoot_risk,
  snapshot_date
) values

  -- AWS â€” Global HQ â€” EDP tracking (contract c14)
  ('b1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000014', 'AWS', '2026-05',
   1000000.00, 'EDP', '2026-11-26',
   780000.00, 28600.00, 1031600.00,  -- projecting overshoot by â‚¬31.6k
   0.71, 18400.00,
   true, false,
   '2026-05-27'),

  -- GCP â€” DACH â€” CUD tracking (contract c15)
  ('b1000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000015', 'GCP', '2026-05',
   400000.00, 'CUD', '2026-10-26',
   372000.00, 13800.00, 400200.00,  -- on track
   0.94, 4200.00,
   false, false,
   '2026-05-27'),

  -- Azure â€” UK â€” Reservation tracking (contract c16, low utilization)
  ('b1000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000016', 'Azure', '2026-05',
   258333.00, 'Reservation', '2026-12-06',
   172000.00, 6300.00, 220800.00,   -- projecting undershoot, wasting commitment
   0.67, 31000.00,
   false, true,
   '2026-05-27'),

  -- AWS â€” DACH (no dedicated contract â€” ad-hoc usage, no EDP)
  ('b1000000-0000-0000-0000-000000000002', NULL, 'AWS', '2026-05',
   150000.00, 'EDP', '2026-11-26',
   118000.00, 4300.00, 145200.00,
   0.82, 6800.00,
   false, false,
   '2026-05-27'),

  -- Azure â€” France (no dedicated contract)
  ('b1000000-0000-0000-0000-000000000005', NULL, 'Azure', '2026-05',
   80000.00, 'Reservation', '2026-12-06',
   61000.00, 2200.00, 74800.00,
   0.78, 8900.00,
   false, false,
   '2026-05-27');
