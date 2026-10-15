#!/usr/bin/env bash
# Main runner: enumerate idea folders, process changed ones through claude,
# write TODO.md/QUESTIONS.md. Intended to be invoked by cron (via
# vault-idea-install.sh) or run by hand.
#
# Usage:
#   vault-idea-run.sh [--dry-run] [--idea <name>]
set -uo pipefail
shopt -s nullglob

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../lib/common.sh"
source "$DIR/../lib/state.sh"
source "$DIR/../lib/prompt.sh"
source "$DIR/../lib/claude_invoke.sh"

DRY_RUN=0
ONLY_IDEA=""

while [ $# -gt 0 ]; do
	case "$1" in
	--dry-run) DRY_RUN=1 ;;
	--idea)
		shift
		ONLY_IDEA="${1:-}"
		;;
	-h | --help)
		echo "Usage: $0 [--dry-run] [--idea <name>]"
		exit 0
		;;
	*)
		echo "Unknown argument: $1" >&2
		exit 1
		;;
	esac
	shift
done

load_config
validate_config
acquire_lock_or_exit
init_state_dir

if [ -n "$ONLY_IDEA" ] && [ ! -d "$VAULT_IDEAS_DIR/$ONLY_IDEA" ]; then
	echo "No such idea folder: $VAULT_IDEAS_DIR/$ONLY_IDEA" >&2
	exit 1
fi

log "run start (dry_run=$DRY_RUN${ONLY_IDEA:+, idea=$ONLY_IDEA})"

processed=0

process_idea() {
	local idea_dir="$1" idea_name="$2"
	local run_count new_run_count prompt

	run_count="$(state_get "$idea_name" run_count)"
	run_count="${run_count:-0}"
	new_run_count=$((run_count + 1))

	prompt="$(build_prompt "$idea_dir" "$idea_name" "$new_run_count")"

	if [ "$DRY_RUN" -eq 1 ]; then
		local prompt_file="$STATE_DIR/logs/dry-run-${idea_name}.prompt.txt"
		printf '%s\n' "$prompt" >"$prompt_file"
		log "would process: $idea_name (run $new_run_count) — prompt saved to $prompt_file"
		return 0
	fi

	if ! invoke_claude_with_retry "$prompt"; then
		log_error "idea $idea_name: claude invocation failed: $CLAUDE_ERROR"
		state_set "$idea_name" "$(jq -n --arg e "$CLAUDE_ERROR" '{last_status:"failed", last_error:$e}')"
		return 1
	fi

	if ! parse_claude_output "$CLAUDE_RESULT"; then
		log_error "idea $idea_name: unparseable model output"
		printf '%s\n' "$CLAUDE_RESULT" >"$STATE_DIR/logs/$(date -u +%Y-%m-%dT%H-%M-%SZ)-${idea_name}-response.txt"
		state_set "$idea_name" "$(jq -n '{last_status:"failed", last_error:"unparseable model output"}')"
		return 1
	fi

	write_todo_file "$idea_dir" "$PARSED_TODO"
	write_questions_file "$idea_dir" "$PARSED_QUESTIONS"

	local new_hash
	new_hash="$(compute_idea_hash "$idea_dir")"
	state_set "$idea_name" "$(jq -n \
		--arg h "$new_hash" \
		--arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
		--argjson rc "$new_run_count" \
		'{content_hash:$h, last_processed_at:$t, last_status:"success", last_error:null, run_count:$rc}')"

	log "idea $idea_name: processed successfully (run $new_run_count)"
	return 0
}

for idea_path in "$VAULT_IDEAS_DIR"/*/; do
	idea_dir="${idea_path%/}"
	idea_name="$(basename "$idea_dir")"

	if [ -n "$ONLY_IDEA" ] && [ "$idea_name" != "$ONLY_IDEA" ]; then
		continue
	fi

	if [ -f "$idea_dir/$DONE_SENTINEL_FILENAME" ]; then
		if [ "$ARCHIVE_ON_DONE" = "true" ]; then
			if [ "$DRY_RUN" -eq 1 ]; then
				log "would archive (done): $idea_name -> $ARCHIVE_DIR/$idea_name"
			else
				mkdir -p "$ARCHIVE_DIR"
				mv "$idea_dir" "$ARCHIVE_DIR/$idea_name"
				state_remove_idea "$idea_name"
				log "archived (done): $idea_name -> $ARCHIVE_DIR/$idea_name"
			fi
		else
			log "skip (done): $idea_name"
		fi
		continue
	fi

	if [ -z "$ONLY_IDEA" ] && [ "$processed" -ge "$MAX_IDEAS_PER_RUN" ]; then
		log "max ideas per run ($MAX_IDEAS_PER_RUN) reached, stopping"
		break
	fi

	state_init_idea "$idea_name" "$idea_dir"

	current_hash="$(compute_idea_hash "$idea_dir")"
	stored_hash="$(state_get "$idea_name" content_hash)"

	if [ -z "$ONLY_IDEA" ] && [ "$current_hash" = "$stored_hash" ]; then
		log "skip (unchanged): $idea_name"
		continue
	fi

	log "processing: $idea_name"
	if process_idea "$idea_dir" "$idea_name"; then
		processed=$((processed + 1))
	fi
done

[ "$DRY_RUN" -eq 0 ] && prune_old_logs

log "run complete: processed=$processed"
