# Registry: Step 0

The 6 bash blocks for Step 0 of `SKILL.md`: read the registry, check the pins against the candidate
lists, print the lists for the pin question, write confirmed pins, keep the codex update setting,
and probe codex. Seat models are pinned in `~/.claude/council-models.json` so they survive across
repos and are confirmed at most once a week.

## Read the registry

The seven-day window is a constant in this block, never a field read back from the registry: a TTL
taken from the file it governs would let one hand-edited `ttl_days` stop the pins from ever coming
up again. A missing, non-numeric or future timestamp is expired, and so is a registry whose `seats`
block fails to parse or lacks a pin, so a broken file routes back through confirmation instead of
into a call with a model of `null`.

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

- **`STATE=fresh`**: run the candidate-list check below and, if it prints nothing, go to Step 1
  without asking anything.
- **`STATE=missing` or `STATE=expired`**: confirm the pins with the user before convening. Expiry
  always asks, even when nothing changed, because judging whether a newer model is better belongs to
  the user.

## Check the pins against the candidate lists

A CLI update can retire a model inside the seven-day window, so `fresh` never skips straight to Step
1. Each list is read once into a variable, and only a successful, non-empty read may accuse a pin; a
truncated catalog or a failed `agy` call must not look like a retired model.

codex's catalog comes from `codex debug models` (JSON, `.models[].slug`; see `codex debug --help`),
with `models_cache.json` only as the fallback for a CLI that predates the subcommand. For agy only
the first field of each line is the slug, whether `agy models` prints bare slugs or
`slug<TAB>Display Name`. When a pin you just saw in a listing still comes back as `STALE_PIN`, run
that listing once and look at its format before asking the user anything.

```bash
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"   # codex honors CODEX_HOME
REG="$HOME/.claude/council-models.json"
CM=$(jq -r '.seats.codex.model' "$REG"); AM=$(jq -r '.seats.agy.model' "$REG")

# codex — the CLI's own catalog first; the cache file only when the subcommand
# is missing or fails. A parse failure or an empty list is a read failure, never
# a retirement.
codex_json=""
if command -v codex >/dev/null 2>&1 && codex_json=$(codex debug models 2>/dev/null); then
  :
elif [ -f "$CODEX_DIR/models_cache.json" ]; then
  codex_json=$(cat "$CODEX_DIR/models_cache.json")
fi
if [ -z "$codex_json" ]; then
  echo "LIST_UNREAD=codex reason=catalog-absent"
elif ! codex_slugs=$(printf '%s\n' "$codex_json" | jq -r '.models[].slug' 2>/dev/null) \
     || [ -z "$codex_slugs" ]; then
  echo "LIST_UNREAD=codex reason=catalog-unparseable"
elif ! printf '%s\n' "$codex_slugs" | grep -qxF "$CM"; then
  echo "STALE_PIN=codex:$CM"
fi

# agy: one invocation, captured, so a failed listing never reads as a missing pin.
# Only field 1 is the slug: agy 1.2.9 separates it with a tab, the headless docs
# show aligned spaces.
if ! command -v agy >/dev/null 2>&1; then
  echo "LIST_UNREAD=agy reason=binary-absent"
elif ! agy_out=$(agy models 2>/dev/null); then
  echo "LIST_UNREAD=agy reason=listing-failed"
elif agy_slugs=$(printf '%s\n' "$agy_out" | awk 'NF {print $1}') && [ -z "$agy_slugs" ]; then
  echo "LIST_UNREAD=agy reason=listing-empty"
elif ! printf '%s\n' "$agy_slugs" | grep -qxF "$AM"; then
  echo "STALE_PIN=agy:$AM"
fi
```

A `STALE_PIN=` line means: tell the user which pin disappeared and ask for a replacement, even
though the TTL has not elapsed. A `LIST_UNREAD=` line means say nothing about that seat's pin,
because a list you could not read is not evidence of anything.

## Ask with the real candidate lists

Print the lists first so the pin question carries evidence rather than guesses. Absence and failure
are different answers: an expired agy login or an unparseable cache must not read as "not
installed".

```bash
# codex: slugs, the reasoning levels each one accepts, speed tiers.
# Source is `codex debug models`; the cache file is the fallback for an older CLI,
# resolved through CODEX_HOME because that is the directory the running CLI reads.
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
codex_json=""
if command -v codex >/dev/null 2>&1 && codex_json=$(codex debug models 2>/dev/null); then
  :
elif [ -f "$CODEX_DIR/models_cache.json" ]; then
  codex_json=$(cat "$CODEX_DIR/models_cache.json")
fi
if [ -z "$codex_json" ]; then
  echo "(codex model catalog absent)"
elif ! printf '%s\n' "$codex_json" | jq -r '
  .models[] | select(.visibility != "hide")
  | "\(.slug)  efforts=\([.supported_reasoning_levels[].effort] | join(","))  speed=\(.additional_speed_tiers // [] | join(","))"
'; then
  echo "(codex model catalog unreadable — present but unparseable)" >&2
fi

# agy: the slug is the first tab-separated field; the rest is a display name
if ! command -v agy >/dev/null 2>&1; then
  echo "(agy absent)"
elif ! agy models; then
  echo "(agy model listing failed — auth or network, not absence)" >&2
fi
```

When a list fails rather than being absent, say so in the pin question and never present that side
as "no models available". Show the current pins next to the lists and ask with `AskUserQuestion`
whether to keep or change them.

Accept a natural-language answer ("codex를 luna로 바꿔줘") and resolve it against the list you just
printed; a name not on the list goes back to the user, not into the registry. First-run proposals:
the first visible codex entry (`visibility != "hide"`) at effort `xhigh` when it lists it, else its
highest level, plus its first speed tier; the first agy slug; claude `opus`.

## Write confirmed pins

The confirmed pins never pass through shell source. Record the answer with the `Write` tool (not a
heredoc, not `echo`) to `.claude/state/council-pins.json`, so no value the user typed can become a
command:

```json
{
  "codex":  {"model": "<codex slug>", "effort": "<one of its efforts>", "service_tier": "<one of its speed tiers>"},
  "agy":    {"model": "<agy slug>"},
  "claude": {"model": "opus"}
}
```

This block reads that file, checks every pin against a conservative charset and the Claude seat's
enum, and hands the values to `jq` through `--slurpfile`. A bad pin stops the write, and the temp
file keeps a failing `jq` from truncating a good registry:

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

# The Claude seat has no CLI to query, so its candidate list is a fixed policy enum of
# model aliases (the Agent tool also takes full model IDs and `inherit`; see
# https://code.claude.com/docs/en/sub-agents#choose-a-model). A charset-clean name
# like "claude-opus-4" would otherwise only fail when the seat launches.
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

A Claude value outside the enum is a policy change to this skill, not a per-run choice: re-read
<https://code.claude.com/docs/en/sub-agents#choose-a-model> before answering the user.

## Keep the codex update setting

With the registry write, make sure `${CODEX_HOME:-$HOME/.codex}/config.toml` carries a top-level
`check_for_update_on_startup = true`, and offer to run `codex update` with the weekly pin question.
Never run it mid-council: it replaces the running binary, so a seat can vanish in the middle of a
debate.

- **Insert, never append**: the key is top-level, and a real `config.toml` ends inside a table
  (`[projects."…"]`), so an appended line would belong to that table and do nothing.
- **Scope-aware checks**: the `awk` below counts only an assignment above the first table header, so
  a nested key or `= false` never reads as configured.
- **Absent vs not true**: absent means insert. Present but not `true` is the user's decision: report
  it and leave the file alone, because a second assignment is a duplicate key that breaks every
  later `codex` call.
- **Missing file and verification**: a machine with no `config.toml` gets one created, and the block
  re-checks after writing so a failed write never reads as configured.

```bash
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"   # codex honors CODEX_HOME
CFG="$CODEX_DIR/config.toml"
KEY='check_for_update_on_startup'

# top_level_true -> exit 0 only when the key is set to true ABOVE the first [table].
# The status is decided in a single END exit: an `exit 0` inside a main rule jumps
# to END, and an `exit` there would overwrite it.
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

## Probe codex before Step 1

One fast call proves the pins work on the installed CLI: `--strict-config` rejects a malformed or
unknown-key config, and an unknown model fails in seconds with an HTTP 400. The block re-reads the
pins (a separate tool call keeps nothing), treats a missing binary as an absent seat rather than a
dead run, and branches on the probe's exit status.

```bash
REG="$HOME/.claude/council-models.json"
CODEX_MODEL=$(jq -r '.seats.codex.model'        "$REG")
CODEX_EFFORT=$(jq -r '.seats.codex.effort'      "$REG")
CODEX_TIER=$(jq -r '.seats.codex.service_tier'  "$REG")
out=$(mktemp "${TMPDIR:-/tmp}/council-probe-XXXXXX")

# The probe carries the SAME configuration the Round 1 call will use, service
# tier included, so a pin that fails at the seat also fails here.
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

`SEAT=codex FAILED` is not the same as absent: the binary is there and rejected the pinned model or
config (`unknown configuration field`, or an HTTP 400). Surface it and offer the registry question
rather than seating a model that will fail again in Round 1.
