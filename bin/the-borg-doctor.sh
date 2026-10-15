#!/usr/bin/env bash
# Preflight checks: confirms prerequisites and config are in place before the
# user installs the cron entry (or after, to debug a problem).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../lib/common.sh"

FAILURES=0
check_ok() { echo "[OK] $1"; }
check_fail() {
	echo "[FAIL] $1"
	FAILURES=$((FAILURES + 1))
}

if command -v claude >/dev/null 2>&1; then
	check_ok "claude CLI found ($(claude --version 2>/dev/null | head -n1))"
else
	check_fail "claude CLI not found on PATH"
fi

if command -v jq >/dev/null 2>&1; then
	check_ok "jq found ($(jq --version))"
else
	check_fail "jq not found on PATH"
fi

config_file="${THE_BORG_CONFIG:-$REPO_ROOT/config.sh}"
if [ -f "$config_file" ]; then
	# shellcheck disable=SC1090
	if source "$config_file" 2>/dev/null; then
		check_ok "config.sh loads ($config_file)"
	else
		check_fail "config.sh exists but failed to source: $config_file"
	fi
else
	check_fail "config.sh not found — copy config.example.sh to config.sh: $config_file"
fi

if [ -n "${VAULT_IDEAS_DIR:-}" ] && [ -d "$VAULT_IDEAS_DIR" ]; then
	check_ok "VAULT_IDEAS_DIR exists: $VAULT_IDEAS_DIR"
else
	check_fail "VAULT_IDEAS_DIR missing or not a directory: ${VAULT_IDEAS_DIR:-<unset>}"
fi

if [ -n "${STATE_DIR:-}" ]; then
	if mkdir -p "$STATE_DIR" 2>/dev/null && [ -w "$STATE_DIR" ]; then
		check_ok "STATE_DIR writable: $STATE_DIR"
	else
		check_fail "STATE_DIR not writable: $STATE_DIR"
	fi

	lockfile="$STATE_DIR/lock/run.lock"
	mkdir -p "$(dirname "$lockfile")" 2>/dev/null
	if (
		exec 9>"$lockfile"
		flock -n 9
	); then
		check_ok "no stale lock held"
	else
		check_fail "lock is currently held — another run may be in progress"
	fi
else
	check_fail "STATE_DIR is unset"
fi

if command -v crontab >/dev/null 2>&1; then
	if crontab -l 2>/dev/null | grep -q 'the-borg:managed-entry'; then
		check_ok "crontab entry installed"
	else
		echo "[INFO] crontab entry not installed yet (run bin/the-borg-install.sh)"
	fi
else
	echo "[INFO] crontab command not found — skipping cron check"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
	echo "All checks passed."
	exit 0
else
	echo "$FAILURES check(s) failed."
	exit 1
fi
