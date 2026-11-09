---
name: md-audit
description: "Audit markdown files against the docs writing standard: the bundled script measures bytes, paragraph bytes and sentences, heading depth, short sections and bold, the model judges what the numbers single out (plus the seven skill axes for a SKILL.md), and the report goes to chat. Rewrites only the files the user picks from that report. Default scope is the markdown changed against origin/main; pass paths or --all for more. Run on /docs:md-audit, 'md 점검', '문서 모양 점검', '스킬 진단', '스킬 전수 검토', 'audit markdown', 'audit this skill', 'review all skills'. For writing or restructuring a skill use docs:skill-forge."
disable-model-invocation: true
---

# md-audit

Measure markdown shape with a script, judge with the model, report in chat, rewrite only what the user picks. The rules and the exception list are in `../../references/writing-standard.md`: a SKILL.md at or under 10KB (target 5KB), paragraphs at or under 600 bytes and 3 sentences, no H4, no section under 3 body lines.

## Measure

Resolve the plugin root, then run the shape audit. With no argument it covers the `.md` files changed against the merge-base with `origin/main`; append the user's paths, `--base <ref>`, or `--all`.

```bash
# Honor a caller-supplied PLUGIN_ROOT first — the abort message below tells the user to
# export it, and starting from CLAUDE_PLUGIN_ROOT would overwrite that escape hatch.
PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
[ -z "$PLUGIN_ROOT" ] && [ -d plugins/docs/skills ] && PLUGIN_ROOT=plugins/docs
if [ -z "$PLUGIN_ROOT" ]; then
  # Rank Codex cache candidates on the version basename, not the whole path: a plain
  # sort puts 0.9.0 above 0.10.0 and lets the marketplace directory outrank the version.
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  if sort -V </dev/null >/dev/null 2>&1; then vsort="sort -V"; else vsort="sort -t. -k1,1n -k2,2n -k3,3n"; fi
  PLUGIN_ROOT=$(ls -1d "$cache_root"/*/docs/* 2>/dev/null | awk -F/ '{print $NF "\t" $(0)}' | $vsort | tail -1 | cut -f2-)
fi
[ -d "$PLUGIN_ROOT/skills" ] || { echo "docs plugin root not found; export PLUGIN_ROOT" >&2; exit 1; }
node "$PLUGIN_ROOT/skills/md-audit/scripts/measure-skills.mjs" --md
```

Exit 0 with `md-audit: ok` is a pass, 1 means `fail` findings, 2 means part of the scope could not be read. On 2, stop judging the unread paths and report them as unverified scope.

When the scope holds a SKILL.md, also run the skill table on the tree that contains it (`measure-skills.mjs <skills-root>`) and confirm the target's row is in the output before judging it. Run the repository guards if they exist (`scripts/check-skill-contract.mjs`, `scripts/check-doc-consistency.mjs`); a nonzero exit there is findings, so record each `[name exit N]` verbatim and continue.

## Judge

- **Every file with findings**: read it in full and decide the edit for each `fail`, then the `warn` lines worth acting on. A warn is a prompt to look, not a verdict.
- **What the script cannot count**: tone for the document kind, the first paragraph's what-and-number, unsourced numbers, incident history, reviewer rebuttals, pointers an installed user cannot follow, all per the standard.
- **A SKILL.md**: the seven axes and the P0/P1/P2 tiers in `references/axes.md`. Read every sibling description in the plugin for the pointer axis, since a trigger collision is invisible from inside one skill.

## Report, then rewrite

Write the report in chat, in this order: the scope (measured, skipped as exceptions, unreadable), then findings fail-first with file, line, rule and the concrete edit, then the files checked and found clean in one line, then anything `unverified` with what would settle it.

Write a file only when the user asks: `docs/audit/<YYYY-MM-DD>-md-audit.md`, with a `-1`, `-2` suffix rather than overwriting an earlier one.

Then ask which files to rewrite with `AskUserQuestion` on Claude Code or `request_user_input` on Codex; when neither is available, stop and report. Rewrite only the picked files, keep their meaning, bright lines and frozen names (machine-read strings, cited headings, step numbers), and rerun the measurement on them. A changed file under `plugins/<name>/` needs that plugin's version bump in the same change.

## Bright lines and done

- No edit before the user picks it, and none outside the picked files.
- A run with unreadable scope is never reported as clean.
- The exception list comes only from the standard's `## Exceptions` block. A file is not skipped because it is hard to fix.
- A runtime behavior nobody checked this session is `unverified`, not a finding.
- Done means every measured file has an explicit verdict, every finding names a file and line, every P0 names the runtime it breaks, and each rewritten file measures `md-audit: ok`.
