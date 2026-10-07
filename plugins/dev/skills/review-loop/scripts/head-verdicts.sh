#!/usr/bin/env bash
# Usage: OWNER=... REPO=... PR_NUM=... CUR_SHA=... [PUSH_TIME=ISO8601] \
#        [CR_ON=true|false] [CODEX_ON=auto|true|false] [CAP=seconds] [INTERVAL=30] \
#        [TIMEOUT=1800] [CODEX_GRACE=30] [CODEX_PREFLIGHT_TIMEOUT=600] \
#        bash scripts/head-verdicts.sh
#
# Waits until every reviewer the run has on gave CUR_SHA a HEAD verdict (GLOSSARY
# "HEAD 판정", ADR docs/adr/0002-review-loop-waits-for-head-verdicts.md), then
# prints one JSON line:
#   {"state":"ready|timeout|paused|codex_failed",
#    "cr":"findings|clean|none|error|off", "codex":"<codex-head-verdict verdict>|off",
#    "findings":bool, "cr_review_request":"post|skip"|null, "waited":N}
#
# Verdicts come from cr-head-verdict.sh and codex-head-verdict.sh; this script only
# combines them. findings and clean are verdicts; a progress mark, a rate-limit
# notice and a review pause are not. A reviewer that cannot be read is not ready.
#   ready         every reviewer that is on has findings or clean on CUR_SHA
#   codex_failed  Codex reported Failed on CUR_SHA (no review is coming)
#   paused        CodeRabbit paused automatic reviews and this HEAD has no
#                 `@coderabbitai review` request yet (cr_review_request=post).
#                 The caller posts it; this script never writes to the PR.
#   timeout       the budget ran out first
#
# Budget: the existing caps, anchored to the push so waiting again on the same
# HEAD never extends them. CR: TIMEOUT - push_age. Codex: codex-head-verdict.sh
# wait_seconds, max(CODEX_GRACE, CODEX_PREFLIGHT_TIMEOUT - push_age). The cap is the
# larger budget among reviewers still pending on the first look. CAP overrides it
# (CAP=0 is a single look, which the auto-merge gate uses).
#
# CODEX_ON=auto: Codex counts as on unless it has never engaged on this PR (no
# summary comment, no review, engagement probe says inactive without an error).
set -uo pipefail

: "${OWNER:?owner required}"; : "${REPO:?repo required}"
: "${PR_NUM:?pr required}"; : "${CUR_SHA:?sha required}"
PUSH_TIME="${PUSH_TIME:-}"
: "${CR_ON:=true}"; : "${CODEX_ON:=auto}"; : "${INTERVAL:=30}"
: "${TIMEOUT:=1800}"; : "${CODEX_GRACE:=30}"; : "${CODEX_PREFLIGHT_TIMEOUT:=600}"
CAP="${CAP:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAUSE_MARK='auto-generated comment: review paused by coderabbit\.ai'

# Same age rule as codex-head-verdict.sh: unparseable or absent counts as 0.
cr_budget=$(jq -n --arg t "$PUSH_TIME" --argjson to "$TIMEOUT" '
  ((try (now - ($t | fromdateiso8601)) catch 0) | floor | if . < 0 then 0 else . end) as $age
  | [0, $to - $age] | max')

SECONDS=0
request=""; cap=""
while :; do
  cr=off
  if [ "$CR_ON" = true ]; then
    cr=$(bash "$HERE/cr-head-verdict.sh" "$OWNER" "$REPO" "$PR_NUM" "$CUR_SHA" 2>/dev/null) || cr=error
  fi

  codex=off; codex_budget=0
  if [ "$CODEX_ON" != false ]; then
    # rc 1 still prints a verdict=error line; no line at all is an error too.
    hv=$(OWNER="$OWNER" REPO="$REPO" PR_NUM="$PR_NUM" CUR_SHA="$CUR_SHA" PUSH_TIME="$PUSH_TIME" \
         CODEX_GRACE="$CODEX_GRACE" CODEX_PREFLIGHT_TIMEOUT="$CODEX_PREFLIGHT_TIMEOUT" \
         bash "$HERE/codex-head-verdict.sh" 2>/dev/null)
    codex=$(jq -r '.verdict // "error"' <<<"$hv" 2>/dev/null) || codex=error
    [ -n "$codex" ] || codex=error
    codex_budget=$(jq -r '.wait_seconds // 0' <<<"$hv" 2>/dev/null) || codex_budget=0
    [ -n "$codex_budget" ] || codex_budget=0
    if [ "$CODEX_ON" = auto ] && [ "$codex" = unknown ] \
       && [ "$(jq -r '.summary_state' <<<"$hv")" = absent ]; then
      eng=$(bash "$HERE/probe-codex-engagement.sh" "$OWNER" "$REPO" "$PR_NUM" 2>&1)
      # A probe that warns could not look: keep Codex on.
      if ! grep -q '^warn:' <<<"$eng" && [ "$(tail -1 <<<"$eng")" = inactive ]; then codex=off; fi
    fi
  fi

  state=""
  if [ "$codex" = failed ]; then state=codex_failed
  else
    case "$cr" in off|findings|clean) cr_done=true ;; *) cr_done=false ;; esac
    case "$codex" in off|findings|clean) codex_done=true ;; *) codex_done=false ;; esac
    if [ "$cr_done" = true ] && [ "$codex_done" = true ]; then state=ready; fi
  fi

  if [ -z "$state" ] && [ "$cr" = none ]; then
    # A paused CodeRabbit never reviews this HEAD on its own. The pause block lives
    # in the walkthrough comment CR edits in place, so its presence is the signal.
    if comments=$(gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUM/comments" 2>/dev/null) \
       && jq -s -e --arg m "$PAUSE_MARK" 'add // [] | any(.[];
            ((.user.login // "") | test("^coderabbitai(\\[bot\\])?$"; "i"))
            and ((.body // "") | test($m; "i")))' <<<"$comments" >/dev/null 2>&1; then
      # Exit 1 = comments unreadable, or no PUSH_TIME (this HEAD's request cannot be
      # told from an older one): no request, the same as request_cr_review.
      if d=$(bash "$HERE/cr-review-posted.sh" "$OWNER" "$REPO" "$PR_NUM" "$PUSH_TIME" 2>/dev/null); then
        request="$d"
        [ "$d" = post ] && state=paused
      fi
    fi
  fi

  if [ -z "$cap" ] && [ -z "$state" ]; then
    if [ -n "$CAP" ]; then cap="$CAP"
    else
      cap=0
      case "$cr" in off|findings|clean) : ;; *) [ "$cr_budget" -gt "$cap" ] && cap="$cr_budget" ;; esac
      case "$codex" in off|findings|clean) : ;; *) [ "$codex_budget" -gt "$cap" ] && cap="$codex_budget" ;; esac
    fi
  fi
  [ -z "$state" ] && [ "$SECONDS" -ge "${cap:-0}" ] && state=timeout

  if [ -n "$state" ]; then
    jq -nc --arg s "$state" --arg cr "$cr" --arg cx "$codex" --arg req "$request" --argjson w "$SECONDS" '
      {state:$s, cr:$cr, codex:$cx, findings:($cr == "findings" or $cx == "findings"),
       cr_review_request:(if $req == "" then null else $req end), waited:$w}'
    exit 0
  fi
  sleep "$INTERVAL"
done
