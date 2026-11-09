# Run setup and seat calls

The 5 bash blocks for Step 1 (run setup) and Step 2 (Round 1 seat calls) of `SKILL.md`, plus the
lock release Step 5 runs. Step 4 (Round 2) reuses the same seat commands against `r2-prompt.md`.

## Set up the run

`$SLUG` is a short kebab-case topic name derived from the question. It comes from free text, so it
is validated before it reaches a path: a `/` or `..` segment would place the run directory outside
`.council/`. The session key lands in a filename too and gets the same gate.

```bash
case "$SLUG" in
  ''|*[!a-z0-9-]*|-*|*-)
    echo "council: SLUG must be non-empty kebab-case [a-z0-9-], no leading/trailing dash" >&2
    exit 1 ;;
esac

# Shell variables do NOT survive between tool calls, so park the run directory in a
# machine-local pointer keyed by session: two councils in one repo must not share it.
RUN_KEY="${CLAUDE_SESSION_ID:-${CODEX_COMPANION_SESSION_ID:-}}"
case "$RUN_KEY" in
  *[!A-Za-z0-9._-]*) echo "council: session id has characters outside [A-Za-z0-9._-]" >&2; exit 1 ;;
esac

mkdir -p .claude/state .council
if [ -z "$RUN_KEY" ]; then
  # No session id: two concurrent councils cannot be told apart, so one must lose.
  # `mkdir` is the claim because it is atomic; a check-then-write lets both win.
  RUN_KEY=shared
  LOCK=".claude/state/council-lock-shared"
  if ! mkdir "$LOCK" 2>/dev/null; then
    echo "council: another run holds $LOCK and this runtime exposes no session id to" >&2
    echo "separate them. Remove that directory once the other council has finished." >&2
    exit 1
  fi
fi

# Plain `mkdir` fails when the name is taken (`mkdir -p` would not), so the
# creation itself is the loop condition and two racing runs never share a directory.
BASE=".council/$(date -u +%Y-%m-%d)-$SLUG"; DIR="$BASE"; n=2
until mkdir "$DIR" 2>/dev/null; do
  [ "$n" -gt 999 ] && { echo "council: cannot allocate a run directory under $BASE" >&2; exit 1; }
  DIR="$BASE-$n"; n=$((n+1))
done

# Raw material lives under .tmp/; only consensus.md goes into the tracked $DIR.
RAW=".tmp/council/${DIR#.council/}"
mkdir -p "$RAW" || { echo "council: cannot create $RAW" >&2; exit 1; }

printf '%s\n' "$DIR" > ".claude/state/council-run-$RUN_KEY" \
  || { echo "council: failed to record the run pointer" >&2; exit 1; }
echo "DIR=$DIR RAW=$RAW RUN_KEY=$RUN_KEY"
```

`.tmp/` must be gitignored, or the raw files show up as untracked changes. Test it with `git
check-ignore -q .tmp/`. When it is not ignored, ask with `AskUserQuestion` whether to append `.tmp/`
to `.gitignore`; without an answer, leave `.gitignore` alone and say so.

## Release the lock at the end

Nothing else clears the `shared` lock, so a finished council that skips this blocks every later run.
Step 5 runs it on both the success and the give-up path:

```bash
RUN_KEY="${CLAUDE_SESSION_ID:-${CODEX_COMPANION_SESSION_ID:-shared}}"
case "$RUN_KEY" in *[!A-Za-z0-9._-]*) echo "council: invalid session id" >&2; exit 1 ;; esac
rm -f ".claude/state/council-run-$RUN_KEY"
[ "$RUN_KEY" = shared ] && rmdir ".claude/state/council-lock-shared" 2>/dev/null
exit 0
```

## Re-hydrating state in every later block

Every bash block after setup starts with these lines, because nothing set in an earlier block is
still in scope. The charset check repeats on every read: `RUN_KEY` is part of the path being read,
so an id containing `..` would pull an arbitrary file into `$DIR`.

```bash
REG="$HOME/.claude/council-models.json"
RUN_KEY="${CLAUDE_SESSION_ID:-${CODEX_COMPANION_SESSION_ID:-shared}}"
case "$RUN_KEY" in *[!A-Za-z0-9._-]*) echo "council: invalid session id" >&2; exit 1 ;; esac
DIR=$(cat ".claude/state/council-run-$RUN_KEY")
RAW=".tmp/council/${DIR#.council/}"
CODEX_MODEL=$(jq -r '.seats.codex.model'        "$REG")
CODEX_EFFORT=$(jq -r '.seats.codex.effort'      "$REG")
CODEX_TIER=$(jq -r '.seats.codex.service_tier'  "$REG")
AGY_MODEL=$(jq -r '.seats.agy.model'            "$REG")
CLAUDE_MODEL=$(jq -r '.seats.claude.model'      "$REG")
[ -n "$DIR" ] && [ -d "$DIR" ] || { echo "council: no active run directory" >&2; exit 1; }
```

## Pre-collect only what a path cannot carry

codex and agy read files on their own, so anything reachable by a path is passed as a path. Never
paste `AGENTS.md`, `.llmwiki/` pages or source files; cite their paths.

| Source | Why a path will not do |
|---|---|
| mem0 memories | Behind an MCP service, not a file. Search decisions and task learnings. |
| Serena symbol graph | `find_referencing_symbols` output needs a language-server index. agy cannot build one. |
| scout research | Facts outside the repo. Most expensive; only when the question turns on external facts. |

## Run the seats

Each seat call is its own block and re-hydrates first. codex reads the prompt on stdin, so no user
text is re-parsed by the shell, and writes its final message with `-o` (`--output-last-message`; see
the non-interactive mode page under <https://developers.openai.com/codex/llms.txt>).

```bash
# Re-hydrate first: see "Re-hydrating state in every later block".
REG="$HOME/.claude/council-models.json"
RUN_KEY="${CLAUDE_SESSION_ID:-${CODEX_COMPANION_SESSION_ID:-shared}}"
case "$RUN_KEY" in *[!A-Za-z0-9._-]*) echo "council: invalid session id" >&2; exit 1 ;; esac
DIR=$(cat ".claude/state/council-run-$RUN_KEY")
RAW=".tmp/council/${DIR#.council/}"
CODEX_MODEL=$(jq -r '.seats.codex.model' "$REG")
CODEX_EFFORT=$(jq -r '.seats.codex.effort' "$REG")
CODEX_TIER=$(jq -r '.seats.codex.service_tier' "$REG")

# codex: prompt on stdin, final message to the -o file.
codex exec -s read-only --skip-git-repo-check \
  -m "$CODEX_MODEL" \
  -c model_reasoning_effort="\"$CODEX_EFFORT\"" \
  -c service_tier="\"$CODEX_TIER\"" \
  -o "$RAW/r1-codex.md" - < "$RAW/r1-prompt.md"
```

agy takes the prompt as a shell argument, so `--print` stays the last flag before it. The trailing
`< /dev/null` is mandatory: without it agy waits on a TTY forever and `--print-timeout` does not
bound it. agy writes its answer to a file instead of stdout.

```bash
# Re-hydrate first: a separate tool call means a separate process.
REG="$HOME/.claude/council-models.json"
RUN_KEY="${CLAUDE_SESSION_ID:-${CODEX_COMPANION_SESSION_ID:-shared}}"
case "$RUN_KEY" in *[!A-Za-z0-9._-]*) echo "council: invalid session id" >&2; exit 1 ;; esac
DIR=$(cat ".claude/state/council-run-$RUN_KEY")
RAW=".tmp/council/${DIR#.council/}"
AGY_MODEL=$(jq -r '.seats.agy.model' "$REG")

# agy: quote the expansion and keep --print LAST; < /dev/null is mandatory.
AGY_PROMPT="$(cat "$RAW/r1-prompt.md")
OUTPUT INSTRUCTION: do not print the answer to chat. Write it with the write_file tool to:
  $PWD/$RAW/r1-agy.md
After writing, confirm the path. That is your only deliverable."
agy --dangerously-skip-permissions --add-dir "$PWD/$RAW" --print-timeout 10m0s \
  --model "$AGY_MODEL" --print "$AGY_PROMPT" < /dev/null
```

The Claude seat runs through the `Agent` tool with `model` set to `seats.claude.model` (`opus` by
default; the allowed aliases `sonnet`, `opus`, `haiku`, `fable` are a policy subset of
<https://code.claude.com/docs/en/sub-agents#choose-a-model>) and writes its answer to
`$RAW/r1-claude.md`.
