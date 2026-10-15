#!/usr/bin/env bash
# Removes the crontab entry installed by vault-idea-install.sh. Leaves
# STATE_DIR (logs/state) and idea folders untouched.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../lib/common.sh"

config_file="${VAULT_IDEA_CONFIG:-$REPO_ROOT/config.sh}"
# shellcheck disable=SC1090
[ -f "$config_file" ] && source "$config_file" 2>/dev/null

MARKER="# vault-idea-cron:managed-entry"

existing="$(crontab -l 2>/dev/null || true)"
if [ -z "$existing" ] || ! printf '%s\n' "$existing" | grep -qF "$MARKER"; then
	echo "No vault-idea-cron entry found in crontab; nothing to do."
	exit 0
fi

filtered="$(printf '%s\n' "$existing" | grep -vF "$MARKER" || true)"
printf '%s\n' "$filtered" | crontab -

echo "Removed vault-idea-cron crontab entry."
echo "Note: ${STATE_DIR:-your configured STATE_DIR} and your idea folders were left untouched."
echo "Remove that directory manually if you want a full clean uninstall."
