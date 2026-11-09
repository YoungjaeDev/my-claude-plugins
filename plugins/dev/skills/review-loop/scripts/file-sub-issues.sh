#!/usr/bin/env bash
# Usage: STATE_FILE=... bash scripts/file-sub-issues.sh OWNER REPO PARENT PR_NUM
#
# Step 14 (references/failure-modes.md, "Follow-up issue block"): when this run
# deferred more than SUB_ISSUE_THRESHOLD findings, files one sub-issue per finding
# under the follow-up issue PARENT (GitHub sub-issues REST API). Prints one JSON line:
#   {"split":"none|sub_issues|task_list|failed", "sub_issues":[numbers filed now],
#    "unlinked":[{key, number, id}]}
#
#   none       at most SUB_ISSUE_THRESHOLD defers: the parent alone, as before
#   sub_issues every finding has a sub-issue (one filed earlier is not filed again)
#   task_list  the sub-issues API failed, so the findings without one were added to
#              the parent body as a task list (also deduplicated on a re-run)
#   failed     the parent body could not be read or edited
#
# A finding is keyed by its source and comment id (path:line without one); the key
# rides in each sub-issue body and task item as an HTML comment, which is what makes
# a re-run on the same parent idempotent. A failed listing is never read as "no
# sub-issues": that would file every finding a second time. An issue created but not
# linked is in no listing, so it is reported in `unlinked` (the caller keeps it in
# followup_issue.unlinked) and a re-run links it instead of filing it again.
# Exit 1 only on `failed`.
set -uo pipefail

jq_lf="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../scripts/jq-lf.sh"; if [ -f "$jq_lf" ]; then . "$jq_lf"; fi  # drops CR from Windows jq output; absent in test copies
OWNER="${1:?owner required}"; REPO="${2:?repo required}"; PARENT="${3:?parent required}"; PR_NUM="${4:?pr required}"
: "${STATE_FILE:?STATE_FILE required}"

# The one place the split threshold lives (#389: 5 is an assumption, easy to change).
SUB_ISSUE_THRESHOLD=5

tmpd=$(mktemp -d); trap 'rm -rf "$tmpd"' EXIT
emit() { jq -nc --arg s "$1" --argjson n "$(jq -sc '.' "$tmpd/filed" 2>/dev/null || echo '[]')" \
  --argjson u "$unlinked" '{split:$s, sub_issues:$n, unlinked:$u}'; }
: > "$tmpd/filed"
unlinked=$(jq -c '[.followup_issue.unlinked[]? | select(.key and .number and .id)]' "$STATE_FILE" 2>/dev/null) || unlinked='[]'

defers=$(jq -c '[.auto_judge_log[]? | select(.action == "defer")
  | . + {key: "review-loop-finding:\(.src):\(.comment_id // "\(.path):\(.line // "-")")"}]' "$STATE_FILE") \
  || { echo "file-sub-issues: state file unreadable" >&2; emit failed; exit 1; }
[ "$(jq 'length' <<<"$defers")" -gt "$SUB_ISSUE_THRESHOLD" ] || { emit none; exit 0; }

# Everything already filed for this parent: its sub-issues' bodies and its own body.
parent=$(gh api "repos/$OWNER/$REPO/issues/$PARENT"); rc=$?
pbody=$(jq -r '.body // ""' <<<"$parent" 2>/dev/null)
if [ "$rc" -ne 0 ] || [ -z "$pbody" ]; then
  echo "file-sub-issues: could not read issue #$PARENT; no sub-issue filed, body left as is" >&2
  emit failed; exit 1
fi
printf '%s\n' "$pbody" > "$tmpd/seen"
mode=sub_issues
pages=$(gh api --paginate --slurp "repos/$OWNER/$REPO/issues/$PARENT/sub_issues?per_page=100"); rc=$?
if [ "$rc" -eq 0 ] && jq -r 'add // [] | .[].body // ""' <<<"$pages" >> "$tmpd/seen" 2>/dev/null; then :; else
  echo "file-sub-issues: sub-issues of #$PARENT could not be listed; findings go to its body as a task list" >&2
  mode=task_list
fi

: > "$tmpd/tasks"
while IFS= read -r rec; do
  key=$(jq -r '.key' <<<"$rec")
  grep -qF -- "<!-- $key -->" "$tmpd/seen" && continue
  item=$(jq -r '"\(.src) \(.badge_or_sev) `\(.path):\(.line // "-")`: \(.reason)"' <<<"$rec")
  ref=""
  # An issue an earlier run created for this key but could not link is reused, never refiled.
  id=$(jq -r --arg k "$key" 'map(select(.key == $k))[0].id // empty' <<<"$unlinked")
  num=$(jq -r --arg k "$key" 'map(select(.key == $k))[0].number // empty' <<<"$unlinked")
  unlinked=$(jq -c --arg k "$key" 'map(select(.key != $k))' <<<"$unlinked")
  if [ "$mode" = sub_issues ]; then
    rc=0
    if [ -z "$num" ]; then
      # Reviewer prose reaches the body through a file, never through the command line.
      { printf '%s\n\n' "Deferred by review-loop on PR #$PR_NUM (follow-up #$PARENT)."
        printf '%s\n\n<!-- %s -->\n' "$item" "$key"; } > "$tmpd/body"
      title=$(jq -r --arg pr "$PR_NUM" '"Review follow-up: PR #\($pr) \(.src) \(.path):\(.line // "-")"' <<<"$rec")
      new=$(gh api -X POST "repos/$OWNER/$REPO/issues" -f "title=$title" -F "body=@$tmpd/body" -f "labels[]=tbd"); rc=$?
      id=$(jq -r '.id // empty' <<<"$new" 2>/dev/null); num=$(jq -r '.number // empty' <<<"$new" 2>/dev/null)
    fi
    if [ "$rc" -eq 0 ] && [ -n "$id" ] && [ -n "$num" ] &&
       gh api -X POST "repos/$OWNER/$REPO/issues/$PARENT/sub_issues" -F "sub_issue_id=$id" >/dev/null; then
      echo "$num" >> "$tmpd/filed"; continue
    fi
    echo "file-sub-issues: sub-issue for $key could not be filed or linked; the rest go to #$PARENT as a task list" >&2
    mode=task_list
  fi
  if [ -n "$num" ]; then
    ref="#$num "
    [ -n "$id" ] && unlinked=$(jq -c --arg k "$key" --argjson n "$num" --argjson i "$id" '. + [{key:$k, number:$n, id:$i}]' <<<"$unlinked")
  fi
  printf -- '- [ ] %s%s <!-- %s -->\n' "$ref" "$item" "$key" >> "$tmpd/tasks"
done < <(jq -c '.[]' <<<"$defers")

if [ -s "$tmpd/tasks" ]; then
  header="Deferred findings (the sub-issues API was unavailable):"
  { printf '%s\n\n' "$pbody"
    grep -qxF -- "$header" <<<"$pbody" || printf '%s\n\n' "$header"
    cat "$tmpd/tasks"; } > "$tmpd/new-body"
  gh issue edit "$PARENT" --repo "$OWNER/$REPO" --body-file "$tmpd/new-body" >/dev/null \
    || { echo "file-sub-issues: could not add the task list to #$PARENT" >&2; emit failed; exit 1; }
fi
emit "$mode"
