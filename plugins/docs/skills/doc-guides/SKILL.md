---
name: doc-guides
description: "README/CHANGELOG/deploy-doc/MOC 저작 참조 카드 4종과 사람이 읽는 문서 공통 규칙(톤·TOC·그림·윤문) — 해당 command(/docs:readme 등)가 결정적으로 로드. Triggers: readme template, changelog format, 배포 문서/procedure doc, MOC 생성/wiki index/문서 한 줄 요약."
---

# Doc Guides

Four writing-reference cards for the `docs` document commands, one per output type, plus the common rule they all follow. Each `/docs:*` command loads `## Human-read documents` and the matching section below, so this skill is not read top to bottom. The full patterns live in `../../references/`.

## Human-read documents

The rule every document a person reads follows: README, deployment or procedure doc, CHANGELOG, MOC. Agent-facing documents (AGENTS.md, CLAUDE.md, skill bodies, `.claude/rules/`) keep their own tone.

- **Shape and tone**: read `../../references/writing-standard.md` before writing, and apply its `## Shape` and `## Tone by document kind` to every line the command writes. The user's global guidance §2 "Write so the point lands first" (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`) sets the attention rules; do not restate it here.
- **TOC**: a document with 4 or more `##` headings gets a linked table of contents right after the top summary (README: after the badges and Demo). CHANGELOG and MOC are exempt, since their headings are already the index.
- **Figures**: service connections, architecture and data flow get a structure diagram from the `stack-diagram` skill. A banner or concept picture goes through `codex-image` in the house style: soft 3D by default (clay-like rounded forms, soft studio light, one accent color), pixel style (hard-edged pixels, no anti-aliasing) only when the user asks.
- **Confirm before generating**: generation spends quota and writes files, so name each figure, its tool, style and output path, then ask with `AskUserQuestion` on Claude Code or `request_user_input` on Codex. With neither, or without the needed skill, generate nothing: write the document without the figure and list the proposed figures in the final report.
- **Final polish**: once the content is settled, run `Skill("humanize-korean:humanize-korean")` once over the prose of a Korean document. Code, commands, paths and numbers stay unchanged, and the writing standard wins where the two conflict.
- **Polish fallback**: without `humanize-korean`, self-check the prose against the "Sentence patterns to avoid" table in global §2 and say which path ran; an English document gets the same self-check. Without that table, check for translationese, throat-clearing openers, inflated or invented claims, and mechanical parallel lists.
- **Preserved wording**: a command that keeps existing text (`/docs:deploy-doc rewrite`) applies tone and polish only to the lines it writes itself.

## README

Patterns derived from awesome-readme examples, on top of `## Human-read documents`.

### Quick Reference

- **Open-source order**: header (logo, badges, tagline), quick start (3 steps max), features (benefits, not specs), installation, usage (progressive), configuration, API or props, contributing, license.
- **Internal repo order**: a repo that is not distributed (R&D, PoC, edge hardware, ML training) drops contributing, license and social-proof badges, and uses: top image, `# Name` and a one-line summary, 3-4 static badges, Demo or Results, current status (dated measured table and next step), quick start, structure, verification commands, risks, docs map (or MOC link), owner.
- **Top image**: a real UI or result screenshot when one exists, otherwise a banner. A banner is a text-free visual with the headline (one sentence, 8 words or fewer) typeset by script, 3:1 at about 2x display width, dark and light files via `<picture>`, and `alt` equal to the headline; the rules and sources are in `README_PATTERNS.md` `## Banner`.
- **Demo slot**: UI or demo material goes in `## Demo` (`## 데모` in a Korean README) directly under the badges; without a UI, a result image or a dated measured table takes the slot.
- **Badges**: pick 3-5 from build/CI, version, license, downloads, coverage. Static shields.io badges render without repo access; dynamic or Actions badges on a private repo are unverified.
- **CRO essentials**: what, who and why visible in 5 seconds, quick start under 5 minutes, a "You should see:" verification, a troubleshooting link nearby.
- **Templates**: `--type` cli, library, react-component, mcp-plugin, saas, desktop, internal, each in `../../references/TEMPLATES.md`.

Read further in `../../references/`: `README_PATTERNS.md` (full patterns, Internal Repo Structure, Banner, Demo and Screenshots Placement), `README_SECTIONS.md` (when each section applies and where it lands), `CRO_CHECKLIST.md` (conversion, Demo and Banner checks), `EXAMPLES_ANALYSIS.md` (analyzed examples, measured banners).

## CHANGELOG

Keep a Changelog and Conventional Commits, with entry tone and polish per `## Human-read documents`.

### Quick Reference

```markdown
# Changelog

## [Unreleased]

### Added
- New feature

## [1.0.0] - 2026-02-05

### Fixed
- Bug fix
```

| Category | When to Use |
|----------|-------------|
| Added | New features |
| Changed | Existing functionality changes |
| Deprecated | Features to be removed |
| Removed | Removed features |
| Fixed | Bug fixes |
| Security | Security patches |

Write for users, not developers: "Fixed crash on file upload", not "Fixed async race condition". Versioning, automation tools and anti-patterns are in `../../references/CHANGELOG_PATTERNS.md`.

## Deploy-doc

The cross-runtime source of truth for client-facing deployment and procedure documents. The `deploy-doc` command and any agent self-verify against the skeleton below before writing; tone, TOC, figures and polish follow `## Human-read documents`.

### Quick Reference

The skeleton is Korean by default, with English labels in parentheses for `--lang en`. Each item is a checklist entry to confirm before output:

1. **Title and top summary**: an optional `# H1` title (from `--title`) on the first line, then a 2-3 line summary paragraph above the first `##`. The summary has no heading of its own (no `## 요약`), and without a title it is the top of the file. It states what is deployed and the step count.
2. **Prerequisites**: a `## 전제조건` (`## Prerequisites`) section where every line is a `- [ ]` checklist item, with no bare prose bullets.
3. **Procedure**: a `## 절차` (`## Procedure`) section where every step is a `### N.` heading, numbered contiguously from `### 1.`, with no prose step outside a `### N.` heading.
4. **Number match**: the step count in the top summary equals the number of `### N.` headings. A mismatch is a FAIL.
5. **Link, don't redefine**: detailed contracts, schemas and source-of-truth specifics are linked (to `--links` documents), never inlined.

The empty skeleton, a filled example and the anti-patterns are in `../../references/DEPLOY_DOC_PATTERNS.md`.

## MOC

The cross-runtime source of truth for a Map of Content index over a docs folder. The `### Quick Reference` below binds the `moc` command and any agent; hook tone follows `## Human-read documents`.

### Quick Reference

- **Lightweight (default)**: one file, `<folder>/MOC.md`, with per-file bullets `- [title](relative/path.md) — hook` and per-domain `## <domain>` tables of `| File | Hook |` rows. Generic Markdown only: no frontmatter validation, no `[[id]]`, no typed cross-refs.
- **Strict (`--strict`)**: mirrors the wiki `index.md` convention with `## <domain>` groups (first-level subdirectories, `--depth` default 2, MOC first), bullets `- [title](domain/slug.md) — hook` or `[[id]]` when frontmatter has `id`, an intro paragraph and a typed-cross-ref legend (`> Refines:`, `> See-also:`). The frontmatter and staleness model stays with the `wiki` plugin.
- **Hook source (first hit wins)**: frontmatter `description:` or `summary:`, then the first non-empty paragraph after the first `# H1` (truncated near 100-120 characters), then the first `##` text, then the humanized filename with hook `(요약 없음)`.
- **Link text**: frontmatter `title:`, then the first `# H1`, then the filename.
- **Conflicts**: output is `<folder>/MOC.md` (or `--out`), and an existing `index.md` or `README.md` is never overwritten. Exclude them from the scan and the target; an `--out` whose basename matches `readme.md` or `index.md` case-insensitively is refused or routed to `MOC.md` after confirmation. An existing `MOC.md` is confirmed and updated in place.

Precedence examples and the wiki index mapping are in `../../references/MOC_PATTERNS.md`.
