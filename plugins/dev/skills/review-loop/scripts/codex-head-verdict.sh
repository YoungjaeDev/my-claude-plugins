#!/usr/bin/env bash
# Usage: OWNER=... REPO=... PR_NUM=... CUR_SHA=... [PUSH_TIME=ISO8601] \
#        [CODEX_GRACE=30] [CODEX_PREFLIGHT_TIMEOUT=600] bash scripts/codex-head-verdict.sh
#
# Codex's HEAD verdict: what Codex has said about the commit the PR points at now.
# Emits exactly one JSON line on stdout:
#   {"verdict":"findings|clean|failed|in_progress|none|unknown|error",
#    "summary_state":"completed|running|failed|unparsed|absent|null",
#    "summary_sha":"95ab2f6"|null, "head_review_id":N|null,
#    "fallback":"review_id_poll"|null, "wait_seconds":N}
# Exit 0, or 1 with verdict=error when a gh call fails (never an empty "clean").
#
# Sources (references/codex-state-machine.md "HEAD verdict"):
#   - the `<!-- codex-pull-request-review-summary -->` issue comment Codex edits in
#     place: one table row per review, Status `**Running|Completed|Failed**` and a
#     backticked short SHA. The newest such comment by updated_at wins, and in it
#     the newest row for HEAD (by its relative-time) is the one judged.
#   - a Codex review whose commit_id == CUR_SHA (Codex posts one only with findings).
# wait_seconds is the one Codex wait budget every gate uses:
#   max(CODEX_GRACE, CODEX_PREFLIGHT_TIMEOUT - push_age).
set -euo pipefail

: "${OWNER:?owner required}"; : "${REPO:?repo required}"
: "${PR_NUM:?pr required}"; : "${CUR_SHA:?sha required}"
PUSH_TIME="${PUSH_TIME:-}"
: "${CODEX_GRACE:=30}"; : "${CODEX_PREFLIGHT_TIMEOUT:=600}"

# jq's fromdateiso8601 avoids GNU `date -d` vs BSD `date -j`; an unparseable or
# absent PUSH_TIME counts as age 0 (the full window), the conservative side.
wait_seconds=$(jq -n --arg t "$PUSH_TIME" --argjson g "$CODEX_GRACE" --argjson to "$CODEX_PREFLIGHT_TIMEOUT" '
  ((try (now - ($t | fromdateiso8601)) catch 0) | floor | if . < 0 then 0 else . end) as $age
  | [$g, $to - $age] | max')

if ! comments=$(gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUM/comments" 2>/dev/null) \
   || ! reviews=$(gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews" 2>/dev/null); then
  echo "warn: codex-head-verdict: gh api failed; verdict=error" >&2
  jq -nc --argjson w "$wait_seconds" '{verdict:"error", summary_state:null, summary_sha:null,
    head_review_id:null, fallback:null, wait_seconds:$w}'
  exit 1
fi

jq -nc --argjson w "$wait_seconds" --arg sha "$CUR_SHA" \
  --slurpfile c <(printf '%s' "$comments") --slurpfile r <(printf '%s' "$reviews") '
  ($r | add // [] | [ .[]
      | select((.user.login // "") | test("^chatgpt-codex-connector(\\[bot\\])?$"; "i"))
      | select(.state == "COMMENTED" or .state == "CHANGES_REQUESTED")
      | select(.commit_id == $sha) ]
    | sort_by(.submitted_at) | last | .id) as $hrid
  | ($c | add // [] | [ .[]
      | select((.user.login // "") | test("^chatgpt-codex-connector(\\[bot\\])?$"; "i"))
      | select((.body // "") | contains("<!-- codex-pull-request-review-summary -->")) ]
    | sort_by(.updated_at) | last) as $summary
  # Data rows: a **Status** cell and a backticked hex SHA. Header and separator
  # rows carry neither. A row with an unknown status word poisons the parse.
  # `at` is the <relative-time datetime> of the row, "" when it has none.
  | ( if $summary == null then null else
        [ $summary.body | split("\n")[]
          | select(startswith("|"))
          | ((capture("datetime=\"(?<t>[^\"]+)\"") | .t) // "") as $at
          | (capture("\\*\\*(?<st>[A-Za-z ]+)\\*\\*[^|]*\\|\\s*`(?<sha>[0-9a-fA-F]{7,40})`") // empty)
          | {st: (.st | ascii_downcase), sha: (.sha | ascii_downcase), at: $at} ]
      end ) as $rows
  | ( if $summary == null then "absent"
      elif ($rows | length) == 0 then "unparsed"
      elif any($rows[]; .st | IN("running", "completed", "failed") | not) then "unparsed"
      else null end ) as $bad
  # Only the newest row for HEAD speaks for it: a Failed row followed by a
  # Completed row from a re-run is a pass. Newest by `at`, wherever the row sits;
  # a tie (or no times) keeps table order and takes the later row. $head holds at
  # most that one row.
  | [ ($rows // [])[] | select(. as $x | $sha | ascii_downcase | startswith($x.sha)) ]
    | sort_by(.at) | .[-1:] as $head
  | ( if $bad != null then (if $hrid != null then "findings" else "unknown" end)
      elif ($head | length) == 0 then (if $hrid != null then "findings" else "none" end)
      elif any($head[]; .st == "running") then "in_progress"
      elif any($head[]; .st == "failed") then "failed"
      elif $hrid != null then "findings"
      else "clean" end ) as $verdict
  | ( if $bad != null then $bad
      elif ($head | length) > 0 then
        (if any($head[]; .st == "running") then "running"
         elif any($head[]; .st == "failed") then "failed" else "completed" end)
      else $rows[0].st end ) as $state
  | { verdict: $verdict,
      summary_state: $state,
      summary_sha: (if $bad != null then null else (($head[0] // $rows[0]).sha) end),
      head_review_id: $hrid,
      fallback: (if $bad != null then "review_id_poll" else null end),
      wait_seconds: $w }'
