# Run setup and Round 1/2 detail

Full procedure for Step 1 (run setup, pre-collect context) and Step 2 (Round 1 seat calls),
pulled out of SKILL.md so the body keeps only the decision rule. Referenced from SKILL.md's
Step 1 and Step 2. Step 4 (Round 2) reuses these same three seat commands against
`r2-prompt.md`.

## Step 1 — set up the run and pre-collect context

`$SLUG` is a short kebab-case topic name you derive from the question. **Validate it before it
reaches a path**: it comes from free text, and a `/` or a `..` segment would place the run
directory, and every prompt and log written into it, outside `.council/`.

```bash
case "$SLUG" in
  ''|*[!a-z0-9-]*|-*|*-)
    echo "council: SLUG must be non-empty kebab-case [a-z0-9-], no leading/trailing dash" >&2
    exit 1 ;;
esac

# Shell variables do NOT survive between tool calls — each bash block below is a
# separate process. Park the run directory where later blocks can re-read it.
# .claude/state/ is gitignored and machine-local, which is what a run pointer is.
# Key it by session: two councils running in the same repo would otherwise share
# one pointer, and the first session would start writing its prompts and answers
# into the second's git-tracked decision record, corrupting both.
#
# The key lands in a filename, so it is validated exactly like $SLUG. A session id
# carrying `/` or `..` would otherwise place the pointer outside .claude/state/.
RUN_KEY="${CLAUDE_SESSION_ID:-${CODEX_COMPANION_SESSION_ID:-}}"
case "$RUN_KEY" in
  *[!A-Za-z0-9._-]*) echo "council: session id has characters outside [A-Za-z0-9._-]" >&2; exit 1 ;;
esac

mkdir -p .claude/state .council
if [ -z "$RUN_KEY" ]; then
  # No runtime session id: two concurrent councils cannot be told apart, so one of
  # them must lose. `mkdir` is the claim because it is atomic — a check-then-write
  # on a pointer file lets both runs observe "free" and then both write it.
  RUN_KEY=shared
  LOCK=".claude/state/council-lock-shared"
  if ! mkdir "$LOCK" 2>/dev/null; then
    echo "council: another run holds $LOCK and this runtime exposes no session id to" >&2
    echo "separate them. Remove that directory once the other council has finished." >&2
    exit 1
  fi
fi

# Allocate the run directory atomically for the same reason: `mkdir -p` succeeds on
# a directory that already exists, so two runs racing on the same date and slug
# would both "win" the [ -e ] check and then share one directory, overwriting each
# other's prompts and answers. Plain `mkdir` fails when the name is taken, which
# makes the creation itself the loop condition.
BASE=".council/$(date -u +%Y-%m-%d)-$SLUG"; DIR="$BASE"; n=2
until mkdir "$DIR" 2>/dev/null; do
  [ "$n" -gt 999 ] && { echo "council: cannot allocate a run directory under $BASE" >&2; exit 1; }
  DIR="$BASE-$n"; n=$((n+1))
done

printf '%s\n' "$DIR" > ".claude/state/council-run-$RUN_KEY" \
  || { echo "council: failed to record the run pointer" >&2; exit 1; }
echo "DIR=$DIR RUN_KEY=$RUN_KEY"
```

**Release the lock when the council ends.** The `shared` lock is held for the whole run, and
nothing else clears it: a finished council would otherwise block every later invocation, and
telling the user to "finish that council" cannot help because it already did. Step 5 removes it
on both the success and the give-up path:

```bash
RUN_KEY="${CLAUDE_SESSION_ID:-${CODEX_COMPANION_SESSION_ID:-shared}}"
case "$RUN_KEY" in *[!A-Za-z0-9._-]*) echo "council: invalid session id" >&2; exit 1 ;; esac
rm -f ".claude/state/council-run-$RUN_KEY"
[ "$RUN_KEY" = shared ] && rmdir ".claude/state/council-lock-shared" 2>/dev/null
exit 0
```

The directory is **git-tracked**: it is the decision record, not scratch. The run pointer under
`.claude/state/` is not.

### Re-hydrating state in every later block

Every bash block from here on starts with this, because nothing set in an earlier block is still
in scope. Skipping it hands empty model names and an empty output path to the first seat call:

```bash
REG="$HOME/.claude/council-models.json"
RUN_KEY="${CLAUDE_SESSION_ID:-${CODEX_COMPANION_SESSION_ID:-shared}}"
case "$RUN_KEY" in *[!A-Za-z0-9._-]*) echo "council: invalid session id" >&2; exit 1 ;; esac
DIR=$(cat ".claude/state/council-run-$RUN_KEY")
CODEX_MODEL=$(jq -r '.seats.codex.model'        "$REG")
CODEX_EFFORT=$(jq -r '.seats.codex.effort'      "$REG")
CODEX_TIER=$(jq -r '.seats.codex.service_tier'  "$REG")
AGY_MODEL=$(jq -r '.seats.agy.model'            "$REG")
CLAUDE_MODEL=$(jq -r '.seats.claude.model'      "$REG")
[ -n "$DIR" ] && [ -d "$DIR" ] || { echo "council: no active run directory" >&2; exit 1; }
```

The charset check repeats on every read, not just the write. `RUN_KEY` is interpolated into the
path being read, so an id containing `..` would pull an arbitrary file's contents into `$DIR`,
which is where every prompt and answer then gets written.

### What to pre-collect, and what not to

codex and agy read files on their own. **Anything reachable by a path is passed as a path**, not
pasted. Only collect what a path cannot carry:

| Source | Why a path will not do |
|---|---|
| mem0 memories | Behind an MCP service, not a file at all. Two searches (decisions, task learnings) keep the seats from re-proposing something already rejected. |
| Serena symbol graph | `find_referencing_symbols` output needs a language-server index. agy cannot build one. |
| scout research | Facts outside the repo. Most expensive; only when the question actually turns on external facts. |

Do **not** paste `AGENTS.md`, `.llmwiki/` pages, or source files. Cite their paths.

Write the shared brief to `$DIR/brief.md`: the question, the resolved facts, the pre-collected
context, and the file paths worth reading.

---

## Step 2 — Round 1, independent opinions

Compose `$DIR/r1-prompt.md` from the brief plus these instructions to every seat:

1. Answer the question directly with reasoning.
2. Separately list **open questions for the user**: only things that would change the answer
   and that the repo cannot settle.

The Claude seat additionally gets the adversarial role described in Step 4.

Run the three seats. They must not see each other's answers in this round.

```bash
# Re-hydrate first — see "Re-hydrating state in every later block" in Step 1.
# Without it $CODEX_MODEL and $DIR are empty here and the call fails immediately.
REG="$HOME/.claude/council-models.json"
RUN_KEY="${CLAUDE_SESSION_ID:-${CODEX_COMPANION_SESSION_ID:-shared}}"
case "$RUN_KEY" in *[!A-Za-z0-9._-]*) echo "council: invalid session id" >&2; exit 1 ;; esac
DIR=$(cat ".claude/state/council-run-$RUN_KEY")
CODEX_MODEL=$(jq -r '.seats.codex.model' "$REG")
CODEX_EFFORT=$(jq -r '.seats.codex.effort' "$REG")
CODEX_TIER=$(jq -r '.seats.codex.service_tier' "$REG")

# codex — prompt on stdin (no shell quoting of user text), answer to a file.
# Do NOT parse stdout: hook lines and token counts are interleaved into it.
codex exec -s read-only --skip-git-repo-check \
  -m "$CODEX_MODEL" \
  -c model_reasoning_effort="\"$CODEX_EFFORT\"" \
  -c service_tier="\"$CODEX_TIER\"" \
  -o "$DIR/r1-codex.md" - < "$DIR/r1-prompt.md"
```

```bash
# Re-hydrate first (Step 1) — a separate tool call means a separate process.
REG="$HOME/.claude/council-models.json"
RUN_KEY="${CLAUDE_SESSION_ID:-${CODEX_COMPANION_SESSION_ID:-shared}}"
case "$RUN_KEY" in *[!A-Za-z0-9._-]*) echo "council: invalid session id" >&2; exit 1 ;; esac
DIR=$(cat ".claude/state/council-run-$RUN_KEY")
AGY_MODEL=$(jq -r '.seats.agy.model' "$REG")

# agy — prompt is a shell argument, so quote the expansion and keep --print LAST.
# The trailing < /dev/null is mandatory: without it agy waits on a TTY forever and
# --print-timeout does not bound it.
AGY_PROMPT="$(cat "$DIR/r1-prompt.md")
OUTPUT INSTRUCTION: do not print the answer to chat. Write it with the write_file tool to:
  $PWD/$DIR/r1-agy.md
After writing, confirm the path. That is your only deliverable."
agy --dangerously-skip-permissions --add-dir "$PWD/$DIR" --print-timeout 10m0s \
  --model "$AGY_MODEL" --print "$AGY_PROMPT" < /dev/null
```

The Claude seat runs through the `Agent` tool with `model` set to `seats.claude.model` read from
the registry (`opus` by default; the tool accepts `sonnet`, `opus`, `haiku`, `fable`). Have it
write its answer to `$DIR/r1-claude.md`.

Verify each file exists and is non-empty before moving on. A missing file is a failure, not an
empty opinion; see the failure policy.
