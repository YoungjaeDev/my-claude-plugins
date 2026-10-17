#!/usr/bin/env bash
# Usage: bash collect-cleanup.sh        (run anywhere inside the repo or one of its worktrees)
#
# Read-only collector for post-merge. Prints one JSON object:
#   {"main_repo": "...", "worktrees": [ {path, branch, head, safe, reasons[], pr, tmp} ]}
# A worktree is safe only when every check passes: a merged PR for its branch (gh),
# no open PR, clean, not locked, not prunable, not the current session's worktree,
# and no unique commits: every commit patch-equivalent to one in origin/<base> (git
# cherry), or, for a squash merge, the branch's files identical to the PR's merge
# commit, which must itself be in origin/<base>. Merge state comes from gh only;
# cherry and the content diff are evidence of "no unique commits", never of "merged".
# It never fetches, removes or writes.
# Needs: git, jq, gh (authenticated). Run after `git fetch origin` (post-merge Step 3).
set -u

die() { echo "collect-cleanup: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq not found"

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

# check <path> <head> <branchref> <locked> <prunable>: one worktrees[] element.
check() {
  local path=$1 head=$2 ref=$3 locked=$4 prunable=$5
  local branch="${ref#refs/heads/}" reasons="" pr="null" prs base mc st ch plus=0 l f
  add() { reasons="$reasons$1"$'\n'; }

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
  elif ! prs=$(cd "$MAIN_REPO" && gh pr list --head "$branch" --state all \
        --json number,state,baseRefName,mergeCommit,url --limit 20 2>/dev/null) \
      || ! jq -e 'type == "array"' >/dev/null 2>&1 <<<"$prs"; then
    add "gh lookup failed: merge state unknown"
  else
    local open; open=$(jq -r '[.[] | select(.state == "OPEN") | "#\(.number)"] | join(", ")' <<<"$prs")
    [ -n "$open" ] && add "open PR $open"
    pr=$(jq -c 'map(select(.state == "MERGED")) | first // null' <<<"$prs")
    if [ "$pr" = "null" ]; then
      add "no merged PR for branch $branch"
    else
      base=$(jq -r '.baseRefName' <<<"$pr")
      mc=$(jq -r '.mergeCommit.oid // empty' <<<"$pr")
      if [ -z "$mc" ]; then
        add "merged PR has no merge commit: content unverified"
      elif ! git -C "$MAIN_REPO" merge-base --is-ancestor "$mc" "refs/remotes/origin/$base" 2>/dev/null; then
        add "merge commit ${mc:0:12} not in origin/$base: fetch first"
      else
        # A failed cherry must not read as "no unique commits".
        if ! ch=$(git -C "$MAIN_REPO" cherry "origin/$base" "$ref" 2>/dev/null); then
          add "git cherry failed: unique commits unknown"; ch=""
        fi
        while IFS= read -r l; do case "$l" in "+ "*) plus=$((plus+1));; esac; done <<<"$ch"
        if [ "$plus" -gt 0 ]; then
          # Squash merge: the commits differ but their content may have landed. Compare
          # every file the branch changed with the PR's merge commit, not the base tip:
          # later merges that edit the same files would otherwise read as unique work.
          local mb files=(); mb=$(git -C "$MAIN_REPO" merge-base "$mc" "$ref" 2>/dev/null)
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
        fi
      fi
    fi
  fi

  jq -cn --arg path "$path" --arg branch "$branch" --arg head "$head" \
     --arg reasons "$reasons" --argjson pr "$pr" --argjson tmp "$(tmp_summary "$path")" \
     '($reasons | split("\n") | map(select(. != ""))) as $r
      | {path:$path, branch:(if $branch == "" then null else $branch end), head:$head,
         safe:($r | length == 0), reasons:$r, pr:$pr, tmp:$tmp}'
}

# Porcelain -z: one NUL-terminated attribute per field, an empty field ends a record.
# The first record is the main worktree (or the bare repo), which is never a candidate.
out=""; first=1; path=""; head=""; ref=""; locked=0; prunable=0; bare=0
flush() {
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

printf '%s' "$out" | jq -s --arg main "$MAIN_REPO" '{main_repo:$main, worktrees:.}'
