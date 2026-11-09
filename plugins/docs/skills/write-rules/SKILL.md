---
name: write-rules
description: Generate or restructure CLAUDE.md systems with modular .claude/rules/ delegation. Use when starting new projects, restructuring existing CLAUDE.md, splitting monolithic CLAUDE.md into modular rules files, modularizing project instructions, or aligning rules to Claude Code 2026 best practices. Auto-detects project state and proposes the right mode. Triggers — "rules 작성", "write rules", "generate claude.md", "restructure claude.md", "split claude.md", "modularize instructions", "organize project rules", "rules 분리".
allowed-tools: Read Write Edit Glob Grep Bash
---

# Write Rules

Scan a project, pick one of 4 modes (NEW, TIGHTEN, SPLIT, REORGANIZE), confirm it with the user, then generate or restructure `CLAUDE.md` plus `.claude/rules/*.md`: `paths:` glob scoping for auto-loaded rules, a root at or under 200 lines, each rule at or under 150, Do/Don't structure, and no `@import` of rules. Templates in `assets/templates/` and examples in `assets/examples/` ground the output.

`assets/references/claude-code-memory.md` is a 2026-05-12 snapshot of the official memory docs, so confirm a platform fact against `https://code.claude.com/docs/llms.txt` before relying on it.

Ask with `AskUserQuestion` on Claude Code or `request_user_input` on Codex; when neither is available, stop and report the detected state and the recommended mode without writing any file.

## Modes

| Mode | Trigger | What it does |
|---|---|---|
| NEW | `CLAUDE.md` 부재 | 인터뷰 → 카테고리 선택 → root + 초기 `.claude/rules/*.md` 생성 |
| TIGHTEN | `CLAUDE.md` ≤200줄, `.claude/rules/` 비어있음 | root 만 Do/Don't 로 재구조화 + `paths:` 후보 제안, 신규 rules 파일 없음 |
| SPLIT | `CLAUDE.md` >200줄, `.claude/rules/` 비어있음 | 섹션 추출 → `.claude/rules/<topic>.md` 자동 생성, root 축약 |
| REORGANIZE | `CLAUDE.md` + `.claude/rules/` 둘 다 존재 | root cap 초과·rules 중복·`paths:` 누락 점검 후 per-file 패치 |

## Detection Logic

Scan project state with Bash, then propose a mode.

```
state = {
  hasClaudeMd:      exists("./CLAUDE.md") or exists("./.claude/CLAUDE.md")
  claudeMdPath:     "./CLAUDE.md" or "./.claude/CLAUDE.md" (whichever exists)
  claudeMdLines:    wc -l on the file if present
  hasRulesDir:      exists("./.claude/rules/") and contains at least one *.md
  rulesFileCount:   count of .claude/rules/*.md
  hasAgentsMd:      exists("./AGENTS.md")
  contentSignals:   tags derived from grep over root + rules content
                    (clean-arch, nextjs-framework, supabase, service-spec)
}

mode =
  NEW         if not state.hasClaudeMd
  TIGHTEN     if state.hasClaudeMd and state.claudeMdLines <= 200 and not state.hasRulesDir
  SPLIT       if state.hasClaudeMd and state.claudeMdLines > 200 and not state.hasRulesDir
  REORGANIZE  if state.hasClaudeMd and state.hasRulesDir
```

`contentSignals` does not influence `mode` selection. It tells the
chosen mode which `assets/examples/*.md` to Read for grounding.

## Execution

1. Run the state scan in `references/detection-scan.md` (`wc -l` on `CLAUDE.md` and `.claude/rules`, plus a content-signal grep over tech-stack markers). Collect `signal:*` lines into `state.contentSignals`; an empty list skips the examples.
2. Compute `mode` per the rules above.
3. Present the recommendation with the question tool: one recommended option and three overrides, with the detected facts in the question body:

   ```
   "감지: CLAUDE.md {LINES}줄, .claude/rules/ {COUNT}개 파일, AGENTS.md {존재/부재}.
    추천 모드: {MODE}. 진행?"
   ```

   Options:
   - 진행 (Recommended)
   - 다른 모드로: NEW / TIGHTEN / SPLIT / REORGANIZE 중 사용자 선택
   - 취소

4. On accept or override, read `references/procedure.md` and follow that mode's numbered steps. On cancel, exit with no file changes.
5. If `state.hasAgentsMd` is true, the summary includes the `@AGENTS.md` coexistence hint from `references/lookup-tables.md`.

## Bright lines

- **Confirm before writing**: TIGHTEN and SPLIT propose before/after or an extraction plan and apply only what the user confirms; REORGANIZE applies no finding without the user's explicit selection.
- **Preserve user content**: in TIGHTEN, SPLIT and REORGANIZE, never rewrite content the user did not ask to change. Edit surgically, not with a whole-file rewrite unless necessary.
- **No `@import` of `.claude/rules/*`**: rules auto-load, so an import only adds token cost.
- **Hands off**: do not modify `AGENTS.md` (only hint about coexistence), do not manage auto-memory at `~/.claude/projects/<proj>/memory/`, and do not write `.gitignore` entries (mention the `CLAUDE.local.md` pattern in the summary only).
- **No unrequested sections**: no drive-by additions like "Testing Best Practices" when testing was not discussed, and no emoji in any output.

## Output conventions

- **Sizes**: root `CLAUDE.md` at or under 200 lines, each `.claude/rules/*.md` at or under 150; split a longer rule into sub-rules with more specific `paths:`.
- **Scoping**: `paths:` glob frontmatter for a path-scoped rule (template Variant A), no frontmatter for a universal one (Variant B).
- **Rule shape**: Role / Do / Don't / Examples (optional) / Source of Truth in every rule file, with imperative, verifiable statements ("Run `npm test` before push", not "Test your changes").
- **Root ToC**: reference rule files from the root as a plain-text list (`- \`architecture.md\`: layering invariants`).
- **Writing standard**: every line written follows `../../references/writing-standard.md` `## Shape` and `## Tone by document kind` (paragraphs at or under 600 bytes and 3 sentences, no section under 3 body lines, no H4, bold only as a list lead). TIGHTEN, SPLIT and REORGANIZE apply it only to the lines they write.
- **Reviewable writes**: one Write call per file, so each diff stays reviewable.

## Done

- Each mode ends with its verify block from `references/verify-commands.md`.
- The summary lists the files written with line counts, or the items applied and declined.
- The summary ends with the post-generation hints from `references/lookup-tables.md` (for example `AGENTS.md` present, `CLAUDE.local.md` not gitignored). A worked REORGANIZE trace with a `clean-arch` signal is in `references/worked-example.md`.
