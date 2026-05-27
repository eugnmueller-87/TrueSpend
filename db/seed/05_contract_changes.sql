-- TrueSpend Simulation Seed — Contract Changes
-- Pre-populated agent assessments showing what the reasoning looks like
-- These are the cases that need one-touch confirm or escalation

insert into contract_changes (
  id, contract_id, change_type,
  previous_value, proposed_value, delta_pct, delta_eur,
  market_rate_pct, agent_assessment, recommended_position, walk_away_value
) values

  -- Apple UK — 9% price increase
  ('cc000001-0000-0000-0000-000000000001',
   'c1000000-0000-0000-0000-000000000006', 'price_increase',
   '£4,200,000', '£4,578,000', 9.00, 378000.00,
   4.20,
   'Apple is proposing 9% increase vs market average of 4.2% for hardware. Our consumption is flat YoY — no volume justification for above-market increase. Apple device backlog (1 open dispute) weakens their negotiating position. We have partial Microsoft Surface alternative available for non-design roles (approx 30% of fleet).',
   'Counter at 4% (market rate). Anchor on 3-year commitment in exchange for rate lock. If Apple holds above 6%, escalate to procurement head. Walk-away: 7% with partial fleet migration to Surface for non-creative roles.',
   '7% (£4,494,000 — beyond this, initiate partial Surface migration)'),

  -- Salesforce France — 12% price increase
  ('cc000001-0000-0000-0000-000000000002',
   'c1000000-0000-0000-0000-000000000007', 'price_increase',
   '€1,800,000', '€2,016,000', 12.00, 216000.00,
   5.50,
   'Salesforce proposing 12% — well above market (5.5% SaaS average 2026). Seat utilization is 94% (282 of 300 active) — strong utilization argues against discounting but also shows dependency. French sales team has rejected HubSpot evaluation twice — switching cost is high. However, at 12% this sets a dangerous precedent for 2027.',
   'Counter at 5%. Offer 2-year commit in exchange for rate lock at 5% for both years. Request consumption credit for Q1 downtime incident (3 days, Feb 2026). Walk-away: 8% — beyond this escalate to VP Sales for joint negotiation with Salesforce AE.',
   '8% (€1,944,000 — beyond this requires VP Sales involvement)'),

  -- SAP Global — 7% price increase
  ('cc000001-0000-0000-0000-000000000003',
   'c1000000-0000-0000-0000-000000000008', 'price_increase',
   '€6,400,000', '€6,848,000', 7.00, 448000.00,
   3.80,
   'SAP proposing 7% citing CPI and R&D investment. Market average for ERP renewals is 3.8%. Switching cost for S/4HANA is extremely high — full migration estimated at €8-12M. SAP knows this. However, we have 3 open P2 support tickets unresolved for 45+ days, which is a contractual SLA breach on their part — this is leverage. Also: SAP is pushing RISE with SAP cloud migration; they have commercial incentive to keep us happy.',
   'Counter at 3.5%. Lead with SLA breach as opening position — request credit of €180k for support failures before discussing price. If SAP holds at 7%, escalate: this is a €448k annual impact and warrants CFO-level conversation. Do not accept above 5% without sign-off.',
   '5% (€6,720,000 — above this requires CFO sign-off)'),

  -- Vodafone Italy — 15% price increase + SLA breach
  ('cc000001-0000-0000-0000-000000000004',
   'c1000000-0000-0000-0000-000000000009', 'price_increase',
   '€290,000', '€333,500', 15.00, 43500.00,
   4.00,
   'ESCALATE — DO NOT AUTO-PROCESS. Vodafone Italy proposing 15% increase while currently in active SLA breach (February outage, formal dispute open). Accepting any increase while a breach is unresolved sets a damaging precedent. Contract expires in 18 days — time pressure is real but must not drive a bad decision. Alternatives: TIM Business (quoted €260k for equivalent), Fastweb (€275k). Switching has 30-day lead time — we are at risk of a gap.',
   'Do not negotiate on price until breach is formally resolved with credit applied. Parallel-track: get TIM Business contract ready to sign as backstop. If Vodafone will not resolve breach first, terminate and activate TIM. Escalate to Country Director Italy + Head of Procurement immediately.',
   'Any increase — reject all increases until breach credit is applied. Terminate if no resolution within 5 days.'),

  -- Zoom Benelux — 8% price increase
  ('cc000001-0000-0000-0000-000000000005',
   'c1000000-0000-0000-0000-000000000010', 'price_increase',
   '€180,000', '€194,400', 8.00, 14400.00,
   5.00,
   'Zoom proposing 8% vs market 5%. Seat utilization is 78% (281 of 360 active) — 79 unused seats is a negotiating point. Microsoft Teams is included in existing M365 license for Benelux — partial migration is viable for low-usage cohort. This gives meaningful leverage.',
   'Counter at 0% — anchor on underutilization (79 seats unused) and Teams as a credible alternative. Offer to reduce to 300 seats (remove 60 unused) at current per-seat rate as a compromise. Net saving vs proposed: €34k annually. Walk-away: 5% with seat reduction.',
   '5% with seat count reduced to 300 (€189k total — acceptable)'),

  -- Lenovo DACH — volume increase (200 devices, tier change)
  ('cc000001-0000-0000-0000-000000000006',
   'c1000000-0000-0000-0000-000000000011', 'volume_change',
   '1,600 devices @ €5,125/device', '1,800 devices — triggers 1,800+ tier', 12.50, 1025000.00,
   NULL,
   'Engineering requesting 200 additional ThinkPads. Adding these pushes the full contract from the 1,400-1,799 device tier into the 1,800+ tier — which REPRICES THE ENTIRE CONTRACT at €4,890/device (€235 less per device). Net effect: 1,800 × €4,890 = €8,802,000 vs current 1,600 × €5,125 = €8,200,000. Additional cost for 200 devices is only €602,000 not €1,025,000. However: check utilization first. Current asset register shows 143 devices in DACH marked inactive or in IT refresh queue. Recommend: reclaim 143 before ordering.',
   'Reclaim 143 inactive devices from IT refresh queue. Order 57 new devices to net 200 additional. New total: 1,657 — stays in current pricing tier. No tier repricing. Cost: 57 × €5,125 = €292,125 vs €1,025,000 for full order. Saving: €732,875.',
   'N/A — recommend internal reallocation first'),

  -- Microsoft 365 UK — volume increase (300 seats, renegotiation clause)
  ('cc000001-0000-0000-0000-000000000007',
   'c1000000-0000-0000-0000-000000000012', 'volume_change',
   '700 seats E5 @ £2,000/seat', '1,000 seats — triggers renegotiation clause', 42.86, 600000.00,
   NULL,
   'HR requesting 300 additional E5 seats for Q3 new hires. Contract has a renegotiation clause at 1,000 seats — Microsoft can reprice the full contract. Current rate is below-market for E5 (market: £2,200-2,400). Microsoft will likely attempt to use this clause to bring pricing to market rate. Risk: full repricing at £2,200 on 1,000 seats = £2,200,000 vs current trajectory of £1,400,000 + 300 × £2,000 = £2,000,000. Delta: £200,000 additional risk.',
   'Do not breach 1,000 seat threshold without negotiating the renegotiation clause waiver first. Approach Microsoft with: we will commit to 1,000 seats for 2 years if you waive the renegotiation clause and hold at £2,000/seat. Alternatively, split: add 299 seats now (stays below threshold), cover remaining 1 seat via different license type. Escalate to Sarah Brennan — this is a strategic negotiation.',
   '1,000 seats at £2,000 locked (£2,000,000) — reject any attempt to use clause to reprice'),

  -- Accenture — scope change (40% increase)
  ('cc000001-0000-0000-0000-000000000008',
   'c1000000-0000-0000-0000-000000000017', 'scope_change',
   '3 workstreams @ €3,600,000', '5 workstreams — Accenture proposal', 40.00, 1440000.00,
   NULL,
   'ESCALATE. Accenture proposing 2 additional workstreams at SOW renewal — 40% scope increase (€1.44M additional). Current SOW has 2 open scope creep flags. Adding workstreams without resolving current delivery quality is high risk. The 2 proposed workstreams (AI integration + data platform) overlap with capabilities we are building internally and with work quoted by KPMG at 30% lower rate. Accenture has commercial interest in expanding — this is not necessarily in our interest.',
   'Do not renew with expanded scope until: (1) current 2 scope creep issues are formally resolved with Accenture sign-off, (2) competitive quote obtained for the 2 new workstreams from at least 2 alternatives, (3) internal capability assessment completed. Renew existing 3-workstream SOW at current value only. Negotiate 6-month extension if needed to run competitive process for new workstreams.',
   'Existing scope only (€3,600,000) — no expansion without competitive process');
