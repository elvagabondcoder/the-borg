#!/usr/bin/env bash
# Shared helpers: config loading/validation, logging, locking. Sourced by
# bin/* scripts — not meant to be executed directly.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CURRENT_LOG_FILE=""

log() {
	local line
	line="$(date -u +%Y-%m-%dT%H:%M:%SZ) $*"
	echo "$line"
	[ -n "$CURRENT_LOG_FILE" ] && echo "$line" >>"$CURRENT_LOG_FILE"
}

log_error() {
	log "ERROR: $*" >&2
}

load_config() {
	local config_file="${THE_BORG_CONFIG:-$REPO_ROOT/config.sh}"
	if [ ! -f "$config_file" ]; then
		echo "Config file not found: $config_file" >&2
		echo "Copy config.example.sh to config.sh and edit it first." >&2
		exit 1
	fi
	# shellcheck disable=SC1090
	source "$config_file"
}

validate_config() {
	local missing=()
	for var in VAULT_IDEAS_DIR STATE_DIR CRON_SCHEDULE TODO_FILENAME \
		QUESTIONS_FILENAME DONE_SENTINEL_FILENAME; do
		[ -n "${!var:-}" ] || missing+=("$var")
	done
	if [ "${#missing[@]}" -gt 0 ]; then
		echo "Missing required config values: ${missing[*]}" >&2
		exit 1
	fi
	if [ ! -d "$VAULT_IDEAS_DIR" ]; then
		echo "VAULT_IDEAS_DIR does not exist: $VAULT_IDEAS_DIR" >&2
		exit 1
	fi
	for cmd in claude jq flock timeout sha256sum; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			echo "Required command not found on PATH: $cmd" >&2
			exit 1
		fi
	done
}

init_state_dir() {
	mkdir -p "$STATE_DIR/lock" "$STATE_DIR/logs"
	local state_file="$STATE_DIR/state.json"
	if [ ! -f "$state_file" ]; then
		echo '{"version":1,"ideas":{}}' >"$state_file"
	fi
	CURRENT_LOG_FILE="$STATE_DIR/logs/$(date -u +%Y-%m-%dT%H-%M-%SZ).log"
	: >"$CURRENT_LOG_FILE"
}

# Takes a non-blocking flock on $STATE_DIR/lock/run.lock via fd 9. The lock
# is released automatically when the process exits (fd 9 closes). If another
# run already holds it, logs and exits 0 rather than queuing.
acquire_lock_or_exit() {
	local lockfile="$STATE_DIR/lock/run.lock"
	mkdir -p "$(dirname "$lockfile")"
	exec 9>"$lockfile"
	if ! flock -n 9; then
		log "another run is already in progress, exiting"
		exit 0
	fi
}

prune_old_logs() {
	find "$STATE_DIR/logs" -type f -name '*.log' -mtime "+${LOG_RETENTION_DAYS}" -delete 2>/dev/null || true
}
