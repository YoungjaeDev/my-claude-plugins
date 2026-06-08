---
name: moc
description: Generate a Map of Content (MOC) index for an arbitrary docs folder — one-line hook per file plus per-domain tables, lightweight by default with an optional strict wiki style
argument-hint: "[folder] [--strict] [--out FILE]"
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Skill
---

# MOC Command

Generate a Map of Content (MOC) index for a docs folder: a one-line hook per file plus per-domain tables. Lightweight generic mode by default; `--strict` switches to the llm-wiki-style index. The hook-sourcing and conflict rules live in the `moc-guide` skill (cross-runtime SSOT); this command orchestrates the scan and write.

## Arguments

- `folder` - Scan root. Default `docs/`.

## Options

- `--strict` - Wiki style (domain groups, `[[id]]`, typed cross-ref scaffolding). Default OFF (lightweight).
- `--out FILE` - Output path. Default `<folder>/MOC.md`.
- `--depth N` - Domain-group depth. Default `2`.
- `--lang ko|en` - Output language. Default `ko`.

## Instructions

1. Load the `moc-guide` Skill — its `## Quick Reference` is the binding output spec (hook precedence, lightweight vs strict, conflict rules).
2. `Glob folder/**/*.md`. **Exclude** the output file itself and any existing `index.md` / `README.md` in scope (conflict guard — never overwrite those).
3. Detect domains: each first-level subdirectory of `folder` is a domain (`##` group); root-level files go under `## (root)`. Respect `--depth`. Only when the folder is flat (no subdirectories) AND `--strict` is set, ask the user how to group.
4. Compute a one-line hook per file using the precedence ladder (first hit wins):
   1. frontmatter `description:` / `summary:`
   2. first non-empty paragraph after the first `# H1` (truncate ~100-120 chars)
   3. first `## ` subheading text
   4. fallback: humanized filename + hook = `(요약 없음)` flag
   Link text = frontmatter `title:` -> first `# H1` -> filename. In strict mode, prefer `[[id]]` when frontmatter `id` exists.
5. Build Output 1 (per-file hook bullets) and Output 2 (per-domain MOC table) into the single output file. Do not fan out per-file hook files.
6. If `--strict`: validate frontmatter, mirror the llm-wiki `index.md` bullet style, and add typed cross-ref scaffolding. If lightweight: omit all wiki machinery (no frontmatter checks, no `[[id]]`, no typed cross-refs).

## Output Format

Write to `--out` (default `<folder>/MOC.md`). Both outputs go in that one file.

### Output 1 — per-file hook bullets (lightweight)

```markdown
- [Inference Deploy](deploy/inference.md) — 추론 서비스를 클라이언트 장비에 배포하는 절차.
- [Rollback](deploy/rollback.md) — (요약 없음)
```

### Output 2 — per-domain MOC table (lightweight)

```markdown
## deploy

| File | Hook |
|------|------|
| [Inference Deploy](deploy/inference.md) | 추론 서비스를 클라이언트 장비에 배포하는 절차. |
| [Rollback](deploy/rollback.md) | (요약 없음) |
```

### Strict mode

Replace Output 2 with the llm-wiki bullet style (`- [title](domain/slug.md) — hook`), an MOC intro paragraph, and a typed-cross-ref legend. See `moc-guide` and `references/MOC_PATTERNS.md`.

Report what was written: output path, file count, domains detected, and how many files fell back to `(요약 없음)`.
