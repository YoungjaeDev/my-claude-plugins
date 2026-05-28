#!/usr/bin/env bash
# Usage: echo '<record json>' | SKIP_MINOR=true bash scripts/classify-item.sh
# Reads one record on stdin, prints the same record + {"tier":"auto|gated|skip|review"} on stdout.
# See references/tier-classification.md and references/skip-minor-rules.md.
set -euo pipefail

: "${SKIP_MINOR:=false}"

jq -c --argjson skip_minor "$( [ "$SKIP_MINOR" = "true" ] && echo true || echo false )" '
  . as $r
  | (.source // "") as $src
  | (.type_emoji // "") as $type
  | (.severity_emoji // "") as $sev
  | (.p_badge // "") as $pb
  | (
      # Base tier
      if $src == "codex" then
        if $pb == "1" then "gated"
        elif $pb == "2" then "gated"
        elif $pb == "3" then "skip"
        else "review"
        end
      else
        # cr or cli — same rules
        if ($type | test("Nitpick"; "i")) then "skip"
        elif ($type | test("Verification agent|Outside diff range"; "i")) then "review"
        elif ($type | test("Security"; "i")) then "gated"
        elif ($type | test("Bug|Potential issue"; "i")) then "gated"
        elif ($sev | test("Critical|High|Major"; "i")) then "gated"
        elif ($type | test("Refactor"; "i")) and ($sev | test("Minor|Trivial|Info"; "i")) then "auto"
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
             and (($type | test("Bug|Security"; "i")) | not)
        then "skip"
        else $base_tier
        end
      else
        $base_tier
      end
    ) as $tier
  | $r + { tier: $tier }
'
