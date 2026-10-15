#!/usr/bin/env bash
# State bookkeeping: content hashing + reads/writes against
# $STATE_DIR/state.json. All writes go through a temp-file + atomic mv so a
# killed process never leaves a corrupt state.json. Sourced by bin/* scripts.

state_file() {
	echo "$STATE_DIR/state.json"
}

# sha256 over the sorted concatenation of every *.md file directly inside an
# idea folder, including TODO.md/QUESTIONS.md — so the hash changes both when
# the user edits raw notes and when they check off items or answer questions.
compute_idea_hash() {
	local idea_dir="$1"
	find "$idea_dir" -maxdepth 1 -type f -name '*.md' -print0 |
		LC_ALL=C sort -z |
		xargs -0r cat |
		sha256sum |
		awk '{print $1}'
}

state_get() {
	local name="$1" field="$2"
	jq -r --arg n "$name" --arg f "$field" '.ideas[$n][$f] // empty' "$(state_file)"
}

# state_set <idea-name> <json-object-of-fields-to-merge>
state_set() {
	local name="$1" updates="$2"
	local file tmp
	file="$(state_file)"
	tmp="$(mktemp "${file}.XXXXXX")"
	jq --arg n "$name" --argjson u "$updates" \
		'.ideas[$n] = ((.ideas[$n] // {}) + $u)' "$file" >"$tmp" && mv "$tmp" "$file"
}

state_init_idea() {
	local name="$1" path="$2"
	local file
	file="$(state_file)"
	if [ -z "$(jq -r --arg n "$name" '.ideas[$n] // empty' "$file")" ]; then
		state_set "$name" "$(jq -n --arg p "$path" \
			'{path:$p, content_hash:"", last_processed_at:null, last_status:null, last_error:null, run_count:0, done:false}')"
	fi
}

state_remove_idea() {
	local name="$1"
	local file tmp
	file="$(state_file)"
	tmp="$(mktemp "${file}.XXXXXX")"
	jq --arg n "$name" 'del(.ideas[$n])' "$file" >"$tmp" && mv "$tmp" "$file"
}
