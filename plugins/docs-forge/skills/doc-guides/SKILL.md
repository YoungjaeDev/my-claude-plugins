---
name: doc-guides
description: "README/CHANGELOG/deploy-doc/MOC 저작 참조 카드 4종 통합 — 해당 command(/docs-forge:readme 등)가 결정적으로 로드. Triggers: readme template, changelog format, 배포 문서/procedure doc, MOC 생성/wiki index/문서 한 줄 요약."
---

# Doc Guides

Four writing-reference cards for the `docs-forge` document commands, one per output type. Each
`/docs-forge:*` command loads the matching section below deterministically — this skill is not
meant to be browsed top to bottom.

## README

Patterns and best practices derived from awesome-readme examples.

### Triggers

- "how to write readme"
- "readme best practices"
- "readme template"
- "improve my readme"

### Quick Reference

#### Universal Structure

1. Header (Logo + Badges + Tagline)
2. Quick Start (3 steps max)
3. Features (Benefits, not specs)
4. Installation (Detailed)
5. Usage/Examples (Progressive complexity)
6. Configuration
7. API/Props
8. Contributing
9. License

#### Essential Badges (Pick 3-5)

| Badge | Purpose |
|-------|---------|
| Build/CI | Trust - "it works" |
| Version | Currency |
| License | Legal clarity |
| Downloads | Social proof |
| Coverage | Quality signal |

#### CRO Essentials

- 5-second test: What, Who, Why visible?
- Quick start under 5 minutes
- Visual demo for UI projects
- "You should see:" verification
- Troubleshooting link nearby

### References

For detailed patterns, see:
- `../../references/README_PATTERNS.md` - Full pattern documentation
- `../../references/TEMPLATES.md` - Copy-paste templates
- `../../references/CRO_CHECKLIST.md` - Conversion optimization
- `../../references/EXAMPLES_ANALYSIS.md` - Analyzed examples

### Templates Available

| Type | Use For |
|------|---------|
| CLI Tool | Command-line applications |
| Library | npm/pip packages |
| React Component | UI components |
| MCP Plugin | Claude Code plugins |
| SaaS | Web applications |
| Desktop | Electron/native apps |

## CHANGELOG

Writing patterns based on Keep a Changelog and Conventional Commits.

### Triggers

- "how to write changelog"
- "changelog format"
- "changelog template"
- "keep a changelog"

### Quick Reference

#### Standard Format

```markdown
# Changelog

## [Unreleased]

### Added
- New feature

### Fixed
- Bug fix

## [1.0.0] - 2026-02-05

### Added
- Initial release
```

#### Categories

| Category | When to Use |
|----------|-------------|
| Added | New features |
| Changed | Existing functionality changes |
| Deprecated | Features to be removed |
| Removed | Removed features |
| Fixed | Bug fixes |
| Security | Security patches |

#### Semantic Versioning

```
MAJOR.MINOR.PATCH

MAJOR: Breaking changes
MINOR: New features (backward compatible)
PATCH: Bug fixes (backward compatible)
```

#### Writing Style

Write for users, not developers:

| Bad | Good |
|-----|------|
| "Fixed async race condition" | "Fixed crash on file upload" |
| "Refactored auth module" | "Improved login speed by 50%" |
| "Updated deps" | "Improved security with latest libraries" |

### Automation Tools

| Tool | Best For |
|------|----------|
| semantic-release | Full CI/CD automation |
| release-please | GitHub PR-based review |
| git-cliff | Customizable generation |

### References

For detailed patterns, see:
- `../../references/CHANGELOG_PATTERNS.md` - Full format documentation

## Deploy-doc

The cross-runtime SSOT for client-facing deployment / procedure documents. The `### Quick
Reference` skeleton below is binding — the `deploy-doc` command and any agent must self-verify
against it before writing.

### Triggers

- "배포 문서"
- "deployment doc"
- "procedure doc"
- "절차 문서"
- "client procedure doc"

### Quick Reference

The skeleton (Korean default; English labels in parentheses for `--lang en`). Each item is a
self-verify checklist entry — confirm all before output:

1. **Title + top summary** — an optional `# H1` document title (from `--title`) on the first line,
   then a 2-3 line summary paragraph directly below it and above the first `##`. The summary is
   **untitled** in the sense that it carries no section heading of its own (no `## 요약`) — it is
   bare prose between the `# H1` and the first `##`. If no title is given, the summary paragraph
   is the very top of the file. The summary states what is deployed and the step count at a high
   level.
2. **Prerequisites** — a `## 전제조건` (`## Prerequisites`) section where **every** line is a
   `- [ ]` checklist item. No bare prose bullets.
3. **Procedure** — a `## 절차` (`## Procedure`) section where **every** step is a `### N.`
   heading, numbered contiguously from `### 1.` with no gaps and no `### N.`-less prose steps.
4. **Number-match rule** — the step count named or implied in the top summary MUST equal the
   number of `### N.` headings. Mismatch = FAIL.
5. **Link, don't redefine** — detailed contracts, schemas, and SSOT specifics are linked (to
   `--links` documents), never inlined. The procedure references the authority; it does not
   restate it.

Compliance check before writing: summary 2-3 lines? prerequisites all `- [ ]`? procedure all
contiguous `### N.`? summary count == `### N.` count? contracts linked not inlined?

### References

- `../../references/DEPLOY_DOC_PATTERNS.md` — empty skeleton, a filled example, and anti-patterns.

## MOC

The cross-runtime SSOT for generating a Map of Content index over an arbitrary docs folder. The
`### Quick Reference` below is binding for the `moc` command and any agent.

### Triggers

- "MOC 생성"
- "generate MOC"
- "doc 목차"
- "wiki index"
- "문서 한 줄 요약"

### Quick Reference

#### Lightweight (default)

- One file: `<folder>/MOC.md`. No per-file fan-out.
- Per-file bullets: `- [title](relative/path.md) — hook`.
- Per-domain table: `## <domain>` heading then `| File | Hook |` rows.
- No frontmatter validation, no `[[id]]`, no typed cross-refs — generic Markdown only.

#### Strict (`--strict`)

Mirror the llm-wiki `index.md` convention:
- `## <domain>` group sections (domains = first-level subdirectories, `--depth` default 2,
  MOC-first ordering).
- Bullets `- [title](domain/slug.md) — hook`; when a file's frontmatter has `id`, prefer `[[id]]`
  link form.
- An MOC intro paragraph and a typed-cross-ref legend (`> Refines:` / `> See-also:` / etc.) as
  scaffolding.
- The full frontmatter / staleness model is NOT enforced here — real lore wiki is owned by the
  `llm-wiki` plugin. This is a generalized mirror, not a replacement.

#### Hook source precedence (first hit wins)

1. frontmatter `description:` / `summary:`
2. first non-empty paragraph after the first `# H1` (truncate ~100-120 chars)
3. first `##` subheading text
4. fallback: humanized filename + hook = `(요약 없음)` flag

Link text precedence: frontmatter `title:` -> first `# H1` -> filename.

#### Conflict rules

- Output is `<folder>/MOC.md` (or `--out`). **Never** overwrite an existing `index.md` or
  `README.md` — exclude them from the scan AND from the output target: if `--out`'s basename
  case-insensitively matches `readme.md` / `index.md`, refuse or confirm-then-route to `MOC.md`
  instead of clobbering it (case-insensitive filesystems alias `INDEX.md` to `index.md`).
- If `MOC.md` already exists, confirm and update in place.

### References

- `../../references/MOC_PATTERNS.md` — precedence ladder, lightweight + strict output examples,
  llm-wiki index mapping.
