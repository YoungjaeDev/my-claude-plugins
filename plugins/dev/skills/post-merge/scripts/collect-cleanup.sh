#!/usr/bin/env bash
# Usage: bash collect-cleanup.sh [--pr <N>]   (run anywhere inside the repo or one of its worktrees)
#
# Read-only collector for post-merge. Prints one JSON object:
#   {"main_repo": "...", "worktrees": [ {path, branch, head, safe, reasons[], pr, tmp} ],
#    "remote_branches": [ {name, head, safe, reasons[], pr} ] | null, "remote_error"?: "..."}
# (remote rules above the remote_branches section below).
# With --pr <N> (the merged PR) it adds the issues that PR names, each with its state read
# (see collect_issues below for the sources and the ref-safety rules):
#   "issues": [ {ref, via: keyword|bare|closingRef|spec-parent, state, title, url, reason?, after?} ],
#   "issue_sources": {commits, commits_truncated, merge_commit, error?}
# A worktree is safe only when every check passes: a merged PR for its branch (gh),
# no open PR, clean, not locked, not prunable, not the current session's worktree,
# and no unique commits: every commit patch-equivalent to one in origin/<base> (git
# cherry), or, for a squash merge, the branch's files identical to the PR's merge
# commit, which must itself be in origin/<base>. Merge state comes from gh only;
# cherry and the content diff are evidence of "no unique commits", never of "merged".
# It never fetches, removes or writes.
# Needs: git, jq, gh (authenticated). Run after `git fetch origin` (post-merge Step 3).
set -u

jq_lf="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../scripts/jq-lf.sh"; if [ -f "$jq_lf" ]; then . "$jq_lf"; fi  # drops CR from Windows jq output; absent in test copies
die() { echo "collect-cleanup: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq not found"

PR_NUM=""
while [ $# -gt 0 ]; do
  case "$1" in
    --pr) PR_NUM=${2:-}
          case "$PR_NUM" in ''|*[!0-9]*) die "--pr takes a PR number, got: '$PR_NUM'" ;; esac
          shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || die "not inside a git repository"
MAIN_REPO=$(dirname "$common")
# The worktree this shell runs in: post-merge Step 11 prints its removal command instead.
SELF=$(git rev-parse --show-toplevel 2>/dev/null) || SELF=""
[ -n "$SELF" ] && SELF=$(cd "$SELF" && pwd -P)

# Probed once for its status: the -z listing below is read through process substitution
# (a shell variable cannot hold NUL), which drops the exit code.
git -C "$MAIN_REPO" worktree list --porcelain >/dev/null || die "git worktree list failed"

# tmp_summary <worktree>: files under <worktree>/.tmp with size and mtime (epoch), first 50 listed.
tmp_summary() {
  local root=$1 f sz mt n=0 bytes=0 entries=""
  if [ -d "$root/.tmp" ]; then
    while IFS= read -r -d '' f; do
      # GNU stat first, BSD stat as the fallback.
      read -r sz mt <<EOF
$(stat -c '%s %Y' "$f" 2>/dev/null || stat -f '%z %m' "$f" 2>/dev/null)
EOF
      case "$sz$mt" in ''|*[!0-9]*) sz=0; mt=0;; esac
      n=$((n+1)); bytes=$((bytes+sz))
      [ "$n" -le 50 ] && entries="$entries$(jq -cn --arg p "${f#"$root"/}" --argjson b "$sz" --argjson m "$mt" \
        '{path:$p, bytes:$b, mtime:$m}')"$'\n'
    done < <(find "$root/.tmp" -type f -print0 2>/dev/null)
  fi
  printf '%s' "$entries" | jq -cs --argjson n "$n" --argjson b "$bytes" \
    '{files:$n, bytes:$b, entries:., truncated:($n > (. | length))}'
}

# add <reason>: append to the calling check's local $reasons (bash scoping is dynamic).
add() { reasons="$reasons$1"$'\n'; }

# add_open_prs: add "open PR #N, #M" for the open ones in $PRS (prs_for's result).
add_open_prs() {
  local open
  open=$(jq -r '[.[] | select(.state == "OPEN") | "#\(.number)"] | join(", ")' <<<"$PRS")
  [ -n "$open" ] && add "open PR $open"
  return 0
}

# entry <jq-args...> <filter>: one element, the filter's object plus safe and reasons[]
# from the calling check's $reasons. The filter is the last argument.
entry() {
  local n=$# filter
  filter=${!n}
  jq -cn --arg reasons "$reasons" "${@:1:n-1}" \
    "($filter) as \$o | (\$reasons | split(\"\\n\") | map(select(. != \"\"))) as \$r
     | \$o + {safe: (\$r | length == 0), reasons: \$r}"
}

# prs_for <branch>: set PRS to gh's PRs with that head branch; fails when gh does.
prs_for() {
  PRS=$(cd "$MAIN_REPO" && gh pr list --head "$1" --state all \
        --json number,state,baseRefName,mergeCommit,url --limit 20 2>/dev/null </dev/null) \
    && jq -e 'type == "array"' >/dev/null 2>&1 <<<"$PRS"
}

# landed <merged-pr-json> <ref>: add a reason unless the PR's merge commit is in
# origin/<base> and <ref> holds nothing that merge commit lacks.
landed() {
  local pr=$1 ref=$2 base mc ch plus=0 l f mb files=()
  base=$(jq -r '.baseRefName' <<<"$pr")
  mc=$(jq -r '.mergeCommit.oid // empty' <<<"$pr")
  if [ -z "$mc" ]; then
    add "merged PR has no merge commit: content unverified"; return 0
  elif ! git -C "$MAIN_REPO" merge-base --is-ancestor "$mc" "refs/remotes/origin/$base" 2>/dev/null; then
    add "merge commit ${mc:0:12} not in origin/$base: fetch first"; return 0
  fi
  # A failed cherry must not read as "no unique commits".
  if ! ch=$(git -C "$MAIN_REPO" cherry "origin/$base" "$ref" 2>/dev/null); then
    add "git cherry failed: unique commits unknown"; ch=""
  fi
  while IFS= read -r l; do case "$l" in "+ "*) plus=$((plus+1));; esac; done <<<"$ch"
  [ "$plus" -gt 0 ] || return 0
  # Squash merge: the commits differ but their content may have landed. Compare
  # every file the branch changed with the PR's merge commit, not the base tip:
  # later merges that edit the same files would otherwise read as unique work.
  mb=$(git -C "$MAIN_REPO" merge-base "$mc" "$ref" 2>/dev/null)
  if [ -n "$mb" ]; then
    while IFS= read -r -d '' f; do files+=("$f"); done \
      < <(git -C "$MAIN_REPO" diff -z --name-only "$mb" "$ref" 2>/dev/null)
  fi
  if [ -z "$mb" ]; then
    add "unique commits not in origin/$base: $plus (no merge base)"
  elif [ "${#files[@]}" -gt 0 ] && ! git --literal-pathspecs -C "$MAIN_REPO" \
         diff --quiet "$mc" "$ref" -- "${files[@]}"; then
    add "unique commits not in origin/$base: $plus"
  fi
}

# check <path> <head> <branchref> <locked> <prunable>: one worktrees[] element.
check() {
  local path=$1 head=$2 ref=$3 locked=$4 prunable=$5
  local branch="${ref#refs/heads/}" reasons="" pr="null" st

  [ "$path" = "$SELF" ] && add "current session: post-merge Step 11 prints its removal command"
  [ "$locked" = 1 ] && add "locked"
  if [ "$prunable" = 1 ] || [ ! -d "$path" ]; then
    add "prunable: directory is gone, run git worktree prune"
  else
    # --porcelain leaves ignored files out, so an ignored .tmp/ does not count as dirty.
    if ! st=$(git -C "$path" status --porcelain 2>/dev/null); then add "dirty: git status failed"
    elif [ -n "$st" ]; then add "dirty: $(printf '%s\n' "$st" | wc -l | tr -d ' ') modified or untracked paths"; fi
  fi

  if [ -z "$ref" ]; then
    add "detached HEAD: no branch to look up"
  elif ! prs_for "$branch"; then
    add "gh lookup failed: merge state unknown"
  else
    add_open_prs
    pr=$(jq -c 'map(select(.state == "MERGED")) | first // null' <<<"$PRS")
    if [ "$pr" = "null" ]; then add "no merged PR for branch $branch"
    else landed "$pr" "$ref"; fi
  fi

  entry --arg path "$path" --arg branch "$branch" --arg head "$head" \
     --argjson pr "$pr" --argjson tmp "$(tmp_summary "$path")" \
     '{path:$path, branch:(if $branch == "" then null else $branch end), head:$head, pr:$pr, tmp:$tmp}'
}

# Porcelain -z: one NUL-terminated attribute per field, an empty field ends a record.
# The first record is the main worktree (or the bare repo), which is never a candidate.
# CHECKED: "<branch>\t<path>" for every worktree with a branch checked out, the main one too.
out=""; CHECKED=""; first=1; path=""; head=""; ref=""; locked=0; prunable=0; bare=0
flush() {
  [ -n "$ref" ] && CHECKED="$CHECKED${ref#refs/heads/}"$'\t'"$path"$'\n'
  if [ -n "$path" ]; then
    if [ "$first" = 1 ] || [ "$bare" = 1 ]; then first=0
    else
      [ -d "$path" ] && path=$(cd "$path" && pwd -P)
      out="$out$(check "$path" "$head" "$ref" "$locked" "$prunable")"$'\n'
    fi
  fi
  path=""; head=""; ref=""; locked=0; prunable=0; bare=0
}
while IFS= read -r -d '' line; do
  case "$line" in
    "") flush ;;
    "worktree "*) path=${line#worktree } ;;
    "HEAD "*) head=${line#HEAD } ;;
    "branch "*) ref=${line#branch } ;;
    locked|"locked "*) locked=1 ;;
    prunable|"prunable "*) prunable=1 ;;
    bare) bare=1 ;;
  esac
done < <(git -C "$MAIN_REPO" worktree list --porcelain -z)
flush

# --- remote_branches[] -------------------------------------------------------------------
# Every refs/remotes/origin/* branch (origin/HEAD aside), checked against the fetched refs.
# Never safe: the default branch, a branch checked out in any worktree, the head or the base
# of an open PR (deleting a base closes the PRs on it), a PR closed without merge, a failed
# gh lookup. Safe: a merged PR and no unique commits (landed, as for worktrees), or no PR
# at all and the tip already in origin/<default>.
REMOTE_JSON=null; REMOTE_ERR=""
# rcheck <name> <head>: one remote_branches[] element.
rcheck() {
  local name=$1 head=$2 ref="refs/remotes/origin/$1" reasons="" pr=null wt based
  if [ "$name" = "$DEFAULT" ]; then
    add "default branch"
  else
    wt=$(awk -F'\t' -v b="$name" '$1 == b { print $2; exit }' <<<"$CHECKED")
    [ -n "$wt" ] && add "checked out in $wt"
    if ! prs_for "$name"; then
      add "gh lookup failed: PR state unknown"
    else
      add_open_prs
      pr=$(jq -c '(map(select(.state == "MERGED")) | first) // (map(select(.state == "OPEN")) | first)
                  // first // null' <<<"$PRS")
      case "$(jq -r '.state? // "none"' <<<"$pr")" in
        MERGED) landed "$pr" "$ref" ;;
        CLOSED) add "PR #$(jq -r .number <<<"$pr") closed without merge" ;;
        none) git -C "$MAIN_REPO" merge-base --is-ancestor "$ref" "refs/remotes/origin/$DEFAULT" 2>/dev/null \
                || add "no PR and not in origin/$DEFAULT" ;;
      esac
    fi
    if ! based=$(cd "$MAIN_REPO" && gh pr list --base "$name" --state open --json number --limit 20 2>/dev/null </dev/null) \
       || ! based=$(jq -er 'if type == "array" then map("#\(.number)") | join(", ") else error end' <<<"$based" 2>/dev/null); then
      add "gh lookup failed: open PRs based on it unknown"
    elif [ -n "$based" ]; then
      add "base of open PR $based"
    fi
  fi
  entry --arg name "$name" --arg head "$head" --argjson pr "$pr" '{name:$name, head:$head, pr:$pr}'
}
if ! DEFAULT=$(cd "$MAIN_REPO" && gh repo view --json defaultBranchRef 2>/dev/null </dev/null) \
   || ! DEFAULT=$(jq -er '.defaultBranchRef.name | select(type == "string" and . != "")' <<<"$DEFAULT" 2>/dev/null); then
  REMOTE_ERR="default branch unknown: gh repo view failed, no remote branch checked"
elif ! rrefs=$(git -C "$MAIN_REPO" for-each-ref --format='%(objectname) %(refname)' refs/remotes/origin/); then
  REMOTE_ERR="git for-each-ref failed"
else
  # A refname holds no space or newline (git check-ref-format), so one line per ref is exact.
  rows=""
  while read -r sha r; do
    [ -n "$r" ] && [ "$r" != refs/remotes/origin/HEAD ] || continue
    rows="$rows$(rcheck "${r#refs/remotes/origin/}" "$sha")"$'\n'
  done <<<"$rrefs"
  REMOTE_JSON=$(printf '%s' "$rows" | jq -cs .)
fi

# --- issues[] (--pr only) ---------------------------------------------------------------
# Sources: the PR body, every PR commit message, the merge commit's message (a message typed
# in GitHub's merge dialog is in no PR commit) and closingIssuesReferences (a sidebar link is
# in no text). A ref after one of the nine closing keywords (any case, optional colon) is
# via=keyword; any other ref is via=bare. A ref is #N, OWNER/REPO#N or an issue URL.
# Safety rules, because the text is anyone's:
#  - every ref matches HASH_RE or URL_RE before it reaches a command line;
#  - a URL ref is https and on the PR's own host, or it is listed and never queried;
#  - a URL stays a URL (it carries its host); a # ref keeps its qualifier and is read with
#    --repo <host>/<owner/repo>, since gh resolves an unqualified --repo against github.com;
#  - at most ISSUE_CAP refs are read; the rest, and every failed read, are unresolved
#    (state null, a reason), never "not open";
#  - issues and PRs share one number space: this PR's own number, and any ref gh resolves
#    to a pull request, drop out.
# Spec parent: each read issue's GitHub sub-issue parent (GET .../issues/N/parent, 404 = none)
# is a candidate when it is open and every child still open was read OPEN here; `after`
# lists those children, so the parent closes only once they have.
ISSUE_CAP=25
HASH_RE='^([A-Za-z0-9._-]+/[A-Za-z0-9._-]+)?#[0-9]+$'
URL_RE='^https://([^/[:space:]]+)/([A-Za-z0-9._-]+/[A-Za-z0-9._-]+)/issues/([0-9]+)$'
ISSUES_JSON=null; SOURCES_JSON=null

# unres <ref> <via> <reason>: one unresolved issues[] row
unres() { jq -cn --arg r "$1" --arg v "$2" --arg why "$3" \
  '{ref:$r, via:$v, state:null, title:null, url:null, reason:$why}'; }

collect_issues() {
  local pv url host repo raw cm="[]" ncommits=null trunc=false mc msg="" mstate=none
  local refs via ref res iurl irepo inum p n=0 rows="" parents="" args
  local pr_re='^https://([^/[:space:]]+)/([A-Za-z0-9._-]+/[A-Za-z0-9._-]+)/pull/[0-9]+$'
  if ! pv=$(cd "$MAIN_REPO" && gh pr view "$PR_NUM" \
        --json number,url,body,closingIssuesReferences,mergeCommit 2>/dev/null </dev/null); then
    SOURCES_JSON=$(jq -cn --arg e "gh pr view $PR_NUM failed" '{error:$e}'); return
  fi
  url=$(jq -r '.url // empty' <<<"$pv" 2>/dev/null)
  if ! [[ $url =~ $pr_re ]]; then
    SOURCES_JSON=$(jq -cn --arg e "PR url not recognised: $url" '{error:$e}'); return
  fi
  host=${BASH_REMATCH[1]}; repo=${BASH_REMATCH[2]}

  # --paginate prints one array per page; a failed fetch is reported as commits:null.
  if raw=$(cd "$MAIN_REPO" && gh api --hostname "$host" --paginate \
        "repos/$repo/pulls/$PR_NUM/commits" 2>/dev/null </dev/null) \
     && cm=$(jq -cs 'add // [] | map(.commit.message // "")' <<<"$raw" 2>/dev/null); then
    ncommits=$(jq length <<<"$cm")
    # The endpoint stops at 250 commits and --paginate does not lift it.
    [ "$ncommits" -ge 250 ] && trunc=true
  else
    cm="[]"
  fi

  mc=$(jq -r '.mergeCommit.oid // empty' <<<"$pv")
  if [ -n "$mc" ]; then
    mstate=failed
    case "$mc" in *[!0-9a-f]*) ;; *)
      raw=$(cd "$MAIN_REPO" && gh api --hostname "$host" "repos/$repo/commits/$mc" 2>/dev/null </dev/null) \
        && msg=$(jq -er '.commit.message' <<<"$raw" 2>/dev/null) && mstate=read || msg="" ;;
    esac
  fi

  # Extract, key on host/owner/repo#N, drop this PR, keep the strongest via per issue.
  refs=$(jq -r --arg host "$host" --arg repo "$repo" --arg pr "$PR_NUM" --argjson cm "$cm" --arg mm "$msg" '
    ("(?:\\b((?i:close[sd]?|fix(?:e[sd])?|resolve[sd]?)):?\\s+)?(?<![A-Za-z0-9_&/#.-])"
     + "(https?://[^\\s/]+/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/issues/[0-9]+"
     + "|(?:[A-Za-z0-9._-]+/[A-Za-z0-9._-]+)?#[0-9]+)(?![A-Za-z0-9_])") as $re
    | def key: (if test("^https?://") then sub("^https?://"; "") | sub("/issues/"; "#")
                elif test("/") then "\($host)/" + . else "\($host)/\($repo)" + . end) | ascii_downcase;
      [ (.body // ""), $cm[], $mm | match($re; "g").captures
        | {via: (if .[0].string then "keyword" else "bare" end), ref: .[1].string} ]
    + [ .closingIssuesReferences[]?.url // empty | {via: "closingRef", ref: .} ]
    | map(. + {key: (.ref | key), rank: {keyword: 0, closingRef: 1, bare: 2}[.via]})
    | map(select(.key != ("\($host)/\($repo)#\($pr)" | ascii_downcase)))
    | group_by(.key) | map(min_by(.rank)) | sort_by(.rank, .key)
    | .[] | "\(.via)\t\(.ref)"' <<<"$pv")

  while IFS=$'\t' read -r via ref; do
    [ -n "$ref" ] || continue
    if [[ $ref =~ $URL_RE ]]; then
      if [ "${BASH_REMATCH[1]}" != "$host" ]; then
        rows="$rows$(unres "$ref" "$via" "other host ${BASH_REMATCH[1]}: not queried")"$'\n'; continue
      fi
      args=("$ref")
    elif [[ $ref =~ $HASH_RE ]]; then
      args=("${ref##*#}" --repo "$host/${BASH_REMATCH[1]:-$repo}")
    else
      rows="$rows$(unres "$ref" "$via" "invalid ref: only an https issue URL or [OWNER/REPO]#N")"$'\n'; continue
    fi
    n=$((n+1))
    if [ "$n" -gt "$ISSUE_CAP" ]; then
      rows="$rows$(unres "$ref" "$via" "over the cap of $ISSUE_CAP refs: not read")"$'\n'; continue
    fi
    if ! res=$(cd "$MAIN_REPO" && gh issue view "${args[@]}" --json state,title,url 2>/dev/null </dev/null) \
       || ! iurl=$(jq -er '.url' <<<"$res" 2>/dev/null); then
      rows="$rows$(unres "$ref" "$via" "read failed: state unknown")"$'\n'; continue
    fi
    case "$iurl" in */pull/*) continue ;; esac
    if ! [[ $iurl =~ $URL_RE ]] || [ "${BASH_REMATCH[1]}" != "$host" ]; then
      rows="$rows$(unres "$ref" "$via" "gh answered with an unexpected url: $iurl")"$'\n'; continue
    fi
    irepo=${BASH_REMATCH[2]}; inum=${BASH_REMATCH[3]}
    rows="$rows$(jq -c --arg r "$ref" --arg v "$via" '{ref:$r, via:$v, state, title, url}' <<<"$res")"$'\n'

    if p=$(cd "$MAIN_REPO" && gh api --hostname "$host" "repos/$irepo/issues/$inum/parent" 2>/dev/null </dev/null); then
      url=$(jq -r '.html_url // empty' <<<"$p" 2>/dev/null)
      if [[ $url =~ $URL_RE ]] && [ "${BASH_REMATCH[1]}" = "$host" ]; then
        parents="$parents$(jq -c --arg c "$iurl" --arg cs "$(jq -r .state <<<"$res")" \
          '{url:.html_url, state:(.state // "" | ascii_upcase), title,
            done:(.sub_issues_summary.completed // -1), total:(.sub_issues_summary.total // -2),
            child:$c, child_state:$cs}' <<<"$p")"$'\n'
      else
        rows="$rows$(unres "parent of $iurl" spec-parent "unexpected parent url: $url")"$'\n'
      fi
    elif [ "$(jq -r '.status? // empty' <<<"$p" 2>/dev/null)" != 404 ]; then
      rows="$rows$(unres "parent of $iurl" spec-parent "parent lookup failed: spec parent unknown")"$'\n'
    fi
  done <<<"$refs"

  ISSUES_JSON=$({ printf '%s' "$rows" | jq -cs .; printf '%s' "$parents" | jq -cs .; } | jq -cs '
    .[0] as $rows
    | $rows + (.[1] | group_by(.url) | map(
        .[0] as $p
        | ([.[] | select(.child_state == "OPEN") | .child] | unique) as $open
        | select($p.state == "OPEN" and ($p.total - $p.done) == ($open | length)
                 and (any($rows[]; .url == $p.url) | not))
        | {ref:$p.url, via:"spec-parent", state:$p.state, title:$p.title, url:$p.url, after:$open}))')
  SOURCES_JSON=$(jq -cn --argjson c "$ncommits" --argjson t "$trunc" --arg m "$mstate" \
    '{commits:$c, commits_truncated:$t, merge_commit:$m}')
}
[ -n "$PR_NUM" ] && collect_issues

printf '%s' "$out" | jq -s --arg main "$MAIN_REPO" --argjson issues "$ISSUES_JSON" --argjson src "$SOURCES_JSON" \
  --argjson rb "$REMOTE_JSON" --arg rerr "$REMOTE_ERR" \
  '{main_repo:$main, worktrees:., remote_branches:$rb}
   + (if $rerr == "" then {} else {remote_error:$rerr} end)
   + (if $src == null then {} else {issues:$issues, issue_sources:$src} end)'
