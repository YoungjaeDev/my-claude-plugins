#!/usr/bin/env bash
# Usage: echo '<record json>' | ITER=N SKIP_MINOR=true bash scripts/classify-item.sh
# Reads one record on stdin, prints the same record + {"tier":"auto|gated|skip|review|defer"} on stdout.
# ITER (default 1) is the loop iteration: a Codex P2 from iteration 2 on is `defer` (decision 15).
# See references/tier-classification.md and references/skip-minor-rules.md.
set -euo pipefail

: "${SKIP_MINOR:=false}"
: "${ITER:=1}"
case "$ITER" in ''|*[!0-9]*) echo "classify-item: ITER must be a non-negative integer, got '$ITER'" >&2; exit 2;; esac

jq -c --argjson skip_minor "$( [ "$SKIP_MINOR" = "true" ] && echo true || echo false )" \
      --argjson iter "$ITER" '
  . as $r
  | (.source // "") as $src
  | (.category_emoji // "") as $cat
  | (.severity_emoji // "") as $sev
  | (.effort_emoji // "") as $eff
  | ((.p_badge // "") | tostring) as $pb
  | (
      # Base tier. CR/CLI is severity-first: the header category names the defect
      # domain, not how bad it is, so only Security escalates on category alone.
      if $src == "codex" then
        # P2 is judged on iteration 1 only; a later one goes to the follow-up
        # issue unjudged, because an applied P2 becomes material for the next round.
        if $pb == "2" and $iter >= 2 then "defer"
        elif $pb == "0" or $pb == "1" or $pb == "2" then "gated"
        else "review" end
      else
        # cr or cli — same rules
        if ($cat | test("Security"; "i")) then "gated"
        elif ($cat | test("Nitpick"; "i")) then "skip"
        elif ($sev | test("Critical|High|Major"; "i")) then "gated"
        elif ($sev | test("Trivial|Info"; "i")) then "skip"
        elif ($sev | test("Minor"; "i")) then
          (if ($eff | test("Heavy lift"; "i")) then "gated" else "auto" end)
        else "review"
        end
      end
    ) as $base_tier
  | (
      # --skip-minor post-filter
      if $skip_minor then
        if $src == "codex" and $pb == "2" then "skip"
        elif ($src == "cr" or $src == "cli")
             and ($sev | test("Minor|Trivial|Info"; "i"))
             and (($cat | test("Security"; "i")) | not)
        then "skip"
        else $base_tier
        end
      else
        $base_tier
      end
    ) as $tier
  | $r + { tier: $tier }
'
