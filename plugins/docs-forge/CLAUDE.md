# docs-forge Plugin

Generate and analyze README/CHANGELOG files using CRO best practices from awesome-readme.

## Skills

| Skill | Description |
|-------|-------------|
| `readme-guide` | README patterns and templates reference |
| `changelog-guide` | CHANGELOG format and automation guide |
| `deploy-doc-guide` | Deployment / procedure doc skeleton (summary + prerequisites + numbered steps) |
| `moc-guide` | MOC index generation spec (hook precedence, lightweight vs strict) |
| `write-rules` | CLAUDE.md + `.claude/rules/` generation with auto mode detection (absorbed from `rules-forge`) |
| `interview-methodology` | Requirements interview: breadth-first / depth-first / relentless grill-me modes (absorbed from `interview`) |
| `tcrei-prompt` | Rewrite a prompt into Google's TCREI structure for next-session reuse (absorbed from `tcrei-prompt`) |
| `voice-prompt` | Normalize Korean voice-mode STT input before acting on it (absorbed from `voice-prompt`) |
| `skill-forge` | Write or revise a skill — frontmatter schema, writing levers, structure, three-runtime packaging contract |
| `skill-audit` | Diagnose one skill across seven axes, returning P0/P1/P2 findings with concrete edits |
| `skill-fleet-review` | Repository-wide skill sweep — measure first, review a selected cohort, emit a dated audit report + CSV |

## Commands

| Command | Description |
|---------|-------------|
| `/docs-forge:readme` | Generate or analyze README |
| `/docs-forge:changelog` | Generate or analyze CHANGELOG |
| `/docs-forge:deploy-doc` | Generate or restructure a deployment / procedure doc |
| `/docs-forge:moc` | Generate a Map of Content index for a docs folder |

## References

Comprehensive reference documents in `references/`:

| File | Content |
|------|---------|
| `README_PATTERNS.md` | Structure patterns from 9 awesome-readme examples |
| `CHANGELOG_PATTERNS.md` | Keep a Changelog format and automation |
| `TEMPLATES.md` | Copy-paste templates for 6 project types |
| `CRO_CHECKLIST.md` | Conversion optimization checklist |
| `EXAMPLES_ANALYSIS.md` | Detailed analysis of each example project |
| `DEPLOY_DOC_PATTERNS.md` | Deployment-doc skeleton, filled example, anti-patterns (Korean-default output examples) |
| `MOC_PATTERNS.md` | MOC hook-sourcing ladder, lightweight + strict examples (Korean-default output examples) |

## Analyzed Examples

Based on awesome-readme curated list:

- ai/size-limit - User segmentation, "Who Uses"
- gofiber/fiber - Benchmarks, Limitations transparency
- httpie/cli - GIF demo, progressive examples
- release-it/release-it - Multi-path install, schema config
- dbt-labs/dbt-core - Visual architecture, analogy-driven
- PostHog/posthog - Cloud-first, feature density
- ryanoasis/nerd-fonts - Decision tree, platform matrix
- electron-markdownify - Hero GIF, dual install paths
- react-parallax-tilt - Props table, external demos

## Usage

### Generate README

```
/docs-forge:readme generate --type cli
/docs-forge:readme generate --type library
/docs-forge:readme generate --type react-component
/docs-forge:readme generate --type mcp-plugin
/docs-forge:readme generate --type saas
/docs-forge:readme generate --type desktop
```

### Analyze Existing README

```
/docs-forge:readme analyze
```

### Generate CHANGELOG

```
/docs-forge:changelog init
/docs-forge:changelog add "Added new feature"
```

### Generate Deployment Doc

```
/docs-forge:deploy-doc generate docs/deploy/inference.md --title "추론 서비스 배포"
/docs-forge:deploy-doc generate docs/deploy/inference.md --links deploy/spec.md
/docs-forge:deploy-doc rewrite docs/legacy-procedure.md
```

### Generate MOC

```
/docs-forge:moc docs/
/docs-forge:moc docs/ --strict
/docs-forge:moc docs/ --out docs/CONTENTS.md
```

## skill-forge / skill-audit / skill-fleet-review

Three skills that write, diagnose, and sweep skills. Split because they are called at different
moments; merging them would put the fleet-sweep procedure on the single-skill authoring path.

`skill-forge` owns the rules — `skills/skill-forge/references/{frontmatter,writing-levers,structure,runtime-contract}.md` —
and the other two apply them. The bundled `skills/skill-forge/scripts/measure-skills.mjs` produces
the per-skill numbers (lines, body tokens, description length, sections, references depth, bundled
scripts, frontmatter keys) plus a fleet-wide frontmatter key inventory.

**Self-contained by design.** No body, reference, or script here may instruct the reader to open an
external marketplace skill, and the measurement script is bundled rather than pointing at
`docs/audit/measure-skills.mjs`. External sources are cited as provenance only. A pointer added to
one of them fails silently for any user who does not have that skill installed.

## write-rules (흡수: rules-forge)

**Generate and restructure CLAUDE.md systems with modular `.claude/rules/` delegation**

### Overview

Rules Forge helps create and maintain clean, modular CLAUDE.md
instruction systems. A single skill (`write-rules`) auto-detects
project state and branches into one of four modes:

- **NEW** — Generate a fresh CLAUDE.md system + initial `.claude/rules/*.md`
- **TIGHTEN** — Patch an existing small CLAUDE.md into Do/Don't shape
- **SPLIT** — Extract sections from a monolithic CLAUDE.md into modular rules
- **REORGANIZE** — Audit existing root + rules/ structure for drift

Aligned with Claude Code 2026 official docs: `.claude/rules/*.md`
auto-load with `paths:` glob scoping, 200-line root target, no
redundant `@import` directives.

### Skills

| Skill | Trigger | Purpose |
|-------|---------|---------|
| `write-rules` | `/docs-forge:write-rules` or natural language | Generate or restructure CLAUDE.md + `.claude/rules/` with auto mode detection |

**Auto-triggers** (natural language phrases the skill responds to):
- "rules 작성", "write rules"
- "generate claude.md", "create claude.md system"
- "restructure claude.md", "split claude.md", "modularize instructions"
- "organize project rules", "rules 분리"

### Assets

The skill ships with three asset categories under
`skills/write-rules/assets/`:

| Directory | Contents | When loaded |
|-----------|----------|-------------|
| `references/` | Verbatim KR excerpt of Claude Code's official memory docs (CLAUDE.md placement, `.claude/rules/`, auto-memory, AGENTS.md, troubleshooting) | On demand when user asks "why this structure" or skill needs to cite docs |
| `templates/` | Output skeletons — root CLAUDE.md, single rule file (Variants A/B), category catalog | Per mode execution |
| `examples/` | Four adapted reference rules from `codefactory-co/golden-rabbit-antigravity-v1` (Next.js Clean Architecture, Next.js Framework, Tech Stack: Supabase, SaaS Service Spec) | Per mode execution when tech stack matches |

Assets are loaded with the `Read` tool only when the skill needs them
— they don't enter context at session start.

### Output File Structure

The skill generates this canonical layout:

```
your-project/
├── CLAUDE.md                   # Root (≤200 lines target)
└── .claude/
    └── rules/
        ├── architecture.md     # path-scoped or always-load
        ├── framework.md        # path-scoped
        ├── tech-stack.md       # usually always-load
        └── ...                 # one per detected category
```

Optional companions the skill detects and hints about (but does not
generate):

- `AGENTS.md` — if present, skill suggests `@AGENTS.md` import line
- `CLAUDE.local.md` — skill hints about `.gitignore` pattern

### Output Conventions

#### Root CLAUDE.md

- Project overview (1–2 sentences)
- Critical Rules (5–7 always-visible safety items)
- Quick Reference table (build / test / dev commands)
- Code Structure (brief, ≤10 lines)
- Rules section (plain text ToC pointing to `.claude/rules/*.md`)
- **No `@import` directives** — `.claude/rules/*.md` auto-loads

#### Each `.claude/rules/*.md`

Follows the proven Role / Do / Don't / Examples / Source of Truth
shape (the same pattern this repo uses in
`.claude/rules/dual-integration.md`).

Variant A (path-scoped):
```yaml
---
paths:
  - "src/api/**/*.ts"
---
```

Variant B (always-load): no frontmatter at all.

### Integration with `claude-md-management`

Rules Forge handles **initial creation and major restructuring**.
The official `claude-md-management` plugin handles **ongoing
maintenance** — incremental rule additions, edits, and refactors.

Recommended workflow:

1. Initial setup → `write-rules` (mode = NEW)
2. Daily updates → `claude-md-management`
3. Major refactors → `write-rules` (mode = REORGANIZE or SPLIT)

### Version History

- **2.1.0** (2026-05-13) — Asset routing fixes (non-breaking)
  - Mode execution sections now cite `Read assets/*` inline at the
    first step (was: bottom-of-file `Assets Reference` table only).
    REORGANIZE / TIGHTEN / SPLIT no longer skip the bundled examples
    when a tech-stack signal is present.
  - Detection Logic adds `contentSignals` field (grep tags:
    `clean-arch`, `nextjs-framework`, `supabase`, `service-spec`)
    that drives which `assets/examples/*.md` the mode Reads. Signals
    do not affect mode selection.
  - Verify steps in every mode replaced prose checks with concrete
    bash commands (`wc -l`, `find`, `grep -c '^@\.claude/rules'`).
  - Added a Worked Example section showing REORGANIZE + Clean Arch
    signal flow end-to-end.
- **2.0.0** (2026-05-12) — BREAKING
  - Consolidated `rules-guide` skill + `generate` / `split` commands
    into a single `write-rules` skill with internal mode detection
  - Aligned output with Claude Code 2026 docs (200-line root cap,
    `paths:` glob scoping, no auto `@import` for `.claude/rules/`)
  - Added `assets/` directory with references / templates / examples
  - Removed `commands/` directory (commands merged into skills per
    docs change)
  - Migration: `/rules-forge:generate` and `/rules-forge:split` removed.
    Use `/docs-forge:write-rules` (or natural-language triggers).
- **1.0.0** (2026-02-14) — Initial release

## tcrei-prompt (흡수: tcrei-prompt)

Rewrite prompts using Google's TCREI structure for next-session reuse.

### Skill

| Skill | Description |
|-------|-------------|
| `tcrei-prompt` | Diagnose missing TCREI elements, interview to fill gaps, generate copy-paste-ready prompt |

### TCREI Framework

Google's Prompting Essentials (Coursera) 5-step structure:

| Step | Purpose | Sub-elements |
|------|---------|-------------|
| Task | Define the action | verb + output + constraints |
| Context | Provide background | audience + purpose + source material |
| References | Show desired form | samples, schemas, tone examples |
| Evaluate | Set quality gates | must-have + must-not + verification |
| Iterate | Plan refinements | specific numbers, rules, actions |

### Workflow

1. Diagnose which T/C/R/E/I elements exist in the original prompt
2. Interview for missing elements using AskUserQuestion
3. Generate structured TCREI prompt
4. Self-verify with OMC verifier agent
5. Save to `.claude/prompts/{YYYY-MM-DD}-{name}.md`

### Triggers

- "TCREI"
- "structure this prompt"
- "prompt enhance"
- "make a prompt for next session"

## interview-methodology (흡수: interview)

Structured requirements gathering before implementation.

### Skill

| Skill | Description |
|-------|-------------|
| `interview-methodology` | In-depth user interview framework |

### Purpose

Conduct thorough interviews to uncover hidden needs, constraints, and edge cases before writing code.

### Triggers

- "interview me"
- "ask me questions"
- "understand my needs before implementing"
- "spec-based development"
- Feature requests without detailed specs

### Three Modes

- **Breadth-first** (the 5-phase flow) - sweep every category; for large, multi-decision work.
- **Depth-first / Socratic (focused)** - target the single biggest uncertainty, one question at a time; for one-or-two-decision work. The two compose (map breadth-first, then dive focused).
- **Relentless / stress-test (adversarial)** - for "grill me" / "poke holes in this": press an existing plan, inverting the default "don't bother the user" posture. "When NOT to Interview" does not apply; adds a hard act-gate (no action until the user confirms shared understanding), dependency-frontier ordering, and non-blocking fact-dispatch.

### Interview Phases (breadth-first mode)

1. **Context Gathering** (2-3 questions) - Big picture
2. **Deep Dive** (5-10 questions) - Technical, UX, edge cases
3. **Edge Case Exploration** (3-5 questions) - "What if" scenarios
4. **Prioritization** (2-3 questions) - Must-have vs nice-to-have
5. **Validation** (1-2 questions) - Confirm understanding

### Key Principles

- Use the interactive-input gate for all questions (Claude: AskUserQuestion; Codex: request_user_input when exposed)
- Verify against the codebase first - don't ask what the repo already answers
- Ask non-obvious questions (not what user already said)
- Per-question scaffold: current understanding / stuck decision / recommended default / question
- **When NOT to interview**: skip (or drop to 2-3 targeted questions) for already-concrete requests, typos, small config/copy changes, dep bumps, test additions, or "just do it"

### Output

Scale to weight: **lightweight close** (Decisions + Open questions inline, no file) for small/focused interviews; **full spec file** for large/multi-decision interviews.

Full spec at `.claude/spec/{YYYY-MM-DD}-{feature-name}.md`:

```markdown
# Feature Specification: [Name]

## Overview
## User Stories
## Requirements (P0/P1/P2)
## Technical Constraints
## Edge Cases
## Out of Scope
```

## voice-prompt (흡수: voice-prompt)

One skill, `voice-prompt`, that normalizes Korean voice-mode STT input before the session acts
on it. Typed once as `/docs-forge:voice-prompt`, it stays active until released.

### Why this exists

Korean voice mode breaks in three ways: orthography misrecognition, failed Korean-to-English
code-switching (an English identifier spoken with Korean pronunciation comes back as Korean
syllables — "로더 파일"), and speech habits landing inside the command ("어쨌든", "그냥", "뭐").

Two of the three barely need a plugin. A model already ignores fillers and reads through
misspellings, so making that explicit buys consistency, not new capability. The third one is
different in kind: hearing "로더 파일", a model **guesses** a filename. It cannot know whether
`loader.py` exists without looking. That is not a comprehension failure, it is a missing action —
and a missing action is exactly what instructions can add.

So this plugin is not a text cleaner. It is a threshold changer. Everything it really
contributes is a decision rather than a transform:

| What it adds | Kind |
|---|---|
| Resolve identifiers against the repo instead of guessing | action added |
| Never rewrite numbers, dates, versions, PR/issue numbers | action forbidden |
| Echo one line of what was understood before acting | observability |
| Confirm before an irreversible action | gate |

### Shape

```text
plugins/docs-forge/
└── skills/voice-prompt/
    ├── SKILL.md                             # the body
    ├── references/stt-error-classes.md      # error taxonomy, live-command stance
    ├── references/korean-filler.md          # filler classes + function-residue test
    └── templates/speech-profile.md          # seeded to .claude/voice-prompt/speech-profile.md
```

### Boundary with plaud-note-taking

Both correct STT output, and the error distribution is the same, so the taxonomy is shared in
spirit. The discipline is not. `plaud-note-taking` treats its transcript as immutable evidence
and preserves every filler because the filler is part of the record; this skill treats its input
as a disposable command and deletes the filler because the filler is noise. Their term
dictionaries do not overlap either — one holds meeting attendees and company names, the other
holds one speaker's pronunciation habits.

Two plugins, not one skill with a mode flag: a body carrying both stances would need a
conditional on every rule.

### Known limit

This is instruction-following, not interception. Nothing sits between STT and the model — a
skill cannot rewrite the incoming message, and `UserPromptSubmit` hook output arrives as
appended `additionalContext` rather than a replacement. So the normalization happens in the
model's own reasoning and carries the same reliability as any other skill: it can fade in a long
session.

The echo line is the tell. If it stops appearing, the skill has drifted out — re-invoke
`/docs-forge:voice-prompt`. That self-signal is why the echo is mandatory rather than optional,
and why this plugin ships no marker file or re-injection hook to enforce stickiness.

The persisted profile has the same property: `.claude/voice-prompt/speech-profile.md` is an
ordinary project file, so nothing loads it for you. The activation step reads it explicitly —
without that read it would be a write-only dictionary, and every session would re-ask the same
misrecognition.
