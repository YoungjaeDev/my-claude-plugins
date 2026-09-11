#!/usr/bin/env bash
# Usage: echo '<record json>' | SKIP_MINOR=true bash scripts/classify-item.sh
# Reads one record on stdin, prints the same record + {"tier":"auto|gated|skip|review"} on stdout.
# See references/tier-classification.md and references/skip-minor-rules.md.
set -euo pipefail

: "${SKIP_MINOR:=false}"

jq -c --argjson skip_minor "$( [ "$SKIP_MINOR" = "true" ] && echo true || echo false )" '
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
        if $pb == "1" or $pb == "2" then "gated" else "review" end
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
