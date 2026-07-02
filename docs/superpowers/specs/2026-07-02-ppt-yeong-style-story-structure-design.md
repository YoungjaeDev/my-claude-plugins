# ppt-yeong-style 스토리 구조 설계 강화 설계

- 작성일: 2026-07-02
- 상태: draft (승인 대기)
- 관련 스킬: `plugins/ppt-yeong-style/skills/ppt-yeong-style/`
- 근거: 다른 repo(woogang-chatbot)에서 ppt-yeong-style + anti-slop-design으로 포트폴리오 덱을 만든 세션 전체를 리뷰, 설치된 `ppt-master` 플러그인(`~/.claude/plugins/marketplaces/ppt-master/skills/ppt-master/`) 파일트리로 직접 검증

## 1. 배경과 목적

woogang-chatbot 세션 리뷰에서 두 개의 구체적 버그가 나왔다: (a) 목차(TOC) 슬라이드가 나열한 순서와 실제 빌드된 페이지 순서가 달랐다, (b) 표지가 약속한 범위("검색·평가·배포까지")보다 실제 빌드 범위(배포 섹션 제외)가 좁았다. 두 버그 다 `ppt-master-and-qa.md` §8b "스토리 흐름 review"가 "through-line"·"개념 등장 순서"라는 이름으로 이미 다루고 있었고, 그 규칙은 `SKILL.md` 파이프라인 줄·§8b 본문·`injection-prompt.md` "[완료 기준]" 줄까지 최소 세 곳에 이미 명시돼 있었다. 그런데도 두 번의 빌드 시도(폐기된 것·수정된 것) 모두 사용자가 "스토리 흐름 어때?"라고 먼저 묻기 전까지 이 리뷰 자체가 실행되지 않았다.

별개로, ppt-master의 실제 `references/modes/_index.md` §2 auto-selection표를 직접 읽어 확인한 결과 "Strategic decision / analysis / board / investor → `pyramid`" 신호가 있고, `pyramid` 모드에는 SCQA(Situation-Complication-Question-Answer) 오프닝 스켈레톤이 내장돼 있다(`modes/pyramid.md`로 직접 확인). woogang 콘텐츠("4개 검색 전략 비교 후 1개 확정")는 정확히 이 신호에 해당하는데, `ppt-master-craft.md`의 mode 레버 행은 지금 "제안 덱 → narrative/pyramid 중 인터뷰 판단"이라고만 돼 있어 이 구체적 트리거를 주지 않는다. `pyramid`를 제대로 골랐다면 페이지 순서가 SCQA 스켈레톤을 따라 애초에 안정됐을 것이고, 목차 불일치 버그 자체가 덜 생겼을 것이다.

목표: 문제를 사후(빌드 후 §8b 리뷰)에만 잡는 구조에서, **원인 단계(mode 선택·목차 작성 시점)에서 줄이고 + 사후 안전망(§8b)을 스킵 못 하게 강제**하는 쪽으로 옮긴다.

## 2. 검토한 대안과 선택

### 2.1 mode 트리거 (craft.md)

| 접근 | 내용 | 채택/기각 사유 |
|---|---|---|
| **A. 기존 mode 레버 행에 트리거 한 줄 추가 (채택)** | "비교→확정 구조면 pyramid 우선(SCQA·MECE 내장)"을 기존 표 셀에 추가 | PR #87이 같은 표에 mode/visual_style 행을 추가한 방식과 결이 같음. 새 섹션 없이 최소 변경 |
| B. 별도 "mode 선택 콘텐츠 신호" 소제목 신설 | ppt-master의 auto-selection표 구조를 통째로 미러링 | 테이블 하나 더 늘어나는 유지보수 비용 대비 이득 작음 — 기각 |

### 2.2 §8b 스토리 흐름 review (qa.md + SKILL.md)

| 접근 | 내용 | 채택/기각 사유 |
|---|---|---|
| A. 기존 리스트에 항목 2개 추가만 | "목차-실순서 일치"·"표지약속-범위 일치"를 이름 붙은 불릿으로 추가 | 리스트 항목을 늘리는 것만으론 "규칙은 있었는데 조용히 스킵됐다"는 이번 조사의 핵심 실패 패턴을 못 고침 — 단독으론 기각 |
| **B. 원인(TOC 최종 작성 시점) + 안전망(체크리스트 실제 출력 강제) 병행 (채택)** | §2에 "TOC는 페이지 순서 확정 후 마지막에 작성" 규칙 추가 + §8b를 "빌드 완료 보고 전 항목별 ✓/✗를 실제로 출력해야 하는" 형식으로 재구성(그 안에 목차·표지범위 항목을 이름 붙여 포함) | 재발한 두 버그 각각에 원인 쪽(순서 확정 후 TOC)과 안전망 쪽(출력 강제로 스킵 방지)을 하나씩 배치 — A보다 실제 스킵 방지 효과가 크다고 판단 |

## 3. 변경 파일 및 내용

### 3.1 `references/ppt-master-craft.md` (mode 레버 행)

기존 "제안 덱 → `narrative`/`pyramid` 중 인터뷰에서 판단" 뒤에 괄호로 트리거 추가:

> (콘텐츠가 **여러 옵션을 비교해 1개로 확정**하는 구조면 `pyramid` 우선 — SCQA 오프닝[Situation→Complication→Question→Answer]과 MECE 비교가 내장돼 있어 페이지 순서·비교 논리가 저절로 안정된다. ppt-master 자체 auto-selection표의 "Strategic decision/analysis/board/investor → pyramid"와 일치. 스토리가 서사 아치[기승전결]로 가는 제안이면 여전히 `narrative`.)

### 3.2 `SKILL.md` §2 md 소스 작성 규약 (TOC 작성 시점)

목차 슬라이드 작성 규칙 한 줄 추가: 목차(TOC)는 다른 슬라이드와 같이 초안 단계에서 쓰지 않는다 — **전체 페이지 순서가 spec_lock에 확정된 뒤 마지막에** 그 순서를 그대로 옮겨 적는다. 순서가 나중에 바뀌면 목차도 같이 갱신(재확인 없이 방치 금지).

### 3.3 `references/ppt-master-and-qa.md` §8b (체크리스트 출력 강제)

§8b 본문을 아래 취지로 재구성:

- 기존 6개 체크(through-line·surface 일관·용어 일관·개념 등장 순서·고아 슬라이드·사실 정확)는 유지하되, 두 항목을 이름 붙여 분리: **"목차-실제 순서 일치"**(개념 등장 순서에서 분리) / **"표지 약속 범위-실제 빌드 범위 일치"**(through-line에서 분리) — 재발한 두 버그가 각각 이 이름으로 걸리게.
- 새 규칙: **빌드 완료를 사용자에게 보고하기 전, 위 항목을 실제로 하나씩 ✓/✗로 출력한다**(내부적으로 판단만 하고 넘어가는 것 금지). ✗가 하나라도 있으면 완료 보고 대신 해당 장 수정부터.
- SKILL.md §1 파이프라인 줄의 "스토리 흐름 review" 문구도 "스토리 흐름 review(체크리스트 출력)"로 짧게 갱신해 이 강제가 파이프라인 개요에서부터 보이게 한다.

## 4. 이번 라운드에서 제외 (다음 라운드 후보)

- **엔진 우회(스크립트로 SVG 직접 생성) 방지용 PreToolUse 훅** — 별도 브레인스토밍으로 진행하기로 확정(이 설계와 독립적인 메커니즘이라 별도 스펙).
- **`injection-prompt.md`의 PR #87 동기화 누락** — 이번 조사에서 발견됐지만 이번 설계(스토리 구조)와는 무관한 별개의 lever-alignment 콘텐츠 동기화 문제. 별도 소규모 후속으로 남긴다.
- SCQA를 `pyramid` 외 다른 mode에도 부분 적용하는 것 — 현재 근거(ppt-master 자체 문서)가 `pyramid` 모드에만 SCQA를 명시하므로 확장하지 않는다.

## 5. 검증 방법

문서(스킬 md) 변경이라 자동 테스트는 없다. 대신:
1. 각 파일 수정 후 `python3 -c "import yaml; yaml.safe_load(...)"` 류로 SKILL.md frontmatter 파싱 이상 없는지 확인.
2. §8b 새 체크리스트 형식이 기존 §8(Visual QA, 렌더 기반 완료 기준)과 형식·용어가 충돌하지 않는지 대조.
3. `node scripts/sync-codex-manifests.mjs --check` / `sync-hermes-manifests.mjs --check` 통과 확인(설명 변경 없어 영향 없을 것으로 예상, 회귀 확인 차원).
4. 실사용 검증: 다음에 "여러 옵션 비교 후 확정" 구조의 덱을 만들 때 mode 트리거가 실제로 pyramid 선택을 유도하는지, §8b 체크리스트가 실제로 출력되는지로 확인 — 사용 시점 검증이라 이번 PR에서 자동 확인은 안 됨.

## 6. 다음 단계

승인되면 `superpowers:writing-plans`로 넘어가 구현 계획을 만든다. 현재 `main`이 clean 상태라(동시 작업 브랜치 없음) PR #87 때와 달리 worktree 격리 없이 바로 새 브랜치에서 진행 가능.
