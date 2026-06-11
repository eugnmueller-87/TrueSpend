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

# ── S. Security checks (run first — hard block) ───────────────
info "Running security checks..."

JWT_PATTERN='eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'

# Scan all tracked workflow + source files for hardcoded JWTs
SECRET_HITS=$(git ls-files -- 'workflows/*.json' 'workflows/**/*.json' 'intake/src/**' \
  | grep -v '.env.example' \
  | xargs grep -lP "$JWT_PATTERN" 2>/dev/null || true)

if [ -n "$SECRET_HITS" ]; then
  fail "Hardcoded JWT found in tracked files:"
  echo "$SECRET_HITS" | while read -r f; do echo "    $f"; done
  echo -e "  ${YELLOW}→ Replace with \$env.POSTGREST_JWT in n8n code nodes${NC}"
else
  pass "No hardcoded JWTs in workflows or source"
fi

# Check for private keys in tracked files
# Use regex anchored to start-of-line to match actual key blocks, not grep patterns in scripts
KEY_HITS=$(git ls-files | grep -v '^scripts/' | grep -v '.env.example' \
  | xargs grep -lE '^-----BEGIN (RSA |EC )?PRIVATE KEY-----' 2>/dev/null || true)

if [ -n "$KEY_HITS" ]; then
  fail "Private key found in tracked files: $KEY_HITS"
else
  pass "No private keys in tracked files"
fi

# intake/dist/ must not be tracked
DIST_TRACKED=$(git ls-files intake/dist/ 2>/dev/null || true)
if [ -n "$DIST_TRACKED" ]; then
  fail "intake/dist/ is tracked by git — run: git rm -r --cached intake/dist/"
else
  pass "intake/dist/ is not tracked by git"
fi

# All workflow code nodes must use \$env not hardcoded URLs in auth headers
HARDCODED_AUTH=$(git ls-files -- 'workflows/*.json' 'workflows/**/*.json' \
  | xargs grep -lP '"Authorization".*"Bearer eyJ' 2>/dev/null || true)

if [ -n "$HARDCODED_AUTH" ]; then
  fail "Hardcoded Bearer token in workflow Authorization header:"
  echo "$HARDCODED_AUTH" | while read -r f; do echo "    $f"; done
else
  pass "No hardcoded Bearer tokens in workflow headers"
fi

# ── 0. Prerequisites ───────────────────────────────────────────
if ! command -v node &>/dev/null; then
  echo -e "${RED}node not found — install Node.js to run this gate${NC}"
  exit 1
fi

# ── 1. All JSON files must be valid ───────────────────────────
info "Checking JSON validity..."

# Auto-discover all tracked workflow + grafana dashboard JSON so every current
# and future workflow is validated without editing this list.
mapfile -t JSON_FILES < <(git ls-files -- 'workflows/**/*.json' 'grafana/dashboards/*.json')

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

# ── 8a. Migrations are dbmate-shaped + ordered (Phase 3) ──────────
info "Checking migration files (dbmate format + ordering)..."
node -e "
  const fs = require('fs');
  const dir = 'db/migrations';
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.sql'));
  let bad = [];
  const versions = [];
  for (const f of files) {
    const m = f.match(/^(\d{6})_[a-z0-9_]+\.sql\$/);
    if (!m) { bad.push(f + ' — not NNNNNN_slug.sql'); continue; }
    versions.push(parseInt(m[1], 10));
    const body = fs.readFileSync(dir + '/' + f, 'utf8');
    if (!/^-- migrate:up/m.test(body))   bad.push(f + ' — missing -- migrate:up');
    if (!/^-- migrate:down/m.test(body)) bad.push(f + ' — missing -- migrate:down');
  }
  const dupes = versions.filter((v,i) => versions.indexOf(v) !== i);
  if (dupes.length) bad.push('duplicate versions: ' + [...new Set(dupes)].join(','));
  if (bad.length) { bad.forEach(b => console.error('  ' + b)); process.exit(1); }
  console.error('  ' + versions.length + ' migrations, well-formed and unique');
" && pass "Migrations: dbmate format + unique ordering" || fail "Migration files malformed (see above) — db/migrations/ must be NNNNNN_slug.sql with up/down markers"

# ── 8b. Workflow guards in sync + prompt-injection repro (Phase 1) ─
info "Checking workflow guards (LLM-advises-code-decides boundary)..."

if node scripts/sync-workflow-guards.js >/dev/null 2>&1; then
  pass "Workflow guards in sync with workflows/lib/"
else
  fail "Workflow guard DRIFT — run: node scripts/sync-workflow-guards.js --write"
fi

if node workflows/__tests__/phase1_repro.test.js >/dev/null 2>&1; then
  pass "Prompt-injection repro: holes proven on pre-fix snapshot, inert after fix"
else
  fail "Phase 1 repro/guard test FAILED — node workflows/__tests__/phase1_repro.test.js"
fi

# ── 8c. Hygiene: no placeholder sender / no bare prod URL in live workflows (Phase 5)
info "Checking workflow hygiene (sender email + prod URL)..."
node -e "
  const fs = require('fs'), path = require('path');
  const dirs = ['workflows/automatic','workflows/stakeholder','workflows/communication','workflows/monitoring'];
  const LIT = 'postgrest-production-7960.up.railway.app';
  let bad = [];
  for (const d of dirs) {
    if (!fs.existsSync(d)) continue;
    for (const f of fs.readdirSync(d).filter(x => x.endsWith('.json'))) {
      const fp = path.join(d, f);
      const t = fs.readFileSync(fp, 'utf8');
      if (t.includes('procurement@company.com')) bad.push(fp + ' — placeholder sender procurement@company.com');
      // every prod URL literal must be guarded by the env-fallback pattern
      const bare = t.split(LIT).length - 1;
      const guarded = (t.match(/POSTGREST_URL \|\| '[^']*'/g) || []).length
                    + (t.match(/POSTGREST_URL \|\| \"[^\"]*\"/g) || []).length;
      if (bare > guarded) bad.push(fp + ' — ' + (bare - guarded) + ' bare prod URL literal(s) not behind \$env.POSTGREST_URL');
    }
  }
  if (bad.length) { bad.forEach(b => console.error('  ' + b)); process.exit(1); }
  console.error('  live workflows: no placeholder senders, all prod URLs env-guarded');
" && pass "Workflow hygiene: env-guarded URLs + no placeholder senders" || fail "Workflow hygiene defects (see above) — Phase 5"

# ── 9. Intake Vite build ───────────────────────────────────────
info "Building intake UI..."
cd intake

if [ ! -d node_modules ]; then
  info "Installing dependencies..."
  if [ -f package-lock.json ]; then
    npm ci --silent 2>&1 | tail -3
  else
    npm install --silent 2>&1 | tail -3
  fi
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
