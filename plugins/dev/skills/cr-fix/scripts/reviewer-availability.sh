#!/usr/bin/env bash
# Usage: [CR_SOURCE=auto] [NO_CODEX=false] bash scripts/reviewer-availability.sh OWNER REPO PR_NUM
# Reads the PR's issue comments once, before iter 1 waits, for each reviewer's
# "will not review this PR" signal:
#   Codex:      chatgpt-codex-connector[bot], "You have reached your Codex usage limits for code reviews"
#   CodeRabbit: coderabbitai[bot], the `auto-generated comment: skip review by coderabbit.ai`
#               marker together with "Auto reviews are disabled on this repository"
# Logins are anchored at both ends: a registrable look-alike such as
# `coderabbitai-evil` must not be able to switch a reviewer off.
#
# Prints one JSON line:
#   {"codex_unavailable":bool,"cr_unavailable":bool,"codex_url":str|null,"cr_url":str|null,
#    "action":"proceed"|"drop_codex"|"drop_cr"|"stop"}
# `action` folds in which reviewers this run actually uses: the CR skip only
# matters to the PR-bot sources (auto / pr-bot), never to the local CLI, and the
# Codex signal is moot under NO_CODEX=true. `stop` = no reviewer left.
# Exit 1 with no stdout when the comments cannot be fetched: that is "did not
# look", not "no signal", and the caller keeps the normal wait path.
#
# SINCE (ISO-8601, optional): ignore comments last touched before it. The caller
# passes the head SHA's push time, so a signal from an earlier push, whose quota
# may have come back since, cannot switch a reviewer off. Empty = no cut.
set -uo pipefail

OWNER="${1:?owner required}"; REPO="${2:?repo required}"; PR_NUM="${3:?pr required}"
CR_SOURCE="${CR_SOURCE:-auto}"; NO_CODEX="${NO_CODEX:-false}"; SINCE="${SINCE:-}"

raw=$(gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUM/comments" 2>/dev/null) \
  || { echo "reviewer-availability: could not fetch PR #$PR_NUM comments" >&2; exit 1; }

jq -sc --arg src "$CR_SOURCE" --arg nocodex "$NO_CODEX" --arg since "$SINCE" '
  def newest_url(login_re; test_body):
    [ .[] | select((.user.login // "") | test(login_re; "i")) | select((.body // "") | test_body)
          | select((.updated_at // .created_at // "") >= $since) ]
    | sort_by(.created_at) | last | .html_url // null;
  (add // []) as $c
  | ($c | newest_url("^chatgpt-codex-connector(\\[bot\\])?$";
        contains("You have reached your Codex usage limits for code reviews"))) as $codex
  | ($c | newest_url("^coderabbitai(\\[bot\\])?$";
        contains("auto-generated comment: skip review by coderabbit.ai")
        and contains("Auto reviews are disabled on this repository"))) as $cr
  | ($codex != null and $nocodex != "true") as $codex_down
  | ($cr != null and ($src == "auto" or $src == "pr-bot")) as $cr_down
  | (($src != "codex-only") and ($cr_down | not)) as $cr_left
  | (($nocodex != "true") and ($codex_down | not)) as $codex_left
  | { codex_unavailable: ($codex != null), cr_unavailable: ($cr != null),
      codex_url: $codex, cr_url: $cr,
      action: (if ($codex_down or $cr_down) | not then "proceed"
               elif ($cr_left or $codex_left) | not then "stop"
               elif $cr_down then "drop_cr"
               else "drop_codex" end) }' <<<"$raw" \
  || { echo "reviewer-availability: could not parse PR #$PR_NUM comments" >&2; exit 1; }
