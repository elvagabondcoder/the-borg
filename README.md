# the-borg

A small cron-driven suite that watches an "ideas" folder inside an Obsidian
vault and iteratively fleshes out whatever's in there.

Drop a subfolder into your ideas folder — one subfolder, one idea, usually a
pile of raw, half-formed, late-night notes. On every cron tick this suite
looks for idea folders that have changed since the last run, feeds their
notes to [Claude Code](https://claude.com/product/claude-code) in headless
mode, and writes back two files per idea:

- **`TODO.md`** — concrete next steps to move the idea forward.
- **`QUESTIONS.md`** — a short list of open questions for you to answer.

Check off TODO items and write your answers under the questions directly in
those files. The next run reads your edits as input, refines the TODO list
(without losing what you've already checked off), and asks new questions
instead of repeating old ones. That loop — notes in, TODOs and questions out,
your edits back in — is the whole product.

## Run with Docker (recommended)

Everything the suite needs — the `claude` CLI, `jq`, `flock`, cron — lives in
the image, so nothing has to be installed on the host beyond Docker itself.

```sh
git clone https://github.com/elvagabondcoder/the-borg.git
cd the-borg
cp .env.example .env
"$EDITOR" .env    # set VAULT_IDEAS_DIR, STATE_DIR, and an auth token/key

docker compose up -d --build
docker compose logs -f   # watch the first pass run immediately
```

`VAULT_IDEAS_DIR` and `STATE_DIR` in `.env` are **host** paths — compose
bind-mounts them into the container at the fixed paths `/vault/ideas` and
`/state`, which is what the suite actually runs against internally. For
auth, set one of `CLAUDE_CODE_OAUTH_TOKEN` (a long-lived token from
`claude setup-token`, works against an existing Claude subscription) or
`ANTHROPIC_API_KEY` in `.env` — see the comments there.

On start, the container generates its own `config.sh` from `.env`, runs
`the-borg-doctor.sh` (fails fast and loudly if something's misconfigured),
does one immediate run so you see output right away, then hands off to
`crond` for the `CRON_SCHEDULE` in `.env`. `docker compose restart` after
editing `.env` to pick up changes.

```sh
docker compose down   # stop; STATE_DIR and your vault are untouched
```

## Run without Docker

### Requirements

- `claude` (Claude Code CLI) on your `PATH`, already logged in.
- `jq`, `flock`, `timeout`, `sha256sum` — standard on most Linux distros and
  installable on macOS via Homebrew (`brew install jq util-linux coreutils`
  if `flock`/`timeout`/`sha256sum` are missing; on macOS these ship as
  `gflock`/`gtimeout`/`gsha256sum` under some package managers — make sure
  the unprefixed names resolve on your `PATH`, or symlink them).
- `crontab` if you want the suite to install its own schedule (optional —
  you can always run `bin/the-borg-run.sh` by hand or from your own
  scheduler).

### Quickstart

```sh
git clone https://github.com/elvagabondcoder/the-borg.git
cd the-borg
cp config.example.sh config.sh
"$EDITOR" config.sh                 # set VAULT_IDEAS_DIR at minimum

./bin/the-borg-doctor.sh          # check prerequisites and config
./bin/the-borg-run.sh --dry-run   # see what would happen, writes nothing
./bin/the-borg-run.sh             # do one real run by hand

# once you're happy with the output:
./bin/the-borg-install.sh         # install the cron schedule from config.sh

# to stop:
./bin/the-borg-uninstall.sh
```

## How it decides what to process

Each run computes a content hash over every `*.md` file directly inside an
idea folder (including `TODO.md`/`QUESTIONS.md`) and compares it to the hash
stored from the last successful run. Unchanged folders are skipped, so
editing your raw notes *or* checking off a TODO *or* answering a question all
trigger reprocessing — nothing else does.

Machine bookkeeping (hashes, timestamps, logs, the run lock) lives outside
the vault, in `STATE_DIR` (default `~/.the-borg`), so it never shows
up as sync noise in Obsidian and never clutters an idea folder. The only
files this tool ever writes inside your vault are `TODO.md`, `QUESTIONS.md`,
and — only if you create it — the folder gets skipped once you drop in a
`.idea-done` marker.

## Marking an idea done

Create an empty `.idea-done` file inside an idea folder (from Obsidian or the
shell) and it will be skipped on every future run. If you set
`ARCHIVE_ON_DONE=true` in `config.sh`, the folder is instead moved into
`ARCHIVE_DIR` (a sibling `Archive/` folder in your vault by default) the next
time it's seen — after that it's out of the ideas folder entirely.

## Useful flags

```sh
bin/the-borg-run.sh --dry-run           # show what would happen, write nothing
bin/the-borg-run.sh --idea some-folder  # force-reprocess one idea, ignore the unchanged-skip
```

Combine both to preview the exact prompt that would be sent for one idea
without spending an API call.

## Testing without an API key

```sh
test/run_dry_run_demo.sh
```

Runs the whole pipeline — hashing, prompt assembly, invocation, parsing,
file writes, state updates — against a fake `claude` executable
(`test/stub_claude.sh`) and a sample idea folder, so you can see the shape of
the output with zero API cost. Good for verifying a fresh checkout works, or
as a CI smoke test.

## Configuration reference

See the comments in `config.example.sh` for every tunable: `VAULT_IDEAS_DIR`,
`STATE_DIR`, `CRON_SCHEDULE`, `CLAUDE_MODEL`, `MAX_IDEAS_PER_RUN`,
`CLAUDE_TIMEOUT_SECONDS`, `MAX_RETRIES`, `MAX_CONTEXT_CHARS`, filenames, the
done-sentinel name, `ARCHIVE_ON_DONE`/`ARCHIVE_DIR`, and `LOG_RETENTION_DAYS`.
`config.sh` is gitignored — it's expected to hold a path specific to your
machine.

## Troubleshooting

- `bin/the-borg-doctor.sh` — run this first. It checks that `claude`/`jq`
  are on `PATH`, that `config.sh` loads, that `VAULT_IDEAS_DIR` exists, that
  `STATE_DIR` is writable, and whether a run lock is currently held.
- Logs: `$STATE_DIR/logs/<timestamp>.log`, one per run. On a parse or
  invocation failure the raw model response is also saved next to the log
  for that idea.
- A failed idea keeps its old content hash, so it's retried automatically on
  the next run rather than silently skipped.

## License

MIT — see [LICENSE](LICENSE).
