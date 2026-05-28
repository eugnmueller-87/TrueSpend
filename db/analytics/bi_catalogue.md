# TrueSpend — BI View Catalogue
**For: Tableau, Power BI, Metabase, Grafana, or any PostgreSQL-compatible BI tool**  
**Last updated:** 2026-05-28

---

## Connection Details

| Parameter | Value |
|---|---|
| Host | `zephyr.proxy.rlwy.net` |
| Port | `24934` |
| Database | `truespend` |
| Username | `truespend` |
| SSL | Required (`sslmode=require`) |
| Schema | `public` |

**PostgREST REST API** (alternative to direct PostgreSQL — useful for embedded dashboards):
```
Base URL:     https://postgrest-production-7960.up.railway.app
Auth header:  Authorization: Bearer <POSTGREST_JWT>
Example:      GET /po_analytics?po_status=eq.delivered&order=po_date.desc
```

---

## View Index

| View | Description | Primary use case |
|---|---|---|
| [`po_analytics`](#po_analytics) | Full PO pipeline with cycle times, delivery SLA, invoice and payment linkage | PO dashboards, supplier concentration, cycle time |
| [`invoice_analytics`](#invoice_analytics) | Invoice processing: match rates, disputes, payment cycle | AP dashboards, match rate KPIs, ERP sync status |
| [`spend_trend`](#spend_trend) | Time-series budget consumption by branch × category × period | Burn rate, YTD vs plan, forecasting |
| [`savings_tracking`](#savings_tracking) | Benchmark vs actual pricing, savings realisation per contract | Savings dashboards, negotiation ROI |
| [`supplier_performance`](#supplier_performance) | Delivery SLA, invoice quality, compliance, overall supplier score | Supplier scorecards, QBR preparation |
| [`approval_velocity`](#approval_velocity) | Request-to-PO cycle time by disposition, category, branch | Process efficiency, agent ROI |
| [`budget_command_center`](#budget_command_center) | Real-time budget utilisation with health signals | Controlling dashboard, CFO view |
| [`commitment_register`](#commitment_register) | Open POs not yet invoiced — the accruals list | Month-end, Controlling, ERP reconciliation |
| [`license_waste_report`](#license_waste_report) | Shelfware seats, overage risk, renewal timeline | License optimisation, true-up preparation |
| [`llm_spend_summary`](#llm_spend_summary) | AI API spend by provider, model, team | AI cost governance, shadow AI detection |
| [`agent_performance`](#agent_performance) | Auto-execute rate, reversal rate, confidence trend | Trust expansion, agent accuracy reporting |
| [`supplier_compliance_summary`](#supplier_compliance_summary) | Compliance scores, blockers, document status | Compliance dashboard, onboarding status |

---

## Recommended Dashboard Set

### 1. Executive Procurement Dashboard
**Tool:** Tableau / Power BI  
**Refresh:** Daily

| Panel | View | Key fields |
|---|---|---|
| Total spend YTD | `spend_trend` | `sum(total_consumed_eur)` by `fiscal_year` |
| Spend vs budget (gauge) | `spend_trend` | `total_consumed_pct` |
| Spend by category (treemap) | `spend_trend` | `category`, `total_consumed_eur` |
| Spend by region (map) | `spend_trend` | `region`, `total_consumed_eur` |
| PO pipeline (funnel) | `po_analytics` | `po_status`, `count`, `sum(amount_eur)` |
| Top 10 suppliers by spend | `supplier_performance` | `supplier_name`, `total_po_value_eur` |
| Budget health (heat map) | `budget_command_center` | `branch_name`, `category`, `budget_health` |
| Agent auto-execute rate | `agent_performance` | `week`, `auto_execute_pct` |

---

### 2. Accounts Payable Dashboard
**Tool:** Tableau / Power BI / Metabase  
**Refresh:** Hourly

| Panel | View | Key fields |
|---|---|---|
| Invoice match rate (KPI) | `invoice_analytics` | `count(invoice_match_rate_pct)` |
| Dispute rate trend | `invoice_analytics` | `fiscal_month`, `invoice_dispute_rate_pct` |
| Outstanding invoices | `invoice_analytics` | `invoice_status = 'matched'` or `'disputed'` |
| Days to approval (histogram) | `invoice_analytics` | `days_to_approval` |
| ERP sync status | `invoice_analytics` | `erp_sync_status`, `erp_sync_attempts` |
| Payment due this week | `po_analytics` | `payment_due_date`, `payment_status` |
| Reverse charge flags | `invoice_analytics` | `reverse_charge = true` |
| Disputed invoices (drill-through) | `invoice_analytics` | `is_disputed = true` with supplier/PO detail |

---

### 3. Controlling Dashboard
**Tool:** Metabase (embedded) or Tableau  
**Refresh:** Real-time

| Panel | View | Key fields |
|---|---|---|
| Budget utilisation (heat map) | `budget_command_center` | `branch_name`, `category`, `consumed_pct`, `budget_health` |
| Committed vs spent vs available | `spend_trend` | `committed_eur`, `spent_eur`, `available_eur` |
| Overrun alerts | `budget_command_center` | `budget_health = 'overrun'` or `'critical'` |
| Commitment register | `commitment_register` | All columns — the accruals list |
| Overdue deliveries | `commitment_register` | `delivery_overdue = true` |
| Budget variance (plan vs actual) | `spend_trend` | `budget_plan_eur`, `total_consumed_eur`, `pct_of_plan` |
| Savings realised YTD | `savings_tracking` | `sum(term_saving_eur)` where `saving_pct > 0` |

---

### 4. Supplier Performance Dashboard
**Tool:** Tableau / Power BI  
**Refresh:** Daily

| Panel | View | Key fields |
|---|---|---|
| Supplier scorecard (table) | `supplier_performance` | All suppliers sorted by `supplier_score` |
| On-time delivery by supplier | `supplier_performance` | `supplier_name`, `on_time_delivery_pct` |
| Invoice quality by supplier | `supplier_performance` | `supplier_name`, `invoice_match_rate_pct` |
| Supplier health (traffic light) | `supplier_performance` | `current_health` |
| Strategic vs tail spend | `supplier_performance` | `strategic_tier`, `total_po_value_eur` |
| Renewals next 90 days | `supplier_performance` | `renewals_next_90d > 0` |
| Compliance status matrix | `supplier_compliance_summary` | `supplier_name`, `nda_doc_status`, `dpa_doc_status` |
| Lock-in risk heat map | `supplier_performance` | `supplier_name`, `lock_in_score`, `active_contract_value_eur` |

---

### 5. Procurement Efficiency Dashboard
**Tool:** Tableau / Power BI / Grafana  
**Refresh:** Daily

| Panel | View | Key fields |
|---|---|---|
| Request-to-PO time (KPI) | `approval_velocity` | `avg(minutes_to_po)` |
| Auto-execute vs one-touch vs escalate | `approval_velocity` | `disposition`, `count(*)` |
| Time-to-PO distribution (histogram) | `approval_velocity` | `time_to_po_bucket`, `count(*)` |
| Agent vs human speed comparison | `approval_velocity` | `agent_handled`, `avg(minutes_to_po)` |
| Auto-execute trend | `agent_performance` | `week`, `auto_execute_pct`, `avg_confidence_pct` |
| Reversal rate (accuracy proxy) | `agent_performance` | `week`, `reversed / total_decisions * 100` |
| Bottleneck categories | `approval_velocity` | `category`, `avg(minutes_to_po)` by `disposition` |

---

### 6. Savings & Benchmarking Dashboard
**Tool:** Tableau / Power BI  
**Refresh:** Weekly

| Panel | View | Key fields |
|---|---|---|
| Total savings identified (KPI) | `savings_tracking` | `sum(term_saving_eur)` |
| Pricing position by supplier | `savings_tracking` | `supplier_name`, `pricing_position` |
| Best-in-class vs above-market | `savings_tracking` | `pricing_position`, `count(*)` |
| Savings by category (bar) | `savings_tracking` | `category`, `sum(annual_saving_eur)` |
| Contracts at risk (above market) | `savings_tracking` | `pricing_position = 'above_market'` |
| Upcoming renewals with benchmark gap | `savings_tracking` | `days_to_expiry < 90`, `saving_pct < 0` |

---

## View Reference

---

### po_analytics

**One row per purchase order.** Enriched with supplier, branch, contract, invoice, payment, and timing metrics.

| Column | Type | Description |
|---|---|---|
| `po_id` | uuid | Purchase order ID |
| `po_number` | text | Readable PO number (PO-2026-DACH-0042) |
| `po_status` | text | draft / sent / acknowledged / delivered / invoiced / closed / cancelled |
| `category` | text | spend_category enum |
| `branch_id` | uuid | Branch UUID |
| `branch_name` | text | Branch display name |
| `region` | text | branch_region enum (DACH, UK_IE, etc.) |
| `cost_center_code` | text | Cost center code (matches ERP) |
| `supplier_id` | uuid | Supplier UUID |
| `supplier_name` | text | Supplier display name |
| `supplier_tier` | text | strategic / preferred / standard / tail |
| `supplier_health` | text | green / watch / red |
| `amount_eur` | numeric | Net amount in EUR |
| `total_amount` | numeric | Amount incl. VAT (original currency) |
| `po_date` | date | Date PO was issued |
| `expected_delivery` | date | Committed delivery date |
| `delivered_at` | timestamptz | Actual delivery confirmation |
| `fiscal_year` | int | Derived from po_date |
| `fiscal_quarter` | int | 1–4, derived from po_date |
| `iso_week` | text | ISO week (e.g. 2026-W22) for weekly charts |
| `cycle_time_days` | int | Days from PO creation to delivery confirmation |
| `delivery_overdue` | bool | true if sent/acknowledged past expected_delivery |
| `delivery_delta_days` | int | Negative = early, positive = late |
| `invoice_status` | text | Linked invoice status (null if no invoice yet) |
| `match_result` | text | matched / amount_mismatch / no_po / no_delivery |
| `invoiced_amount_eur` | numeric | Invoice amount in EUR |
| `payment_status` | text | pending / sent_to_erp / paid / failed |
| `erp_posted` | bool | Payment instruction posted to ERP |
| `days_to_invoice` | int | Days from delivery to invoice received |
| `days_to_payment_instruction` | int | Days from invoice to payment instruction created |

**Suggested filters in BI tool:** `po_status`, `category`, `branch_name`, `fiscal_year`, `supplier_tier`

---

### invoice_analytics

**One row per invoice.** Full AP view: match result, dispute flags, cycle times, ERP sync status.

| Column | Type | Description |
|---|---|---|
| `invoice_id` | uuid | Invoice UUID |
| `invoice_number` | text | Supplier's invoice reference |
| `invoice_status` | text | received / parsing / matched / disputed / approved / paid |
| `match_result` | text | matched / amount_mismatch / no_po / no_delivery |
| `supplier_name` | text | |
| `branch_name` | text | From linked PO |
| `category` | text | From linked PO |
| `po_number` | text | Linked PO number |
| `po_amount_eur` | numeric | PO amount (what we expected to pay) |
| `amount_eur` | numeric | Invoice amount |
| `match_delta_eur` | numeric | Difference between invoice and PO (abs) |
| `match_delta_pct` | numeric | Delta as % of PO amount |
| `vat_rate` | numeric | e.g. 0.19 for 19% |
| `reverse_charge` | bool | B2B cross-border reverse charge flag |
| `is_matched` | bool | Quick filter for matched invoices |
| `is_disputed` | bool | Quick filter for disputed invoices |
| `is_amount_dispute` | bool | Amount mismatch specifically |
| `is_orphan_invoice` | bool | No linked PO found |
| `days_to_match` | int | Processing time: received → matched |
| `days_to_approval` | int | Processing time: received → approved |
| `erp_sync_status` | text | pending / syncing / synced / failed / skipped |
| `erp_payment_reference` | text | ERP document number on successful sync |
| `erp_sync_error` | text | Error message if sync failed |
| `parsed_by_model` | text | AI model used for invoice parsing |

---

### spend_trend

**One row per branch × cost center × category × period.** The time-series budget data. Period is either quarterly (2026-Q2) or monthly (2026-05).

| Column | Type | Description |
|---|---|---|
| `branch_name` | text | |
| `region` | text | |
| `cost_center_code` | text | |
| `category` | text | |
| `period` | text | 2026-Q2 or 2026-05 |
| `period_start_date` | date | Derived — use for date axis in BI tools |
| `fiscal_year` | int | |
| `budget_plan_eur` | numeric | Planned amount from budget_buckets (Controlling's plan) |
| `budget_allocated_eur` | numeric | Allocated to this position |
| `committed_eur` | numeric | Approved POs not yet invoiced (encumbrance) |
| `spent_eur` | numeric | Invoiced and approved for payment |
| `available_eur` | numeric | budget - committed - spent |
| `total_consumed_eur` | numeric | committed + spent |
| `committed_pct` | numeric | committed / budget × 100 |
| `spent_pct` | numeric | spent / budget × 100 |
| `total_consumed_pct` | numeric | (committed + spent) / budget × 100 |
| `pct_of_plan` | numeric | total_consumed / budget_plan × 100 |
| `budget_health` | text | healthy / warn / critical / overrun |

**Key insight for BI:** `committed_eur` is the forward-looking encumbrance. `spent_eur` is historical. Most ERP reports show only `spent` — TrueSpend's differentiation is showing both.

---

### savings_tracking

**One row per contract × benchmark data point.** Only contracts with benchmark data appear.

| Column | Type | Description |
|---|---|---|
| `contract_name` | text | |
| `category` | text | |
| `contract_value_eur` | numeric | Total contract value |
| `supplier_name` | text | |
| `supplier_tier` | text | |
| `metric_name` | text | e.g. "price_per_seat", "monthly_api_cost" |
| `our_price` | numeric | What we pay |
| `market_median` | numeric | Market benchmark median |
| `market_low` | numeric | Best price in market sample |
| `market_high` | numeric | Highest price in market sample |
| `unit` | text | e.g. "per seat per year" |
| `sample_size` | int | Number of data points in benchmark |
| `saving_per_unit` | numeric | market_median - our_price (positive = we save) |
| `saving_pct` | numeric | Saving as % of market median |
| `annual_saving_eur` | numeric | saving_per_unit × contract volume |
| `term_saving_eur` | numeric | Annual saving × contract term years |
| `pricing_position` | text | best_in_class / below_market / above_median / above_market |
| `days_to_expiry` | int | Days until contract expires |
| `renewal_state` | text | clean / price_increase / volume_change / manual_required |

---

### supplier_performance

**One row per supplier.** Aggregated across all time.

| Column | Type | Description |
|---|---|---|
| `supplier_name` | text | |
| `primary_category` | text | |
| `current_health` | text | green / watch / red |
| `strategic_tier` | text | strategic / preferred / standard / tail |
| `supplier_score` | numeric | 0–100 weighted score (delivery 40% + invoice 30% + compliance 20% + health 10%) |
| `total_pos` | int | Lifetime PO count |
| `total_po_value_eur` | numeric | Lifetime spend |
| `on_time_delivery_pct` | numeric | % of deliveries on or before SLA |
| `avg_late_days` | numeric | Average delay for late deliveries |
| `invoice_match_rate_pct` | numeric | % of invoices that matched first time |
| `invoice_dispute_rate_pct` | numeric | % of invoices that went to dispute |
| `active_contracts` | int | Contracts currently active |
| `active_contract_value_eur` | numeric | Total active contract value |
| `renewals_next_90d` | int | Contracts expiring in next 90 days |
| `lock_in_score` | numeric | 0–10 (10 = extremely hard to exit) |
| `nda_status` | text | NDA document lifecycle status |
| `dpa_status` | text | DPA document lifecycle status |
| `compliance_status` | text | pending / running / green / amber / red / waived |

---

### approval_velocity

**One row per completed/actioned ticket.** Timing from request to PO.

| Column | Type | Description |
|---|---|---|
| `ticket_reference` | text | Human-readable ticket ID |
| `category` | text | |
| `branch_name` | text | |
| `disposition` | text | auto_execute / one_touch / escalate |
| `confidence` | numeric | Agent confidence score (0–1) |
| `agent_handled` | bool | true = agent auto-executed |
| `amount_eur` | numeric | Request amount |
| `minutes_to_decision` | int | Ticket created → decision made |
| `minutes_to_po` | int | Ticket created → PO created (end-to-end) |
| `minutes_decision_to_po` | int | Decision made → PO created |
| `time_to_po_bucket` | text | < 5 min / 5–60 min / 1–8 hrs / 8–24 hrs / 1–3 days / > 3 days |
| `fiscal_year` | int | |
| `fiscal_quarter` | int | |
| `iso_week` | text | For weekly trend charts |
| `po_number` | text | Resulting PO reference |

---

## Connecting Tableau

1. **New Data Source** → **PostgreSQL**
2. Server: `zephyr.proxy.rlwy.net` | Port: `24934`
3. Database: `truespend` | Username: `truespend`
4. Require SSL: ✅
5. Select schema: `public`
6. Available tables/views: all views listed above appear directly

**Recommended initial workbook structure:**
- Data source: `truespend_analytics` (single source connecting all 6 analytics views via relationships on `supplier_id`, `branch_id`)
- Sheet per dashboard panel
- Published to Tableau Server with row-level security on `branch_name` for regional managers

---

## Connecting Power BI

1. **Get Data** → **PostgreSQL database**
2. Server: `zephyr.proxy.rlwy.net:24934`
3. Database: `truespend`
4. Data Connectivity mode: **Import** (for snapshots) or **DirectQuery** (for real-time)
5. Navigator: select all analytics views
6. Advanced options → SSL: add `sslmode=require` to connection string

**DirectQuery note:** All 6 analytics views are index-optimised for direct query. `spend_trend` and `po_analytics` have dedicated indexes on date + dimension columns.

---

## Connecting Metabase (self-hosted)

1. **Admin** → **Databases** → **Add database**
2. Type: PostgreSQL
3. Host: `zephyr.proxy.rlwy.net` | Port: `24934`
4. Database: `truespend` | User: `truespend`
5. SSL: enabled
6. Schemas to sync: `public`

Metabase will detect all views automatically. Suggested question groups:
- `Procurement / PO Pipeline` — po_analytics
- `Procurement / Spend` — spend_trend, budget_command_center
- `Procurement / AP & Invoices` — invoice_analytics
- `Procurement / Suppliers` — supplier_performance, supplier_compliance_summary
- `Procurement / Efficiency` — approval_velocity, agent_performance

---

## Notes for BI Analysts

**Currency:** All `_eur` columns are normalised EUR values. Original currency and amount are also available for dual-currency analysis.

**Nulls in timing columns:** Timing columns (cycle_time_days, days_to_match, etc.) are null if the event hasn't happened yet. Filter `is not null` before averaging.

**Period format:** `spend_trend.period` uses two formats: `2026-Q2` (quarterly) and `2026-05` (monthly). The `period_start_date` derived column normalises both to a `date` type for BI tool date axes.

**Agent vs human:** In `approval_velocity`, `agent_handled = true` means the agent auto-executed with no human touch. This is the core metric for demonstrating TrueSpend ROI — compare `avg(minutes_to_po)` where `agent_handled = true` vs `false`.

**Supplier score methodology:** `supplier_performance.supplier_score` is a 0–100 weighted score: delivery SLA 40%, invoice match rate 30%, compliance status 20%, health signal 10%. Suppliers with no PO history default delivery/invoice components to 50% of max.
