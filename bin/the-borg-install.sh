#!/usr/bin/env bash
# Idempotently installs (or updates) the crontab entry that runs
# the-borg-run.sh on the schedule configured in config.sh.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../lib/common.sh"

load_config
validate_config

MARKER="# the-borg:managed-entry"
RUN_SCRIPT="$REPO_ROOT/bin/the-borg-run.sh"
mkdir -p "$STATE_DIR/logs"
CRON_LOG="$STATE_DIR/logs/cron-stdout.log"

CRON_LINE="$CRON_SCHEDULE cd \"$REPO_ROOT\" && \"$RUN_SCRIPT\" >> \"$CRON_LOG\" 2>&1 $MARKER"

existing="$(crontab -l 2>/dev/null || true)"
filtered="$(printf '%s\n' "$existing" | grep -vF "$MARKER" || true)"

{
	[ -n "$filtered" ] && printf '%s\n' "$filtered"
	printf '%s\n' "$CRON_LINE"
} | crontab -

echo "Installed cron entry:"
echo "  $CRON_LINE"
echo
echo "Run bin/the-borg-doctor.sh to verify everything is set up correctly."
