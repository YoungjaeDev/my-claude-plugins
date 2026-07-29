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
#   2. Registry TTL arithmetic (execute it). The freshness decision is what stops
#      the skill from either nagging weekly or silently running a stale pin.
#
# No network and no CLI calls: the runner contracts are read out of the document,
# and the TTL block runs against a temp registry.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$HERE/../SKILL.md"
pass=0; fail=0

ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; }
is()  { [ "$2" = "$3" ] && ok "$1" || bad "$1" "$3" "$2"; }
has() { grep -qF -- "$2" "$SKILL" && ok "$1" || bad "$1" "present: $2" "absent"; }

echo "runner contracts in SKILL.md"

# agy blocks forever without this redirect; --print-timeout does not bound it.
has "agy call closes stdin with < /dev/null" '--print "$AGY_PROMPT" < /dev/null'
# Go's flag parser eats the next token as the prompt, so --print must come last.
has "--print is the last flag before the prompt" '--model "$AGY_MODEL" --print'
has "agy model comes from the registry"          '$AGY_MODEL'

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

# The chair must not silently field a two-seat council as if it were three.
has "absent seats are recorded"  '결석'
# Registry is global, not per-repo — a new repo must not re-ask on day one.
has "registry is global"         '$HOME/.claude/council-models.json'

echo
echo "registry TTL arithmetic"

T=$(mktemp -d "${TMPDIR:-/tmp}/council-tests-XXXXXX")
trap 'rm -rf "$T"' EXIT
REG="$T/council-models.json"

# state_of REG -> missing | fresh | expired  (the Step 0 block, verbatim)
state_of() {
  if [ ! -f "$1" ]; then echo missing; return; fi
  local now checked ttl
  now=$(date +%s)
  checked=$(jq -r '.checked_at_epoch // 0' "$1")
  ttl=$(( $(jq -r '.ttl_days // 7' "$1") * 86400 ))
  if [ $(( now - checked )) -gt "$ttl" ]; then echo expired; else echo fresh; fi
}

is "absent registry reads as missing" "$(state_of "$REG")" missing

# The Step 0 writer, verbatim.
jq -n --arg cm gpt-5.6-sol --arg ce xhigh --arg ct fast \
      --arg am gemini-3.6-flash-high --arg clm opus \
      --argjson now "$(date +%s)" --arg today "$(date -u +%Y-%m-%d)" '
  {schema: "council-models/v1",
   checked_at: $today, checked_at_epoch: $now, ttl_days: 7,
   seats: {codex: {model: $cm, effort: $ce, service_tier: $ct},
           agy: {model: $am}, claude: {model: $clm}},
   codex_config: {check_for_update_on_startup: true}}' > "$REG"

is "freshly written registry is fresh"    "$(state_of "$REG")" fresh
is "all three seats are pinned"           "$(jq -r '.seats | keys | join(",")' "$REG")" "agy,claude,codex"
is "claude seat defaults to opus"         "$(jq -r '.seats.claude.model' "$REG")" opus
is "codex seat carries effort and tier"   "$(jq -r '.seats.codex | "\(.effort)/\(.service_tier)"' "$REG")" "xhigh/fast"

# One day inside the window still counts as fresh; one day past it does not.
jq --argjson o "$(( $(date +%s) - 6*86400 ))" '.checked_at_epoch=$o' "$REG" > "$T/x" && mv "$T/x" "$REG"
is "6 days old is still fresh"            "$(state_of "$REG")" fresh
jq --argjson o "$(( $(date +%s) - 8*86400 ))" '.checked_at_epoch=$o' "$REG" > "$T/x" && mv "$T/x" "$REG"
is "8 days old has expired"               "$(state_of "$REG")" expired

# A registry with no timestamp must expire rather than be trusted forever.
jq 'del(.checked_at_epoch)' "$REG" > "$T/x" && mv "$T/x" "$REG"
is "registry without a timestamp expires" "$(state_of "$REG")" expired

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
