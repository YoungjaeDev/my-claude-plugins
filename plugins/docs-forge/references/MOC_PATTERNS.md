# MOC 패턴

임의 폴더용 Map of Content(MOC) 생성의 hook 소싱 사다리, 경량/strict 출력 예시, llm-wiki `index.md` 매핑. `moc-guide` 스킬의 `## Quick Reference`가 SSOT다.

## Hook 소싱

파일별 1줄 hook은 아래 precedence ladder로 결정한다(첫 히트 채택):

1. frontmatter `description:` 또는 `summary:`
2. 첫 `# H1` 다음 첫 비어있지 않은 단락 (~100-120자 절단)
3. 첫 `##` 소제목 텍스트
4. 최후: 휴머나이즈한 파일명 + hook = `(요약 없음)` 플래그

링크 텍스트는 frontmatter `title:` → 첫 `# H1` → 파일명 순. strict 모드에서 frontmatter `id`가 있으면 `[[id]]` 링크 형태 선호.

## 경량 출력 예시

출력1(파일별 hook 불릿)과 출력2(도메인별 테이블)를 같은 `MOC.md` 본문에 둔다.

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

## strict(wiki) 출력 예시

```markdown
# docs Map of Content (MOC)

이 파일은 docs 폴더의 진입점이다. 각 페이지를 1줄 hook과 함께 나열하며,
도메인별로 그룹화한다. typed cross-ref 범례는 아래를 따른다.

> 범례: `> Refines:` 상세 추가 · `> See-also:` 관련 · `> Supersedes:` 대체

## deploy

- [Inference Deploy](deploy/inference.md) — 추론 서비스 배포 절차. [[inference-deploy]]
- [Rollback](deploy/rollback.md) — 배포 롤백 절차.
```

## llm-wiki index.md 매핑

strict 모드는 `plugins/llm-wiki/skills/bootstrap-wiki/assets/templates/wiki-skeleton/index.md`의 컨벤션을 미러한다:

- `## <domain>` 그룹 + `- [page-title](<domain>/<slug>.md) — 1-line hook` 불릿
- 2-depth 최대, MOC-first 진입 규칙
- frontmatter `id` 있으면 `[[id]]` 선호, typed cross-ref(`> Refines:` / `> Contradicts:` / `> Evidence:` / `> See-also:` 등)

단, frontmatter 전체 스키마(`last_verified` / `status` / `volatility` / `sources`)와 staleness 모델은 **강제하지 않는다** — 그 모델과 실제 lore wiki 유지보수는 `llm-wiki` 플러그인(`ingest-finding` / `lint-wiki` 등)에 위임한다. docs-forge MOC는 임의 폴더를 한눈에 보는 일반화된 인덱스이지 lore 시스템이 아니다.
