#!/usr/bin/env bash
# Prompt assembly for one idea, plus parsing/writing of the model's response.
# Sourced by bin/the-borg-run.sh.

# build_prompt <idea_dir> <idea_name> <run_number>
# Prints the assembled prompt to stdout.
build_prompt() {
	local idea_dir="$1" idea_name="$2" run_number="$3"
	local template raw_notes current_todo current_questions timestamp

	template="$(cat "$REPO_ROOT/prompts/idea_refine.tmpl.md")"

	raw_notes=""
	while IFS= read -r -d '' f; do
		raw_notes+="## File: $(basename "$f")"$'\n\n'"$(cat "$f")"$'\n\n'
	done < <(find "$idea_dir" -maxdepth 1 -type f -name '*.md' \
		! -name "$TODO_FILENAME" ! -name "$QUESTIONS_FILENAME" -print0 | LC_ALL=C sort -z)

	if [ -z "$raw_notes" ]; then
		raw_notes="(no notes files found)"
	elif [ "${#raw_notes}" -gt "$MAX_CONTEXT_CHARS" ]; then
		raw_notes="${raw_notes:0:$MAX_CONTEXT_CHARS}"$'\n'"[... truncated, notes exceed ${MAX_CONTEXT_CHARS} chars ...]"
	fi

	if [ -f "$idea_dir/$TODO_FILENAME" ]; then
		current_todo="$(cat "$idea_dir/$TODO_FILENAME")"
	else
		current_todo="No TODO.md yet — this is the first run for this idea."
	fi

	if [ -f "$idea_dir/$QUESTIONS_FILENAME" ]; then
		current_questions="$(cat "$idea_dir/$QUESTIONS_FILENAME")"
	else
		current_questions="No QUESTIONS.md yet."
	fi

	timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

	template="${template//\{\{RUN_NUMBER\}\}/$run_number}"
	template="${template//\{\{IDEA_NAME\}\}/$idea_name}"
	template="${template//\{\{TIMESTAMP\}\}/$timestamp}"
	template="${template//\{\{RAW_NOTES\}\}/$raw_notes}"
	template="${template//\{\{CURRENT_TODO\}\}/$current_todo}"
	template="${template//\{\{CURRENT_QUESTIONS\}\}/$current_questions}"

	printf '%s' "$template"
}

# parse_claude_output <raw_text>
# Sets PARSED_TODO and PARSED_QUESTIONS. Returns 1 if either block is
# missing or empty, so the caller can treat the run as failed.
parse_claude_output() {
	local raw="$1"

	PARSED_TODO="$(printf '%s\n' "$raw" | awk '
		/^[[:space:]]*<<<TODO>>>[[:space:]]*$/{f=1;next}
		/^[[:space:]]*<<<END_TODO>>>[[:space:]]*$/{f=0}
		f
	')"
	PARSED_QUESTIONS="$(printf '%s\n' "$raw" | awk '
		/^[[:space:]]*<<<QUESTIONS>>>[[:space:]]*$/{f=1;next}
		/^[[:space:]]*<<<END_QUESTIONS>>>[[:space:]]*$/{f=0}
		f
	')"

	[ -n "$PARSED_TODO" ] || return 1
	[ -n "$PARSED_QUESTIONS" ] || return 1
	return 0
}

write_todo_file() {
	local idea_dir="$1" content="$2"
	printf '%s\n' "$content" >"$idea_dir/$TODO_FILENAME"
}

# Append log: new dated section on top, prior rounds (with the user's
# answers) preserved below a separator.
write_questions_file() {
	local idea_dir="$1" content="$2"
	local file="$idea_dir/$QUESTIONS_FILENAME"
	local existing=""
	[ -f "$file" ] && existing="$(cat "$file")"
	{
		printf '%s\n' "$content"
		if [ -n "$existing" ]; then
			printf '\n---\n\n%s\n' "$existing"
		fi
	} >"$file"
}
