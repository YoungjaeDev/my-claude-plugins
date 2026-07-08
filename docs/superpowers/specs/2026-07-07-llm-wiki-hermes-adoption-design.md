---
status: in-progress
---

# llm-wiki 2.4.0 — Hermes llm-wiki 스킬 채택분 반영 (A: 위생 3종 + B: ingest 규율 2.5종)

- 작성일: 2026-07-07
- 상태: approved (plan-mode 미러 승인, 세션 6211e08a)
- 관련: `plugins/llm-wiki/` 2.3.1 → 2.4.0, NousResearch hermes-agent `skills/research/llm-wiki/SKILL.md` (비교 대상)
- 미채택 근거 기록처: post-merge wiki ingest에서 `curated-conservative` 페이지에 통합 예정

## Context

NousResearch hermes-agent의 `skills/research/llm-wiki/SKILL.md`를 검토한 결과, 대부분은
우리 설계 기록(`llm-wiki-design/curated-conservative` 등)에서 이미 기각된 아이디어의 재등장
(confidence 밴드, raw wikilink, archive-move, type 디렉토리)이거나 PKM 전용 장치였다.
그러나 우리 플러그인에 실제로 뚫려 있는 구멍을 메우는 항목이 있어 채택한다:

- **log.md 무한 append** — 페이지는 5KB 초과 시 분할하면서 로그만 무한 성장. 로테이션 규칙 부재.
- **raw/ 불변성 미검증** — "raw는 불변" 원칙은 있으나 검증 수단이 없음. sha256이면 재ingest 드리프트도 감지.
- **참조 고립 페이지** — orphan 스캔은 index 누락만 잡고, typed ref 0개인 페이지(그래프 고립)는 못 잡음.
- **bulk ingest 규율 부재** — staging drain에 마커가 2+개 쌓이는 구조인데 배칭 지침이 없음.
- **대량 수정 상한 부재** — autonomy boundaries에 "한 ingest가 10+ 페이지를 건드리면 확인" 게이트 없음.

사용자 확정 범위: A(위생 3종) + B(ingest 규율 2.5종). C(query 회수 규칙)는 미채택.
type 디렉토리(entities/concepts/…)는 질의 후 기각 합의.

## 변경 파일

### 1. `plugins/llm-wiki/references/wiki-conventions.md` (agent-facing SSOT)

- **`## raw/ frontmatter` 섹션 신설** (Frontmatter schema 아래):
  ```yaml
  ---
  source_url: https://...        # 원본 URL (해당 시)
  ingested: YYYY-MM-DD
  sha256: <hex>                  # frontmatter 아래 body만의 해시
  ---
  ```
  - 신규 raw 캡처 시 부여. 같은 URL 재ingest 시: body 해시 재계산 → 동일하면 skip, 다르면
    드리프트 플래그 + 신규 스냅샷 (기존 raw 파일은 수정하지 않음 — 불변).
  - **prospective-only**: 기존 raw 파일 backfill은 하지 않는다(raw 수정 금지 원칙). sha256 없는
    파일은 드리프트 검사에서 skip.
- **`## raw/ layout` 섹션 신설** (raw frontmatter 위에, 세션 중 추가된 범위): raw를 평평하게
  덤프하지 않고 **출처(source-type) 축**으로 하위 버킷을 둔다. wiki의 도메인 subdir·insight의
  flat과 달리 raw는 출처가 이질적(제3자 문서 / 우리 리서치 / 대화·녹취 / 감사)이라 이 축이 실제로
  갈린다.
  ```
  raw/
  ├── external/      # 제3자 원본 (gist, paper, vendor doc, 웹 아티클)
  ├── research/      # 우리 생성 리서치 (deep-research, code-scout, survey)
  ├── transcripts/   # 대화·녹취 (카카오톡 대화 export, 녹음/미팅 전사)
  └── audits/        # 디버그·감사 캡처 (audit md, 세션 디버그 노트)
  ```
  - **파일명**: `YYYY-MM-DD-<slug>.<ext>` (날짜 = 캡처/ingested 일자, frontmatter `ingested:` 와 동기).
    ingest-finding worked example(`2026-05-29-provider-x-debug.md`) + `.staging` 마커 네이밍과 일치.
  - **불변성 = 내용 불변, 경로 고정 아님**: 기존 raw 파일을 `git mv`로 버킷에 옮기고 rename해도
    바이트가 그대로라 body sha256 불변 → 드리프트 검사와 무충돌. 이동은 위키 편집(Evidence ref 갱신),
    파일 수정이 아니다. 기존 4파일은 frontmatter 없이 이동만 (prospective-only 유지).
- **이 repo의 실제 raw 이동**: karpathy·rohitg00 gist → `external/2026-05-29-*`, perplexity md·pdf →
  `research/2026-05-29-perplexity-llm-wiki-survey.*`. `transcripts/`·`audits/`는 `.gitkeep`로 빈 버킷.
  Evidence ref 갱신 대상: `volatility-over-decay` / `provenance-over-confidence` /
  `curated-conservative` / `neutral-llmwiki-root` (~7 Evidence 라인 + 본문 언급). bootstrap
  wiki-skeleton 템플릿에도 4버킷을 반영.
- **wiki·insight는 안 건드림**: wiki는 이미 도메인 subdir 보유, insight는 균질·상한 설계라 flat 유지
  (커지면 index.md 헤딩 그룹핑 — 물리 폴더 아님). 세 층이 성격상 다른 구조를 갖는 게 정상.
- **`## log.md discipline`에 로테이션 규칙 추가**: 해가 바뀐 뒤 첫 wiki 이벤트 시 전년도
  엔트리를 같은 루트의 `log-YYYY.md`로 이관(newest-first 유지). 시계열 복구는
  `grep '## ' log*.md`. (Hermes의 500-엔트리 임계 대신 연도 기준 — 우리 헤더가 날짜형이라
  결정론적이고 grep-friendly.)

### 2. `plugins/llm-wiki/skills/lint-wiki/SKILL.md`

Steps 11–13 추가 (기존 1–10 뒤, 모두 report-only):

- **11. Source-drift scan**: `.llmwiki/raw/`에서 `sha256:` frontmatter 보유 파일의 body 해시
  재계산 → 불일치 리포트 (raw 수정됨 or 원본 URL 변경). frontmatter 없는 파일은 skip.
  - bash 스니펫은 기존 shell-portability 규칙 준수: `LC_ALL=C.UTF-8` + GNU/BSD 폴백
    (`sha256sum || shasum -a 256`), frontmatter 스트립은 awk.
- **12. Link-poverty scan**: typed cross-ref 라인(`^> \w+(-\w+)*:`)이 0개인 wiki 페이지 플래그
  (index/log 제외). report-only — 도메인 첫 페이지 등 정당한 단독 페이지가 있을 수 있음.
- **13. Log-rotation due**: `log.md`에 전년도(이전 연도) 엔트리가 있으면 `log-YYYY.md` 로테이션 제안.

Output format 블록 + worked example에 세 줄 추가 (`- Source drift:` / `- Link poverty:` / `- Log rotation:`).

### 3. `plugins/llm-wiki/skills/ingest-finding/SKILL.md`

- **dedup 게이트에 생성 임계 1줄**: 신규 페이지는 "독립 근거 2+개에서 등장하거나, 현재
  결정/수정의 load-bearing 개념일 때만". (Hermes Page Thresholds의 lore 적응판.)
- **`### Bulk ingest` 소절 신설** (Core patterns 내): 소스/스테이징 마커 N개 동시 처리 시 —
  전부 먼저 읽기 → dedup 패스 1회 → 페이지 편집 배치 → index 1회 갱신 → **log 엔트리 1개**로
  배치 전체 커버.
- **autonomy boundaries 표에 1행**: "단일 ingest가 10+ 페이지 수정 | ❌ | ✅ 범위 확인 후 진행".
- **Steps 1(소스 캡처)에 1줄**: 신규 raw 저장 시 conventions의 raw frontmatter 부여.

### 4. `plugins/llm-wiki/CLAUDE.md` (human-facing 미러 — dual-home 패턴)

- Frontmatter 섹션에 raw/ frontmatter 요약, Event log 섹션에 로테이션 규칙 1줄.
- conventions ↔ CLAUDE.md 미러 동기화 필수 (skill-engine-layering의 mirror fan-out 교훈).

### 5. 버전/매니페스트 동기 (`.claude/rules/plugin-versioning.md` 계약)

- `plugins/llm-wiki/.claude-plugin/plugin.json` version 2.3.1 → 2.4.0 (MINOR, 소스에서 확인 완료).
- `.claude-plugin/marketplace.json` 동일 bump + `metadata.version` MINOR bump
  (머지 직전 origin/main 재확인 — concurrent-branch 규칙).
- `node scripts/sync-codex-manifests.mjs` + `sync-hermes-manifests.mjs` 재실행
  (llm-wiki는 HERMES_ELIGIBLE 아님 — Codex 매니페스트만 실변경) + 양쪽 `--check` 통과.
- 플러그인 수/스킬 수 불변 → 루트 CLAUDE.md/README 카운트 변경 없음. marketplace description은
  변경 없으면 그대로 (1024자 규칙 영향 없음).

## 워크플로 (github-dev 표준 체인 — 사용자 지정)

0. **main 정리 확인**: 현재 main에 post-merge #97 산출물 + 이번 세션 wiki drain 편집이
   uncommitted로 남아 있음 (`dual-integration.md`, `AGENTS.md`, `.llmwiki/wiki/*` 5파일,
   spec status flip). 구현 시작 시 git status 재확인 후 docs 커밋으로 정리하고 브랜치 —
   PR diff를 surgical하게 유지. (다른 세션이 post-merge 진행 중이면 완료 대기.)
1. **spec 확정**: 합의된 이 plan 본문을 `docs/superpowers/specs/2026-07-07-llm-wiki-hermes-adoption-design.md`로
   확정 + 커밋.
2. `github-dev:decompose-issue` — 단일 모듈이므로 같은-모듈 묶음 규칙에 따라 이슈 1개
   (또는 conventions/lint/ingest 축으로 나뉘어도 단일 PR로 묶음).
3. `github-dev:resolve-issue` (cr-fix loop on) → 단일 PR.
4. 사용자 머지 → `github-dev:post-merge` — 이 단계의 wiki ingest에서 Hermes 비교의
   채택/기각 근거를 `curated-conservative` 페이지에 통합 (새 페이지 아님 — consolidate).

## Verification

- 신규 lint bash 스니펫 3개를 이 repo의 실제 `.llmwiki/` 트리에 직접 실행:
  - source-drift: 기존 raw 파일(sha256 없음) → 전부 skip되는지 (빈 리포트).
  - link-poverty: 실제 위키 페이지 대상 스캔 → 플래그 출력 형식 확인 (hit 존재 예상).
  - log-rotation: 2026 단일 연도라 미해당 → 침묵 확인. 전년도 엔트리 mock으로 양성 케이스도 1회.
- raw frontmatter 해시 규칙 self-check: 샘플 파일 만들어 body 해시 재계산 일치 확인 (scratchpad).
- raw 재구조화 검증: `git mv` 후 4파일 body sha256이 이동 전과 동일(내용 불변) 확인, 갱신된 Evidence
  ref가 새 경로로 resolve되는지(broken ref 0), source-drift 스니펫이 subdir 재귀 스캔하는지.
- `node scripts/sync-codex-manifests.mjs --check` + `node scripts/sync-hermes-manifests.mjs --check` 통과.
- 버전 3파일(plugin.json / marketplace entry / metadata.version) grep으로 일치 확인.
- 전체 `lint-wiki` 수동 1회 실행해 신규 Output format이 실제 리포트에 렌더되는지 확인.

## Non-goals

- C그룹(query 답변 회수 규칙) — 미채택.
- 기존 raw 파일 sha256 backfill — raw 불변 원칙 우선, prospective-only.
- type 디렉토리(entities/concepts/comparisons/queries), tags taxonomy, confidence 밴드,
  archive-move, Obsidian 연동 — 기각 (근거는 post-merge에서 위키에 기록).
- 훅 변경 없음 (5개 훅 그대로).
