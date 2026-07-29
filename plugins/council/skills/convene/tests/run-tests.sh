#!/usr/bin/env bash
# Usage: bash plugins/council/skills/convene/tests/run-tests.sh
#
# The convene skill has no bundled scripts — its runner contracts and its
# registry arithmetic live as shell inside SKILL.md, where nothing executes them.
# Two classes of breakage are silent and expensive, so they are asserted here:
#
#   1. Runner contracts (grep the document). Dropping `< /dev/null` from the agy
#      call makes it block forever on a TTY that never arrives, and
#      `--print-timeout` does not bound it. Parsing codex stdout instead of its
#      `-o` file picks up hook lines and token counts as if they were the answer.
#      Neither failure is caught by check-shell-portability.
#   2. Registry behavior (execute it). The blocks are EXTRACTED FROM SKILL.md and
#      run against a throwaway HOME — never re-typed here. A copy would let a
#      regression in the real Step 0 block leave this suite green, which is the
#      one outcome that makes the suite worse than having none.
#
# No network and no CLI calls.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$HERE/../SKILL.md"
pass=0; fail=0

ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; }
is()  { [ "$2" = "$3" ] && ok "$1" || bad "$1" "$3" "$2"; }
has() { grep -qF -- "$2" "$SKILL" && ok "$1" || bad "$1" "present: $2" "absent"; }

# Pull the first ```bash fence whose body contains $1, verbatim. Anchoring on
# content rather than an ordinal is deliberate: inserting one new fence earlier in
# the document would silently shift a positional index onto the wrong block, and
# the suite would then test something other than what it claims to.
# This is what keeps the executable cases honest — the bytes under test are the
# bytes the skill instructs an agent to run.
extract_bash_block_with() {
  awk -v marker="$1" '
    /^```bash$/ { inb=1; n=0; hit=0; next }
    inb && /^```$/ {
      if (hit) { for (i = 1; i <= n; i++) print buf[i]; exit }
      inb=0; next
    }
    inb { buf[++n] = $0; if (index($0, marker)) hit=1 }
  ' "$SKILL"
}

echo "document structure"

# An unclosed fence swallows the prose that follows it, and the extractor then
# hands that prose to bash as if it were script. Caught exactly that in review.
is "code fences are balanced" "$(( $(grep -c '^```' "$SKILL") % 2 ))" 0
is "no markdown prose inside a bash fence" \
   "$(awk '/^```bash$/{inb=1;next} inb&&/^```$/{inb=0;next} inb&&/^\*\*[A-Z"]/{n++} END{print n+0}' "$SKILL")" 0

echo
echo "runner contracts in SKILL.md"

# agy blocks forever without this redirect; --print-timeout does not bound it.
has "agy call closes stdin with < /dev/null" '--print "$AGY_PROMPT" < /dev/null'
# Go's flag parser eats the next token as the prompt, so --print must come last.
has "--print is the last flag before the prompt" '--model "$AGY_MODEL" --print'

# codex stdout interleaves hook lines and a token count; -o carries the answer.
has "codex captures its answer with -o"     '-o "$DIR/r1-codex.md"'
# `-` reads the prompt from stdin, so no user text is ever re-parsed by the shell.
has "codex takes its prompt on stdin"       '- < "$DIR/r1-prompt.md"'
has "codex effort is quoted as TOML"        'model_reasoning_effort="\"$CODEX_EFFORT\""'

# GNU-only date math would break on macOS; epoch seconds behave the same on both.
# Only the positive intent is asserted here — check-shell-portability.mjs already
# owns "no unguarded GNU-only construct", and it distinguishes a real invocation
# from prose that merely names one. Re-implementing that distinction with grep
# would just false-flag this file's own explanation of why epochs are used.
has "TTL uses epoch arithmetic"  'checked_at_epoch'

# Nothing set in one bash block survives into the next; the seat blocks must say so.
has "seat blocks re-hydrate their pins"  'DIR=$(cat ".claude/state/council-run-$RUN_KEY")'
# Two concurrent councils in one repo must not share a run pointer.
has "run pointer is keyed by session"    'DIR=$(cat ".claude/state/council-run-$RUN_KEY")'
# RUN_KEY lands in a filename, so it needs the same gate $SLUG gets — in EVERY
# fence that interpolates it, not just somewhere in the document. A presence grep
# would let one site lose its gate while another site's copy kept the test green.
is "every RUN_KEY fence validates the id" \
   "$(awk '
      /^```bash$/ { inb=1; uses=0; gate=0; next }
      inb && /^```$/ { if (uses && !gate) bad++; inb=0; next }
      inb {
        if (index($0, "council-run-$RUN_KEY") || index($0, "council-run-shared")) uses=1
        if (index($0, "A-Za-z0-9._-")) gate=1
      }
      END { print bad+0 }' "$SKILL")" 0
# With no session id there is no safe way to separate two runs — refuse the second.
has "no-session-id concurrency is refused" 'another run is already active at'
# A read failure must not masquerade as a retired model.
has "unread lists are reported separately" 'LIST_UNREAD=codex reason=cache-unparseable'
# A user's deliberate `false` must not gain a duplicate key above it.
has "an existing non-true setting is preserved" 'leaving it untouched'
# The writer requires service_tier, so freshness must require it too.
has "service_tier is a required pin"     '(.seats.codex.service_tier // "") != ""'
# codex reads $CODEX_HOME when set; $HOME/.codex is then a directory it never opens.
has "codex paths resolve through CODEX_HOME" 'CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"'
# A probe whose exit status is never inspected is not a check.
has "codex probe branches on its result" 'SEAT=codex FAILED reason=probe-rejected-model-or-config'
# Confirmed pins are data, never shell source.
has "pins are read from a JSON file"     'PINS=".claude/state/council-pins.json"'
# $SLUG reaches a path and comes from free text.
has "SLUG is validated before path use"  '*[!a-z0-9-]*'
# A bare `>` truncates the registry before jq runs.
has "registry is written through a temp file" 'mv "$tmp" "$REG"'
# check_for_update_on_startup is top-level; appending nests it under the last table.
has "codex config key goes before the first table" 'print key " = true"; done=1'
# A codex-less machine is an absent seat, not a dead run.
has "codex probe is guarded on the binary"         'if ! command -v codex >/dev/null 2>&1; then'
# A TTL read back from the file it governs is not a guarantee.
has "TTL is a constant, not a registry field"      'TTL=$(( 7 * 86400 ))'
# The chair must not silently field a two-seat council as if it were three.
has "absences reach the chat summary"    '결석 whenever any seat was absent'
# Registry is global, not per-repo — a new repo must not re-ask on day one.
has "registry is global"                 '$HOME/.claude/council-models.json'

echo
echo "registry behavior (blocks extracted from SKILL.md, not re-typed)"

READER=$(extract_bash_block_with 'TTL=$(( 7 * 86400 ))')
WRITER=$(extract_bash_block_with 'council-models/v1')
CFGBLOCK=$(extract_bash_block_with 'top_level_true')

# A renamed heading or a reordered fence must fail loudly, not silently extract
# nothing and let every case below "pass" against an empty script.
case "$READER" in *checked_at_epoch*) ok "reader block extracted from SKILL.md" ;;
  *) bad "reader block extracted from SKILL.md" "block containing checked_at_epoch" "$(printf '%.60s' "$READER")" ;; esac
case "$WRITER" in *'council-models/v1'*) ok "writer block extracted from SKILL.md" ;;
  *) bad "writer block extracted from SKILL.md" "block containing council-models/v1" "$(printf '%.60s' "$WRITER")" ;; esac

T=$(mktemp -d "${TMPDIR:-/tmp}/council-tests-XXXXXX")
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/home" "$T/cwd/.claude/state"
REG="$T/home/.claude/council-models.json"
PINS="$T/cwd/.claude/state/council-pins.json"

# The writer resolves $PINS relative to the working directory, so both the reader
# and the writer run from a throwaway cwd as well as a throwaway HOME.
seed_pins() {
  cat > "$PINS" <<'PINEOF'
{"codex":{"model":"gpt-5.6-sol","effort":"xhigh","service_tier":"fast"},
 "agy":{"model":"gemini-3.6-flash-high"},
 "claude":{"model":"opus"}}
PINEOF
}
seed_pins

# Run the extracted reader against a throwaway HOME and report just its verdict.
state_of() { HOME="$T/home" bash -c "$READER" 2>/dev/null | sed -n 's/^STATE=//p'; }
# Run the extracted writer with NOTHING injected. Feeding the pins in through the
# environment is what previously hid a real defect: the documented block never
# re-assigned them, so following the skill literally wrote five empty strings
# while this suite stayed green. The pins now arrive as a FILE the agent wrote
# with the Write tool, so no user value is ever parsed by a shell.
write_registry() { ( cd "$T/cwd" && HOME="$T/home" bash -c "$WRITER" ) >/dev/null 2>&1; }
# Rewind checked_at_epoch by $1 days without touching anything else.
age_registry() {
  jq --argjson o "$(( $(date +%s) - $1 * 86400 ))" '.checked_at_epoch=$o' "$REG" > "$T/x" \
    && mv "$T/x" "$REG"
}

is "absent registry reads as missing"     "$(state_of)" missing

write_registry
is "writer creates the registry"          "$([ -f "$REG" ] && echo yes || echo no)" yes
is "freshly written registry is fresh"    "$(state_of)" fresh
is "all three seats are pinned"           "$(jq -r '.seats | keys | join(",")' "$REG")" "agy,claude,codex"
is "claude seat defaults to opus"         "$(jq -r '.seats.claude.model' "$REG")" opus
is "codex seat carries effort and tier"   "$(jq -r '.seats.codex | "\(.effort)/\(.service_tier)"' "$REG")" "xhigh/fast"
is "codex update setting is recorded"     "$(jq -r '.codex_config.check_for_update_on_startup' "$REG")" true

age_registry 6; is "6 days old is still fresh"  "$(state_of)" fresh
# The boundary itself: at exactly seven days the pin is due, not good one more second.
age_registry 7; is "exactly 7 days has expired" "$(state_of)" expired
age_registry 8; is "8 days old has expired"     "$(state_of)" expired

# The shapes a corrupted or tampered registry takes must not buy freshness.
jq 'del(.checked_at_epoch)' "$REG" > "$T/x" && mv "$T/x" "$REG"
is "registry without a timestamp expires" "$(state_of)" expired
write_registry
jq '.checked_at_epoch="not-a-number"' "$REG" > "$T/x" && mv "$T/x" "$REG"
is "non-numeric timestamp expires"        "$(state_of)" expired
write_registry
age_registry -3                           # three days in the FUTURE
is "future timestamp expires"             "$(state_of)" expired
# A registry that inflates its own TTL must not extend the window.
write_registry
jq '.ttl_days=3650' "$REG" > "$T/x" && mv "$T/x" "$REG"
age_registry 8
is "injected ttl_days cannot extend the window" "$(state_of)" expired

# A failed write must leave the previous pins intact rather than truncate them.
# This is the whole point of the temp-file indirection: with a bare `>` the
# registry is already gone by the time jq reports failure. Assert the failure
# actually happened — otherwise a shim that silently did not take would leave the
# registry byte-identical and this case would "pass" having proven nothing.
write_registry                      # restore a good registry
before=$(cat "$REG")
mkdir -p "$T/nojq"
printf '#!/bin/sh\nexit 1\n' > "$T/nojq/jq"; chmod +x "$T/nojq/jq"
if ( cd "$T/cwd" && HOME="$T/home" PATH="$T/nojq:$PATH" bash -c "$WRITER" ) >/dev/null 2>&1; then rc=0; else rc=1; fi
is "writer reports failure when jq fails" "$rc" 1
is "failed write keeps the old registry"  "$(cat "$REG")" "$before"

# The pin file is the trust boundary — every bad shape must stop the write.
try_pins() {  # $1 = pin-file body; echoes the writer's exit code
  printf '%s\n' "$1" > "$PINS"
  if ( cd "$T/cwd" && HOME="$T/home" bash -c "$WRITER" ) >/dev/null 2>&1; then echo 0; else echo 1; fi
}
is "empty pin value is refused"  "$(try_pins '{"codex":{"model":"","effort":"xhigh","service_tier":"fast"},"agy":{"model":"a"},"claude":{"model":"opus"}}')" 1
is "missing seat is refused"     "$(try_pins '{"codex":{"model":"m","effort":"xhigh","service_tier":"fast"},"claude":{"model":"opus"}}')" 1
is "unparseable pin file is refused" "$(try_pins 'not json at all')" 1
# Shell metacharacters must be rejected by the charset gate, not executed.
is "command substitution is refused"  "$(try_pins '{"codex":{"model":"$(touch '"$T"'/pwned)","effort":"xhigh","service_tier":"fast"},"agy":{"model":"a"},"claude":{"model":"opus"}}')" 1
is "injection did not execute"        "$([ -e "$T/pwned" ] && echo yes || echo no)" no
is "quote injection is refused"       "$(try_pins '{"codex":{"model":"a\"; rm -rf /tmp/x; \"","effort":"xhigh","service_tier":"fast"},"agy":{"model":"a"},"claude":{"model":"opus"}}')" 1
is "every refused write left the registry alone" "$(cat "$REG")" "$before"
seed_pins                           # restore good pins for any later case

echo
echo "codex config block — TOML scope (extracted from SKILL.md, executed)"

case "$CFGBLOCK" in *check_for_update_on_startup*) ok "config block extracted from SKILL.md" ;;
  *) bad "config block extracted from SKILL.md" "block defining top_level_true" "$(printf '%.60s' "$CFGBLOCK")" ;; esac

# Run the real block against a throwaway CODEX_HOME seeded with $1, then report
# whether the setting ends up recognised as a top-level true. Grepping for the
# awk's presence is not enough — an `exit 0` inside a main rule jumps to END,
# where a second `exit` would silently overwrite the status. Only executing it
# catches that.
cfg_verdict() {
  local home="$T/codex-$RANDOM$$"; mkdir -p "$home"
  printf '%s\n' "$1" > "$home/config.toml"
  if ( CODEX_HOME="$home" HOME="$T/home" bash -c "$CFGBLOCK" ) >/dev/null 2>&1; then
    # block succeeded — report what the file now says at top level
    awk '/^[[:space:]]*\[/{exit} /^[[:space:]]*check_for_update_on_startup[[:space:]]*=/{
           sub(/^[^=]*=[[:space:]]*/,""); sub(/#.*$/,""); sub(/[[:space:]]+$/,""); print; exit}' \
      "$home/config.toml"
  else
    echo "BLOCKED"
  fi
}

# How many times the key ends up in the file — a duplicate TOML key is the damage
# an append-when-not-true would leave behind in the user's global config.
cfg_count_key() {
  local home="$T/codex-count-$RANDOM$$"; mkdir -p "$home"
  printf '%s\n' "$1" > "$home/config.toml"
  ( CODEX_HOME="$home" HOME="$T/home" bash -c "$CFGBLOCK" ) >/dev/null 2>&1
  grep -cE '^[[:space:]]*check_for_update_on_startup[[:space:]]*=' "$home/config.toml"
}

is "already-true config is accepted as-is" \
   "$(cfg_verdict 'model = "x"
check_for_update_on_startup = true
[projects."a"]')" true
# A user who set it to false made a decision. Inserting a second assignment above
# it leaves a duplicate key in their global config — invalid TOML that outlives
# the abort. The block must leave the file exactly as it found it.
is "an explicit false is left untouched" \
   "$(cfg_verdict 'check_for_update_on_startup = false')" false
is "an explicit false gains no duplicate key" \
   "$(cfg_count_key 'check_for_update_on_startup = false')" 1
is "inline comment after true is accepted" \
   "$(cfg_verdict 'check_for_update_on_startup = true # keep me')" true
# The key nested under a table is NOT the effective setting — the block must add
# a real top-level one rather than declaring success.
is "table-scoped key gets a top-level one added" \
   "$(cfg_verdict 'model = "x"
[projects."a"]
check_for_update_on_startup = true')" true
is "an empty config gains the key" "$(cfg_verdict '')" true
# A config that ends inside a table is the shape that made a naive append nest the key.
is "config ending in a table still gets top level" \
   "$(cfg_verdict '[hooks.state."a"]
enabled = true')" true

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
