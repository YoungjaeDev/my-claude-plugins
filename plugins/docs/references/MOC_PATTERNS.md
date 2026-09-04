# MOC Patterns

The hook-sourcing ladder, lightweight/strict output examples, and wiki
`index.md` mapping for generating a Map of Content (MOC) over an arbitrary
folder. The `## MOC` section's `### Quick Reference` in the `doc-guides` skill
is the SSOT. Output examples below use the Korean-default form (hooks reflect
the Korean docs being indexed).

## Hook sourcing

The one-line hook for each file is decided by this precedence ladder (first hit wins):

1. frontmatter `description:` or `summary:`
2. the first non-empty paragraph after the first `# H1` (truncate to ~100-120 chars)
3. the first `##` subheading text
4. fallback: humanized filename + a `(요약 없음)` (no-summary) flag

Link text precedence: frontmatter `title:` → first `# H1` → filename. In strict mode, when a file's frontmatter carries an `id`, prefer the `[[id]]` link form.

## Lightweight output example

Output 1 (per-file hook bullets) and output 2 (per-domain table) go in the same `MOC.md` body.

```markdown
# docs MOC

## (root)

- [Overview](overview.md) — 프로젝트 전체 개요와 디렉토리 안내.

## deploy

- [Inference Deploy](deploy/inference.md) — 추론 서비스를 클라이언트 장비에 배포하는 절차.
- [Rollback](deploy/rollback.md) — (요약 없음)

| File | Hook |
|------|------|
| [Inference Deploy](deploy/inference.md) | 추론 서비스를 클라이언트 장비에 배포하는 절차. |
| [Rollback](deploy/rollback.md) | (요약 없음) |
```

## Strict (wiki) output example

```markdown
# docs Map of Content (MOC)

이 파일은 docs 폴더의 진입점이다. 각 페이지를 1줄 hook과 함께 나열하며,
도메인별로 그룹화한다. typed cross-ref 범례는 아래를 따른다.

> 범례: `> Refines:` 상세 추가 · `> See-also:` 관련 · `> Supersedes:` 대체

## deploy

- [Inference Deploy](deploy/inference.md) — 추론 서비스 배포 절차. [[inference-deploy]]
- [Rollback](deploy/rollback.md) — 배포 롤백 절차.
```

## wiki index.md mapping

Strict mode mirrors the convention in `plugins/wiki/skills/bootstrap-wiki/assets/templates/wiki-skeleton/index.md`:

- `## <domain>` group sections plus `- [page-title](<domain>/<slug>.md) — 1-line hook` bullets.
- 2-depth maximum, MOC-first entry rule.
- When frontmatter has an `id`, prefer `[[id]]`, with typed cross-refs (`> Refines:` / `> Contradicts:` / `> Evidence:` / `> See-also:` and so on).

The full frontmatter schema (`last_verified` / `status` / `volatility` / `sources`) and the staleness model, however, are **not enforced** — that model and the actual lore-wiki maintenance are delegated to the `wiki` plugin (`ingest-finding` / `lint-wiki`, etc.). The docs MOC is a generalized at-a-glance index over an arbitrary folder, not a lore system.
