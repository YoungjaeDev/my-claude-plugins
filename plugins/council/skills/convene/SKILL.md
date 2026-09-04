---
name: convene
description: "Convene a cross-vendor council: codex (GPT), agy (Gemini) and a Claude Opus seat answer independently, hand follow-up questions to the user, rebut each other, then the chair synthesizes agreement and surviving disagreement. Use on /council:convene, '카운슬', '심의', '다른 모델 의견', 'convene a council', 'second opinion from another model', 'cross-model debate'. For a decision that needs a different model's judgment rather than more Claude sampling; not for ordinary code review."
---

# Council — cross-vendor deliberation

Put one question to three models from three different vendors, make them read and rebut each
other, and write down what they agreed on, what stayed contested, and what nobody could answer.

The point is divergence. Several Claude subagents share weights and therefore share their
systematic mistakes; a real second opinion has to come from a model somebody else trained.

## Cross-runtime interactive input

Every question below runs through a **capability-aware** interactive-input gate rather than one
hardcoded tool:

- **Claude Code** — use `AskUserQuestion`.
- **Codex** — use `request_user_input` when that tool is exposed. When it is not, ask ONE
  concise blocking question only where a wrong assumption would be costly; otherwise proceed on
  a documented safe default and state the assumption.

This plugin is Claude-only in practice (the Claude seat needs the `Agent` tool), so the Claude
row is the operative one. The other row is kept so the body never asserts that a single
interactive tool exists.

## Roles

The **chair** is the main session. It composes prompts, relays the user's answers, and
synthesizes. **The chair is not a seat and does not vote.**

| Seat | Runner | Registry key |
|---|---|---|
| codex | `codex exec` | `seats.codex` |
| agy | `agy --print` | `seats.agy` |
| claude | `Agent` tool with a `model` override | `seats.claude` |

---

## Step 0 — resolve the model registry

Seat models are pinned in `~/.claude/council-models.json` so they survive across repos and are
confirmed at most once a week.

The seven-day window is a **constant here, never a field read back from the registry.** A TTL
taken from the file it governs is not a guarantee — one hand-edited `ttl_days` and the pins never
come up for confirmation again, which is exactly the "always ask on expiry" property this design
was chosen for. A timestamp that is missing, non-numeric, or in the future is treated as expired
for the same reason: those are the shapes a corrupted or tampered registry takes, and none of
them should buy indefinite freshness.

Freshness also requires the pins to actually be there. A registry whose `checked_at_epoch` is
recent but whose `seats` block is missing, malformed, or empty would otherwise read as `fresh`,
and the seats would then run with a model name of `null`. Anything that fails to parse or is
missing a seat pin is `expired` — that routes it back through confirmation instead of forward
into a broken call.

```bash
REG="$HOME/.claude/council-models.json"
TTL=$(( 7 * 86400 ))          # policy constant — not configurable from the file
if [ ! -f "$REG" ]; then
  echo "STATE=missing"
elif ! jq -e '(.seats.codex.model // "") != "" and (.seats.codex.effort // "") != ""
              and (.seats.codex.service_tier // "") != ""
              and (.seats.agy.model // "") != "" and (.seats.claude.model // "") != ""' \
       "$REG" >/dev/null 2>&1; then
  # covers unparseable JSON (jq exits non-zero) and any absent/empty seat pin
  echo "STATE=expired"
else
  NOW=$(date +%s)
  CHECKED=$(jq -r '.checked_at_epoch // empty' "$REG")
  case "$CHECKED" in
    ''|*[!0-9]*) echo "STATE=expired" ;;                    # absent or not a number
    *)
      AGE=$(( NOW - CHECKED ))
      # -ge, not -gt: at exactly seven days the pin has reached its stated life
      # and is due. A negative age means a future timestamp — also expired.
      if [ "$AGE" -lt 0 ] || [ "$AGE" -ge "$TTL" ]; then echo "STATE=expired"; else echo "STATE=fresh"; fi ;;
  esac
  jq -r '.seats | to_entries[] | "\(.key)=\(.value | tostring)"' "$REG"
fi
```

- `STATE=fresh` — the pins are still current; run the validity check below and, if it passes, go
  to Step 1 without asking anything.
- `STATE=missing` or `STATE=expired` — confirm the pins with the user before convening. Expiry
  **always** asks, even when nothing changed. Deciding whether a newer model is actually better
  belongs to the user, and a silent upgrade drifts into unintended spend.

### Fresh does not mean valid

A CLI update can retire a model inside the seven-day window. The failure table says a pin that
has vanished from the candidate list is asked about **before** expiry, so `fresh` cannot skip
straight to Step 1 — otherwise the run reaches Round 1 with a dead pin and merely records the
seat as absent, which reads as "the seat failed" rather than "your pin is gone". The check is
local and cheap:

**Read the list first, then test membership against what you read.** Folding both steps into one
negated command makes a truncated cache or a failed `agy` call indistinguishable from a retired
model, and the user gets sent to pick a replacement with no trustworthy list in front of them.
Each list is fetched exactly once, into a variable, and only a *successful* read is allowed to
accuse a pin:

```bash
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"   # codex honors CODEX_HOME; see project_state.sh
REG="$HOME/.claude/council-models.json"
CM=$(jq -r '.seats.codex.model' "$REG"); AM=$(jq -r '.seats.agy.model' "$REG")

# codex — one read; a parse failure is a read failure, never a retirement.
if [ ! -f "$CODEX_DIR/models_cache.json" ]; then
  echo "LIST_UNREAD=codex reason=cache-absent"
elif ! codex_slugs=$(jq -r '.models[].slug' "$CODEX_DIR/models_cache.json" 2>/dev/null); then
  echo "LIST_UNREAD=codex reason=cache-unparseable"
elif ! printf '%s\n' "$codex_slugs" | grep -qxF "$CM"; then
  echo "STALE_PIN=codex:$CM"
fi

# agy — one invocation, captured; the earlier version called `agy models` twice
# and let the second call's failure read as a missing pin.
if ! command -v agy >/dev/null 2>&1; then
  echo "LIST_UNREAD=agy reason=binary-absent"
elif ! agy_slugs=$(agy models 2>/dev/null); then
  echo "LIST_UNREAD=agy reason=listing-failed"
elif ! printf '%s\n' "$agy_slugs" | grep -qxF "$AM"; then
  echo "STALE_PIN=agy:$AM"
fi
```

A `STALE_PIN=` line means: tell the user which pin disappeared and ask for a replacement, even
though the TTL has not elapsed. A `LIST_UNREAD=` line means the opposite — say nothing about that
seat's pin, because a list you could not read is not evidence of anything.

Gather the real candidate lists first so the question carries evidence rather than guesses:

```bash
# Absence and failure are different answers and must not collapse into one.
# `cmd && list || echo absent` swallows every non-zero exit — an expired agy
# login or an unparseable cache would be reported as "not installed", and the
# pin question would then be asked with no real candidate list behind it.

# codex: slugs plus the reasoning levels each one accepts.
# Resolve through CODEX_HOME — codex layers `$CODEX_HOME/<name>.config.toml`, so on a
# machine that sets it, `$HOME/.codex` is a directory the running CLI never reads.
# Same rule the repo's own detector applies (plugins/dev/scripts/project_state.sh).
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
if [ ! -f "$CODEX_DIR/models_cache.json" ]; then
  echo "(codex model cache absent)"
elif ! jq -r '
  .models[] | select(.visibility != "hide")
  | "\(.slug)  efforts=\([.supported_reasoning_levels[].effort] | join(","))  speed=\(.additional_speed_tiers // [] | join(","))"
' "$CODEX_DIR/models_cache.json"; then
  echo "(codex model cache unreadable — present but unparseable)" >&2
fi

# agy: one slug per line, effort already folded into the slug
if ! command -v agy >/dev/null 2>&1; then
  echo "(agy absent)"
elif ! agy models; then
  echo "(agy model listing failed — auth or network, not absence)" >&2
fi
```

When either list comes back as a *failure* rather than an absence, say so in the pin question and
do not present the missing side as "no models available". A pin confirmed against a list that
failed to load is a pin confirmed against nothing.

Show the current pins next to those lists and ask through the interactive-input gate whether to
keep or change them. Accept a natural-language answer ("codex를 luna로 바꿔줘"), and resolve it
against the candidate list you just printed — a name that is not on the list goes back to the
user rather than into the registry. Then write the file; `checked_at_epoch` is what keeps the TTL
arithmetic off `date -d` and portable.

**The confirmed pins never pass through shell source.** Two failure modes sit on either side of
that rule: hard-coding defaults into the block throws the user's actual choice away, and pasting
their answer into a quoted string hands `$(…)` and stray quotes to the shell. Neither is
necessary — the pins are data, so write them as data.

First record the confirmed answer with the **`Write` tool** (not a heredoc, not `echo`) to
`.claude/state/council-pins.json`. Nothing in that path is parsed by a shell, so no value the
user typed can become a command:

```json
{
  "codex":  {"model": "gpt-5.6-sol", "effort": "xhigh", "service_tier": "fast"},
  "agy":    {"model": "gemini-3.6-flash-high"},
  "claude": {"model": "opus"}
}
```

Then this block reads that file, checks every pin against a conservative charset, and hands the
values to `jq` through `--arg` (argv, never re-parsed). A pin outside the charset or missing
altogether stops the write rather than landing a registry that looks valid:

```bash
PINS=".claude/state/council-pins.json"
REG="$HOME/.claude/council-models.json"
jq -e '.' "$PINS" >/dev/null 2>&1 || { echo "council: $PINS missing or unparseable" >&2; exit 1; }

for k in codex.model codex.effort codex.service_tier agy.model claude.model; do
  v=$(jq -r ".$k // empty" "$PINS")
  case "$v" in
    ''|*[!a-zA-Z0-9._-]*)
      echo "council: pin $k is empty or has characters outside [a-zA-Z0-9._-]: '$v'" >&2; exit 1 ;;
  esac
done

# The Claude seat has no CLI to query, so its candidate list is a fixed enum — the
# four values the Agent tool accepts. Without this, a plausible-looking answer like
# "claude-opus-4" is charset-clean, gets written, and only fails when the seat launches.
case "$(jq -r '.claude.model' "$PINS")" in
  sonnet|opus|haiku|fable) ;;
  *) echo "council: claude pin must be one of sonnet|opus|haiku|fable" >&2; exit 1 ;;
esac

mkdir -p "$HOME/.claude"
tmp=$(mktemp "${TMPDIR:-/tmp}/council-reg-XXXXXX")
if jq -n --slurpfile p "$PINS" \
  --argjson now "$(date +%s)" --arg today "$(date -u +%Y-%m-%d)" '
  {schema: "council-models/v1",
   checked_at: $today, checked_at_epoch: $now,
   seats: {
     codex:  {model: $p[0].codex.model, effort: $p[0].codex.effort, service_tier: $p[0].codex.service_tier},
     agy:    {model: $p[0].agy.model},
     claude: {model: $p[0].claude.model}
   },
   codex_config: {check_for_update_on_startup: true}}
' > "$tmp"; then
  mv "$tmp" "$REG"
else
  rm -f "$tmp"
  echo "council: registry write failed — previous pins left intact" >&2
  exit 1
fi
```

Write it through the temp file, as above. A bare `>` truncates the registry before `jq` runs, so
a failing `jq` would destroy a perfectly good set of pins and silently send the next run back to
first-run defaults.

Defaults on first run: codex `gpt-5.6-sol` / `xhigh` / `fast`, agy `gemini-3.6-flash-high`,
claude `opus`.

### codex update setting

When writing the registry, also make sure `~/.codex/config.toml` carries
`check_for_update_on_startup = true`. Only write it when the key is absent — never rewrite keys
the user set. In the same breath as the weekly pin question, offer to run `codex update`.
**Never run it mid-council**: it replaces the running binary, so a seat can vanish in the middle
of a debate.

**Insert before the first table header, never append.** `check_for_update_on_startup` is a
top-level key, and a real `config.toml` ends inside a table (`[projects."…"]`,
`[hooks.state."…"]`). A line appended to the end belongs to that last table, so the setting
silently does nothing and `--strict-config` may reject the file outright.

A machine with no `config.toml` yet still needs the setting, so create the file rather than
skipping. And **verify after writing** — a write that failed while the run continued would let
the probe below pass with the key still absent, which reads as "configured" when it is not.

Both the presence check and the verification must be **TOML-scope aware**. A plain `grep` for the
key matches one nested under `[projects."…"]` just as happily as a top-level one, so it would
report "already configured" while the effective setting is still absent — and it would accept
`= false` as success. The `awk` below only counts a `true` assignment that appears before the
first table header.

**"Not true" and "not there" are different, and only one of them may be written.** A user who
deliberately set `check_for_update_on_startup = false` has made a decision; inserting a second
assignment above it leaves a duplicate key in their global Codex config — invalid TOML that can
break every later `codex` invocation, and it survives even when the verification aborts. Absent
means insert; present-but-not-true means report and leave it alone.

```bash
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"   # codex honors CODEX_HOME (project_state.sh)
CFG="$CODEX_DIR/config.toml"
KEY='check_for_update_on_startup'

# top_level_true -> exit 0 only when the key is set to true ABOVE the first [table].
# The status is decided in a single END exit: an `exit 0` inside a main rule jumps
# to END, and an `exit` there would overwrite it — the awk trap that made an
# earlier version reject a correctly-configured file every time.
top_level_true() {
  awk -v key="$KEY" '
    done_scan { next }
    /^[[:space:]]*\[/ { done_scan = 1; next }          # first table ends top level
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      v = $0
      sub(/^[^=]*=[[:space:]]*/, "", v)                # drop "key ="
      sub(/#.*$/, "", v)                               # drop an inline comment
      sub(/[[:space:]]+$/, "", v)
      if (v == "true") ok = 1
      done_scan = 1; next
    }
    END { exit ok ? 0 : 1 }' "$1"
}

# top_level_present -> exit 0 when the key appears at all above the first [table],
# whatever its value. Same single-END-exit discipline as top_level_true.
top_level_present() {
  awk -v key="$KEY" '
    done_scan { next }
    /^[[:space:]]*\[/ { done_scan = 1; next }
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" { found = 1; done_scan = 1; next }
    END { exit found ? 0 : 1 }' "$1"
}

mkdir -p "$CODEX_DIR"; [ -f "$CFG" ] || : > "$CFG"
if top_level_true "$CFG"; then
  :                                        # already what we want
elif top_level_present "$CFG"; then
  # Set, but not to true — the user's own choice. Never append a second key.
  echo "council: $KEY is already set to a non-true value in $CFG; leaving it untouched." >&2
  echo "council: codex will not auto-check for updates. Change it yourself if that is not intended." >&2
else
  tmp=$(mktemp "${TMPDIR:-/tmp}/codex-cfg-XXXXXX")
  # Emit the key before the first `[table]` line; if the file has no table at
  # all, every line is already top-level and the key goes at the end.
  if awk -v key="$KEY" 'BEGIN{done=0}
       !done && /^[[:space:]]*\[/ {print key " = true"; done=1}
       {print}
       END{if(!done) print key " = true"}' "$CFG" > "$tmp" && mv "$tmp" "$CFG"; then
    # Verify rather than assume — this is the line that makes "configured" mean something.
    top_level_true "$CFG" \
      || { echo "council: $KEY is not a top-level true after the write — treat it as NOT set" >&2; exit 1; }
  else
    rm -f "$tmp"; echo "council: codex config write failed — $KEY NOT set" >&2; exit 1
  fi
fi
```

Confirm the result parses before relying on it — `codex exec --strict-config` rejects a malformed
or unknown-key config, so one probe call proves the edit landed as a top-level key.

Verify a pin is still valid on the installed CLI before relying on it. This costs one fast call
and catches a config key that a codex upgrade removed:

Three things this block must get right, each of which was wrong in an earlier draft. It
re-reads the pins (this is a separate tool call, so nothing from the write block survives). It
guards on `codex` being installed — the failure policy makes a missing binary an absent seat, and
an unguarded probe would kill the run with `command not found` before that path is reached. And
it **branches on the probe's exit status**: a probe whose result is never checked is not a check.

```bash
REG="$HOME/.claude/council-models.json"
CODEX_MODEL=$(jq -r '.seats.codex.model'        "$REG")
CODEX_EFFORT=$(jq -r '.seats.codex.effort'      "$REG")
CODEX_TIER=$(jq -r '.seats.codex.service_tier'  "$REG")
out=$(mktemp "${TMPDIR:-/tmp}/council-probe-XXXXXX")

# The probe must carry the SAME configuration the Round 1 call will use, service
# tier included. Leaving the tier out lets a pin whose model and effort are still
# accepted pass here and fail at the seat, which is the one thing a preflight is
# supposed to prevent.
if ! command -v codex >/dev/null 2>&1; then
  echo "SEAT=codex ABSENT reason=binary-not-on-path"
elif codex exec --strict-config -s read-only --skip-git-repo-check \
       -m "$CODEX_MODEL" -c model_reasoning_effort="\"$CODEX_EFFORT\"" \
       -c service_tier="\"$CODEX_TIER\"" \
       -o "$out" - <<'PROBE'
reply with exactly: OK
PROBE
then
  echo "SEAT=codex OK"
else
  echo "SEAT=codex FAILED reason=probe-rejected-model-or-config"
fi
rm -f "$out"
```

`SEAT=codex FAILED` is **not** the same as absent — the binary is there and rejected the pinned
model or the config. Surface it and offer the registry question rather than silently seating a
model that will fail again in Round 1. An unknown key fails with `unknown configuration field`;
an unknown model fails in seconds with an HTTP 400. Neither hangs.

---

## Step 1 — set up the run and pre-collect context

`$SLUG` is a short kebab-case topic name you derive from the question. **Validate it before it
reaches a path** — it comes from free text, and a `/` or a `..` segment would place the run
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
nothing else clears it — a finished council would otherwise block every later invocation, and
telling the user to "finish that council" cannot help because it already did. Step 5 removes it
on both the success and the give-up path:

```bash
RUN_KEY="${CLAUDE_SESSION_ID:-${CODEX_COMPANION_SESSION_ID:-shared}}"
case "$RUN_KEY" in *[!A-Za-z0-9._-]*) echo "council: invalid session id" >&2; exit 1 ;; esac
rm -f ".claude/state/council-run-$RUN_KEY"
[ "$RUN_KEY" = shared ] && rmdir ".claude/state/council-lock-shared" 2>/dev/null
exit 0
```

The directory is **git-tracked** — it is the decision record, not scratch. The run pointer under
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
path being read, so an id containing `..` would pull an arbitrary file's contents into `$DIR` —
and `$DIR` is where every prompt and answer then gets written.

### What to pre-collect, and what not to

codex and agy read files on their own. **Anything reachable by a path is passed as a path**, not
pasted. Only collect what a path cannot carry:

| Source | Why a path will not do |
|---|---|
| mem0 memories | Behind an MCP service, not a file at all. Two searches (decisions, task learnings) keep the seats from re-proposing something already rejected. |
| Serena symbol graph | `find_referencing_symbols` output needs a language-server index. agy cannot build one. |
| scout research | Facts outside the repo. Most expensive — only when the question actually turns on external facts. |

Do **not** paste `AGENTS.md`, `.llmwiki/` pages, or source files. Cite their paths.

Write the shared brief to `$DIR/brief.md`: the question, the resolved facts, the pre-collected
context, and the file paths worth reading.

---

## Step 2 — Round 1, independent opinions

Compose `$DIR/r1-prompt.md` from the brief plus these instructions to every seat:

1. Answer the question directly with reasoning.
2. Separately list **open questions for the user** — only things that would change the answer
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
empty opinion — see the failure policy.

---

## Step 3 — re-question gate

Merge the seats' open questions. Drop duplicates, and drop anything the chair can answer itself
from the repo or by running a read-only command — **facts are the chair's job, decisions are the
user's**. Ask what remains through the interactive-input gate, in the user's language, in one
batch.

Record the questions and the user's answers in `$DIR/questions.md`.

If the user declines to answer, carry those items forward as unresolved and say so in the
final document rather than guessing.

---

## Step 4 — Round 2, mutual rebuttal

Compose `$DIR/r2-prompt.md` containing, for each seat: the other two seats' full Round 1
answers, the user's answers from Step 3, and the instruction to state where it agrees, where it
disagrees, and why — with reasons, not verdicts.

The Claude seat's prompt carries an extra line: **attack the strongest argument among the other
seats first.** It shares weights with the chair, so agreement is its cheapest and least useful
move; the role exists to stop it defaulting there.

Run the same three commands as Step 2 against `r2-prompt.md`, writing `r2-codex.md`,
`r2-agy.md`, `r2-claude.md`. Each round is a fresh CLI invocation carrying the debate in its
prompt — deterministic, and no dependence on `--resume-last` picking the right session.

---

## Step 5 — synthesis and output

The chair writes `$DIR/consensus.md`:

- **합의** — what the seats converged on, and on what grounds.
- **갈린 이견** — positions that survived rebuttal, each with its holder and its strongest
  argument. Do not average them into a fake middle.
- **미해결** — what nobody could answer, plus questions the user left open.
- **결석** — any seat that did not participate, and why.

Apply the **same-family consensus discount**. The Claude seat shares weights with the chair, so
its agreement is not an independent second judgment. Count it only when it brought an argument
the chair had not already made; otherwise record the agreement without treating it as support.

Print 합의 / 갈린 이견 / 미해결 to the conversation, and **결석 whenever any seat was absent** —
leave the rest of the record in the files. Dropping the absence line is what makes a two-seat
result read as a full three-seat council.

**Do not apply anything to the code.** Present the conclusion and stop. Acting on a council
result is a separate, explicit request.

---

## Failure policy

Seats fail independently and the council continues without them. Every absence is named in
`consensus.md` and in the chat summary — a quiet absence would make a two-seat result look like
a three-seat one.

| Situation | Action |
|---|---|
| `codex` or `agy` missing from PATH | Mark the seat absent. Continue. |
| agy produced no file, or an empty one | Retry once with the same prompt, then mark absent. |
| agy log shows `auth timed out` / `silent auth failed` | Do not retry — the model never ran. Tell the user to run `agy` once interactively to re-authenticate. |
| codex returns HTTP 400 on the model | The pin is stale. Surface it and offer the Step 0 registry question. |
| All three seats fail | There is no council. Report and stop; do not synthesize from nothing. |

Triage an agy failure by matching its most recent log against the three known signatures. Match
and report the classification, not the log body — the log sits in an agent configuration
directory and its lines carry paths, settings, and auth diagnostics that the triage decision does
not need. Grepping for the three patterns answers the question with none of that exposure:

```bash
LOG=$(ls -t "$HOME/.gemini/antigravity-cli/log/"cli-*.log 2>/dev/null | head -1)
if [ -z "$LOG" ]; then
  echo "agy-triage: no log found"
elif grep -qE 'auth timed out|silent auth failed|keyringAuth: timed out' "$LOG"; then
  echo "agy-triage: auth-timeout"      # the model never ran — do not retry
elif grep -qE 'rename .*Access is denied' "$LOG"; then
  echo "agy-triage: file-lock"         # transient — the one retry is worth it
elif grep -qE 'text_drip.*length=' "$LOG"; then
  echo "agy-triage: output-dropped"    # generated but not delivered — retry
else
  echo "agy-triage: unclassified"
fi
```

Show the raw log only if the user asks for it after seeing the classification.
