#!/usr/bin/env bash
# Usage: bash plugins/dev/skills/post-merge/tests/run-tests.sh
#
# Drives scripts/collect-cleanup.sh against a throwaway repo (bare origin, main
# checkout, linked worktrees) with a PATH gh shim. No network, no live repo.
# Everything this suite creates or removes lives under one mktemp -d.
set -uo pipefail

# Inherited from a pre-commit hook, these send the fixtures' git writes into the
# calling repo (same guard as review-loop's runner).
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECT="$HERE/../scripts/collect-cleanup.sh"
pass=0; fail=0
ok()  { pass=$((pass+1)); [ "${VERBOSE:-0}" = 1 ] && printf '  ok   %s\n' "$1"; return 0; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; }
is()  { [ "$2" = "$3" ] && ok "$1" || bad "$1" "$3" "$2"; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
# pwd -P: macOS mktemp hands out /var/..., which git reports as /private/var/...
T=$(cd "$T" && pwd -P)
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# --- gh shim. Fixtures live under $GH_FIX; every issue/api call is logged to calls.log.
#   pr list --head <branch>   -> <branch, / -> __>.json, a .fail file fails it, else []
#   pr list --base <branch>   -> base-<branch, / -> __>.json, else []
#   repo view                 -> repo.json, missing fails
#   pr view <N>               -> prview-<N>.json
#   issue view <url> | <N> --repo <host/o/r>  -> issue/<host__o__r__issues__N>.json
#   api --hostname <h> <path> -> api/<h__path>.json; a missing .../parent answers GitHub's
#                                404 body (no parent), anything else missing fails
SHIM="$T/shim"; GH_FIX="$T/ghfix"; mkdir -p "$SHIM" "$GH_FIX/issue" "$GH_FIX/api"
cat > "$SHIM/gh" <<'SH'
#!/usr/bin/env bash
flat() { printf '%s' "$1" | sed 's#/#__#g'; }
case "$1 $2" in
  "pr list")
    head=""; base=""
    while [ $# -gt 0 ]; do case "$1" in --head|-H) head=$2; shift;; --base|-B) base=$2; shift;; esac; shift; done
    if [ -n "$base" ]; then f="$GH_FIX/base-$(flat "$base")"; else f="$GH_FIX/$(flat "$head")"; fi
    [ -f "$f.fail" ] && { echo "HTTP 502" >&2; exit 1; }
    [ -f "$f.json" ] && { cat "$f.json"; exit 0; }
    echo '[]' ;;
  "repo view")
    [ -f "$GH_FIX/repo.json" ] || { echo "HTTP 502" >&2; exit 1; }
    cat "$GH_FIX/repo.json" ;;
  "pr view")
    [ -f "$GH_FIX/prview-$3.json" ] || { echo "no pull request $3" >&2; exit 1; }
    cat "$GH_FIX/prview-$3.json" ;;
  "issue view")
    ref=$3; repo=""; shift 3
    while [ $# -gt 0 ]; do case "$1" in --repo|-R) repo=$2; shift;; esac; shift; done
    case "$ref" in https://*) k=${ref#https://} ;; *) k="$repo/issues/$ref" ;; esac
    echo "issue view $k" >> "$GH_FIX/calls.log"
    f="$GH_FIX/issue/$(flat "$k").json"
    [ -f "$f" ] || { echo "Could not resolve to an issue" >&2; exit 1; }
    cat "$f" ;;
  "api "*)
    host=github.com; path=""; shift
    while [ $# -gt 0 ]; do
      case "$1" in --hostname) host=$2; shift;; repos/*) path=$1;; esac; shift
    done
    echo "api $host/$path" >> "$GH_FIX/calls.log"
    f="$GH_FIX/api/$(flat "$host/$path").json"
    [ -f "$f" ] && { cat "$f"; exit 0; }
    case "$path" in */parent)
      echo '{"message":"No parent issue found","status":"404"}'
      echo "gh: No parent issue found (HTTP 404)" >&2; exit 1;;
    esac
    echo "HTTP 500" >&2; exit 1 ;;
  *) echo "shim: unexpected gh $*" >&2; exit 2 ;;
esac
SH
chmod +x "$SHIM/gh"
export GH_FIX
pr() {  # pr <branch> <number> <MERGED|OPEN|CLOSED>; base main, a MERGED PR's merge commit = main's HEAD now
  local mc=null; [ "$3" = MERGED ] && mc="{\"oid\":\"$(g rev-parse HEAD)\"}"
  printf '[{"number":%s,"state":"%s","baseRefName":"main","mergeCommit":%s,"url":"https://github.com/o/r/pull/%s"}]\n' \
    "$2" "$3" "$mc" "$2" > "$GH_FIX/$(printf '%s' "$1" | sed 's#/#__#g').json"
}

# --- fixture repo
M="$T/main"
git init -q --bare "$T/origin.git"
git init -q -b main "$M"
g() { git -C "$M" "$@"; }
printf '.tmp/\n' > "$M/.gitignore"; echo base > "$M/a.txt"
g add -A; g commit -qm base
g remote add origin "$T/origin.git"; g push -q origin main

# wt <name> <branch>: a linked worktree on a new branch with one commit adding <name>.txt
wt() {
  g worktree add -q -b "$2" "$T/$1" main
  echo "$1" > "$T/$1/$1.txt"
  git -C "$T/$1" add -A; git -C "$T/$1" commit -qm "$1"
}

# pick <branch>: land the branch tip on main as a patch-equivalent commit (a rebase merge)
pick() { g cherry-pick "$(g rev-parse "$1")" >/dev/null; }

# merged + clean, landed by rebase (patch-equivalent commit on main), with .tmp material
wt merged feat/merged
mkdir -p "$T/merged/.tmp/research/run1"; printf 'notes\n' > "$T/merged/.tmp/research/run1/notes.md"
pick feat/merged
pr feat/merged 1 MERGED

# merged by squash: two commits on the branch, one different commit on main
wt squash feat-squash
echo more >> "$T/squash/squash.txt"; git -C "$T/squash" commit -qam more
g merge -q --squash feat-squash >/dev/null; g commit -qm "squash (#2)"
pr feat-squash 2 MERGED
# base moves on and edits the same file: the squash still landed, as of its merge commit
echo later >> "$M/squash.txt"; g commit -qam "later edit"

# dirty: merged, then an untracked file
wt dirty feat-dirty
pick feat-dirty
echo wip > "$T/dirty/wip.txt"
pr feat-dirty 3 MERGED

# locked: merged, then locked
wt locked feat-locked
pick feat-locked
g worktree lock --reason "in use" "$T/locked"
pr feat-locked 4 MERGED

# unique: PR merged, then one more commit that never reached main
wt unique feat-unique
pick feat-unique
echo late > "$T/unique/late.txt"; git -C "$T/unique" add -A; git -C "$T/unique" commit -qm late
pr feat-unique 5 MERGED

# orphan: commits, no upstream, no PR at all
wt orphan feat-orphan

# open PR
wt open feat-open
pr feat-open 7 OPEN

# gh failure for this branch must not read as "no PR"
wt ghfail feat-ghfail
: > "$GH_FIX/feat-ghfail.fail"

# detached HEAD: no branch, so no PR to look up
g worktree add -q --detach "$T/detached" main

# prunable: the directory is gone (removed inside this suite's own mktemp dir)
wt gone feat-gone
pr feat-gone 9 MERGED
rm -rf "$T/gone"

# --- remote branches (pushed to the bare origin; main stays checked out in $M)
echo '{"defaultBranchRef":{"name":"main"}}' > "$GH_FIX/repo.json"
# rb <branch>: push a new branch off main with one commit adding r-<branch>.txt
rb() { g checkout -q -b "$1" main; echo "$1" > "$M/r-${1//\//_}.txt"; g add -A; g commit -qm "r $1"
  g push -q origin "$1"; g checkout -q main; }
rb r/merged;  pick r/merged;  pr r/merged 21 MERGED
# squash: two commits on the branch, one different commit on main
rb r/squash; g checkout -q r/squash; echo more >> "$M/r-r_squash.txt"; g commit -qam more
g push -q origin r/squash; g checkout -q main
g merge -q --squash r/squash >/dev/null; g commit -qm "squash (#22)"; pr r/squash 22 MERGED
# unique: merged, then one more commit pushed that never reached main
rb r/unique;  pick r/unique;  pr r/unique 23 MERGED
g checkout -q r/unique; echo late > "$M/r-late.txt"; g add -A; g commit -qm late; g push -q origin r/unique; g checkout -q main
rb r/closed;  pr r/closed 24 CLOSED
rb r/open;    pr r/open 25 OPEN
# no PR, tip already on main
g branch r/contained main~1; g push -q origin r/contained
# no PR, own commit
rb r/nopr
# merged, but the base of another open PR: deleting it would close that PR
rb r/stack;   pick r/stack;   pr r/stack 27 MERGED
echo '[{"number":28}]' > "$GH_FIX/base-r__stack.json"
rb r/ghfail;  : > "$GH_FIX/r__ghfail.fail"
# merged and clean, but checked out in a worktree
git -C "$T/merged" push -q origin feat/merged
g remote set-head origin main

g push -q origin main
g fetch -q origin

out=$(cd "$M" && PATH="$SHIM:$PATH" bash "$COLLECT"); rc=$?
is "exits 0" "$rc" 0
is "valid JSON object with worktrees[]" "$(jq -r '.worktrees | type' <<<"$out" 2>/dev/null)" array
w() { jq -r --arg p "$T/$1" ".worktrees[] | select(.path == \$p) | $2" <<<"$out"; }
has_reason() { jq -r --arg p "$T/$1" --arg r "$2" \
  '[.worktrees[] | select(.path == $p) | .reasons[] | select(startswith($r))] | length > 0' <<<"$out"; }

echo "collect-cleanup.sh worktrees[]"
is "main worktree is not listed" "$(jq -r --arg p "$M" '[.worktrees[] | select(.path == $p)] | length' <<<"$out")" 0
is "lists every linked worktree" "$(jq -r '.worktrees | length' <<<"$out")" 10
is "merged+clean (rebase) -> safe"        "$(w merged .safe)" true
is "merged+clean -> no reasons"           "$(w merged '.reasons | length')" 0
is "merged -> branch name"                "$(w merged .branch)" feat/merged
is "merged -> PR number"                  "$(w merged .pr.number)" 1
is "squash merge, base edited the file later -> safe" "$(w squash .safe)" true
is "dirty -> not safe"                    "$(w dirty .safe)" false
is "dirty -> reason dirty"                "$(has_reason dirty dirty)" true
is "locked -> not safe"                   "$(w locked .safe)" false
is "locked -> reason locked"              "$(has_reason locked locked)" true
is "unique commit after merge -> not safe" "$(w unique .safe)" false
is "unique -> reason unique commits"      "$(has_reason unique 'unique commits')" true
is "orphan, no PR -> not safe"            "$(w orphan .safe)" false
is "orphan -> reason no merged PR"        "$(has_reason orphan 'no merged PR')" true
is "open PR -> not safe"                  "$(w open .safe)" false
is "open PR -> reason names the PR"       "$(has_reason open 'open PR #7')" true
is "gh failure -> not safe"               "$(w ghfail .safe)" false
is "gh failure -> reason, not 'no merged PR'" "$(has_reason ghfail 'gh lookup failed')" true
is "detached -> not safe"                 "$(w detached .safe)" false
is "detached -> reason"                   "$(has_reason detached 'detached HEAD')" true
is "detached -> branch null"              "$(w detached .branch)" null
is "prunable -> not safe"                 "$(w gone .safe)" false
is "prunable -> reason"                   "$(has_reason gone prunable)" true
is ".tmp summary: file count"             "$(w merged .tmp.files)" 1
is ".tmp summary: entry path"             "$(w merged '.tmp.entries[0].path')" .tmp/research/run1/notes.md
is ".tmp summary: entry bytes"            "$(w merged '.tmp.entries[0].bytes')" 6
is ".tmp summary: entry mtime is a number" "$(w merged '.tmp.entries[0].mtime | type')" number
is "no .tmp -> zero files"                "$(w squash .tmp.files)" 0
is "ignored .tmp does not make a worktree dirty" "$(has_reason merged dirty)" false

echo "collect-cleanup.sh remote_branches[]"
rbr() { jq -r --arg n "$1" "[.remote_branches[]? | select(.name == \$n)] | if length == 0 then \"absent\" else (.[0] | $2) end" <<<"$out"; }
rbr_has() { rbr "$1" "[.reasons[] | select(startswith(\"$2\"))] | length > 0"; }
is "remote_branches is an array"           "$(jq -r '.remote_branches | type' <<<"$out")" array
is "fixture: origin/HEAD exists"           "$(g symbolic-ref -q refs/remotes/origin/HEAD)" refs/remotes/origin/main
is "origin/HEAD is not listed"             "$(rbr HEAD .name)" absent
is "default branch -> not safe"            "$(rbr main .safe)" false
is "default branch -> reason"              "$(rbr_has main 'default branch')" true
is "merged (rebase) -> safe"               "$(rbr r/merged .safe)" true
is "merged -> PR number and state"         "$(rbr r/merged '"\(.pr.number) \(.pr.state)"')" "21 MERGED"
is "merged -> head is the remote tip"      "$(rbr r/merged .head)" "$(g rev-parse origin/r/merged)"
is "squash merged -> safe"                 "$(rbr r/squash .safe)" true
is "unique commit after merge -> not safe" "$(rbr r/unique .safe)" false
is "unique -> reason"                      "$(rbr_has r/unique 'unique commits')" true
is "closed without merge -> not safe"      "$(rbr r/closed .safe)" false
is "closed -> reason names the PR"         "$(rbr_has r/closed 'PR #24 closed without merge')" true
is "closed -> PR state reported"           "$(rbr r/closed .pr.state)" CLOSED
is "open PR -> not safe"                   "$(rbr r/open .safe)" false
is "open PR -> reason names the PR"        "$(rbr_has r/open 'open PR #25')" true
is "no PR, tip on origin/main -> safe"     "$(rbr r/contained .safe)" true
is "no PR, tip on origin/main -> pr null"  "$(rbr r/contained .pr)" null
is "no PR, own commit -> not safe"         "$(rbr r/nopr .safe)" false
is "no PR, own commit -> reason"           "$(rbr_has r/nopr 'no PR and not in origin/main')" true
is "base of an open PR -> not safe"        "$(rbr r/stack .safe)" false
is "base of an open PR -> reason"          "$(rbr_has r/stack 'base of open PR #28')" true
is "gh failure -> not safe"                "$(rbr r/ghfail .safe)" false
is "gh failure -> reason"                  "$(rbr_has r/ghfail 'gh lookup failed')" true
is "checked out in a worktree -> not safe" "$(rbr feat/merged .safe)" false
is "checked out -> reason names the path"  "$(rbr_has feat/merged "checked out in $T/merged")" true
is "default branch known -> no remote_error" "$(jq -r '.remote_error // "none"' <<<"$out")" none

# default branch unknown: nothing is listed, and the error says why
mv "$GH_FIX/repo.json" "$GH_FIX/repo.json.off"
out=$(cd "$M" && PATH="$SHIM:$PATH" bash "$COLLECT")
is "default branch unknown -> remote_branches null" "$(jq -r .remote_branches <<<"$out")" null
is "default branch unknown -> remote_error" "$(jq -r '.remote_error | startswith("default branch unknown")' <<<"$out")" true
is "default branch unknown -> worktrees still listed" "$(jq -r '.worktrees | length' <<<"$out")" 10
mv "$GH_FIX/repo.json.off" "$GH_FIX/repo.json"
out=$(cd "$M" && PATH="$SHIM:$PATH" bash "$COLLECT")

# Run from inside a linked worktree: that one is the current session and Step 11 owns it.
out=$(cd "$T/merged" && PATH="$SHIM:$PATH" bash "$COLLECT")
is "current session worktree -> not safe" "$(w merged .safe)" false
is "current session -> reason"            "$(has_reason merged 'current session')" true
is "other worktrees unaffected"           "$(w squash .safe)" true

# --- issues[] (--pr <N>). PR #40 in o/r on github.com targets a non-default base, so
# GitHub honoured none of its keywords and closingIssuesReferences is empty.
flat() { printf '%s' "$1" | sed 's#/#__#g'; }
# iss <host/o/r/N> <state> <title> [pull]: what `gh issue view --json state,title,url` prints
iss() { local kind=issues; [ "${4:-}" = pull ] && kind=pull
  jq -cn --arg s "$2" --arg t "$3" --arg u "https://${1%/*}/$kind/${1##*/}" '{state:$s,title:$t,url:$u}' \
    > "$GH_FIX/issue/$(flat "${1%/*}/issues/${1##*/}").json"; }
# parent <host/o/r/N> <host/o/r/P> <open|closed> <completed> <total>: GET repos/o/r/issues/N/parent
parent() { local c=${1#*/}
  jq -cn --arg u "https://${2%/*}/issues/${2##*/}" --arg s "$3" --argjson n "${2##*/}" \
    --argjson c "$4" --argjson t "$5" \
    '{number:$n,state:$s,title:"spec",html_url:$u,sub_issues_summary:{completed:$c,total:$t}}' \
    > "$GH_FIX/api/$(flat "${1%%/*}/repos/${c%/*}/issues/${1##*/}/parent").json"; }
MC=0123456789abcdef0123456789abcdef01234567
BODY='Closes #10
이 PR 은 #11 의 남은 일을 끝낸다. #41 에서 시작했고 #40 이 이 PR 이다.
Also other/repo#12, https://evil.example/o/r/issues/13 and http://github.com/o/r/issues/18.
Fixes https://github.com/o/r/issues/14
Not refs: &#19; C#20x a/b/c#21'
jq -n --arg mc "$MC" --arg body "$BODY" '{number:40, url:"https://github.com/o/r/pull/40",
  baseRefName:"integration/x", body:$body, closingIssuesReferences:[], mergeCommit:{oid:$mc}}' \
  > "$GH_FIX/prview-40.json"
# two pages, the way --paginate prints them
printf '%s\n%s\n' '[{"commit":{"message":"feat: a\n\nresolved: #15"}}]' '[{"commit":{"message":"chore: b"}}]' \
  > "$GH_FIX/api/$(flat github.com/repos/o/r/pulls/40/commits).json"
printf '%s\n' '{"commit":{"message":"Merge (#40)\n\nfixed #16"}}' \
  > "$GH_FIX/api/$(flat "github.com/repos/o/r/commits/$MC").json"
iss github.com/o/r/10 OPEN ten
iss github.com/o/r/11 OPEN eleven
iss github.com/o/r/41 MERGED "a pr" pull
iss github.com/other/repo/12 OPEN elsewhere
iss github.com/o/r/14 OPEN fourteen
iss github.com/o/r/15 CLOSED fifteen
iss github.com/o/r/16 OPEN sixteen
# #10 and #11 are the last two open children of spec #50 (1 of 3 done): a candidate once they close.
parent github.com/o/r/10 github.com/o/r/50 open 1 3
parent github.com/o/r/11 github.com/o/r/50 open 1 3
# #16's sibling outside this PR is still open: its spec #60 is not a candidate.
parent github.com/o/r/16 github.com/o/r/60 open 0 2
: > "$GH_FIX/calls.log"

out=$(cd "$M" && PATH="$SHIM:$PATH" bash "$COLLECT" --pr 40); rc=$?
is "--pr: exits 0" "$rc" 0
i() { jq -r --arg r "$1" "[.issues[]? | select(.ref == \$r)] | if length == 0 then \"absent\" else (.[0] | $2) end" <<<"$out"; }
echo "collect-cleanup.sh issues[]"
is "--pr keeps worktrees[]"                 "$(jq -r '.worktrees | type' <<<"$out")" array
is "body keyword -> via keyword"            "$(i '#10' .via)" keyword
is "body keyword -> state read"             "$(i '#10' .state)" OPEN
is "body keyword -> title read"             "$(i '#10' .title)" ten
is "body keyword -> url to close by"        "$(i '#10' .url)" https://github.com/o/r/issues/10
is "bare #N in a Korean sentence -> via bare" "$(i '#11' .via)" bare
is "own PR number dropped"                  "$(i '#40' .via)" absent
is "bare #N that is a PR dropped"           "$(i '#41' .via)" absent
is "other-repo ref keeps its qualifier"     "$(i 'other/repo#12' .url)" https://github.com/other/repo/issues/12
is "other-repo ref read with --repo host/owner/repo" \
  "$(grep -c '^issue view github.com/other/repo/issues/12$' "$GH_FIX/calls.log")" 1
is "other-host URL -> unresolved"           "$(i https://evil.example/o/r/issues/13 .state)" null
is "other-host URL -> reason"               "$(i https://evil.example/o/r/issues/13 '.reason | startswith("other host")')" true
is "other-host URL never queried"           "$(grep -c evil.example "$GH_FIX/calls.log")" 0
is "http URL -> unresolved"                 "$(i http://github.com/o/r/issues/18 '.reason | startswith("invalid")')" true
is "keyword + URL -> kept as URL"           "$(i https://github.com/o/r/issues/14 .via)" keyword
is "commit-message keyword"                 "$(i '#15' .via)" keyword
is "closed issue reported with its state"   "$(i '#15' .state)" CLOSED
is "merge-commit message keyword"           "$(i '#16' .via)" keyword
is "entity, C#20x, a/b/c#21 are not refs"   "$(jq -r '[.issues[]?.ref | select(test("19|20|21"))] | length' <<<"$out")" 0
is "commits counted across pages"           "$(jq -r .issue_sources.commits <<<"$out")" 2
is "commit scan not truncated"              "$(jq -r .issue_sources.commits_truncated <<<"$out")" false
is "merge commit read"                      "$(jq -r .issue_sources.merge_commit <<<"$out")" read
p50=https://github.com/o/r/issues/50
is "spec parent, last open children in this PR -> via spec-parent" "$(i "$p50" .via)" spec-parent
is "spec parent -> closes after those children" "$(i "$p50" '.after | join(" ")')" \
  "https://github.com/o/r/issues/10 https://github.com/o/r/issues/11"
is "spec parent with an outside child open -> not a candidate" "$(i https://github.com/o/r/issues/60 .via)" absent

# default base: GitHub linked the issue, the body names it nowhere
jq -n '{number:42, url:"https://github.com/o/r/pull/42", baseRefName:"main", body:"no refs",
  closingIssuesReferences:[{number:17, url:"https://github.com/o/r/issues/17"}], mergeCommit:null}' \
  > "$GH_FIX/prview-42.json"
echo '[]' > "$GH_FIX/api/$(flat github.com/repos/o/r/pulls/42/commits).json"
iss github.com/o/r/17 OPEN linked
out=$(cd "$M" && PATH="$SHIM:$PATH" bash "$COLLECT" --pr 42)
is "closingIssuesReferences -> via closingRef" "$(i https://github.com/o/r/issues/17 .via)" closingRef
is "null merge commit -> skipped, not failed" "$(jq -r .issue_sources.merge_commit <<<"$out")" none

# untrusted text cannot fan out: refs past the cap stay unread
jq -n --arg body "$(seq 100 140 | sed 's/^/#/' | tr '\n' ' ')" '{number:43, url:"https://github.com/o/r/pull/43",
  baseRefName:"main", body:$body, closingIssuesReferences:[], mergeCommit:null}' > "$GH_FIX/prview-43.json"
echo '[]' > "$GH_FIX/api/$(flat github.com/repos/o/r/pulls/43/commits).json"
: > "$GH_FIX/calls.log"
out=$(cd "$M" && PATH="$SHIM:$PATH" bash "$COLLECT" --pr 43)
is "cap: refs past it are unresolved"   "$(jq -r '[.issues[]? | select((.reason // "") | startswith("over the cap"))] | length' <<<"$out")" 16
is "cap: no read past it"               "$(grep -c '^issue view' "$GH_FIX/calls.log")" 25
is "failed read -> unresolved, not closed" "$(i '#100' '.reason | startswith("read failed")')" true

# a failed PR read must not look like "no issues"
out=$(cd "$M" && PATH="$SHIM:$PATH" bash "$COLLECT" --pr 99)
is "PR read fails -> issues null"       "$(jq -r .issues <<<"$out")" null
is "PR read fails -> error reported"    "$(jq -r '.issue_sources.error | length > 0' <<<"$out")" true

# Fixture sanity, not script behaviour: git removes a clean worktree together with its
# ignored .tmp/, which is why SKILL.md moves .tmp material out before the remove.
g worktree remove "$T/squash" >/dev/null 2>&1
is "fixture: no-force remove of a clean worktree succeeds" "$([ -d "$T/squash" ] && echo kept || echo removed)" removed
g worktree remove "$T/merged" >/dev/null 2>&1
is "fixture: ignored .tmp/ goes with the worktree" "$([ -e "$T/merged/.tmp/research/run1/notes.md" ] && echo kept || echo removed)" removed
g worktree remove "$T/dirty" >/dev/null 2>&1
is "fixture: no-force remove refuses a dirty worktree" "$([ -d "$T/dirty" ] && echo kept || echo removed)" kept

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
