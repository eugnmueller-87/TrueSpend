# Data Model

Single source of truth: `db/schema.sql`

## Enums (schema.sql:33–226)

| Enum | Values |
|---|---|
| `branch_region` | DACH, BENELUX, NORDICS, UK_IE, FRANCE, IBERIA, ITALY, CEE, NORDICS_EAST, GLOBAL_HQ |
| `spend_category` | hardware, hyperscaler, saas_license, ai_consumption, services, facilities, telecoms, other |
| `renewal_state` | clean, price_increase, volume_change, scope_change, manual_required |
| `disposition` | auto_execute, one_touch, escalate |
| `ticket_source` | automatic, intake, jira, renewal, monitoring, compliance |
| `ticket_status` | open, reasoning, pending_confirm, pending_review, signature_required, approved, rejected, escalated, closed |
| `supplier_health` | green, watch, red |
| `signal_type` | contract, consumption, supplier, request, policy, budget, compliance, asset, license, intake, reorder, contract_renewal |
| `doc_type` | nda, dpa, tom, scc, coc, lksg |
| `doc_status` | not_required, generating, generated, sent, signed, filed, rejected, expired |
| `compliance_status` | pending, running, green, amber, red, waived |
| `asset_status` | ordered, active, in_repair, decommissioning, disposed |
| `depreciation_method` | straight_line, declining_balance, sum_of_years_digits |
| `po_status` | draft, sent, acknowledged, delivered, invoiced, closed, cancelled |
| `invoice_status` | received, parsing, matched, disputed, approved, paid, rejected |
| `erp_sync_status` | pending, syncing, synced, failed, skipped |
| `license_type` | named_user, concurrent, device, capacity, site, enterprise |
| `clause_type` | auto_renew, price_escalation, true_up, audit_rights, exit_penalty, most_favoured_nation, bench_review, data_processing, liability_cap, force_majeure, governing_law |
| `change_type` | price_increase, volume_change, scope_change, term_change, currency_change, clause_addition |

KNOWN VIOLATION: Live DB `spend_category` enum has no `ai_consumption` value — use `other`. (`CLAUDE.md:67`)

## Tables by Domain

### Organization (schema.sql:232–308)

**branches** (schema.sql:234)
Key columns: `id` UUID PK, `name`, `region` branch_region, `country`, `currency`, `legal_name`, `po_prefix` (e.g. "DACH" → PO-DACH-2026-0042), `annual_budget`, `po_email`, `erp_company_code`

**cost_centers** (schema.sql:259)
Key columns: `id` UUID PK, `code` unique, `branch_id` FK→branches, `gl_account`, `budget_owner_id` FK→users, `annual_budget`

**users** (schema.sql:277)
Key columns: `id` UUID PK, `email` unique, `name`, `role` text (see role values below), `branch_ids` uuid[], `spend_authority` numeric, `spend_authority_by_category` jsonb, `jira_account_id`, `active` bool
Role values: `procurement_manager`, `head_of_procurement`, `category_manager`, `it_manager`, `budget_owner`, `requester`, `controlling`, `admin`, `ops_manager`

### Suppliers (schema.sql:312–356)

**suppliers** (schema.sql:315)
Key columns: `id` UUID PK, `name`, `category` spend_category, `health` supplier_health, `compliance_status` compliance_status, `nda_status` doc_status, `dpa_status` doc_status, `infosec_score` 0-100, `processes_personal_data`, `data_residency`, `iso27001`, `soc2`, `strategic_tier` (strategic/preferred/standard/tail), `lock_in_score` 0-10

### Contracts (schema.sql:360–438)

**contracts** (schema.sql:363)
Key columns: `id` UUID PK, `supplier_id` FK, `branch_id` FK, `owner_id` FK→users, `name`, `category` spend_category, `value`, `value_eur`, `start_date`, `expiry_date`, `notice_days`, `auto_renew` bool, `renewal_state`, `escalation_clause`, `escalation_rate`, `lock_in_score`, `alert_90_sent`, `alert_60_sent`, `alert_30_sent`

**contract_changes** (schema.sql:405)
Key columns: `contract_id` FK, `change_type`, `previous_value`, `proposed_value`, `delta_pct`, `delta_eur`, `market_rate_pct`, `agent_assessment`, `recommended_position`, `walk_away_value`, `accepted` bool

**contract_clauses** (schema.sql:426)
Key columns: `contract_id` FK, `clause_type`, `clause_text`, `extracted_value`, `financial_impact_eur`, `flagged` bool, `extraction_model` default='claude-sonnet-4-6'

### Budget (schema.sql:444–525)

**budget_buckets** (schema.sql:447)
The annual plan. Key: `branch_id + cost_center_id + category + fiscal_year + quarter` (unique constraint). Columns: `planned_amount`, `set_by_user_id`, `approved_by`

**budget_positions** (schema.sql:470)
The running ledger. Key: `branch_id + cost_center_id + category + period` (unique). Columns: `budget`, `committed`, `spent`, `available` (generated: budget - committed - spent)

**budget_pools** (schema.sql:488)
CFO reserve. Columns: `branch_id`, `fiscal_year`, `total_amount`, `committed`, `available` (generated), `draw_authority`

**budget_reallocations** (schema.sql:506)
Immutable audit trail. Columns: `from_type`, `from_id`, `to_type`, `to_id`, `amount`, `reason`, `requested_by`, `approved_by`, `ticket_id`

### P2I — Purchase to Invoice (schema.sql:528–664)

**purchase_orders** (schema.sql:533)
Key columns: `id` UUID PK, `po_number` unique (PO-{YEAR}-{BRANCH}-{SEQ}), `ticket_id` FK, `supplier_id` FK, `branch_id` FK, `description`, `category`, `line_items` jsonb, `amount`, `amount_eur`, `expected_delivery`, `delivered_at`, `status` po_status, `delivery_overdue` (generated: status=sent AND expected_delivery < current_date)

**po_sequences** (schema.sql:573)
PK: `branch_id + fiscal_year`. `last_seq` int. Used by `next_po_number()` RPC for atomic PO numbering.

**invoices** (schema.sql:581)
Key columns: `po_id` FK, `supplier_id` FK, `invoice_number`, `invoice_date`, `amount`, `amount_eur`, `vat_rate`, `reverse_charge`, `match_result` (matched/amount_mismatch/no_po/no_delivery), `match_tolerance_pct` default=0.02, `status` invoice_status, `parsed_by_model` default='claude-sonnet-4-6', `raw_extraction` jsonb

**payment_instructions** (schema.sql:618)
Key columns: `invoice_id` FK, `po_id` FK, `supplier_id` FK, `amount`, `payment_ref`, `due_date`, `erp_posted`, `erp_reference`, `status` (pending/sent_to_erp/paid/failed)

**erp_sync_queue** (schema.sql:639)
Key columns: `event_type` (po_created/invoice_approved/payment_instruction/vendor_created/budget_update/asset_disposal), `entity_type`, `entity_id`, `payload` jsonb, `erp_system`, `status` erp_sync_status, `attempts`, `erp_response` jsonb

### Assets (schema.sql:668–736)

**assets** (schema.sql:671)
Key columns: `asset_tag` unique, `category` text, `make`, `model`, `serial_number`, `specs` jsonb, `po_id` FK, `purchase_cost`, `purchase_cost_eur`, `depreciation_method`, `useful_life_months`, `residual_value`, `accumulated_depreciation`, `current_book_value`, `warranty_expiry`, `branch_id`, `cost_center_id`, `assigned_user`, `status` asset_status, `disposal_method`, `disposal_reference`

**asset_depreciation_log** (schema.sql:722)
Key columns: `asset_id` FK, `period` (2026-05), `depreciation_amount`, `book_value_before`, `book_value_after`, `method_used`, `gl_account`, `cost_center_code`, `journal_entry_ref`, `posted` bool

### Licenses (schema.sql:740–817)

**license_entitlements** (schema.sql:745)
Key columns: `contract_id`, `supplier_id`, `product_name`, `license_type`, `total_seats`, `assigned_seats`, `active_seats`, `available_seats` (generated), `shelfware_seats`, `overage_seats`, `true_up_date`, `price_per_seat`, `utilization_pct`, `term_end`

**license_assignments** (schema.sql:797)
Key columns: `entitlement_id` FK, `assigned_to_user` text (email), `assigned_to_asset_id` FK, `cost_center_id`, `ticket_id`, `last_active_at`, `active` bool, `reclaimed_at`

### Consumption (schema.sql:820–917)

**hyperscaler_positions** (schema.sql:825)
Key columns: `provider` (AWS/GCP/Azure), `account_id`, `service_name`, `period`, `committed_eur`, `mtd_spend_eur`, `projected_eur`, `reservation_util`, `overshoot_risk`, `undershoot_risk`, `snapshot_date`

**llm_api_keys** (schema.sql:857)
Key columns: `provider`, `key_alias` (last 4 chars only), `owner_email`, `monthly_limit_usd`, `alert_threshold_pct`, `status`

**llm_consumption** (schema.sql:883)
Key columns: `api_key_id`, `provider`, `model`, `branch_id`, `period`, `input_tokens`, `output_tokens`, `total_tokens` (generated), `cost_usd`, `cost_eur`, `anomaly_detected`, `prior_7d_avg_cost_usd`

### Operations (schema.sql:921–1035)

**tickets** (schema.sql:925)
Key columns: `id` UUID PK, `reference` unique (TS-YYYY-XXXX), `source` ticket_source, `status` ticket_status, `title`, `description`, `category` spend_category (denormalized to avoid correlated subquery), `branch_id`, `cost_center_id`, `supplier_id`, `contract_id`, `requested_by` text (email), `requester_id` FK→users, `amount`, `amount_eur`, `review_type` (major_contract/compliance_flag/signature/budget_overrun), `pdf_url`, `po_id` FK, `jira_key`, `target_close`

**decisions** (schema.sql:982)
Key columns: `ticket_id` FK, `contract_id` FK, `disposition`, `confidence` 0.0–1.0, `reasoning`, `recommendation`, `brief`, `budget_available_eur`, `budget_bucket_pct`, `outcome`, `actioned_by`, `model_used` default='claude-sonnet-4-6'

**trace_log** (schema.sql:1010)
Key columns: `decision_id` FK (no ticket_id FK — KNOWN VIOLATION from schema divergence), `signal` signal_type, `value`, `weight`, `green` bool, `notes`

**supplier_emails** (schema.sql:1022)
Key columns: `supplier_id` FK, `contract_id` FK, `direction` (inbound/outbound), `subject`, `body_summary`, `commitments` text[], `order_reference`, `flagged`

### Compliance (schema.sql:1038–1094)

**legal_documents** (schema.sql:1043)
Key columns: `supplier_id` FK (no ticket_id — KNOWN VIOLATION), `doc_type`, `status` doc_status, `content`, `company_name`, `supplier_name`, `governing_law`, `generated_at`, `sent_at`, `signed_at`, `expires_at`. UNIQUE: `(supplier_id, doc_type)`

**compliance_checks** (schema.sql:1069)
Key columns: `supplier_id` FK, `check_type` (lawyer/gdpr/infosec/lksg/ethics), `status` compliance_status, `score` 0-100, `passed` bool, `findings` text[], `blockers` text[], `recommendations` text[], `docs_required` doc_type[], `model_used`

### Intelligence (schema.sql:1097–1153)

**vendor_pricing_benchmarks** (schema.sql:1103)
Key columns: `supplier_id`, `product_name`, `list_price`, `typical_discount_pct`, `floor_price_pct`, `pricing_model`, `competitor_products` jsonb

**trust_settings** (schema.sql:1130)
Key columns: `branch_id` (null=org-wide), `category` (null=all), `auto_execute_threshold_eur` default=10000, `one_touch_threshold_eur` default=100000, `min_confidence_auto` default=0.95, `total_decisions`, `auto_executed`, `reversed_by_human`, `accuracy_pct`

### Operations / Monitoring (schema.sql:2002)

**workflow_runs** (schema.sql:2003)
Key columns: `workflow_name`, `n8n_execution_id`, `started_at`, `completed_at`, `duration_ms` (generated), `status` (running/success/partial/failed), `records_processed`, `records_errored`, `summary`, `error_message`, `error_node`

## Views (schema.sql:1156–1440)

| View | Purpose | Where Used |
|---|---|---|
| `contracts_expiring` (schema.sql:1161) | Contracts expiring ≤90 days with supplier/branch/owner join | contract_watcher.json |
| `open_tickets_board` (schema.sql:1192) | Operations Board — open tickets with supplier, budget position, decisions, PO context. Sort: sig_required→1, pending_confirm→2, pending_review→3, escalated→4 | App.jsx:1026 |
| `budget_command_center` (schema.sql:1273) | Branch × category × period budget health. budget_status: overrun/critical/warn/healthy | Budget screen |
| `commitment_register` (schema.sql:1306) | Open POs not yet invoiced — Controlling's accrual list | Orders screen |
| `license_waste_report` (schema.sql:1337) | Entitlements with shelfware or overage | VERIFY: no direct UI use found |
| `llm_spend_summary` (schema.sql:1365) | LLM cost by provider/model/team/period | Grafana dashboards |
| `agent_performance` (schema.sql:1391) | Weekly auto_execute%, avg confidence | Grafana dashboards |
| `supplier_compliance_summary` (schema.sql:1412) | Per-supplier compliance scores + doc status | Suppliers screen |
| `po_analytics` (schema.sql:2063) | Full PO pipeline — cycle time, SLA, invoice, payment linkage | BI tools / Grafana |
| `invoice_analytics` (schema.sql:2168) | Invoice match rates, dispute analysis, payment cycle | BI tools / Grafana |

`open_tickets_board` exposes: `branch_id`, `cost_center_id`, `submitted_by`, `submitted_by_email`, `confidence_score` (alias of `t.confidence`), `value_eur`, `category`. `po_delivery_overdue` is computed inline.

## RPCs (all SECURITY DEFINER — schema.sql:1603–1994)

All callable via PostgREST: `POST /rpc/{function_name}`

### commit_budget (schema.sql:1613)
```sql
commit_budget(p_branch_id, p_cost_center_id, p_category, p_period, p_amount)
  → budget_positions
```
Row-level lock (`FOR UPDATE`). Raises if insufficient. Increments `committed`.

### release_budget (schema.sql:1655)
```sql
release_budget(p_branch_id, p_cost_center_id, p_category, p_period, p_amount)
  → budget_positions
```
Decrements `committed` (floor: 0). Called on rejection or cancellation.

### record_spend (schema.sql:1693)
```sql
record_spend(p_branch_id, p_cost_center_id, p_category, p_period,
             p_committed_release, p_spend_amount) → budget_positions
```
Releases committed (PO amount), increments spent (invoice amount). Called from `create_payment_instruction`.

### next_po_number (schema.sql:1743)
```sql
next_po_number(p_branch_id, p_branch_code) → text
```
Atomic sequence via `po_sequences` table. Format: `PO-{YEAR}-{BRANCH_CODE}-{SEQ:04}`.

### approve_and_commit (schema.sql:1764)
```sql
approve_and_commit(p_ticket_id, p_branch_id, p_branch_code, p_cost_center_id,
                   p_category, p_period, p_supplier_id, p_contract_id,
                   p_description, p_amount, p_currency, p_amount_eur,
                   p_raised_by, p_expected_delivery, p_line_items) → purchase_orders
```
Atomic: (1) next_po_number, (2) commit_budget, (3) INSERT purchase_orders, (4) UPDATE tickets set status=approved, po_id.

### confirm_delivery (schema.sql:1816)
```sql
confirm_delivery(p_po_id, p_confirmed_by) → purchase_orders
```
Sets PO status=delivered, delivered_at=now. If late (current_date > expected_delivery): appends `[LATE: N days]` to notes, sets supplier health green→watch.

### match_invoice (schema.sql:1863)
```sql
match_invoice(p_invoice_id) → invoices
```
3-way match logic: checks po_id exists, PO status in (delivered/invoiced/closed), amount delta ≤ 2% tolerance. Returns match_result: matched/amount_mismatch/no_po/no_delivery.

### create_payment_instruction (schema.sql:1921)
```sql
create_payment_instruction(p_invoice_id, p_due_date) → payment_instructions
```
Creates PI record, sets invoice status=approved, writes `erp_sync_queue` entry (event_type=invoice_approved), calls `record_spend`.

### search_documents_text (VERIFY: in db/migrations/rag_schema.sql — not in main schema.sql)
```sql
search_documents_text(query_text, filter_doc_type, filter_supplier, result_limit)
```
Full-text search via tsvector on `document_embeddings`. PostgREST: `POST /rpc/search_documents_text`.

## Indexes (schema.sql:1443–1525)

Performance-critical:
- `idx_budget_pos_lookup` — covering index on `budget_positions(branch_id, category, period)` INCLUDE (budget, committed, spent, available). Budget check answered from index.
- `idx_tickets_board` — partial index on `tickets(status, created_at)` WHERE status IN (open, pending_confirm, pending_review, signature_required, escalated). Operations Board uses index-only scan.
- `idx_tickets_category` — partial on `tickets(category)` WHERE category IS NOT NULL. For budget join in open_tickets_board.
