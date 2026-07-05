-- migrate:up
-- =============================================================================
-- 000017_open_tickets_board_actionable_only.sql
--
-- Stop the Ops Board API from shipping un-renderable rows.
--
-- The `open_tickets_board` view (db/schema.sql:1200) drives the React
-- Operations Board (intake/src/App.jsx). Its WHERE clause admitted SIX
-- statuses: 'open', 'pending_confirm', 'pending_review', 'signature_required',
-- 'escalated', 'approved'. But the board can only RENDER four — the
-- BOARD_SECTIONS set: signature_required, pending_review, escalated,
-- pending_confirm. 'open' (intake not yet dispositioned) and 'approved'
-- (terminal — PO created, no human action left) have NO section.
--
-- The React board COUNTS every row the view returns (tickets.length,
-- StatsStrip, sidebar badge) but only renders rows whose status is in a
-- section. Live, the view returns 49 'approved' rows plus one each of the four
-- actionable statuses; a branch-scoped 'approved' ticket produced the
-- "1 item need you / Across 0 sections" blank-board symptom.
--
-- A UI-side filter (App.jsx BOARD_STATUSES, ~line 181/1262) already fixes the
-- rendering. This migration fixes it at the source so the API stops emitting
-- rows no consumer can act on. Three consumers, all satisfied by the narrowed
-- set:
--   1. The board list — needs exactly the 4 actionable statuses.
--   2. SigningModal (App.jsx:1072) — single-ticket fetch by id from this view,
--      only ever a 'signature_required' ticket. Still present. ✓
--   3. Ask assistant (chat_assistant.json, I-9) — see dependency below. ✓
--
-- ── I-9 DEPENDENCY — do the workflow re-import together with this migration ──
-- The Ask assistant previously used THIS view as its SOLE order-status source.
-- Narrowing the view alone would blind it to 'approved'/'open' orders → it would
-- answer "I don't have that in TrueSpend" for approved-order questions (a recall
-- regression; ADR-005 specs order_status = tickets + open_tickets_board +
-- purchase_orders + commitment_register). SO, in the SAME commit, the assistant's
-- "Fetch Open Tickets" node was repointed OFF this view onto
--   /tickets?...&status=in.(signature_required,pending_review,escalated,
--            pending_confirm,approved,auto_executed)
-- (spec-aligned; actually WIDER recall than before). That workflow must be
-- re-imported + reactivated in n8n for the assistant to keep approved-order
-- recall once this view is narrowed. Applying this migration WITHOUT the
-- re-import live degrades the assistant until the workflow is updated.
--
-- 'open' is dropped: intake tickets in 'open' are pre-disposition and belong to
-- no board section. 'approved' is dropped: terminal, no action. Delivery
-- follow-up already lives under 'pending_confirm' (kept). No new/in-flight
-- lifecycle status needs to appear here beyond the four.
--
-- CREATE OR REPLACE VIEW: keeps existing grants (000011 granted SELECT to
-- truespend_app) and does NOT change the column list/order — the select list
-- below is byte-for-byte the current view; only the WHERE narrows. A DROP+CREATE
-- would drop the grants and 403 the board, so we deliberately use OR REPLACE.
--
-- PostgREST caches the schema; after replacing the view it must reload or it
-- serves the stale definition, so we NOTIFY at the end.
-- =============================================================================

create or replace view open_tickets_board as
select
  t.id,
  t.reference,
  t.source,
  t.status,
  t.title,
  t.description,
  t.review_type,
  t.review_notes,
  t.pdf_url,
  t.amount,
  t.amount_eur,
  t.value_eur,
  t.currency,
  t.jira_key,
  t.po_id,
  po.po_number,
  po.status            as po_status,
  po.expected_delivery as po_expected_delivery,
  (po.expected_delivery is not null and po.expected_delivery < current_date and po.delivered_at is null) as po_delivery_overdue,
  t.created_at,
  t.target_close,
  t.category,
  -- UI scoping fields
  t.branch_id,
  t.cost_center_id,
  t.submitted_by,
  t.submitted_by_email,
  t.confidence         as confidence_score,
  -- Supplier
  s.name               as supplier_name,
  s.health             as supplier_health,
  s.compliance_status  as supplier_compliance,
  -- Branch & cost center names
  b.name               as branch_name,
  cc.code              as cost_center_code,
  cc.name              as cost_center_name,
  -- Owner
  u.name               as owner_name,
  u.email              as owner_email,
  -- Latest decision
  d.disposition,
  d.confidence,
  d.recommendation,
  d.reasoning          as agent_reasoning,
  -- Budget position context
  bp.budget            as bucket_budget,
  bp.committed         as bucket_committed,
  bp.spent             as bucket_spent,
  bp.available         as bucket_available,
  -- Priority sort: signature_required first, then pending_confirm, then others
  case t.status
    when 'signature_required' then 1
    when 'pending_confirm'    then 2
    when 'pending_review'     then 3
    when 'escalated'          then 4
    else 5
  end as sort_priority
from tickets t
left join suppliers s        on s.id   = t.supplier_id
left join branches b         on b.id   = t.branch_id
left join cost_centers cc    on cc.id  = t.cost_center_id
left join users u            on u.id   = t.owner_id
left join decisions d        on d.ticket_id = t.id
left join purchase_orders po on po.id  = t.po_id
left join budget_positions bp
  on  bp.branch_id     = t.branch_id
  and bp.cost_center_id is not distinct from t.cost_center_id
  and bp.category::text = t.category
  and bp.period = (
    extract(year from now())::text || '-Q' ||
    ceil(extract(month from now()) / 3.0)::text
  )
where t.status in (
  'pending_confirm', 'pending_review',
  'signature_required', 'escalated'
)
order by sort_priority, t.created_at asc;

-- PostgREST: pick up the replaced view definition.
notify pgrst, 'reload schema';

-- migrate:down
-- Restore the original view: the same select list with the WIDER 6-status
-- WHERE ('open' + 'approved' re-admitted). CREATE OR REPLACE keeps grants.
create or replace view open_tickets_board as
select
  t.id,
  t.reference,
  t.source,
  t.status,
  t.title,
  t.description,
  t.review_type,
  t.review_notes,
  t.pdf_url,
  t.amount,
  t.amount_eur,
  t.value_eur,
  t.currency,
  t.jira_key,
  t.po_id,
  po.po_number,
  po.status            as po_status,
  po.expected_delivery as po_expected_delivery,
  (po.expected_delivery is not null and po.expected_delivery < current_date and po.delivered_at is null) as po_delivery_overdue,
  t.created_at,
  t.target_close,
  t.category,
  -- UI scoping fields
  t.branch_id,
  t.cost_center_id,
  t.submitted_by,
  t.submitted_by_email,
  t.confidence         as confidence_score,
  -- Supplier
  s.name               as supplier_name,
  s.health             as supplier_health,
  s.compliance_status  as supplier_compliance,
  -- Branch & cost center names
  b.name               as branch_name,
  cc.code              as cost_center_code,
  cc.name              as cost_center_name,
  -- Owner
  u.name               as owner_name,
  u.email              as owner_email,
  -- Latest decision
  d.disposition,
  d.confidence,
  d.recommendation,
  d.reasoning          as agent_reasoning,
  -- Budget position context
  bp.budget            as bucket_budget,
  bp.committed         as bucket_committed,
  bp.spent             as bucket_spent,
  bp.available         as bucket_available,
  -- Priority sort: signature_required first, then pending_confirm, then others
  case t.status
    when 'signature_required' then 1
    when 'pending_confirm'    then 2
    when 'pending_review'     then 3
    when 'escalated'          then 4
    else 5
  end as sort_priority
from tickets t
left join suppliers s        on s.id   = t.supplier_id
left join branches b         on b.id   = t.branch_id
left join cost_centers cc    on cc.id  = t.cost_center_id
left join users u            on u.id   = t.owner_id
left join decisions d        on d.ticket_id = t.id
left join purchase_orders po on po.id  = t.po_id
left join budget_positions bp
  on  bp.branch_id     = t.branch_id
  and bp.cost_center_id is not distinct from t.cost_center_id
  and bp.category::text = t.category
  and bp.period = (
    extract(year from now())::text || '-Q' ||
    ceil(extract(month from now()) / 3.0)::text
  )
where t.status in (
  'open', 'pending_confirm', 'pending_review',
  'signature_required', 'escalated', 'approved'
)
order by sort_priority, t.created_at asc;

notify pgrst, 'reload schema';
