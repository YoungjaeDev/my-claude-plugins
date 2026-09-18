---
name: write-rules
description: Generate or restructure CLAUDE.md systems with modular .claude/rules/ delegation. Use when starting new projects, restructuring existing CLAUDE.md, splitting monolithic CLAUDE.md into modular rules files, modularizing project instructions, or aligning rules to Claude Code 2026 best practices. Auto-detects project state and proposes the right mode. Triggers — "rules 작성", "write rules", "generate claude.md", "restructure claude.md", "split claude.md", "modularize instructions", "organize project rules", "rules 분리".
allowed-tools: Read Write Edit Glob Grep Bash
---

# Write Rules

## Role

AI Context Architect for CLAUDE.md systems. Scans the project state,
detects which of four operating modes applies (NEW / TIGHTEN / SPLIT /
REORGANIZE), confirms with the user via AskUserQuestion, then
generates or restructures the rules layout following Claude Code 2026
official patterns: `.claude/rules/*.md` auto-load with `paths:` glob
scoping, 200-line root CLAUDE.md target, Do/Don't structure, no
redundant `@import` directives.

Output conventions are tuned to the official memory docs (see
`assets/references/claude-code-memory.md`). Adapted templates in
`assets/templates/` and reference examples in `assets/examples/`
ground the generation.

## Modes

| Mode | Trigger | What it does |
|---|---|---|
| **NEW** | `CLAUDE.md` 부재 | 인터뷰 → 카테고리 선택 → root + 초기 `.claude/rules/*.md` 생성 |
| **TIGHTEN** | `CLAUDE.md` ≤200줄, `.claude/rules/` 비어있음 | root 만 Do/Don't 로 재구조화 + `paths:` 후보 제안, 신규 rules 파일 없음 |
| **SPLIT** | `CLAUDE.md` >200줄, `.claude/rules/` 비어있음 | 섹션 추출 → `.claude/rules/<topic>.md` 자동 생성, root 축약 |
| **REORGANIZE** | `CLAUDE.md` + `.claude/rules/` 둘 다 존재 | root cap 초과·rules 중복·`paths:` 누락 점검 후 per-file 패치 |

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

### Execution

1. Run state scan:
   Script: `references/detection-scan.md` (wc -l checks on CLAUDE.md /
   .claude/rules, plus content-signal grep over tech-stack markers).
   Collect `signal:*` lines into `state.contentSignals`. Empty list is
   fine: examples are then skipped.

2. Compute `mode` per the rules above.

3. Present the recommendation via AskUserQuestion with one
   recommended option and three override options. Include detected
   facts in the question body:

   ```
   "감지: CLAUDE.md {LINES}줄, .claude/rules/ {COUNT}개 파일, AGENTS.md {존재/부재}.
    추천 모드: {MODE}. 진행?"
   ```

   Options:
   - 진행 (Recommended)
   - 다른 모드로: NEW / TIGHTEN / SPLIT / REORGANIZE 중 사용자 선택
   - 취소

4. If user accepts or overrides, branch to the corresponding Mode
   Execution subsection. If user cancels, exit with no file changes.

5. If `state.hasAgentsMd` is true, the post-generation summary
   includes a hint about `@AGENTS.md` import coexistence (handled in
   Post-generation Hints section).

## Mode Execution

### Mode: NEW

Generate a fresh CLAUDE.md system from scratch.

1. **Interview** via AskUserQuestion (max 2 questions):
   - Q1: 프로젝트 1-2문장 overview + 기술 스택
   - Q2: 주요 도메인 / 카테고리 (`rule-categories.md` 의 5개 중
     해당하는 것 다중 선택)

2. **Read** `assets/templates/rule-categories.md` to map user
   selections to filenames and `paths:` globs.

3. **Read** `assets/templates/root-claude-md.md` as the root skeleton.

4. **Read** relevant `assets/examples/*.md` based on tech stack:
   - Next.js / React → `nextjs-clean-arch.md` + `nextjs-framework.md`
   - Supabase / similar SaaS backend → `tech-stack-supabase.md`
   - Product-context heavy → `saas-service-spec.md` (PRD-rules hybrid)

5. **Fill** placeholders in root template using interview answers
   (project name, overview, tech stack, command examples).

6. **Generate** `.claude/rules/*.md` files, one per selected
   category, using `assets/templates/rule-file.md` as the per-file
   skeleton. Use Variant A (`paths:`) for path-scoped categories,
   Variant B (no frontmatter) for universal ones.

7. **Write** files in this order: `.claude/rules/*.md` first, then
   `./CLAUDE.md` last (so the root file's "Rules" ToC references
   files that already exist).

8. **Verify** (deterministic commands):
   `references/verify-commands.md` NEW/SPLIT/REORGANIZE block (`wc -l`
   on CLAUDE.md ≤200 and each rule ≤150, `grep -c` for 0 `@import`).

9. **Summarize**: file list with line counts + Post-generation Hints.

### Mode: TIGHTEN

Patch the existing root CLAUDE.md in place: no new rules/ files.

1. **Read** current root CLAUDE.md.

2. **Read** `assets/templates/root-claude-md.md` for the target shape.
   For each tag in `state.contentSignals`, also **Read** the matching
   `assets/examples/*.md` so the Do/Don't framings can borrow proven
   wording instead of being invented from scratch.

3. **Identify**:
   - Sections that map to specific file paths (candidates for
     `paths:` later if SPLIT is invoked separately)
   - Sections written as long prose that could become Do/Don't bullets
   - Repeated guidance or stale content

4. **Propose** a patch via AskUserQuestion showing before/after for
   each non-trivial transformation. User confirms each cluster of
   changes.

5. **Apply** edits via Edit tool: surgical, no whole-file rewrite
   unless necessary.

6. **Verify** (deterministic commands):
   `references/verify-commands.md` TIGHTEN block (`wc -l` lower than
   before, `git diff --stat` surgical, `grep -c` for 0 `@import`).
   Cross-check: no new sections added that don't trace to user input.

7. **Summarize**: changes applied + suggestion to consider SPLIT if
   root remains ≥150 lines after tightening.

### Mode: SPLIT

Extract sections from root CLAUDE.md into new `.claude/rules/*.md`.

1. **Read** current root CLAUDE.md.

2. **Read** `assets/templates/rule-categories.md` (category
   vocabulary) and `assets/templates/rule-file.md` (per-target
   skeleton). For each tag in `state.contentSignals`, also **Read**
   the matching `assets/examples/*.md`: these tell you the canonical
   shape an extracted section should land in, instead of dumping raw
   prose into a new file.

3. **Parse** section headers (`## Foo`, `### Bar`).

4. **Classify** each section by topic. Use the category vocabulary
   you just loaded. Heuristics:
   table in `references/lookup-tables.md` (header keyword → target filename).

5. **Select** sections ≥ extraction threshold (default 10 lines, or
   adjusted via skill argument if provided).

6. **Propose** the extraction plan via AskUserQuestion: per-target
   filename + line range + suggested `paths:` glob (if directory
   pattern is clear from section content).

7. **Generate** each target rule file using Variant A or B of
   `rule-file.md`:
   - Variant A (`paths:`) when section content references specific
     directories or file patterns.
   - Variant B (no frontmatter) otherwise.

8. **Rewrite** root CLAUDE.md: keep Project Overview + Critical Rules
   + Quick Reference + Rules ToC. Remove extracted sections.
   No `@import` directives: `.claude/rules/*.md` auto-loads.

9. **Verify** (deterministic commands):
   `references/verify-commands.md` NEW/SPLIT/REORGANIZE block,
   including the extraction cross-check.

10. **Summarize**: before/after line counts + new files + Post-generation Hints.

### Mode: REORGANIZE

Cross-check existing root + rules/ structure.

1. **Read** the assets that ground the audit:
   - `assets/templates/rule-file.md`: target shape (Role / Do / Don't
     / Source of Truth) for any restructure proposals.
   - `assets/templates/rule-categories.md`: category vocabulary and
     naming convention for any rename/split proposals.
   - For each tag in `state.contentSignals`, also **Read** the
     matching example (mapping: `references/lookup-tables.md` Assets
     Reference table): canonical shapes to diff existing rules against.

2. **Read** root CLAUDE.md and all `.claude/rules/*.md`.

3. **Audit** each issue:
   - Root size: if >200 lines, propose extraction (subset of SPLIT
     logic). Bash command blocks ≥30 lines are prime candidates for
     extraction to operationally-named rules (`experiments.md`,
     `serving.md`, etc.).
   - Per-rule size: if any rule >150 lines, propose splitting into
     sub-rules with more specific `paths:`.
   - Missing `paths:`: for rules whose content clearly maps to a
     directory, propose adding `paths:` frontmatter.
   - Duplication: if same guidance appears in root and a rule,
     consolidate to the rule and drop from root.
   - Stale `@import`: if root has `@.claude/rules/*` directives,
     propose removing (auto-load handles loading).
   - Missing Do/Don't structure: if a rule is long prose, propose
     restructuring.

4. **Present** findings as a numbered list via AskUserQuestion: the
   user chooses which items to apply (multi-select). No items applied
   without explicit selection.

5. **Apply** each accepted item:
   - Section extraction: use Edit on root + Write for new rule file.
   - Frontmatter addition: use Edit on the target rule.
   - `@import` removal: Edit on root.
   - Restructuring: Edit on target.

6. **Verify** after each apply (deterministic commands):
   `references/verify-commands.md` NEW/SPLIT/REORGANIZE block.

7. **Summarize**: items applied / declined + Post-generation Hints.

A worked trace of REORGANIZE + a `clean-arch` signal, showing what
`contentSignals` changes end-to-end: `references/worked-example.md`.

## Output Conventions

### Do

- Target **root CLAUDE.md ≤200 lines**. Shorter is better for LLM
  compliance.
- Target **each `.claude/rules/*.md` ≤150 lines**. Split into
  sub-rules with more specific `paths:` if longer.
- Use **`paths:` glob frontmatter** for path-scoped rules. Omit
  frontmatter for universal rules.
- Follow **Role / Do / Don't / Examples (optional) / Source of Truth**
  structure in every rule file.
- Reference `.claude/rules/*.md` files from root as **plain text ToC**
  (e.g., `- \`architecture.md\` — layering invariants`).
- Use imperative verifiable statements: "Run `npm test` before push"
  beats "Test your changes".
- Preserve existing user content during TIGHTEN / SPLIT / REORGANIZE.
  Never rewrite content the user did not ask to change.

### Don't

- **Don't generate `@import` directives for `.claude/rules/*`**:
  they auto-load. `@import` would only add token cost.
- **Don't generate emojis** in any output.
- **Don't add sections the user did not request**. No drive-by
  additions like "Testing Best Practices" if testing wasn't discussed.
- **Don't modify `AGENTS.md`**: it's managed by the user / other
  tooling. Only hint about coexistence in summary.
- **Don't manage auto-memory** at `~/.claude/projects/<proj>/memory/`:
  that's Claude's own area.
- **Don't generate `.gitignore` entries**. Mention `CLAUDE.local.md`
  pattern in summary hint only.
- **Don't bundle file changes into one Write call** when separate
  files would be clearer. Multiple Write calls keep diffs reviewable.

## Post-generation Hints and Assets Reference

After any mode completes, append detected-state hints to the summary
(e.g. `AGENTS.md` present, `CLAUDE.local.md` not gitignored). Full
hint table and the per-mode "always Read" / "signal Read" asset
lookup table: `references/lookup-tables.md`.

## Invocation

- Explicit slash: `/docs:write-rules`
- Natural language: any phrase from the description's Triggers list
  ("rules 작성", "restructure my CLAUDE.md", "split claude.md", ...)
