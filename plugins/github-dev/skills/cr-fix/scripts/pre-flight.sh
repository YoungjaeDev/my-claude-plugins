#!/usr/bin/env bash
# Usage: OWNER=... REPO=... PR_NUM=... CUR_SHA=... PUSH_TIME=... STATE_FILE=... \
#        [CODEX_TIMEOUT=600] [SKIP_DIR=/path/to/scripts] \
#        bash scripts/pre-flight.sh
#
# Emits exactly one JSON line on stdout summarising the pre-flight decision.
# See references/pre-flight-rules.md for the decision matrix and field contract.
#
# Exits 0 always. Per-channel failures are absorbed and surface as "unknown"
# values; the SKILL.md falls back to legacy Step 6 polling on gate=cr_wait.
set -euo pipefail

: "${OWNER:?owner required}"
: "${REPO:?repo required}"
: "${PR_NUM:?pr required}"
: "${CUR_SHA:?sha required}"
: "${PUSH_TIME:?push time required}"
: "${STATE_FILE:?state file required}"
# Honor the documented CODEX_PREFLIGHT_TIMEOUT alias (references/arguments.md);
# fall through to the internal CODEX_TIMEOUT name otherwise. Default 600s.
: "${CODEX_TIMEOUT:=${CODEX_PREFLIGHT_TIMEOUT:-600}}"
# Grace window during which a transient `success` + "Review skipped: free tier
# disabled" placeholder is held as cr_wait rather than rate_limited. See
# references/pre-flight-rules.md. Mirrors poll-cr-status.sh CR_SKIP_GRACE.
: "${CR_SKIP_GRACE:=300}"

SCRIPT_DIR="${SKIP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# ── 1. CR reported state (commit-status, else check-run) ─────────────────────
# Delegated to cr-commit-state.sh: CodeRabbit reports through the commit-status
# API on some installs and a check-run on others, and reading only /statuses made
# every check-run repo look like "CR never answered" (issue #105).
cr_status=$(bash "$SCRIPT_DIR/cr-commit-state.sh" "$OWNER" "$REPO" "$CUR_SHA" 2>/dev/null || echo '{}')
cr_state=$(jq -r 'if (.state // "none") == "none" then "" else .state end' <<<"$cr_status" 2>/dev/null || echo "")
cr_desc=$(jq -r '.description // ""' <<<"$cr_status" 2>/dev/null || echo "")
cr_created_at=$(jq -r '.created_at // ""' <<<"$cr_status" 2>/dev/null || echo "")

# Normalize empty state → "none" for the output JSON; the matrix treats both
# as "no status row yet" but downstream tooling reads strings, not blanks.
cr_state_out="${cr_state:-none}"

# ── 1b. push age & timeout ──────────────────────────────────────────────────
# Computed before the rate-limit sniff because the free-tier grace guard (§2)
# needs push_age to decide transient-vs-genuine.
# Portable ISO-8601 → epoch: GNU `date -d` first, then BSD `date -j -f`.
# Without the BSD fallback push_age stays at 0 on macOS, codex_timeout_active
# stays true forever, and gate decisions skew toward codex_wait. (CR Major, Codex P1)
iso_to_epoch() {
  local iso="$1" ts
  ts=$(date -d "$iso" +%s 2>/dev/null) && { printf '%s\n' "$ts"; return 0; }
  # BSD date: accept either `2026-05-30T01:49:10Z` or `...+00:00`.
  ts=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$iso" +%s 2>/dev/null) && { printf '%s\n' "$ts"; return 0; }
  ts=$(date -j -u -f '%Y-%m-%dT%H:%M:%S%z' "${iso/Z/+0000}" +%s 2>/dev/null) && { printf '%s\n' "$ts"; return 0; }
  return 1
}
now_ts=$(date +%s)
push_age=0
if push_ts=$(iso_to_epoch "$PUSH_TIME"); then
  push_age=$((now_ts - push_ts))
  # Clock skew (push timestamp ahead of local now) can make this negative; the
  # output schema floors push_age_seconds at 0, so clamp at the source.
  [ "$push_age" -lt 0 ] && push_age=0
fi
codex_timeout_active=false
if [ "$push_age" -lt "$CODEX_TIMEOUT" ]; then codex_timeout_active=true; fi

# Grace clock for the free-tier transient is anchored to WHEN THE CR STATUS ROW
# APPEARED (created_at), not push time — a bot that queues the placeholder more
# than CR_SKIP_GRACE after the push must still get the full grace to flip to
# "Review completed", or pre-flight would lock it to rate_limited prematurely.
# Falls back to push_age when the status carries no parseable timestamp.
cr_skip_age="$push_age"
if [ -n "$cr_created_at" ] && cr_created_ts=$(iso_to_epoch "$cr_created_at"); then
  cr_skip_age=$((now_ts - cr_created_ts))
  [ "$cr_skip_age" -lt 0 ] && cr_skip_age=0
fi

# ── 2. CR rate-limit sniff (comment body + commit-status description) ───────
# "Review skipped: free tier disabled" is a TRANSIENT quota-refill placeholder,
# not a genuine rate-limit. Within CR_SKIP_GRACE of the push it is held as
# cr_wait (§6) so CR can finish; only past grace does it route to rate_limited.
# Genuine patterns (`Review limit reached`/`rate limited`) route immediately.
rate_limit_source="none"
cr_free_tier_skip=false
# All three description classifiers require cr_state == "success": the documented
# decision matrix only routes description-derived signals on a success row, and a
# non-success status (pending/error) carrying these strings must not promote to
# rate_limited or skip the sniff.
if [ "$cr_state" = "success" ] && [ "$cr_desc" != "" ] \
   && jq -nr --arg d "$cr_desc" '$d | test("^Review skipped: free tier disabled"; "i")' \
        | grep -q true 2>/dev/null; then
  cr_free_tier_skip=true
fi
if [ "$cr_state" = "success" ] && [ "$cr_desc" != "" ] \
   && jq -nr --arg d "$cr_desc" '$d | test("Review limit reached|rate limited"; "i")' \
        | grep -q true 2>/dev/null; then
  rate_limit_source="description"
fi
# Free-tier transient that has outlived its grace window → genuine disable.
if [ "$cr_free_tier_skip" = "true" ] && [ "$cr_skip_age" -ge "$CR_SKIP_GRACE" ]; then
  rate_limit_source="description"
fi
# Skip the body sniff while a free-tier transient is still within grace — the
# sniffer also inspects the commit-status description and would re-flag the
# same placeholder, masking the cr_wait hold. (sniffer itself is unmodified.)
if [ "$rate_limit_source" = "none" ] \
   && ! { [ "$cr_free_tier_skip" = "true" ] && [ "$cr_skip_age" -lt "$CR_SKIP_GRACE" ]; } \
   && sniff_json=$(bash "$SCRIPT_DIR/sniff-cr-rate-limit.sh" "$OWNER" "$REPO" "$PR_NUM" "$PUSH_TIME" 2>/dev/null); then
  # Honor the actual channel the sniffer detected instead of always writing "comment".
  # The sniffer emits {channel: "comment"|"description"|"both"} — propagate verbatim.
  sniff_channel=$(jq -r '.channel // "comment"' <<<"$sniff_json" 2>/dev/null || echo comment)
  rate_limit_source="$sniff_channel"
fi

# ── 3. Codex review submission (unprocessed id) ─────────────────────────────
# Honor NO_CODEX from the SKILL.md per-iter cache so --no-codex shuts off the
# Codex probe entirely. Without this guard, codex_latest_id gets populated and
# downstream codex_actionable=true revives Codex paths the user explicitly
# disabled. (references/arguments.md contract)
PROCESSED='[]'
if [ -f "$STATE_FILE" ]; then
  PROCESSED=$(jq -c '.codex_processed_reviews // []' "$STATE_FILE" 2>/dev/null || echo '[]')
fi
codex_latest_id=""
codex_emoji_state="unknown"
if [ "${NO_CODEX:-false}" != "true" ]; then
  if codex_pages=$(gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews" 2>/dev/null); then
    codex_latest_id=$(jq -rs --argjson p "$PROCESSED" 'add // []
        | [ .[]
            | select(.user.login == "chatgpt-codex-connector[bot]")
            | select(.state == "COMMENTED" or .state == "CHANGES_REQUESTED")
            | select(.id as $i | $p | index($i) | not) ]
        | sort_by(.submitted_at) | last | .id // ""' <<<"$codex_pages")
  fi
  [ "$codex_latest_id" = "null" ] && codex_latest_id=""

  # ── 4. Codex emoji probe (best-effort, 3 channels) ────────────────────────
  if [ -x "$SCRIPT_DIR/probe-codex-state.sh" ]; then
    emoji_json=$(OWNER="$OWNER" REPO="$REPO" PR_NUM="$PR_NUM" CUR_SHA="$CUR_SHA" PUSH_TIME="$PUSH_TIME" \
                 bash "$SCRIPT_DIR/probe-codex-state.sh" 2>/dev/null || echo '{}')
    codex_emoji_state=$(jq -r '.emoji_state // "unknown"' <<<"$emoji_json")
  fi
fi

# ── 6. Decision matrix ──────────────────────────────────────────────────────
# cr_actionable: does CR have a real terminal state right now?
cr_actionable=false
codex_actionable=false
gate="cr_wait"

case "$cr_state" in
  success)
    if [ "$cr_free_tier_skip" = "true" ] && [ "$cr_skip_age" -lt "$CR_SKIP_GRACE" ]; then
      # Transient free-tier placeholder still within grace → not terminal yet.
      # Keep waiting (cr_wait) for the real "Review completed"; the gate
      # refinement below is skipped because cr_actionable stays false.
      cr_actionable=false
      gate="cr_wait"
    else
      cr_actionable=true
    fi
    ;;
  failure)
    gate="failure"
    cr_actionable=true
    ;;
  pending|error|"")
    # No terminal state yet → fall through to cr_wait (Step 6 polling).
    ;;
esac

# Rate-limit overrides everything except failure.
if [ "$rate_limit_source" != "none" ] && [ "$gate" != "failure" ]; then
  gate="rate_limited"
fi

# Codex actionability is independent of CR state.
if [ -n "$codex_latest_id" ]; then
  codex_actionable=true
fi

# Codex state classification.
# When NO_CODEX is unset AND all Codex signals are absent (no latest id, no emoji,
# no past engagement), short-circuit to `clean` so CR-only PRs never burn the
# CODEX_PREFLIGHT_TIMEOUT window waiting for a Codex review that will never come.
codex_state="unknown"
if [ "${NO_CODEX:-false}" = "true" ]; then
  # User opted out of Codex; report disabled so the gate decision treats
  # Codex as a no-op rather than waiting for a signal that will never arrive.
  codex_state="disabled"
elif [ "$codex_actionable" = "true" ]; then
  codex_state="actionable"
elif [ "$codex_emoji_state" = "clean" ] && [ "$push_age" -ge 60 ]; then
  # 60s minimum guard against the false-clean check-run race
  # (see references/codex-parsing-rules.md).
  codex_state="clean"
elif [ "$codex_emoji_state" = "findings" ] || [ "$codex_emoji_state" = "in_progress" ]; then
  codex_state="arriving"
elif [ "$codex_timeout_active" = "false" ]; then
  codex_state="clean"
elif [ "$codex_emoji_state" = "unknown" ] && [ -z "$codex_latest_id" ]; then
  # Last resort: ask "has Codex EVER reviewed this PR?". If no — treat as
  # inactive (clean) so CR-only PRs return gate=proceed instead of codex_wait.
  # Important: probe-codex-engagement.sh also prints "inactive" on gh API
  # failure (with a "warn:" stderr line) — that path must NOT collapse to
  # clean, or transient API errors silently mark Codex done. Capture stderr
  # too and treat any "warn:" line as "API failure → unknown → arriving".
  if [ -x "$SCRIPT_DIR/probe-codex-engagement.sh" ]; then
    eng_combined=$(bash "$SCRIPT_DIR/probe-codex-engagement.sh" "$OWNER" "$REPO" "$PR_NUM" 2>&1 || true)
    eng_stdout=$(printf '%s\n' "$eng_combined" | grep -v '^warn:' | tail -1)
    if printf '%s\n' "$eng_combined" | grep -q '^warn:'; then
      codex_state="arriving"  # API failure → conservative
    elif [ "$eng_stdout" = "inactive" ]; then
      codex_state="clean"
    else
      codex_state="arriving"
    fi
  else
    codex_state="arriving"
  fi
else
  codex_state="arriving"
fi

# Gate refinement: only refine when not already pinned to rate_limited/failure.
if [ "$gate" != "rate_limited" ] && [ "$gate" != "failure" ]; then
  if [ "$cr_actionable" = "true" ]; then
    case "$codex_state" in
      actionable|clean|disabled) gate="proceed" ;;
      arriving|unknown)          gate="codex_wait" ;;
    esac
  fi
fi

# ── 7. Emit ─────────────────────────────────────────────────────────────────
jq -nc \
  --arg cr_state "$cr_state_out" \
  --argjson cr_actionable "$cr_actionable" \
  --arg cr_desc "$cr_desc" \
  --arg codex_state "$codex_state" \
  --argjson codex_actionable "$codex_actionable" \
  --arg codex_latest_id "$codex_latest_id" \
  --arg codex_emoji_state "$codex_emoji_state" \
  --arg gate "$gate" \
  --argjson codex_timeout_active "$codex_timeout_active" \
  --argjson push_age "$push_age" \
  --arg rate_limit_source "$rate_limit_source" \
  '{
    cr_state: $cr_state,
    cr_actionable: $cr_actionable,
    cr_desc: $cr_desc,
    codex_state: $codex_state,
    codex_actionable: $codex_actionable,
    codex_latest_id: ( if $codex_latest_id == "" then null else ($codex_latest_id | tonumber) end ),
    codex_emoji_state: $codex_emoji_state,
    gate: $gate,
    codex_timeout_active: $codex_timeout_active,
    push_age_seconds: $push_age,
    rate_limit_source: $rate_limit_source
  }'
