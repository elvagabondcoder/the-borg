#!/usr/bin/env bash
# Exercises the full pipeline (hash -> prompt build -> invoke -> parse ->
# write -> state update) against the stub claude executable and the sample
# fixture idea, with zero API cost. Useful for contributors and CI.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DIR/.." && pwd)"

chmod +x "$DIR/stub_claude.sh"
TMP_BIN="$(mktemp -d)"
ln -sf "$DIR/stub_claude.sh" "$TMP_BIN/claude"

TMP_STATE="$(mktemp -d)"
TMP_VAULT="$(mktemp -d)"
cp -r "$DIR/fixtures/sample-vault/ideas" "$TMP_VAULT/"
cleanup() { rm -rf "$TMP_BIN" "$TMP_STATE" "$TMP_VAULT"; }
trap cleanup EXIT

cat >"$TMP_STATE/config.sh" <<EOF
VAULT_IDEAS_DIR="$TMP_VAULT/ideas"
STATE_DIR="$TMP_STATE/state"
CRON_SCHEDULE="*/30 * * * *"
CLAUDE_MODEL=""
CLAUDE_EXTRA_ARGS=()
MAX_IDEAS_PER_RUN=5
CLAUDE_TIMEOUT_SECONDS=30
MAX_RETRIES=0
MAX_CONTEXT_CHARS=60000
TODO_FILENAME="TODO.md"
QUESTIONS_FILENAME="QUESTIONS.md"
DONE_SENTINEL_FILENAME=".idea-done"
ARCHIVE_ON_DONE=false
ARCHIVE_DIR="$TMP_VAULT/Archive"
LOG_RETENTION_DAYS=30
EOF

PATH="$TMP_BIN:$PATH" VAULT_IDEA_CONFIG="$TMP_STATE/config.sh" "$REPO_ROOT/bin/vault-idea-run.sh"

echo
echo "=== Generated TODO.md ==="
cat "$TMP_VAULT/ideas/my-first-idea/TODO.md"
echo
echo "=== Generated QUESTIONS.md ==="
cat "$TMP_VAULT/ideas/my-first-idea/QUESTIONS.md"
