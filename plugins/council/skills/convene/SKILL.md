---
name: convene
description: Convene a cross-vendor model council — codex (GPT), agy (Gemini) and a Claude Opus seat answer independently, hand their follow-up questions back to the user, then rebut each other before the chair synthesizes agreement and surviving disagreement. Use when a decision needs a genuinely different model's judgment rather than more Claude sampling, or when the user asks to hear from another model. Korean triggers — "council", "카운슬", "심의", "다른 모델 의견", "codex랑 agy한테 물어봐", "토론시켜", "합의 봐줘", "2차 의견". English triggers — "convene a council", "second opinion from another model", "cross-model debate", "ask codex and gemini", "have the models argue".
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
- **Hermes** — use `clarify`.

This plugin is Claude-only in practice (it is listed in `CODEX_EXCLUDED`, and the Claude seat
needs the `Agent` tool), so the Claude row is the operative one. The other rows are kept so the
body never asserts that a single interactive tool exists.

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

```bash
REG="$HOME/.claude/council-models.json"
if [ ! -f "$REG" ]; then
  echo "STATE=missing"
else
  NOW=$(date +%s)
  CHECKED=$(jq -r '.checked_at_epoch // 0' "$REG")
  TTL=$(( $(jq -r '.ttl_days // 7' "$REG") * 86400 ))
  # -ge, not -gt: at exactly ttl_days the pin has reached its stated life and is
  # due for confirmation. -gt would keep it fresh for one more second.
  if [ $(( NOW - CHECKED )) -ge "$TTL" ]; then echo "STATE=expired"; else echo "STATE=fresh"; fi
  jq -r '.seats | to_entries[] | "\(.key)=\(.value | tostring)"' "$REG"
fi
```

- `STATE=fresh` — go to Step 1. Ask nothing.
- `STATE=missing` or `STATE=expired` — confirm the pins with the user before convening. Expiry
  **always** asks, even when nothing changed. Deciding whether a newer model is actually better
  belongs to the user, and a silent upgrade drifts into unintended spend.

Gather the real candidate lists first so the question carries evidence rather than guesses:

```bash
# Absence and failure are different answers and must not collapse into one.
# `cmd && list || echo absent` swallows every non-zero exit — an expired agy
# login or an unparseable cache would be reported as "not installed", and the
# pin question would then be asked with no real candidate list behind it.

# codex: slugs plus the reasoning levels each one accepts
if [ ! -f "$HOME/.codex/models_cache.json" ]; then
  echo "(codex model cache absent)"
elif ! jq -r '
  .models[] | select(.visibility != "hide")
  | "\(.slug)  efforts=\([.supported_reasoning_levels[].effort] | join(","))  speed=\(.additional_speed_tiers // [] | join(","))"
' "$HOME/.codex/models_cache.json"; then
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
keep or change them. Accept a natural-language answer ("codex를 luna로 바꿔줘"). Then write the
file — note `checked_at_epoch`, which keeps the TTL arithmetic off `date -d` and portable:

Write it through a temp file. A bare `>` truncates the registry before `jq` runs, so a failing
`jq` would destroy a perfectly good set of pins and silently send the next run back to first-run
defaults.

```bash
mkdir -p "$HOME/.claude"
REG="$HOME/.claude/council-models.json"
tmp=$(mktemp "${TMPDIR:-/tmp}/council-reg-XXXXXX")
if jq -n \
  --arg cm "$CODEX_MODEL" --arg ce "$CODEX_EFFORT" --arg ct "$CODEX_TIER" \
  --arg am "$AGY_MODEL" --arg clm "$CLAUDE_MODEL" \
  --argjson now "$(date +%s)" --arg today "$(date -u +%Y-%m-%d)" '
  {schema: "council-models/v1",
   checked_at: $today, checked_at_epoch: $now, ttl_days: 7,
   seats: {
     codex:  {model: $cm, effort: $ce, service_tier: $ct},
     agy:    {model: $am},
     claude: {model: $clm}
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

```bash
CFG="$HOME/.codex/config.toml"
if [ -f "$CFG" ] && ! grep -qE '^[[:space:]]*check_for_update_on_startup[[:space:]]*=' "$CFG"; then
  tmp=$(mktemp "${TMPDIR:-/tmp}/codex-cfg-XXXXXX")
  # Emit the key before the first `[table]` line; if the file has no table at
  # all, every line is already top-level and the key goes at the end.
  awk 'BEGIN{done=0}
       !done && /^[[:space:]]*\[/ {print "check_for_update_on_startup = true"; done=1}
       {print}
       END{if(!done) print "check_for_update_on_startup = true"}' "$CFG" > "$tmp" \
    && mv "$tmp" "$CFG" || { rm -f "$tmp"; echo "council: codex config update failed" >&2; }
fi
```

Confirm the result parses before relying on it — `codex exec --strict-config` rejects a malformed
or unknown-key config, so one probe call proves the edit landed as a top-level key.

Verify a pin is still valid on the installed CLI before relying on it. This costs one fast call
and catches a config key that a codex upgrade removed:

```bash
codex exec --strict-config -s read-only --skip-git-repo-check \
  -m "$CODEX_MODEL" -c model_reasoning_effort="\"$CODEX_EFFORT\"" - <<'PROBE'
reply with exactly: OK
PROBE
```

An unknown key fails with `unknown configuration field`; an unknown model fails in seconds with
an HTTP 400. Neither hangs.

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

BASE=".council/$(date -u +%Y-%m-%d)-$SLUG"; DIR="$BASE"; n=2
while [ -e "$DIR" ]; do DIR="$BASE-$n"; n=$((n+1)); done
mkdir -p "$DIR"

# Shell variables do NOT survive between tool calls — each bash block below is a
# separate process. Park the run directory where later blocks can re-read it.
# .claude/state/ is gitignored and machine-local, which is what a run pointer is.
mkdir -p .claude/state && printf '%s\n' "$DIR" > .claude/state/council-current-run
echo "DIR=$DIR"
```

The directory is **git-tracked** — it is the decision record, not scratch. The run pointer under
`.claude/state/` is not.

### Re-hydrating state in every later block

Every bash block from here on starts with this, because nothing set in an earlier block is still
in scope. Skipping it hands empty model names and an empty output path to the first seat call:

```bash
REG="$HOME/.claude/council-models.json"
DIR=$(cat .claude/state/council-current-run)
CODEX_MODEL=$(jq -r '.seats.codex.model'        "$REG")
CODEX_EFFORT=$(jq -r '.seats.codex.effort'      "$REG")
CODEX_TIER=$(jq -r '.seats.codex.service_tier'  "$REG")
AGY_MODEL=$(jq -r '.seats.agy.model'            "$REG")
CLAUDE_MODEL=$(jq -r '.seats.claude.model'      "$REG")
[ -n "$DIR" ] && [ -d "$DIR" ] || { echo "council: no active run directory" >&2; exit 1; }
```

### What to pre-collect, and what not to

codex and agy read files on their own. **Anything reachable by a path is passed as a path**, not
pasted. Only collect what a path cannot carry:

| Source | Why a path will not do |
|---|---|
| mem0 memories | Behind an MCP service, not a file at all. Two searches (decisions, task learnings) keep the seats from re-proposing something already rejected. |
| Serena symbol graph | `find_referencing_symbols` output needs a language-server index. agy cannot build one. |
| code-scout research | Facts outside the repo. Most expensive — only when the question actually turns on external facts. |

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
REG="$HOME/.claude/council-models.json"; DIR=$(cat .claude/state/council-current-run)
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
REG="$HOME/.claude/council-models.json"; DIR=$(cat .claude/state/council-current-run)
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
