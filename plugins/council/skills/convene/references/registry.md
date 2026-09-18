# Registry — Step 0 detail

Full procedure for the model registry (Step 0), pulled out of SKILL.md so the body keeps only
the decision rule. Referenced from SKILL.md's Step 0.

## Step 0 — resolve the model registry

Seat models are pinned in `~/.claude/council-models.json` so they survive across repos and are
confirmed at most once a week.

The seven-day window is a **constant here, never a field read back from the registry.** A TTL
taken from the file it governs is not a guarantee: one hand-edited `ttl_days` and the pins never
come up for confirmation again, which is exactly the "always ask on expiry" property this design
was chosen for. A timestamp that is missing, non-numeric, or in the future is treated as expired
for the same reason: those are the shapes a corrupted or tampered registry takes, and none of
them should buy indefinite freshness.

Freshness also requires the pins to actually be there. A registry whose `checked_at_epoch` is
recent but whose `seats` block is missing, malformed, or empty would otherwise read as `fresh`,
and the seats would then run with a model name of `null`. Anything that fails to parse or is
missing a seat pin is `expired`, which routes it back through confirmation instead of forward
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

- `STATE=fresh`: the pins are still current; run the validity check below and, if it passes, go
  to Step 1 without asking anything.
- `STATE=missing` or `STATE=expired`: confirm the pins with the user before convening. Expiry
  **always** asks, even when nothing changed. Deciding whether a newer model is actually better
  belongs to the user, and a silent upgrade drifts into unintended spend.

### Fresh does not mean valid

A CLI update can retire a model inside the seven-day window. The failure table says a pin that
has vanished from the candidate list is asked about **before** expiry, so `fresh` cannot skip
straight to Step 1: otherwise the run reaches Round 1 with a dead pin and merely records the
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
though the TTL has not elapsed. A `LIST_UNREAD=` line means the opposite: say nothing about that
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
against the candidate list you just printed: a name that is not on the list goes back to the
user rather than into the registry. Then write the file; `checked_at_epoch` is what keeps the TTL
arithmetic off `date -d` and portable.

**The confirmed pins never pass through shell source.** Two failure modes sit on either side of
that rule: hard-coding defaults into the block throws the user's actual choice away, and pasting
their answer into a quoted string hands `$(…)` and stray quotes to the shell. Neither is
necessary: the pins are data, so write them as data.

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
`check_for_update_on_startup = true`. Only write it when the key is absent; never rewrite keys
the user set. In the same breath as the weekly pin question, offer to run `codex update`.
**Never run it mid-council**: it replaces the running binary, so a seat can vanish in the middle
of a debate.

**Insert before the first table header, never append.** `check_for_update_on_startup` is a
top-level key, and a real `config.toml` ends inside a table (`[projects."…"]`,
`[hooks.state."…"]`). A line appended to the end belongs to that last table, so the setting
silently does nothing and `--strict-config` may reject the file outright.

A machine with no `config.toml` yet still needs the setting, so create the file rather than
skipping. And **verify after writing**: a write that failed while the run continued would let
the probe below pass with the key still absent, which reads as "configured" when it is not.

Both the presence check and the verification must be **TOML-scope aware**. A plain `grep` for the
key matches one nested under `[projects."…"]` just as happily as a top-level one, so it would
report "already configured" while the effective setting is still absent, and it would accept
`= false` as success. The `awk` below only counts a `true` assignment that appears before the
first table header.

**"Not true" and "not there" are different, and only one of them may be written.** A user who
deliberately set `check_for_update_on_startup = false` has made a decision; inserting a second
assignment above it leaves a duplicate key in their global Codex config: invalid TOML that can
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

Confirm the result parses before relying on it: `codex exec --strict-config` rejects a malformed
or unknown-key config, so one probe call proves the edit landed as a top-level key.

Verify a pin is still valid on the installed CLI before relying on it. This costs one fast call
and catches a config key that a codex upgrade removed:

Three things this block must get right, each of which was wrong in an earlier draft. It
re-reads the pins (this is a separate tool call, so nothing from the write block survives). It
guards on `codex` being installed: the failure policy makes a missing binary an absent seat, and
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

`SEAT=codex FAILED` is **not** the same as absent: the binary is there and rejected the pinned
model or the config. Surface it and offer the registry question rather than silently seating a
model that will fail again in Round 1. An unknown key fails with `unknown configuration field`;
an unknown model fails in seconds with an HTTP 400. Neither hangs.
