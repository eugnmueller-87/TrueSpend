#!/usr/bin/env bash
# =============================================================================
# TrueSpend — db-migrate.sh  (Phase 3: thin dbmate wrapper)
#
# dbmate is the canonical migration runner. Migrations live in db/migrations/
# as immutable version-ordered NNNNNN_slug.sql files with -- migrate:up /
# -- migrate:down markers (I-8 by convention: never edit an applied migration;
# add a new one). dbmate tracks applied versions in the schema_migrations table.
#
# Usage (unchanged CLI surface so CI + docs keep working):
#   DATABASE_URL=postgresql://... bash scripts/db-migrate.sh            # apply pending
#   bash scripts/db-migrate.sh --status                                 # show status
#   bash scripts/db-migrate.sh --dry-run                                # plan only
#
# FIRST-TIME CUTOVER from the old bespoke runner: run db/reconcile_dbmate_ledger.sql
# ONCE against prod before the first `dbmate up`, or dbmate will re-run every
# migration. See docs/decisions/ADR-007-dbmate.md.
#
# Definition of done (I-8): a migration is "done" only once dbmate has applied it
# against prod and its version appears in schema_migrations.
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "ERROR: DATABASE_URL is not set."
  echo "  Prefix: DATABASE_URL=postgresql://... bash scripts/db-migrate.sh"
  exit 1
fi

# dbmate honors DATABASE_URL directly. Railway internal has no SSL; if your URL
# needs it, append ?sslmode=disable. Config (migrations dir, schema file, no
# auto-dump) lives in db/dbmate.yml.
export DBMATE_MIGRATIONS_DIR="${DBMATE_MIGRATIONS_DIR:-db/migrations}"
export DBMATE_NO_DUMP_SCHEMA="${DBMATE_NO_DUMP_SCHEMA:-true}"

if ! command -v dbmate >/dev/null 2>&1; then
  echo "ERROR: dbmate not found. Install it:"
  echo "  macOS:   brew install dbmate"
  echo "  linux:   sudo curl -fsSL -o /usr/local/bin/dbmate https://github.com/amacneil/dbmate/releases/latest/download/dbmate-linux-amd64 && sudo chmod +x /usr/local/bin/dbmate"
  echo "  node:    npx dbmate ...  (or add as a devDependency)"
  exit 1
fi

case "${1:-}" in
  --status)  exec dbmate status ;;
  --dry-run) echo "DRY RUN — pending migrations:"; exec dbmate status ;;
  "")        exec dbmate up ;;
  *) echo "Unknown arg: $1"; echo "Use: (no arg) | --status | --dry-run"; exit 1 ;;
esac
