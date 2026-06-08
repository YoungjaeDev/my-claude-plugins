---
name: moc-guide
description: Map of Content (MOC) generation spec — hook-sourcing precedence, lightweight generic vs strict wiki output, and conflict rules for indexing an arbitrary docs folder into a single MOC.md. Loaded by the docs-forge moc workflow.
---

# MOC Guide

The cross-runtime SSOT for generating a Map of Content index over an arbitrary docs folder. The `## Quick Reference` below is binding for the `moc` command and any agent.

## Triggers

- "MOC 생성"
- "generate MOC"
- "doc 목차"
- "wiki index"
- "문서 한 줄 요약"

## Quick Reference

### Lightweight (default)

- One file: `<folder>/MOC.md`. No per-file fan-out.
- Per-file bullets: `- [title](relative/path.md) — hook`.
- Per-domain table: `## <domain>` heading then `| File | Hook |` rows.
- No frontmatter validation, no `[[id]]`, no typed cross-refs — generic Markdown only.

### Strict (`--strict`)

Mirror the llm-wiki `index.md` convention:
- `## <domain>` group sections (domains = first-level subdirectories, `--depth` default 2, MOC-first ordering).
- Bullets `- [title](domain/slug.md) — hook`; when a file's frontmatter has `id`, prefer `[[id]]` link form.
- An MOC intro paragraph and a typed-cross-ref legend (`> Refines:` / `> See-also:` / etc.) as scaffolding.
- The full frontmatter / staleness model is NOT enforced here — real lore wiki is owned by the `llm-wiki` plugin. This is a generalized mirror, not a replacement.

### Hook source precedence (first hit wins)

1. frontmatter `description:` / `summary:`
2. first non-empty paragraph after the first `# H1` (truncate ~100-120 chars)
3. first `## ` subheading text
4. fallback: humanized filename + hook = `(요약 없음)` flag

Link text precedence: frontmatter `title:` -> first `# H1` -> filename.

### Conflict rules

- Output is `<folder>/MOC.md` (or `--out`). **Never** overwrite an existing `index.md` or `README.md` — exclude them from the scan AND from the output target: if `--out`'s basename case-insensitively matches `readme.md` / `index.md`, refuse or confirm-then-route to `MOC.md` instead of clobbering it (case-insensitive filesystems alias `INDEX.md` to `index.md`).
- If `MOC.md` already exists, confirm and update in place.

## References

- `../../references/MOC_PATTERNS.md` — precedence ladder, lightweight + strict output examples, llm-wiki index mapping.
