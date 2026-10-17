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

# --- gh shim: `pr list --head <branch> ...` answers from $GH_FIX/<branch, / -> __>.json,
# fails for a .fail file, and prints [] when neither exists.
SHIM="$T/shim"; GH_FIX="$T/ghfix"; mkdir -p "$SHIM" "$GH_FIX"
cat > "$SHIM/gh" <<'SH'
#!/usr/bin/env bash
[ "$1 $2" = "pr list" ] || { echo "shim: unexpected gh $*" >&2; exit 2; }
head=""
while [ $# -gt 0 ]; do
  case "$1" in --head|-H) head=$2; shift;; esac
  shift
done
f="$GH_FIX/$(printf '%s' "$head" | sed 's#/#__#g')"
[ -f "$f.fail" ] && { echo "HTTP 502" >&2; exit 1; }
[ -f "$f.json" ] && { cat "$f.json"; exit 0; }
echo '[]'
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

# Run from inside a linked worktree: that one is the current session and Step 11 owns it.
out=$(cd "$T/merged" && PATH="$SHIM:$PATH" bash "$COLLECT")
is "current session worktree -> not safe" "$(w merged .safe)" false
is "current session -> reason"            "$(has_reason merged 'current session')" true
is "other worktrees unaffected"           "$(w squash .safe)" true

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
