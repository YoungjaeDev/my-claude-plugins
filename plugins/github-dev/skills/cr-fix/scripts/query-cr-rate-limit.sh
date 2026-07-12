#!/usr/bin/env bash
# Usage: bash scripts/query-cr-rate-limit.sh OWNER REPO PR_NUM
#        bash scripts/query-cr-rate-limit.sh parse < reply-body.txt   (test seam)
#
# ACTIVE rate-limit query — the companion to the passive sniff-cr-rate-limit.sh.
# Posts "@coderabbitai rate limit" on the PR, then polls issue comments for a
# CodeRabbit reply newer than the SERVER-recorded time of that post and parses
# the remaining-review count + reset window out of the reply body. SKILL.md
# Step 7b calls this only when the passive sniff is ambiguous (a rate-limit
# signal with no reset estimate).
#
# Emits one JSON line:
#   {"remaining":N|null,"reset_minutes":N|null,"replied":bool,"body_excerpt":"..."}
# Exit 0 = query ran (replied true/false in payload). Exit 1 = could not post.
#
# TEST SEAM: `parse` reads a reply body on stdin and prints only the parsed
# {remaining, reset_minutes} — no gh, no network, no sleep. Used by run-tests.sh.
# --paginate on the comments read per plugins/github-dev/CLAUDE.md gh/jq rules.
set -euo pipefail

# jq capture() yields NO OUTPUT on a non-match (it neither throws nor returns
# null), so `capture(...).x // empty` collapses to empty and the var stays unset
# -> normalized to null below. See .llmwiki jq-capture-yields-empty.
parse_rate_limit_reply() {
  local body="$1" remaining reset
  remaining=$(jq -rn --arg b "$body" \
    '$b | (capture("(?<n>[0-9]+)\\s+reviews?\\s+(?:remaining|left)"; "i").n) // empty' 2>/dev/null || true)
  reset=$(jq -rn --arg b "$body" \
    '$b | (capture("(?:available in|reset in|reviews will be available in)[^0-9]{0,12}(?<m>[0-9]+)\\s*minutes?"; "i").m) // empty' 2>/dev/null || true)
  printf '{"remaining":%s,"reset_minutes":%s}\n' "${remaining:-null}" "${reset:-null}"
}

if [ "${1:-}" = "parse" ]; then
  parse_rate_limit_reply "$(cat)"
  exit 0
fi

OWNER="${1:?owner required}"; REPO="${2:?repo required}"; PR_NUM="${3:?pr required}"

if ! post_url=$(gh pr comment "$PR_NUM" --repo "$OWNER/$REPO" --body "@coderabbitai rate limit" 2>/dev/null); then
  printf '{"remaining":null,"reset_minutes":null,"replied":false,"body_excerpt":"comment post failed"}\n'
  exit 1
fi
# Anchor on OUR post's own comment id, parsed from the URL gh prints on success
# (…#issuecomment-<id>). Every cr-fix run posts the identical body, so re-finding
# the post by body-match `last` is ambiguous across runs: while the new post is
# not yet visible in the list API, a previous run's post anchors the filter and
# its old reply is returned as fresh (stale reset_minutes). Ids are monotonic,
# so `reply.id > post.id` selects only replies to THIS query — and subsumes the
# same-second `>=` timestamp clause.
anchor_id="${post_url##*issuecomment-}"
case "$anchor_id" in *[!0-9]*|"") anchor_id="";; esac

# Bounded poll: default 6 rounds x 20s. Overridable for tests / tuning.
POLLS="${QUERY_CR_POLLS:-6}"; SLEEP="${QUERY_CR_SLEEP:-20}"
reply=""
for _ in $(seq 1 "$POLLS"); do
  sleep "$SLEEP"
  # $anchor empty (gh printed no URL — unexpected) degrades to the body-match
  # `last` anchor: same-run correct, cross-run ambiguity documented above.
  # `.user.login // ""`: ghost/deleted accounts carry a null user, and jq's
  # test() errors on null input.
  # `|| reply=""`: a transient gh error (secondary rate limit, 502) would
  # otherwise trip set -e on this bare assignment and kill the bounded poll
  # before the terminal JSON line — treat it as "no reply yet this round".
  reply=$(gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUM/comments" 2>/dev/null \
    | jq -sr --arg aid "$anchor_id" 'add // []
        | (if $aid != "" then ($aid|tonumber) else
             (map(select(.body == "@coderabbitai rate limit")) | last | .id) // null
           end) as $anchor
        | if $anchor == null then "" else
            ([ .[] | select(.user.login // "" | test("coderabbit"; "i"))
                   | select((.id // 0) > $anchor)
                   | .body // "" ] | last // "")
          end') || reply=""
  [ -n "$reply" ] && break
done

if [ -z "$reply" ]; then
  printf '{"remaining":null,"reset_minutes":null,"replied":false,"body_excerpt":""}\n'
  exit 0
fi

parsed=$(parse_rate_limit_reply "$reply")
excerpt=$(printf '%s' "$reply" | head -c 200 | tr '\n' ' ')
jq -nc --argjson p "$parsed" --arg e "$excerpt" '$p + {replied:true, body_excerpt:$e}'
