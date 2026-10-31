#!/usr/bin/env bash
# Usage: bash plugins/dev/skills/review-loop/tests/run-tests.sh
#
# Fixture-driven checks for the two review-loop paths that only execute when the
# primary path has already failed, and which therefore had nothing exercising
# them (issue #105): the CodeRabbit CLI JSONL parser, and the commit-state
# reader that decides whether a review has finished.
#
# No network, no `gh`, no live PR. cr-commit-state.sh reads its two HTTP
# responses from CR_STATE_STATUSES_FILE / CR_STATE_CHECKRUNS_FILE when set.
set -uo pipefail

# The churn-scope cases `git init` throwaway repos. Inherited from a pre-commit hook
# (absolute paths in a linked worktree), these variables sent the fixtures' writes
# into the calling repo: its index was replaced and its .git/config gained
# core.bare=true and user.name=t.
jq_lf="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../scripts/jq-lf.sh"; if [ -f "$jq_lf" ]; then . "$jq_lf"; fi  # drops CR from Windows jq output; absent in test copies
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/../scripts"
FIX="$HERE/fixtures"
pass=0; fail=0

# Passing cases print only with VERBOSE=1: the pre-commit hook and agents read this output.
ok()   { pass=$((pass+1)); [ "${VERBOSE:-0}" = 1 ] && printf '  ok   %s\n' "$1"; return 0; }
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
is "0.5.x category_emoji from comment header" \
   "$(jq -r '.[0].category_emoji' <<<"$out")" "🎯 Functional Correctness"
is "0.5.x two-field header has no effort" "$(jq -r '.[0].effort_emoji' <<<"$out")" null

# 0.7.x header carries a third `effort` field. It is what splits a Minor into
# auto vs gated, so the parser must surface it rather than stop at two fields.
out=$(bash "$SCRIPTS/parse-cr-cli-jsonl.sh" "$FIX/cr-cli-0.7.x-findings.jsonl" 2>/dev/null); rc=$?
is "0.7.x exits 0"                  "$rc" 0
is "0.7.x category from 3-field header" \
   "$(jq -r '.[0].category_emoji' <<<"$out")" "🎯 Functional Correctness"
is "0.7.x effort from 3-field header"  "$(jq -r '.[0].effort_emoji' <<<"$out")" "🏗️ Heavy lift"
is "0.7.x quick-win effort parsed"     "$(jq -r '.[1].effort_emoji' <<<"$out")" "⚡ Quick win"

# A genuinely unparseable line must degrade, not abort.
out=$(bash "$SCRIPTS/parse-cr-cli-jsonl.sh" "$FIX/cr-cli-malformed.jsonl" 2>/dev/null); rc=$?
is "malformed exits 0"              "$rc" 0
is "malformed keeps valid findings" "$(jq 'length' <<<"$out")" 2

# Severity `none` is the CLI's informational level, not "unreadable": it must
# skip like Info rather than fall through to `review`. Trivial/Info carry the
# 🔵/⚪ badges CodeRabbit documents, and a bold comment header parses too.
out=$(bash "$SCRIPTS/parse-cr-cli-jsonl.sh" "$FIX/cr-cli-severity-none.jsonl" 2>/dev/null)
cli_tier() { jq -c ".[$1]" <<<"$out" | bash "$SCRIPTS/classify-item.sh" | jq -r '.tier'; }
is "CLI severity none -> skip"      "$(cli_tier 0)" skip
is "CLI trivial label is 🔵"        "$(jq -r '.[1].severity_emoji' <<<"$out")" "🔵 Trivial"
is "CLI info label is ⚪"           "$(jq -r '.[2].severity_emoji' <<<"$out")" "⚪ Info"
is "CLI bold comment header -> category" "$(jq -r '.[3].category_emoji' <<<"$out")" "🗄️ Data Integrity & Integration"
is "CLI bold comment header -> effort"   "$(jq -r '.[3].effort_emoji' <<<"$out")" "🏗️ Heavy lift"
is "CLI bold Minor+Heavy lift -> gated"  "$(cli_tier 3)" gated

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

# CodeRabbit marks a rate-limited push with a PASSING "Review rate limited" check
# by design (docs management/rate-limits), so the success row is no review at all.
# PR #283 merged on exactly this row. Both surfaces must read it as rate_limited.
s=$(state statuses-cr-review-rate-limited.json checkruns-empty.json)
is "success 'Review rate limited' status -> rate_limited" "$(jq -r '.state' <<<"$s")" rate_limited
s=$(state statuses-empty.json checkruns-cr-review-rate-limited.json)
is "success 'Review rate limited' check-run -> rate_limited" "$(jq -r '.state' <<<"$s")" rate_limited
s=$(state statuses-cr-ratelimited.json checkruns-empty.json)
is "success 'Review limit reached' -> rate_limited" "$(jq -r '.state' <<<"$s")" rate_limited

# Fetch failure must be its own state, not masked as "none" (== "no CR row").
# __FAIL__ sentinel simulates auth/network/rate-limit. (issue #110 step 4)
s=$(CR_STATE_STATUSES_FILE=__FAIL__ bash "$SCRIPTS/cr-commit-state.sh" o r sha 2>/dev/null)
is "statuses fetch failure -> error"  "$(jq -r '.state' <<<"$s")" error
is "statuses fetch failure -> channel status" "$(jq -r '.channel' <<<"$s")" status
s=$(CR_STATE_STATUSES_FILE="$FIX/statuses-empty.json" CR_STATE_CHECKRUNS_FILE=__FAIL__ \
      bash "$SCRIPTS/cr-commit-state.sh" o r sha 2>/dev/null)
is "checkruns fetch failure -> error" "$(jq -r '.state' <<<"$s")" error
is "checkruns fetch failure -> channel check_run" "$(jq -r '.channel' <<<"$s")" check_run
# A page that arrives but does not parse is no answer either: falling back to {}
# read as "no CR row" and ended at state:none (issue #297).
s=$(state not-json.txt checkruns-empty.json)
is "unparseable statuses page -> error, not none" "$(jq -r '[.state, .channel] | join("/")' <<<"$s")" error/status
s=$(state statuses-empty.json not-json.txt)
is "unparseable check-runs page -> error, not none" "$(jq -r '[.state, .channel] | join("/")' <<<"$s")" error/check_run

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
echo "ci-checks.sh"

# HEAD's CI conclusions (issue #317). The gh stub answers `gh pr checks` from a
# sequence file, one line per call: a fixture path, FAIL (lookup error) or NONE.
CIS=$(mktemp -d)
cat > "$CIS/gh" <<'SH'
#!/usr/bin/env bash
[ "$1 $2" = "pr checks" ] || { echo "unknown gh args: $*" >&2; exit 1; }
echo "$*" > "$CI_COUNT.args"
n=$(cat "$CI_COUNT" 2>/dev/null || echo 0); echo $((n+1)) > "$CI_COUNT"
f=$(sed -n "$((n+1))p" "$CI_SEQ" | tr -d '\r'); [ -n "$f" ] || f=$(tail -1 "$CI_SEQ" | tr -d '\r')
case "$f" in
  FAIL) echo "HTTP 502" >&2; exit 1 ;;
  NONE) echo "no checks reported on the 'feat' branch" >&2; exit 1 ;;
  RC*:*) cat "${f#*:}"; r=${f%%:*}; exit "${r#RC}" ;;
  *) cat "$f" ;;
esac
SH
chmod +x "$CIS/gh"
ci() { # CAP SEQ... -> the script's JSON line
  local cap=$1; shift
  printf '%s\n' "$@" > "$CIS/seq"; rm -f "$CIS/count"
  CI_SEQ="$CIS/seq" CI_COUNT="$CIS/count" PATH="$CIS:$PATH" CAP="$cap" INTERVAL=0 \
    bash "$SCRIPTS/ci-checks.sh" 42 2>/dev/null
}
c=$(ci 0 "$FIX/pr-checks-failing.json")
is "failing check on HEAD -> fail"                "$(jq -r '.state' <<<"$c")" fail
# The reviewer's own check is left out under both names it reports (plain status
# and `CodeRabbit / Review` check run); a CI job that only starts with it still counts.
is "failing names exclude CodeRabbit, keep a lookalike" "$(jq -c '.failing' <<<"$c")" '["policy","coderabbit-lint","deploy"]'
# Classification reads gh's normalized bucket, never a copied list of raw states.
is "checks are read with the bucket field"        "$(grep -c 'bucket' "$CIS/count.args")" 1
c=$(ci 0 "$FIX/pr-checks-passing.json")
is "passing checks (CodeRabbit pending ignored) -> pass" "$(jq -r '.state' <<<"$c")" pass
is "passing checks -> no failing names"           "$(jq -c '.failing' <<<"$c")" '[]'
c=$(ci 0 "$FIX/pr-checks-pending.json")
is "pending check, no wait (CAP=0) -> pending"    "$(jq -r '.state' <<<"$c")" pending
# A bucket gh adds later is not a pass (STALE, new states).
is "pending names listed, an unknown bucket among them" "$(jq -c '.pending' <<<"$c")" '["build","stale-job"]'
# The poll sleeps no longer than what is left of the caller's cap.
printf '%s\n' "$FIX/pr-checks-pending.json" > "$CIS/seq"; rm -f "$CIS/count"; t0=$SECONDS
c=$(CI_SEQ="$CIS/seq" CI_COUNT="$CIS/count" PATH="$CIS:$PATH" CAP=1 INTERVAL=30 \
    bash "$SCRIPTS/ci-checks.sh" 42 2>/dev/null)
is "pending past the cap -> pending"              "$(jq -r '.state' <<<"$c")" pending
is "sleep never outlasts the cap"                 "$([ $((SECONDS - t0)) -le 3 ] && echo yes || echo no)" yes
c=$(ci 30 "$FIX/pr-checks-pending.json" "$FIX/pr-checks-passing.json")
is "pending then pass within the cap -> pass"     "$(jq -r '.state' <<<"$c")" pass
is "pending then pass -> looked twice"            "$(tr -d '\r' < "$CIS/count")" 2
# Valid JSON on stdout is the answer whatever the exit status (1 failed, 8 pending).
is "JSON with exit 1 -> still read as fail"       "$(jq -r '.state' <<<"$(ci 0 "RC1:$FIX/pr-checks-failing.json")")" fail
is "JSON with exit 8 -> still read as pending"    "$(jq -r '.state' <<<"$(ci 0 "RC8:$FIX/pr-checks-pending.json")")" pending
is "lookup failure -> error, not fail"            "$(jq -r '.state' <<<"$(ci 0 FAIL)")" error
is "no checks at all -> none"                     "$(jq -r '.state' <<<"$(ci 0 NONE)")" none
rm -rf "$CIS"

echo
echo "auto-merge-gate.sh"

# Unprotected base returns 404: the old pipe emitted "404\n404", which --argjson
# rejected and killed the whole gate. It must yield a single clean 404. (step 2)
SHIMDIR=$(mktemp -d)
cat > "$SHIMDIR/gh" <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  "api --paginate"*) echo '[]';;
  "pr checks") echo '[]';;
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
  "pr checks") echo '[]';;
  "pr view") echo "main";;
  "api repos"*) exit 1;;
  *) echo "unknown gh args: $*" >&2; exit 1;;
esac
SH
g=$(PATH="$SHIMDIR:$PATH" bash "$SCRIPTS/auto-merge-gate.sh" o r 42 deadbeef 2>/dev/null)
is "probe failure -> protection_http 0" "$(jq -r '.protection_http' <<<"$g" 2>/dev/null)" 0

# `gh pr checks` itself failing (network/auth/API, exit 1 even with --json) must not
# kill the gate under `set -e` before the guard runs: the gate still prints its
# JSON and counts the unmeasured checks as blocking. (codex P1, PR #300)
cat > "$SHIMDIR/gh" <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  "api --paginate"*) echo '[]';;
  "pr checks") echo "HTTP 502" >&2; exit 1;;
  "pr view") echo "main";;
  "api repos"*) echo "HTTP/2.0 404 Not Found"; exit 1;;
  *) echo "unknown gh args: $*" >&2; exit 1;;
esac
SH
g=$(PATH="$SHIMDIR:$PATH" bash "$SCRIPTS/auto-merge-gate.sh" o r 42 deadbeef 2>/dev/null)
is "gh pr checks failure -> gate still emits JSON" "$(jq -e . <<<"$g" >/dev/null 2>&1 && echo yes || echo no)" yes
is "gh pr checks failure -> blocking_checks 1" "$(jq -r '.blocking_checks' <<<"$g" 2>/dev/null)" 1
is "gh pr checks failure -> ci_state error"   "$(jq -r '.ci_state' <<<"$g" 2>/dev/null)" error

# Check-run-only CR repo: CR posts 0 commit statuses and 1 check-run. The old
# status-only cr_state read saw nothing -> "unknown" -> Step 15 never merged on
# --auto-merge. Now it delegates to cr-commit-state.sh (dual-surface), so a
# completed/success check-run yields cr_state:"success". RED against the
# status-only implementation by construction. (self-found, PR #122)
cat > "$SHIMDIR/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"/check-runs"*) echo '{"check_runs":[{"name":"CodeRabbit","status":"completed","conclusion":"success","started_at":"2025-01-01T00:00:00Z"}]}';;
  *"/statuses"*)   if [ -n "${AMG_STATUSES:-}" ]; then cat "$AMG_STATUSES"; else echo '[]'; fi;;
  *"/reactions"*)  if [ -n "${AMG_REACTIONS:-}" ]; then cat "$AMG_REACTIONS"; else echo '[]'; fi;;
  *"/pulls/"*"/reviews"*)   cat "$AMG_REVIEWS";;
  *"/issues/"*"/comments"*) cat "$AMG_COMMENTS";;
  "pr checks"*)    if [ -n "${AMG_CHECKS:-}" ]; then cat "$AMG_CHECKS"; else echo '[]'; fi;;
  "pr view"*)      echo "main";;
  *"/protection"*) if [ -n "${AMG_PROTECTED:-}" ]; then echo "HTTP/2.0 200 OK"; else echo "HTTP/2.0 404 Not Found"; exit 1; fi;;
  *"/branches/main --jq .protected") if [ -n "${AMG_PROTECTED:-}${AMG_RULESET:-}" ]; then echo true; else echo false; fi;;
  *) echo "unknown gh args: $*" >&2; exit 1;;
esac
SH
# HEAD deadbeef carries both verdicts unless a case swaps a listing out.
jq '[.[0] | .commit_id = "deadbeef" | .body = "**Actionable comments posted: 0**"]' \
  "$FIX/pr-reviews-cr-older-commit.json" > "$SHIMDIR/reviews.json"
sed 's/95ab2f6/deadbee/' "$FIX/issue-comments-codex-summary-completed.json" > "$SHIMDIR/comments.json"
export AMG_REVIEWS="$SHIMDIR/reviews.json" AMG_COMMENTS="$SHIMDIR/comments.json"
chmod +x "$SHIMDIR/gh"
g=$(PATH="$SHIMDIR:$PATH" bash "$SCRIPTS/auto-merge-gate.sh" o r 42 deadbeef 2>/dev/null)
is "check-run-only CR -> cr_state success" "$(jq -r '.cr_state' <<<"$g" 2>/dev/null)" success

# Convergence axis. `clean` merges on its own; `minor_floor`/`churn` stopped with
# real findings still open, so they merge only once the follow-up issue recorded
# them. A failed `gh issue create` therefore keeps the PR open by construction,
# rather than merging a PR whose deferred findings exist nowhere a person looks.
elig() { FINAL_STATE="$1" FOLLOWUP_ISSUE="${2:-}" PATH="$SHIMDIR:$PATH"            bash "$SCRIPTS/auto-merge-gate.sh" o r 42 deadbeef 2>/dev/null | jq -r '.eligible'; }
is "clean -> eligible"                       "$(DEFERRED_TOTAL=0 elig clean)" true
# An unknown count of left-behind findings is read as some: the issue is required.
is "clean, nothing said about defers -> needs the issue" "$(elig clean)" false
is "minor_floor without issue -> ineligible" "$(elig minor_floor)" false
is "minor_floor with issue -> eligible"      "$(elig minor_floor 321)" true
is "churn without issue -> ineligible"       "$(elig churn)" false
is "churn with issue -> eligible"            "$(elig churn 321)" true
is "churn with null issue -> ineligible"     "$(elig churn null)" false
is "churn with issue 0 -> ineligible"        "$(elig churn 0)" false
is "minor_floor, nothing deferred -> eligible" "$(DEFERRED_TOTAL=0 elig minor_floor)" true
is "churn, deferred but no issue -> ineligible" "$(DEFERRED_TOTAL=2 elig churn)" false
is "churn, append failed -> ineligible"       "$(FOLLOWUP_APPEND_FAILED=true elig churn 321)" false
is "iteration_cap with issue -> still ineligible" "$(elig iteration_cap 321)" false
is "user_declined -> ineligible"             "$(elig user_declined)" false
# No reviewer looked at the PR: stopping is not convergence.
is "reviewers_unavailable -> ineligible"     "$(elig reviewers_unavailable)" false
# CI failing on HEAD is not convergence (issue #317), with or without an issue.
is "ci_failing with issue -> ineligible"     "$(elig ci_failing 321)" false
is "ci_failing reason names CI" \
   "$(FINAL_STATE=ci_failing PATH="$SHIMDIR:$PATH" bash "$SCRIPTS/auto-merge-gate.sh" o r 42 deadbeef 2>/dev/null | jq -r '.ineligible_reason | test("CI")')" true
g=$(AMG_CHECKS="$FIX/pr-checks-failing.json" FINAL_STATE=clean PATH="$SHIMDIR:$PATH" bash "$SCRIPTS/auto-merge-gate.sh" o r 42 deadbeef 2>/dev/null)
is "gate: failing checks counted without CodeRabbit" "$(jq -r '.blocking_checks' <<<"$g")" 3
is "gate: failing check names carried"        "$(jq -c '.failing_checks' <<<"$g")" '["policy","coderabbit-lint","deploy"]'
is "gate: pending check is not blocking" \
   "$(AMG_CHECKS="$FIX/pr-checks-pending.json" FINAL_STATE=clean PATH="$SHIMDIR:$PATH" bash "$SCRIPTS/auto-merge-gate.sh" o r 42 deadbeef 2>/dev/null | jq -r '.blocking_checks')" 0
is "unset FINAL_STATE -> ineligible"         "$(PATH="$SHIMDIR:$PATH" bash "$SCRIPTS/auto-merge-gate.sh" o r 42 deadbeef 2>/dev/null | jq -r '.eligible')" false
is "ineligible carries a reason"    "$(FINAL_STATE=churn PATH="$SHIMDIR:$PATH" bash "$SCRIPTS/auto-merge-gate.sh" o r 42 deadbeef 2>/dev/null       | jq -r '.ineligible_reason | length > 0')" true
# A defer from an earlier cycle is still unrecorded when a later one ends clean.
is "clean, earlier defers, no issue -> ineligible" "$(DEFERRED_TOTAL=2 elig clean)" false
is "clean, earlier defers, issue filed -> eligible" "$(DEFERRED_TOTAL=2 elig clean 321)" true
# Every reviewer that is on must have given HEAD a verdict (ADR 0002).
jq '.[0].commit_id = "0ldc0mm1t"' "$SHIMDIR/reviews.json" > "$SHIMDIR/reviews-none.json"
jq '.[0].body = "<!-- This is an auto-generated comment: rate limited by coderabbit.ai -->\nReview rate limited"' \
  "$SHIMDIR/reviews.json" > "$SHIMDIR/reviews-rl.json"
sed 's/Completed/Running/' "$SHIMDIR/comments.json" > "$SHIMDIR/comments-running.json"
amg() { FINAL_STATE="${FINAL_STATE:-clean}" DEFERRED_TOTAL="${DEFERRED_TOTAL-0}" PATH="$SHIMDIR:$PATH" bash "$SCRIPTS/auto-merge-gate.sh" o r 42 deadbeef 2>/dev/null; }
g=$(AMG_REVIEWS="$SHIMDIR/reviews-none.json" amg)
is "no CodeRabbit verdict on HEAD -> ineligible"   "$(jq -r '.eligible' <<<"$g")" false
is "no-verdict reason names the HEAD verdict"     "$(jq -r '.ineligible_reason | test("HEAD verdict")' <<<"$g")" true
is "rate-limit notice only on HEAD -> ineligible" "$(AMG_REVIEWS="$SHIMDIR/reviews-rl.json" amg | jq -r '.eligible')" false
is "Codex still Running on HEAD -> ineligible"    "$(AMG_COMMENTS="$SHIMDIR/comments-running.json" amg | jq -r '.eligible')" false
is "Codex off for the run -> CR verdict suffices" \
   "$(AMG_COMMENTS="$SHIMDIR/comments-running.json" CODEX_ON=false amg | jq -r '.eligible')" true
# Codex's clean can be only a 👍 after the push (its summary row is for an older SHA):
# the gate reads it only when it passes the push time on (PR #334).
printf '[{"context":"ci","state":"success","created_at":"2026-01-01T00:00:00Z"}]' > "$SHIMDIR/statuses.json"
printf '[{"user":{"login":"chatgpt-codex-connector[bot]"},"content":"+1","created_at":"2026-06-01T00:00:00Z"}]' > "$SHIMDIR/reactions.json"
sed 's/95ab2f621c9add07df26af3770418786a29a62bb/deadbeef/' "$FIX/issue-comments-codex-summary-state-head.json" \
  > "$SHIMDIR/comments-state-head.json"
is "Codex 👍 after the push, state marker on HEAD -> eligible" \
   "$(AMG_COMMENTS="$SHIMDIR/comments-state-head.json" AMG_STATUSES="$SHIMDIR/statuses.json" \
      AMG_REACTIONS="$SHIMDIR/reactions.json" amg | jq -r '.eligible')" true
# The same 👍 with the marker still on the previous commit is Codex finishing that
# commit after the push, not a verdict on HEAD (#338).
is "Codex 👍 after the push, state marker on an older commit -> ineligible" \
   "$(AMG_COMMENTS="$FIX/issue-comments-codex-summary-state-stale.json" AMG_STATUSES="$SHIMDIR/statuses.json" \
      AMG_REACTIONS="$SHIMDIR/reactions.json" amg | jq -r '.eligible')" false
# Severity decides who reviews the fixes the cycle applied (ADR 0006): one from a
# Critical/Major/Security/Codex P0-P1 finding goes back to the PR for re-review; if
# all are Minor or lower, the reviewed HEAD merges and they go straight to the base.
SF="$SHIMDIR/state.json"
st() { printf '{"auto_judge_log":[%s]}' "$1" > "$SF"; }
nxt() { STATE_FILE="$SF" FIX_ITER=2 VERIFICATION_GATE="${VG:-on}" amg | jq -r '.next_action'; }
fix() { # ITER SRC CATEGORY BADGE ACTION [REASSESS]
  jq -nc --argjson i "$1" --arg s "$2" --arg c "$3" --arg b "$4" --arg a "$5" --arg r "${6:-low}" \
    '{iter:$i, src:$s, category:$c, badge_or_sev:$b, action:$a, judgment:{severity_reassess:$r}}'
}
minor=$(fix 2 cr '🎯 Functional Correctness' '🟡 Minor' apply)
st "$minor"
is "only Minor fixes -> merge_then_main_push" "$(nxt)" merge_then_main_push
st "$minor,$(fix 2 cr '🎯 Functional Correctness' '🟠 Major' apply high)"
is "a Major fix -> rereview_push" "$(nxt)" rereview_push
st "$minor,$(fix 2 cr '🔒 Security & Privacy' '🟡 Minor' apply)"
is "a Security fix, even Minor -> rereview_push" "$(nxt)" rereview_push
st "$(fix 2 cli '🩺 Stability & Availability' '🔴 Critical' apply high)"
is "a Critical CLI fix -> rereview_push" "$(nxt)" rereview_push
st "$(fix 2 codex '' P1 apply low)"
is "a Codex P1 fix, even reassessed low -> rereview_push" "$(nxt)" rereview_push
st "$(fix 2 codex '' P0 apply)"
is "a Codex P0 fix -> rereview_push" "$(nxt)" rereview_push
st "$(fix 2 codex '' P2 apply)"
is "a Codex P2 fix -> merge_then_main_push" "$(nxt)" merge_then_main_push
st "$(fix 2 cr '🎯 Functional Correctness' '🟡 Minor' apply high)"
is "a Minor reassessed high -> rereview_push" "$(nxt)" rereview_push
# Only fixes no reviewer has seen count: an earlier iteration's Major was re-reviewed,
# and a deferred Major changed no code.
st "$(fix 1 cr '🎯 Functional Correctness' '🟠 Major' apply high),$minor"
is "an earlier round's Major -> merge_then_main_push" "$(nxt)" merge_then_main_push
st "$(fix 2 cr '🎯 Functional Correctness' '🟠 Major' defer high),$minor"
is "a deferred Major -> merge_then_main_push" "$(nxt)" merge_then_main_push
st "$minor"
is "base protected (200): no direct push -> rereview_push" "$(AMG_PROTECTED=1 nxt)" rereview_push
is "base guarded by a ruleset only (404, protected) -> rereview_push" "$(AMG_RULESET=1 nxt)" rereview_push
is "build/test gate off -> rereview_push"                  "$(VG=baseline_failed nxt)" rereview_push
is "--no-minor-stop -> rereview_push"                      "$(MINOR_STOP=false nxt)" rereview_push
is "state file unreadable -> rereview_push" \
   "$(STATE_FILE="$SHIMDIR/missing.json" FIX_ITER=2 VERIFICATION_GATE=on amg | jq -r '.next_action')" rereview_push
# One follow-up issue only when something was left behind; a HEAD without every
# verdict, or failing CI, goes to the final report instead.
fi_of() { FINAL_STATE=$1 DEFERRED_TOTAL=$2 amg | jq -r '.file_issue'; }
is "minor_floor, nothing deferred -> no issue"     "$(fi_of minor_floor 0)" false
is "minor_floor, deferred -> issue"                "$(fi_of minor_floor 2)" true
is "timeout (HEAD unverified), nothing deferred -> no issue" "$(fi_of timeout 0)" false
is "iteration_cap, deferred -> issue"              "$(fi_of iteration_cap 1)" true
is "ci_failing alone -> no issue"                  "$(fi_of ci_failing 0)" false
is "ci_failing alone -> not eligible"              "$(FINAL_STATE=ci_failing DEFERRED_TOTAL=0 amg | jq -r '.eligible')" false
is "ci_failing with a defer -> issue"              "$(fi_of ci_failing 1)" true
is "failure is not a state that files one"         "$(fi_of failure 3)" false
is "unknown defer count -> issue"                  "$(FINAL_STATE=churn DEFERRED_TOTAL='' amg | jq -r '.file_issue')" true
# A reviewer the wait dropped (ADR 0006) is named in the decision output; the HEAD
# axis judges without it because the caller passes it as off.
is "dropped reviewers named in the gate output" \
   "$(DROPPED_REVIEWERS="coderabbit codex" amg | jq -c '.dropped_reviewers')" '["coderabbit","codex"]'
is "nothing dropped -> empty list"                 "$(amg | jq -c '.dropped_reviewers')" '[]'
is "Codex dropped and off -> CR verdict suffices" \
   "$(AMG_COMMENTS="$SHIMDIR/comments-running.json" CODEX_ON=false DROPPED_REVIEWERS=codex amg | jq -r '.eligible')" true
unset AMG_REVIEWS AMG_COMMENTS
rm -rf "$SHIMDIR"

echo
echo "classify-item.sh"

# Severity, not category, decides a CR tier. Reading header field 1 as an issue
# TYPE sent every Minor to `review` (surfaced, never applied) and left `auto`
# unreachable, because CodeRabbit's field 1 is the defect CATEGORY.
cls() { printf '%s' "$1" | SKIP_MINOR="${2:-false}" bash "$SCRIPTS/classify-item.sh" | jq -r '.tier'; }
cr()  { jq -nc --arg c "$1" --arg s "$2" --arg e "$3" \
          '{source:"cr",path:"p",line:1,category_emoji:$c,severity_emoji:$s,effort_emoji:$e}'; }

is "CR Major -> gated"  "$(cls "$(cr '🎯 Functional Correctness' '🟠 Major' '⚡ Quick win')")"  gated
is "CR Critical -> gated" "$(cls "$(cr '🩺 Stability & Availability' '🔴 Critical' '🏗️ Heavy lift')")" gated
is "CR Minor + Quick win -> auto" \
   "$(cls "$(cr '📐 Maintainability & Code Quality' '🟡 Minor' '⚡ Quick win')")" auto
is "CR Minor + Heavy lift -> gated" \
   "$(cls "$(cr '📐 Maintainability & Code Quality' '🟡 Minor' '🏗️ Heavy lift')")" gated
is "CR Trivial -> skip"  "$(cls "$(cr '📐 Maintainability & Code Quality' '🔵 Trivial' '⚡ Quick win')")" skip
# Security escalates on category alone: a Minor-rated privacy leak is still a leak.
is "CR Security + Minor -> gated" \
   "$(cls "$(cr '🔒 Security & Privacy' '🟡 Minor' '⚡ Quick win')")" gated
is "CR Security + Trivial -> gated" \
   "$(cls "$(cr '🔒 Security & Privacy' '🔵 Trivial' '⚡ Quick win')")" gated
# Legacy two-field header: no effort field reads as Quick win, so Minor still
# reaches `auto` rather than silently regressing to `review`.
is "CR Minor, no effort field -> auto" \
   "$(cls "$(jq -nc '{source:"cr",category_emoji:"🛠️ Refactor suggestion",severity_emoji:"🟡 Minor"}')")" auto
is "CR no header -> review" "$(cls "$(jq -nc '{source:"cr",path:"p"}')")" review
is "CR Nitpick -> skip" "$(cls "$(cr '📝 Nitpick' '🟡 Minor' '⚡ Quick win')")" skip

# Codex flags P1/P2 on GitHub and nothing else. The old P3 branch was dead; an
# unfamiliar badge must surface as `review`, never be applied unseen.
is "Codex P1 -> gated" "$(cls "$(jq -nc '{source:"codex",p_badge:"1"}')")" gated
is "Codex P2 -> gated" "$(cls "$(jq -nc '{source:"codex",p_badge:"2"}')")" gated
is "Codex unfamiliar badge -> review" "$(cls "$(jq -nc '{source:"codex",p_badge:"3"}')")" review
is "Codex no badge -> review" "$(cls "$(jq -nc '{source:"codex",p_badge:"none"}')")" review

# --skip-minor demotes Minor unless the category is Security.
is "skip-minor: CR Minor -> skip" \
   "$(cls "$(cr '🎯 Functional Correctness' '🟡 Minor' '⚡ Quick win')" true)" skip
is "skip-minor: CR Security+Minor stays gated" \
   "$(cls "$(cr '🔒 Security & Privacy' '🟡 Minor' '⚡ Quick win')" true)" gated
is "skip-minor: Codex P2 -> skip" "$(cls "$(jq -nc '{source:"codex",p_badge:"2"}')" true)" skip
is "skip-minor: Codex P1 stays gated" "$(cls "$(jq -nc '{source:"codex",p_badge:"1"}')" true)" gated

# P0 is Codex's most severe badge. Before the parser read it, P0 fell to `review`
# (surfaced, never judged): the worst finding was the one the loop never acted on.
is "Codex P0 -> gated" "$(cls "$(jq -nc '{source:"codex",p_badge:"0"}')")" gated
# A Codex P2 from a later round is judged like any other finding (#327): deferring it
# unjudged filled the follow-up issues. The round no longer changes a tier.
clsi() { printf '%s' "$1" | ITER="$2" bash "$SCRIPTS/classify-item.sh" | jq -r '.tier'; }
is "iter 2 Codex P2 -> gated (judged)"   "$(clsi "$(jq -nc '{source:"codex",p_badge:"2"}')" 2)" gated
is "iter 3 Codex P2 -> gated (judged)"   "$(clsi "$(jq -nc '{source:"codex",p_badge:"2"}')" 3)" gated

echo
echo "fetch-codex-comments.sh"

CXSHIM=$(mktemp -d)
cat > "$CXSHIM/gh" <<SH
#!/usr/bin/env bash
cat "$FIX/pr-comments-codex-badges.json"
SH
chmod +x "$CXSHIM/gh"
cx=$(PATH="$CXSHIM:$PATH" bash "$SCRIPTS/fetch-codex-comments.sh" o r 42 777 2>/dev/null); rc=$?
is "codex fetch exits 0"                   "$rc" 0
is "only the requested review id"          "$(jq 'length' <<<"$cx")" 2
is "P0 badge parsed"                       "$(jq -r '.[0].p_badge' <<<"$cx")" 0
is "P0 badge fixture -> gated"             "$(jq -c '.[0]' <<<"$cx" | bash "$SCRIPTS/classify-item.sh" | jq -r '.tier')" gated
# A comment whose line left the current diff has line=null; the original line keeps
# it locatable instead of reading as a file-level finding.
is "null line falls back to original_line" "$(jq -r '.[1].line' <<<"$cx")" 40
is "current line wins when present"        "$(jq -r '.[0].line' <<<"$cx")" 12
# A failed fetch is not "no findings". `gh ... 2>/dev/null | jq -s 'add // []'` printed
# [] for it, and the caller read that as a Codex review with nothing to say.
cat > "$CXSHIM/gh" <<'SH'
#!/usr/bin/env bash
echo "gh: HTTP 502" >&2; exit 1
SH
cx=$(PATH="$CXSHIM:$PATH" bash "$SCRIPTS/fetch-codex-comments.sh" o r 42 777 2>/dev/null); rc=$?
is "gh failure -> non-zero exit"           "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)" nonzero
is "gh failure -> no [] on stdout"         "$cx" ""
rm -rf "$CXSHIM"

echo
echo "fetch-cr-threads.sh header fields"

# The inline header is `_<category>_ | _<severity>_ | _<effort>_`. Dropping the
# third field is what made every Minor look effort-less; a body with NO header
# must still yield a record (capture() emits nothing on a non-match, and an empty
# value inside an object constructor deletes the whole object).
th=$(CR_THREADS_RESPONSE_FILE="$FIX/cr-threads-3field.json" \
       bash "$SCRIPTS/fetch-cr-threads.sh" o r 42 2>/dev/null)
is "3-field header -> 4 records kept"   "$(jq 'length' <<<"$th")" 4
is "3-field header -> category"         "$(jq -r '.[0].category_emoji' <<<"$th")" "🎯 Functional Correctness"
is "3-field header -> severity"         "$(jq -r '.[0].severity_emoji' <<<"$th")" "🟠 Major"
is "3-field header -> effort"           "$(jq -r '.[0].effort_emoji' <<<"$th")" "⚡ Quick win"
is "3-field header -> heavy lift"       "$(jq -r '.[1].effort_emoji' <<<"$th")" "🏗️ Heavy lift"
is "legacy 2-field header -> severity"  "$(jq -r '.[2].severity_emoji' <<<"$th")" "🟡 Minor"
is "legacy 2-field header -> null effort" "$(jq -r '.[2].effort_emoji' <<<"$th")" null
is "headerless body -> record survives" "$(jq -r '.[3].path' <<<"$th")" "src/d.py"
is "headerless body -> null category"   "$(jq -r '.[3].category_emoji' <<<"$th")" null

# The header is read by its emoji badges, not its emphasis. PR #283 got bold
# headers (`**…** | **…** | **…**`) and the old `_…_` regex either missed them
# (tier `review`) or latched onto underscores in the body (`last_verified`).
th=$(CR_THREADS_RESPONSE_FILE="$FIX/cr-threads-header-formats.json" \
       bash "$SCRIPTS/fetch-cr-threads.sh" o r 42 2>/dev/null)
fields() { jq -r ".[$1] | [.category_emoji, .severity_emoji, .effort_emoji] | join(\" / \")" <<<"$th"; }
want="🎯 Functional Correctness / 🟡 Minor / ⚡ Quick win"
is "bold header -> badge fields"    "$(fields 0)" "$want"
is "italic header -> badge fields"  "$(fields 1)" "$want"
is "plain header -> badge fields"   "$(fields 2)" "$want"
is "underscores in body do not leak into header" "$(fields 4)" "$want"
tier_at() { jq -c ".[$1]" <<<"$th" | bash "$SCRIPTS/classify-item.sh" | jq -r '.tier'; }
is "PR #283 bold Minor+Quick win -> auto" "$(tier_at 0)" auto
is "PR #283 bold Major -> gated"          "$(tier_at 3)" gated
is "🔵 Trivial header -> skip"           "$(tier_at 5)" skip
is "⚪ Info header -> skip"              "$(tier_at 6)" skip

echo
echo "fetch-cr-outside-diff.sh"

# CodeRabbit puts findings outside the diff only in the review body, never in a
# thread. The fixture is review 5427040251 on PR #283 (3 such findings), plus the
# same body under the registrable impostor login `coderabbitai-evil`.
od() { CR_REVIEWS_RESPONSE_FILE="$1" bash "$SCRIPTS/fetch-cr-outside-diff.sh" o r 42 "${2:-[]}" 2>/dev/null; }
ODF="$FIX/cr-reviews-outside-diff.json"
out=$(od "$ODF" <<<'[]'); rc=$?
is "outside-diff: exits 0"               "$rc" 0
is "outside-diff: 3 records, impostor ignored" "$(jq 'length' <<<"$out")" 3
is "outside-diff: path"                  "$(jq -r '.[0].path' <<<"$out")" "plugins/wiki/skills/lint/SKILL.md"
is "outside-diff: line range"            "$(jq -r '[.[] | "\(.startLine)-\(.line)"] | join(",")' <<<"$out")" "28-30,33-35,48-49"
is "outside-diff: header fields on every record" \
   "$(jq -r '[.[] | [.category_emoji, .severity_emoji, .effort_emoji] | join(" / ")] | unique | .[]' <<<"$out")" \
   "🎯 Functional Correctness / 🟡 Minor / ⚡ Quick win"
is "outside-diff: body carries the finding" \
   "$(jq -r '.[1].body | test("frontmatter")' <<<"$out")" true
is "outside-diff: marked with origin + review id" \
   "$(jq -r '[.[] | "\(.source)/\(.origin)/\(.review_id)"] | unique | .[]' <<<"$out")" "cr/outside-diff/5427040251"
is "outside-diff: Minor + Quick win -> auto" \
   "$(jq -c '.[0]' <<<"$out" | bash "$SCRIPTS/classify-item.sh" | jq -r '.tier')" auto
# A thread that is a confirmed copy of the finding (same path, line, header and
# title; the header emphasis may differ) is one record, which carries the review
# id so the review is still recorded as processed.
thr_body() { jq -Rs --arg sev "$1" --arg title "$2" \
  '"_🎯 Functional Correctness_ | _\($sev)_ | _⚡ Quick win_\n\n**\($title)**\n\nbody"' </dev/null; }
thr=$(jq -nc --argjson b "$(thr_body '🟡 Minor' 'Check for `index.md` before the page loops.')" \
  '[{"source":"cr","path":"plugins/wiki/skills/lint/SKILL.md","line":30,"startLine":28,"body":$b,"databaseId":7}]')
out=$(od "$ODF" <<<"$thr")
is "outside-diff: confirmed copy of a thread -> merged" "$(jq 'length' <<<"$out")" 3
is "outside-diff: merged record is the thread"   "$(jq -r '.[0].databaseId' <<<"$out")" 7
is "outside-diff: merged thread keeps review id" "$(jq -r '.[0].review_id' <<<"$out")" 5427040251
# A different finding on the same path and line is not a copy: both are judged
# (issue #297). Same header, other title; and a thread with no header at all.
thr2=$(jq -nc --argjson b "$(thr_body '🟡 Minor' 'Quote `$W` in the find call.')" \
  '[{"source":"cr","path":"plugins/wiki/skills/lint/SKILL.md","line":30,"startLine":28,"body":$b,"databaseId":8},
    {"source":"cr","path":"plugins/wiki/skills/lint/SKILL.md","line":35,"startLine":33,"body":"t","databaseId":9}]')
out2=$(od "$ODF" <<<"$thr2")
is "outside-diff: distinct finding on a thread line -> both kept" "$(jq 'length' <<<"$out2")" 5
is "outside-diff: distinct finding -> thread gains no review id" \
   "$(jq -r '[.[0].review_id, .[1].review_id] | map(tostring) | join(",")' <<<"$out2")" "null,null"
# A processed review is not judged again: Step 9c.7 records each review_id under
# cr_processed_reviews, and the next round reads that list back.
OD=$(mktemp -d)
printf '{"codex_processed_reviews":[9]}\n' > "$OD/state.json"
jq -r '[.[].review_id // empty] | unique | .[]' <<<"$out" \
  | while IFS= read -r rid; do bash "$SCRIPTS/persist-codex-id.sh" "$OD/state.json" "$rid" cr_processed_reviews; done
is "outside-diff: review id persisted under its own key" \
   "$(jq -c '[.cr_processed_reviews, .codex_processed_reviews]' "$OD/state.json")" "[[5427040251],[9]]"
out=$(od "$ODF" "$(jq -c '.cr_processed_reviews' "$OD/state.json")" <<<"$thr")
is "outside-diff: processed review -> thread only" "$(jq 'length' <<<"$out")" 1
# The path comes from an untrusted body: it reaches path-trust like a thread path.
jq '.[0][0].body |= sub("`plugins/wiki/skills/lint/SKILL.md:28-30`"; "`../../../etc/passwd:28-30`")' "$ODF" > "$OD/escape.json"
p=$(od "$OD/escape.json" <<<'[]' | jq -r '.[0].path')
is "outside-diff: escaping path extracted as-is" "$p" "../../../etc/passwd"
bash "$SCRIPTS/path-trust.sh" "$HERE" "$p" 2>/dev/null; rc=$?
is "outside-diff: escaping path rejected by path-trust" "$rc" 1
# A block whose findings cannot be read (the older per-file grouping) fails loud:
# an empty result would read as "nothing outside the diff".
out=$(od "$FIX/cr-reviews-outside-diff-grouped.json" <<<'[]'); rc=$?
is "outside-diff: unreadable block -> non-zero exit" "$rc" 1
is "outside-diff: unreadable block -> no records"    "$out" ""
# No reviews at all is a real empty, not a failure.
printf '[[]]' > "$OD/none.json"
is "outside-diff: no reviews -> threads unchanged" "$(od "$OD/none.json" <<<"$thr" | jq 'length')" 1
# Fetch failure is not "no findings".
printf '#!/usr/bin/env bash\nexit 1\n' > "$OD/gh"; chmod +x "$OD/gh"
PATH="$OD:$PATH" bash "$SCRIPTS/fetch-cr-outside-diff.sh" o r 42 '[]' <<<'[]' >/dev/null 2>&1; rc=$?
is "outside-diff: gh failure -> non-zero exit" "$rc" 1
# gh before 2.45 has no --slurp: the live path must work on raw --paginate output.
cat > "$OD/gh" <<SH
#!/usr/bin/env bash
case " \$* " in *" --slurp "*) echo "unknown flag: --slurp" >&2; exit 1 ;; esac
jq -c '.[]' "$ODF"
SH
out=$(PATH="$OD:$PATH" bash "$SCRIPTS/fetch-cr-outside-diff.sh" o r 42 '[]' <<<'[]' 2>/dev/null); rc=$?
is "outside-diff: gh without --slurp -> findings read" "$rc:$(jq 'length' <<<"$out" 2>/dev/null)" "0:3"
# A long PR's thread records outgrow ARG_MAX: they must not ride on the command line.
jq -nc '[range(0; 20000) | {source:"cr", path:"big.sh", line:., body:("x" * 150)}]' > "$OD/big.json"
out=$(od "$ODF" < "$OD/big.json" | jq 'length'); rc=$?
is "outside-diff: thread records past ARG_MAX -> all kept" "$out" 20003
rm -rf "$OD"

echo
echo "churn-scope.sh"

# A finding on lines the PREVIOUS iteration's own commit produced, or outside the
# PR diff entirely, is churn: the reviewer has run out of pull request to review.
# Code fixtures carry a code extension on purpose: the position test only applies
# to code, so a .txt stand-in would exercise the prose path instead.
CH=$(mktemp -d)
(
  cd "$CH" && git init -q . && git config user.email t@t && git config user.name t \
    && git checkout -q -b main \
    && printf 'a\nb\nc\nd\ne\n' > base.sh && printf 'a\nb\nc\nd\ne\n' > doc.md \
    && git add -A && git commit -qm base \
    && git checkout -q -b feat \
    && printf 'a\nb\nNEW-PR\nd\ne\n' > base.sh && printf 'a\nb\nNEW-PR\nd\ne\n' > doc.md \
    && git add -A && git commit -qm pr-change \
    && printf 'p\nq\n' > 'space file.sh' && printf 'p\nq\n' > '한글.sh' \
    && git add -A && git commit -qm awkward-names \
    && printf 'x\ny\n' > added-by-loop.sh && printf 'x\ny\n' > rewritten.md \
    && printf 'x\ny\n' > notes.MD && printf 'x\ny\n' > LICENSE \
    && git add -A && git commit -qm iter-commit
) >/dev/null 2>&1
# PREV_SHA = HEAD~1, i.e. everything the last iteration committed.
PREV=$(cd "$CH" && git rev-parse HEAD~1)
ch() { (cd "$CH" && bash "$SCRIPTS/churn-scope.sh" "$PREV" main "$1" "$2"); }
is "line added by the previous iteration -> churn" "$(ch added-by-loop.sh 1)" churn
is "line the PR itself changed -> fresh"           "$(ch base.sh 3)" fresh
is "line outside the PR diff -> churn"             "$(ch base.sh 5)" churn
is "file not in the PR at all -> churn"            "$(ch untouched.sh 1)" churn
# Prose rewrites its own paragraphs every iteration, so a line the last commit
# produced says nothing about who authored the defect on it. Charging that as
# churn stopped a live loop at iter 3 while real findings were still arriving
# (PR #254). The position test is skipped for prose; the PR-diff test is not.
is "prose line the previous iteration rewrote -> fresh" "$(ch rewritten.md 1)" fresh
is "prose line the PR itself changed -> fresh"          "$(ch doc.md 3)" fresh
is "prose line outside the PR diff -> churn"            "$(ch doc.md 5)" churn
is "prose file not in the PR at all -> churn"           "$(ch untouched.md 1)" churn
# Both must sit on a file the previous iteration actually committed: a name that
# is not in the repository returns churn through the outside-the-diff test, so the
# assertion would pass with the prose match removed entirely.
is "prose extension match ignores case"                 "$(ch notes.MD 1)" fresh
# LICENSE / NOTICE / a bare README are prose with no extension to match on.
is "extensionless prose basename -> fresh"              "$(ch LICENSE 1)" fresh
# Iter 1 has no previous commit; the PR-diff test still applies.
is "no PREV_SHA: PR line still fresh" \
   "$( (cd "$CH" && bash "$SCRIPTS/churn-scope.sh" "" main base.sh 3) )" fresh
# A file-level finding has no position to compare. Defaulting it to churn would
# silence real file-level work, so it stays fresh.
is "file-level finding (no line) -> fresh"  "$(ch base.sh '')" fresh
is "non-numeric line -> fresh"              "$(ch base.sh 'null')" fresh
# An unresolvable base must not manufacture churn out of a lookup failure.
is "unresolvable base -> fresh" \
   "$( (cd "$CH" && bash "$SCRIPTS/churn-scope.sh" "" no-such-ref base.sh 3) )" fresh
# git pads the `+++` header with a tab and octal-escapes non-ASCII names. Comparing
# the raw header text marked every finding in such a file as churn, which quietly
# demoted real findings to cosmetic and let the loop stop early.
is "path with a space -> fresh"             "$(ch 'space file.sh' 1)" fresh
is "non-ASCII path -> fresh"                "$(ch '한글.sh' 1)" fresh
rm -rf "$CH"

echo
echo "sniff-cr-rate-limit.sh permanent skip"

# "Review skipped: N files exceed the limit" is not a rate-limit that resets —
# waiting reproduces it forever. Treating it as transient let the iteration
# converge to `clean` on a PR CodeRabbit had never actually read.
SSHIM=$(mktemp -d)
cat > "$SSHIM/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"/issues/"*"/comments"*) echo '[{"user":{"login":"coderabbitai[bot]"},"created_at":"2030-01-01T00:00:00Z","updated_at":"2030-01-01T00:00:00Z","body":"Review skipped: 356 files exceed the limit of 300"}]' ;;
  *"/pulls/"*"/reviews"*)   echo '[]' ;;
  *"/pulls/"*)              echo '{"head":{"sha":"deadbeef"}}' ;;
  *"/statuses"*)            echo '[]' ;;
  *"/check-runs"*)          echo '{"check_runs":[]}' ;;
  *) echo "unknown gh args: $*" >&2; exit 1 ;;
esac
SH
chmod +x "$SSHIM/gh"
rl=$(PATH="$SSHIM:$PATH" bash "$SCRIPTS/sniff-cr-rate-limit.sh" o r 42 "2020-01-01T00:00:00Z" 2>/dev/null) || true
is "file-limit skip -> detected"  "$(jq -r '.hits > 0' <<<"$rl" 2>/dev/null)" true
is "file-limit skip -> permanent" "$(jq -r '.permanent' <<<"$rl" 2>/dev/null)" true

# A plain quota refill is NOT permanent, and its minute count must still parse
# through the newer "Next included review available in" phrasing.
cat > "$SSHIM/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"/issues/"*"/comments"*) echo '[{"user":{"login":"coderabbitai[bot]"},"created_at":"2030-01-01T00:00:00Z","updated_at":"2030-01-01T00:00:00Z","body":"Review limit reached. **Next included review available in:** **6 minutes**"}]' ;;
  *"/pulls/"*"/reviews"*)   echo '[]' ;;
  *"/pulls/"*)              echo '{"head":{"sha":"deadbeef"}}' ;;
  *"/statuses"*)            echo '[]' ;;
  *"/check-runs"*)          echo '{"check_runs":[]}' ;;
  *) echo "unknown gh args: $*" >&2; exit 1 ;;
esac
SH
rl2=$(PATH="$SSHIM:$PATH" bash "$SCRIPTS/sniff-cr-rate-limit.sh" o r 42 "2020-01-01T00:00:00Z" 2>/dev/null) || true
is "quota refill -> not permanent" "$(jq -r '.permanent' <<<"$rl2" 2>/dev/null)" false
is "'Next included review available in' -> reset parsed" \
   "$(jq -r '.reset_minutes_estimate' <<<"$rl2" 2>/dev/null)" 6
rm -rf "$SSHIM"

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
is "0 completes -> incomplete"             "$(jq -r '.incomplete' <<<"$so")" true
cat > "$CRSHIM/coderabbit" <<'SH'
#!/usr/bin/env bash
printf '{"type":"finding"}\n{"type":"complete"}\n'
SH
so=$(PATH="$CRSHIM:$PATH" BASE=main PR_NUM=990002 ITER=1 bash "$SCRIPTS/cr-cli-spawn.sh" 2>/dev/null)
is "complete present -> emitted_complete true" "$(jq -r '.emitted_complete' <<<"$so")" true
is "bare complete -> not incomplete" "$(jq -r '.incomplete' <<<"$so")" false

# A `complete` event alone does not mean the review finished: `outcome: "failed"`
# or a positive `unreviewedFileCount` marks a partial run (docs cli/agent-mode),
# and findings may already have been emitted. The shim exits 0 on purpose: the
# marker must say incomplete even where the exit code does not (CLI < 0.7.7).
cli_incomplete() {
  printf '{"type":"finding"}\n%s\n' "$1" > "$CRSHIM/events.jsonl"
  printf '#!/usr/bin/env bash\ncat "%s"\n' "$CRSHIM/events.jsonl" > "$CRSHIM/coderabbit"
  PATH="$CRSHIM:$PATH" BASE=main PR_NUM=990003 ITER=1 bash "$SCRIPTS/cr-cli-spawn.sh" 2>/dev/null | jq -r '.incomplete'
}
is "complete outcome failed -> incomplete" \
   "$(cli_incomplete '{"type":"complete","status":"review_completed","outcome":"failed","findings":1}')" true
is "complete unreviewedFileCount > 0 -> incomplete" \
   "$(cli_incomplete '{"type":"complete","status":"review_completed","unreviewedFileCount":3}')" true
is "completed_with_warnings, nothing unreviewed -> complete" \
   "$(cli_incomplete '{"type":"complete","status":"review_completed","outcome":"completed_with_warnings","unreviewedFileCount":0}')" false
rm -rf "$CRSHIM" /tmp/cr-cli-review-990001-iter1-* /tmp/cr-cli-review-990002-iter1-* /tmp/cr-cli-review-990003-iter1-*

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

# Same review set, but authored by the suffixless login GraphQL reports. REST
# says `chatgpt-codex-connector[bot]`, GraphQL says `chatgpt-codex-connector`,
# and the old `== "chatgpt-codex-connector[bot]"` equality matched only the
# first — zero rows on the other, which is indistinguishable from "Codex has
# not reviewed yet" and spins the grace poll to its cap. The fixture also
# carries a null `user` (ghost/deleted account) because `null | test(...)`
# aborts the whole jq program, so the `// ""` guard is part of the contract.
# RED against the equality filter AND against a `// ""`-less test().
GSHIM3=$(mktemp -d)
cat > "$GSHIM3/gh" <<SH
#!/usr/bin/env bash
cat "$FIX/pr-reviews-codex-graphql-login.json"
SH
chmod +x "$GSHIM3/gh"
g3=$(PATH="$GSHIM3:$PATH" OWNER=o REPO=r PR_NUM=42 PROCESSED='[555]' INTERVAL=0 \
      bash "$SCRIPTS/poll-codex-grace.sh" 2>/dev/null) || true
is "suffixless (GraphQL) codex login still matches -> id 777" "$(jq -r '.codex_review_id' <<<"$g3" 2>/dev/null)" 777

e3=$(PATH="$GSHIM3:$PATH" bash "$SCRIPTS/probe-codex-engagement.sh" o r 42 2>/dev/null) || true
is "suffixless (GraphQL) codex login reads as engaged" "$e3" active
rm -rf "$GSHIM3"

# Matching the login as a bare stem (`test("chatgpt-codex-connector"; "i")`) is
# a SUBSTRING match, and `chatgpt-codex-connector-evil` is a registrable GitHub
# login (28 chars, alnum+hyphen) that any account can use to review a public PR.
# review-loop feeds Codex review bodies back into code edits, so a matcher an
# outsider can satisfy is an injection path into that loop. The anchored form
# `^chatgpt-codex-connector(\[bot\])?$` is forgery-proof because `[` and `]`
# are not legal login characters. The spoof review is the NEWEST here, so the
# stem filter fails as a WRONG SUCCESS, not as an error: `sort_by(.submitted_at)
# | last` hands back id 999. RED against the unanchored stem by construction.
GSHIM4=$(mktemp -d)
cat > "$GSHIM4/gh" <<SH
#!/usr/bin/env bash
cat "$FIX/pr-reviews-codex-spoof-login.json"
SH
chmod +x "$GSHIM4/gh"
g4=$(PATH="$GSHIM4:$PATH" OWNER=o REPO=r PR_NUM=42 PROCESSED='[]' INTERVAL=0 \
      bash "$SCRIPTS/poll-codex-grace.sh" 2>/dev/null) || true
is "spoofed codex-lookalike login is not picked as newest -> id 777" "$(jq -r '.codex_review_id' <<<"$g4" 2>/dev/null)" 777
rm -rf "$GSHIM4"

# Same threat on the engagement probe, which counts authors rather than picking
# one. A PR whose ONLY review comes from the lookalike must read as inactive;
# under the stem filter it read as active, which is how a forged review gets the
# state machine to treat outsider text as Codex output. (Separate fixture: the
# probe has no processed-id filter, so the legit 777 above would mask this.)
GSHIM5=$(mktemp -d)
cat > "$GSHIM5/gh" <<SH
#!/usr/bin/env bash
cat "$FIX/pr-reviews-codex-spoof-only.json"
SH
chmod +x "$GSHIM5/gh"
e5=$(PATH="$GSHIM5:$PATH" bash "$SCRIPTS/probe-codex-engagement.sh" o r 42 2>/dev/null) || true
is "spoofed codex-lookalike login alone reads as inactive" "$e5" inactive
rm -rf "$GSHIM5"

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
# Keep run_capped's status: empty stdout alone cannot tell "the watchdog killed a
# still-waiting poll" (the pass condition) from "setup broke and the child died
# instantly" (a false green). Measured: SIGTERM -> 143, missing script -> 127,
# both with empty stdout. Asserting 143 is what makes the empty-output check mean
# anything. (CodeRabbit 🟠 Major, PR #183)
g=$(run_capped 3 env PATH="$GSHIM2:$PATH" OWNER=o REPO=r PR_NUM=42 PROCESSED='[555]' INTERVAL=1 \
      bash "$SCRIPTS/poll-codex-grace.sh" 2>/dev/null); g_rc=$?
is "no unprocessed review -> no terminal line" "$g" ""
is "no unprocessed review -> watchdog killed it (not an early exit)" "$g_rc" 143
rm -rf "$GSHIM2"

echo
echo "codex-head-verdict.sh"

# Codex reports its HEAD verdict in one `<!-- codex-pull-request-review-summary -->`
# issue comment it edits in place (Running/Completed/Failed + short SHA; shape
# copied from PR #283), and posts a review only when it has findings. A run that
# read only review ids archived PR #223 as clean while Codex was still Running
# on HEAD (ADR 0002). Fixture HEAD is 95ab2f6...; `__FAIL__` makes gh fail.
CHEAD=95ab2f621c9add07df26af3770418786a29a62bb
VSHIM=$(mktemp -d)
verdict() { # COMMENTS_FIXTURE REVIEWS_FIXTURE [VAR=value ...]; RXN=<fixture> serves PR reactions ([] unset, __FAIL__ fails)
  local c="$1" r="$2"; shift 2
  cat > "$VSHIM/gh" <<SH
#!/usr/bin/env bash
case "\$*" in
  *"/issues/"*"/reactions"*) [ "${RXN:-}" = __FAIL__ ] && exit 1; [ -n "${RXN:-}" ] || { echo '[]'; exit 0; }; cat "$FIX/${RXN:-}" ;;
  *"/issues/"*"/comments"*) [ "$c" = __FAIL__ ] && exit 1; cat "$FIX/$c" ;;
  *"/pulls/"*"/reviews"*)   [ "$r" = __FAIL__ ] && exit 1; cat "$FIX/$r" ;;
  *) echo "unknown gh args: \$*" >&2; exit 1 ;;
esac
SH
  chmod +x "$VSHIM/gh"
  env PATH="$VSHIM:$PATH" OWNER=o REPO=r PR_NUM=42 CUR_SHA="$CHEAD" \
    PUSH_TIME=2020-01-01T00:00:00Z CODEX_GRACE=30 "$@" \
    bash "$SCRIPTS/codex-head-verdict.sh" 2>/dev/null
}
vf() { jq -r "$1" <<<"$v" 2>/dev/null; }

v=$(verdict issue-comments-codex-summary-completed.json pr-reviews-codex-head.json)
is "Completed on HEAD + HEAD review -> findings"        "$(vf .verdict)" findings
is "Completed on HEAD + HEAD review -> that review id"  "$(vf .head_review_id)" 5427206208
is "Completed on HEAD -> summary_state completed"       "$(vf .summary_state)" completed
is "Completed on HEAD -> summary_sha"                   "$(vf .summary_sha)" 95ab2f6
is "Completed on HEAD -> no fallback"                   "$(vf .fallback)" null

# --paginate prints one array per page; the summary and the HEAD review each sit
# on page two. The inputs go through temp files, not <(…), since #309.
v=$(verdict issue-comments-codex-summary-two-pages.json pr-reviews-codex-two-pages.json)
is "two pages each -> findings from page two"           "$(vf .verdict)" findings
is "two pages each -> HEAD review id from page two"     "$(vf .head_review_id)" 5427206208

# The lookalike-login review on HEAD must not turn a pass into findings.
v=$(verdict issue-comments-codex-summary-completed.json pr-reviews-codex-prior-only.json)
is "Completed on HEAD, no HEAD review -> clean"         "$(vf .verdict)" clean
is "spoofed codex-lookalike review on HEAD is ignored"  "$(vf .head_review_id)" null

v=$(verdict issue-comments-codex-summary-running.json pr-reviews-codex-prior-only.json)
is "Running on HEAD -> in_progress"                     "$(vf .verdict)" in_progress
v=$(verdict issue-comments-codex-summary-failed.json pr-reviews-codex-prior-only.json)
is "Failed on HEAD -> failed"                           "$(vf .verdict)" failed
# A Failed row and a later Completed row (a re-run) for the same HEAD: only the
# newest row, by its relative-time, speaks for HEAD, wherever it sits in the
# table (issue #297). The newer row is listed first here.
v=$(verdict issue-comments-codex-summary-failed-then-completed.json pr-reviews-codex-prior-only.json)
is "Failed then a later Completed on HEAD -> clean"     "$(vf .verdict):$(vf .summary_state)" clean:completed

# Completed, but for the previous commit: Codex has not judged HEAD yet.
v=$(verdict issue-comments-codex-summary-stale-sha.json pr-reviews-codex-prior-only.json)
is "Completed on another SHA -> none"                   "$(vf .verdict)" none
is "Completed on another SHA -> summary_sha kept"       "$(vf .summary_sha)" 03a3e71

# Edit history: a stale summary still says Running on HEAD, the live one was
# edited to Completed, and a newer lookalike-login comment claims Failed.
v=$(verdict issue-comments-codex-summary-edited.json pr-reviews-codex-prior-only.json)
is "edited summary -> newest real comment wins (clean)" "$(vf .verdict)" clean

# Unparseable summary: never clean; hand the caller to review-id polling.
v=$(verdict issue-comments-codex-summary-unparseable.json pr-reviews-codex-prior-only.json)
is "unparseable summary -> unknown, not clean"          "$(vf .verdict)" unknown
is "unparseable summary -> summary_state unparsed"      "$(vf .summary_state)" unparsed
is "unparseable summary -> review-id poll fallback"     "$(vf .fallback)" review_id_poll
v=$(verdict issue-comments-codex-summary-unknown-status.json pr-reviews-codex-prior-only.json)
is "unknown status word -> unknown, not clean"          "$(vf .verdict)" unknown
is "unknown status word -> review-id poll fallback"     "$(vf .fallback)" review_id_poll

# No summary comment at all: the HEAD review alone still decides findings.
v=$(verdict issue-comments-cr-edited-in-place.json pr-reviews-codex-prior-only.json)
is "no summary -> unknown"                              "$(vf .verdict)" unknown
is "no summary -> summary_state absent"                 "$(vf .summary_state)" absent
is "no summary -> review-id poll fallback"              "$(vf .fallback)" review_id_poll
v=$(verdict issue-comments-cr-edited-in-place.json pr-reviews-codex-head.json)
is "no summary + HEAD review -> findings"               "$(vf .verdict)" findings

# Codex with nothing to say leaves a 👍 on the PR and no review (PR #320: push
# 11:45:48Z, 👍 11:48:26Z). Only the anchored bot login's +1 created after the push
# counts; one from before the push belongs to an older HEAD. And only when the
# summary's `<!-- codex-review-state:v1 {...} -->` marker (shape read from PR #320
# and #334) names HEAD as the completed code review: Codex finishing the previous
# commit after a new push leaves a 👍 newer than the push too (#338).
v=$(RXN=issue-reactions-codex-plus1.json verdict issue-comments-codex-summary-state-head.json pr-reviews-codex-prior-only.json PUSH_TIME=2026-10-17T11:45:48Z)
is "Codex 👍 after the push, older-SHA row, state marker on HEAD -> clean" "$(vf .verdict)" clean
v=$(RXN=issue-reactions-codex-plus1.json verdict issue-comments-codex-summary-state-stale.json pr-reviews-codex-prior-only.json PUSH_TIME=2026-10-17T11:45:48Z)
is "Codex 👍 after the push, state marker on the previous commit -> none (#338)" "$(vf .verdict)" none
v=$(RXN=issue-reactions-codex-plus1.json verdict issue-comments-codex-summary-state-head-running.json pr-reviews-codex-prior-only.json PUSH_TIME=2026-10-17T11:45:48Z)
is "Codex 👍 after the push, state marker running on HEAD -> none" "$(vf .verdict)" none
v=$(RXN=issue-reactions-codex-plus1.json verdict issue-comments-codex-summary-stale-sha.json pr-reviews-codex-prior-only.json PUSH_TIME=2026-10-17T11:45:48Z)
is "Codex 👍 after the push, older-SHA row, no state marker -> none" "$(vf .verdict)" none
v=$(RXN=issue-reactions-codex-plus1.json verdict issue-comments-cr-edited-in-place.json pr-reviews-codex-prior-only.json PUSH_TIME=2026-10-17T11:45:48Z)
is "Codex 👍 after the push, no summary -> not clean"   "$(vf .verdict)" unknown
v=$(RXN=issue-reactions-codex-plus1.json verdict issue-comments-cr-edited-in-place.json pr-reviews-codex-prior-only.json PUSH_TIME=2026-10-17T11:50:00Z)
is "Codex 👍 before the push -> not clean"              "$(vf .verdict)" unknown
v=$(RXN=issue-reactions-codex-plus1.json verdict issue-comments-cr-edited-in-place.json pr-reviews-codex-prior-only.json PUSH_TIME=)
is "Codex 👍, push time unknown -> not clean"           "$(vf .verdict)" unknown
v=$(RXN=issue-reactions-codex-lookalike.json verdict issue-comments-cr-edited-in-place.json pr-reviews-codex-prior-only.json PUSH_TIME=2026-10-17T11:45:48Z)
is "look-alike logins' 👍 and the bot's 👀 -> not clean" "$(vf .verdict)" unknown
v=$(RXN=issue-reactions-codex-plus1.json verdict issue-comments-cr-edited-in-place.json pr-reviews-codex-head.json PUSH_TIME=2026-10-17T11:45:48Z)
is "Codex 👍 and a Codex review on HEAD -> findings"    "$(vf .verdict)" findings
v=$(RXN=issue-reactions-codex-plus1.json verdict issue-comments-codex-summary-running.json pr-reviews-codex-prior-only.json PUSH_TIME=2026-10-17T11:45:48Z)
is "Codex 👍 while the summary says Running on HEAD -> in_progress" "$(vf .verdict)" in_progress
# Reactions that cannot be read only withhold the 👍; they never fail the verdict.
v=$(RXN=__FAIL__ verdict issue-comments-codex-summary-completed.json pr-reviews-codex-prior-only.json PUSH_TIME=2026-10-17T11:45:48Z); v_rc=$?
is "reactions unreadable -> summary still decides"      "$v_rc:$(vf .verdict)" 0:clean
is "reactions unreadable -> reported as unreadable"     "$(vf .reactions)" unreadable
# Where only a 👍 could give the verdict, an unreadable list is a failed read, not
# "no 👍": verdict error, so the HEAD verdict wait never drops Codex over it (#328).
v=$(RXN=__FAIL__ verdict issue-comments-codex-summary-state-head.json pr-reviews-codex-prior-only.json PUSH_TIME=2026-10-17T11:45:48Z); v_rc=$?
is "reactions unreadable, state marker on HEAD -> error, exit 1" "$v_rc:$(vf .verdict)" 1:error
# Without the marker on HEAD no 👍 could decide, so the failed read changes nothing.
v=$(RXN=__FAIL__ verdict issue-comments-cr-edited-in-place.json pr-reviews-codex-prior-only.json PUSH_TIME=2026-10-17T11:45:48Z); v_rc=$?
is "reactions unreadable, no summary -> unknown"        "$v_rc:$(vf .verdict)" 0:unknown
v=$(RXN=__FAIL__ verdict issue-comments-codex-summary-state-stale.json pr-reviews-codex-prior-only.json PUSH_TIME=2026-10-17T11:45:48Z); v_rc=$?
is "reactions unreadable, state marker on an older commit -> none" "$v_rc:$(vf .verdict)" 0:none
v=$(RXN=__FAIL__ verdict issue-comments-cr-edited-in-place.json pr-reviews-codex-prior-only.json PUSH_TIME=); v_rc=$?
is "reactions unreadable, no push time (no 👍 counts) -> unknown" "$v_rc:$(vf .verdict)" 0:unknown
v=$(RXN=issue-reactions-codex-plus1.json verdict issue-comments-cr-edited-in-place.json pr-reviews-codex-prior-only.json PUSH_TIME=2026-10-17T11:45:48Z)
is "reactions read -> reported as read"                 "$(vf .reactions)" read

# gh failure is its own verdict with a non-zero exit, never an empty "clean".
v=$(verdict __FAIL__ pr-reviews-codex-head.json); v_rc=$?
is "comments fetch failure -> verdict error"            "$(vf .verdict)" error
is "comments fetch failure -> exit 1"                   "$v_rc" 1
v=$(verdict issue-comments-codex-summary-completed.json __FAIL__); v_rc=$?
is "reviews fetch failure -> verdict error"             "$(vf .verdict)" error
is "reviews fetch failure -> exit 1"                    "$v_rc" 1

# One wait formula for every caller: max(CODEX_GRACE, CODEX_PREFLIGHT_TIMEOUT - push_age).
v=$(verdict issue-comments-codex-summary-running.json pr-reviews-codex-prior-only.json)
is "old push -> wait is CODEX_GRACE"                    "$(vf .wait_seconds)" 30
# The floor allows for slow process start-up (Git Bash on Windows), as in the pre-flight checks.
recent=$(jq -nr 'now - 100 | strftime("%Y-%m-%dT%H:%M:%SZ")')
v=$(verdict issue-comments-codex-summary-running.json pr-reviews-codex-prior-only.json PUSH_TIME="$recent" CODEX_PREFLIGHT_TIMEOUT=600)
is "push 100s ago -> wait is timeout - age (~500)" \
   "$(vf '.wait_seconds >= 470 and .wait_seconds <= 500')" true
v=$(verdict issue-comments-codex-summary-running.json pr-reviews-codex-prior-only.json PUSH_TIME= CODEX_PREFLIGHT_TIMEOUT=600)
is "no push time -> age 0 -> full timeout"              "$(vf .wait_seconds)" 600
v=$(verdict __FAIL__ __FAIL__ PUSH_TIME="$recent" CODEX_PREFLIGHT_TIMEOUT=600)
is "gh failure still reports the wait budget" \
   "$(vf '.wait_seconds >= 470 and .wait_seconds <= 500')" true
# The default budget sits above the slowest Codex turnaround ADR 0002 measured (726 s),
# so a late but ordinary review is not dropped (ADR 0006).
v=$(verdict issue-comments-codex-summary-running.json pr-reviews-codex-prior-only.json PUSH_TIME=)
is "default Codex budget is above the slowest turnaround" "$(vf '.wait_seconds > 726')" true

# The grace poll now runs under the full Codex wait budget on every gate, so it
# must end as soon as Codex passes HEAD instead of sleeping out up to 600s.
# Unreadable summaries keep it on plain review-id polling (watchdog kill = 143).
pollv() { # COMMENTS_FIXTURE
  cat > "$VSHIM/gh" <<SH
#!/usr/bin/env bash
case "\$*" in
  *"/issues/"*"/comments"*) cat "$FIX/$1" ;;
  *"/pulls/"*"/reviews"*)   cat "$FIX/pr-reviews-codex-prior-only.json" ;;
  *) echo "unknown gh args: \$*" >&2; exit 1 ;;
esac
SH
  chmod +x "$VSHIM/gh"
  run_capped 4 env PATH="$VSHIM:$PATH" OWNER=o REPO=r PR_NUM=42 CUR_SHA="$CHEAD" \
    PROCESSED='[5426830676]' INTERVAL=1 bash "$SCRIPTS/poll-codex-grace.sh" 2>/dev/null
}
g=$(pollv issue-comments-codex-summary-completed.json); g_rc=$?
is "grace poll: Completed clean on HEAD -> ends at once"   "$g_rc" 0
is "grace poll: Completed clean on HEAD -> verdict clean"  "$(jq -r '.verdict' <<<"$g" 2>/dev/null)" clean
is "grace poll: Completed clean on HEAD -> no review id"   "$(jq -r '.codex_review_id' <<<"$g" 2>/dev/null)" null
g=$(pollv issue-comments-codex-summary-failed.json); g_rc=$?
is "grace poll: Failed on HEAD -> ends with verdict failed" "$g_rc:$(jq -r '.verdict' <<<"$g" 2>/dev/null)" 0:failed
g=$(pollv issue-comments-codex-summary-unparseable.json); g_rc=$?
is "grace poll: unparseable summary -> keeps review-id polling" "$g_rc:$g" "143:"
g=$(pollv issue-comments-codex-summary-running.json); g_rc=$?
is "grace poll: Running on HEAD -> keeps waiting"          "$g_rc:$g" "143:"
rm -rf "$VSHIM"

echo
echo "engagement-gate.sh"

# CR does NOT post a new comment when a re-review finds nothing — it EDITS its
# existing walkthrough comment in place. Counting only `created_at` therefore
# reads a genuine clean re-review as "CR never looked at this push", which Step
# 8c turns into an infinite wait and finally cr_inactive, so --auto-merge can
# never fire on the normal converged path. Reproduced on PR #183: commit status
# said "Review completed" at 14:23:22 while the comment still carried
# created_at 14:10:37. The sibling sniff-cr-rate-limit.sh:25 already anchors on
# `created_at > $t or updated_at > $t`; the gate was left behind. RED against
# the created_at-only filter by construction. (issue #184)
ESHIM=$(mktemp -d)
cat > "$ESHIM/gh" <<SH
#!/usr/bin/env bash
case "\$3" in
  *pulls*reviews) echo '[]';;
  *) cat "$FIX/issue-comments-cr-edited-in-place.json";;
esac
SH
chmod +x "$ESHIM/gh"
e=$(PATH="$ESHIM:$PATH" bash "$SCRIPTS/engagement-gate.sh" o r 42 "2026-07-27T14:20:43Z" 2>/dev/null) || true
is "in-place comment edit after push counts as engagement" "$e" 1
rm -rf "$ESHIM"

# The inverse must still hold, or the gate would call every stale walkthrough
# "engaged" and Step 8c would declare a PR converged that CR never re-read.
ESHIM2=$(mktemp -d)
cat > "$ESHIM2/gh" <<SH
#!/usr/bin/env bash
case "\$3" in
  *pulls*reviews) echo '[]';;
  *) cat "$FIX/issue-comments-cr-stale-only.json";;
esac
SH
chmod +x "$ESHIM2/gh"
e2=$(PATH="$ESHIM2:$PATH" bash "$SCRIPTS/engagement-gate.sh" o r 42 "2026-07-27T14:20:43Z" 2>/dev/null) || true
is "comment untouched since before the push is not engagement" "$e2" 0
rm -rf "$ESHIM2"

# CodeRabbit edits its rate-limit notice in place on every limited push. The
# updated_at anchor above then counted that edit as "CR reviewed this push"
# (PR #223's false clean). A notice is the authoritative "no review ran" signal.
ESHIM4=$(mktemp -d)
cat > "$ESHIM4/gh" <<SH
#!/usr/bin/env bash
case "\$3" in
  *pulls*reviews) echo '[]';;
  *) cat "$FIX/issue-comments-cr-rl-notice-edited.json";;
esac
SH
chmod +x "$ESHIM4/gh"
e4=$(PATH="$ESHIM4:$PATH" bash "$SCRIPTS/engagement-gate.sh" o r 42 "2026-10-06T09:00:00Z" 2>/dev/null) || true
is "rate-limit notice edited after push is not engagement" "$e4" 0
rm -rf "$ESHIM4"

# Same anchoring contract on the CodeRabbit side, where the stem is only 10
# chars (`coderabbit`) and the canonical login is `coderabbitai` — so
# `coderabbitfake` slipped through and counted as a convergence signal, letting
# an outside account tell Step 8c the review landed. RED against
# `test("coderabbit"; "i")` by construction.
ESHIM3=$(mktemp -d)
cat > "$ESHIM3/gh" <<SH
#!/usr/bin/env bash
case "\$3" in
  *pulls*reviews) cat "$FIX/pr-reviews-cr-spoof-login.json";;
  *) echo '[]';;
esac
SH
chmod +x "$ESHIM3/gh"
e3g=$(PATH="$ESHIM3:$PATH" bash "$SCRIPTS/engagement-gate.sh" o r 42 "2026-07-27T14:20:43Z" 2>/dev/null) || true
is "spoofed coderabbit-lookalike login is not engagement" "$e3g" 0
rm -rf "$ESHIM3"

echo
echo "cr-head-verdict.sh"

# CodeRabbit's verdict is the review attached to HEAD, not its success status:
# a success row can stand on a push CR never reviewed. HV_REVIEWS / HV_COMMENTS
# are what the shimmed gh serves for the two PR listings.
HEAD_SHA=3e5ee3e4d477b7345ca5737210a2e76cc8ea4dfe
HV=$(mktemp -d)
cat > "$HV/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"/statuses"*) echo '[{"context":"CodeRabbit","state":"success","description":"Review completed","created_at":"2026-10-06T09:15:00Z"}]' ;;
  *"/pulls/"*"/reviews"*) cat "$HV_REVIEWS" ;;
  *"/issues/"*"/comments"*) cat "$HV_COMMENTS" ;;
  *) echo "unknown gh args: $*" >&2; exit 1 ;;
esac
SH
chmod +x "$HV/gh"
echo '[]' > "$HV/none.json"
hv() { HV_REVIEWS="$1" HV_COMMENTS="${2:-$HV/none.json}" PATH="$HV:$PATH" \
         bash "$SCRIPTS/cr-head-verdict.sh" o r 42 "${3:-$HEAD_SHA}" 2>/dev/null; }
is "success status, CR review only on an older commit -> none" \
   "$(hv "$FIX/pr-reviews-cr-older-commit.json")" none
jq --arg h "$HEAD_SHA" '.[0].commit_id = $h' "$FIX/pr-reviews-cr-older-commit.json" > "$HV/head-findings.json"
is "CR review on HEAD with actionable comments -> findings" "$(hv "$HV/head-findings.json")" findings
jq --arg h "$HEAD_SHA" '.[0].commit_id = $h | .[0].body = "**Actionable comments posted: 0**"' \
  "$FIX/pr-reviews-cr-older-commit.json" > "$HV/head-zero.json"
is "CR review on HEAD with 0 actionable -> clean" "$(hv "$HV/head-zero.json")" clean
# A clean re-review posts no review; CR edits the walkthrough to name the new head.
is "walkthrough 'No actionable comments' naming HEAD -> clean" \
   "$(hv "$FIX/pr-reviews-cr-older-commit.json" "$FIX/issue-comments-cr-edited-in-place.json")" clean
# The walkthrough names its range as "between <base> and <head>"; HEAD appearing
# as the BASE of that range is an older review, not one of HEAD.
is "walkthrough with HEAD only as range base -> none" \
   "$(hv "$HV/none.json" "$FIX/issue-comments-cr-edited-in-place.json" 86b604f13062715e11801304d6b58a0b6c90c84e)" none
jq --arg h "$HEAD_SHA" '.[0].commit_id = $h | .[0].body = "<!-- This is an auto-generated comment: rate limited by coderabbit.ai -->\nReview rate limited"' \
  "$FIX/pr-reviews-cr-older-commit.json" > "$HV/head-rl.json"
is "rate-limit notice on HEAD is not a verdict -> none" "$(hv "$HV/head-rl.json")" none
# A real review that quotes a notice phrase (reviewing code that matches on it) is
# still a review: it carries the actionable count a notice never has.
jq --arg h "$HEAD_SHA" '.[0].commit_id = $h | .[0].body = "**Actionable comments posted: 2**\n\nThe matcher misses `Review rate limited`."' \
  "$FIX/pr-reviews-cr-older-commit.json" > "$HV/head-quotes-notice.json"
is "review on HEAD quoting a notice phrase -> findings" "$(hv "$HV/head-quotes-notice.json")" findings
# Could not look is not "no verdict": exit non-zero with nothing on stdout.
out=$(HV_REVIEWS=/nonexistent PATH="$HV:$PATH" bash "$SCRIPTS/cr-head-verdict.sh" o r 42 "$HEAD_SHA" 2>/dev/null); rc=$?
is "reviews fetch failure -> non-zero exit" "$([ "$rc" -ne 0 ] && echo yes || echo no)" yes
is "reviews fetch failure -> no verdict printed" "$out" ""
rm -rf "$HV"

echo
echo "probe-codex-state.sh"

# The emoji probe is the fallback where Codex posts no summary comment. Its heuristic
# channels must never turn forgeable evidence into clean: a check-run anyone's app can
# name "codex-*", or a reaction anyone can leave on the Codex review.
PS=$(mktemp -d)
cat > "$PS/gh" <<'SH'
#!/usr/bin/env bash
[ -n "${PS_FAIL:-}" ] && { echo "HTTP 502" >&2; exit 1; }
case "$*" in
  *"/issues/"*"/reactions"*)            echo "${PS_ISSUE_RXN:-[]}" ;;
  *"/check-runs"*)                      echo "${PS_CHECKRUNS:-"{\"check_runs\":[]}"}" ;;
  *"/pulls/"*"/reviews/"*"/reactions"*) echo "${PS_REVIEW_RXN:-[]}" ;;
  *"/pulls/"*"/reviews"*)               echo "${PS_REVIEWS:-[]}" ;;
  *) echo "unknown gh args: $*" >&2; exit 1 ;;
esac
SH
chmod +x "$PS/gh"
ps_state() { PATH="$PS:$PATH" OWNER=o REPO=r PR_NUM=42 CUR_SHA=deadbeef PUSH_TIME=2026-10-06T09:00:00Z \
               bash "$SCRIPTS/probe-codex-state.sh" 2>/dev/null | jq -r '.emoji_state'; }
is "forged 'codex-lint' check-run summarising clean -> not clean" \
   "$(PS_CHECKRUNS='{"check_runs":[{"name":"codex-lint","status":"completed","conclusion":"success","app":{"slug":"codex-lint","owner":{"login":"mallory"}},"output":{"summary":"All clean"},"completed_at":"2026-10-06T09:05:00Z"}]}' ps_state)" unknown
PS_CODEX_REVIEW='[{"id":9,"user":{"login":"chatgpt-codex-connector[bot]"},"submitted_at":"2026-10-06T09:04:00Z"}]'
is "non-bot +1 on the Codex review -> not clean" \
   "$(PS_REVIEWS="$PS_CODEX_REVIEW" PS_REVIEW_RXN='[{"user":{"login":"mallory"},"content":"+1","created_at":"2026-10-06T09:06:00Z"}]' ps_state)" unknown
is "chatgpt-codex-connector[bot] +1 on its review -> clean" \
   "$(PS_REVIEWS="$PS_CODEX_REVIEW" PS_REVIEW_RXN='[{"user":{"login":"chatgpt-codex-connector[bot]"},"content":"+1","created_at":"2026-10-06T09:06:00Z"}]' ps_state)" clean
is "every gh call failing -> unknown, never clean" "$(PS_FAIL=1 ps_state)" unknown
rm -rf "$PS"

echo
echo "next-check.sh"

# The next look in a wait comes from what the wait saw, not a fixed 30 s: a reviewer
# at work is checked soon, nothing is due before Codex's fastest observed turnaround
# (68 s, ADR 0002), past its slowest (726 s) the wait backs off, and no sleep runs
# past the budget left.
nc() { bash "$SCRIPTS/next-check.sh" "$@" 2>/dev/null; }
is "reviewer in progress -> a third of INTERVAL"   "$(nc 300 600 true 30)" 10
is "push 20 s old, nothing seen -> until 68 s"     "$(nc 20 600 false 30)" 48
is "inside the usual turnaround -> INTERVAL"       "$(nc 300 600 false 30)" 30
is "past the slowest turnaround -> backs off"      "$(nc 900 600 false 30)" 60
is "never past the budget left"                    "$(nc 900 7 false 30)" 7
is "budget spent -> 1, never 0 or negative"        "$(nc 900 0 false 30)" 1
is "in progress wins over a young push"            "$(nc 20 600 true 30)" 10
is "INTERVAL 1 in progress -> 1"                   "$(nc 300 600 true 1)" 1
is "non-numeric input -> INTERVAL, clamped"        "$(nc x 600 false 30)" 30
# ADR 0002's turnaround numbers and the default Codex budget are written once
# (codex-turnaround.sh), and every wait rule and budget reads them from there.
is "turnaround numbers and the Codex budget live in one script" \
   "$(grep -lwE '68|726|600' "$SCRIPTS"/*.sh | while read -r f; do basename "$f"; done | tr '\n' ' ')" "codex-turnaround.sh "

echo
echo "head-verdicts.sh"

# The loop ends or merges only once every reviewer it has on gave HEAD a verdict
# (ADR 0002). A progress mark, a rate-limit notice or a review pause is not one.
# HW_REVIEWS / HW_COMMENTS are what the shimmed gh serves; every call is logged.
HW=$(mktemp -d); HW_LOG="$HW/gh.log"
cat > "$HW/gh" <<'SH'
#!/usr/bin/env bash
echo "$*" >> "$HW_LOG"
case "$*" in
  *"/issues/"*"/reactions"*) [ "${HW_RXN:-}" = __FAIL__ ] && exit 1; echo '[]' ;;
  *"/pulls/"*"/reviews"*) cat "$HW_REVIEWS" ;;
  *"/issues/"*"/comments"*) cat "$HW_COMMENTS" ;;
  *) echo "unknown gh args: $*" >&2; exit 1 ;;
esac
SH
chmod +x "$HW/gh"
jq --arg h "$CHEAD" '[.[0] | .commit_id = $h | .body = "**Actionable comments posted: 0**"]' \
  "$FIX/pr-reviews-cr-older-commit.json" > "$HW/cr-clean.json"
jq --arg h "$CHEAD" '[.[0] | .commit_id = $h]' "$FIX/pr-reviews-cr-older-commit.json" > "$HW/cr-findings.json"
jq --arg h "$CHEAD" '[.[0] | .commit_id = $h | .body = "<!-- This is an auto-generated comment: rate limited by coderabbit.ai -->\nReview rate limited"]' \
  "$FIX/pr-reviews-cr-older-commit.json" > "$HW/cr-rl.json"
mix() { jq -s 'add' "$@"; }
mix "$HW/cr-clean.json" "$FIX/pr-reviews-codex-prior-only.json" > "$HW/r-clean.json"
mix "$HW/cr-findings.json" "$FIX/pr-reviews-codex-prior-only.json" > "$HW/r-findings.json"
mix "$HW/cr-rl.json" "$FIX/pr-reviews-codex-prior-only.json" > "$HW/r-rl.json"
mix "$FIX/pr-reviews-cr-older-commit.json" "$FIX/pr-reviews-codex-prior-only.json" > "$HW/r-none.json"
mix "$FIX/issue-comments-cr-review-paused.json" "$FIX/issue-comments-codex-summary-completed.json" > "$HW/c-paused.json"
printf '[{"user":{"login":"YoungjaeDev"},"body":"@coderabbitai review","created_at":"2026-10-06T11:00:00Z"}]\n' > "$HW/req.json"
mix "$HW/c-paused.json" "$HW/req.json" > "$HW/c-paused-requested.json"
hw() { # REVIEWS COMMENTS [VAR=value ...]; one-shot unless CAP is given
  local r="$1" c="$2"; shift 2
  env HW_LOG="$HW_LOG" HW_REVIEWS="$r" HW_COMMENTS="$c" PATH="$HW:$PATH" \
    OWNER=o REPO=r PR_NUM=42 CUR_SHA="$CHEAD" PUSH_TIME=2026-10-06T10:00:00Z CAP=0 INTERVAL=1 "$@" \
    bash "$SCRIPTS/head-verdicts.sh" 2>/dev/null
}
hf() { jq -r "$1" <<<"$w" 2>/dev/null; }
w=$(hw "$HW/r-clean.json" "$FIX/issue-comments-codex-summary-completed.json")
is "both reviewers passed HEAD -> ready"            "$(hf .state)" ready
is "both passed -> no findings on HEAD"             "$(hf .findings)" false
w=$(hw "$HW/r-findings.json" "$FIX/issue-comments-codex-summary-completed.json")
is "CR findings on HEAD is a verdict -> ready"      "$(hf .state)" ready
is "CR findings on HEAD -> findings true"           "$(hf .findings)" true
# The minor_floor case: CR is done, Codex still Running on HEAD. Not ready, and
# with a budget left the wait keeps going (watchdog kill = 143).
w=$(hw "$HW/r-clean.json" "$FIX/issue-comments-codex-summary-running.json")
is "Codex Running on HEAD -> not ready (cap 0: timeout)" "$(hf .state)" timeout
is "Codex Running on HEAD -> codex in_progress"     "$(hf .codex)" in_progress
w=$(run_capped 3 env HW_LOG="$HW_LOG" HW_REVIEWS="$HW/r-clean.json" HW_COMMENTS="$FIX/issue-comments-codex-summary-running.json" \
      PATH="$HW:$PATH" OWNER=o REPO=r PR_NUM=42 CUR_SHA="$CHEAD" CAP=60 INTERVAL=1 \
      bash "$SCRIPTS/head-verdicts.sh" 2>/dev/null); rc=$?
is "Codex Running on HEAD with budget left -> keeps waiting" "$rc:$w" "143:"
# The wait stays inside the existing caps: an old push leaves the CR budget
# (TIMEOUT - age) at 0 and the Codex budget at CODEX_GRACE. Codex past its budget
# is dropped, never nudged (`@codex review` stays banned): CR's verdict decides.
w=$(run_capped 8 env HW_LOG="$HW_LOG" HW_REVIEWS="$HW/r-clean.json" HW_COMMENTS="$FIX/issue-comments-codex-summary-running.json" \
      PATH="$HW:$PATH" OWNER=o REPO=r PR_NUM=42 CUR_SHA="$CHEAD" PUSH_TIME=2020-01-01T00:00:00Z \
      TIMEOUT=1800 CODEX_GRACE=2 CODEX_PREFLIGHT_TIMEOUT=600 INTERVAL=1 \
      bash "$SCRIPTS/head-verdicts.sh" 2>/dev/null); rc=$?
is "Codex past its budget -> dropped, CR's verdict stands" "$rc:$(hf .state):$(hf '.dropped | join(",")')" 0:ready:codex
is "Codex dropped at its own budget from push time" "$(hf '.waited >= 2 and .waited <= 4')" true
# CodeRabbit silent (PR #315: 6 h, no status, no pause, no notice). The outer cap is
# TIMEOUT from the push or the first request: silent for half of it, CodeRabbit gets
# one `@coderabbitai review` for this HEAD (decided here, posted by the caller), and
# the nudge waits only in what is left of that cap.
hago() { jq -nr --argjson s "$1" 'now - $s | strftime("%Y-%m-%dT%H:%M:%SZ")'; }
p6=$(hago 6)
: > "$HW_LOG"
w=$(hw "$HW/r-none.json" "$FIX/issue-comments-codex-summary-completed.json" CAP= TIMEOUT=10 PUSH_TIME="$p6")
is "CR silent half its budget -> stuck at once, nudge decided" "$(hf .state):$(hf .cr_review_request):$(hf '.waited <= 3')" stuck:post:true
is "stuck reports the outer CR deadline (push + TIMEOUT)" \
   "$(hf .cr_deadline)" "$(jq -n --arg t "$p6" '$t | fromdateiso8601 + 10 | floor')"
is "stuck: the script decides, it never posts" \
   "$(grep -cE -- '(-X|--method) *(POST|PATCH|PUT|DELETE)|(^| )(-f|-F|--field|--raw-field) |(pr|issue) comment' "$HW_LOG")" 0
cr_dl=$(hf .cr_deadline)
jq -n --arg t "$(hago 0)" '[{"user":{"login":"YoungjaeDev"},"body":"@coderabbitai review","created_at":$t}]' > "$HW/req-now.json"
mix "$FIX/issue-comments-codex-summary-completed.json" "$HW/req-now.json" > "$HW/c-nudged.json"
w=$(run_capped 9 env HW_LOG="$HW_LOG" HW_REVIEWS="$HW/r-none.json" HW_COMMENTS="$HW/c-nudged.json" \
      PATH="$HW:$PATH" OWNER=o REPO=r PR_NUM=42 CUR_SHA="$CHEAD" PUSH_TIME="$p6" \
      TIMEOUT=10 INTERVAL=1 CR_DEADLINE="$cr_dl" bash "$SCRIPTS/head-verdicts.sh" 2>/dev/null); rc=$?
is "after the nudge the wait ends at the outer deadline, not TIMEOUT from the request" \
   "$rc:$(hf .state):$(hf '.dropped | join(",")')" 0:ready:coderabbit
# A run that starts after the cap ran out has nothing left to nudge with: dropped.
w=$(hw "$HW/r-none.json" "$FIX/issue-comments-codex-summary-completed.json" CAP=)
is "CR silent, cap already spent -> dropped without a nudge" \
   "$(hf .state):$(hf .cr_review_request):$(hf '.dropped | join(",")')" ready:null:coderabbit
# A nudge check that cannot read the PR comments is not "already nudged": CodeRabbit
# is not dropped, and HEAD is left without its verdict.
HWS=$(mktemp -d); cp -R "$SCRIPTS/." "$HWS/"; printf '#!/usr/bin/env bash\nexit 1\n' > "$HWS/cr-review-posted.sh"
# Past half the cap with 8 s left, so a slow process start (Git Bash on Windows) still reaches
# the nudge check before the cap runs out.
w=$(run_capped 15 env HW_LOG="$HW_LOG" HW_REVIEWS="$HW/r-none.json" HW_COMMENTS="$FIX/issue-comments-codex-summary-completed.json" \
      PATH="$HW:$PATH" OWNER=o REPO=r PR_NUM=42 CUR_SHA="$CHEAD" PUSH_TIME="$(hago 12)" \
      TIMEOUT=20 INTERVAL=1 bash "$HWS/head-verdicts.sh" 2>/dev/null); rc=$?
is "nudge check unreadable -> CR not dropped, HEAD unjudged" \
   "$rc:$(hf .state):$(hf .cr):$(hf '.dropped | length')" 0:timeout:error:0
rm -rf "$HWS"
mix "$FIX/issue-comments-codex-summary-completed.json" "$HW/req.json" > "$HW/c-codex-requested.json"
w=$(hw "$HW/r-none.json" "$HW/c-codex-requested.json" CAP=)
is "CR silent after this HEAD's request -> dropped, Codex's verdict stands" \
   "$(hf .state):$(hf '.dropped | join(",")'):$(hf .codex)" ready:coderabbit:clean
mix "$FIX/issue-comments-codex-summary-running.json" "$HW/req.json" > "$HW/c-running-requested.json"
w=$(hw "$HW/r-none.json" "$HW/c-running-requested.json" CAP= CODEX_GRACE=0)
is "every reviewer past its budget -> timeout, nobody dropped" "$(hf .state):$(hf '.dropped | length')" timeout:0
# A reviewer that cannot be read is not stuck: it is never dropped.
w=$(hw "$HW/missing.json" "$FIX/issue-comments-codex-summary-completed.json" CAP= CODEX_GRACE=0)
is "unreadable reviewers past budget -> timeout, nobody dropped" "$(hf .state):$(hf '.dropped | length')" timeout:0
# CodeRabbit unreadable past its deadline while Codex still works: the next look waits
# for Codex's deadline, not a negative `left` clamped to a 1 s poll (PR #334).
HWS=$(mktemp -d); cp -R "$SCRIPTS/." "$HWS/"; printf '#!/usr/bin/env bash\nexit 1\n' > "$HWS/cr-head-verdict.sh"
: > "$HW_LOG"
run_capped 4 env HW_LOG="$HW_LOG" HW_REVIEWS="$HW/r-clean.json" HW_COMMENTS="$FIX/issue-comments-codex-summary-running.json" \
  PATH="$HW:$PATH" OWNER=o REPO=r PR_NUM=42 CUR_SHA="$CHEAD" PUSH_TIME=2020-01-01T00:00:00Z \
  TIMEOUT=1800 INTERVAL=30 bash "$HWS/head-verdicts.sh" >/dev/null 2>&1
is "CR error past its deadline -> no 1 s polling while Codex works" "$(grep -c '/pulls/' "$HW_LOG")" 1
rm -rf "$HWS"
# A `@coderabbitai review` posted long after the push starts CodeRabbit's work
# then: its budget runs from the newer of the push and the request comment's
# server time, or an old push leaves it nothing to wait with (issue #297).
jq -n --arg t "$(jq -nr 'now - 100 | strftime("%Y-%m-%dT%H:%M:%SZ")')" \
  '[{"user":{"login":"YoungjaeDev"},"body":" @coderabbitai review\n","created_at":$t}]' > "$HW/req-recent.json"
mix "$FIX/issue-comments-codex-summary-completed.json" "$HW/req-recent.json" > "$HW/c-requested-late.json"
w=$(run_capped 3 env HW_LOG="$HW_LOG" HW_REVIEWS="$HW/r-none.json" HW_COMMENTS="$HW/c-requested-late.json" \
      PATH="$HW:$PATH" OWNER=o REPO=r PR_NUM=42 CUR_SHA="$CHEAD" PUSH_TIME=2020-01-01T00:00:00Z \
      TIMEOUT=1800 INTERVAL=1 bash "$SCRIPTS/head-verdicts.sh" 2>/dev/null); rc=$?
is "old push, request 100s ago -> CR budget from the request (keeps waiting)" "$rc:$w" "143:"
# Comments that cannot be read hide any request: the anchor is unknown, so the
# budget is the full TIMEOUT, never a spent one read off the old push.
w=$(run_capped 3 env HW_LOG="$HW_LOG" HW_REVIEWS="$HW/r-none.json" HW_COMMENTS="$HW/missing.json" \
      PATH="$HW:$PATH" OWNER=o REPO=r PR_NUM=42 CUR_SHA="$CHEAD" PUSH_TIME=2020-01-01T00:00:00Z \
      CODEX_ON=false TIMEOUT=1800 INTERVAL=1 bash "$SCRIPTS/head-verdicts.sh" 2>/dev/null); rc=$?
is "old push, comments unreadable -> full CR budget (keeps waiting)" "$rc:$w" "143:"
w=$(hw "$HW/r-clean.json" "$FIX/issue-comments-codex-summary-failed.json")
is "Codex Failed on HEAD -> codex_failed"           "$(hf .state)" codex_failed
# No CR review on HEAD (the success status alone is no verdict), or only a
# rate-limit notice on it: not ready.
w=$(hw "$HW/r-none.json" "$FIX/issue-comments-codex-summary-completed.json")
is "no CR review on HEAD -> not ready"              "$(hf .state):$(hf .cr)" timeout:none
w=$(hw "$HW/r-rl.json" "$FIX/issue-comments-codex-summary-completed.json")
is "rate-limit notice only on HEAD -> not ready"    "$(hf .state):$(hf .cr)" timeout:none
# CodeRabbit paused automatic reviews (auto_pause_after_reviewed_commits): ask once per HEAD.
: > "$HW_LOG"
w=$(hw "$HW/r-none.json" "$HW/c-paused.json")
is "review pause notice -> paused, request decided" "$(hf .state):$(hf .cr_review_request)" paused:post
is "the script decides, it never posts" \
   "$(grep -cE -- '(-X|--method) *(POST|PATCH|PUT|DELETE)|(^| )(-f|-F|--field|--raw-field) |(pr|issue) comment' "$HW_LOG")" 0
w=$(hw "$HW/r-none.json" "$HW/c-paused-requested.json")
is "pause, already requested on this HEAD -> no second request" "$(hf .state):$(hf .cr_review_request)" timeout:skip
# No push time: this HEAD's request cannot be told from an older one, so no request
# is decided (request_cr_review, reading the same push time, would not post either).
w=$(hw "$HW/r-none.json" "$HW/c-paused.json" PUSH_TIME=)
is "pause, push time unknown -> no request decided" "$(hf .state):$(hf .cr_review_request)" timeout:null
# Reviewers that are off do not hold the loop.
echo '[]' > "$HW/empty.json"
w=$(hw "$HW/cr-clean.json" "$HW/empty.json" CODEX_ON=auto)
is "Codex never engaged on the PR -> off, CR clean -> ready" "$(hf .state):$(hf .codex)" ready:off
# Codex whose only possible verdict (a 👍, which the state marker on HEAD would let
# count) cannot be read is not dropped (#328).
w=$(hw "$HW/r-clean.json" "$FIX/issue-comments-codex-summary-state-head.json" CAP= CODEX_ON=true CODEX_GRACE=0 HW_RXN=__FAIL__)
is "Codex reactions unreadable past its budget -> not dropped, timeout" \
   "$(hf .state):$(hf '.dropped | length'):$(hf .codex)" timeout:0:error
w=$(hw "$HW/r-clean.json" "$FIX/issue-comments-codex-summary-running.json" CODEX_ON=false)
is "CODEX_ON=false -> Codex not waited for"         "$(hf .state):$(hf .codex)" ready:off
w=$(hw "$HW/r-none.json" "$FIX/issue-comments-codex-summary-completed.json" CR_ON=false)
is "CR_ON=false (cli / codex-only) -> CR not waited for" "$(hf .state):$(hf .cr)" ready:off
rm -rf "$HW"

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

# The poller keeps its own deadline: run in the background, no harness timeout
# stops it, and PR #315's poll ran 6 h past TIMEOUT=1800. CR silent throughout; a
# sleep longer than the time left is cut to it (watchdog kill would be 143).
DLSHIM=$(mktemp -d)
cat > "$DLSHIM/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"/check-runs"*) echo '{"check_runs":[]}' ;;
  *) echo '[]' ;;
esac
SH
chmod +x "$DLSHIM/gh"
dl=$(run_capped 10 env PATH="$DLSHIM:$PATH" OWNER=o REPO=r SHA=s PR_NUM=42 INTERVAL=30 TIMEOUT=2 \
  EARLY_CHECK_WINDOW=999 PUSH_TIME=2020-01-01T00:00:00Z bash "$SCRIPTS/poll-cr-status.sh" 2>/dev/null); dl_rc=$?
is "poll-cr-status: CR silent past TIMEOUT -> own timeout line, exit 124" "$dl_rc:$(jq -r '.state' <<<"$dl" 2>/dev/null)" 124:timeout
# Same for the Codex grace poll: CAP is its deadline, the grace-expiry branch (no line).
dl=$(run_capped 10 env PATH="$DLSHIM:$PATH" OWNER=o REPO=r PR_NUM=42 PROCESSED='[]' INTERVAL=30 CAP=2 \
  bash "$SCRIPTS/poll-codex-grace.sh" 2>/dev/null); dl_rc=$?
is "poll-codex-grace: no review by CAP -> exits 124, no line" "$dl_rc:$dl" "124:"

# Every poller picks its next look with next-check.sh, as head-verdicts.sh does: soon
# while the reviewer is at work, not before Codex's fastest turnaround, backed off past
# its slowest. A PATH `sleep` logs the first nap and ends the poller (no real wait).
NAP=$(mktemp -d)
cat > "$NAP/sleep" <<'SH'
#!/usr/bin/env bash
echo "$1" >> "$NAP_LOG"; kill -TERM "$PPID" 2>/dev/null; exit 0
SH
chmod +x "$NAP/sleep"
first_nap() { # VAR=value... CMD...: the first sleep the command asks for
  : > "$NAP/log"
  run_capped 10 env PATH="$NAP:$PATH" NAP_LOG="$NAP/log" "$@" >/dev/null 2>&1
  head -1 "$NAP/log"
}
ago() { jq -nr --argjson s "$1" 'now - $s | strftime("%Y-%m-%dT%H:%M:%SZ")'; }
cat > "$NAP/gh-pending" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"/statuses"*) echo '[{"context":"CodeRabbit","state":"pending","description":"Review in progress","created_at":"2026-10-06T10:00:00Z"}]' ;;
  *"/check-runs"*) echo '{"check_runs":[]}' ;;
  *) echo '[]' ;;
esac
SH
mkdir -p "$NAP/pend"; mv "$NAP/gh-pending" "$NAP/pend/gh"; chmod +x "$NAP/pend/gh"
pcs() { first_nap PATH="$1:$NAP:$PATH" OWNER=o REPO=r SHA=s PR_NUM=42 INTERVAL=30 TIMEOUT=1800 \
  EARLY_CHECK_WINDOW=999 PUSH_TIME="$2" bash "$SCRIPTS/poll-cr-status.sh"; }
is "poll-cr-status: CodeRabbit pending -> a third of INTERVAL" "$(pcs "$NAP/pend" "$(ago 300)")" 10
n=$(pcs "$DLSHIM" "$(ago 20)")
is "poll-cr-status: push 20 s old, nothing seen -> until 68 s" "$([ "${n:-0}" -ge 46 ] && [ "${n:-0}" -le 48 ] && echo yes || echo "no ($n)")" yes
is "poll-cr-status: past the slowest turnaround -> 2 x INTERVAL" "$(pcs "$DLSHIM" 2020-01-01T00:00:00Z)" 60
pcg() { first_nap PATH="$DLSHIM:$NAP:$PATH" OWNER=o REPO=r PR_NUM=42 PROCESSED='[]' INTERVAL=15 CAP=600 "$@" \
  bash "$SCRIPTS/poll-codex-grace.sh"; }
is "poll-codex-grace: past the slowest turnaround -> 2 x INTERVAL" "$(pcg PUSH_TIME=2020-01-01T00:00:00Z)" 30
is "poll-codex-grace: push time unknown -> INTERVAL"              "$(pcg)" 15
cat > "$NAP/run-gh" <<SH
#!/usr/bin/env bash
case "\$*" in
  *"/issues/"*"/reactions"*) echo '[]' ;;
  *"/issues/"*"/comments"*) cat "$FIX/issue-comments-codex-summary-running.json" ;;
  *"/pulls/"*"/reviews"*)   cat "$FIX/pr-reviews-codex-prior-only.json" ;;
  *) exit 1 ;;
esac
SH
mkdir -p "$NAP/run"; mv "$NAP/run-gh" "$NAP/run/gh"; chmod +x "$NAP/run/gh"
is "poll-codex-grace: Codex Running on HEAD -> a third of INTERVAL" \
   "$(first_nap PATH="$NAP/run:$NAP:$PATH" OWNER=o REPO=r PR_NUM=42 PROCESSED='[5426830676]' INTERVAL=15 CAP=600 \
      CUR_SHA="$CHEAD" PUSH_TIME="$(ago 300)" bash "$SCRIPTS/poll-codex-grace.sh")" 5
cat > "$NAP/ci-gh" <<SH
#!/usr/bin/env bash
cat "$FIX/pr-checks-pending.json"
SH
mkdir -p "$NAP/ci"; mv "$NAP/ci-gh" "$NAP/ci/gh"; chmod +x "$NAP/ci/gh"
is "ci-checks: pending past the slowest turnaround -> 2 x INTERVAL" \
   "$(first_nap PATH="$NAP/ci:$NAP:$PATH" CAP=600 INTERVAL=30 PUSH_TIME=2020-01-01T00:00:00Z bash "$SCRIPTS/ci-checks.sh" 42)" 60
n=$(first_nap PATH="$NAP/ci:$NAP:$PATH" CAP=7 INTERVAL=30 PUSH_TIME=2020-01-01T00:00:00Z bash "$SCRIPTS/ci-checks.sh" 42)
is "ci-checks: never past CAP" "$([ "${n:-0}" -ge 6 ] && [ "${n:-0}" -le 7 ] && echo yes || echo "no ($n)")" yes
rm -rf "$DLSHIM" "$NAP"

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

# The documented "Review rate limited" passing check (PR #283) carries none of the
# sniffer's comment phrasings, so the gate must come from the state itself.
cat > "$FSHIM/gh" <<SH
#!/usr/bin/env bash
case "\$*" in
  *"/statuses"*) cat "$FIX/statuses-cr-review-rate-limited.json" ;;
  *"/check-runs"*) echo '{"check_runs":[]}' ;;
  *"/issues/"*"/comments"*) echo '[]' ;;
  *"/pulls/"*"/reviews"*) echo '[]' ;;
  *"/pulls/"*) echo '{"head":{"sha":"deadbeef"}}' ;;
  *) echo "unknown gh args: \$*" >&2; exit 1 ;;
esac
SH
pfr=$(PATH="$FSHIM:$PATH" NO_CODEX=true OWNER=o REPO=r PR_NUM=42 CUR_SHA=s \
  PUSH_TIME=2020-01-01T00:00:00Z STATE_FILE="$FST" \
  bash "$SCRIPTS/pre-flight.sh" 2>/dev/null)
is "'Review rate limited' success -> gate rate_limited" "$(jq -r '.gate' <<<"$pfr" 2>/dev/null)" rate_limited
is "'Review rate limited' success -> cr_state rate_limited" "$(jq -r '.cr_state' <<<"$pfr" 2>/dev/null)" rate_limited
is "'Review rate limited' success -> not actionable" "$(jq -r '.cr_actionable' <<<"$pfr" 2>/dev/null)" false

# Same row on the background poller: it emitted `success` straight from the
# terminal branch, which Step 6b read as a finished review.
rlp=$(PATH="$FSHIM:$PATH" OWNER=o REPO=r SHA=s PR_NUM=42 INTERVAL=0 \
  EARLY_CHECK_WINDOW=0 PUSH_TIME=2020-01-01T00:00:00Z \
  run_capped 10 bash "$SCRIPTS/poll-cr-status.sh" 2>/dev/null) || true
is "poll: 'Review rate limited' success -> rate_limited" "$(jq -r '.state' <<<"$rlp" 2>/dev/null)" rate_limited
rm -rf "$FSHIM"

# Codex HEAD verdict inside pre-flight (codex-head-verdict.sh). CR_ROW picks the
# CodeRabbit status row: success | pending | ratelimited.
pfv() { # CR_ROW COMMENTS_FIXTURE REVIEWS_FIXTURE [VAR=value ...]
  local row="$1" c="$2" r="$3"; shift 3
  # Prior-SHA reviews in the fixtures were handled on earlier iterations.
  local d; d=$(mktemp -d); echo '{"codex_processed_reviews":[555,5426830676]}' > "$d/state.json"
  local st='[{"context":"CodeRabbit","state":"success","description":"Review completed","target_url":"","created_at":"2020-01-01T00:00:00Z"}]'
  [ "$row" = pending ] && st='[{"context":"CodeRabbit","state":"pending","description":"Review in progress","target_url":"","created_at":"2020-01-01T00:00:00Z"}]'
  [ "$row" = ratelimited ] && st='[{"context":"CodeRabbit","state":"success","description":"Review limit reached","target_url":"","created_at":"2020-01-01T00:00:00Z"}]'
  cat > "$d/gh" <<SH
#!/usr/bin/env bash
case "\$*" in
  *"/statuses"*) echo '$st' ;;
  *"/check-runs"*) echo '{"check_runs":[]}' ;;
  *"/issues/"*"/comments"*) cat "$FIX/$c" ;;
  *"/issues/"*"/reactions"*) echo '[]' ;;
  *"/pulls/"*"/reviews"*) cat "$FIX/$r" ;;
  *"/pulls/"*) echo '{"head":{"sha":"$CHEAD"}}' ;;
  *) echo "unknown gh args: \$*" >&2; exit 1 ;;
esac
SH
  chmod +x "$d/gh"
  env PATH="$d:$PATH" OWNER=o REPO=r PR_NUM=42 CUR_SHA="$CHEAD" \
    PUSH_TIME=2020-01-01T00:00:00Z STATE_FILE="$d/state.json" CODEX_GRACE=30 "$@" \
    bash "$SCRIPTS/pre-flight.sh" 2>/dev/null
  rm -rf "$d"
}
pg() { jq -r "$1" <<<"$pf" 2>/dev/null; }

# Running on HEAD long past the timeout: the old timeout path called this clean.
pf=$(pfv success issue-comments-codex-summary-running.json pr-reviews-codex-prior-only.json)
is "pre-flight: Running on HEAD past timeout -> codex_wait, not proceed" "$(pg .gate)" codex_wait
is "pre-flight: Running on HEAD -> codex_verdict in_progress"          "$(pg .codex_verdict)" in_progress

# Completed without a HEAD review: Codex passed HEAD.
pf=$(pfv success issue-comments-codex-summary-completed.json pr-reviews-codex-none.json)
is "pre-flight: Completed clean on HEAD -> proceed"                    "$(pg .gate)" proceed
is "pre-flight: Completed clean on HEAD -> codex_state clean"          "$(pg .codex_state)" clean

# Unparseable summary is never clean, even past the timeout.
pf=$(pfv success issue-comments-codex-summary-unparseable.json pr-reviews-codex-none.json)
is "pre-flight: unparseable summary -> codex_wait (review-id poll)"    "$(pg .gate)" codex_wait
is "pre-flight: unparseable summary -> codex_state arriving"           "$(pg .codex_state)" arriving

# Completed on a previous SHA: Codex has not judged HEAD -> not clean.
pf=$(pfv success issue-comments-codex-summary-stale-sha.json pr-reviews-codex-prior-only.json)
is "pre-flight: summary on another SHA -> codex_wait"                  "$(pg .gate)" codex_wait

# The Codex wait budget is one formula whatever the gate.
recent=$(jq -nr 'now - 100 | strftime("%Y-%m-%dT%H:%M:%SZ")')
waits=""
for row in success pending ratelimited; do
  pf=$(pfv "$row" issue-comments-codex-summary-running.json pr-reviews-codex-prior-only.json \
         PUSH_TIME="$recent" CODEX_PREFLIGHT_TIMEOUT=600)
  # The floor allows for slow process start-up (Git Bash on Windows spends seconds per row).
  waits="$waits $(pg .gate):$(pg '.codex_wait_seconds >= 470 and .codex_wait_seconds <= 500')"
done
is "pre-flight: every gate carries the same Codex wait budget" \
   "$waits" " codex_wait:true cr_wait:true rate_limited:true"
pf=$(pfv success issue-comments-codex-summary-completed.json pr-reviews-codex-none.json \
       PUSH_TIME="$recent" CODEX_PREFLIGHT_TIMEOUT=600)
is "pre-flight: proceed gate carries the same Codex wait budget" \
   "$(pg '.gate + ":" + (.codex_wait_seconds >= 470 and .codex_wait_seconds <= 500 | tostring)')" "proceed:true"
# The default budget sits above the slowest Codex turnaround ADR 0002 measured (726 s).
pf=$(pfv success issue-comments-codex-summary-running.json pr-reviews-codex-prior-only.json PUSH_TIME="$(jq -nr 'now | strftime("%Y-%m-%dT%H:%M:%SZ")')")
is "pre-flight: default Codex budget is above the slowest turnaround" "$(pg '.codex_wait_seconds > 726')" true

# Codex Failed on HEAD (decision 16): no review is coming, and the loop never asks
# for one, so it stops at codex_failed without writing to the PR. Every gh call on
# the path is logged; none may be a write.
CFD=$(mktemp -d); GH_LOG="$CFD/gh.log"; : > "$GH_LOG"
pf=$(GH_LOG="$GH_LOG" pfv success issue-comments-codex-summary-failed.json pr-reviews-codex-prior-only.json)
is "pre-flight: Failed on HEAD -> codex_verdict failed" "$(pg .codex_verdict)" failed
# Step 5 codex_failed stop. Mirrors the Step 5 block in references/run-blocks.md.
cf_stop() {
  PF="$1" bash -c 'for ITER in 1 2; do pf=$PF; final_state=""
    codex_verdict_pf=$(jq -r ".codex_verdict // empty" <<<"$pf")
    if [ "$codex_verdict_pf" = failed ]; then final_state=codex_failed; break; fi
    final_state=looped; done; printf %s "$final_state"'
}
cf_final=$(cf_stop "$pf")
is "loop: Failed on HEAD -> final_state codex_failed" "$cf_final" codex_failed
is "loop: Running on HEAD -> keeps going" \
   "$(cf_stop "$(pfv success issue-comments-codex-summary-running.json pr-reviews-codex-prior-only.json)")" looped
# Minimal draft-07 check of what the schema states: required keys, no extra keys, enums.
schema_ok() {
  jq -n --argjson o "$1" --slurpfile s "$HERE/../assets/final-output.schema.json" '$s[0] as $s
    | (($s.required - ($o | keys)) == [])
      and ((($o | keys) - ($s.properties | keys)) == [])
      and all($s.properties | to_entries[]; .key as $k | (.value.enum // null) as $e
              | $e == null or ($o | has($k) | not) or ($e | index($o[$k])) != null)'
}
fo=$(FINAL_STATE="$cf_final" PR_NUM=42 LAST_SHA="$CHEAD" bash "$SCRIPTS/emit-final-json.sh" 2>/dev/null)
is "final output: codex_failed passes the schema" "$(schema_ok "$fo")" true
is "final output: final_state codex_failed"       "$(jq -r '.final_state' <<<"$fo")" codex_failed
is "schema check rejects an unlisted final_state" "$(schema_ok "$(jq -c '.final_state="bogus"' <<<"$fo")")" false
is "final output: no CI failure -> empty ci_failing_checks" "$(jq -c '.ci_failing_checks' <<<"$fo")" '[]'
fo=$(FINAL_STATE=ci_failing CI_FAILING_CHECKS='["policy"]' PR_NUM=42 LAST_SHA="$CHEAD" bash "$SCRIPTS/emit-final-json.sh" 2>/dev/null)
is "final output: ci_failing passes the schema"   "$(schema_ok "$fo")" true
is "final output: ci_failing_checks carried"      "$(jq -c '.ci_failing_checks' <<<"$fo")" '["policy"]'
is "final output: verdicts complete -> head_verdict null" "$(jq -c '.head_verdict' <<<"$fo")" null
# A HEAD left without every verdict files no issue (#327); the final output says so.
fo=$(FINAL_STATE=minor_floor HEAD_VERDICT=timeout PR_NUM=42 LAST_SHA="$CHEAD" bash "$SCRIPTS/emit-final-json.sh" 2>/dev/null)
is "final output: unverified HEAD reported"       "$(jq -r '.head_verdict' <<<"$fo")" timeout
is "final output: head_verdict passes the schema" "$(schema_ok "$fo")" true
# The Minor fixes pushed straight to the base after the merge (merge_then_main_push).
BPS=$(mktemp -d); mkdir -p "$BPS/s"
echo '{"base_push":{"branch":"main","sha":"abc","fixes":[{"src":"cr","path":"a.sh","line":3,"badge_or_sev":"🟡 Minor"}]}}' > "$BPS/s/st.json"
fo=$(FINAL_STATE=minor_floor MERGED=true STATE_FILE="$BPS/s/st.json" PR_NUM=42 LAST_SHA="$CHEAD" bash "$SCRIPTS/emit-final-json.sh" 2>/dev/null)
is "final output: base push carried"              "$(jq -r '.base_push.fixes[0].path' <<<"$fo")" a.sh
is "final output: base_push passes the schema"    "$(schema_ok "$fo")" true
# The runner's line is also a file next to the state, so the main session reads it
# on any wake instead of waiting on a completion notification.
is "final output: written to the state dir too"   "$(cat "$BPS/s/review-loop-final-42.json" 2>/dev/null)" "$fo"
fo=$(FINAL_STATE=minor_floor DROPPED_REVIEWERS="coderabbit" CR_BASE_REQUESTED=integration/322 \
  PENDING_DECISION='{"question":"merge","pr":42,"base":"main","protection_http":404}' PR_NUM=42 LAST_SHA="$CHEAD" \
  bash "$SCRIPTS/emit-final-json.sh" 2>/dev/null)
is "final output: dropped reviewers listed"       "$(jq -c '.dropped_reviewers' <<<"$fo")" '["coderabbit"]'
is "final output: non-default base request named" "$(jq -r '.cr_review_requested_base' <<<"$fo")" integration/322
is "final output: pending decision carried"       "$(jq -r '.pending_decision.question' <<<"$fo")" merge
is "final output: new fields pass the schema"     "$(schema_ok "$fo")" true
fo=$(FINAL_STATE=clean PENDING_DECISION='not json' PR_NUM=42 LAST_SHA="$CHEAD" bash "$SCRIPTS/emit-final-json.sh" 2>/dev/null)
is "final output: defaults -> [] / null / null" \
   "$(jq -c '[.dropped_reviewers, .cr_review_requested_base, .pending_decision]' <<<"$fo")" '[[],null,null]'
# dropped_reviewers is one shell word list read by one helper (words-json.sh): the gate,
# the final output and the runner's merge question cannot parse it three ways.
fo=$(FINAL_STATE=clean DROPPED_REVIEWERS=$'coderabbit\n\tcodex ' PR_NUM=42 LAST_SHA="$CHEAD" bash "$SCRIPTS/emit-final-json.sh" 2>/dev/null)
is "final output: any whitespace separates dropped reviewers" "$(jq -c '.dropped_reviewers' <<<"$fo")" '["coderabbit","codex"]'
is "dropped reviewers are split in one helper only" \
   "$(grep -lF 'split(" ")' "$SCRIPTS"/*.sh "$HERE/../references/run-blocks.md" | while read -r f; do basename "$f"; done | tr '\n' ' ')" ""
rm -rf "$BPS"
cat > "$CFD/gh" <<SH
#!/usr/bin/env bash
echo "\$*" >> "$GH_LOG"
case "\$*" in
  *"/check-runs"*) echo '{"check_runs":[{"name":"CodeRabbit","status":"completed","conclusion":"success","started_at":"2025-01-01T00:00:00Z"}]}';;
  *"/statuses"*)   echo '[]';;
  "pr checks"*)    echo '[]';;
  "pr view"*)      echo "main";;
  *"/protection"*) echo "HTTP/2.0 200 OK";;
  *) echo "unknown gh args: \$*" >&2; exit 1;;
esac
SH
chmod +x "$CFD/gh"
g=$(FINAL_STATE="$cf_final" PATH="$CFD:$PATH" bash "$SCRIPTS/auto-merge-gate.sh" o r 42 "$CHEAD" 2>/dev/null)
is "auto-merge: codex_failed -> ineligible"       "$(jq -r '.eligible' <<<"$g")" false
is "auto-merge: codex_failed reason names Codex"  "$(jq -r '.ineligible_reason | test("Codex.*Failed")' <<<"$g")" true
is "codex_failed path: gh was called"             "$([ -s "$GH_LOG" ] && echo yes)" yes
is "codex_failed path: no PR write" \
   "$(grep -cE -- '(-X|--method) *(POST|PATCH|PUT|DELETE)|(^| )(-f|-F|--field|--raw-field) |(pr|issue) (comment|review|edit)' "$GH_LOG")" 0
rm -rf "$CFD"; unset GH_LOG

echo
echo "SKILL.md snippet contracts (mirror SKILL.md and references/run-blocks.md blocks)"

# Step 2 archive fallback: the EXIT trap archives the live state, so the next run
# must read codex_processed_reviews from the newest archive or re-process Codex
# reviews. Mirrors the Step 2 state-init block in references/run-blocks.md. (issue #110 step 3)
AF=$(mktemp -d); mkdir -p "$AF/.claude/state/archive"
echo '{"codex_processed_reviews":[111,222]}' > "$AF/.claude/state/archive/review-loop-42-20260101-000000.json"
echo '{"codex_processed_reviews":[333]}'     > "$AF/.claude/state/archive/review-loop-42-20260102-000000.json"
# touch -t (POSIX) — `-d` is GNU-only and breaks the suite on macOS/BSD.
touch -t 202601010000 "$AF/.claude/state/archive/review-loop-42-20260101-000000.json"
touch -t 202601020000 "$AF/.claude/state/archive/review-loop-42-20260102-000000.json"
af_got=$(cd "$AF" && PR_NUM=42
  PRIOR_STATE=".claude/state/review-loop-${PR_NUM}.json"
  [ -f "$PRIOR_STATE" ] || PRIOR_STATE=$(ls -1t ".claude/state/archive/review-loop-${PR_NUM}-"*.json 2>/dev/null | head -1)
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
  PRIOR_STATE=".claude/state/review-loop-${PR_NUM}.json"
  [ -f "$PRIOR_STATE" ] || PRIOR_STATE=$(ls -1t ".claude/state/archive/review-loop-${PR_NUM}-"*.json 2>/dev/null | head -1 || true)
') || arc=$?
is "archive fallback: no archive survives errexit" "$arc" 0
rm -rf "$AF2"

# Corrupt prior state must ABORT before the new state file is created — a
# warn-and-continue reset re-judges already-processed Codex reviews and can
# re-apply fixes onto already-fixed code. Mirrors the Step 2 state-init block in references/run-blocks.md.
AF3=$(mktemp -d); mkdir -p "$AF3/.claude/state/archive"
echo 'not-json{' > "$AF3/.claude/state/review-loop-44.json"
crc=0; (cd "$AF3" && bash -c '
  PR_NUM=44
  PRIOR_STATE=".claude/state/review-loop-${PR_NUM}.json"
  [ -f "$PRIOR_STATE" ] || PRIOR_STATE=$(ls -1t ".claude/state/archive/review-loop-${PR_NUM}-"*.json 2>/dev/null | head -1 || true)
  if [ -n "$PRIOR_STATE" ] && [ -f "$PRIOR_STATE" ]; then
    PRIOR_PROCESSED=$(jq -c ".codex_processed_reviews // []" "$PRIOR_STATE" 2>/dev/null) || {
      echo "review-loop: prior state $PRIOR_STATE unparseable — aborting before the Codex dedupe is reset" >&2
      exit 1
    }
  fi' 2>/dev/null) || crc=$?
is "corrupt prior state -> aborts rc 1" "$crc" 1
rm -rf "$AF3"

# Step 1 SKILL_DIR resolver: CLAUDE_PLUGIN_ROOT wins, and the Codex cache is the
# fallback outside the source tree. Mirrors the SKILL.md Step 1 resolver. (step 7)
RS=$(mktemp -d)
mkdir -p "$RS/pluginroot/skills/review-loop" "$RS/cache/marketplace/dev/2.8.0/skills/review-loop"
cat > "$RS/resolver.sh" <<'SH'
CACHE_ROOT="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
if sort -V </dev/null >/dev/null 2>&1; then
  CODEX_CAND=$(ls -1d "$CACHE_ROOT"/*/dev/* 2>/dev/null \
    | awk -F/ '{print $NF "\t" $(0)}' | sort -V | tail -1 | cut -f2- || true)
else
  CODEX_CAND=$(ls -1d "$CACHE_ROOT"/*/dev/* 2>/dev/null \
    | awk -F/ '{print $NF "\t" $(0)}' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1 | cut -f2- || true)
fi
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "$CLAUDE_PLUGIN_ROOT/skills/review-loop" ]; then SKILL_DIR="$CLAUDE_PLUGIN_ROOT/skills/review-loop"
elif [ -d "plugins/dev/skills/review-loop" ]; then SKILL_DIR="plugins/dev/skills/review-loop"
elif [ -n "$CODEX_CAND" ] && [ -d "$CODEX_CAND/skills/review-loop" ]; then SKILL_DIR="$CODEX_CAND/skills/review-loop"
else SKILL_DIR="plugins/dev/skills/review-loop"; fi
printf '%s' "$SKILL_DIR"
SH
# From a non-source-tree cwd so the source-tree branch cannot win.
got=$(cd "$RS" && CLAUDE_PLUGIN_ROOT="$RS/pluginroot" CODEX_PLUGIN_CACHE="$RS/cache" bash resolver.sh)
is "resolver: CLAUDE_PLUGIN_ROOT wins" "$got" "$RS/pluginroot/skills/review-loop"
got=$(cd "$RS" && CLAUDE_PLUGIN_ROOT="" CODEX_PLUGIN_CACHE="$RS/cache" bash resolver.sh)
is "resolver: Codex cache fallback"    "$got" "$RS/cache/marketplace/dev/2.8.0/skills/review-loop"

# Multi-marketplace cache: the VERSION must win, not the marketplace dir name.
# The old full-path sort -V let zeta/dev/2.10.0 outrank
# alpha/dev/3.0.0. (CR Major, SKILL.md:66)
mkdir -p "$RS/cache2/zeta/dev/2.10.0/skills/review-loop" \
         "$RS/cache2/alpha/dev/3.0.0/skills/review-loop"
got=$(cd "$RS" && CLAUDE_PLUGIN_ROOT="" CODEX_PLUGIN_CACHE="$RS/cache2" bash resolver.sh)
is "resolver: version outranks marketplace name" "$got" "$RS/cache2/alpha/dev/3.0.0/skills/review-loop"

# Fresh env (no cache at all) must not kill an errexit caller — the unguarded
# CODEX_CAND ls substitution died rc=2 under set -euo pipefail. (counsel P1)
rrc=0; (cd "$RS" && CLAUDE_PLUGIN_ROOT="" CODEX_PLUGIN_CACHE="$RS/no-such-cache" \
  bash -euo pipefail resolver.sh >/dev/null) || rrc=$?
is "resolver: empty cache survives errexit" "$rrc" 0

# BSD/no-sort-V fallback: the numeric dotted-field sort must rank 2.10.0 above
# 2.9.0 (plain lexicographic sort picked 2.9.0). Asserts the exact fallback
# pipeline from the SKILL.md Step 1 resolver. (codex counsel P2)
fb=$(printf '2.9.0\t/a\n2.10.0\t/b\n' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1 | cut -f2-)
is "fallback sort: 2.10.0 outranks 2.9.0" "$fb" "/b"
rm -rf "$RS"

# Step 6b grace cap. Mirrors the Step 6b block in references/codex-state-machine.md.
# One budget on every gate, max(CODEX_GRACE, CODEX_PREFLIGHT_TIMEOUT - push_age),
# from codex-head-verdict.sh. It used to be CODEX_GRACE alone on cr_wait / bypass,
# so a Codex review still running when CR finished was cut off after 30s. The
# block never reads $pf: the bypass path (cli / codex-only) has none, and a bare
# `<<<"$pf"` aborts it under set -u. gh fails here on purpose: the budget must
# survive a verdict error. (Codex P2 iter 8; ticket #287)
GCSHIM=$(mktemp -d)
printf '#!/usr/bin/env bash\nexit 1\n' > "$GCSHIM/gh"; chmod +x "$GCSHIM/gh"
recent=$(jq -nr 'now - 100 | strftime("%Y-%m-%dT%H:%M:%SZ")')
gcaps=""; budget_default=$(. "$SCRIPTS/codex-turnaround.sh"; echo "$CODEX_BUDGET_DEFAULT")
for g in bypass cr_wait codex_wait; do
  gc_rc=0; gcap=$(env PATH="$GCSHIM:$PATH" SKILL_DIR="$HERE/.." gate="$g" PUSH_TIME="$recent" \
    bash -euo pipefail -c '
    OWNER=o REPO=r PR_NUM=42 CUR_SHA=deadbeef CODEX_GRACE=30
    hv=$(OWNER="$OWNER" REPO="$REPO" PR_NUM="$PR_NUM" CUR_SHA="$CUR_SHA" PUSH_TIME="$PUSH_TIME" \
         CODEX_GRACE="$CODEX_GRACE" bash "$SKILL_DIR/scripts/codex-head-verdict.sh" 2>/dev/null) \
      || echo "warn: Codex HEAD verdict unavailable (gh error); the wait budget still applies" >&2
    grace_cap=$(jq -r ".wait_seconds // empty" <<<"$hv"); [ -n "$grace_cap" ] || grace_cap="$CODEX_GRACE"
    printf "%s" "$grace_cap"' 2>/dev/null) || gc_rc=$?
  gcaps="$gcaps $g:$gc_rc:$([ "${gcap:-0}" -ge $((budget_default - 130)) ] && [ "${gcap:-0}" -le $((budget_default - 100)) ] && echo ok || echo "$gcap")"
done
is "grace-cap: same budget on every gate, errexit-safe without \$pf" \
   "$gcaps" " bypass:0:ok cr_wait:0:ok codex_wait:0:ok"
rm -rf "$GCSHIM"

# Step 13 convergence ladder. Mirrors the Step 13 block in references/run-blocks.md. The churn test
# must be guarded by judged_this_cycle > 0, or an iteration with NO findings
# (0 == 0) reports churn instead of clean and never files the follow-up issue.
conv() {
  ITER=$1 JUDGED=$2 CHURN=$3 APPLIED=$4 DEFERRED=$5 HIGH=$6 MINOR_STOP=${7:-true} REVIEW=${8:-0} \
  bash -c '
    if [ "$ITER" -ge 2 ] && [ "$JUDGED" -gt 0 ] && [ "$CHURN" = "$JUDGED" ]; then echo churn
    elif [ "$MINOR_STOP" = true ] && [ "$ITER" -ge 2 ] && [ "$APPLIED" -gt 0 ] \
         && [ "$HIGH" = 0 ] && [ "$DEFERRED" = 0 ] && [ "$REVIEW" = 0 ]; then echo minor_floor
    elif [ "$APPLIED" = 0 ] && [ "$DEFERRED" = 0 ] && [ "$REVIEW" = 0 ]; then echo clean
    elif [ "$APPLIED" = 0 ]; then echo user_declined
    else echo continue; fi'
}
# Step 15 cr_state allow-list. Mirrors the Step 15 block in references/run-blocks.md. It must be an
# allow-list: a deny-list of failure|error lets `none` / `unknown` through, and those
# mean CR was never observed on this SHA — merging there merges an unreviewed PR.
merge_state() {
  CR_STATE=$1 bash -c '
    case "$CR_STATE" in success|pending) echo proceed;; *) echo stop;; esac'
}
is "cr_state success -> proceed"          "$(merge_state success)" proceed
is "cr_state pending -> proceed"          "$(merge_state pending)" proceed
is "cr_state none -> stop"                "$(merge_state none)" stop
is "cr_state unknown -> stop"             "$(merge_state unknown)" stop
is "cr_state failure -> stop"             "$(merge_state failure)" stop
is "cr_state error -> stop"               "$(merge_state error)" stop

# Step 15 append_failed gating. The flag rides on the inherited followup_issue, so it
# only speaks for a run that actually deferred something; a clean run must not inherit
# an older run's append failure and stay unmergeable forever.
append_flag() {
  DEFERRED=$1 FLAG=$2 bash -c '
    [ "$DEFERRED" -gt 0 ] && echo "$FLAG" || echo false'
}
is "deferred>0 keeps append_failed"       "$(append_flag 2 true)" true
is "deferred=0 drops stale append_failed" "$(append_flag 0 true)" false

#         iter judged churn applied deferred high
is "all findings churn -> churn"          "$(conv 2 3 3 2 1 0)" churn
is "iter 1 never churns"                  "$(conv 1 3 3 2 1 0)" continue
is "no findings at all -> clean not churn" "$(conv 3 0 0 0 0 0)" clean
is "partial churn keeps looping"          "$(conv 2 3 2 2 1 0)" continue
is "low-severity-only cycle -> minor_floor" "$(conv 2 2 0 2 0 0)" minor_floor
is "--no-minor-stop keeps looping"        "$(conv 2 2 0 2 0 0 false)" continue
is "high severity blocks minor_floor"     "$(conv 2 2 0 2 0 1)" continue
# A `review`-tier item is a finding nobody could parse, so nobody examined it. Calling
# that a floor would hand an unexamined finding to the auto-merge gate.
is "unparsed review item blocks minor_floor" "$(conv 2 2 0 2 0 0 true 1)" continue
is "deferred everything -> user_declined"  "$(conv 2 2 0 0 2 0)" user_declined
# Nothing applied or deferred, but a finding nobody could read is still open: that
# is not convergence, and `clean` is the state that auto-merges unconditionally.
is "unparsed review item blocks clean"     "$(conv 2 0 0 0 0 0 true 1)" user_declined
is "unparsed review item blocks clean (iter 1)" "$(conv 1 0 0 0 0 0 true 1)" user_declined

echo
echo "run-blocks: HEAD verdict wait (blocks executed from references/run-blocks.md)"

# These run the blocks as written, extracted by heading, so a drift between the
# reference and the test cannot hide. Waits and posts are stubbed where noted.
RB="$HERE/../references/run-blocks.md"
rb_block() { awk -v h="## $1" '$0 == h {f=1; next} f && /^## / {exit}
  f && /^```bash$/ {c=1; next} c && /^```$/ {c=0; next} c {print}' "$RB"; }
for b in "Step 2: draft PR" "Step 2: request_cr_review" "Step 7e: HEAD verdict wait" \
         "Step 8c: engagement gate" "Step 9a: classify" "Step 13: convergence ladder" \
         "Step 14: last-push HEAD verdicts and follow-up trigger"; do
  [ -n "$(rb_block "$b")" ] || bad "run-blocks.md has a '$b' block" present missing
done

# Step 13: a stop right after a push is held for the new HEAD's verdicts.
ladder() { # PUSHED ITER MAX_ITER APPLIED DEFERRED -> final_state:HOLD_STATE
  PUSHED=$1 IT=$2 MAX=$3 AP=$4 DF=$5 BLOCK="$(rb_block "Step 13: convergence ladder")" bash -c '
    applied_total=0 deferred_total=0 MINOR_STOP=true MAX_ITER=$MAX HOLD_STATE="" final_state=""
    REVIEWED_SHA=${REVIEWED:-}
    pushed_this_cycle=$PUSHED applied_this_cycle=$AP deferred_this_cycle=$DF
    judged_this_cycle=$((AP+DF)) churn_this_cycle=0 high_sev_this_cycle=0 review_this_cycle=0
    eval "for ITER in $IT; do $BLOCK"
    printf "%s:%s" "$final_state" "$HOLD_STATE"'
}
is "minor_floor right after a push -> held, loop not ended" "$(ladder true 2 5 2 0)" ":minor_floor"
is "minor_floor with no push this cycle -> ends"            "$(ladder false 2 5 2 0)" "minor_floor:"
is "minor_floor pushed on the last iteration -> ends (Step 14 waits)" "$(ladder true 5 5 2 0)" "minor_floor:"
is "clean (nothing pushed) -> ends"                          "$(ladder false 3 5 0 0)" "clean:"
# Step 12 held Minor fixes for the base: the reviewed HEAD merges, even on iter 1.
is "Minor fixes held for the base -> minor_floor on iter 1"  "$(REVIEWED=abc ladder false 1 5 1 0)" "minor_floor:"
is "Minor fixes held, a defer too -> still stops"           "$(REVIEWED=abc ladder false 1 5 1 1)" "minor_floor:"

# Step 7e: no round goes past this block, so nothing is pushed, before every
# verdict is in. await_head_verdicts is stubbed to the state under test.
verdict_gate() { # HV_STATE HOLD_STATE -> final_state:HEAD_VERDICT:pushes
  HVS=$1 HOLD=$2 BLOCK="$(rb_block "Step 7e: HEAD verdict wait")" bash -c '
    await_head_verdicts() { hv_state=$HVS; }
    HOLD_STATE=$HOLD HEAD_VERDICT="" final_state="" pushes=0
    eval "for ITER in 1 2; do $BLOCK
      pushes=\$((pushes+1)); done"
    printf "%s:%s:%s" "$final_state" "$HEAD_VERDICT" "$pushes"'
}
is "verdicts in -> the rounds go on and push"            "$(verdict_gate ready "")" "::2"
is "no verdict before the budget -> no push, timeout"    "$(verdict_gate timeout "")" "timeout:timeout:0"
is "held minor_floor, budget spent -> minor_floor, HEAD unverified" \
   "$(verdict_gate timeout minor_floor)" "minor_floor:timeout:0"
is "Codex Failed while waiting -> codex_failed, no push" "$(verdict_gate codex_failed minor_floor)" "codex_failed::0"

# Step 9a: a held stop resolves on the new HEAD's findings. Real classify-item.sh.
# Step 9a drops the threads this run already judged (auto_judge_log comment ids).
EMPTY_SF=$(mktemp); echo '{"auto_judge_log":[]}' > "$EMPTY_SF"
hold_round() { # CR_RECORD_JSON -> final_state:HOLD_STATE:round
  REC=$1 STATE_FILE="$EMPTY_SF" SKILL_DIR="$HERE/.." BLOCK="$(rb_block "Step 9a: classify")" bash -c '
    cr_records="[$REC]" codex_records="[]" ITER=3 SKIP_MINOR=false HOLD_STATE=minor_floor final_state="" round=""
    eval "for i in 1; do $BLOCK
      round=yes; done"
    printf "%s:%s:%s" "$final_state" "$HOLD_STATE" "$round"'
}
major='{"source":"cr","path":"a.sh","line":3,"category_emoji":"🎯 Functional Correctness","severity_emoji":"🟠 Major","effort_emoji":"⚡ Quick win"}'
minor='{"source":"cr","path":"a.sh","line":3,"category_emoji":"🎯 Functional Correctness","severity_emoji":"🟡 Minor","effort_emoji":"⚡ Quick win"}'
is "new gated finding on the held HEAD -> one more round" "$(hold_round "$major")" "::yes"
is "only a quick-win Minor on the held HEAD -> ends as held" "$(hold_round "$minor")" "minor_floor:minor_floor:"
# Step 8c: nothing at all to fetch on the held HEAD -> ends as held, not clean.
is "held stop, nothing fetched -> ends as held" \
   "$(BLOCK="$(rb_block "Step 8c: engagement gate")" bash -c '
      HOLD_STATE=churn final_state=""; eval "for i in 1; do $BLOCK
      done"; printf %s "$final_state"')" churn
# Step 8c then 9a, as one round runs them: a held stop whose new HEAD brought a gated
# finding must reach the classifier, not end at 8c. gh fails: 8c may not look.
H8=$(mktemp -d); printf '#!/usr/bin/env bash\nexit 1\n' > "$H8/gh"; chmod +x "$H8/gh"
is "held stop, gated finding fetched -> 8c hands it to 9a, one more round" \
   "$(REC=$major PATH="$H8:$PATH" STATE_FILE="$EMPTY_SF" SKILL_DIR="$HERE/.." B8="$(rb_block "Step 8c: engagement gate")" \
      B9="$(rb_block "Step 9a: classify")" bash -c '
      cr_records="[$REC]" codex_records="[]" ITER=3 SKIP_MINOR=false HOLD_STATE=minor_floor final_state="" round=""
      eval "for i in 1; do $B8
      $B9
      round=yes; done"
      printf "%s:%s:%s" "$final_state" "$HOLD_STATE" "$round"' 2>/dev/null)" "::yes"
rm -rf "$H8" "$EMPTY_SF"

# Step 9c.6: a check that dies before printing (its revert failed under set -e) is not
# a pass. Only `pass` keeps the apply; anything else turns it into a defer.
V96=$(mktemp -d); mkdir -p "$V96/scripts"
verify_step() { # CHECK_STDOUT CHECK_RC -> applied:deferred
  printf '#!/usr/bin/env bash\n[ "$1" = check ] || { echo snap; exit 0; }\nprintf %%s "%s"\nexit %s\n' "$1" "$2" \
    > "$V96/scripts/verify-fix.sh"
  SKILL_DIR="$V96" BLOCK="$(rb_block "Step 9c.6: verify the fix")" bash -c '
    VERIFICATION_GATE=on VERIFY_CMD=true applied_this_cycle=1 auto_judge_apply=1
    deferred_this_cycle=0 auto_judge_defer=0
    eval "$BLOCK"; printf "%s:%s" "$applied_this_cycle" "$deferred_this_cycle"' 2>/dev/null
}
is "9c.6 pass keeps the apply"                       "$(verify_step pass 0)" "1:0"
is "9c.6 fail turns the apply into a defer"          "$(verify_step fail 0)" "0:1"
is "9c.6 check died with no output -> defer, not pass" "$(verify_step "" 1)" "0:1"
rm -rf "$V96"

# Step 2 state init on a PR the loop already ran on before the cr-fix -> review-loop
# rename: the old state carries the dedupe lists and the follow-up issue.
si_inherit() { # SETUP -> codex_processed_reviews|followup_issue.number of the new state
  local d; d=$(mktemp -d); mkdir -p "$d/.claude/state/archive"; (cd "$d" && eval "$1")
  (cd "$d" && PR_NUM=46 START_SHA=abc CR_SOURCE=auto BLOCK="$(rb_block "Step 2: state init")" bash -c 'eval "$BLOCK"' >/dev/null 2>&1
   jq -r '"\(.codex_processed_reviews)|\(.followup_issue.number)"' .claude/state/review-loop-46.json 2>/dev/null)
  rm -rf "$d"
}
is "state init inherits a pre-rename live cr-fix state" \
   "$(si_inherit "echo '{\"codex_processed_reviews\":[9],\"followup_issue\":{\"number\":5}}' > .claude/state/cr-fix-46.json")" "[9]|5"
is "state init inherits a pre-rename cr-fix archive" \
   "$(si_inherit "echo '{\"codex_processed_reviews\":[8]}' > .claude/state/archive/cr-fix-46-20260101-000000-1.json")" "[8]|null"
is "state init: a review-loop state wins over a cr-fix one" \
   "$(si_inherit "echo '{\"codex_processed_reviews\":[1]}' > .claude/state/archive/review-loop-46-20260102-000000-1.json; echo '{\"codex_processed_reviews\":[9]}' > .claude/state/cr-fix-46.json")" "[1]|null"
rm -f /tmp/review-loop-46-modified.list

# Step 15: findings nobody could read need the follow-up issue as much as deferred
# ones, so the gate sees them in DEFERRED_TOTAL (and the append flag with them).
G15=$(mktemp -d); mkdir -p "$G15/scripts"; cp "$SCRIPTS/words-json.sh" "$G15/scripts/"
printf '#!/usr/bin/env bash\njq -nc --arg d "$DEFERRED_TOTAL" --arg a "$FOLLOWUP_APPEND_FAILED" '"'"'{eligible:false,ineligible_reason:("D=\\($d) A=\\($a)")}'"'"'\n' \
  > "$G15/scripts/auto-merge-gate.sh"
echo '{"followup_issue":{"number":7,"append_failed":true}}' > "$G15/state.json"
gate_env() { # DEFERRED REVIEW -> the env the gate saw
  DT=$1 RT=$2 SKILL_DIR="$G15" STATE_FILE="$G15/state.json" BLOCK="$(rb_block "Step 15: auto-merge gate")" bash -c '
    reviewers_on() { cr_on=true; codex_on=auto; }
    final_state=clean deferred_total=$DT review_total=$RT OWNER=o REPO=r PR_NUM=1
    eval "$BLOCK"' 2>&1 >/dev/null | sed -n 's/^auto-merge: //p'
}
is "Step 15 gate counts unread findings as left behind" "$(gate_env 0 2)" "D=2 A=true"
is "Step 15 gate with nothing left behind"              "$(gate_env 0 0)" "D=0 A=false"
# The cr_state allow-list speaks for CodeRabbit only: a run that dropped it (codex-only,
# cli) must not be refused on its rate-limited status. Blocking checks stop the merge.
printf '#!/usr/bin/env bash\njq -nc %s\n' "'{eligible:true,cr_state:\"rate_limited\",blocking_checks:1,ci_state:\"fail\",failing_checks:[\"policy\"],protection_http:200,base_branch:\"main\"}'" \
  > "$G15/scripts/auto-merge-gate.sh"
cr_gate() { # CR_ON -> the Step 15 refusal line, if any
  CRON=$1 SKILL_DIR="$G15" STATE_FILE="$G15/state.json" BLOCK="$(rb_block "Step 15: auto-merge gate")" bash -c '
    reviewers_on() { cr_on=$CRON; codex_on=auto; }
    final_state=clean deferred_total=0 review_total=0 OWNER=o REPO=r PR_NUM=1
    eval "$BLOCK"' 2>&1 >/dev/null | sed -n 's/^auto-merge: //p'
}
is "Step 15: CodeRabbit on, rate-limited -> refused" "$(cr_gate true)" "cr_state=rate_limited is not a merge-approved state"
# With CodeRabbit off the next refusal is the failing check, which says why (#317).
is "Step 15: CodeRabbit off -> its status is not read, failing check named" "$(cr_gate false)" "failing CI check(s) on HEAD: policy"
printf '#!/usr/bin/env bash\njq -nc %s\n' "'{eligible:true,cr_state:\"success\",blocking_checks:1,ci_state:\"error\",failing_checks:[],protection_http:200,base_branch:\"main\"}'" \
  > "$G15/scripts/auto-merge-gate.sh"
is "Step 15: unreadable checks -> says so, not merged" "$(cr_gate true)" "CI checks on HEAD could not be read; merge not attempted"
# Step 15 end to end on a stubbed gate: the #336 CI update, the merge question, and the
# held Minor fixes (merge_then_main_push). gh, git and base-push.sh log their calls.
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$GATE_JSON"\n' > "$G15/scripts/auto-merge-gate.sh"
printf '#!/usr/bin/env bash\necho "base-push $*" >> "%s/calls"; echo pu5h\n' "$G15" > "$G15/scripts/base-push.sh"
mkdir -p "$G15/bin"
# PR reads answer "open" and "merged or auto-merge armed" (the merge is read from the PR,
# not gh pr merge's exit code); every other call is logged.
printf '#!/usr/bin/env bash\ncase "$*" in\n  "pr view"*autoMergeRequest*) echo yes ;;\n  "pr view"*) echo OPEN ;;\n  *) echo "gh $*" >> "%s/calls" ;;\nesac\n' "$G15" > "$G15/bin/gh"
printf '#!/usr/bin/env bash\ncase "$1" in rev-parse) echo f1x ;; *) echo "git $*" >> "%s/calls" ;; esac\n' "$G15" > "$G15/bin/git"
chmod +x "$G15/bin/gh" "$G15/bin/git"
s15() { # GATE_JSON -> final_state|ci_failing_checks|merged|calls ; env FS AM ANS RS DR RUNNER
  : > "$G15/calls"; echo '{"auto_judge_log":[{"iter":1,"src":"cr","path":"a.sh","line":3,"badge_or_sev":"🟡 Minor","action":"apply"}]}' > "$G15/state.json"
  GATE_JSON=$1 PATH="$G15/bin:$PATH" SKILL_DIR="$G15" STATE_FILE="$G15/state.json" CALLS="$G15/calls" \
    BLOCK="$(rb_block "Step 15: auto-merge gate")
$(rb_block "Step 15: merge")" bash -c '
    reviewers_on() { cr_on=true; codex_on=auto; }
    final_state=${FS:-clean} deferred_total=0 review_total=0 OWNER=o REPO=r PR_NUM=1 ITER=1 merged=false
    AUTO_MERGE=${AM:-false} MERGE_ANSWER=${ANS:-} REVIEWED_SHA=${RS:-} VERIFY_CMD=true verification_blocking=false
    dropped_reviewers=${DR:-} pending_decision=""
    eval "$BLOCK"
    printf "%s|%s|%s|%s" "$final_state" "${ci_failing_checks:-}" "$merged" "$(tr "\n" ";" < "$CALLS")"
    [ -z "${SHOW_PENDING:-}" ] || printf "|%s" "$pending_decision"' 2>/dev/null
}
ok404='{"eligible":true,"cr_state":"success","blocking_checks":0,"ci_state":"pass","failing_checks":[],"protection_http":404,"base_branch":"main"}'
ok200=$(jq -c '.protection_http = 200' <<<"$ok404")
cifail='{"eligible":true,"cr_state":"success","blocking_checks":1,"ci_state":"fail","failing_checks":["policy"],"protection_http":404,"base_branch":"main"}'
# #336: a check that failed after Step 14 looked reaches final_state and ci_failing_checks.
is "Step 15: CI failing at the gate -> ci_failing + names, no merge" "$(AM=true ANS=yes s15 "$cifail")" 'ci_failing|["policy"]|false|'
is "Step 15: CI failing does not rewrite iteration_cap" \
   "$(FS=iteration_cap s15 "$(jq -c '.eligible = false | .ineligible_reason = "x"' <<<"$cifail")")" 'iteration_cap||false|'
# Without --auto-merge a finished review asks; no answer (no interaction tool) is no merge.
is "Step 15: no --auto-merge, nobody answered -> not merged" "$(s15 "$ok200")" 'clean||false|'
is "Step 15: no --auto-merge, user said merge -> merged" "$(ANS=yes s15 "$ok200")" 'clean||true|gh pr merge 1 --auto --squash --delete-branch --match-head-commit f1x;'
is "Step 15: --auto-merge on a protected base -> merged without asking" \
   "$(AM=true s15 "$ok200")" 'clean||true|gh pr merge 1 --auto --squash --delete-branch --match-head-commit f1x;'
is "Step 15: --auto-merge, unprotected base, nobody answered -> not merged" "$(AM=true s15 "$ok404")" 'clean||false|'
# merge_then_main_push: the reviewed HEAD merges, then the held fixes go to the base.
is "Step 15: held Minor fixes, merged -> pushed to the base" \
   "$(RS=r3v ANS=yes s15 "$ok404")" 'clean||true|gh pr merge 1 --squash --delete-branch --match-head-commit r3v;base-push main r3v f1x true;'
is "Step 15: base push recorded for the final output" \
   "$(jq -c '[.base_push.branch, .base_push.sha, .base_push.fixes[0].path]' "$G15/state.json")" '["main","pu5h","a.sh"]'
is "Step 15: held Minor fixes, not merged -> pushed to the PR instead" "$(RS=r3v s15 "$ok404")" 'clean||false|git push;'
# A reviewer the wait dropped never saw HEAD: even --auto-merge on a protected base asks.
is "Step 15: dropped reviewer, --auto-merge, nobody answered -> not merged" "$(DR=codex AM=true s15 "$ok200")" 'clean||false|'
is "Step 15: dropped reviewer, user said merge -> merged" \
   "$(DR=codex AM=true ANS=yes s15 "$ok200")" 'clean||true|gh pr merge 1 --auto --squash --delete-branch --match-head-commit f1x;'
# The runner cannot ask (no AskUserQuestion in a subagent): it leaves the question to
# the main session, touches nothing, and keeps the held fixes on the local commit.
out=$(RUNNER=true RS=r3v SHOW_PENDING=1 s15 "$ok404")
is "Step 15 runner: merge question pending, no merge, no push" "${out%|*}" 'clean||false|'
is "Step 15 runner: pending decision carries the merge inputs" \
   "$(jq -c '[.question, .pr, .base, .protection_http, .reviewed_sha, .fix_sha, .iter]' <<<"${out##*|}")" '["merge",1,"main",404,"r3v","f1x",1]'
# The main session's answer runs the Step 15 merge block with the pending inputs.
s15m() { # WHY -> merged|calls
  : > "$G15/calls"; echo '{"auto_judge_log":[{"iter":1,"src":"cr","path":"a.sh","line":3,"badge_or_sev":"🟡 Minor","action":"apply"}]}' > "$G15/state.json"
  W=$1 PATH="$G15/bin:$PATH" SKILL_DIR="$G15" STATE_FILE="$G15/state.json" CALLS="$G15/calls" \
    BLOCK="$(rb_block "Step 15: merge")" bash -c '
    why=$W PR_NUM=1 base=main proto=404 REVIEWED_SHA=r3v FIX_SHA=f1x ITER=1 VERIFY_CMD=true pending_decision="" merged=false
    eval "$BLOCK"; printf "%s|%s" "$merged" "$(tr "\n" ";" < "$CALLS")"' 2>/dev/null
}
is "main session, user said merge -> merged, fixes to the base" \
   "$(s15m "")" 'true|gh pr merge 1 --squash --delete-branch --match-head-commit r3v;base-push main r3v f1x true;'
is "main session, user said no -> fixes to the PR" \
   "$(s15m "not merged: the user did not choose to merge")" 'false|git push;'
rm -rf "$G15"

# Step 14 follow-up issue (failure-modes.md): a re-run that appends to the inherited
# issue says why HEAD is unverified, as a new issue does.
FM=$(mktemp -d); printf '#!/usr/bin/env bash\n[ "$1 $2" = "issue comment" ] && cp "$5" "%s/body"\nexit 0\n' "$FM" > "$FM/gh"; chmod +x "$FM/gh"
echo '{"followup_issue":{"number":7},"auto_judge_log":[]}' > "$FM/state.json"
FM_BLOCK=$(awk '/^Fires when the Step 14 block/ {f=1; next} f && /^```bash$/ {c=1; next} c && /^```$/ {exit} c {print}' \
  "$HERE/../references/failure-modes.md")
PATH="$FM:$PATH" STATE_FILE="$FM/state.json" BLOCK="$FM_BLOCK" bash -c '
  final_state=iteration_cap review_total=0 deferred_total=0 PR_NUM=1 HEAD_VERDICT=unread
  eval "$BLOCK"' >/dev/null 2>&1
is "appended follow-up names an unread HEAD" "$(grep -c 'drew reviewer findings after the last round' "$FM/body" 2>/dev/null)" 1
# A follow-up issue filed on ci_failing (for its deferred findings) names the failing checks (#317).
cat > "$FM/gh" <<SH
#!/usr/bin/env bash
prev=""; for a in "\$@"; do [ "\$prev" = --body-file ] && cp "\$a" "$FM/body"; prev=\$a; done
[ "\$1 \$2" = "issue create" ] && echo https://github.com/o/r/issues/9
exit 0
SH
echo '{"auto_judge_log":[]}' > "$FM/state.json"; rm -f "$FM/body"
PATH="$FM:$PATH" STATE_FILE="$FM/state.json" BLOCK="$FM_BLOCK" bash -c '
  final_state=ci_failing ci_failing_checks="[\"policy\",\"build\"]" review_total=0 deferred_total=0 PR_NUM=1 HEAD_VERDICT=""
  eval "$BLOCK"' >/dev/null 2>&1
is "ci_failing follow-up issue names the failing checks" "$(grep -c 'CI checks failing on HEAD .*: policy, build' "$FM/body" 2>/dev/null)" 1
rm -rf "$FM"

# Step 12: a noop Step 10 (every fix reverted, or none applied) pushes nothing.
P12=$(mktemp -d); printf '#!/usr/bin/env bash\necho "$*" >> "%s/calls"\n' "$P12" > "$P12/git"; chmod +x "$P12/git"
# The PR is still open (the merged-meanwhile case is under "retro #339"); no network.
printf '#!/usr/bin/env bash\necho OPEN\n' > "$P12/gh"; chmod +x "$P12/gh"
# The gate (stubbed: prints NEXT) decides who reviews the fixes; it is asked about this iteration's.
mkdir -p "$P12/gate/scripts"
printf '#!/usr/bin/env bash\necho "FIX_ITER=$FIX_ITER sha=$4" > "%s/gate.args"\n[ "$NEXT" = broken ] && exit 1\necho "{\\"next_action\\":\\"$NEXT\\"}"\n' "$P12" \
  > "$P12/gate/scripts/auto-merge-gate.sh"
push_step() { # RES [NEXT] -> pushed_this_cycle:git-calls:REVIEWED_SHA
  local pushed
  : > "$P12/calls"
  pushed=$(RES=$1 NEXT=${2:-rereview_push} PATH="$P12:$PATH" SKILL_DIR="$P12/gate" BLOCK="$(rb_block "Step 12: push")" bash -c '
    request_cr_review() { :; }
    res=$RES pushed_this_cycle=false TRACK_FILE=/dev/null final_state="" ITER=2 CUR_SHA=r3v REVIEWED_SHA=""
    eval "for i in 1; do $BLOCK
    done"; printf "%s:%s" "$pushed_this_cycle" "$REVIEWED_SHA"' 2>/dev/null)
  printf '%s:%s' "${pushed%%:*}" "$(grep -c push "$P12/calls"):${pushed#*:}"
}
is "Step 10 noop -> no push"        "$(push_step noop)" "false:0:"
is "Step 10 staged -> one push"     "$(push_step staged:2)" "true:1:"
is "gate asked about this iteration's fixes on the reviewed HEAD" "$(cat "$P12/gate.args")" "FIX_ITER=2 sha=r3v"
is "Minor-only fixes -> held for the base, no PR push" "$(push_step staged:2 merge_then_main_push)" "false:0:r3v"
is "gate unreadable -> pushed for re-review"           "$(push_step staged:2 broken)" "true:1:"
# A failed commit (a pre-commit hook refusing it) leaves the fixes staged and HEAD
# unchanged: the run stops before Step 12 can mark a push or clear the track file.
mkdir -p "$P12/skill/scripts"; printf '#!/usr/bin/env bash\necho "[hook] refused" >&2\nexit 1\n' > "$P12/skill/scripts/stage-and-commit.sh"
: > "$P12/calls"
is "Step 10 commit failure -> failure, no push" \
   "$(PATH="$P12:$PATH" SKILL_DIR="$P12/skill" B10="$(rb_block "Step 10: stage and commit")" \
      B12="$(rb_block "Step 12: push")" bash -c '
      request_cr_review() { :; }
      pushed_this_cycle=false TRACK_FILE=/dev/null ITER=1 final_state=""
      eval "for i in 1; do $B10
      $B12
      done"; printf "%s:%s" "$final_state" "$pushed_this_cycle"' 2>/dev/null):$(grep -c push "$P12/calls")" "failure:false:0"
rm -rf "$P12"

# Step 14: the last iteration's push is waited on, then one follow-up trigger.
# ci-checks.sh is stubbed to print $CI_OUT (default: every check passed).
# The follow-up trigger is the real auto-merge-gate.sh (`file_issue`), next to the stub;
# gh fails, so the gate's lookups all come back unread.
CI14=$(mktemp -d); mkdir -p "$CI14/scripts" "$CI14/bin"
printf '#!/usr/bin/env bash\necho "$CI_OUT"; echo "CAP=$CAP" >> "%s/cap"\n' "$CI14" > "$CI14/scripts/ci-checks.sh"
cp "$SCRIPTS/auto-merge-gate.sh" "$SCRIPTS/words-json.sh" "$CI14/scripts/"
printf '#!/usr/bin/env bash\necho 2026-10-06T10:00:00Z\n' > "$CI14/scripts/push-time.sh"
printf '#!/usr/bin/env bash\nexit 1\n' > "$CI14/bin/gh"; chmod +x "$CI14/bin/gh"
CI_PASS='{"state":"pass","failing":[],"pending":[]}'
last_push() { # PUSHED FINAL HV_STATE FINDINGS DEFERRED [UNREAD] -> final_state:HEAD_VERDICT:followup
  PUSHED=$1 FS=$2 HVS=$3 FND=$4 DT=$5 RT=${6:-0} SKILL_DIR="$CI14" CI_OUT="${CI_OUT-$CI_PASS}" PATH="$CI14/bin:$PATH" \
    BLOCK="$(rb_block "Step 14: last-push HEAD verdicts and follow-up trigger")" bash -c '
    await_head_verdicts() { hv_state=$HVS; hv="{\"findings\":$FND}"; }
    reviewers_on() { cr_on=true; codex_on=auto; }
    pushed_this_cycle=$PUSHED final_state=$FS deferred_total=$DT review_total=$RT HEAD_VERDICT=""
    OWNER=o REPO=r PR_NUM=1 TIMEOUT=1800 INTERVAL=30
    eval "$BLOCK"
    printf "%s:%s:%s" "$final_state" "$HEAD_VERDICT" "$followup_needed"
    [ -z "${SHOW_CI:-}" ] || printf ":%s" "${ci_failing_checks:-}"'
}
CI_FAIL='{"state":"fail","failing":["policy"],"pending":[]}'
# A failing check alone files no issue (minimal-issue policy, #325): the final
# report carries the names. Deferred findings still get theirs.
is "clean HEAD with a failing check -> ci_failing + names, no issue" \
   "$(CI_OUT=$CI_FAIL SHOW_CI=1 last_push false clean ready false 0)" 'ci_failing::false:["policy"]'
is "minor_floor HEAD with a failing check and a defer -> ci_failing + issue" \
   "$(CI_OUT=$CI_FAIL last_push false minor_floor ready false 1)" "ci_failing::true"
is "churn HEAD with a failing check, nothing deferred -> no issue" \
   "$(CI_OUT=$CI_FAIL last_push false churn ready false 0)" "ci_failing::false"
is "CI wait runs under TIMEOUT"                          "$(grep -q 'CAP=1800' "$CI14/cap" && echo yes)" yes
is "iteration_cap is not rewritten by CI"  "$(CI_OUT=$CI_FAIL last_push false iteration_cap ready false 1)" "iteration_cap::true"
is "clean HEAD, checks still pending at the cap -> clean" \
   "$(CI_OUT='{"state":"pending","failing":[],"pending":["build"]}' last_push false clean ready false 0)" "clean::false"
is "clean HEAD, checks unreadable -> clean (gate re-reads)" \
   "$(CI_OUT='{"state":"error","failing":[],"pending":[]}' last_push false clean ready false 0 2>/dev/null)" "clean::false"
is "clean HEAD, CI script printed nothing -> clean + warning" \
   "$(CI_OUT='' last_push false clean ready false 0 2>&1 >/dev/null | grep -c 'could not be read')" 1
# Nothing deferred files no issue, however HEAD ended (#327): the report says so.
is "last push, findings on HEAD, no round left, nothing deferred -> iteration_cap, no issue" \
   "$(last_push true minor_floor ready true 0 2>/dev/null)" "iteration_cap:unread:false"
is "unverified HEAD is reported instead" \
   "$(last_push true minor_floor ready true 0 2>&1 >/dev/null | grep -c 'HEAD_VERDICT=unread')" 1
is "last push, HEAD passed -> state kept, nothing to file" \
   "$(last_push true minor_floor ready false 0)" "minor_floor::false"
is "last push, budget spent, nothing deferred -> HEAD unverified, no issue" \
   "$(last_push true churn timeout false 0 2>/dev/null)" "churn:timeout:false"
is "last push, budget spent, a defer -> issue" \
   "$(last_push true churn timeout false 1 2>/dev/null)" "churn:timeout:true"
is "loop ran out after a push -> iteration_cap"   "$(last_push true "" ready false 1)" "iteration_cap::true"
# The earlier gap: a defer from cycle 1 and a clean cycle 2 filed nothing.
is "clean after earlier defers -> follow-up issue" "$(last_push false clean ready false 2)" "clean::true"
is "clean, nothing deferred -> no issue"           "$(last_push false clean ready false 0)" "clean::false"
is "timeout with earlier defers -> follow-up issue" "$(last_push false timeout timeout false 1)" "timeout::true"
# A finding nobody could read (`review` tier) is left behind too: user_declined on it
# alone must still file the issue failure-modes.md points the user to.
is "only unread review-tier items -> follow-up issue" "$(last_push false user_declined ready false 0 1)" "user_declined::true"
rm -rf "$CI14"

# await_head_verdicts on a paused CodeRabbit: one request, then the same budget.
AW=$(mktemp -d)
cat > "$AW/gh" <<SH
#!/usr/bin/env bash
case "\$*" in
  *"/statuses"*) echo '[{"created_at":"2026-10-06T10:00:00Z"}]' ;;
  *"/pulls/"*"/reviews"*) cat "$FIX/pr-reviews-cr-older-commit.json" ;;
  *"/issues/"*"/comments"*) cat "$FIX/issue-comments-cr-review-paused.json" ;;
  *) echo "unknown gh args: \$*" >&2; exit 1 ;;
esac
SH
chmod +x "$AW/gh"
aw=$(cd "$HERE" && PATH="$AW:$PATH" SKILL_DIR="$HERE/.." BLOCK="$(rb_block "Step 2: request_cr_review")" bash -c '
  OWNER=o REPO=r PR_NUM=42 CR_SOURCE=auto CR_REVIEW_REQUEST=skip NO_CODEX=false codex_active=unknown
  TIMEOUT=0 INTERVAL=1 CODEX_GRACE=0
  eval "$BLOCK"
  requests=0; request_cr_review() { requests=$((requests+1)); }
  await_head_verdicts
  printf "%s:%s" "$hv_state" "$requests"' 2>/dev/null)
is "paused CodeRabbit -> one review request, wait resumes" "$aw" "timeout:1"
# A silent CodeRabbit (PR #315) half its budget in: one nudge for this HEAD (the stub
# posts it into the listing), then it is dropped at the outer cap and named; Codex's
# clean verdict carries HEAD. CR is off for the rest of the run, as Step 2b's drop_cr.
aw_push=$(jq -nr 'now - 6 | strftime("%Y-%m-%dT%H:%M:%SZ")')
cat > "$AW/gh" <<SH
#!/usr/bin/env bash
case "\$*" in
  *"/statuses"*) echo '[{"created_at":"$aw_push"}]' ;;
  *"/issues/"*"/reactions"*) echo '[]' ;;
  *"/pulls/"*"/reviews"*) cat "$FIX/pr-reviews-cr-older-commit.json" ;;
  *"/issues/"*"/comments"*) cat "$AW/comments.json" ;;
  *) exit 1 ;;
esac
SH
cp "$FIX/issue-comments-codex-summary-completed.json" "$AW/comments.json"
echo '{"cr_source":"auto"}' > "$AW/state.json"
# The waits' naps are logged and then really taken (the poller's clock is its own
# SECONDS): their sum is what the wait asked for, which load cannot stretch the way
# it stretched the elapsed time this case once measured (8-12 s against 7, #339).
mkdir -p "$AW/nap"; : > "$AW/naps"
printf '#!/usr/bin/env bash\necho "$1" >> "%s/naps"\nexec %s "$1"\n' "$AW" "$(command -v sleep)" > "$AW/nap/sleep"
chmod +x "$AW/nap/sleep"
aw=$(cd "$HERE" && AWD="$AW" FIX="$FIX" PATH="$AW/nap:$AW:$PATH" SKILL_DIR="$HERE/.." BLOCK="$(rb_block "Step 2: request_cr_review")" bash -c '
  OWNER=o REPO=r PR_NUM=42 CR_SOURCE=auto CR_REVIEW_REQUEST=skip NO_CODEX=false codex_active=unknown
  TIMEOUT=10 INTERVAL=1 CODEX_GRACE=0 STATE_FILE="$AWD/state.json" dropped_reviewers=""
  git() { echo 95ab2f621c9add07df26af3770418786a29a62bb; }
  eval "$BLOCK"
  requests=""
  request_cr_review() { requests="$requests $1"
    jq --arg t "$(jq -nr "now | strftime(\"%Y-%m-%dT%H:%M:%SZ\")")" \
      ". + [{user:{login:\"YoungjaeDev\"}, body:\"@coderabbitai review\", created_at:\$t}]" \
      "$FIX/issue-comments-codex-summary-completed.json" > "$AWD/comments.json"; }
  await_head_verdicts
  printf "%s:%s:%s:%s:%s" "$hv_state" "${requests# }" "$dropped_reviewers" "$CR_SOURCE" "$(jq -r .cr_source "$AWD/state.json")"' 2>/dev/null)
is "stuck CodeRabbit -> one nudge, then dropped and listed" "$aw" "ready:stuck:coderabbit:codex-only:codex-only"
# The nudge waits only in what is left of the cap (push + TIMEOUT), not TIMEOUT again.
# Push 6 s ago, TIMEOUT 10: about 4 s are left, and a nudge that restarted TIMEOUT
# would ask for 10 more.
aw_naps=$(awk '{s += $1} END {print s + 0}' "$AW/naps")
is "stuck CodeRabbit -> the whole wait stays inside one TIMEOUT" \
   "$(awk -v s="$aw_naps" 'BEGIN {print (s <= 6) ? "yes" : "no (" s " s of naps)"}')" yes
# Codex past its budget is dropped the way Step 2b drops it: no Codex wait or fetch after.
mkdir -p "$AW/skill/scripts"
printf '#!/usr/bin/env bash\necho 2026-10-06T10:00:00Z\n' > "$AW/skill/scripts/push-time.sh"
printf '#!/usr/bin/env bash\necho %s\n' "'{\"state\":\"ready\",\"cr\":\"clean\",\"codex\":\"dropped\",\"findings\":false,\"dropped\":[\"codex\"]}'" \
  > "$AW/skill/scripts/head-verdicts.sh"
aw=$(SKILL_DIR="$AW/skill" BLOCK="$(rb_block "Step 2: request_cr_review")" bash -c '
  OWNER=o REPO=r PR_NUM=42 CR_SOURCE=auto CR_REVIEW_REQUEST=skip NO_CODEX=false codex_active=active dropped_reviewers="coderabbit"
  git() { echo deadbeef; }
  eval "$BLOCK"; request_cr_review() { :; }
  await_head_verdicts; await_head_verdicts
  printf "%s:%s:%s:%s" "$hv_state" "$NO_CODEX" "$codex_active" "$dropped_reviewers"' 2>/dev/null)
is "Codex past its budget -> dropped once, off for the run" "$aw" "ready:true:disabled:coderabbit codex"
# After a stuck nudge the second wait keeps the first one's CodeRabbit deadline; after
# a pause request (which starts the review) it counts afresh.
for first in stuck paused; do
  rm -f "$AW/called" "$AW/deadlines"
  printf '#!/usr/bin/env bash\necho "${CR_DEADLINE:-none}" >> "%s/deadlines"\nif [ -f "%s/called" ]; then echo "{\\"state\\":\\"ready\\",\\"cr\\":\\"clean\\",\\"codex\\":\\"clean\\",\\"dropped\\":[]}"; else touch "%s/called"; echo "{\\"state\\":\\"%s\\",\\"cr\\":\\"none\\",\\"codex\\":\\"clean\\",\\"cr_review_request\\":\\"post\\",\\"cr_deadline\\":12345,\\"dropped\\":[]}"; fi\n' \
    "$AW" "$AW" "$AW" "$first" > "$AW/skill/scripts/head-verdicts.sh"
  (SKILL_DIR="$AW/skill" BLOCK="$(rb_block "Step 2: request_cr_review")" bash -c '
    OWNER=o REPO=r PR_NUM=42 CR_SOURCE=auto CR_REVIEW_REQUEST=skip NO_CODEX=false codex_active=active dropped_reviewers=""
    git() { echo deadbeef; }
    eval "$BLOCK"; request_cr_review() { :; }
    await_head_verdicts' >/dev/null 2>&1)
  eval "dl_$first=\"\$(tr '\n' ' ' < "$AW/deadlines")\""
done
is "after a stuck nudge the second wait keeps the CR deadline" "$dl_stuck" "none 12345 "
is "after a pause request the second wait counts afresh"      "$dl_paused" "none none "
rm -rf "$AW"

# request_cr_review owns its guard: a PR-bot source and a base CodeRabbit will not
# auto-review, or a pause, which needs the request on any base.
RQ=$(mktemp -d)
cat > "$RQ/gh" <<SH
#!/usr/bin/env bash
case "\$*" in
  *"/statuses"*) echo '[{"created_at":"2026-10-06T10:00:00Z"}]' ;;
  *"/issues/"*"/comments"*) echo '[]' ;;
  "pr comment"*) echo post >> "$RQ/posts" ;;
  *) echo "unknown gh args: \$*" >&2; exit 1 ;;
esac
SH
chmod +x "$RQ/gh"
req() { # CR_SOURCE CR_REVIEW_REQUEST [ARG] -> posts
  : > "$RQ/posts"
  SRC=$1 CRR=$2 ARG=${3:-} PATH="$RQ:$PATH" SKILL_DIR="$HERE/.." BLOCK="$(rb_block "Step 2: request_cr_review")" bash -c '
    OWNER=o REPO=r PR_NUM=42 CR_SOURCE=$SRC CR_REVIEW_REQUEST=skip
    git() { echo deadbeef; }
    eval "$BLOCK"; CR_REVIEW_REQUEST=$CRR
    request_cr_review $ARG' >/dev/null 2>&1
  wc -l < "$RQ/posts" | tr -d ' '
}
is "request: default base -> no post"            "$(req auto skip)" 0
is "request: non-default base, pr-bot -> post"   "$(req pr-bot request)" 1
is "request: cli source -> no post"              "$(req cli request)" 0
is "request: paused, default base -> post"       "$(req auto skip paused)" 1
is "request: paused, codex-only -> no post"      "$(req codex-only skip paused)" 0
is "request: stuck, default base -> post"        "$(req auto skip stuck)" 1
# The final report suggests adding the base to CodeRabbit's auto-review base branches
# only when this run actually posted the non-default-base request.
reqbase() { # CR_REVIEW_REQUEST [ARG] -> CR_BASE_REQUESTED
  CRR=$1 ARG=${2:-} PATH="$RQ:$PATH" SKILL_DIR="$HERE/.." BLOCK="$(rb_block "Step 2: request_cr_review")" bash -c '
    OWNER=o REPO=r PR_NUM=42 CR_SOURCE=auto CR_REVIEW_REQUEST=skip BASE=integration/322 CR_BASE_REQUESTED=""
    git() { echo deadbeef; }
    eval "$BLOCK"; CR_REVIEW_REQUEST=$CRR
    request_cr_review $ARG; printf %s "$CR_BASE_REQUESTED"' 2>/dev/null
}
is "non-default base request fired -> base recorded for the report" "$(reqbase request)" integration/322
is "default base, stuck nudge -> no base hint"                      "$(reqbase skip stuck)" ""
cat > "$RQ/gh" <<SH
#!/usr/bin/env bash
case "\$*" in
  *"/statuses"*) echo '[{"created_at":"2026-10-06T10:00:00Z"}]' ;;
  *"/issues/"*"/comments"*) echo '[{"body":"@coderabbitai review","created_at":"2026-10-06T11:00:00Z"}]' ;;
  "pr comment"*) echo post >> "$RQ/posts" ;;
  *) exit 1 ;;
esac
SH
is "non-default base, request already on HEAD (re-run) -> no base hint" "$(reqbase request)" ""
rm -rf "$RQ"

# Step 2: a draft PR stops with the `gh pr ready` hint.
DR=$(mktemp -d)
printf '#!/usr/bin/env bash\necho "$DRAFT"\n' > "$DR/gh"; chmod +x "$DR/gh"
draft() { DRAFT=$1 PATH="$DR:$PATH" BLOCK="$(rb_block "Step 2: draft PR")" bash -c 'PR_NUM=42; eval "$BLOCK"; echo went-on' 2>&1; }
out=$(draft true); rc=$?
is "draft PR -> stops"                    "$rc:$(grep -c went-on <<<"$out")" "1:0"
is "draft PR -> says gh pr ready"         "$(grep -c 'gh pr ready 42' <<<"$out")" 1
is "ready PR -> goes on"                  "$(draft false)" went-on
rm -rf "$DR"

# CodeRabbit's notice phrasings live in one file, or a new phrasing reaches only
# some of the readers (four copies drifted apart once already).
is "rate-limit phrasings defined only in scripts/cr-notices.sh" \
   "$(grep -l "='[^']*Review limit reached" "$SCRIPTS"/* | grep -vc '/cr-notices\.sh$')" 0

# The repo has no .llmwiki/ (ADR 0003); a pointer there leads nowhere.
is "no review-loop script points at a deleted wiki page" \
   "$(grep -l '\.llmwiki' "$SCRIPTS"/* 2>/dev/null | wc -l | tr -d ' ')" 0

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
   && ln -s "sub/nested/deep.txt" "$PT_ROOT/link-inside.md" 2>/dev/null \
   && [ -L "$PT_ROOT/link-dir" ] && [ -L "$PT_ROOT/link-file.md" ]; then  # Git Bash ln -s copies and still exits 0
  is "symlinked dir component escaping repo rejected"   "$(pt 'link-dir/x.md')"    1
  is "symlinked final component escaping repo rejected" "$(pt 'link-file.md')"     1
  is "symlink staying inside repo allowed"              "$(pt 'link-inside.md')"   0
else
  ok "symlink escape cases (skipped: ln -s unavailable)"
fi
# Nonexistent intermediate dir has no resolvable parent — reject, do not crash.
is "unresolvable parent rejected"    "$(pt 'no/such/dir/f.md')"     1

echo
echo "cr-review-request.sh"

# Non-default base: CodeRabbit auto-reviews only the default branch plus
# reviews.auto_review.base_branches, so an unmatched base needs a manual
# `@coderabbitai review` per push. No network: the config is a local file.
RQ=$(mktemp -d)
rq() { bash "$SCRIPTS/cr-review-request.sh" "$1" main "$2" 2>/dev/null; }
printf 'reviews:\n  auto_review:\n    base_branches: ["release/.*", "develop"]\n' > "$RQ/flow.yaml"
printf 'reviews:\n  auto_review:\n    enabled: true  # on\n    base_branches:\n      - %s\n' "'release/.*'" > "$RQ/block.yaml"
printf 'reviews:\n  auto_review:\n    enabled: false\n    base_branches: []\n' > "$RQ/off.yaml"
printf 'reviews:\n  path_instructions: []\n' > "$RQ/none.yaml"
is "default base -> skip"                        "$(rq main "$RQ/flow.yaml")"          skip
is "non-default base matched (flow list) -> skip" "$(rq release/1.2 "$RQ/flow.yaml")"  skip
is "non-default base matched (block list) -> skip" "$(rq release/1.2 "$RQ/block.yaml")" skip
is "non-default base unmatched -> request"       "$(rq feature/x "$RQ/flow.yaml")"     request
is "non-default base, no base_branches -> request" "$(rq feature/x "$RQ/none.yaml")"   request
is "no config file -> request"                   "$(rq feature/x "$RQ/missing.yaml")"  request
# Decision 17: auto-review switched off to save quota wins over the manual request.
is "auto_review.enabled false -> skip"           "$(rq feature/x "$RQ/off.yaml")"      skip
printf 'reviews:\n  auto_review:\n    enabled: False\n' > "$RQ/off-cap.yaml"
is "auto_review.enabled False -> skip"           "$(rq feature/x "$RQ/off-cap.yaml")"  skip
is "default base, no config -> skip"             "$(rq main "$RQ/missing.yaml")"       skip
# An empty list item is not a match-everything pattern.
printf 'reviews:\n  auto_review:\n    base_branches:\n      -\n      - ""\n' > "$RQ/empty.yaml"
is "empty base_branches items -> request"        "$(rq feature/x "$RQ/empty.yaml")"    request
rm -rf "$RQ"

echo
echo "cr-review-posted.sh"

# A re-run on the same head must not post a second `@coderabbitai review`. The PR's
# comments are the record: any exact request at or after the head's push time counts,
# whoever posted it (the requester is the user's own account).
RP=$(mktemp -d)
cat > "$RP/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"/issues/"*"/comments"*) [ -n "${RP_FAIL:-}" ] && exit 1; cat "$RP_COMMENTS" ;;
  *) echo "unknown gh args: $*" >&2; exit 1 ;;
esac
SH
chmod +x "$RP/gh"
# Two pages, as --paginate emits them; the request sits on the second.
printf '[{"user":null,"body":"x","created_at":"2026-01-01T00:00:00Z"}]\n[{"user":{"login":"YoungjaeDev"},"body":"  @coderabbitai review\\n","created_at":"2026-01-02T00:00:00Z"}]\n' > "$RP/after.json"
printf '[{"user":{"login":"YoungjaeDev"},"body":"@coderabbitai review","created_at":"2025-12-31T00:00:00Z"}]\n' > "$RP/before.json"
printf '[{"user":{"login":"YoungjaeDev"},"body":"@coderabbitai review please","created_at":"2026-01-02T00:00:00Z"},{"user":{"login":"coderabbitai[bot]"},"body":"summary","created_at":"2026-01-02T00:00:00Z"}]\n' > "$RP/none.json"
rp() { RP_COMMENTS="$1" RP_FAIL="${2:-}" PATH="$RP:$PATH" \
         bash "$SCRIPTS/cr-review-posted.sh" o r 42 2026-01-01T12:00:00Z 2>/dev/null; }
is "requested after this push -> skip"    "$(rp "$RP/after.json")"  skip
is "requested only before push -> post"   "$(rp "$RP/before.json")" post
is "no exact request -> post"             "$(rp "$RP/none.json")"   post
out=$(rp "$RP/after.json" 1); rc=$?
is "API failure -> exit 1"                "$rc" 1
is "API failure -> no decision printed"   "$out" ""
rm -rf "$RP"

echo
echo "reviewer-availability.sh"

# The two "will not review" comments observed on PR #237, seconds after the PR
# opened. Without this probe the loop spent its whole grace and poll budget and
# ended as `timeout`.
AV=$(mktemp -d)
cat > "$AV/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"/issues/"*"/comments"*) cat "$AV_COMMENTS" ;;
  *) echo "unknown gh args: $*" >&2; exit 1 ;;
esac
SH
chmod +x "$AV/gh"
UNAV="$FIX/issue-comments-reviewers-unavailable.json"
jq '[.[] | select(.user.login | startswith("chatgpt"))]' "$UNAV" > "$AV/codex-only.json"
jq '[.[] | select(.user.login | startswith("coderabbit"))]' "$UNAV" > "$AV/cr-only.json"
# Impostor: a registrable login that only prefixes the bot's name must not count.
jq '[.[] | if (.user.login | startswith("coderabbit")) then .user.login = "coderabbitai-evil" else . end]' \
  "$UNAV" > "$AV/impostor.json"
jq '[.[] | .user.login |= sub("\\[bot\\]$"; "")]' "$UNAV" > "$AV/graphql-spelling.json"
av() { AV_COMMENTS="$1" CR_SOURCE="${2:-auto}" NO_CODEX="${3:-false}" PATH="$AV:$PATH" \
         bash "$SCRIPTS/reviewer-availability.sh" o r 42 2>/dev/null; }
out=$(av "$UNAV")
is "both unavailable -> stop"            "$(jq -r '.action' <<<"$out")" stop
is "both unavailable -> codex url"       "$(jq -r '.codex_url' <<<"$out")" \
   "https://github.com/YoungjaeDev/my-claude-plugins/pull/237#issuecomment-5723787512"
is "both unavailable -> cr url"          "$(jq -r '.cr_url' <<<"$out")" \
   "https://github.com/YoungjaeDev/my-claude-plugins/pull/237#issuecomment-5723787904"
is "codex only unavailable -> drop_codex" "$(av "$AV/codex-only.json" | jq -r '.action')" drop_codex
is "cr only unavailable -> drop_cr"      "$(av "$AV/cr-only.json" | jq -r '.action')" drop_cr
is "impostor coderabbitai-evil ignored"  "$(av "$AV/impostor.json" | jq -r '.cr_unavailable')" false
is "impostor + codex limit -> drop_codex" "$(av "$AV/impostor.json" | jq -r '.action')" drop_codex
is "login without [bot] still matched"   "$(av "$AV/graphql-spelling.json" | jq -r '.action')" stop
# The CLI is local: a PR-bot skip comment says nothing about it.
is "cli source ignores the PR-bot skip"  "$(av "$UNAV" cli | jq -r '.action')" drop_codex
is "codex-only source + codex limit -> stop" "$(av "$AV/codex-only.json" codex-only | jq -r '.action')" stop
is "--no-codex + cr skip -> stop"        "$(av "$AV/cr-only.json" auto true | jq -r '.action')" stop
is "no signal -> proceed"                "$(av "$FIX/issue-comments-rl.json" | jq -r '.action')" proceed
# A signal older than this push belongs to an earlier one; the quota may be back.
is "signals before SINCE ignored"        "$(SINCE=2030-01-01T00:00:00Z av "$UNAV" | jq -r '.action')" proceed
is "signals after SINCE still count"     "$(SINCE=2020-01-01T00:00:00Z av "$UNAV" | jq -r '.action')" stop
# A failed fetch is not "no signal": exit non-zero so the caller knows it did not look.
cat > "$AV/gh" <<'SH'
#!/usr/bin/env bash
exit 1
SH
AV_COMMENTS=/dev/null PATH="$AV:$PATH" bash "$SCRIPTS/reviewer-availability.sh" o r 42 >/dev/null 2>&1; rc=$?
is "gh failure -> non-zero exit"         "$rc" 1
rm -rf "$AV"

echo
echo "verify-fix.sh"

# Verification runs before the commit, one fix at a time, so only fixes that pass
# reach the push. A repository whose build or test already fails before the loop
# touches it (GPU- or data-bound suites) is left out of the gate, and the final
# output says so, instead of every fix being reverted for a failure it did not cause.
vf() { bash "$SCRIPTS/verify-fix.sh" "$@" 2>/dev/null; }
is "baseline fails from the start -> gate off"  "$(vf baseline 'exit 1')" baseline_failed
is "baseline passes -> gate on"                 "$(vf baseline 'true')" on
is "no build/test command -> gate off"          "$(vf baseline '')" no_command
is "--no-build-check -> gate off, cmd not run"  "$(NO_BUILD=true vf baseline 'echo ran; exit 1')" no_build_check
fo=$(VERIFICATION_GATE=baseline_failed bash "$SCRIPTS/emit-final-json.sh" 2>/dev/null)
is "final output records the disabled gate"     "$(jq -r '.verification_gate' <<<"$fo")" baseline_failed
is "schema lists the disabled gate" \
   "$(jq -r '.properties.verification_gate.enum | index("baseline_failed") != null' "$HERE/../assets/final-output.schema.json")" true

# Two fixes, the second breaks the test. The broken one is reverted (including a
# file it created), the passing one survives, and only the survivor is committed.
VF=$(mktemp -d)
(
  cd "$VF" && git init -q . && git config user.email t@t && git config user.name t \
    && printf 'old\n' > a.sh && printf 'old\n' > b.sh && git add -A && git commit -qm base
) >/dev/null 2>&1
VCMD='! grep -q BROKEN a.sh b.sh'
vfx() { (cd "$VF" && bash "$SCRIPTS/verify-fix.sh" "$@" 2>/dev/null); }
TRK=$(mktemp)
snap=$(vfx snapshot); printf 'fixed\n' > "$VF/a.sh"; printf '%s\0' a.sh >> "$TRK"
is "passing fix -> pass"                        "$(vfx check "$snap" "$VCMD")" pass
snap=$(vfx snapshot)
printf 'fixed\nBROKEN\n' > "$VF/a.sh"; printf 'BROKEN\n' > "$VF/b.sh"; printf 'new\n' > "$VF/c.sh"
printf '%s\0' a.sh b.sh c.sh >> "$TRK"
is "failing fix -> fail"                        "$(vfx check "$snap" "$VCMD")" fail
is "failing fix reverted, earlier fix kept"     "$(cat "$VF/a.sh")" fixed
is "failing fix reverted to HEAD content"       "$(cat "$VF/b.sh")" old
is "file the failing fix created is removed"    "$([ -e "$VF/c.sh" ] && echo present || echo absent)" absent
(cd "$VF" && bash "$SCRIPTS/stage-and-commit.sh" "$TRK" 1) >/dev/null 2>&1
is "only the passing fix is committed" \
   "$(cd "$VF" && git show --name-only --pretty=format: HEAD | tr '\n' ' ')" "a.sh "
# A cycle whose only fix failed leaves nothing to commit; Step 10's noop skips the push.
: > "$TRK"
snap=$(vfx snapshot); printf 'BROKEN\n' > "$VF/b.sh"; printf '%s\0' b.sh >> "$TRK"
is "only fix fails -> fail"                     "$(vfx check "$snap" "$VCMD")" fail
is "only-failed cycle -> noop, nothing to push" \
   "$(cd "$VF" && bash "$SCRIPTS/stage-and-commit.sh" "$TRK" 2 2>/dev/null)" noop
# A VERIFY_CMD that stages (this repo's chain opens with `git add -A`) leaves the fix
# in the index: it still differs from HEAD and must be committed, not read as noop.
: > "$TRK"
snap=$(vfx snapshot); printf 'staged fix\n' > "$VF/a.sh"; printf '%s\0' a.sh >> "$TRK"
is "fix staged by the verify command -> pass" "$(vfx check "$snap" 'git add -A')" pass
is "fix already in the index is still committed" \
   "$(cd "$VF" && bash "$SCRIPTS/stage-and-commit.sh" "$TRK" 3 2>/dev/null | tail -1)" staged:1
# The verify command runs on a throwaway index: its `git add -A` must not stage an
# unrelated file into the real index, where the next commit would pick it up.
printf 'user wip\n' > "$VF/wip.txt"
vfx baseline 'git add -A' >/dev/null
is "baseline's git add -A leaves the real index alone" \
   "$(cd "$VF" && git diff --cached --name-only | tr '\n' ' ')" ""
snap=$(vfx snapshot); printf 'fix 4\n' > "$VF/a.sh"
vfx check "$snap" 'git add -A' >/dev/null
is "check's git add -A leaves the real index alone" \
   "$(cd "$VF" && git diff --cached --name-only | tr '\n' ' ')" ""
rm -rf "$VF" "$TRK"

echo
echo "base-push.sh"
# merge_then_main_push (ADR 0006): after the reviewed HEAD merged, the held Minor
# fixes go onto the base, only once build/test and the pre-commit guards pass there.
BP=$(mktemp -d)
(
  git init -q --bare "$BP/remote.git" && git clone -q "$BP/remote.git" "$BP/w" && cd "$BP/w" \
    && git config user.email t@t && git config user.name t && git checkout -q -b main \
    && printf 'a\nb\nc\n' > f && git add f && git commit -qm base && git push -q origin main \
    && git checkout -q -b pr && printf 'a\nB\nc\n' > f && git commit -qam reviewed && git push -q origin pr \
    && printf 'a\nB\nC\n' > f && git commit -qam "fix: minor (review-loop iter 1)" \
    && echo g > g && git add g && git commit -qm "fix: second (review-loop iter 1)" \
    && git checkout -q --detach origin/main && git checkout -q pr~2 -- f && git commit -qm "squash (#1)" \
    && git push -q origin HEAD:main && git checkout -q pr
) >/dev/null 2>&1
BP_R=$(git -C "$BP/w" rev-parse pr~2); BP_F=$(git -C "$BP/w" rev-parse pr)
bp() { (cd "$BP/w" && bash "$SCRIPTS/base-push.sh" main "$BP_R" "$BP_F" "$1" 2>/dev/null); }
bp_main() { git -C "$BP/remote.git" show main:f | tr '\n' ' '; }
bp 'false' >/dev/null; rc=$?
is "build/test fails on base + fixes -> not pushed" "$rc:$(bp_main)" "1:a B c "
bp '' >/dev/null; rc=$?
is "no build/test command -> not pushed"           "$rc:$(bp_main)" "1:a B c "
mkdir -p "$BP/hooks"; printf '#!/bin/sh\nexit 1\n' > "$BP/hooks/pre-commit"; chmod +x "$BP/hooks/pre-commit"
git -C "$BP/w" config core.hooksPath "$BP/hooks"
bp 'true' >/dev/null; rc=$?
is "pre-commit guard refuses -> not pushed"         "$rc:$(bp_main)" "1:a B c "
printf '#!/bin/sh\necho fmt >> f\n' > "$BP/hooks/pre-commit"
bp 'true' >/dev/null; rc=$?
is "pre-commit guard rewrites a file -> not pushed" "$rc:$(bp_main)" "1:a B c "
git -C "$BP/w" config --unset core.hooksPath
is "failed attempts leave no worktree behind"       "$(git -C "$BP/w" worktree list | wc -l | tr -d ' ')" 1
# The command runs where the fixes were applied on top of the base.
out=$(bp 'grep -q C f'); rc=$?
is "fixes pass on the base -> pushed"               "$rc:$(bp_main)" "0:a B C "
is "each fix commit lands as its own commit, message kept" \
   "$(git -C "$BP/remote.git" log -2 --format=%s main | tr '\n' '|')" "fix: second (review-loop iter 1)|fix: minor (review-loop iter 1)|"
is "prints the pushed sha"                          "$out" "$(git -C "$BP/remote.git" rev-parse main)"
is "the user's checkout is left as it was"          "$(git -C "$BP/w" rev-parse --abbrev-ref HEAD):$(git -C "$BP/w" rev-parse HEAD)" "pr:$BP_F"
rm -rf "$BP"
# The guards run whether or not this clone turned its hooks on: a tracked
# .githooks/pre-commit (core.hooksPath unset) still refuses the push.
BP=$(mktemp -d)
(
  git init -q --bare "$BP/remote.git" && git clone -q "$BP/remote.git" "$BP/w" && cd "$BP/w" \
    && git config user.email t@t && git config user.name t && git checkout -q -b main \
    && mkdir .githooks && printf '#!/bin/sh\necho guard-ran >&2\nexit 1\n' > .githooks/pre-commit \
    && chmod +x .githooks/pre-commit && printf 'a\n' > f && git add -A && git commit -qm base \
    && git push -q origin main && git checkout -q -b pr && echo b >> f && git commit -qam reviewed \
    && echo c >> f && git commit -qam "fix: minor (review-loop iter 1)" && git push -q origin pr \
    && git checkout -q --detach origin/main && git checkout -q pr~1 -- f && git commit -qm "squash (#1)" \
    && git push -q origin HEAD:main && git checkout -q pr
) >/dev/null 2>&1
BP_R=$(git -C "$BP/w" rev-parse pr~1); BP_F=$(git -C "$BP/w" rev-parse pr)
before=$(git -C "$BP/remote.git" rev-parse main)
err=$(cd "$BP/w" && bash "$SCRIPTS/base-push.sh" main "$BP_R" "$BP_F" true 2>&1 >/dev/null); rc=$?
is "hooks off in this clone, tracked pre-commit refuses -> not pushed" \
   "$rc:$([ "$(git -C "$BP/remote.git" rev-parse main)" = "$before" ] && echo kept)" 1:kept
is "the tracked guard is the one that ran"          "$(grep -c guard-ran <<<"$err")" 1
rm -rf "$BP"

echo
echo "post-merge leftover surface: reads review-loop- and the pre-rename cr-fix- state"
# The skill was renamed cr-fix -> review-loop; a repo whose only state file was
# written before the rename must still surface its deferred findings.
LR="$HERE/../../post-merge/references/leftover-reviews.md"
lr_primary() { # MAIN_REPO -> "DEFER_N:final_state"
  MAIN_REPO=$1 PR_NUMBER=42 BLOCK="$(awk '/^## Primary signal/ {f=1; next} f && /^## / {exit}
    f && /^```bash$/ {c=1; next} c && /^```$/ {c=0; next} c {print}' "$LR")" bash -c '
    eval "$BLOCK"; printf "%s:%s" "$DEFER_N" "$CRF_FINAL"'
}
LF=$(mktemp -d); mkdir -p "$LF/old/.claude/state" "$LF/arc/.claude/state/archive" "$LF/new/.claude/state"
defer_state() { printf '{"final_state":"%s","auto_judge_log":[{"action":"defer","path":"a.sh","line":3,"badge_or_sev":"major","reason":"r"}]}' "$1"; }
defer_state iteration_cap > "$LF/old/.claude/state/cr-fix-42.json"
is "old cr-fix-<PR>.json only -> deferred item found" "$(lr_primary "$LF/old")" "1:iteration_cap"
defer_state churn > "$LF/arc/.claude/state/archive/cr-fix-42-20260101-000000-1.json"
is "old cr-fix archive only -> deferred item found"   "$(lr_primary "$LF/arc")" "1:churn"
defer_state timeout > "$LF/new/.claude/state/review-loop-42.json"
echo '{"final_state":"clean"}' > "$LF/new/.claude/state/cr-fix-42.json"
is "review-loop-<PR>.json wins over the old prefix"   "$(lr_primary "$LF/new")" "1:timeout"
is "no state file -> none"                           "$(lr_primary "$LF")" "0:"
rm -rf "$LF"

echo
echo "retro #339: per-iteration state, external merges, the commit and the base push"
# Each case is a defect a live run hit (PR #308, #334). Blocks run as written.
R9=$(mktemp -d); mkdir -p "$R9/skill/scripts" "$R9/bin"
(cd "$R9" && git init -q repo && cd repo && git config user.email t@t && git config user.name t \
  && echo a > a.sh && echo t > t.sh && echo w > wip.txt && git add -A && git commit -qm base) >/dev/null 2>&1
printf '#!/usr/bin/env bash\necho "$3" >> "%s/push-time.args"; echo 2026-10-06T10:00:00Z\n' "$R9" > "$R9/skill/scripts/push-time.sh"
printf '#!/usr/bin/env bash\necho active\n' > "$R9/skill/scripts/probe-codex-engagement.sh"
# gh: PR_STATE answers `pr view --json state`, MERGE_RC is `pr merge`'s exit, PRV_MERGED
# answers the merged-or-armed read; writes are logged, reads are not.
cat > "$R9/bin/gh" <<SH
#!/usr/bin/env bash
case "\$*" in
  "pr view"*autoMergeRequest*) echo "\${PRV_MERGED:-yes}" ;;
  "pr view"*"--json mergeable"*) echo MERGEABLE ;;
  "pr view"*"--json state"*) echo "\${PR_STATE:-OPEN}" ;;
  "pr merge"*) echo "gh \$*" >> "$R9/calls"; exit "\${MERGE_RC:-0}" ;;
  "api --paginate repos/o/r/pulls/42/reviews") echo '[{"id":5558727164,"user":{"login":"chatgpt-codex-connector[bot]"},"state":"COMMENTED","submitted_at":"2026-10-17T16:20:00Z"}]' ;;
  *) echo "gh \$*" >> "$R9/calls" ;;
esac
SH
chmod +x "$R9/bin/gh"

# Item 2: the Codex review id is per iteration. Kept, iter 2's Step 6b skips discovery
# and Step 8b fetches iter 1's review again. Item 10: a PR merged or closed outside the
# run ends it at the top of the iteration. Item 8: the loop head records what was
# already dirty, so the commit can tell a fix's extra files from the user's.
loop5() { # PR_STATE -> final_state:codex_review_id_to_process:round
  (cd "$R9/repo" && PR_STATE=$1 PATH="$R9/bin:$PATH" SKILL_DIR="$R9/skill" BLOCK="$(rb_block "Step 5: loop head and pre-flight")" bash -c '
    OWNER=o REPO=r PR_NUM=42 MAX_ITER=1 CR_SOURCE=codex-only codex_review_id_to_process=5558727164
    final_state="" round="" DIRTY_BASE="$DB"
    eval "$BLOCK
      round=yes; done"
    printf "%s:%s:%s" "$final_state" "$codex_review_id_to_process" "$round"' 2>/dev/null)
}
echo changed > "$R9/repo/wip.txt"
export DB="$R9/dirty.base"
is "Step 5: a new iteration starts without the last one's Codex review id" "$(loop5 OPEN)" "::yes"
is "Step 5: the loop head records the files already dirty" "$(tr '\0' ' ' < "$DB")" "wip.txt "
is "Step 5: PR merged outside the run -> merged_externally, no round" "$(loop5 MERGED)" "merged_externally:5558727164:"
is "Step 5: PR closed outside the run -> merged_externally, no round" "$(loop5 CLOSED)" "merged_externally:5558727164:"
unset DB

# Item 3: a thread this run already judged stays unresolved (deferred, skipped, or
# applied and not yet re-reviewed) and comes back every iteration. Judged again, its
# defer is counted twice, blocks minor_floor and lands twice in the follow-up issue.
echo '{"auto_judge_log":[{"iter":1,"src":"cr","path":"a.sh","line":3,"action":"defer","comment_id":4303464262}]}' > "$R9/state.json"
old_major='{"source":"cr","path":"a.sh","line":3,"databaseId":4303464262,"category_emoji":"🎯 Functional Correctness","severity_emoji":"🟠 Major","effort_emoji":"⚡ Quick win"}'
new_minor='{"source":"cr","path":"a.sh","line":9,"databaseId":4303469999,"category_emoji":"🎯 Functional Correctness","severity_emoji":"🟡 Minor","effort_emoji":"⚡ Quick win"}'
judged() { # HOLD_STATE RECORDS -> final_state:classified databaseIds
  HS=$1 RECS=$2 STATE_FILE="$R9/state.json" SKILL_DIR="$HERE/.." BLOCK="$(rb_block "Step 9a: classify")" bash -c '
    cr_records="$RECS" codex_records="[]" ITER=2 SKIP_MINOR=false HOLD_STATE=$HS final_state="" classified="[]"
    eval "for i in 1; do $BLOCK
    done"; printf "%s:%s" "$final_state" "$(jq -c "[.[].databaseId]" <<<"$classified")"' 2>/dev/null
}
is "Step 9a: a thread judged earlier this run is not judged again" "$(judged "" "[$old_major,$new_minor]")" ":[4303469999]"
is "Step 9a: held stop, only an already-judged Major back -> ends as held" "$(judged minor_floor "[$old_major]")" "minor_floor:[]"
is "log shape: the comment id is a state schema field" \
   "$(jq -r '.properties.auto_judge_log.items.properties | has("comment_id")' "$HERE/../assets/state.schema.json")" true

# Item 4: Step 6 probed Codex before the CR poll (PR #334: 292 s after the PR opened,
# no Codex review yet) and stayed inactive, so Step 6b and 8b skipped 4 findings.
SMB=$(awk '/^## Review-id discovery and the grace cap \(Step 6b\)/ {f=1; next} f && /^## / {exit}
  f && /^```bash$/ {c=1; next} c && /^```$/ {c=0; next} c {print}' "$HERE/../references/codex-state-machine.md")
echo '{"codex_processed_reviews":[]}' > "$R9/state6b.json"
is "Step 6b: inactive at entry is probed again, and the review is found" \
   "$(PATH="$R9/bin:$PATH" SKILL_DIR="$R9/skill" STATE_FILE="$R9/state6b.json" BLOCK="$SMB" bash -c '
      OWNER=o REPO=r PR_NUM=42 codex_active=inactive codex_review_id_to_process="" CODEX_GRACE=0 gate=cr_wait
      eval "$BLOCK"; printf "%s:%s" "$codex_active" "$codex_review_id_to_process"' 2>/dev/null)" "active:5558727164"

# Item 10 at the push: the loop must not push a cycle's fixes onto a PR that merged
# while it judged them (PR #308: merged 11:41, pushed 11:46).
mkdir -p "$R9/gate/scripts"
printf '#!/usr/bin/env bash\necho "{\\"next_action\\":\\"${NEXT:-rereview_push}\\"}"\n' > "$R9/gate/scripts/auto-merge-gate.sh"
printf '#!/usr/bin/env bash\necho "git $*" >> "%s/calls"\n' "$R9" > "$R9/bin/git"; chmod +x "$R9/bin/git"
push12() { # PR_STATE -> final_state:pushed_this_cycle:pushes
  : > "$R9/calls"
  PR_STATE=$1 PATH="$R9/bin:$PATH" SKILL_DIR="$R9/gate" BLOCK="$(rb_block "Step 12: push")" bash -c '
    request_cr_review() { :; }
    res=staged:1 pushed_this_cycle=false TRACK_FILE=/dev/null final_state="" ITER=2 CUR_SHA=r3v REVIEWED_SHA="" PR_NUM=42
    eval "for i in 1; do $BLOCK
    done"; printf "%s:%s:%s" "$final_state" "$pushed_this_cycle" "$(grep -c "git push" "$CALLS")"' 2>/dev/null
}
export CALLS="$R9/calls"
is "Step 12: PR still open -> pushed"                       "$(push12 OPEN)" ":true:1"
is "Step 12: PR merged meanwhile -> merged_externally, no push" "$(push12 MERGED)" "merged_externally:false:0"
is "Step 12: PR closed meanwhile -> merged_externally, no push" "$(push12 CLOSED)" "merged_externally:false:0"
rm -f "$R9/bin/git"

# Item 5: gh pr merge's exit code is not the merge. With the branch checked out in
# another worktree gh merges, cannot delete the local branch, and fails; read as
# "not merged", the held fixes were pushed to a merged PR. Item 10 at Step 15: a PR
# merged outside the run sends its held Minor fixes to an unprotected base; a closed
# one keeps them on the local commit.
printf '#!/usr/bin/env bash\necho "{\\"eligible\\":${ELIG:-true},\\"ineligible_reason\\":\\"x\\",\\"cr_state\\":\\"success\\",\\"blocking_checks\\":0,\\"ci_state\\":\\"pass\\",\\"failing_checks\\":[],\\"protection_http\\":${PROTO:-404},\\"base_branch\\":\\"main\\"}"\n' \
  > "$R9/gate/scripts/auto-merge-gate.sh"
printf '#!/usr/bin/env bash\necho "base-push $*" >> "%s/calls"; echo pu5h\n' "$R9" > "$R9/gate/scripts/base-push.sh"
cp "$SCRIPTS/words-json.sh" "$R9/gate/scripts/"
printf '#!/usr/bin/env bash\ncase "$1" in rev-parse) echo f1x ;; *) echo "git $*" >> "%s/calls" ;; esac\n' "$R9" > "$R9/bin/git"; chmod +x "$R9/bin/git"
s15x() { # FINAL_STATE -> final_state|merged|calls ; env PR_STATE MERGE_RC PRV_MERGED PROTO ELIG
  : > "$R9/calls"; echo '{"auto_judge_log":[]}' > "$R9/state15.json"
  FS=$1 PATH="$R9/bin:$PATH" SKILL_DIR="$R9/gate" STATE_FILE="$R9/state15.json" \
    BLOCK="$(rb_block "Step 15: auto-merge gate")
$(rb_block "Step 15: merge")" bash -c '
    reviewers_on() { cr_on=true; codex_on=auto; }
    final_state=$FS deferred_total=0 review_total=0 OWNER=o REPO=r PR_NUM=1 ITER=1 merged=false
    AUTO_MERGE=false MERGE_ANSWER=yes REVIEWED_SHA=r3v VERIFY_CMD=true verification_blocking=false
    dropped_reviewers="" pending_decision=""
    eval "$BLOCK"
    printf "%s|%s|%s" "$final_state" "$merged" "$(tr "\n" ";" < "$CALLS")"' 2>/dev/null
}
is "Step 15: merge lands but gh exits 1 -> merged, held fixes to the base" \
   "$(MERGE_RC=1 s15x minor_floor)" 'minor_floor|true|gh pr merge 1 --squash --delete-branch --match-head-commit r3v;base-push main r3v f1x true;'
is "Step 15: gh exits 0 but the PR is not merged -> not merged, fixes to the PR" \
   "$(PRV_MERGED=no s15x minor_floor)" 'minor_floor|false|gh pr merge 1 --squash --delete-branch --match-head-commit r3v;git push;'
is "Step 15: protected base, auto-merge armed though gh exits 1 -> fixes stay local" \
   "$(PROTO=200 MERGE_RC=1 s15x minor_floor)" 'minor_floor|true|gh pr merge 1 --auto --squash --delete-branch --match-head-commit r3v;'
is "Step 15: PR merged outside the run -> merged_externally, held fixes to the base, no merge call" \
   "$(PR_STATE=MERGED s15x minor_floor)" 'merged_externally|true|base-push main r3v f1x true;'
is "Step 15: PR closed outside the run -> merged_externally, fixes stay local" \
   "$(PR_STATE=CLOSED s15x minor_floor)" 'merged_externally|false|'
is "Step 15: merged_externally from Step 12, closed -> nothing pushed" \
   "$(PR_STATE=CLOSED ELIG=false s15x merged_externally)" 'merged_externally|false|'
unset CALLS
rm -f "$R9/bin/git"
is "auto-merge gate: merged_externally is not merge-eligible" \
   "$(FINAL_STATE=merged_externally DEFERRED_TOTAL=0 PATH="$R9/bin:$PATH" bash "$SCRIPTS/auto-merge-gate.sh" o r 42 deadbeef 2>/dev/null | jq -r '.eligible')" false
is "auto-merge gate: merged_externally with a defer files the follow-up issue" \
   "$(FINAL_STATE=merged_externally DEFERRED_TOTAL=1 PATH="$R9/bin:$PATH" bash "$SCRIPTS/auto-merge-gate.sh" o r 42 deadbeef 2>/dev/null | jq -r '.file_issue')" true

# Item 11: after merge_then_main_push HEAD is a local commit GitHub never saw; the CI
# wait's push time is the reviewed HEAD's.
cp "$SCRIPTS/auto-merge-gate.sh" "$SCRIPTS/words-json.sh" "$R9/skill/scripts/"
printf '#!/usr/bin/env bash\necho "{\\"state\\":\\"pass\\",\\"failing\\":[],\\"pending\\":[]}"\n' > "$R9/skill/scripts/ci-checks.sh"
: > "$R9/push-time.args"
(cd "$R9/repo" && PATH="$R9/bin:$PATH" SKILL_DIR="$R9/skill" \
  BLOCK="$(rb_block "Step 14: last-push HEAD verdicts and follow-up trigger")" bash -c '
  reviewers_on() { cr_on=true; codex_on=auto; }
  pushed_this_cycle=false final_state=minor_floor deferred_total=0 review_total=0 HEAD_VERDICT=""
  OWNER=o REPO=r PR_NUM=1 TIMEOUT=1800 INTERVAL=30 REVIEWED_SHA=r3v
  eval "$BLOCK"' >/dev/null 2>&1)
is "Step 14: CI push time read for the reviewed HEAD, not the local commit" "$(head -1 "$R9/push-time.args")" r3v

# Item 8: a fix that also added its regression test committed only the finding's path
# (PR #334 iter 1 left run-tests.sh out). Files the cycle changed beyond the track list
# go in; files dirty before the cycle (the user's) stay out.
printf 'wip.txt\0' > "$R9/dirty.base"
(cd "$R9/repo" && echo fix >> a.sh && echo test >> t.sh && echo new > new_test.sh)
TRK9=$(mktemp); printf 'a.sh\0' > "$TRK9"
(cd "$R9/repo" && bash "$SCRIPTS/stage-and-commit.sh" "$TRK9" 1 "$R9/dirty.base") >/dev/null 2>&1
is "stage-and-commit: the fix's test and new file go in with it" \
   "$(cd "$R9/repo" && git show --name-only --pretty=format: HEAD | sort | tr '\n' ' ')" "a.sh new_test.sh t.sh "
is "stage-and-commit: a file dirty before the cycle stays out" \
   "$(cd "$R9/repo" && git status --porcelain | tr '\n' ' ')" " M wip.txt "
rm -f "$TRK9"
rm -rf "$R9"

# Item 9: an absolute core.hooksPath can point at another checkout's older hook; the
# base push runs the base's own tracked guard first.
BP=$(mktemp -d)
(
  git init -q --bare "$BP/remote.git" && git clone -q "$BP/remote.git" "$BP/w" && cd "$BP/w" \
    && git config user.email t@t && git config user.name t && git checkout -q -b main \
    && mkdir .githooks && printf '#!/bin/sh\necho tracked-guard >&2\nexit 1\n' > .githooks/pre-commit \
    && chmod +x .githooks/pre-commit && printf 'a\n' > f && git add -A && git commit -qm base \
    && git push -q origin main && git checkout -q -b pr && echo b >> f && git commit -qam reviewed \
    && echo c >> f && git commit -qam "fix: minor (review-loop iter 1)" && git push -q origin pr \
    && git checkout -q --detach origin/main && git checkout -q pr~1 -- f && git commit -qm "squash (#1)" \
    && git push -q origin HEAD:main && git checkout -q pr
) >/dev/null 2>&1
mkdir -p "$BP/old-hooks"; printf '#!/bin/sh\necho old-guard >&2\nexit 0\n' > "$BP/old-hooks/pre-commit"; chmod +x "$BP/old-hooks/pre-commit"
git -C "$BP/w" config core.hooksPath "$BP/old-hooks"
before=$(git -C "$BP/remote.git" rev-parse main)
err=$(cd "$BP/w" && bash "$SCRIPTS/base-push.sh" main "$(git rev-parse pr~1)" "$(git rev-parse pr)" true 2>&1 >/dev/null); rc=$?
is "base-push: tracked guard runs before an absolute core.hooksPath" \
   "$rc:$(grep -c tracked-guard <<<"$err"):$(grep -c old-guard <<<"$err"):$([ "$(git -C "$BP/remote.git" rev-parse main)" = "$before" ] && echo kept)" "1:1:0:kept"
rm -rf "$BP"

echo
echo "final_state enum: one set across the schema and every doc that lists it"
# A value the loop can set but a doc or the schema leaves out is a state the
# reader (or the schema check) does not know. Each doc carries one
# "`final_state` enum: `a`, `b`, ..." list, which ends at the first "(" or ".".
ROOT=$(cd "$HERE/../../../../.." && pwd)
SKILL_ROOT=$(cd "$HERE/.." && pwd)
SCHEMA_STATES=$(jq -r '.properties.final_state.enum[]' "$SKILL_ROOT/assets/final-output.schema.json" | sort | tr '\n' ' ')
enum_line() {
  # C locale: a UTF-8 sed on Git Bash mis-parses the emoji further along the same line.
  grep -F '`final_state` enum' "$1" | head -1 | LC_ALL=C sed -n 's/.*`final_state` enum\([^(.]*\).*/\1/p' \
    | grep -oE '`[a-z_]+`' | tr -d '`' | sort -u | tr '\n' ' '
}
not_in_schema() {  # prints each stdin word the schema enum does not list
  local s
  while read -r s; do
    case " $SCHEMA_STATES" in *" $s "*) ;; *) printf '%s ' "$s" ;; esac
  done
}
is "failure-modes.md table = schema enum" \
   "$(grep -oE '^\| `[a-z_]+` \|' "$SKILL_ROOT/references/failure-modes.md" | grep -oE '[a-z_]+' \
      | grep -vx final_state | sort | tr '\n' ' ')" "$SCHEMA_STATES"
for doc in "$SKILL_ROOT/SKILL.md" "$ROOT/plugins/dev/CLAUDE.md" "$ROOT/AGENTS.md"; do
  is "enum line in ${doc#"$ROOT"/} = schema enum" "$(enum_line "$doc")" "$SCHEMA_STATES"
done
# Every literal the run assigns must be a schema value.
is "every final_state=<literal> in SKILL.md and run-blocks.md is in the schema" \
   "$(grep -ohE 'final_state=[a-z_]+' "$SKILL_ROOT/SKILL.md" "$SKILL_ROOT/references/run-blocks.md" \
      | cut -d= -f2 | sort -u | not_in_schema)" ""

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
