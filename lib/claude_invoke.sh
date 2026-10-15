#!/usr/bin/env bash
# Wraps `claude -p` invocations: timeout, retry, JSON result extraction. The
# invoked process is never given filesystem-write permissions — it only
# returns text, which the caller (lib/prompt.sh writers) turns into files.
# Sourced by bin/vault-idea-run.sh.

# invoke_claude <prompt>
# On success sets CLAUDE_RESULT and returns 0. On failure sets CLAUDE_ERROR
# and returns 1.
invoke_claude() {
	local prompt="$1"
	local -a cmd=(claude -p "$prompt" --output-format json)
	[ -n "${CLAUDE_MODEL:-}" ] && cmd+=(--model "$CLAUDE_MODEL")
	if [ "${#CLAUDE_EXTRA_ARGS[@]}" -gt 0 ]; then
		cmd+=("${CLAUDE_EXTRA_ARGS[@]}")
	fi

	local stderr_file raw_output exit_code
	stderr_file="$(mktemp)"
	raw_output="$(timeout "$CLAUDE_TIMEOUT_SECONDS" "${cmd[@]}" 2>"$stderr_file")"
	exit_code=$?

	if [ "$exit_code" -eq 124 ]; then
		CLAUDE_ERROR="timed out after ${CLAUDE_TIMEOUT_SECONDS}s"
		rm -f "$stderr_file"
		return 1
	elif [ "$exit_code" -ne 0 ]; then
		CLAUDE_ERROR="claude exited $exit_code: $(tail -c 500 "$stderr_file")"
		rm -f "$stderr_file"
		return 1
	fi
	rm -f "$stderr_file"

	CLAUDE_RESULT="$(printf '%s' "$raw_output" | jq -r '.result // empty' 2>/dev/null)"
	if [ -z "$CLAUDE_RESULT" ]; then
		# Fallback for a claude CLI version without --output-format json
		# support: treat raw stdout as the result text.
		CLAUDE_RESULT="$raw_output"
	fi

	if [ -z "$CLAUDE_RESULT" ]; then
		CLAUDE_ERROR="empty response"
		return 1
	fi
	return 0
}

# invoke_claude_with_retry <prompt>
# Same contract as invoke_claude, retried up to MAX_RETRIES times.
invoke_claude_with_retry() {
	local prompt="$1" attempt=0
	while :; do
		if invoke_claude "$prompt"; then
			return 0
		fi
		attempt=$((attempt + 1))
		[ "$attempt" -gt "$MAX_RETRIES" ] && return 1
		log "retrying claude invocation (attempt $((attempt + 1)))"
	done
}
