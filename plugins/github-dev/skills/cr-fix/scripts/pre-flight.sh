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

SCRIPT_DIR="${SKIP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# ── 1. CR commit-status (state + description) ────────────────────────────────
cr_status='{}'
if cr_pages=$(gh api --paginate "repos/$OWNER/$REPO/commits/$CUR_SHA/statuses" 2>/dev/null); then
  cr_status=$(jq -s 'add // []
                     | [ .[] | select(.context | test("CodeRabbit"; "i")) ]
                     | sort_by(.created_at) | reverse | .[0] // {}' <<<"$cr_pages")
fi
cr_state=$(jq -r '.state // ""' <<<"$cr_status")
cr_desc=$(jq -r '.description // ""' <<<"$cr_status")

# Normalize empty state → "none" for the output JSON; the matrix treats both
# as "no status row yet" but downstream tooling reads strings, not blanks.
cr_state_out="${cr_state:-none}"

# ── 2. CR rate-limit sniff (comment body + commit-status description) ───────
rate_limit_source="none"
if [ "$cr_desc" != "" ] \
   && jq -nr --arg d "$cr_desc" '$d | test("Review skipped: free tier disabled|Review limit reached|rate limited"; "i")' \
        | grep -q true 2>/dev/null; then
  rate_limit_source="description"
fi
if [ "$rate_limit_source" = "none" ] \
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

# ── 5. push age & timeout ───────────────────────────────────────────────────
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
push_age=0
if push_ts=$(iso_to_epoch "$PUSH_TIME"); then
  now_ts=$(date +%s)
  push_age=$((now_ts - push_ts))
fi
codex_timeout_active=false
if [ "$push_age" -lt "$CODEX_TIMEOUT" ]; then codex_timeout_active=true; fi

# ── 6. Decision matrix ──────────────────────────────────────────────────────
# cr_actionable: does CR have a real terminal state right now?
cr_actionable=false
codex_actionable=false
gate="cr_wait"

case "$cr_state" in
  success)
    cr_actionable=true
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
  if [ -x "$SCRIPT_DIR/probe-codex-engagement.sh" ] \
     && [ "$(bash "$SCRIPT_DIR/probe-codex-engagement.sh" "$OWNER" "$REPO" "$PR_NUM" 2>/dev/null)" = "inactive" ]; then
    codex_state="clean"
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
