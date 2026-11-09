# Mode Procedures

The numbered steps for the 4 write-rules modes (NEW, TIGHTEN, SPLIT, REORGANIZE), read after the mode is confirmed. Paths are relative to the skill directory; the bright lines and output conventions stay in `SKILL.md`.

## Mode: NEW

Generate a fresh CLAUDE.md system from scratch.

1. **Interview** with the question tool (max 2 questions):
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

## Mode: TIGHTEN

Patch the existing root CLAUDE.md in place: no new rules/ files.

1. **Read** current root CLAUDE.md.

2. **Read** `assets/templates/root-claude-md.md` for the target shape.
   For each tag in `state.contentSignals`, also Read the matching
   `assets/examples/*.md` so the Do/Don't framings can borrow proven
   wording instead of being invented from scratch.

3. **Identify**:
   - Sections that map to specific file paths (candidates for
     `paths:` later if SPLIT is invoked separately)
   - Sections written as long prose that could become Do/Don't bullets
   - Repeated guidance or stale content

4. **Propose** a patch with the question tool showing before/after for
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

## Mode: SPLIT

Extract sections from root CLAUDE.md into new `.claude/rules/*.md`.

1. **Read** current root CLAUDE.md.

2. **Read** `assets/templates/rule-categories.md` (category
   vocabulary) and `assets/templates/rule-file.md` (per-target
   skeleton). For each tag in `state.contentSignals`, also Read
   the matching `assets/examples/*.md`: these tell you the canonical
   shape an extracted section should land in, instead of dumping raw
   prose into a new file.

3. **Parse** section headers (`## Foo`, `### Bar`).

4. **Classify** each section by topic. Use the category vocabulary
   you just loaded and the heuristics table in `references/lookup-tables.md`
   (header keyword → target filename).

5. **Select** sections ≥ extraction threshold (default 10 lines, or
   adjusted via skill argument if provided).

6. **Propose** the extraction plan with the question tool: per-target
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

## Mode: REORGANIZE

Cross-check existing root + rules/ structure.

1. **Read** the assets that ground the audit:
   - `assets/templates/rule-file.md`: target shape (Role / Do / Don't
     / Source of Truth) for any restructure proposals.
   - `assets/templates/rule-categories.md`: category vocabulary and
     naming convention for any rename/split proposals.
   - For each tag in `state.contentSignals`, also Read the
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

4. **Present** findings as a numbered list with the question tool: the
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
