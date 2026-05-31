#!/usr/bin/env bash
# =============================================================================
# TrueSpend — db-migrate.sh
# Applies ordered SQL migrations from db/migrations/ to $DATABASE_URL.
#
# Usage:
#   DATABASE_URL=postgresql://... bash scripts/db-migrate.sh
#   bash scripts/db-migrate.sh --dry-run          # print plan, apply nothing
#   bash scripts/db-migrate.sh --status           # show applied/pending only
#
# How it works:
#   1. Creates schema_migrations table if it doesn't exist.
#   2. Reads migration files in the fixed MIGRATION_ORDER list below.
#   3. Skips files already recorded in schema_migrations.
#   4. Applies pending files in a transaction; records name + sha256 on success.
#   5. Halts on first failure — does NOT skip or continue past errors.
#
# Definition of done: a db/migrations change is only "done" once this script
# runs green against prod and the migration name appears in schema_migrations.
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRATIONS_DIR="$REPO_ROOT/db/migrations"

# ── Canonical migration order ─────────────────────────────────────────────────
# Add new migrations to the END of this list. Never reorder existing entries.
MIGRATION_ORDER=(
  "cost_centers_seed.sql"
  "step2_rpc_boundary.sql"
  "step2c_demote_truespend.sql"
  "step2d_truespend_app_role.sql"
  "step3_invoice_rpc_grants.sql"
  "step4_rls_truespend_app.sql"
  "step5_action_ledger.sql"
)

# ── Args ──────────────────────────────────────────────────────────────────────
DRY_RUN=0
STATUS_ONLY=0
for arg in "$@"; do
  case $arg in
    --dry-run)   DRY_RUN=1 ;;
    --status)    STATUS_ONLY=1 ;;
    *) echo "Unknown arg: $arg"; exit 1 ;;
  esac
done

# ── Require DATABASE_URL ──────────────────────────────────────────────────────
if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "ERROR: DATABASE_URL is not set."
  echo "  Export it or prefix: DATABASE_URL=postgresql://... bash scripts/db-migrate.sh"
  exit 1
fi

# ── psql wrapper — uses DATABASE_URL, no SSL (Railway internal) ───────────────
psql_cmd() {
  PGSSLMODE=disable psql "$DATABASE_URL" "$@"
}

# ── Bootstrap tracking table (idempotent) ─────────────────────────────────────
psql_cmd -v ON_ERROR_STOP=1 -q <<'SQL'
create table if not exists schema_migrations (
  name         text        primary key,
  applied_at   timestamptz not null default now(),
  checksum     text        not null
);
SQL

# ── Fetch already-applied migrations ─────────────────────────────────────────
applied=$(psql_cmd -t -A -c "select name from schema_migrations order by applied_at")

# ── Determine pending ─────────────────────────────────────────────────────────
pending=()
for migration in "${MIGRATION_ORDER[@]}"; do
  if echo "$applied" | grep -qx "$migration"; then
    echo "  [skip]    $migration (already applied)"
  else
    pending+=("$migration")
    echo "  [pending] $migration"
  fi
done

echo ""

if [[ ${#pending[@]} -eq 0 ]]; then
  echo "✓ All migrations up to date. Nothing to apply."
  exit 0
fi

if [[ $STATUS_ONLY -eq 1 ]]; then
  echo "${#pending[@]} migration(s) pending. Run without --status to apply."
  exit 0
fi

if [[ $DRY_RUN -eq 1 ]]; then
  echo "DRY RUN — would apply ${#pending[@]} migration(s):"
  for m in "${pending[@]}"; do echo "  $m"; done
  exit 0
fi

# ── Apply pending migrations ──────────────────────────────────────────────────
echo "Applying ${#pending[@]} migration(s)..."
echo ""

for migration in "${pending[@]}"; do
  filepath="$MIGRATIONS_DIR/$migration"
  if [[ ! -f "$filepath" ]]; then
    echo "ERROR: File not found: $filepath"
    exit 1
  fi

  checksum=$(sha256sum "$filepath" | awk '{print $1}')
  echo "→ Applying: $migration (sha256: ${checksum:0:12}…)"

  # Apply in a transaction; record in schema_migrations on success
  PGSSLMODE=disable psql "$DATABASE_URL" \
    -v ON_ERROR_STOP=1 \
    -v migration_name="$migration" \
    -v migration_checksum="$checksum" \
    --single-transaction \
    -f "$filepath" \
    -c "insert into schema_migrations (name, checksum) values (:'migration_name', :'migration_checksum')
        on conflict (name) do update set applied_at = now(), checksum = :'migration_checksum';" \
    2>&1 | grep -v "^$" | sed "s/^/  /"

  echo "  ✓ $migration applied and recorded"
  echo ""
done

echo "✓ Migration complete. Applied ${#pending[@]} file(s)."
echo ""
echo "Applied migrations:"
psql_cmd -t -A -c "select name, applied_at from schema_migrations order by applied_at" \
  | sed 's/^/  /'
