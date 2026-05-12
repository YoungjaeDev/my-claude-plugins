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
}

mode =
  NEW         if not state.hasClaudeMd
  TIGHTEN     if state.hasClaudeMd and state.claudeMdLines <= 200 and not state.hasRulesDir
  SPLIT       if state.hasClaudeMd and state.claudeMdLines > 200 and not state.hasRulesDir
  REORGANIZE  if state.hasClaudeMd and state.hasRulesDir
```

### Execution

1. Run state scan:
   ```bash
   { test -f CLAUDE.md && wc -l CLAUDE.md; }
   { test -f .claude/CLAUDE.md && wc -l .claude/CLAUDE.md; }
   { test -d .claude/rules && ls .claude/rules/*.md 2>/dev/null | wc -l; }
   test -f AGENTS.md && echo agents-md-present
   ```

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

6. **Generate** `.claude/rules/*.md` files — one per selected
   category, using `assets/templates/rule-file.md` as the per-file
   skeleton. Use Variant A (`paths:`) for path-scoped categories,
   Variant B (no frontmatter) for universal ones.

7. **Write** files in this order: `.claude/rules/*.md` first, then
   `./CLAUDE.md` last (so the root file's "Rules" ToC references
   files that already exist).

8. **Verify**: root ≤200 lines, each rule ≤150 lines, root contains
   no `@import` for rules/.

9. **Summarize**: file list with line counts + Post-generation Hints.

### Mode: TIGHTEN

Patch the existing root CLAUDE.md in place — no new rules/ files.

1. **Read** current root CLAUDE.md.

2. **Read** `assets/templates/root-claude-md.md` for the target shape.

3. **Identify**:
   - Sections that map to specific file paths (candidates for
     `paths:` later if SPLIT is invoked separately)
   - Sections written as long prose that could become Do/Don't bullets
   - Repeated guidance or stale content

4. **Propose** a patch via AskUserQuestion showing before/after for
   each non-trivial transformation. User confirms each cluster of
   changes.

5. **Apply** edits via Edit tool — surgical, no whole-file rewrite
   unless necessary.

6. **Verify**: line count delta, no new sections added that don't
   trace to user input.

7. **Summarize**: changes applied + suggestion to consider SPLIT if
   root remains ≥150 lines after tightening.

### Mode: SPLIT

Extract sections from root CLAUDE.md into new `.claude/rules/*.md`.

1. **Read** current root CLAUDE.md.

2. **Parse** section headers (`## Foo`, `### Bar`).

3. **Classify** each section by topic. Use `assets/templates/rule-categories.md`
   as the category vocabulary. Heuristics:
   - Headers containing "Architecture", "Design", "Structure" → `architecture.md`
   - Headers containing "Framework", "Next.js", "React", "Vue" → `framework.md`
   - Headers containing "Stack", "Tool", "Database", "Style" → `tech-stack.md`
   - Headers containing "Test", "QA", "Verification" → `testing.md`
   - Headers containing "Deploy", "Release", "CI" → `deployment.md`
   - Headers containing "Security", "Auth", "Permission" → `security.md`
   - Headers with dense bash command blocks ≥30 lines → `<purpose>.md`
     (e.g., `experiments.md`, `vlm-serving.md`)

4. **Select** sections ≥ extraction threshold (default 10 lines, or
   adjusted via skill argument if provided).

5. **Propose** the extraction plan via AskUserQuestion: per-target
   filename + line range + suggested `paths:` glob (if directory
   pattern is clear from section content).

6. **Generate** each target rule file using
   `assets/templates/rule-file.md` Variant A or B:
   - Variant A (`paths:`) when section content references specific
     directories or file patterns.
   - Variant B (no frontmatter) otherwise.

7. **Rewrite** root CLAUDE.md: keep Project Overview + Critical Rules
   + Quick Reference + Rules ToC. Remove extracted sections.
   No `@import` directives — `.claude/rules/*.md` auto-loads.

8. **Verify**: root ≤200 lines, each new rule ≤150 lines, no content
   lost (sum of extracted sections + reduced root ≈ original root).

9. **Summarize**: before/after line counts + new files + Post-generation Hints.

### Mode: REORGANIZE

Cross-check existing root + rules/ structure.

1. **Read** root CLAUDE.md and all `.claude/rules/*.md`.

2. **Audit** each issue:
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

3. **Present** findings as a numbered list via AskUserQuestion — user
   chooses which items to apply (multi-select). No items applied
   without explicit selection.

4. **Apply** each accepted item:
   - Section extraction: use Edit on root + Write for new rule file.
   - Frontmatter addition: use Edit on the target rule.
   - `@import` removal: Edit on root.
   - Restructuring: Edit on target.

5. **Verify** after each apply: file syntax intact, line counts
   match plan.

6. **Summarize**: items applied / declined + Post-generation Hints.

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

- **Don't generate `@import` directives for `.claude/rules/*`** —
  they auto-load. `@import` would only add token cost.
- **Don't generate emojis** in any output.
- **Don't add sections the user did not request**. No drive-by
  additions like "Testing Best Practices" if testing wasn't discussed.
- **Don't modify `AGENTS.md`** — it's managed by the user / other
  tooling. Only hint about coexistence in summary.
- **Don't manage auto-memory** at `~/.claude/projects/<proj>/memory/`
  — that's Claude's own area.
- **Don't generate `.gitignore` entries**. Mention `CLAUDE.local.md`
  pattern in summary hint only.
- **Don't bundle file changes into one Write call** when separate
  files would be clearer. Multiple Write calls keep diffs reviewable.

## Post-generation Hints

After any mode completes, append these hints to the summary based on
detected state. Each hint is informational only — no auto-modification.

| Detected state | Hint shown to user |
|---|---|
| `AGENTS.md` exists | "Detected `AGENTS.md` ({LINES} lines). Consider adding `@AGENTS.md` as the first line of CLAUDE.md so Claude reads both without duplication. See `assets/references/claude-code-memory.md` AGENTS.md section." |
| No `.gitignore` mentions `CLAUDE.local.md` | "Tip: 개인 프로젝트별 선호도는 `CLAUDE.local.md` 에 두고 `.gitignore` 에 추가하면 버전 제어 영향 없이 사용 가능." |
| Root file is `./.claude/CLAUDE.md` (not `./CLAUDE.md`) | "Note: `./.claude/CLAUDE.md` 와 `./CLAUDE.md` 둘 다 유효 — 둘 다 있으면 둘 다 로드되니 하나만 유지 권장." |
| Generated 3+ rules files | "참고: 자동 메모리는 `~/.claude/projects/<proj>/memory/` 에서 Claude 가 직접 관리. write-rules 가 만든 `.claude/rules/` 와 무관." |
| `/compact` 워크플로우가 잦다고 사용자가 언급 | "주의: 하위 디렉토리의 CLAUDE.md 는 `/compact` 후 자동 재주입 안 됨. 핵심 지침은 root CLAUDE.md 에." |

## Assets Reference

Files this skill Read s on demand, by mode:

| Mode | Read | Purpose |
|---|---|---|
| NEW | `assets/templates/root-claude-md.md` | root skeleton |
| NEW | `assets/templates/rule-file.md` | rule file skeleton |
| NEW | `assets/templates/rule-categories.md` | category catalog + globs |
| NEW (tech stack matches) | `assets/examples/nextjs-clean-arch.md` | Clean Architecture example |
| NEW (tech stack matches) | `assets/examples/nextjs-framework.md` | Next.js framework example |
| NEW (tech stack matches) | `assets/examples/tech-stack-supabase.md` | Tech stack example |
| NEW (product-heavy) | `assets/examples/saas-service-spec.md` | PRD-rules hybrid example |
| TIGHTEN | `assets/templates/root-claude-md.md` | target shape reference |
| SPLIT | `assets/templates/rule-categories.md` | classification vocabulary |
| SPLIT | `assets/templates/rule-file.md` | per-extracted skeleton |
| REORGANIZE | `assets/templates/rule-file.md` | shape for restructure |
| REORGANIZE | `assets/templates/rule-categories.md` | category audit |
| Any (on "why" question) | `assets/references/claude-code-memory.md` | official docs grounding |

## Invocation

- Explicit slash: `/rules-forge:write-rules`
- Natural language: any phrase from the description's Triggers list
  ("rules 작성", "restructure my CLAUDE.md", "split claude.md", ...)
