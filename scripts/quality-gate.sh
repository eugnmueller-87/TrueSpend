#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# TrueSpend — Quality Gate
# Run before every push. Fails fast on any check.
# Usage:  bash scripts/quality-gate.sh
# Needs:  node (for JSON checks + build), bash
# ──────────────────────────────────────────────────────────────

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

pass() { echo -e "${GREEN}✓${NC} $1"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}✗${NC} $1"; FAIL=$((FAIL+1)); }
info() { echo -e "${YELLOW}→${NC} $1"; }

echo ""
echo "TrueSpend Quality Gate"
echo "────────────────────────────────────────"

# ── 0. Prerequisites ───────────────────────────────────────────
if ! command -v node &>/dev/null; then
  echo -e "${RED}node not found — install Node.js to run this gate${NC}"
  exit 1
fi

# ── 1. All JSON files must be valid ───────────────────────────
info "Checking JSON validity..."

JSON_FILES=(
  "workflows/automatic/contract_watcher.json"
  "workflows/automatic/hyperscaler_monitor.json"
  "workflows/automatic/reorder_trigger.json"
  "workflows/communication/supplier_reply_handler.json"
  "workflows/stakeholder/intake_receiver.json"
  "grafana/dashboards/truespend_main.json"
)

for f in "${JSON_FILES[@]}"; do
  if node -e "JSON.parse(require('fs').readFileSync('$f','utf8'))" 2>/dev/null; then
    pass "Valid JSON: $f"
  else
    fail "Invalid JSON: $f"
  fi
done

# ── 2. Schema field audit ─────────────────────────────────────
info "Auditing schema field names..."

SCHEMA="db/schema.sql"

check_schema_field() {
  local field="$1"
  local context="$2"
  if grep -q "$field" "$SCHEMA"; then
    pass "Schema field exists: $field ($context)"
  else
    fail "Schema MISSING field: $field — referenced in $context"
  fi
}

check_schema_field "order_reference"  "supplier_emails (H2)"
check_schema_field "alert_90_sent"    "contracts"
check_schema_field "auto_renew"       "contracts"
check_schema_field "renewal_state"    "contracts"
check_schema_field "projected_eur"    "hyperscaler_positions"
check_schema_field "committed_eur"    "hyperscaler_positions"
check_schema_field "reservation_util" "hyperscaler_positions"

# ── 3. View exists ────────────────────────────────────────────
info "Checking required views..."

if grep -q "contracts_expiring" "$SCHEMA"; then
  pass "View 'contracts_expiring' defined"
else
  fail "View 'contracts_expiring' missing from schema"
fi

# ── 4. reorder_trigger must not use invalid status filter ──────
info "Checking workflow filter correctness..."

REORDER="workflows/automatic/reorder_trigger.json"
if node -e "
  const w = JSON.parse(require('fs').readFileSync('$REORDER','utf8'));
  const text = JSON.stringify(w);
  if (text.includes('status.eq.active')) process.exit(1);
" 2>/dev/null; then
  pass "reorder_trigger: no invalid 'status.eq.active' filter"
else
  fail "reorder_trigger: filters on 'status.eq.active' — contracts has no status column (M5)"
fi

# ── 5. hyperscaler_monitor must use correct schema field names ─
info "Checking hyperscaler_monitor field names..."

HYPER="workflows/automatic/hyperscaler_monitor.json"

node -e "
  const fs = require('fs');
  const text = fs.readFileSync('$HYPER','utf8');
  let ok = true;
  const stale = ['projected_spend_eur','committed_spend_eur','reservation_utilization'];
  stale.forEach(f => {
    if (text.includes(f)) {
      console.error('STALE:' + f);
      ok = false;
    }
  });
  process.exit(ok ? 0 : 1);
" && pass "hyperscaler_monitor: field names match schema" || fail "hyperscaler_monitor: stale field names found (H1) — run: node -e to see which"

# ── 6. trace_log signal enum values ───────────────────────────
info "Checking trace_log signal enum values..."

VALID_SIGNALS='contract|consumption|supplier|request|policy'

node -e "
  const fs = require('fs');
  const files = [
    'workflows/automatic/contract_watcher.json',
    'workflows/automatic/hyperscaler_monitor.json',
    'workflows/automatic/reorder_trigger.json',
    'workflows/communication/supplier_reply_handler.json',
    'workflows/stakeholder/intake_receiver.json',
  ];
  const valid = ['contract','consumption','supplier','request','policy'];
  let bad = [];
  files.forEach(f => {
    const text = fs.readFileSync(f,'utf8');
    const matches = [...text.matchAll(/\"signal\"\s*:\s*\"([^\"]+)\"/g)];
    matches.forEach(m => {
      if (!valid.includes(m[1])) bad.push(m[1] + ' in ' + f);
    });
  });
  if (bad.length) { bad.forEach(b => console.error('INVALID SIGNAL: ' + b)); process.exit(1); }
" && pass "All trace_log signal values are valid enum members" || fail "Invalid signal_type values found (L2)"

# ── 7. intake UI: branch_id values must be UUIDs ──────────────
info "Checking intake UI branch_id..."

UUID_RE="[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"

node -e "
  const fs = require('fs');
  const src = fs.readFileSync('intake/src/App.jsx','utf8');
  // Extract only the BRANCHES constant block
  const branchBlock = src.match(/const BRANCHES\s*=\s*\[([\s\S]*?)\]/);
  if (!branchBlock) { console.error('BRANCHES constant not found'); process.exit(1); }
  const uuidRe = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/g;
  const uuids = [...branchBlock[1].matchAll(uuidRe)];
  if (uuids.length < 10) {
    console.error('Expected 10 UUID branch ids in BRANCHES, found ' + uuids.length);
    process.exit(1);
  }
" && pass "intake: branch_id values are UUIDs (10 branches)" || fail "intake: branch_id not using UUIDs (M4)"

# ── 8. .env.example covers docker-compose vars ────────────────
info "Checking .env.example completeness..."

node -e "
  const fs = require('fs');
  const compose = fs.readFileSync('infra/docker-compose.yml','utf8');
  const example = fs.readFileSync('.env.example','utf8');
  const matches = [...compose.matchAll(/\\\$\{([A-Z_][A-Z0-9_]*)\}/g)].map(m => m[1]);
  const unique = [...new Set(matches)];
  const missing = unique.filter(v => !example.includes(v + '='));
  if (missing.length) {
    console.error('Missing from .env.example: ' + missing.join(', '));
    process.exit(1);
  }
" && pass ".env.example covers all docker-compose variables" || fail ".env.example missing some docker-compose variables"

# ── 9. Intake Vite build ───────────────────────────────────────
info "Building intake UI..."
cd intake

if [ ! -d node_modules ]; then
  info "Installing dependencies (first run)..."
  npm ci --silent 2>&1 | tail -3
fi

if npm run build 2>&1 | tail -6; then
  pass "Vite build succeeded"
else
  fail "Vite build FAILED — fix build errors before pushing"
fi

cd ..

# ── Summary ────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────"
echo -e "Results: ${GREEN}${PASS} passed${NC}  ${RED}${FAIL} failed${NC}"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo -e "${RED}Quality gate FAILED. Fix the above before pushing.${NC}"
  exit 1
else
  echo -e "${GREEN}Quality gate PASSED. Safe to push.${NC}"
  exit 0
fi
