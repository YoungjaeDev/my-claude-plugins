#!/usr/bin/env bash
# Usage: bash plugins/github-dev/skills/cr-fix/tests/run-tests.sh
#
# Fixture-driven checks for the two cr-fix paths that only execute when the
# primary path has already failed, and which therefore had nothing exercising
# them (issue #105): the CodeRabbit CLI JSONL parser, and the commit-state
# reader that decides whether a review has finished.
#
# No network, no `gh`, no live PR. cr-commit-state.sh reads its two HTTP
# responses from CR_STATE_STATUSES_FILE / CR_STATE_CHECKRUNS_FILE when set.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/../scripts"
FIX="$HERE/fixtures"
pass=0; fail=0

ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; }
is()   { [ "$2" = "$3" ] && ok "$1" || bad "$1" "$3" "$2"; }

# run_capped SECS CMD... -- run CMD, SIGTERM it after SECS, pass its stdout through.
# The portable stand-in for GNU `timeout`, which stock macOS/BSD does not ship;
# used where the script under test only ends on an external signal. Always used
# (never gated behind `command -v timeout`) so the GNU CI leg exercises the same
# path a Mac takes -- a fallback only BSD reaches is a fallback that rots.
# The watchdog's own stdout is closed, or command substitution would block on it.
run_capped() {
  local secs=$1; shift
  "$@" & local cmd_pid=$!
  ( sleep "$secs"; kill -TERM "$cmd_pid" 2>/dev/null ) >/dev/null 2>&1 & local wd_pid=$!
  wait "$cmd_pid" 2>/dev/null; local rc=$?
  kill -TERM "$wd_pid" 2>/dev/null; wait "$wd_pid" 2>/dev/null
  return "$rc"
}

echo "parse-cr-cli-jsonl.sh"

# CLI 0.6.5: `suggestions` holds patch STRINGS. `.suggestions[0].line` aborted jq
# with `Cannot index string with string "line"` and killed the fallback too.
out=$(bash "$SCRIPTS/parse-cr-cli-jsonl.sh" "$FIX/cr-cli-0.6.5-findings.jsonl" 2>/dev/null); rc=$?
is "0.6.5 exits 0 (string suggestions do not abort jq)" "$rc" 0
is "0.6.5 yields 3 findings"        "$(jq 'length' <<<"$out")" 3
is "0.6.5 line from 'around lines'" "$(jq -r '.[0].line' <<<"$out")" 11
is "0.6.5 line from 'at line'"      "$(jq -r '.[1].line' <<<"$out")" 4
is "0.6.5 severity maps to emoji"   "$(jq -r '.[0].severity_emoji' <<<"$out")" "🟠 Major"
is "0.6.5 body falls back to codegenInstructions" \
   "$(jq -r '.[0].body | length > 0' <<<"$out")" true

# 0.5.x still parses: object suggestions, `comment` present.
out=$(bash "$SCRIPTS/parse-cr-cli-jsonl.sh" "$FIX/cr-cli-0.5.x-findings.jsonl" 2>/dev/null); rc=$?
is "0.5.x exits 0"                  "$rc" 0
is "0.5.x line from suggestions[0]" "$(jq -r '.[0].line' <<<"$out")" 42
is "0.5.x type_emoji from comment header" \
   "$(jq -r '.[0].type_emoji' <<<"$out")" "🎯 Functional Correctness"
is "0.5.x nitpick header parsed"    "$(jq -r '.[1].type_emoji' <<<"$out")" "📝 Nitpick"

# A genuinely unparseable line must degrade, not abort.
out=$(bash "$SCRIPTS/parse-cr-cli-jsonl.sh" "$FIX/cr-cli-malformed.jsonl" 2>/dev/null); rc=$?
is "malformed exits 0"              "$rc" 0
is "malformed keeps valid findings" "$(jq 'length' <<<"$out")" 2

echo
echo "cr-commit-state.sh"

state() {
  CR_STATE_STATUSES_FILE="$FIX/$1" CR_STATE_CHECKRUNS_FILE="$FIX/$2" \
    bash "$SCRIPTS/cr-commit-state.sh" o r sha 2>/dev/null
}

# The issue #105 case: /statuses empty, CodeRabbit reports via check-run.
s=$(state statuses-empty.json checkruns-cr-success.json)
is "check-run success -> success"   "$(jq -r '.state' <<<"$s")" success
is "check-run success -> channel"   "$(jq -r '.channel' <<<"$s")" check_run
is "check-run picks the CodeRabbit run, not 'check'" \
   "$(jq -r '.target_url' <<<"$s")" "https://coderabbit.ai/r/1"

s=$(state statuses-empty.json checkruns-cr-inprogress.json)
is "check-run in_progress -> pending" "$(jq -r '.state' <<<"$s")" pending

# Queued run (started_at null) must beat an older completed run — null sorts
# newest, or the stale success masks the queued re-review.
s=$(state statuses-empty.json checkruns-cr-queued-after-success.json)
is "queued after success -> pending"  "$(jq -r '.state' <<<"$s")" pending

s=$(state statuses-empty.json checkruns-cr-failure.json)
is "check-run timed_out -> failure"   "$(jq -r '.state' <<<"$s")" failure

# commit-status wins when present, and carries the rate-limit description.
s=$(state statuses-cr-ratelimited.json checkruns-cr-success.json)
is "status preferred over check-run"  "$(jq -r '.channel' <<<"$s")" status
is "status description preserved"     "$(jq -r '.description' <<<"$s")" "Review limit reached"

s=$(state statuses-empty.json checkruns-empty.json)
is "neither surface -> none"          "$(jq -r '.state' <<<"$s")" none

# Fetch failure must be its own state, not masked as "none" (== "no CR row").
# __FAIL__ sentinel simulates auth/network/rate-limit. (issue #110 step 4)
s=$(CR_STATE_STATUSES_FILE=__FAIL__ bash "$SCRIPTS/cr-commit-state.sh" o r sha 2>/dev/null)
is "statuses fetch failure -> error"  "$(jq -r '.state' <<<"$s")" error
is "statuses fetch failure -> channel status" "$(jq -r '.channel' <<<"$s")" status
s=$(CR_STATE_STATUSES_FILE="$FIX/statuses-empty.json" CR_STATE_CHECKRUNS_FILE=__FAIL__ \
      bash "$SCRIPTS/cr-commit-state.sh" o r sha 2>/dev/null)
is "checkruns fetch failure -> error" "$(jq -r '.state' <<<"$s")" error
is "checkruns fetch failure -> channel check_run" "$(jq -r '.channel' <<<"$s")" check_run

# A completed check-run reports completion via completed_at; started_at is older
# and made CR_SKIP_GRACE misfire. created_at must prefer completed_at. (step 4)
s=$(state statuses-empty.json checkruns-cr-completed-at.json)
is "check_run created_at prefers completed_at" "$(jq -r '.created_at' <<<"$s")" "2026-07-10T02:47:00Z"

echo
echo "fetch-cr-threads.sh"

# A null repository (errors null AND repository null) exited the old detector 4,
# unmatched, so the loop projected [] — a false clean convergence. It must fail
# instead. CR_THREADS_RESPONSE_FILE replaces the GraphQL call. (issue #110 step 1)
out=$(CR_THREADS_RESPONSE_FILE="$FIX/gql-null-repository.json" \
        bash "$SCRIPTS/fetch-cr-threads.sh" o r 42 2>/dev/null); rc=$?
is "null repository -> non-zero exit"  "$([ "$rc" -ne 0 ] && echo yes || echo no)" yes
is "null repository -> emits no []"    "$out" ""
out=$(CR_THREADS_RESPONSE_FILE="$FIX/gql-healthy-empty.json" \
        bash "$SCRIPTS/fetch-cr-threads.sh" o r 42 2>/dev/null); rc=$?
is "healthy empty -> exit 0"           "$rc" 0
is "healthy empty -> []"               "$out" "[]"

# Same silent-failure family, one level deeper: a non-null repository whose
# pullRequest is null (wrong PR number, deleted PR) passed the repository-only
# detector and still projected [] — false clean. The detector must require the
# reviewThreads.nodes array itself. (codex counsel P2)
out=$(CR_THREADS_RESPONSE_FILE="$FIX/gql-null-pullrequest.json" \
        bash "$SCRIPTS/fetch-cr-threads.sh" o r 42 2>/dev/null); rc=$?
is "null pullRequest -> non-zero exit" "$([ "$rc" -ne 0 ] && echo yes || echo no)" yes
is "null pullRequest -> emits no []"   "$out" ""

# Round-3 detector hardening: an empty errors OBJECT ({}), a missing pageInfo,
# and hasNextPage=true without a cursor all slipped the predicate — the first
# two silently truncate multi-page threads, the third re-reads the first page
# forever (a hang). (CR Major, iter 3)
out=$(CR_THREADS_RESPONSE_FILE="$FIX/gql-errors-empty-object.json" \
        bash "$SCRIPTS/fetch-cr-threads.sh" o r 42 2>/dev/null); rc=$?
is "errors empty-object -> non-zero exit" "$([ "$rc" -ne 0 ] && echo yes || echo no)" yes
out=$(CR_THREADS_RESPONSE_FILE="$FIX/gql-missing-pageinfo.json" \
        bash "$SCRIPTS/fetch-cr-threads.sh" o r 42 2>/dev/null); rc=$?
is "missing pageInfo -> non-zero exit"    "$([ "$rc" -ne 0 ] && echo yes || echo no)" yes
# rc must be the detector's clean 1, not a hang killed by the timeout guard.
TMO2=""; command -v timeout >/dev/null 2>&1 && TMO2="timeout 10"
out=$(CR_THREADS_RESPONSE_FILE="$FIX/gql-cursorless-next.json" \
        $TMO2 bash "$SCRIPTS/fetch-cr-threads.sh" o r 42 2>/dev/null); rc=$?
is "cursorless hasNextPage -> detector rc 1" "$rc" 1

echo
echo "auto-merge-gate.sh"

# Unprotected base returns 404: the old pipe emitted "404\n404", which --argjson
# rejected and killed the whole gate. It must yield a single clean 404. (step 2)
SHIMDIR=$(mktemp -d)
cat > "$SHIMDIR/gh" <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  "api --paginate"*) echo '[]';;
  "pr checks") echo '0';;
  "pr view") echo "main";;
  "api repos"*) echo "HTTP/2.0 404 Not Found"; exit 1;;
  *) echo "unknown gh args: $*" >&2; exit 1;;
esac
SH
chmod +x "$SHIMDIR/gh"
g=$(PATH="$SHIMDIR:$PATH" bash "$SCRIPTS/auto-merge-gate.sh" o r 42 deadbeef 2>/dev/null)
is "unprotected base -> valid JSON"    "$(jq -e . <<<"$g" >/dev/null 2>&1 && echo yes || echo no)" yes
is "unprotected base -> protection_http 404" "$(jq -r '.protection_http' <<<"$g" 2>/dev/null)" 404

# Probe failure (network/auth/5xx — gh dies with no status line) must NOT
# masquerade as 404 "unprotected": it reports protection_http 0 so Step 15
# refuses to merge on an unverified protection state. (codex counsel P1)
cat > "$SHIMDIR/gh" <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  "api --paginate"*) echo '[]';;
  "pr checks") echo '0';;
  "pr view") echo "main";;
  "api repos"*) exit 1;;
  *) echo "unknown gh args: $*" >&2; exit 1;;
esac
SH
g=$(PATH="$SHIMDIR:$PATH" bash "$SCRIPTS/auto-merge-gate.sh" o r 42 deadbeef 2>/dev/null)
is "probe failure -> protection_http 0" "$(jq -r '.protection_http' <<<"$g" 2>/dev/null)" 0

# Check-run-only CR repo: CR posts 0 commit statuses and 1 check-run. The old
# status-only cr_state read saw nothing -> "unknown" -> Step 15 never merged on
# --auto-merge. Now it delegates to cr-commit-state.sh (dual-surface), so a
# completed/success check-run yields cr_state:"success". RED against the
# status-only implementation by construction. (self-found, PR #122)
cat > "$SHIMDIR/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"/check-runs"*) echo '{"check_runs":[{"name":"CodeRabbit","status":"completed","conclusion":"success","started_at":"2025-01-01T00:00:00Z"}]}';;
  *"/statuses"*)   echo '[]';;
  "pr checks"*)    echo '0';;
  "pr view"*)      echo "main";;
  *"/protection"*) echo "HTTP/2.0 404 Not Found"; exit 1;;
  *) echo "unknown gh args: $*" >&2; exit 1;;
esac
SH
chmod +x "$SHIMDIR/gh"
g=$(PATH="$SHIMDIR:$PATH" bash "$SCRIPTS/auto-merge-gate.sh" o r 42 deadbeef 2>/dev/null)
is "check-run-only CR -> cr_state success" "$(jq -r '.cr_state' <<<"$g" 2>/dev/null)" success
rm -rf "$SHIMDIR"

echo
echo "cr-cli-spawn.sh"

# grep -c on zero matches printed "0" and exited 1; the old `|| echo 0` appended a
# second 0, so `[ "0\n0" -gt 0 ]` errored. A shimmed coderabbit lets us drive the
# whole script without the CLI. (issue #110 step 5)
CRSHIM=$(mktemp -d)
cat > "$CRSHIM/coderabbit" <<'SH'
#!/usr/bin/env bash
printf '{"type":"finding"}\n{"type":"finding"}\n'
SH
chmod +x "$CRSHIM/coderabbit"
so=$(PATH="$CRSHIM:$PATH" BASE=main PR_NUM=990001 ITER=1 bash "$SCRIPTS/cr-cli-spawn.sh" 2>/dev/null)
se=$(PATH="$CRSHIM:$PATH" BASE=main PR_NUM=990001 ITER=1 bash "$SCRIPTS/cr-cli-spawn.sh" 2>&1 >/dev/null)
is "0 completes -> marker valid JSON"  "$(jq -e . <<<"$so" >/dev/null 2>&1 && echo yes || echo no)" yes
is "0 completes -> no integer-expr err" "$(printf '%s' "$se" | grep -c 'integer expression')" 0
is "0 completes -> emitted_complete false" "$(jq -r '.emitted_complete' <<<"$so")" false
cat > "$CRSHIM/coderabbit" <<'SH'
#!/usr/bin/env bash
printf '{"type":"finding"}\n{"type":"complete"}\n'
SH
so=$(PATH="$CRSHIM:$PATH" BASE=main PR_NUM=990002 ITER=1 bash "$SCRIPTS/cr-cli-spawn.sh" 2>/dev/null)
is "complete present -> emitted_complete true" "$(jq -r '.emitted_complete' <<<"$so")" true
rm -rf "$CRSHIM" /tmp/cr-cli-review-990001-iter1-* /tmp/cr-cli-review-990002-iter1-*

echo
echo "query-cr-rate-limit.sh (parse seam)"

# Parse-only, no network: feed captured @coderabbitai reply bodies. (step 9)
p=$(bash "$SCRIPTS/query-cr-rate-limit.sh" parse < "$FIX/cr-ratelimit-reply-full.txt")
is "reply full -> remaining"           "$(jq -r '.remaining' <<<"$p")" 3
is "reply full -> reset_minutes"       "$(jq -r '.reset_minutes' <<<"$p")" 41
p=$(bash "$SCRIPTS/query-cr-rate-limit.sh" parse < "$FIX/cr-ratelimit-reply-reset-only.txt")
is "reply reset-only -> remaining null" "$(jq -r '.remaining' <<<"$p")" null
is "reply reset-only -> reset 12"      "$(jq -r '.reset_minutes' <<<"$p")" 12
p=$(bash "$SCRIPTS/query-cr-rate-limit.sh" parse < "$FIX/cr-ratelimit-reply-none.txt")
is "reply no-signal -> remaining null" "$(jq -r '.remaining' <<<"$p")" null
is "reply no-signal -> reset null"     "$(jq -r '.reset_minutes' <<<"$p")" null

# A transient gh failure mid-poll (secondary rate limit, 502) must not kill the
# bounded poll via set -e on the bare `reply=$(...)` assignment: the script must
# survive the round and still emit its terminal JSON line. (review P2)
QSHIM=$(mktemp -d)
cat > "$QSHIM/gh" <<'SH'
#!/usr/bin/env bash
case "$1" in
  pr)  exit 0;;   # @coderabbitai post succeeds
  api) exit 1;;   # comments fetch fails transiently
  *)   exit 1;;
esac
SH
chmod +x "$QSHIM/gh"
q=$(PATH="$QSHIM:$PATH" QUERY_CR_POLLS=1 QUERY_CR_SLEEP=0 \
      bash "$SCRIPTS/query-cr-rate-limit.sh" o r 42 2>/dev/null); qrc=$?
is "gh failure mid-poll -> exit 0"        "$qrc" 0
is "gh failure mid-poll -> replied false" "$(jq -r '.replied' <<<"$q" 2>/dev/null)" false
rm -rf "$QSHIM"

# Id-anchored reply detection. The old filter anchored on a LOCAL `date -u`
# POST_TIME, so a runner clock ahead of GitHub filtered the genuine reply
# forever; and a ghost (null-user) comment crashed jq's test(), forcing
# reply="" every round. Fixture timestamps are fixed in the past, so this is
# RED against the local-clock anchor by construction. (counsel P1 + P2)
# The shim echoes the #issuecomment-<id> URL real `gh pr comment` prints;
# the fixture reply id (1001) > anchor (1000) is the fresh-reply signal.
QSHIM2=$(mktemp -d)
cat > "$QSHIM2/gh" <<SH
#!/usr/bin/env bash
case "\$1" in
  pr)  echo "https://github.com/o/r/pull/42#issuecomment-1000";;
  api) cat "$FIX/issue-comments-rl.json";;
  *)   exit 1;;
esac
SH
chmod +x "$QSHIM2/gh"
q=$(PATH="$QSHIM2:$PATH" QUERY_CR_POLLS=1 QUERY_CR_SLEEP=0 \
      bash "$SCRIPTS/query-cr-rate-limit.sh" o r 42 2>/dev/null) || true
is "id-anchored reply -> replied true" "$(jq -r '.replied' <<<"$q" 2>/dev/null)" true
is "id-anchored reply -> remaining 3"  "$(jq -r '.remaining' <<<"$q" 2>/dev/null)" 3
is "ghost user tolerated -> reset 41"  "$(jq -r '.reset_minutes' <<<"$q" 2>/dev/null)" 41
rm -rf "$QSHIM2"

# A PREVIOUS run's identical "@coderabbitai rate limit" post + reply must not
# be returned as this query's answer while the new post is not yet visible in
# the list API. Body-match `last` anchoring picked the old post (id 500) and
# served its stale reply (id 501) as fresh; id-anchoring (anchor 1000 from the
# POST URL) sees no reply with id > 1000 and keeps polling. RED against the
# body-anchor implementation by construction. (Codex P2 iter 4)
QSHIM3=$(mktemp -d)
cat > "$QSHIM3/gh" <<SH
#!/usr/bin/env bash
case "\$1" in
  pr)  echo "https://github.com/o/r/pull/42#issuecomment-1000";;
  api) cat "$FIX/issue-comments-rl-stale.json";;
  *)   exit 1;;
esac
SH
chmod +x "$QSHIM3/gh"
q=$(PATH="$QSHIM3:$PATH" QUERY_CR_POLLS=1 QUERY_CR_SLEEP=0 \
      bash "$SCRIPTS/query-cr-rate-limit.sh" o r 42 2>/dev/null) || true
is "stale prior-run reply -> replied false" "$(jq -r '.replied' <<<"$q" 2>/dev/null)" false
is "stale prior-run reply -> reset null"    "$(jq -r '.reset_minutes' <<<"$q" 2>/dev/null)" null
rm -rf "$QSHIM3"

echo
echo "poll-codex-grace.sh"

# An unprocessed Codex review must be found and emitted by id.
GSHIM=$(mktemp -d)
cat > "$GSHIM/gh" <<SH
#!/usr/bin/env bash
cat "$FIX/pr-reviews-codex.json"
SH
chmod +x "$GSHIM/gh"
g=$(PATH="$GSHIM:$PATH" OWNER=o REPO=r PR_NUM=42 PROCESSED='[555]' INTERVAL=0 \
      bash "$SCRIPTS/poll-codex-grace.sh" 2>/dev/null) || true
is "unprocessed review found -> id 777" "$(jq -r '.codex_review_id' <<<"$g" 2>/dev/null)" 777
rm -rf "$GSHIM"

# No unprocessed review -> the poll must KEEP WAITING, not emit a fabricated
# empty id. Without jq -r the empty jq result printed the two-char string '""',
# which passed [ -n ] and ended the until-loop on round 1 (reproduced live:
# grace poll returned {"codex_review_id":""} instantly). RED against the -s
# variant by construction. poll-codex-grace.sh has no bounded-round env (its
# contract is "caller wraps with a timeout"), so this case needs a real
# loop-breaker. It used GNU `timeout`, absent on stock macOS/BSD, so the whole
# block was skipped there and this regression had zero coverage on the platform
# the pre-commit hook actually runs on. run_capped is the portable stand-in;
# env(1) carries the environment so no assignment leaks into the shell.
GSHIM2=$(mktemp -d)
cat > "$GSHIM2/gh" <<SH
#!/usr/bin/env bash
cat "$FIX/pr-reviews-codex-none.json"
SH
chmod +x "$GSHIM2/gh"
g=$(run_capped 3 env PATH="$GSHIM2:$PATH" OWNER=o REPO=r PR_NUM=42 PROCESSED='[555]' INTERVAL=1 \
      bash "$SCRIPTS/poll-codex-grace.sh" 2>/dev/null) || true
is "no unprocessed review -> no terminal line" "$g" ""
rm -rf "$GSHIM2"

echo
echo "poll-cr-status.sh"

# A persistent fetch error (state:"error" from cr-commit-state.sh) must become
# a terminal line after ERROR_STREAK_MAX consecutive rounds instead of spinning
# silently to the outer TIMEOUT; a single transient error keeps polling. (Codex P1)
# `timeout` is GNU-only (absent on stock macOS/BSD, where this suite runs via
# the pre-commit hook) — use it as a hang guard only where it exists; the case
# itself terminates deterministically (INTERVAL=0, ERROR_STREAK_MAX=2).
TMO=""; command -v timeout >/dev/null 2>&1 && TMO="timeout 10"
pout=$(OWNER=o REPO=r SHA=s PR_NUM=42 INTERVAL=0 PUSH_TIME=x \
  CR_STATE_STATUSES_FILE=__FAIL__ ERROR_STREAK_MAX=2 \
  $TMO bash "$SCRIPTS/poll-cr-status.sh" 2>/dev/null) || true
is "persistent error -> terminal state error" "$(jq -r '.state' <<<"$pout" 2>/dev/null)" error

# W1-2: a rate-limit *comment* lingering on a PR whose commit-status has already
# flipped to terminal success must NOT route the poll to rate_limited. The sniff
# fires on the empty first fetch (s=""), but the re-fetch sees success and wins.
# Counter shim: /statuses empty on fetch #1 (→ sniff path), success on #2+
# (→ re-fetch). RED against the pre-re-fetch poll by construction (it emitted
# rate_limited straight from the sniff hit without re-confirming the status).
TMO3=""; command -v timeout >/dev/null 2>&1 && TMO3="timeout 10"
PSHIM=$(mktemp -d); PCNT="$PSHIM/n"; echo 0 > "$PCNT"
cat > "$PSHIM/gh" <<SH
#!/usr/bin/env bash
case "\$*" in
  *"/statuses"*)
    n=\$(cat "$PCNT"); echo \$((n+1)) > "$PCNT"
    if [ "\$n" -eq 0 ]; then echo '[]'
    else echo '[{"context":"CodeRabbit","state":"success","description":"Review completed","target_url":"https://cr/x","created_at":"2026-07-15T00:00:00Z"}]'; fi ;;
  *"/check-runs"*) echo '{"check_runs":[]}' ;;
  *"/issues/"*"/comments"*) echo '[{"user":{"login":"coderabbitai[bot]"},"created_at":"2026-07-15T00:00:00Z","updated_at":"2026-07-15T00:00:00Z","body":"Review limit reached"}]' ;;
  *"/pulls/"*"/reviews"*) echo '[]' ;;
  *"/pulls/"*) echo '{"head":{"sha":"deadbeef"}}' ;;
  *) echo "unknown gh args: \$*" >&2; exit 1 ;;
esac
SH
chmod +x "$PSHIM/gh"
pflip=$(PATH="$PSHIM:$PATH" OWNER=o REPO=r SHA=s PR_NUM=42 INTERVAL=0 \
  EARLY_CHECK_WINDOW=0 PUSH_TIME=2020-01-01T00:00:00Z \
  $TMO3 bash "$SCRIPTS/poll-cr-status.sh" 2>/dev/null) || true
is "stale RL comment + status flips success -> poll emits success" \
   "$(jq -r '.state' <<<"$pflip" 2>/dev/null)" success
rm -rf "$PSHIM"

# W1-2 follow-up (Codex P2): the re-fetch must NOT treat a *free-tier* success
# (the transient "Review skipped: free tier disabled" placeholder) as terminal —
# that skips the CR_SKIP_GRACE hold the top-of-loop branch applies. Counter shim:
# /statuses empty on fetch #1 (→ sniff path), free-tier success on #2+. With
# CR_SKIP_GRACE=0 the next loop's grace branch routes to rate_limited; the
# pre-guard re-fetch emitted `success` outright. RED against that by construction.
TMO4=""; command -v timeout >/dev/null 2>&1 && TMO4="timeout 10"
FTSHIM=$(mktemp -d); FTCNT="$FTSHIM/n"; echo 0 > "$FTCNT"
cat > "$FTSHIM/gh" <<SH
#!/usr/bin/env bash
case "\$*" in
  *"/statuses"*)
    n=\$(cat "$FTCNT"); echo \$((n+1)) > "$FTCNT"
    if [ "\$n" -eq 0 ]; then echo '[]'
    else echo '[{"context":"CodeRabbit","state":"success","description":"Review skipped: free tier disabled","target_url":"https://cr/x","created_at":"2026-07-15T00:00:00Z"}]'; fi ;;
  *"/check-runs"*) echo '{"check_runs":[]}' ;;
  *"/issues/"*"/comments"*) echo '[]' ;;
  *"/pulls/"*"/reviews"*) echo '[]' ;;
  *"/pulls/"*) echo '{"head":{"sha":"deadbeef"}}' ;;
  *) echo "unknown gh args: \$*" >&2; exit 1 ;;
esac
SH
chmod +x "$FTSHIM/gh"
ftier=$(PATH="$FTSHIM:$PATH" OWNER=o REPO=r SHA=s PR_NUM=42 INTERVAL=0 \
  EARLY_CHECK_WINDOW=0 CR_SKIP_GRACE=0 PUSH_TIME=2020-01-01T00:00:00Z \
  $TMO4 bash "$SCRIPTS/poll-cr-status.sh" 2>/dev/null) || true
is "re-fetch free-tier success -> held for grace, not terminal success" \
   "$(jq -r '.state' <<<"$ftier" 2>/dev/null)" rate_limited
rm -rf "$FTSHIM"

echo
echo "pre-flight.sh"

# W1-2: a comment-channel rate-limit sniff must NOT override an authoritative
# terminal CR success. The commit-status/check-run is the authority; a lingering
# rate-limit *comment* (stale from an earlier push, or CR's in-place edit) is only
# a hint. With cr_state=success + channel=comment, the gate must be proceed, not
# rate_limited. RED against the unconditional override by construction.
FSHIM=$(mktemp -d); FST="$FSHIM/state.json"; echo '{}' > "$FST"
cat > "$FSHIM/gh" <<SH
#!/usr/bin/env bash
case "\$*" in
  *"/statuses"*) echo '[{"context":"CodeRabbit","state":"success","description":"Review completed","target_url":"https://cr/x","created_at":"2026-07-15T00:00:00Z"}]' ;;
  *"/check-runs"*) echo '{"check_runs":[]}' ;;
  *"/issues/"*"/comments"*) echo '[{"user":{"login":"coderabbitai[bot]"},"created_at":"2026-07-15T00:00:00Z","updated_at":"2026-07-15T00:00:00Z","body":"Review limit reached"}]' ;;
  *"/pulls/"*"/reviews"*) echo '[]' ;;
  *"/pulls/"*) echo '{"head":{"sha":"deadbeef"}}' ;;
  *) echo "unknown gh args: \$*" >&2; exit 1 ;;
esac
SH
chmod +x "$FSHIM/gh"
pf=$(PATH="$FSHIM:$PATH" NO_CODEX=true OWNER=o REPO=r PR_NUM=42 CUR_SHA=s \
  PUSH_TIME=2020-01-01T00:00:00Z STATE_FILE="$FST" \
  bash "$SCRIPTS/pre-flight.sh" 2>/dev/null)
is "comment RL over terminal success -> gate proceed" \
   "$(jq -r '.gate' <<<"$pf" 2>/dev/null)" proceed
is "comment RL over terminal success -> source still comment" \
   "$(jq -r '.rate_limit_source' <<<"$pf" 2>/dev/null)" comment

# Control: a description-channel rate-limit (commit-status derived, authoritative)
# on a success row DOES still route to rate_limited — the fix suppresses only the
# comment channel. GREEN on both old and new implementations by construction.
cat > "$FSHIM/gh" <<SH
#!/usr/bin/env bash
case "\$*" in
  *"/statuses"*) echo '[{"context":"CodeRabbit","state":"success","description":"Review limit reached","target_url":"","created_at":"2026-07-15T00:00:00Z"}]' ;;
  *"/check-runs"*) echo '{"check_runs":[]}' ;;
  *"/issues/"*"/comments"*) echo '[]' ;;
  *"/pulls/"*"/reviews"*) echo '[]' ;;
  *"/pulls/"*) echo '{"head":{"sha":"deadbeef"}}' ;;
  *) echo "unknown gh args: \$*" >&2; exit 1 ;;
esac
SH
pfd=$(PATH="$FSHIM:$PATH" NO_CODEX=true OWNER=o REPO=r PR_NUM=42 CUR_SHA=s \
  PUSH_TIME=2020-01-01T00:00:00Z STATE_FILE="$FST" \
  bash "$SCRIPTS/pre-flight.sh" 2>/dev/null)
is "description RL on success -> gate rate_limited (authority retained)" \
   "$(jq -r '.gate' <<<"$pfd" 2>/dev/null)" rate_limited
rm -rf "$FSHIM"

echo
echo "SKILL.md snippet contracts (mirror SKILL.md prose blocks)"

# Step 2 archive fallback: the EXIT trap archives the live state, so the next run
# must read codex_processed_reviews from the newest archive or re-process Codex
# reviews. Mirrors the SKILL.md Step 2 resolution. (issue #110 step 3)
AF=$(mktemp -d); mkdir -p "$AF/.claude/state/archive"
echo '{"codex_processed_reviews":[111,222]}' > "$AF/.claude/state/archive/cr-fix-42-20260101-000000.json"
echo '{"codex_processed_reviews":[333]}'     > "$AF/.claude/state/archive/cr-fix-42-20260102-000000.json"
# touch -t (POSIX) — `-d` is GNU-only and breaks the suite on macOS/BSD.
touch -t 202601010000 "$AF/.claude/state/archive/cr-fix-42-20260101-000000.json"
touch -t 202601020000 "$AF/.claude/state/archive/cr-fix-42-20260102-000000.json"
af_got=$(cd "$AF" && PR_NUM=42
  PRIOR_STATE=".claude/state/cr-fix-${PR_NUM}.json"
  [ -f "$PRIOR_STATE" ] || PRIOR_STATE=$(ls -1t ".claude/state/archive/cr-fix-${PR_NUM}-"*.json 2>/dev/null | head -1)
  PRIOR_PROCESSED='[]'
  [ -n "$PRIOR_STATE" ] && [ -f "$PRIOR_STATE" ] && PRIOR_PROCESSED=$(jq -c '.codex_processed_reviews // []' "$PRIOR_STATE")
  printf '%s' "$PRIOR_PROCESSED")
is "archive fallback reads newest archive" "$af_got" "[333]"
rm -rf "$AF"

# First run ever: no archive exists at all. The unguarded ls fallback died
# rc=2 under set -euo pipefail (RED reproduced manually); the || true guard
# must let an errexit caller survive. (counsel P1)
AF2=$(mktemp -d); mkdir -p "$AF2/.claude/state/archive"
arc=0; (cd "$AF2" && bash -euo pipefail -c '
  PR_NUM=43
  PRIOR_STATE=".claude/state/cr-fix-${PR_NUM}.json"
  [ -f "$PRIOR_STATE" ] || PRIOR_STATE=$(ls -1t ".claude/state/archive/cr-fix-${PR_NUM}-"*.json 2>/dev/null | head -1 || true)
') || arc=$?
is "archive fallback: no archive survives errexit" "$arc" 0
rm -rf "$AF2"

# Corrupt prior state must ABORT before the new state file is created — a
# warn-and-continue reset re-judges already-processed Codex reviews and can
# re-apply fixes onto already-fixed code. Mirrors the SKILL.md Step 2 branch.
AF3=$(mktemp -d); mkdir -p "$AF3/.claude/state/archive"
echo 'not-json{' > "$AF3/.claude/state/cr-fix-44.json"
crc=0; (cd "$AF3" && bash -c '
  PR_NUM=44
  PRIOR_STATE=".claude/state/cr-fix-${PR_NUM}.json"
  [ -f "$PRIOR_STATE" ] || PRIOR_STATE=$(ls -1t ".claude/state/archive/cr-fix-${PR_NUM}-"*.json 2>/dev/null | head -1 || true)
  if [ -n "$PRIOR_STATE" ] && [ -f "$PRIOR_STATE" ]; then
    PRIOR_PROCESSED=$(jq -c ".codex_processed_reviews // []" "$PRIOR_STATE" 2>/dev/null) || {
      echo "cr-fix: prior state $PRIOR_STATE unparseable — aborting before the Codex dedupe is reset" >&2
      exit 1
    }
  fi' 2>/dev/null) || crc=$?
is "corrupt prior state -> aborts rc 1" "$crc" 1
rm -rf "$AF3"

# Step 1 SKILL_DIR resolver: CLAUDE_PLUGIN_ROOT wins, and the Codex cache is the
# fallback outside the source tree. Mirrors the SKILL.md Step 1 resolver. (step 7)
RS=$(mktemp -d)
mkdir -p "$RS/pluginroot/skills/cr-fix" "$RS/cache/marketplace/github-dev/2.8.0/skills/cr-fix"
cat > "$RS/resolver.sh" <<'SH'
CACHE_ROOT="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
if sort -V </dev/null >/dev/null 2>&1; then
  CODEX_CAND=$(ls -1d "$CACHE_ROOT"/*/github-dev/* 2>/dev/null \
    | awk -F/ '{print $NF "\t" $0}' | sort -V | tail -1 | cut -f2- || true)
else
  CODEX_CAND=$(ls -1d "$CACHE_ROOT"/*/github-dev/* 2>/dev/null \
    | awk -F/ '{print $NF "\t" $0}' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1 | cut -f2- || true)
fi
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "$CLAUDE_PLUGIN_ROOT/skills/cr-fix" ]; then SKILL_DIR="$CLAUDE_PLUGIN_ROOT/skills/cr-fix"
elif [ -d "plugins/github-dev/skills/cr-fix" ]; then SKILL_DIR="plugins/github-dev/skills/cr-fix"
elif [ -n "$CODEX_CAND" ] && [ -d "$CODEX_CAND/skills/cr-fix" ]; then SKILL_DIR="$CODEX_CAND/skills/cr-fix"
elif [ -n "${HERMES_HOME:-}" ] && [ -d "$HERMES_HOME/plugins/github-dev/skills/cr-fix" ]; then SKILL_DIR="$HERMES_HOME/plugins/github-dev/skills/cr-fix"
elif [ -n "${HERMES_HOME:-}" ] && [ -d "$HERMES_HOME/skills/cr-fix" ]; then SKILL_DIR="$HERMES_HOME/skills/cr-fix"
else SKILL_DIR="$HOME/.hermes/plugins/github-dev/skills/cr-fix"; fi
printf '%s' "$SKILL_DIR"
SH
# From a non-source-tree cwd so the source-tree branch cannot win.
got=$(cd "$RS" && CLAUDE_PLUGIN_ROOT="$RS/pluginroot" CODEX_PLUGIN_CACHE="$RS/cache" HERMES_HOME="" bash resolver.sh)
is "resolver: CLAUDE_PLUGIN_ROOT wins" "$got" "$RS/pluginroot/skills/cr-fix"
got=$(cd "$RS" && CLAUDE_PLUGIN_ROOT="" CODEX_PLUGIN_CACHE="$RS/cache" HERMES_HOME="" bash resolver.sh)
is "resolver: Codex cache fallback"    "$got" "$RS/cache/marketplace/github-dev/2.8.0/skills/cr-fix"

# Multi-marketplace cache: the VERSION must win, not the marketplace dir name.
# The old full-path sort -V let zeta/github-dev/2.10.0 outrank
# alpha/github-dev/3.0.0. (CR Major, SKILL.md:66)
mkdir -p "$RS/cache2/zeta/github-dev/2.10.0/skills/cr-fix" \
         "$RS/cache2/alpha/github-dev/3.0.0/skills/cr-fix"
got=$(cd "$RS" && CLAUDE_PLUGIN_ROOT="" CODEX_PLUGIN_CACHE="$RS/cache2" HERMES_HOME="" bash resolver.sh)
is "resolver: version outranks marketplace name" "$got" "$RS/cache2/alpha/github-dev/3.0.0/skills/cr-fix"

# Fresh env (no cache at all) must not kill an errexit caller — the unguarded
# CODEX_CAND ls substitution died rc=2 under set -euo pipefail. (counsel P1)
rrc=0; (cd "$RS" && CLAUDE_PLUGIN_ROOT="" CODEX_PLUGIN_CACHE="$RS/no-such-cache" HERMES_HOME="" \
  bash -euo pipefail resolver.sh >/dev/null) || rrc=$?
is "resolver: empty cache survives errexit" "$rrc" 0

# BSD/no-sort-V fallback: the numeric dotted-field sort must rank 2.10.0 above
# 2.9.0 (plain lexicographic sort picked 2.9.0). Asserts the exact fallback
# pipeline from the SKILL.md Step 1 resolver. (codex counsel P2)
fb=$(printf '2.9.0\t/a\n2.10.0\t/b\n' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1 | cut -f2-)
is "fallback sort: 2.10.0 outranks 2.9.0" "$fb" "/b"
rm -rf "$RS"

# Step 6b grace-cap selection: the bypass path (CR_SOURCE cli/codex-only) skips
# Step 5 pre-flight, so $pf is UNSET. Reading `<<<"$pf"` unconditionally aborts
# it under set -u; pf_remaining matters only for gate=codex_wait, so $pf is read
# only under that gate. RED against the bare read by construction. (Codex P2 iter 8)
gc_rc=0; gcap=$(bash -euo pipefail -c '
  gate=bypass; CODEX_GRACE=30
  if [ "$gate" = "codex_wait" ]; then
    pf_timeout=${CODEX_PREFLIGHT_TIMEOUT:-600}
    push_age=$(jq -r ".push_age_seconds // 0" <<<"$pf")
    pf_remaining=$(( pf_timeout - push_age )); [ "$pf_remaining" -lt 0 ] && pf_remaining=0
    [ "$pf_remaining" -gt "$CODEX_GRACE" ] && grace_cap="$pf_remaining" || grace_cap="$CODEX_GRACE"
  else
    grace_cap="$CODEX_GRACE"
  fi
  printf "%s" "$grace_cap"') || gc_rc=$?
is "grace-cap bypass: unset pf survives errexit" "$gc_rc" 0
is "grace-cap bypass: falls back to CODEX_GRACE" "$gcap" 30
# codex_wait path still consults pre-flight remaining when it is the larger budget;
# $pf is guaranteed set there (Step 5 populated it), read bare — no fragile default.
gcap2=$(bash -euo pipefail -c '
  gate=codex_wait; CODEX_GRACE=30; pf="{\"push_age_seconds\":100}"
  if [ "$gate" = "codex_wait" ]; then
    pf_timeout=${CODEX_PREFLIGHT_TIMEOUT:-600}
    push_age=$(jq -r ".push_age_seconds // 0" <<<"$pf")
    pf_remaining=$(( pf_timeout - push_age )); [ "$pf_remaining" -lt 0 ] && pf_remaining=0
    [ "$pf_remaining" -gt "$CODEX_GRACE" ] && grace_cap="$pf_remaining" || grace_cap="$CODEX_GRACE"
  else
    grace_cap="$CODEX_GRACE"
  fi
  printf "%s" "$grace_cap"')
is "grace-cap codex_wait: pre-flight remaining wins" "$gcap2" 500

echo
echo "path-trust.sh"

# The Step 9c gate runs this per finding. It used GNU-only `realpath -m`, so on
# BSD/macOS it aborted under `set -e` for EVERY path — including valid ones —
# and the gate's `|| { skip; continue; }` branch turned that into "every finding
# is untrusted", converging the loop to a false `final_state=clean` (issue #152).
PT="$SCRIPTS/path-trust.sh"
PT_ROOT=$(mktemp -d); PT_OUT=$(mktemp -d)
trap 'rm -rf "$PT_ROOT" "$PT_OUT"' EXIT
mkdir -p "$PT_ROOT/sub/nested"
: > "$PT_ROOT/README.md"; : > "$PT_ROOT/sub/nested/deep.txt"; : > "$PT_OUT/secret.txt"

# `env -i PATH=/usr/bin:/bin` on purpose: a GNU-rich runner (or Claude Code's
# grep->ugrep shell function) otherwise masks exactly the BSD portability breaks
# these cases exist to catch.
pt() {
  env -i PATH=/usr/bin:/bin bash "$PT" "$PT_ROOT" "$1" >/dev/null 2>&1
  printf '%s' "$?"
}

is "in-repo file at root"            "$(pt 'README.md')"            0
is "in-repo nested file"             "$(pt 'sub/nested/deep.txt')"  0
# The whole reason `-m` was there: a fix may create a file that does not exist yet.
is "not-yet-created file in repo"    "$(pt 'sub/brand-new.md')"     0
is "not-yet-created nested dir file" "$(pt 'sub/nested/new.txt')"   0
# Containment must still hold.
is "parent escape rejected"          "$(pt '../escape.md')"         1
is "mid-path .. rejected"            "$(pt 'sub/../../escape.md')"  1
is "absolute path rejected"          "$(pt '/etc/passwd')"          1
is "home-relative rejected"          "$(pt '~/secrets')"            1
# Symlinks must not smuggle a write past the gate. Two distinct shapes: a symlinked
# DIRECTORY component (caught by parent resolution) and a symlinked FINAL component
# (needs the link chain followed — resolving only the parent leaves `abs` looking
# in-repo while the write lands outside). An explicit if/else, not `&& ... || ok`,
# so a real regression fails the suite instead of being reported as skipped.
if ln -s "$PT_OUT" "$PT_ROOT/link-dir" 2>/dev/null \
   && ln -s "$PT_OUT/secret.txt" "$PT_ROOT/link-file.md" 2>/dev/null \
   && ln -s "sub/nested/deep.txt" "$PT_ROOT/link-inside.md" 2>/dev/null; then
  is "symlinked dir component escaping repo rejected"   "$(pt 'link-dir/x.md')"    1
  is "symlinked final component escaping repo rejected" "$(pt 'link-file.md')"     1
  is "symlink staying inside repo allowed"              "$(pt 'link-inside.md')"   0
else
  ok "symlink escape cases (skipped: ln -s unavailable)"
fi
# Nonexistent intermediate dir has no resolvable parent — reject, do not crash.
is "unresolvable parent rejected"    "$(pt 'no/such/dir/f.md')"     1

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
