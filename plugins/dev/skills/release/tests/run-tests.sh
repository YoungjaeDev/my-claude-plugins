#!/usr/bin/env bash
# Usage: bash plugins/dev/skills/release/tests/run-tests.sh
#
# ci-run-check.sh against a PATH gh shim (issue #394). The never-started fixture is
# trimmed from the real run 41364746682 (v2.78.0): jobs completed/failure with 0 steps,
# runner_id 0, and a billing-lock check-run annotation. No network, no live repo.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/../scripts/ci-run-check.sh"
pass=0; fail=0
ok()  { pass=$((pass+1)); [ "${VERBOSE:-0}" = 1 ] && printf '  ok   %s\n' "$1"; return 0; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; }
is()  { [ "$2" = "$3" ] && ok "$1" || bad "$1" "$3" "$2"; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "contains: $3" "$2" ;; esac; }
lacks() { case "$2" in *"$3"*) bad "$1" "no: $3" "$2" ;; *) ok "$1" ;; esac; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
SHIM="$T/shim"; GH_FIX="$T/fix"; mkdir -p "$SHIM"
# gh api [--paginate] [--slurp] <path>: answers $GH_FIX/<case>/<path with non-alnum -> _>.json,
# a missing fixture is an API error. Every call is logged so tests can see what was asked.
cat > "$SHIM/gh" <<'SH'
#!/usr/bin/env bash
[ "$1" = api ] || { echo "shim: unexpected gh $*" >&2; exit 2; }
shift; path=""
for a in "$@"; do case "$a" in repos/*) path=$a ;; esac; done
echo "$*" >> "$GH_FIX/calls.log"
f="$GH_FIX/$CASE/$(printf '%s' "$path" | sed 's/[^A-Za-z0-9]/_/g').json"
[ -f "$f" ] || { echo "gh: HTTP 502 for $path" >&2; exit 1; }
cat "$f"
SH
chmod +x "$SHIM/gh"
export GH_FIX

# fix <case> <api path> <json>: one slurped response (an array of pages)
fix() { mkdir -p "$GH_FIX/$1"; printf '%s\n' "$3" > "$GH_FIX/$1/$(printf '%s' "$2" | sed 's/[^A-Za-z0-9]/_/g').json"; }
runs_path() { printf 'repos/{owner}/{repo}/actions/runs?branch=%s&event=push&per_page=100' "$1"; }
jobs_path() { printf 'repos/{owner}/{repo}/actions/runs/%s/jobs?filter=latest&per_page=100' "$1"; }
ann_path()  { printf 'repos/{owner}/{repo}/check-runs/%s/annotations' "$1"; }
run() { CASE=$1; shift; : > "$GH_FIX/calls.log"; out=$(CASE=$CASE PATH="$SHIM:$PATH" bash "$CHECK" "$@" 2>"$T/err"); rc=$?; err=$(cat "$T/err"); }

echo "ci-run-check.sh"

# --- 1. never started: the real v2.78.0 shape
fix locked "$(runs_path v2.78.0)" '[{"total_count":1,"workflow_runs":[{"id":41364746682,"name":"validate-codex","head_branch":"v2.78.0","event":"push","status":"completed","conclusion":"failure","html_url":"https://github.com/YoungjaeDev/my-claude-plugins/actions/runs/41364746682"}]}]'
fix locked "$(jobs_path 41364746682)" '[{"total_count":2,"jobs":[
 {"id":125022415689,"name":"check","status":"completed","conclusion":"failure","steps":[],"runner_id":0,"runner_name":"","check_run_url":"https://api.github.com/repos/YoungjaeDev/my-claude-plugins/check-runs/125022415689"},
 {"id":125022415818,"name":"macos","status":"completed","conclusion":"failure","steps":[],"runner_id":0,"runner_name":"","check_run_url":"https://api.github.com/repos/YoungjaeDev/my-claude-plugins/check-runs/125022415818"}]}]'
ANN='[[{"path":".github","annotation_level":"failure","title":"","message":"The job was not started because your account is locked due to a billing issue.","raw_details":""},{"path":".github","annotation_level":"notice","title":"","message":"\"The ubuntu-latest label will migrate to Ubuntu 26 beginning October 19, 2026.\"","raw_details":""}]]'
fix locked "$(ann_path 125022415689)" "$ANN"
fix locked "$(ann_path 125022415818)" "$ANN"
run locked v2.78.0
is    "never-started run exits 0 (a report, not a gate)" "$rc" 0
has   "names the run" "$out" "run 41364746682"
has   "check job flagged never started" "$out" "job check never started"
has   "macos job flagged never started" "$out" "job macos never started"
has   "quotes the failure annotation" "$out" "The job was not started because your account is locked due to a billing issue."
lacks "notice annotations are not quoted" "$out" "Ubuntu 26"
has   "billing lock names Settings, Billing" "$out" "GitHub Settings -> Billing"
has   "asks for --paginate --slurp" "$(cat "$GH_FIX/calls.log")" "--paginate --slurp"

# --- 2. a started run: runner assigned, steps running. Nothing to warn about.
fix started "$(runs_path v1.1.0)" '[{"total_count":1,"workflow_runs":[{"id":7,"name":"validate-codex","status":"in_progress","conclusion":null,"html_url":"https://example/runs/7"}]}]'
fix started "$(jobs_path 7)" '[{"total_count":1,"jobs":[{"id":70,"name":"check","status":"in_progress","conclusion":null,"steps":[{"name":"Set up job","status":"completed"}],"runner_id":12,"runner_name":"GitHub Actions 12","check_run_url":"https://api.github.com/repos/o/r/check-runs/70"}]}]'
run started v1.1.0
is    "started run exits 0" "$rc" 0
has   "started run reports its status" "$out" "run 7 in_progress"
lacks "started run has no warning" "$out" "never started"

# --- 3. queued right after the push (no runner yet) and a skipped job: neither is "never started"
fix queued "$(runs_path v1.2.0)" '[{"total_count":1,"workflow_runs":[{"id":8,"name":"validate-codex","status":"queued","conclusion":null,"html_url":"https://example/runs/8"}]}]'
fix queued "$(jobs_path 8)" '[{"total_count":2,"jobs":[{"id":80,"name":"check","status":"queued","conclusion":null,"steps":[],"runner_id":null,"runner_name":null},{"id":81,"name":"deploy","status":"completed","conclusion":"skipped","steps":[],"runner_id":0,"runner_name":""}]}]'
run queued v1.2.0
has   "queued run reported as queued" "$out" "run 8 queued"
has   "empty conclusion does not shift the url" "$out" "run 8 queued https://example/runs/8"
lacks "queued or skipped job is not never-started" "$out" "never started"

# --- 4. no run for the tag
fix none "$(runs_path v1.3.0)" '[{"total_count":0,"workflow_runs":[]}]'
run none v1.3.0
is    "no run exits 0" "$rc" 0
has   "no run is said out loud" "$out" "no workflow run"

# --- 5. API failure is not "no run"
run broken v9.9.9
is    "API failure exits 1" "$rc" 1
lacks "API failure is not reported as no run" "$out" "no workflow run"
has   "API failure says the CI state is unknown" "$err" "unknown"

# --- 6. never started without a readable annotation: still warned, no billing claim
fix noann "$(runs_path v1.4.0)" '[{"total_count":1,"workflow_runs":[{"id":9,"name":"validate-codex","status":"completed","conclusion":"failure","html_url":"https://example/runs/9"}]}]'
fix noann "$(jobs_path 9)" '[{"total_count":1,"jobs":[{"id":90,"name":"check","status":"completed","conclusion":"failure","steps":[],"runner_id":0,"runner_name":"","check_run_url":"https://api.github.com/repos/o/r/check-runs/90"}]}]'
run noann v1.4.0
has   "unannotated never-started job still flagged" "$out" "job check never started"
lacks "no billing hint without a billing annotation" "$out" "Billing"
has   "missing annotation is marked unread" "$out" "annotation unread"

# --- 7. usage
run none
is    "missing tag is a usage error" "$rc" 2

printf 'release ci-run-check: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
