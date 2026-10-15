#!/usr/bin/env bash
# vault-idea-cron configuration
#
# Copy this file to config.sh (kept out of git — see .gitignore) and edit the
# values below for your machine.
#
#   cp config.example.sh config.sh
#   "$EDITOR" config.sh

# Absolute path to the "ideas" folder inside your Obsidian vault. Each direct
# subfolder of this path is treated as one idea.
VAULT_IDEAS_DIR="/absolute/path/to/YourVault/Ideas"

# Where machine-generated bookkeeping (content hashes, timestamps, logs, the
# run lockfile) is stored. Kept OUTSIDE the vault on purpose so Obsidian
# sync tools never see it churn on every cron tick. Override only if you
# have a reason to.
STATE_DIR="${HOME}/.vault-idea-cron"

# Standard 5-field crontab schedule, used by bin/vault-idea-install.sh.
CRON_SCHEDULE="*/30 * * * *"

# claude CLI options. Leave CLAUDE_MODEL empty to use the CLI's own default
# model rather than pinning one here.
CLAUDE_MODEL=""
CLAUDE_EXTRA_ARGS=()

# Limits.
MAX_IDEAS_PER_RUN=5
CLAUDE_TIMEOUT_SECONDS=180
MAX_RETRIES=1
MAX_CONTEXT_CHARS=60000

# Filenames written inside each idea folder. Rarely need to change.
TODO_FILENAME="TODO.md"
QUESTIONS_FILENAME="QUESTIONS.md"
DONE_SENTINEL_FILENAME=".idea-done"

# If true, an idea folder marked done (via DONE_SENTINEL_FILENAME) is moved
# into ARCHIVE_DIR on the run after the sentinel appears, and its state is
# dropped. If false (default), it's just skipped forever in place.
ARCHIVE_ON_DONE=false
ARCHIVE_DIR="$(dirname "$VAULT_IDEAS_DIR")/Archive"

# Logging.
LOG_RETENTION_DAYS=30
