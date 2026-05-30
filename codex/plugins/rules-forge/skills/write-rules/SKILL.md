---
name: write-rules
description: Generate or restructure CLAUDE.md systems with modular .claude/rules/ delegation. Use when starting new projects, restructuring existing CLAUDE.md, splitting monolithic CLAUDE.md into modular rules files, modularizing project instructions, or aligning rules to Claude Code 2026 best practices. Auto-detects project state and proposes the right mode. Triggers — "rules 작성", "write rules", "generate claude.md", "restructure claude.md", "split claude.md", "modularize instructions", "organize project rules", "rules 분리".
allowed-tools: Read Write Edit Glob Grep Bash
bridge_source: rules-forge/write-rules
---

# Write Rules

## Role

AI Context Architect for AGENTS.md systems. Scans the project state,
detects which of four operating modes applies (NEW / TIGHTEN / SPLIT /
REORGANIZE), confirms with the user via AskUserQuestion, then
generates or restructures the rules layout following Claude Code 2026
official patterns: `.codex/rules/*.md` auto-load with `paths:` glob
scoping, 200-line root AGENTS.md target, Do/Don't structure, no
redundant `@import` directives.

Output conventions are tuned to the official memory docs (see
`assets/references/claude-code-memory.md`). Adapted templates in
`assets/templates/` and reference examples in `assets/examples/`
ground the generation.

## Modes

| Mode | Trigger | What it does |
|---|---|---|
| **NEW** | `AGENTS.md` 부재 | 인터뷰 → 카테고리 선택 → root + 초기 `.codex/rules/*.md` 생성 |
| **TIGHTEN** | `AGENTS.md` ≤200줄, `.codex/rules/` 비어있음 | root 만 Do/Don't 로 재구조화 + `paths:` 후보 제안, 신규 rules 파일 없음 |
| **SPLIT** | `AGENTS.md` >200줄, `.codex/rules/` 비어있음 | 섹션 추출 → `.codex/rules/<topic>.md` 자동 생성, root 축약 |
| **REORGANIZE** | `AGENTS.md` + `.codex/rules/` 둘 다 존재 | root cap 초과·rules 중복·`paths:` 누락 점검 후 per-file 패치 |

## Detection Logic

Scan project state with Bash, then propose a mode.

```
state = {
  hasClaudeMd:      exists("./AGENTS.md") or exists("./.codex/AGENTS.md")
  claudeMdPath:     "./AGENTS.md" or "./.codex/AGENTS.md" (whichever exists)
  claudeMdLines:    wc -l on the file if present
  hasRulesDir:      exists("./.codex/rules/") and contains at least one *.md
  rulesFileCount:   count of .codex/rules/*.md
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
   ```bash
   { test -f AGENTS.md && wc -l AGENTS.md; }
   { test -f .codex/AGENTS.md && wc -l .codex/AGENTS.md; }
   { test -d .codex/rules && ls .codex/rules/*.md 2>/dev/null | wc -l; }
   test -f AGENTS.md && echo agents-md-present

   # Content signals — scan root + rules for canonical tech-stack
   # markers that map to a bundled example.
   SCAN_FILES=$(ls AGENTS.md .codex/AGENTS.md .codex/rules/*.md 2>/dev/null)
   [ -n "$SCAN_FILES" ] && {
     grep -liE 'clean architecture|composition root|use ?case|repository pattern' $SCAN_FILES && echo signal:clean-arch
     grep -liE 'next\.js|server component|server action|app router'              $SCAN_FILES && echo signal:nextjs-framework
     grep -liE 'supabase|rls policy|row-level security'                          $SCAN_FILES && echo signal:supabase
     grep -liE 'pricing tier|service spec|prd|target user'                       $SCAN_FILES && echo signal:service-spec
   } 2>/dev/null
   ```

   Collect `signal:*` lines into `state.contentSignals`. Empty list
   is fine — examples are then skipped.

2. Compute `mode` per the rules above.

3. Present the recommendation via AskUserQuestion with one
   recommended option and three override options. Include detected
   facts in the question body:

   ```
   "감지: AGENTS.md {LINES}줄, .codex/rules/ {COUNT}개 파일, AGENTS.md {존재/부재}.
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

Generate a fresh AGENTS.md system from scratch.

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

6. **Generate** `.codex/rules/*.md` files — one per selected
   category, using `assets/templates/rule-file.md` as the per-file
   skeleton. Use Variant A (`paths:`) for path-scoped categories,
   Variant B (no frontmatter) for universal ones.

7. **Write** files in this order: `.codex/rules/*.md` first, then
   `./AGENTS.md` last (so the root file's "Rules" ToC references
   files that already exist).

8. **Verify** (deterministic commands):
   ```bash
   wc -l AGENTS.md                                     # expect ≤200
   find .codex/rules -name '*.md' -exec wc -l {} +    # each ≤150
   grep -c '^@\.codex/rules' AGENTS.md                # expect 0
   ```

9. **Summarize**: file list with line counts + Post-generation Hints.

### Mode: TIGHTEN

Patch the existing root AGENTS.md in place — no new rules/ files.

1. **Read** current root AGENTS.md.

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

5. **Apply** edits via Edit tool — surgical, no whole-file rewrite
   unless necessary.

6. **Verify** (deterministic commands):
   ```bash
   wc -l AGENTS.md                           # expect lower than before
   git diff --stat AGENTS.md                 # confirm scope is surgical
   grep -c '^@\.codex/rules' AGENTS.md      # expect 0
   ```
   Cross-check: no new sections added that don't trace to user input.

7. **Summarize**: changes applied + suggestion to consider SPLIT if
   root remains ≥150 lines after tightening.

### Mode: SPLIT

Extract sections from root AGENTS.md into new `.codex/rules/*.md`.

1. **Read** current root AGENTS.md.

2. **Read** `assets/templates/rule-categories.md` (category
   vocabulary) and `assets/templates/rule-file.md` (per-target
   skeleton). For each tag in `state.contentSignals`, also **Read**
   the matching `assets/examples/*.md` — these tell you the canonical
   shape an extracted section should land in, instead of dumping raw
   prose into a new file.

3. **Parse** section headers (`## Foo`, `### Bar`).

4. **Classify** each section by topic. Use the category vocabulary
   you just loaded. Heuristics:
   - Headers containing "Architecture", "Design", "Structure" → `architecture.md`
   - Headers containing "Framework", "Next.js", "React", "Vue" → `framework.md`
   - Headers containing "Stack", "Tool", "Database", "Style" → `tech-stack.md`
   - Headers containing "Test", "QA", "Verification" → `testing.md`
   - Headers containing "Deploy", "Release", "CI" → `deployment.md`
   - Headers containing "Security", "Auth", "Permission" → `security.md`
   - Headers with dense bash command blocks ≥30 lines → `<purpose>.md`
     (e.g., `experiments.md`, `vlm-serving.md`)

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

8. **Rewrite** root AGENTS.md: keep Project Overview + Critical Rules
   + Quick Reference + Rules ToC. Remove extracted sections.
   No `@import` directives — `.codex/rules/*.md` auto-loads.

9. **Verify** (deterministic commands):
   ```bash
   wc -l AGENTS.md                                     # expect ≤200
   find .codex/rules -name '*.md' -exec wc -l {} +    # each ≤150
   grep -c '^@\.codex/rules' AGENTS.md                # expect 0
   ```
   Cross-check: sum of extracted sections + reduced root ≈ original
   root (no content silently dropped).

10. **Summarize**: before/after line counts + new files + Post-generation Hints.

### Mode: REORGANIZE

Cross-check existing root + rules/ structure.

1. **Read** the assets that ground the audit:
   - `assets/templates/rule-file.md` — target shape (Role / Do / Don't
     / Source of Truth) for any restructure proposals.
   - `assets/templates/rule-categories.md` — category vocabulary and
     naming convention for any rename/split proposals.
   - For each tag in `state.contentSignals`, also **Read** the
     matching example: `clean-arch` → `assets/examples/nextjs-clean-arch.md`,
     `nextjs-framework` → `assets/examples/nextjs-framework.md`,
     `supabase` → `assets/examples/tech-stack-supabase.md`,
     `service-spec` → `assets/examples/saas-service-spec.md`. These
     give canonical reference shapes for comparing against existing
     rules — without them, "should this rule look different?" is a
     guess instead of a diff.

2. **Read** root AGENTS.md and all `.codex/rules/*.md`.

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
   - Stale `@import`: if root has `@.codex/rules/*` directives,
     propose removing (auto-load handles loading).
   - Missing Do/Don't structure: if a rule is long prose, propose
     restructuring.

4. **Present** findings as a numbered list via AskUserQuestion — user
   chooses which items to apply (multi-select). No items applied
   without explicit selection.

5. **Apply** each accepted item:
   - Section extraction: use Edit on root + Write for new rule file.
   - Frontmatter addition: use Edit on the target rule.
   - `@import` removal: Edit on root.
   - Restructuring: Edit on target.

6. **Verify** after each apply (deterministic commands):
   ```bash
   wc -l AGENTS.md                                     # expect ≤200
   find .codex/rules -name '*.md' -exec wc -l {} +    # each ≤150
   grep -c '^@\.codex/rules' AGENTS.md                # expect 0
   ```

7. **Summarize**: items applied / declined + Post-generation Hints.

## Worked Example: REORGANIZE + Clean Arch signal

A short trace of how the pieces fit together when the audit lands on
a Clean Architecture codebase. The point is to show what
`contentSignals` actually changes — without it the audit is generic
prose; with it the audit can cite a canonical reference.

```
Input state:
  AGENTS.md         (210 lines)
  .codex/rules/architecture.md  (180 lines, prose-heavy)

Scan:
  state.claudeMdLines = 210
  state.hasRulesDir   = true
  state.contentSignals = ["clean-arch"]      ← grep hit on "Composition Root"
  mode = REORGANIZE

Read (step 1):
  assets/templates/rule-file.md              ← target shape
  assets/templates/rule-categories.md        ← naming/paths vocab
  assets/examples/nextjs-clean-arch.md       ← canonical Clean Arch shape
                                               (only because signal matched)

Read (step 2):
  AGENTS.md, .codex/rules/architecture.md

Audit findings (step 3):
  - root size 210 > 200 → propose extracting "Build & Test" block
  - architecture.md 180 > 150 → propose splitting by layer
    (domain.md / application.md / infrastructure.md), with paths:
    globs grounded in nextjs-clean-arch.md's layer map
  - architecture.md is prose → propose restructure to
    Role / Do / Don't using rule-file.md Variant A
```

Without `contentSignals`, step 3 still flags the size issues but the
restructure proposal would be generic. The signal-driven Read of
`nextjs-clean-arch.md` is what turns "this rule should be shorter"
into "this rule should split along the layer seams the example uses".

## Output Conventions

### Do

- Target **root AGENTS.md ≤200 lines**. Shorter is better for LLM
  compliance.
- Target **each `.codex/rules/*.md` ≤150 lines**. Split into
  sub-rules with more specific `paths:` if longer.
- Use **`paths:` glob frontmatter** for path-scoped rules. Omit
  frontmatter for universal rules.
- Follow **Role / Do / Don't / Examples (optional) / Source of Truth**
  structure in every rule file.
- Reference `.codex/rules/*.md` files from root as **plain text ToC**
  (e.g., `- \`architecture.md\` — layering invariants`).
- Use imperative verifiable statements: "Run `npm test` before push"
  beats "Test your changes".
- Preserve existing user content during TIGHTEN / SPLIT / REORGANIZE.
  Never rewrite content the user did not ask to change.

### Don't

- **Don't generate `@import` directives for `.codex/rules/*`** —
  they auto-load. `@import` would only add token cost.
- **Don't generate emojis** in any output.
- **Don't add sections the user did not request**. No drive-by
  additions like "Testing Best Practices" if testing wasn't discussed.
- **Don't modify `AGENTS.md`** — it's managed by the user / other
  tooling. Only hint about coexistence in summary.
- **Don't manage auto-memory** at `~/.codex/projects/<proj>/memory/`
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
| `AGENTS.md` exists | "Detected `AGENTS.md` ({LINES} lines). Consider adding `@AGENTS.md` as the first line of AGENTS.md so Claude reads both without duplication. See `assets/references/claude-code-memory.md` AGENTS.md section." |
| No `.gitignore` mentions `CLAUDE.local.md` | "Tip: 개인 프로젝트별 선호도는 `CLAUDE.local.md` 에 두고 `.gitignore` 에 추가하면 버전 제어 영향 없이 사용 가능." |
| Root file is `./.codex/AGENTS.md` (not `./AGENTS.md`) | "Note: `./.codex/AGENTS.md` 와 `./AGENTS.md` 둘 다 유효 — 둘 다 있으면 둘 다 로드되니 하나만 유지 권장." |
| Generated 3+ rules files | "참고: 자동 메모리는 `~/.codex/projects/<proj>/memory/` 에서 Claude 가 직접 관리. write-rules 가 만든 `.codex/rules/` 와 무관." |
| `/compact` 워크플로우가 잦다고 사용자가 언급 | "주의: 하위 디렉토리의 AGENTS.md 는 `/compact` 후 자동 재주입 안 됨. 핵심 지침은 root AGENTS.md 에." |

## Assets Reference

Index of the files each mode's execution steps already cite. The
single source of truth for *when* to Read each file is the numbered
step list inside each Mode Execution section — this table is just
a quick lookup.

| Mode | Always Read | Read if `contentSignals` matches |
|---|---|---|
| NEW (interview) | `templates/root-claude-md.md`, `templates/rule-file.md`, `templates/rule-categories.md` | `examples/nextjs-clean-arch.md` (clean-arch), `examples/nextjs-framework.md` (nextjs-framework), `examples/tech-stack-supabase.md` (supabase), `examples/saas-service-spec.md` (service-spec) |
| TIGHTEN | `templates/root-claude-md.md` | same example-tag mapping as above |
| SPLIT | `templates/rule-categories.md`, `templates/rule-file.md` | same example-tag mapping as above |
| REORGANIZE | `templates/rule-file.md`, `templates/rule-categories.md` | same example-tag mapping as above |
| Any (when user asks "why this structure") | `references/claude-code-memory.md` | — |

`contentSignals` are emitted by the Detection Logic bash scan
(`grep -liE`). Tags: `clean-arch`, `nextjs-framework`, `supabase`,
`service-spec`. Empty list = no example Read.

## Invocation

- Explicit slash: `/rules-forge:write-rules`
- Natural language: any phrase from the description's Triggers list
  ("rules 작성", "restructure my AGENTS.md", "split claude.md", ...)
