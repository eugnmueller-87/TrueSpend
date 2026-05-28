-- migrate_v2_patch.sql — fixes 6 views that failed in migrate_v2.sql
-- Run after migrate_v2.sql succeeds

-- ─────────────────────────────────────────────────────────────────────────────
-- Fix po_cycle_time (delivery_overdue was stored col; now computed inline)
-- ─────────────────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS po_cycle_time CASCADE;
CREATE VIEW po_cycle_time AS
SELECT
  po.id                                             AS po_id,
  po.po_number,
  po.branch_id,
  b.name                                            AS branch_name,
  po.supplier_id,
  s.name                                            AS supplier_name,
  po.category,
  po.po_date,
  po.expected_delivery,
  po.delivered_at,
  po.status                                         AS po_status,
  (po.expected_delivery < current_date AND po.delivered_at IS NULL)
                                                    AS po_delivery_overdue,
  CASE WHEN po.delivered_at IS NOT NULL
       THEN (po.delivered_at::date - po.po_date)
       ELSE NULL
  END                                               AS fulfillment_days,
  CASE WHEN po.delivered_at IS NOT NULL AND po.expected_delivery IS NOT NULL
       THEN (po.delivered_at::date - po.expected_delivery)
       ELSE NULL
  END                                               AS delivery_variance_days
FROM purchase_orders po
JOIN suppliers s ON s.id = po.supplier_id
JOIN branches  b ON b.id = po.branch_id;

GRANT SELECT ON po_cycle_time TO truespend;

-- ─────────────────────────────────────────────────────────────────────────────
-- Fix llm_cost_by_key (owner_email not a stored col; use joined users table)
-- ─────────────────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS llm_cost_by_key CASCADE;
CREATE VIEW llm_cost_by_key AS
SELECT
  k.id                                              AS key_id,
  k.provider,
  k.key_ref,
  k.branch_id,
  b.name                                            AS branch_name,
  k.team_name,
  k.monthly_budget_eur,
  u.email                                           AS key_owner,
  COALESCE(SUM(lc.cost_eur), 0)                     AS total_cost_eur,
  COALESCE(SUM(lc.input_tokens + lc.output_tokens), 0) AS total_tokens,
  MAX(lc.period)                                    AS latest_period,
  COUNT(lc.id)                                      AS consumption_records
FROM llm_api_keys k
JOIN branches b ON b.id = k.branch_id
LEFT JOIN users u ON u.id = k.owner_user_id
LEFT JOIN llm_consumption lc ON lc.api_key_id = k.id
GROUP BY k.id, k.provider, k.key_ref, k.branch_id, b.name, k.team_name, k.monthly_budget_eur, u.email;

GRANT SELECT ON llm_cost_by_key TO truespend;

-- ─────────────────────────────────────────────────────────────────────────────
-- Fix po_analytics (delivery_overdue computed inline)
-- ─────────────────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS po_analytics CASCADE;
CREATE VIEW po_analytics AS
SELECT
  po.id                                                              AS po_id,
  po.po_number,
  po.branch_id,
  b.name                                                             AS branch_name,
  po.supplier_id,
  s.name                                                             AS supplier_name,
  po.category,
  po.po_date,
  date_trunc('month', po.po_date)                                    AS period_start_date,
  to_char(po.po_date, 'IYYY')                                        AS fiscal_year,
  'Q' || to_char(po.po_date, 'Q')                                    AS fiscal_quarter,
  to_char(po.po_date, 'IW')                                         AS iso_week,
  po.expected_delivery,
  po.delivered_at,
  po.status                                                          AS po_status,
  (po.expected_delivery < current_date AND po.delivered_at IS NULL)  AS delivery_overdue,
  po.amount_eur,
  po.currency,
  po.amount                                                          AS amount_local,
  po.description,
  po.line_items,
  po.cost_center_id,
  cc.name                                                            AS cost_center_name,
  po.raised_by,
  u.email                                                            AS raised_by_email,
  CASE WHEN po.delivered_at IS NOT NULL
       THEN (po.delivered_at::date - po.po_date)
       ELSE NULL
  END                                                                AS fulfillment_days,
  CASE WHEN po.delivered_at IS NOT NULL AND po.expected_delivery IS NOT NULL
       THEN (po.delivered_at::date - po.expected_delivery)
       ELSE NULL
  END                                                                AS delivery_variance_days,
  po.contract_id,
  c.name                                                             AS contract_name
FROM purchase_orders po
JOIN suppliers s      ON s.id  = po.supplier_id
JOIN branches  b      ON b.id  = po.branch_id
LEFT JOIN cost_centers cc ON cc.id = po.cost_center_id
LEFT JOIN users        u  ON u.id  = po.raised_by
LEFT JOIN contracts    c  ON c.id  = po.contract_id;

GRANT SELECT ON po_analytics TO truespend;

-- ─────────────────────────────────────────────────────────────────────────────
-- Fix invoice_analytics (match_result now exists after column addition)
-- ─────────────────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS invoice_analytics CASCADE;
CREATE VIEW invoice_analytics AS
SELECT
  inv.id                                                             AS invoice_id,
  inv.invoice_number,
  inv.po_id,
  po.po_number,
  inv.supplier_id,
  s.name                                                             AS supplier_name,
  po.branch_id,
  b.name                                                             AS branch_name,
  po.category,
  po.cost_center_id,
  cc.name                                                            AS cost_center_name,
  inv.received_at,
  date_trunc('month', inv.received_at)                               AS period_start_date,
  to_char(inv.received_at, 'IYYY')                                   AS fiscal_year,
  'Q' || to_char(inv.received_at, 'Q')                              AS fiscal_quarter,
  to_char(inv.received_at, 'IW')                                    AS iso_week,
  inv.matched_at,
  inv.status                                                         AS invoice_status,
  inv.match_result,
  inv.amount_eur,
  inv.currency,
  inv.raw_amount,
  inv.raw_currency,
  inv.vat_amount,
  inv.due_date,
  inv.payment_terms_days,
  CASE WHEN inv.matched_at IS NOT NULL
       THEN extract(epoch FROM (inv.matched_at - inv.received_at))/86400
       ELSE NULL
  END::numeric(8,1)                                                  AS days_to_match,
  CASE WHEN inv.due_date IS NOT NULL AND inv.matched_at IS NULL
       THEN inv.due_date < current_date
       ELSE false
  END                                                                AS overdue,
  po.amount_eur                                                      AS po_amount_eur
FROM invoices inv
JOIN purchase_orders po ON po.id = inv.po_id
JOIN suppliers  s       ON s.id  = inv.supplier_id
JOIN branches   b       ON b.id  = po.branch_id
LEFT JOIN cost_centers cc ON cc.id = po.cost_center_id;

GRANT SELECT ON invoice_analytics TO truespend;

-- ─────────────────────────────────────────────────────────────────────────────
-- Fix savings_tracking (category type cast: both cast to text to compare across enums)
-- ─────────────────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS savings_tracking CASCADE;
CREATE VIEW savings_tracking AS
SELECT
  po.id                                                              AS po_id,
  po.po_number,
  po.po_date,
  date_trunc('month', po.po_date)                                    AS period_start_date,
  to_char(po.po_date, 'IYYY')                                        AS fiscal_year,
  'Q' || to_char(po.po_date, 'Q')                                    AS fiscal_quarter,
  po.branch_id,
  b.name                                                             AS branch_name,
  po.supplier_id,
  s.name                                                             AS supplier_name,
  po.category::text                                                  AS category,
  po.amount_eur                                                      AS po_amount_eur,
  vpb.metric_name,
  vpb.our_price,
  vpb.market_median,
  vpb.market_low,
  vpb.market_high,
  vpb.unit,
  vpb.sample_size,
  CASE WHEN vpb.market_median IS NOT NULL AND vpb.our_price IS NOT NULL
       THEN (vpb.market_median - vpb.our_price) * COALESCE(po.amount_eur / NULLIF(vpb.our_price,0), 1)
       ELSE NULL
  END                                                                AS estimated_savings_eur,
  CASE WHEN vpb.market_median IS NOT NULL AND vpb.our_price IS NOT NULL AND vpb.market_median > 0
       THEN round((vpb.market_median - vpb.our_price) / vpb.market_median * 100, 1)
       ELSE NULL
  END                                                                AS savings_pct,
  CASE WHEN vpb.market_median IS NOT NULL AND vpb.our_price IS NOT NULL
       THEN CASE
         WHEN vpb.our_price <= vpb.market_low    THEN 'best_in_class'
         WHEN vpb.our_price <= vpb.market_median THEN 'above_median'
         WHEN vpb.our_price <= vpb.market_high   THEN 'below_median'
         ELSE 'above_market'
       END
       ELSE 'no_benchmark'
  END                                                                AS price_position
FROM purchase_orders po
JOIN branches  b ON b.id = po.branch_id
JOIN suppliers s ON s.id = po.supplier_id
LEFT JOIN vendor_pricing_benchmarks vpb
  ON  vpb.supplier_id = po.supplier_id
  AND vpb.category::text = po.category::text;

GRANT SELECT ON savings_tracking TO truespend;

-- ─────────────────────────────────────────────────────────────────────────────
-- Fix supplier_performance (match_result: use inv.status = 'matched' not match_result col)
-- ─────────────────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS supplier_performance CASCADE;
CREATE VIEW supplier_performance AS
SELECT
  s.id                                                               AS supplier_id,
  s.name                                                             AS supplier_name,
  s.country,
  s.compliance_status,
  s.strategic_tier,
  s.health_signal,
  s.infosec_score,
  s.nda_status,
  s.dpa_status,
  s.lksg_compliant,
  count(distinct po.id)                                              AS total_pos,
  coalesce(sum(po.amount_eur), 0)                                    AS total_spend_eur,
  count(distinct po.id) filter (where po.delivered_at is not null)   AS delivered_pos,
  count(distinct po.id) filter (
    where po.delivered_at is not null
    and po.expected_delivery is not null
    and po.delivered_at::date <= po.expected_delivery
  )                                                                  AS on_time_pos,
  count(distinct inv.id)                                             AS total_invoices,
  count(distinct inv.id) filter (where inv.status = 'matched')       AS matched_invoices,
  round(
    case when count(distinct po.id) filter (where po.delivered_at is not null) > 0
         then (count(distinct po.id) filter (
                 where po.delivered_at is not null
                 and po.expected_delivery is not null
                 and po.delivered_at::date <= po.expected_delivery
               )::numeric
               / nullif(count(distinct po.id) filter (where po.delivered_at is not null), 0)
              ) * 40
         else 0
    end
    + case when count(distinct inv.id) > 0
           then (count(distinct inv.id) filter (where inv.status = 'matched')::numeric
                 / nullif(count(distinct inv.id), 0)) * 30
           else 30
      end
    + case s.compliance_status
        when 'approved'  then 20
        when 'pending'   then 10
        else 0
      end
    + case s.health_signal
        when 'green'  then 10
        when 'amber'  then 5
        else 0
      end
  , 1)                                                               AS supplier_score
FROM suppliers s
LEFT JOIN purchase_orders po ON po.supplier_id = s.id
LEFT JOIN invoices        inv ON inv.supplier_id = s.id
GROUP BY s.id, s.name, s.country, s.compliance_status, s.strategic_tier,
         s.health_signal, s.infosec_score, s.nda_status, s.dpa_status, s.lksg_compliant;

GRANT SELECT ON supplier_performance TO truespend;

-- ─────────────────────────────────────────────────────────────────────────────
-- Fix approval_velocity (clean rebuild)
-- ─────────────────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS approval_velocity CASCADE;
CREATE VIEW approval_velocity AS
SELECT
  t.id                                                               AS ticket_id,
  t.reference,
  t.status,
  t.category,
  t.disposition,
  t.amount_eur,
  t.branch_id,
  b.name                                                             AS branch_name,
  t.created_at,
  t.updated_at,
  date_trunc('month', t.created_at)                                  AS period_start_date,
  to_char(t.created_at, 'IYYY')                                      AS fiscal_year,
  'Q' || to_char(t.created_at, 'Q')                                  AS fiscal_quarter,
  extract(epoch FROM (t.updated_at - t.created_at))/3600             AS hours_open,
  CASE
    WHEN t.status IN ('approved','rejected','closed')
    THEN extract(epoch FROM (t.updated_at - t.created_at))/3600
    ELSE NULL
  END                                                                AS hours_to_resolution,
  CASE
    WHEN t.disposition = 'auto_execute'          THEN 'automated'
    WHEN t.disposition IN ('one_touch','escalate') THEN 'human_touch'
    ELSE 'unknown'
  END                                                                AS handling_type,
  CASE
    WHEN t.status NOT IN ('approved','rejected','closed') THEN NULL
    WHEN t.disposition = 'auto_execute'
         AND extract(epoch FROM (t.updated_at - t.created_at))/3600 <= 1  THEN true
    WHEN t.disposition = 'one_touch'
         AND extract(epoch FROM (t.updated_at - t.created_at))/3600 <= 24 THEN true
    WHEN t.disposition = 'escalate'
         AND extract(epoch FROM (t.updated_at - t.created_at))/3600 <= 72 THEN true
    ELSE false
  END                                                                AS within_sla,
  po.po_number,
  po.id                                                              AS po_id
FROM tickets t
JOIN branches b ON b.id = t.branch_id
LEFT JOIN purchase_orders po ON po.ticket_id = t.id;

GRANT SELECT ON approval_velocity TO truespend;

-- ─────────────────────────────────────────────────────────────────────────────
-- Final check
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'Patch complete' AS status,
  (SELECT count(*) FROM information_schema.views WHERE table_schema = 'public') AS view_count;
