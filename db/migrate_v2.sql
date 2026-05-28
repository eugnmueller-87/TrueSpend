-- =============================================================================
-- TrueSpend — Schema Migration v1 → v2.0
-- Safe: adds missing columns, renames where needed, creates missing views/functions
-- Does NOT drop any existing tables or data.
-- Apply with: psql $DATABASE_URL -f db/migrate_v2.sql
-- =============================================================================

-- =============================================================================
-- CONTRACTS — add missing columns
-- =============================================================================
alter table contracts
  add column if not exists value_eur           numeric(15,2),
  add column if not exists tco_eur             numeric(15,2),
  add column if not exists tco_calculated_at   timestamptz,
  add column if not exists escalation_clause   boolean default false,
  add column if not exists escalation_rate     numeric(5,4),
  add column if not exists lock_in_score       numeric(3,1),
  add column if not exists audit_rights        boolean default false,
  add column if not exists exit_penalty_eur    numeric(15,2);

-- Backfill value_eur from value (assume EUR for existing rows)
update contracts set value_eur = value where value_eur is null;


-- =============================================================================
-- SUPPLIERS — add missing columns
-- =============================================================================
alter table suppliers
  add column if not exists nda_status          doc_status default 'not_required',
  add column if not exists dpa_status          doc_status default 'not_required',
  add column if not exists lksg_compliant      boolean,
  add column if not exists infosec_score       numeric(5,2),
  add column if not exists compliance_status   compliance_status default 'pending',
  add column if not exists onboarding_complete boolean default false,
  add column if not exists processes_personal_data boolean default false,
  add column if not exists data_residency      text,
  add column if not exists iso27001            boolean default false,
  add column if not exists soc2                boolean default false,
  add column if not exists strategic_tier      text default 'standard',
  add column if not exists lock_in_score       numeric(3,1);


-- =============================================================================
-- TICKETS — add missing columns
-- =============================================================================
alter table tickets
  add column if not exists cost_center_id      uuid references cost_centers(id),
  add column if not exists amount_eur          numeric(15,2),
  add column if not exists review_type         text,
  add column if not exists disposition         disposition;

-- Backfill amount_eur from value_eur where present
update tickets set amount_eur = value_eur where amount_eur is null and value_eur is not null;


-- =============================================================================
-- BUDGET POSITIONS — add missing columns
-- =============================================================================
alter table budget_positions
  add column if not exists cost_center_id      uuid references cost_centers(id);

-- Fix available column: if it's not a generated column, make it computed properly
-- (skip if already generated — postgres won't let us alter a generated column)
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_name='budget_positions' and column_name='available'
    and is_generated = 'ALWAYS'
  ) then
    -- Not generated — update it manually for now, migration will keep it in sync
    update budget_positions set available = budget - committed - spent;
  end if;
end $$;


-- =============================================================================
-- BUDGET BUCKETS — rename allocated_eur → planned_amount, add missing columns
-- =============================================================================
alter table budget_buckets
  add column if not exists planned_amount      numeric(15,2),
  add column if not exists currency            text not null default 'EUR',
  add column if not exists set_by_user_id      uuid references users(id),
  add column if not exists set_at              timestamptz default now(),
  add column if not exists approved_by         uuid references users(id),
  add column if not exists approved_at         timestamptz,
  add column if not exists notes               text;

-- Backfill planned_amount from allocated_eur
update budget_buckets set planned_amount = coalesce(allocated_eur, 0) where planned_amount is null;

-- Add unique constraint if not exists
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'budget_buckets_branch_id_cost_center_id_category_fiscal_year_q'
  ) then
    alter table budget_buckets
      add constraint budget_buckets_unique
      unique (branch_id, cost_center_id, category, fiscal_year, quarter);
  end if;
exception when others then null;
end $$;


-- =============================================================================
-- BUDGET REALLOCATIONS — rename columns to match v2 schema
-- =============================================================================
alter table budget_reallocations
  add column if not exists from_type           text,
  add column if not exists from_id             uuid,
  add column if not exists to_type             text,
  add column if not exists to_id               uuid,
  add column if not exists amount              numeric(15,2),
  add column if not exists currency            text default 'EUR',
  add column if not exists requested_by        uuid references users(id),
  add column if not exists ticket_id           uuid,
  add column if not exists notes               text,
  add column if not exists approved_at         timestamptz;

-- Backfill from old column names
update budget_reallocations set
  from_id   = from_bucket_id,
  to_id     = to_bucket_id,
  amount    = amount_eur,
  from_type = 'cost_center',
  to_type   = 'cost_center'
where from_id is null;


-- =============================================================================
-- PURCHASE ORDERS — add missing columns, rename total_eur → amount_eur
-- =============================================================================
alter table purchase_orders
  add column if not exists contract_id         uuid references contracts(id),
  add column if not exists cost_center_id      uuid references cost_centers(id),
  add column if not exists raised_by           uuid references users(id),
  add column if not exists description         text,
  add column if not exists category            spend_category,
  add column if not exists line_items          jsonb,
  add column if not exists amount              numeric(15,2),
  add column if not exists vat_amount          numeric(15,2) default 0,
  add column if not exists currency            text not null default 'EUR',
  add column if not exists amount_eur          numeric(15,2),
  add column if not exists po_date             date not null default current_date,
  add column if not exists expected_delivery   date,
  add column if not exists delivery_sla_days   int,
  add column if not exists notes               text,
  add column if not exists updated_at          timestamptz default now();

-- Backfill amount + amount_eur from total_eur
update purchase_orders set
  amount     = coalesce(amount, total_eur),
  amount_eur = coalesce(amount_eur, total_eur),
  po_date    = coalesce(po_date, issued_at::date, current_date)
where amount is null or po_date is null;

-- Fix status default (old schema had 'sent', v2 uses po_status enum)
-- Add generated columns only if amount exists now
do $$
begin
  -- total_amount generated column
  if not exists (
    select 1 from information_schema.columns
    where table_name='purchase_orders' and column_name='total_amount'
  ) then
    alter table purchase_orders
      add column total_amount numeric(15,2) generated always as (coalesce(amount,0) + coalesce(vat_amount,0)) stored;
  end if;
  -- delivery_overdue generated column
  if not exists (
    select 1 from information_schema.columns
    where table_name='purchase_orders' and column_name='delivery_overdue'
  ) then
    alter table purchase_orders
      add column delivery_overdue boolean generated always as (
        status = 'sent' and expected_delivery < current_date
      ) stored;
  end if;
end $$;


-- =============================================================================
-- LICENSE ENTITLEMENTS — add missing columns
-- =============================================================================
alter table license_entitlements
  add column if not exists contract_id         uuid references contracts(id),
  add column if not exists product_code        text,
  add column if not exists license_type        license_type not null default 'named_user',
  add column if not exists bundle_parent_id    uuid references license_entitlements(id),
  add column if not exists is_bundle           boolean default false,
  add column if not exists bundle_components   jsonb,
  add column if not exists assigned_seats      int default 0,
  add column if not exists active_seats        int default 0,
  add column if not exists shelfware_seats     int default 0,
  add column if not exists shelfware_pct       numeric(5,2),
  add column if not exists true_up_date        date,
  add column if not exists true_up_frequency   text,
  add column if not exists overage_seats       int default 0,
  add column if not exists overage_price_per_seat numeric(15,4),
  add column if not exists price_per_seat      numeric(15,4),
  add column if not exists price_currency      text default 'EUR',
  add column if not exists total_cost_eur      numeric(15,2),
  add column if not exists default_cost_center_id uuid references cost_centers(id),
  add column if not exists billing_split       jsonb,
  add column if not exists term_start          date,
  add column if not exists term_end            date,
  add column if not exists utilization_pct     numeric(5,2),
  add column if not exists avg_feature_usage_depth numeric(5,2),
  add column if not exists utilization_last_checked date,
  add column if not exists notes               text,
  add column if not exists updated_at          timestamptz default now();

-- Backfill assigned_seats from used_seats
update license_entitlements set
  assigned_seats = coalesce(assigned_seats, used_seats, 0),
  active_seats   = coalesce(active_seats, used_seats, 0)
where assigned_seats = 0 and used_seats > 0;

-- Add available_seats generated column
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_name='license_entitlements' and column_name='available_seats'
  ) then
    alter table license_entitlements
      add column available_seats int generated always as (
        case when total_seats is null then null
        else total_seats - assigned_seats end
      ) stored;
  end if;
end $$;


-- =============================================================================
-- LICENSE ASSIGNMENTS — add missing columns
-- =============================================================================
alter table license_assignments
  add column if not exists assigned_to_user    text,
  add column if not exists assigned_to_asset_id uuid references assets(id),
  add column if not exists cost_center_id      uuid references cost_centers(id),
  add column if not exists ticket_id           uuid,
  add column if not exists jira_key            text,
  add column if not exists last_active_at      timestamptz,
  add column if not exists active              boolean default true,
  add column if not exists usage_depth_pct     numeric(5,2),
  add column if not exists reclaimed_at        timestamptz,
  add column if not exists reclaim_reason      text,
  add column if not exists created_at          timestamptz default now();

-- Backfill assigned_to_user from old user_id FK if users table has emails
update license_assignments la
set assigned_to_user = u.email
from users u
where la.user_id = u.id and la.assigned_to_user is null;


-- =============================================================================
-- LLM CONSUMPTION — add missing columns, align with v2
-- =============================================================================
alter table llm_consumption
  add column if not exists provider            text,
  add column if not exists model               text,
  add column if not exists period              text,
  add column if not exists cost_center_id      uuid references cost_centers(id),
  add column if not exists input_tokens        bigint default 0,
  add column if not exists output_tokens       bigint default 0,
  add column if not exists cost_usd            numeric(15,6),
  add column if not exists anomaly_detected    boolean default false,
  add column if not exists updated_at          timestamptz default now();

-- Backfill period from period_date
update llm_consumption set
  period = to_char(period_date, 'YYYY-MM')
where period is null and period_date is not null;

-- Backfill input_tokens from tokens_used (can't split retroactively — put in input)
update llm_consumption set
  input_tokens = coalesce(tokens_used, 0)
where input_tokens = 0 and tokens_used > 0;

-- Add total_tokens generated column
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_name='llm_consumption' and column_name='total_tokens'
  ) then
    alter table llm_consumption
      add column total_tokens bigint generated always as (input_tokens + output_tokens) stored;
  end if;
end $$;


-- =============================================================================
-- VENDOR PRICING BENCHMARKS — add missing columns
-- =============================================================================
alter table vendor_pricing_benchmarks
  add column if not exists category            spend_category,
  add column if not exists metric_name         text,
  add column if not exists our_price           numeric(15,4),
  add column if not exists our_currency        text default 'EUR',
  add column if not exists market_low          numeric(15,4),
  add column if not exists market_median       numeric(15,4),
  add column if not exists market_high         numeric(15,4),
  add column if not exists benchmark_currency  text default 'EUR',
  add column if not exists unit                text,
  add column if not exists sample_size         int,
  add column if not exists benchmarked_at      date,
  add column if not exists valid_until         date,
  add column if not exists updated_at          timestamptz default now();

-- Backfill from old columns where possible
update vendor_pricing_benchmarks set
  our_price      = coalesce(our_price, benchmark_price),
  market_median  = coalesce(market_median, benchmark_price),
  metric_name    = coalesce(metric_name, product)
where our_price is null;


-- =============================================================================
-- HYPERSCALER POSITIONS — add missing columns
-- =============================================================================
alter table hyperscaler_positions
  add column if not exists account_id          text,
  add column if not exists service_name        text,
  add column if not exists actual_spend_eur    numeric(15,2),
  add column if not exists alert_type          text,
  add column if not exists alert_severity      text,
  add column if not exists estimated_saving_eur numeric(15,2),
  add column if not exists last_reviewed_at    timestamptz,
  add column if not exists decision_id         uuid,
  add column if not exists undershoot_risk     boolean default false;


-- =============================================================================
-- MISSING TABLES — create if they don't exist yet
-- (budget_pools already exists, skip)
-- =============================================================================

-- budget_pools already in DB, just ensure right columns
alter table budget_pools
  add column if not exists fiscal_year         int,
  add column if not exists committed           numeric(15,2) default 0,
  add column if not exists draw_authority      text default 'head_of_procurement',
  add column if not exists notes               text,
  add column if not exists created_at          timestamptz default now();


-- =============================================================================
-- DROP AND RECREATE ALL VIEWS (safe — views have no data)
-- =============================================================================

drop view if exists contracts_expiring cascade;
drop view if exists open_tickets_board cascade;
drop view if exists budget_command_center cascade;
drop view if exists commitment_register cascade;
drop view if exists license_waste_report cascade;
drop view if exists llm_spend_summary cascade;
drop view if exists agent_performance cascade;
drop view if exists supplier_compliance_summary cascade;
drop view if exists po_analytics cascade;
drop view if exists invoice_analytics cascade;
drop view if exists spend_trend cascade;
drop view if exists savings_tracking cascade;
drop view if exists supplier_performance cascade;
drop view if exists approval_velocity cascade;


-- contracts_expiring
create view contracts_expiring as
select
  c.id, c.name, c.category, c.value, c.value_eur, c.currency,
  c.expiry_date, c.notice_days, c.auto_renew, c.renewal_state,
  c.alert_90_sent, c.alert_60_sent, c.alert_30_sent,
  c.terms_summary, c.escalation_clause, c.escalation_rate,
  c.lock_in_score, c.exit_penalty_eur,
  s.id as supplier_id, s.name as supplier_name, s.health as supplier_health,
  s.contact_email, s.account_team_email,
  b.id as branch_id, b.name as branch_name, b.region,
  (c.expiry_date - current_date) as days_to_expiry,
  (c.expiry_date - c.notice_days) as notice_deadline
from contracts c
join suppliers s on s.id = c.supplier_id
join branches  b on b.id = c.branch_id
where c.expiry_date >= current_date
order by c.expiry_date asc;


-- open_tickets_board
create view open_tickets_board as
select
  t.id, t.reference, t.source, t.status, t.title, t.description,
  t.category, t.amount, t.amount_eur, t.currency,
  t.confidence, t.recommendation, t.brief,
  t.review_notes, t.jira_key, t.jira_url,
  t.submitted_by, t.submitted_by_email, t.supplier_name,
  t.created_at, t.updated_at, t.target_close,
  t.po_id, t.po_number,
  b.name  as branch_name, b.region,
  cc.code as cost_center_code, cc.name as cost_center_name,
  s.name  as supplier_name_linked, s.health as supplier_health,
  u.name  as owner_name, u.email as owner_email,
  -- PO details for delivery tracking
  po.status           as po_status,
  po.expected_delivery as po_expected_delivery,
  po.delivery_overdue  as po_delivery_overdue
from tickets t
left join branches       b  on b.id  = t.branch_id
left join cost_centers   cc on cc.id = t.cost_center_id
left join suppliers      s  on s.id  = t.supplier_id
left join users          u  on u.id  = t.owner_id
left join purchase_orders po on po.id = t.po_id
where t.status in ('open','pending_confirm','pending_review',
                   'signature_required','escalated','approved')
order by
  case t.status
    when 'pending_confirm'    then 1
    when 'pending_review'     then 2
    when 'signature_required' then 3
    when 'escalated'          then 4
    when 'approved'           then 5
    when 'open'               then 6
  end,
  t.created_at desc;


-- budget_command_center
create view budget_command_center as
select
  b.id            as branch_id,
  b.name          as branch_name,
  b.region,
  bp.category,
  bp.period,
  cc.code         as cost_center_code,
  cc.name         as cost_center_name,
  bp.budget,
  bp.committed,
  bp.spent,
  (bp.budget - bp.committed - bp.spent) as available,
  round(bp.committed / nullif(bp.budget,0) * 100, 1) as committed_pct,
  round((bp.committed + bp.spent) / nullif(bp.budget,0) * 100, 1) as consumed_pct,
  case
    when (bp.budget - bp.committed - bp.spent) < 0 then 'overrun'
    when (bp.committed + bp.spent) / nullif(bp.budget,0) > 0.90 then 'critical'
    when (bp.committed + bp.spent) / nullif(bp.budget,0) > 0.75 then 'warn'
    else 'healthy'
  end as budget_status
from budget_positions bp
join branches b on b.id = bp.branch_id
left join cost_centers cc on cc.id = bp.cost_center_id
order by
  case
    when (bp.budget - bp.committed - bp.spent) < 0 then 1
    when (bp.committed + bp.spent) / nullif(bp.budget,0) > 0.90 then 2
    when (bp.committed + bp.spent) / nullif(bp.budget,0) > 0.75 then 3
    else 4
  end,
  b.name, bp.category;


-- commitment_register
create view commitment_register as
select
  po.id, po.po_number, po.description, po.amount_eur, po.currency,
  po.po_date, po.expected_delivery, po.status as po_status,
  s.name  as supplier_name,
  b.name  as branch_name,
  cc.code as cost_center_code, cc.name as cost_center_name,
  po.category,
  t.reference as ticket_reference, t.jira_key,
  case
    when po.expected_delivery < current_date
    and po.status in ('sent','acknowledged')
    then true else false
  end as delivery_overdue
from purchase_orders po
join suppliers s on s.id = po.supplier_id
join branches  b on b.id = po.branch_id
left join cost_centers  cc on cc.id = po.cost_center_id
left join tickets        t on t.id  = po.ticket_id
where po.status not in ('closed','cancelled')
order by po.po_date desc;


-- license_waste_report
create view license_waste_report as
select
  le.id as entitlement_id, le.product_name, le.license_type,
  s.name  as supplier_name,
  b.name  as branch_name,
  cc.name as cost_center_name,
  le.total_seats, le.assigned_seats, le.active_seats,
  le.shelfware_seats, le.overage_seats, le.utilization_pct,
  le.price_per_seat,
  round(le.shelfware_seats * le.price_per_seat, 2) as annual_shelfware_cost,
  round(le.overage_seats * coalesce(le.overage_price_per_seat, le.price_per_seat), 2) as overage_exposure,
  le.term_end,
  (le.term_end - current_date) as days_to_renewal
from license_entitlements le
join suppliers s on s.id = le.supplier_id
left join contracts c on c.id = le.contract_id
left join branches  b on b.id = coalesce(c.branch_id, le.branch_id)
left join cost_centers cc on cc.id = le.default_cost_center_id
where le.shelfware_seats > 0 or le.overage_seats > 0
order by (le.shelfware_seats * le.price_per_seat) desc nulls last;


-- llm_spend_summary
create view llm_spend_summary as
select
  lc.provider, lc.model, lc.period,
  b.name  as branch_name,
  cc.name as cost_center_name,
  k.owner_email as key_owner, k.team_name,
  sum(lc.input_tokens)  as total_input_tokens,
  sum(lc.output_tokens) as total_output_tokens,
  sum(lc.cost_usd)      as total_cost_usd,
  sum(lc.cost_eur)      as total_cost_eur,
  count(*) filter (where lc.anomaly_detected) as anomaly_days,
  k.monthly_limit_usd,
  round(sum(lc.cost_usd) / nullif(k.monthly_limit_usd,0) * 100, 1) as pct_of_limit
from llm_consumption lc
join llm_api_keys k on k.id = lc.api_key_id
left join branches     b  on b.id  = lc.branch_id
left join cost_centers cc on cc.id = lc.cost_center_id
group by lc.provider, lc.model, lc.period, b.name, cc.name,
         k.owner_email, k.team_name, k.monthly_limit_usd
order by sum(lc.cost_eur) desc nulls last;


-- agent_performance
create view agent_performance as
select
  date_trunc('week', d.created_at)                      as week,
  count(*)                                              as total_decisions,
  count(*) filter (where d.disposition = 'auto_execute') as auto_executed,
  count(*) filter (where d.disposition = 'one_touch')    as one_touch,
  count(*) filter (where d.disposition = 'escalate')     as escalated,
  round(
    count(*) filter (where d.disposition = 'auto_execute')::numeric
    / nullif(count(*),0)::numeric * 100, 1
  )                                                     as auto_execute_pct,
  round(avg(d.confidence) * 100, 1)                     as avg_confidence_pct
from decisions d
group by date_trunc('week', d.created_at)
order by week desc;


-- supplier_compliance_summary
create view supplier_compliance_summary as
select
  s.id as supplier_id, s.name as supplier_name,
  s.compliance_status, s.nda_status, s.dpa_status,
  s.lksg_compliant, s.infosec_score, s.onboarding_complete,
  max(case when cc.check_type = 'lawyer'  then cc.score end) as lawyer_score,
  max(case when cc.check_type = 'gdpr'    then cc.score end) as gdpr_score,
  max(case when cc.check_type = 'infosec' then cc.score end) as infosec_score_check,
  max(case when cc.check_type = 'lksg'    then cc.score end) as lksg_score,
  max(case when ld.doc_type = 'nda' then ld.status::text end) as nda_doc_status,
  max(case when ld.doc_type = 'dpa' then ld.status::text end) as dpa_doc_status
from suppliers s
left join compliance_checks cc on cc.supplier_id = s.id
left join legal_documents   ld on ld.supplier_id = s.id
group by s.id, s.name, s.compliance_status, s.nda_status, s.dpa_status,
         s.lksg_compliant, s.infosec_score, s.onboarding_complete;


-- po_analytics
create view po_analytics as
select
  po.id as po_id, po.po_number, po.status as po_status, po.category,
  b.id as branch_id, b.name as branch_name, b.region,
  cc.code as cost_center_code, cc.name as cost_center_name,
  s.id as supplier_id, s.name as supplier_name,
  s.strategic_tier as supplier_tier, s.health as supplier_health,
  c.name as contract_name,
  po.amount, po.currency, po.amount_eur, po.vat_amount,
  po.po_date,
  po.expected_delivery, po.delivered_at,
  extract(year  from po.po_date)::int    as fiscal_year,
  extract(month from po.po_date)::int    as fiscal_month,
  extract(quarter from po.po_date)::int  as fiscal_quarter,
  to_char(po.po_date, 'IYYY-IW')         as iso_week,
  case when po.delivered_at is not null
    then extract(epoch from (po.delivered_at - po.po_date::timestamptz))::int / 86400
  end as cycle_time_days,
  po.delivery_overdue,
  case when po.delivered_at is not null and po.expected_delivery is not null
    then (po.delivered_at::date - po.expected_delivery)
  end as delivery_delta_days,
  inv.id as invoice_id, inv.invoice_number, inv.invoice_date,
  inv.amount_eur as invoiced_amount_eur, inv.match_result,
  inv.status as invoice_status,
  pi.id as payment_instruction_id, pi.due_date as payment_due_date,
  pi.status as payment_status, pi.erp_posted, pi.erp_posted_at,
  case when inv.received_at is not null and po.delivered_at is not null
    then extract(epoch from (inv.received_at - po.delivered_at))::int / 86400
  end as days_to_invoice,
  case when pi.created_at is not null and inv.received_at is not null
    then extract(epoch from (pi.created_at - inv.received_at))::int / 86400
  end as days_to_payment_instruction,
  t.reference as ticket_reference, t.jira_key, t.source as ticket_source,
  po.created_at, po.updated_at
from purchase_orders po
join suppliers  s  on s.id  = po.supplier_id
join branches   b  on b.id  = po.branch_id
left join cost_centers  cc  on cc.id = po.cost_center_id
left join contracts      c  on c.id  = po.contract_id
left join tickets        t  on t.id  = po.ticket_id
left join invoices      inv on inv.po_id = po.id
left join payment_instructions pi on pi.invoice_id = inv.id;


-- invoice_analytics
create view invoice_analytics as
select
  inv.id as invoice_id, inv.invoice_number,
  inv.status as invoice_status, inv.match_result,
  s.id as supplier_id, s.name as supplier_name,
  s.strategic_tier as supplier_tier, s.health as supplier_health,
  po.branch_id, b.name as branch_name, b.region,
  cc.code as cost_center_code, po.category,
  po.po_number, po.amount_eur as po_amount_eur,
  inv.amount, inv.currency, inv.amount_eur, inv.vat_amount,
  inv.total_amount, inv.vat_rate, inv.reverse_charge, inv.match_delta_eur,
  round(abs(inv.match_delta_eur) / nullif(po.amount_eur,0) * 100, 2) as match_delta_pct,
  (inv.match_result = 'matched')        as is_matched,
  (inv.match_result = 'amount_mismatch') as is_amount_dispute,
  (inv.match_result = 'no_delivery')    as is_delivery_dispute,
  (inv.match_result = 'no_po')          as is_orphan_invoice,
  (inv.status = 'disputed')             as is_disputed,
  inv.invoice_date, inv.received_at, inv.matched_at, inv.approved_at,
  extract(year  from inv.received_at)::int   as fiscal_year,
  extract(month from inv.received_at)::int   as fiscal_month,
  extract(quarter from inv.received_at)::int as fiscal_quarter,
  extract(epoch from (inv.matched_at  - inv.received_at))::int / 86400 as days_to_match,
  extract(epoch from (inv.approved_at - inv.received_at))::int / 86400 as days_to_approval,
  pi.id as payment_instruction_id, pi.payment_ref,
  pi.due_date as payment_due_date, pi.status as payment_status,
  pi.erp_posted, pi.erp_reference as erp_payment_reference, pi.erp_posted_at,
  esq.status as erp_sync_status, esq.erp_system,
  esq.attempts as erp_sync_attempts, esq.error_message as erp_sync_error,
  inv.parsed_by_model,
  inv.created_at, inv.updated_at
from invoices inv
join suppliers s on s.id = inv.supplier_id
left join purchase_orders po on po.id = inv.po_id
left join branches b         on b.id  = po.branch_id
left join cost_centers cc    on cc.id = po.cost_center_id
left join payment_instructions pi on pi.invoice_id = inv.id
left join erp_sync_queue esq on esq.entity_id = inv.id and esq.entity_type = 'invoice';


-- spend_trend
create view spend_trend as
select
  bp.branch_id, b.name as branch_name, b.region,
  bp.cost_center_id, cc.code as cost_center_code, cc.name as cost_center_name,
  bp.category, bp.period,
  case
    when bp.period like '____-Q_' then
      to_date(left(bp.period,4) || '-' ||
        case right(bp.period,1) when '1' then '01' when '2' then '04'
          when '3' then '07' when '4' then '10' end || '-01', 'YYYY-MM-DD')
    when bp.period like '____-__' then to_date(bp.period || '-01', 'YYYY-MM-DD')
  end as period_start_date,
  bb.planned_amount as budget_plan_eur,
  bp.budget as budget_allocated_eur,
  bp.committed as committed_eur,
  bp.spent as spent_eur,
  (bp.budget - bp.committed - bp.spent) as available_eur,
  (bp.committed + bp.spent) as total_consumed_eur,
  round(bp.committed / nullif(bp.budget,0) * 100, 1) as committed_pct,
  round(bp.spent     / nullif(bp.budget,0) * 100, 1) as spent_pct,
  round((bp.committed + bp.spent) / nullif(bp.budget,0) * 100, 1) as total_consumed_pct,
  round((bp.committed + bp.spent) / nullif(bb.planned_amount,0) * 100, 1) as pct_of_plan,
  case
    when (bp.budget - bp.committed - bp.spent) < 0 then 'overrun'
    when (bp.committed + bp.spent) / nullif(bp.budget,0) > 0.90 then 'critical'
    when (bp.committed + bp.spent) / nullif(bp.budget,0) > 0.75 then 'warn'
    else 'healthy'
  end as budget_health,
  bp.updated_at as last_updated
from budget_positions bp
join branches b on b.id = bp.branch_id
left join cost_centers cc on cc.id = bp.cost_center_id
left join budget_buckets bb
  on  bb.branch_id   = bp.branch_id
  and (bb.cost_center_id = bp.cost_center_id or (bb.cost_center_id is null and bp.cost_center_id is null))
  and bb.category    = bp.category::text
  and bb.fiscal_year = extract(year from
      case when bp.period like '____-Q_' then
        to_date(left(bp.period,4) || '-' ||
          case right(bp.period,1) when '1' then '01' when '2' then '04'
            when '3' then '07' when '4' then '10' end || '-01', 'YYYY-MM-DD')
      when bp.period like '____-__' then to_date(bp.period || '-01', 'YYYY-MM-DD')
      end)::int
  and bb.quarter = case when bp.period like '____-Q_' then right(bp.period,1)::int else null end
order by b.name, bp.category, bp.period;


-- savings_tracking
create view savings_tracking as
select
  c.id as contract_id, c.name as contract_name, c.category,
  c.value_eur as contract_value_eur, c.start_date, c.expiry_date,
  (c.expiry_date - c.start_date)::int / 365.0 as contract_term_years,
  s.id as supplier_id, s.name as supplier_name,
  s.strategic_tier as supplier_tier, s.lock_in_score as supplier_lock_in,
  b.id as branch_id, b.name as branch_name, b.region,
  vpb.id as benchmark_id, vpb.metric_name,
  vpb.our_price, vpb.our_currency,
  vpb.market_low, vpb.market_median, vpb.market_high,
  vpb.benchmark_currency, vpb.unit, vpb.sample_size,
  vpb.source, vpb.benchmarked_at, vpb.valid_until,
  round((vpb.market_median - vpb.our_price), 4) as saving_per_unit,
  round((vpb.market_median - vpb.our_price) / nullif(vpb.market_median,0) * 100, 1) as saving_pct,
  round((vpb.market_median - vpb.our_price) * coalesce(c.volume,0), 2) as annual_saving_eur,
  round((vpb.market_median - vpb.our_price) * coalesce(c.volume,0)
        * ((c.expiry_date - c.start_date)::numeric / 365), 2) as term_saving_eur,
  case
    when vpb.our_price <= vpb.market_low    then 'best_in_class'
    when vpb.our_price <= vpb.market_median then 'below_market'
    when vpb.our_price <= vpb.market_high   then 'above_median'
    else 'above_market'
  end as pricing_position,
  (c.expiry_date - current_date) as days_to_expiry,
  c.renewal_state, c.auto_renew, c.escalation_clause,
  c.escalation_rate, c.tco_eur, c.exit_penalty_eur,
  c.lock_in_score as contract_lock_in
from contracts c
join suppliers s on s.id = c.supplier_id
join branches  b on b.id = c.branch_id
join vendor_pricing_benchmarks vpb
  on vpb.supplier_id = c.supplier_id
  and (vpb.category = c.category or vpb.category is null)
where c.expiry_date >= current_date - interval '12 months'
order by abs(term_saving_eur) desc nulls last;


-- supplier_performance
create view supplier_performance as
select
  s.id as supplier_id, s.name as supplier_name,
  s.category as primary_category, s.health as current_health,
  s.strategic_tier, s.lock_in_score, s.open_disputes,
  s.compliance_status, s.onboarding_complete, s.infosec_score,
  count(distinct po.id)                              as total_pos,
  coalesce(sum(po.amount_eur), 0)                    as total_po_value_eur,
  coalesce(avg(po.amount_eur), 0)                    as avg_po_value_eur,
  count(distinct po.id) filter (where po.status = 'cancelled') as cancelled_pos,
  count(distinct po.id) filter (where po.delivered_at is not null) as delivered_pos,
  count(distinct po.id) filter (
    where po.delivered_at is not null and po.expected_delivery is not null
    and po.delivered_at::date > po.expected_delivery
  ) as late_deliveries,
  round(
    count(distinct po.id) filter (
      where po.delivered_at is not null
      and (po.expected_delivery is null or po.delivered_at::date <= po.expected_delivery)
    )::numeric / nullif(count(distinct po.id) filter (where po.delivered_at is not null),0) * 100, 1
  ) as on_time_delivery_pct,
  round(avg(case
    when po.delivered_at is not null and po.expected_delivery is not null
    and po.delivered_at::date > po.expected_delivery
    then (po.delivered_at::date - po.expected_delivery) end
  ), 1) as avg_late_days,
  count(distinct inv.id)                             as total_invoices,
  count(distinct inv.id) filter (where inv.match_result = 'matched') as matched_invoices,
  count(distinct inv.id) filter (where inv.status = 'disputed')      as disputed_invoices,
  round(count(distinct inv.id) filter (where inv.match_result = 'matched')::numeric
    / nullif(count(distinct inv.id),0) * 100, 1) as invoice_match_rate_pct,
  round(count(distinct inv.id) filter (where inv.status = 'disputed')::numeric
    / nullif(count(distinct inv.id),0) * 100, 1) as invoice_dispute_rate_pct,
  count(distinct c.id) filter (where c.expiry_date >= current_date) as active_contracts,
  coalesce(sum(c.value_eur) filter (where c.expiry_date >= current_date),0) as active_contract_value_eur,
  count(distinct c.id) filter (
    where c.expiry_date between current_date and current_date + 90
  ) as renewals_next_90d,
  s.nda_status, s.dpa_status, s.lksg_compliant,
  round((
    coalesce(
      count(distinct po.id) filter (
        where po.delivered_at is not null
        and (po.expected_delivery is null or po.delivered_at::date <= po.expected_delivery)
      )::numeric / nullif(count(distinct po.id) filter (where po.delivered_at is not null),0) * 40, 20)
    + coalesce(count(distinct inv.id) filter (where inv.match_result='matched')::numeric
        / nullif(count(distinct inv.id),0) * 30, 15)
    + case s.compliance_status when 'green' then 20 when 'amber' then 12
        when 'red' then 0 when 'pending' then 8 else 10 end
    + case s.health when 'green' then 10 when 'watch' then 5 when 'red' then 0 end
  ), 1) as supplier_score
from suppliers s
left join purchase_orders po on po.supplier_id = s.id
left join invoices        inv on inv.supplier_id = s.id
left join contracts       c  on c.supplier_id  = s.id
group by s.id, s.name, s.category, s.health, s.strategic_tier,
  s.lock_in_score, s.open_disputes, s.compliance_status,
  s.onboarding_complete, s.infosec_score, s.nda_status, s.dpa_status, s.lksg_compliant
order by total_po_value_eur desc nulls last;


-- approval_velocity
create view approval_velocity as
select
  t.id as ticket_id, t.reference as ticket_reference,
  t.source as ticket_source, t.category,
  b.id as branch_id, b.name as branch_name, b.region,
  cc.code as cost_center_code, s.name as supplier_name,
  d.disposition, d.confidence, d.actioned_by,
  (d.actioned_by = 'agent') as agent_handled,
  d.created_at as decision_at,
  t.amount_eur,
  extract(epoch from (d.created_at - t.created_at))::int / 60 as minutes_to_decision,
  extract(epoch from (po.created_at - t.created_at))::int / 60 as minutes_to_po,
  extract(epoch from (po.created_at - d.created_at))::int / 60 as minutes_decision_to_po,
  case
    when extract(epoch from (po.created_at - t.created_at))::int / 60 < 5    then '< 5 min'
    when extract(epoch from (po.created_at - t.created_at))::int / 60 < 60   then '5-60 min'
    when extract(epoch from (po.created_at - t.created_at))::int / 60 < 480  then '1-8 hrs'
    when extract(epoch from (po.created_at - t.created_at))::int / 60 < 1440 then '8-24 hrs'
    when extract(epoch from (po.created_at - t.created_at))::int / 60 < 4320 then '1-3 days'
    else '> 3 days'
  end as time_to_po_bucket,
  t.created_at as requested_at,
  extract(year  from t.created_at)::int   as fiscal_year,
  extract(month from t.created_at)::int   as fiscal_month,
  extract(quarter from t.created_at)::int as fiscal_quarter,
  to_char(t.created_at, 'IYYY-IW')        as iso_week,
  po.po_number, po.amount_eur as po_amount_eur, po.status as po_status
from tickets t
left join branches       b  on b.id  = t.branch_id
left join cost_centers   cc on cc.id = t.cost_center_id
left join suppliers      s  on s.id  = t.supplier_id
left join decisions      d  on d.ticket_id = t.id
left join purchase_orders po on po.ticket_id = t.id
where t.status not in ('open','reasoning')
order by t.created_at desc;


-- =============================================================================
-- GRANT SELECT ON ALL VIEWS
-- =============================================================================
do $$
declare v text;
begin
  for v in select viewname from pg_views where schemaname = 'public'
  loop
    execute 'grant select on ' || v || ' to truespend';
  end loop;
end $$;


-- =============================================================================
-- RECREATE FUNCTIONS (idempotent — create or replace)
-- =============================================================================

create or replace function commit_budget(
  p_branch_id uuid, p_cost_center_id uuid, p_category spend_category,
  p_period text, p_amount numeric
) returns budget_positions language plpgsql security definer as $$
declare v_row budget_positions;
begin
  select * into v_row from budget_positions
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category and period = p_period
  for update;
  if not found then
    raise exception 'Budget position not found: % / % / % / %',
      p_branch_id, p_cost_center_id, p_category, p_period;
  end if;
  if (v_row.budget - v_row.committed - v_row.spent) < p_amount then
    raise exception 'Insufficient budget: available=%, requested=%',
      (v_row.budget - v_row.committed - v_row.spent), p_amount;
  end if;
  update budget_positions set committed = committed + p_amount, updated_at = now()
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category and period = p_period
  returning * into v_row;
  return v_row;
end $$;

create or replace function release_budget(
  p_branch_id uuid, p_cost_center_id uuid, p_category spend_category,
  p_period text, p_amount numeric
) returns budget_positions language plpgsql security definer as $$
declare v_row budget_positions;
begin
  select * into v_row from budget_positions
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category and period = p_period
  for update;
  if not found then
    raise exception 'Budget position not found: % / % / % / %',
      p_branch_id, p_cost_center_id, p_category, p_period;
  end if;
  update budget_positions
  set committed = greatest(committed - p_amount, 0), updated_at = now()
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category and period = p_period
  returning * into v_row;
  return v_row;
end $$;

create or replace function record_spend(
  p_branch_id uuid, p_cost_center_id uuid, p_category spend_category,
  p_period text, p_committed_release numeric, p_spend_amount numeric
) returns budget_positions language plpgsql security definer as $$
declare v_row budget_positions;
begin
  select * into v_row from budget_positions
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category and period = p_period
  for update;
  if not found then
    raise exception 'Budget position not found: % / % / % / %',
      p_branch_id, p_cost_center_id, p_category, p_period;
  end if;
  update budget_positions
  set committed = greatest(committed - p_committed_release, 0),
      spent = spent + p_spend_amount, updated_at = now()
  where branch_id = p_branch_id
    and cost_center_id is not distinct from p_cost_center_id
    and category = p_category and period = p_period
  returning * into v_row;
  return v_row;
end $$;

create or replace function next_po_number(p_branch_id uuid, p_branch_code text)
returns text language plpgsql security definer as $$
declare v_year int := extract(year from current_date); v_seq int;
begin
  insert into po_sequences (branch_id, fiscal_year, last_seq) values (p_branch_id, v_year, 1)
  on conflict (branch_id, fiscal_year) do update set last_seq = po_sequences.last_seq + 1
  returning last_seq into v_seq;
  return 'PO-' || v_year || '-' || upper(p_branch_code) || '-' || lpad(v_seq::text, 4, '0');
end $$;

create or replace function approve_and_commit(
  p_ticket_id uuid, p_branch_id uuid, p_branch_code text, p_cost_center_id uuid,
  p_category spend_category, p_period text, p_supplier_id uuid, p_contract_id uuid,
  p_description text, p_amount numeric, p_currency text, p_amount_eur numeric,
  p_raised_by uuid, p_expected_delivery date, p_line_items jsonb
) returns purchase_orders language plpgsql security definer as $$
declare v_po_number text; v_po purchase_orders;
begin
  v_po_number := next_po_number(p_branch_id, p_branch_code);
  perform commit_budget(p_branch_id, p_cost_center_id, p_category, p_period, p_amount_eur);
  insert into purchase_orders (
    po_number, ticket_id, contract_id, supplier_id, branch_id, cost_center_id,
    raised_by, description, category, line_items, amount, currency, amount_eur,
    po_date, expected_delivery, status
  ) values (
    v_po_number, p_ticket_id, p_contract_id, p_supplier_id, p_branch_id, p_cost_center_id,
    p_raised_by, p_description, p_category, p_line_items, p_amount, p_currency, p_amount_eur,
    current_date, p_expected_delivery, 'draft'
  ) returning * into v_po;
  update tickets set status = 'approved', po_id = v_po.id, updated_at = now()
  where id = p_ticket_id;
  return v_po;
end $$;

create or replace function confirm_delivery(p_po_id uuid, p_confirmed_by text)
returns purchase_orders language plpgsql security definer as $$
declare v_po purchase_orders; v_late boolean;
begin
  select * into v_po from purchase_orders where id = p_po_id for update;
  if not found then raise exception 'PO not found: %', p_po_id; end if;
  v_late := v_po.expected_delivery is not null and current_date > v_po.expected_delivery;
  update purchase_orders set status = 'delivered', delivered_at = now(),
    notes = coalesce(notes,'') || case when v_late
      then ' [LATE: delivered ' || (current_date - v_po.expected_delivery)::text || ' days after SLA]'
      else '' end,
    updated_at = now()
  where id = p_po_id returning * into v_po;
  if v_late then
    update suppliers set health = case when health = 'green' then 'watch'::supplier_health else health end,
      updated_at = now()
    where id = v_po.supplier_id;
  end if;
  return v_po;
end $$;

create or replace function match_invoice(p_invoice_id uuid)
returns invoices language plpgsql security definer as $$
declare v_inv invoices; v_po purchase_orders; v_tolerance numeric; v_delta numeric; v_result text;
begin
  select * into v_inv from invoices where id = p_invoice_id for update;
  if not found then raise exception 'Invoice not found: %', p_invoice_id; end if;
  if v_inv.po_id is null then
    update invoices set match_result='no_po', status='disputed', matched_at=now(), updated_at=now()
    where id=p_invoice_id returning * into v_inv; return v_inv;
  end if;
  select * into v_po from purchase_orders where id = v_inv.po_id;
  if v_po.status not in ('delivered','invoiced','closed') then
    update invoices set match_result='no_delivery', status='disputed', matched_at=now(), updated_at=now()
    where id=p_invoice_id returning * into v_inv; return v_inv;
  end if;
  v_tolerance := v_po.amount * coalesce(v_inv.match_tolerance_pct, 0.02);
  v_delta     := abs(v_inv.amount - v_po.amount);
  if v_delta <= v_tolerance then
    v_result := 'matched';
    update purchase_orders set status='invoiced', updated_at=now() where id=v_po.id;
  else
    v_result := 'amount_mismatch';
  end if;
  update invoices set match_result=v_result, match_delta_eur=v_delta,
    status=case v_result when 'matched' then 'matched' else 'disputed' end,
    matched_at=now(), updated_at=now()
  where id=p_invoice_id returning * into v_inv;
  return v_inv;
end $$;

create or replace function create_payment_instruction(p_invoice_id uuid, p_due_date date)
returns payment_instructions language plpgsql security definer as $$
declare v_inv invoices; v_po purchase_orders; v_pi payment_instructions; v_ref text;
begin
  select * into v_inv from invoices where id = p_invoice_id;
  select * into v_po  from purchase_orders where id = v_inv.po_id;
  v_ref := 'PAY-' || extract(year from current_date)::text || '-' ||
           to_char(now(),'MM') || '-' || substr(p_invoice_id::text,1,8);
  insert into payment_instructions (invoice_id, po_id, supplier_id, amount, currency,
    payment_ref, due_date, status)
  values (p_invoice_id, v_inv.po_id, v_inv.supplier_id, v_inv.amount, v_inv.currency,
    v_ref, p_due_date, 'pending')
  returning * into v_pi;
  update invoices set status='approved', approved_at=now(), updated_at=now() where id=p_invoice_id;
  insert into erp_sync_queue (event_type, entity_type, entity_id, payload, status)
  values ('invoice_approved', 'invoice', p_invoice_id,
    jsonb_build_object('payment_instruction_id', v_pi.id, 'payment_ref', v_ref,
      'invoice_id', p_invoice_id, 'po_id', v_inv.po_id, 'supplier_id', v_inv.supplier_id,
      'amount', v_inv.amount, 'currency', v_inv.currency, 'due_date', p_due_date,
      'po_number', v_po.po_number), 'pending');
  if v_po.branch_id is not null and v_po.category is not null then
    perform record_spend(v_po.branch_id, v_po.cost_center_id, v_po.category,
      extract(year from current_date)::text || '-Q' ||
        ceil(extract(month from current_date)/3.0)::int::text,
      v_po.amount_eur, v_inv.amount_eur);
  end if;
  return v_pi;
end $$;

grant execute on function commit_budget              to truespend;
grant execute on function release_budget             to truespend;
grant execute on function record_spend               to truespend;
grant execute on function next_po_number             to truespend;
grant execute on function approve_and_commit         to truespend;
grant execute on function confirm_delivery           to truespend;
grant execute on function match_invoice              to truespend;
grant execute on function create_payment_instruction to truespend;

-- Done
select 'Migration v2.0 complete' as status,
  (select count(*) from information_schema.tables where table_schema='public' and table_type='BASE TABLE') as tables,
  (select count(*) from information_schema.views  where table_schema='public') as views;
