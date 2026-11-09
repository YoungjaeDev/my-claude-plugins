# Writing standard

The one shape and tone standard for every markdown file in this plugin marketplace and for the documents the docs skills generate. A SKILL.md stays at or under 10KB (target 5KB), a paragraph at or under 600 bytes and 3 sentences, and headings stop at H3 (1KB here is 1000 bytes, the `wc -c` convention).

`docs:skill-forge`, `docs:doc-guides` and `docs:md-audit` point here. The exception list at the bottom is the only copy, and the md-audit script reads it.

## Measure

Run the bundled script from the repository root. It counts; the model judges what the numbers single out.

```bash
node plugins/docs/skills/md-audit/scripts/measure-skills.mjs --md <path>...   # files or directories
node plugins/docs/skills/md-audit/scripts/measure-skills.mjs --md              # .md changed vs the merge-base with origin/main (--base <ref> to change it)
node plugins/docs/skills/md-audit/scripts/measure-skills.mjs --md --all        # every tracked .md
```

- **Pass**: the last line is `md-audit: ok` and the exit status is 0. Exit 1 means at least one `fail` finding, exit 2 means part of the scope could not be read, so the run proves nothing about it.
- **fail** rules: `size` (SKILL.md over 10000 bytes, frontmatter included), `para` (a paragraph over 600 bytes), `h4` (an H4 or deeper heading), `short` (a section with fewer than 3 body lines).
- **warn** rules, reported and judged: `size` (SKILL.md over 5000 bytes), `sentences` (a paragraph over 3 sentences), `bold` (bold outside a list lead beyond the 1 the file may use).

## Shape

These apply to every markdown file, for people and for agents alike.

- **Paragraph**: at most 3 sentences and 600 bytes (UTF-8, so about 200 Korean characters). Each list item and each footnote counts as its own paragraph, continuation lines included. Table rows, fenced code, frontmatter and HTML comments are exempt.
- **Heading**: one heading per thing the reader does. A section needs at least 3 non-blank body lines, counted up to the next heading of the same or higher level, so a container counts its children; merge a shorter one into the section above. H1 is exempt, and H4 or deeper is not used.
- **Bold**: only as a list lead (`**Name**: description`) plus one warning per document.
- **Voice**: the first paragraph says what the thing is and gives a number. Limits and todos stay visible. No flourish and no first person.
- **Evidence**: a number or a claim carries its source file or issue as a footnote (`[^n]`). A required reason that would interrupt the text goes into the same kind of footnote.

## Tone by document kind

- **Skill bodies and plugin `CLAUDE.md`**: English. Domain content, user-facing copy and the Korean trigger phrases in a `description` keep their source language.
- **Korean agent documents** (`AGENTS.md`, deck rule templates, aside runtime docs): 한다체.
- **Korean user documents**: list items and table cells end in a noun (`~지원`, `~기록`) or in 개조식 `~음` / `~함`, never in 한다체 `~다`. 합니다체 is for a sentence that asks the reader to act (`실행하세요`) and for a complete summary or notice sentence.
- **English user documents**: short noun phrases in lists, the imperative for actions.
- **README top**: a real UI or result screenshot when one exists, otherwise a banner. An internal repo is recommended to carry current status, next step, verification and owner sections.

## Skill shape

- **SKILL.md**: the goal, the core model, the output shape, the bright lines and the done condition. Every bright line stays in SKILL.md.
- **Procedure**: step prose goes to `references/procedure.md`, keyed by the existing step numbers, and SKILL.md says to read it before the first step. Code stays in `references/run-blocks.md` or `scripts/`.
- **Two runtimes**: one inline sentence per skill that asks the user: "Ask with `AskUserQuestion` on Claude Code or `request_user_input` on Codex; when neither is available, proceed with the safe default and say so." Where proceeding is unsafe, end it with "stop and report" instead. A Claude-only skill names only `AskUserQuestion`.
- **Resolver**: a skill that calls a bundled script keeps its `PLUGIN_ROOT` resolver block.

## Editing

- **No appending**: put a new point into the sentence that already covers it, or replace that sentence. When a section goes over its budget, shorten something else or move detail to `references/`. This holds for `CLAUDE.md.global` §2 too.
- **Delete**: incident history ("PR #334에서…"), reviewer rebuttals, rationale that an ADR or git already records, orphan references, and copied vendor docs (point at the live source instead).
- **Pointers**: a shipped file drops a pointer installed users cannot follow (`docs/adr/…`, an `AGENTS.md` section, `.claude/rules/…`), or inlines it as one line or a footnote. Plugin-relative paths stay. A file a script cites is not merged away.
- **Frozen names**: machine-read strings, cited headings and step numbers stay as they are. Renaming one means updating every caller found by grep in the same commit.
- **Generated documents**: `/docs:readme`, `/docs:deploy-doc`, `/docs:moc` and `docs:write-rules` apply this whole standard to what they write into a user's repository. A command that preserves existing wording (`/docs:deploy-doc rewrite`) applies it only to the lines it writes itself.

## Exceptions

The files below are skipped. A glob is relative to the repository root (`**` crosses directories, `*` stays in one), `#` starts a comment, and `path#Heading` skips one section of a file.

```text
# Records and history
docs/adr/**
docs/audit/**
docs/prd/**
docs/superpowers/**
.claude/spec/**
**/CHANGELOG.md
# Matt-generated or Matt-format, read by heading name
docs/agents/**
GLOSSARY.md
AGENTS.md#Agent skills
# Runtime files copied into ~/aside-ops
plugins/aside/runtime/**
# Seeded templates and code-heavy references
plugins/aside/skills/browser-ops/templates/**
plugins/deck/templates/brands/**
plugins/deck/templates/decks/*/outline.md
plugins/deck/templates/decks/*/vendor/**
plugins/dev/assets/**
plugins/docs/skills/write-rules/assets/**
plugins/ml/skills/cv-notebook/references/templates/**
plugins/ml/skills/cv-notebook/references/diagrams.md
plugins/wiki/skills/plaud-note-taking/references/terminology.md
plugins/wiki/skills/plaud-note-taking/templates/**
# Stamped rule copies in a user's deck repository (deck-sync owns them)
.claude/rules/deck-*.md
.claude/rules/korean-style.md
```
