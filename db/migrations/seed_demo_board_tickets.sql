-- =============================================================================
-- seed_demo_board_tickets.sql   ── DEMO SAFETY NET, not part of the live path ──
--
-- Inserts a handful of tickets in ACTIONABLE states so the Operations board and
-- the approve / sign / escalate flow demo cleanly, independent of the live
-- intake auto-execute path (which has known routing/approve-branch bugs — see
-- CLAUDE.md). These are hand-seeded board rows, NOT produced by the agent.
--
-- One per actionable board state (open_tickets_board shows: signature_required,
-- pending_confirm, pending_review, escalated).
--
-- NOTE: tickets.source is the ticket_source ENUM (automatic/intake/renewal/
-- monitoring) — NOT a free-text tag — so these use source='intake'. The demo
-- wipe key is the reference prefix instead.
--
-- Idempotent: fixed UUIDs + ON CONFLICT DO UPDATE.
-- Wipeable:   delete from tickets where reference like 'TS-2026-DEMO%';
-- =============================================================================

begin;

insert into tickets
  (id, reference, source, status, title, description,
   branch_id, supplier_id, supplier_name, category, ticket_type,
   submitted_by, submitted_by_email, requested_by,
   amount, value_eur, currency, recommendation, brief, confidence,
   review_type, disposition)
values
  -- 1) SIGNATURE REQUIRED — sorts first on the board (sign & send)
  ('d7000000-0000-0000-0000-000000000001','TS-2026-DEMO1','intake','signature_required',
   'Salesforce Sales Cloud — 40 seat expansion (DACH)',
   'Renewal + 40 seats for the DACH sales org. Contract package prepared, awaiting signature.',
   'b1000000-0000-0000-0000-000000000002','f1000000-0000-0000-0000-000000000008','Salesforce',
   'saas_license','purchase','Lena Hoffmann','lena.hoffmann@truespend.com','lena.hoffmann@truespend.com',
   96000,96000,'EUR',
   'Approved terms within budget — package ready for signature.',
   'Renewal at list with 40 added seats; pricing benchmarked OK.',0.93,
   'signature','one_touch'),

  -- 2) PENDING CONFIRM — quick one-touch confirm
  ('d7000000-0000-0000-0000-000000000002','TS-2026-DEMO2','intake','pending_confirm',
   'Workday HCM — annual renewal (Global HQ)',
   'Standard annual HCM renewal, clean terms, within budget. One-touch confirm.',
   'b1000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000010','Workday',
   'saas_license','purchase','Demo Requester','demo.hq@truespend.com','demo.hq@truespend.com',
   72000,72000,'EUR',
   'All five signals green — safe to confirm.',
   'Clean renewal, no price increase, budget available.',0.97,
   null,'one_touch'),

  -- 3) PENDING REVIEW — one signal uncertain, human decides
  ('d7000000-0000-0000-0000-000000000003','TS-2026-DEMO3','intake','pending_review',
   'Dell workstation refresh — 25 units (DACH Engineering)',
   'Hardware refresh for the Munich engineering team. Supplier lead-time uncertain.',
   'b1000000-0000-0000-0000-000000000002','f1000000-0000-0000-0000-000000000001','Dell Technologies',
   'hardware','purchase','Demo Requester','demo.dach@truespend.com','demo.dach@truespend.com',
   62500,62500,'EUR',
   'Recommend approve — verify delivery date against project milestone.',
   'Within budget; one signal (lead time) needs a human check.',0.81,
   'budget_overrun','one_touch'),

  -- 4) ESCALATED — crosses €100k threshold
  ('d7000000-0000-0000-0000-000000000004','TS-2026-DEMO4','intake','escalated',
   'Securitas facility services — multi-site contract (Global)',
   'Multi-site security services contract above the €100k escalation threshold.',
   'b1000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000015','Securitas',
   'facilities','purchase','Demo Requester','demo.hq@truespend.com','demo.hq@truespend.com',
   180000,180000,'EUR',
   'Escalate — exceeds €100k; supplier compliance flagged amber.',
   'Above auto threshold and supplier health is watch — needs senior review.',0.74,
   'major_contract','escalate')

on conflict (id) do update set
  reference=excluded.reference, source=excluded.source, status=excluded.status,
  title=excluded.title, description=excluded.description, branch_id=excluded.branch_id,
  supplier_id=excluded.supplier_id, supplier_name=excluded.supplier_name,
  category=excluded.category, ticket_type=excluded.ticket_type,
  submitted_by=excluded.submitted_by, submitted_by_email=excluded.submitted_by_email,
  requested_by=excluded.requested_by, amount=excluded.amount, value_eur=excluded.value_eur,
  currency=excluded.currency, recommendation=excluded.recommendation, brief=excluded.brief,
  confidence=excluded.confidence, review_type=excluded.review_type, disposition=excluded.disposition,
  updated_at=now();

commit;
