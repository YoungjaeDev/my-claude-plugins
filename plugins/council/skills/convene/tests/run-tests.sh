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

# Pull the Nth ```bash fence that follows a heading containing $1, verbatim.
# This is what keeps the executable cases honest: the bytes under test are the
# bytes the skill instructs an agent to run.
extract_bash_block() {
  awk -v anchor="$1" -v want="$2" '
    !found { if (index($0, anchor)) found = 1; next }
    !inb   { if ($0 == "```bash") { n++; if (n == want) inb = 1 } ; next }
    $0 == "```" { exit }
    { print }
  ' "$SKILL"
}

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
has "seat blocks re-hydrate their pins"  'DIR=$(cat .claude/state/council-current-run)'
# $SLUG reaches a path and comes from free text.
has "SLUG is validated before path use"  '*[!a-z0-9-]*'
# A bare `>` truncates the registry before jq runs.
has "registry is written through a temp file" 'mv "$tmp" "$REG"'
# check_for_update_on_startup is top-level; appending nests it under the last table.
has "codex config key goes before the first table" 'print key " = true"; done=1'
# A codex-less machine is an absent seat, not a dead run.
has "codex probe is guarded on the binary"         'if command -v codex >/dev/null 2>&1; then'
# A TTL read back from the file it governs is not a guarantee.
has "TTL is a constant, not a registry field"      'TTL=$(( 7 * 86400 ))'
# The chair must not silently field a two-seat council as if it were three.
has "absences reach the chat summary"    '결석 whenever any seat was absent'
# Registry is global, not per-repo — a new repo must not re-ask on day one.
has "registry is global"                 '$HOME/.claude/council-models.json'

echo
echo "registry behavior (blocks extracted from SKILL.md, not re-typed)"

ANCHOR='## Step 0 — resolve the model registry'
READER=$(extract_bash_block "$ANCHOR" 1)
WRITER=$(extract_bash_block "$ANCHOR" 3)

# A renamed heading or a reordered fence must fail loudly, not silently extract
# nothing and let every case below "pass" against an empty script.
case "$READER" in *checked_at_epoch*) ok "reader block extracted from SKILL.md" ;;
  *) bad "reader block extracted from SKILL.md" "block containing checked_at_epoch" "$(printf '%.60s' "$READER")" ;; esac
case "$WRITER" in *'council-models/v1'*) ok "writer block extracted from SKILL.md" ;;
  *) bad "writer block extracted from SKILL.md" "block containing council-models/v1" "$(printf '%.60s' "$WRITER")" ;; esac

T=$(mktemp -d "${TMPDIR:-/tmp}/council-tests-XXXXXX")
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/home"
REG="$T/home/.claude/council-models.json"

# Run the extracted reader against a throwaway HOME and report just its verdict.
state_of() { HOME="$T/home" bash -c "$READER" 2>/dev/null | sed -n 's/^STATE=//p'; }
# Run the extracted writer with NOTHING injected. Feeding the pins in through the
# environment is what previously hid the real defect: the documented block never
# re-assigned them, so following the skill literally wrote five empty strings
# while this suite stayed green. If the block stops being self-contained, the
# pin assertions below go empty and fail — which is the point.
write_registry() { HOME="$T/home" bash -c "$WRITER" >/dev/null 2>&1; }
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
if HOME="$T/home" PATH="$T/nojq:$PATH" bash -c "$WRITER" >/dev/null 2>&1; then rc=0; else rc=1; fi
is "writer reports failure when jq fails" "$rc" 1
is "failed write keeps the old registry"  "$(cat "$REG")" "$before"

# Empty pins must be refused outright rather than written as valid-looking JSON.
WRITER_EMPTY=$(printf '%s\n' "$WRITER" | awk \
  '/^CODEX_MODEL=/ {print "CODEX_MODEL=\"\"; CODEX_EFFORT=\"\"; CODEX_TIER=\"\""; next}
   /^AGY_MODEL=/   {print "AGY_MODEL=\"\"; CLAUDE_MODEL=\"\""; next}
   {print}')
if HOME="$T/home" bash -c "$WRITER_EMPTY" >/dev/null 2>&1; then rc=0; else rc=1; fi
is "empty pins are refused"               "$rc" 1
is "refused write leaves the registry alone" "$(cat "$REG")" "$before"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
