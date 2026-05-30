#!/usr/bin/env bash
# Usage: OWNER=... REPO=... PR_NUM=... CUR_SHA=... [PUSH_TIME=ISO8601] bash scripts/probe-codex-state.sh
# Best-effort detection of Codex's CURRENT review state (in_progress / clean / findings).
# Distinct from probe-codex-engagement.sh which answers "has Codex EVER reviewed this PR?".
#
# Emits one JSON line on stdout:
#   {"emoji_state":"clean|in_progress|findings|unknown","source":"reactions|check-runs|review-reactions|none"}
# Exits 0 always.
#
# Channels (first non-unknown wins):
#   A. issues/{pr}/reactions       — PR-level reactions, filtered to created_at > PUSH_TIME
#                                    so stale prior-iter reactions never produce false-clean.
#   B. commits/{sha}/check-runs    — Codex check-run name/conclusion/summary (SHA-scoped natively).
#   C. pulls/{pr}/reviews/{rid}/reactions — usually 404, kept as opportunistic tier-3,
#                                    also PUSH_TIME-filtered.
#
# When PUSH_TIME is absent the reaction channels still work but trust check-runs (B) more,
# matching the codex-parsing-rules.md caveat about false-clean.
#
# See references/codex-parsing-rules.md for the mapping tables and false-emoji caveats.
set -euo pipefail

: "${OWNER:?owner required}"
: "${REPO:?repo required}"
: "${PR_NUM:?pr required}"
: "${CUR_SHA:?sha required}"
PUSH_TIME="${PUSH_TIME:-}"

emit() {
  jq -nc --arg s "$1" --arg src "$2" '{emoji_state:$s, source:$src}'
  exit 0
}

# ── Channel A: PR-level reactions by Codex (PUSH_TIME-filtered) ─────────────
# Without the created_at > PUSH_TIME filter, a stale `+1` from a prior iter would
# surface as clean against a fresh SHA — false-positive proceed gate.
content=""
if pages=$(gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUM/reactions" 2>/dev/null); then
  content=$(jq -sr --arg t "$PUSH_TIME" 'add // []
                    | map(select(.user.login == "chatgpt-codex-connector[bot]"))
                    | map(select($t == "" or .created_at > $t))
                    | sort_by(.created_at) | last | .content // ""' <<<"$pages")
fi
case "$content" in
  "+1"|"hooray")        emit clean reactions ;;
  "eyes")               emit in_progress reactions ;;
  "-1"|"confused")      emit findings reactions ;;
esac

# ── Channel B: check-runs on current SHA ────────────────────────────────────
if cr_pages=$(gh api --paginate "repos/$OWNER/$REPO/commits/$CUR_SHA/check-runs" 2>/dev/null); then
  # GH paginated check-runs returns {total_count, check_runs:[...]} per page (object, not array).
  # jq -s 'add' on objects collapses to last page only, so flatten via per-page .check_runs.
  codex_run=$(jq -s '[ .[] | (.check_runs // [])[]? ]
                     | map(select((.name // "") | test("codex|chatgpt"; "i")))
                     | sort_by(.completed_at // .started_at // "") | last // {}' <<<"$cr_pages")
  status=$(jq -r '.status // ""' <<<"$codex_run")
  conclusion=$(jq -r '.conclusion // ""' <<<"$codex_run")
  summary=$(jq -r '.output.summary // ""' <<<"$codex_run")
  if [ -n "$status" ]; then
    case "$status" in
      in_progress|queued) emit in_progress check-runs ;;
      completed)
        case "$conclusion" in
          failure|action_required) emit findings check-runs ;;
          success|neutral)
            if jq -nr --arg s "$summary" '$s | test("no issues|clean|all good"; "i")' \
                 | grep -q true 2>/dev/null; then
              emit clean check-runs
            fi
            ;;
        esac
        ;;
    esac
  fi
fi

# ── Channel C: review-level reactions on latest Codex review (cheap, often 404) ─
if rid=$(gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews" 2>/dev/null \
           | jq -sr 'add // []
                     | [ .[] | select(.user.login == "chatgpt-codex-connector[bot]") ]
                     | sort_by(.submitted_at) | last | .id // ""'); \
   [ -n "$rid" ] && [ "$rid" != "null" ]; then
  if rrxn=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews/$rid/reactions" 2>/dev/null); then
    content=$(jq -r --arg t "$PUSH_TIME" 'map(select($t == "" or .created_at > $t))
                                          | sort_by(.created_at) | last | .content // ""' <<<"$rrxn" 2>/dev/null || echo "")
    case "$content" in
      "+1"|"hooray")        emit clean review-reactions ;;
      "eyes")               emit in_progress review-reactions ;;
      "-1"|"confused")      emit findings review-reactions ;;
    esac
  fi
fi

emit unknown none
