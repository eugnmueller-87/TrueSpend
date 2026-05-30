#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# TrueSpend — Install Git Hooks
# Run once after cloning: bash scripts/install-hooks.sh
# ──────────────────────────────────────────────────────────────

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_SRC="$REPO_ROOT/scripts/hooks"
HOOKS_DST="$REPO_ROOT/.git/hooks"

echo "Installing TrueSpend git hooks..."

cp "$HOOKS_SRC/pre-commit" "$HOOKS_DST/pre-commit"
chmod +x "$HOOKS_DST/pre-commit"

echo "✓ pre-commit hook installed"
echo ""
echo "The hook will block commits containing:"
echo "  - Hardcoded JWT tokens"
echo "  - Private keys (RSA, EC)"
echo "  - Real .env files"
echo "  - Build artifacts (intake/dist/)"
echo "  - Anthropic / OpenAI / Railway / Jira API keys"
