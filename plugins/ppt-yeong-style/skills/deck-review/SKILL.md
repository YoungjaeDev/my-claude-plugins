---
name: deck-review
description: yeong 스타일 덱 리뷰 파이프라인 오케스트레이션 — 빌드된(또는 md 확정 단계의) 덱을 관점별 리뷰 서브에이전트 4종(audience-fit·story-flow·fact-check·design-qa)에 병렬 dispatch하고, codex:rescue가 설치돼 있으면 교차 리뷰 1회를 추가한 뒤, 리포트를 종합해 장별 수정 티켓으로 정리한다. 트리거 — "덱 리뷰해줘", "완성 덱 검수", "페르소나 검증 돌려줘", "deck review", ppt-yeong-style 파이프라인 (6)~(7) 사이의 감사 단계를 다인 관점으로 돌리고 싶을 때. 단일 관점 감사(디자인만·윤문만)는 anti-slop-design·humanize-korean을 직접 쓰는 게 가볍다.
---

# deck-review — 리뷰 파이프라인 오케스트레이션

ppt-yeong-style 파이프라인의 감사 단계((6) anti-slop 감사·윤문, §8b 스토리 흐름 review)를 **관점별 서브에이전트 병렬 리뷰**로 확장한 것. 메인 세션은 dispatch와 종합만 하고, 통독·검증은 각 리뷰어가 자기 컨텍스트에서 수행한다.

## 언제 쓰나 / 안 쓰나

- **쓴다**: 덱 빌드 완주 후 완료 게이트 전 최종 검수. md 소스 확정 직전의 사전 리뷰(이때는 design-qa 생략). 큰 개정 라운드(다수 장 수정) 후 회귀 검수.
- **안 쓴다**: 한두 장 수정의 국소 확인(그 장 렌더만 보면 됨). 디자인 단독 감사(→ anti-slop-design), 한국어 윤문(→ humanize-korean).

## 입력 확정 (dispatch 전에)

| 항목 | 소스 |
|---|---|
| `deck_source` | 프로젝트의 `sources/deck.md` (내용 SOT) |
| `spec_lock` | 프로젝트의 `spec_lock.md` |
| `render_dir` | 렌더 PNG 디렉터리(없으면 Playwright로 먼저 렌더 — svg_output 직접 검산은 차선) |
| `personas` | **파라미터** — 사용자에게 확인하거나 deck.md 전역 규약 블록의 청중 정의에서 도출. 페르소나는 에이전트에 하드코딩돼 있지 않다 |
| `official_sources` | deck.md 출처 절 + 사용자 지정 |
| `usage_notes` | 실사용 경험 기록(BUILD_PROGRESS·notes 등) — fact-check의 공식 vs 실사용 병기 점검용(없으면 생략 가능) |
| `render_qa` | `lecture-deck`의 `render-qa.sh` 출력(강의 덱이면) — 대괄호 leak·미교체 placeholder·리넘버 동기화의 **결정론** 결과. design-qa는 이 FAIL 목록을 눈검사보다 우선 소비한다(없으면 design-qa가 자체 검산으로 대체) |

## 절차

1. **범위 결정** — 전수 리뷰인지 이번 라운드 수정 장 한정인지. 수정 장 한정이어도 story-flow는 항상 전수(흐름은 부분 리뷰가 안 된다).
2. **병렬 dispatch** — 한 메시지에 4개 Agent 호출(subagent_type은 플러그인 네임스페이스 포함 `ppt-yeong-style:<agent>` — bare name은 Claude Code에서 해석 안 됨. 각각 자기완결 브리프: 위 입력 + 리뷰어 md의 입력 계약대로):
   - `ppt-yeong-style:audience-fit` (personas 주입)
   - `ppt-yeong-style:story-flow` (qa_reference로 ppt-yeong-style의 `references/ppt-master-and-qa.md` 경로 전달)
   - `ppt-yeong-style:fact-check` (official_sources + usage_notes 경로)
   - `ppt-yeong-style:design-qa` (render_dir + spec_lock + `render_qa` 결정론 결과가 있으면 그 FAIL 목록도 함께)
   md 확정 단계 사전 리뷰면 design-qa는 생략하고 3종만.
3. **codex 교차 리뷰(조건부)** — `codex:rescue` 스킬이 설치돼 있으면 리포트 종합 전에 1회 호출해 덱 소스(또는 수정 diff)에 대한 독립 리뷰를 받는다. **미설치면 생략하되 설치 제안 문구를 출력한다**: "codex 플러그인(codex:rescue)이 있으면 이 단계에서 교차 리뷰를 자동으로 받습니다 — marketplace에서 codex 플러그인을 설치하면 활성화됩니다."
4. **종합** — 리포트 3~5건(사전 리뷰·codex 미설치 조합에 따라 3건까지 줄 수 있음)을 장 번호 기준으로 병합해 **장별 수정 티켓**으로 정리:
   - 두 리뷰어 이상이 같은 장을 지적하면 우선순위 ↑.
   - 리뷰어 간 충돌(예: audience-fit "더 풀어라" vs design-qa "밀도 초과")은 그대로 노출하고 판단을 사용자/메인 세션에 남긴다 — 오케스트레이터가 임의 중재하지 않는다.
   - fact-check의 `unverified` 항목은 수정 티켓이 아니라 **검증 티켓**으로 분리.
5. **보고** — 티켓 목록 + 리뷰어별 GO/NO-GO 요약. 수정 실행은 이 스킬 밖(ppt-yeong-style 수정 규율: deck.md → SVG → notes 3중 동기화)이다.

## 하드 룰

- 리뷰어는 **관찰 + 제안**만 반환한다 — 파일 수정은 메인 세션이 한다(수정 규율 준수를 위해).
- 리뷰어 리포트를 그대로 사용자에게 쏟지 않는다 — 장별 티켓으로 종합해 전달.
- **런타임 폴백**: 이 스킬은 Claude Code의 서브에이전트 dispatch를 전제한다. Codex(0.135는 `agents`를 노출하지 않음)·Hermes처럼 dispatch가 없는 런타임에서는 병렬 dispatch가 막히므로, `agents/` 4종의 관점(audience-fit·story-flow·fact-check·design-qa)을 **메인 세션에서 순차 체크리스트로 직접 수행**하는 것으로 강등한다 — 관점·입력·출력 계약은 그대로. dispatch 가능한 런타임(Claude Code)에서만 4종을 순차로 돌리지 말고 병렬로 보낸다.
- 페르소나·출처 목록 같은 파라미터를 에이전트 파일에 써넣지 않는다 — dispatch prompt로만 주입(에이전트는 범용 유지).

## 의존

- 에이전트 4종은 이 플러그인 동봉(`agents/`). `codex:rescue`는 있으면 사용, 없으면 생략 + 설치 제안 문구(§위 3). 렌더가 필요한데 Playwright가 없으면 svg_output 검산으로 강등하고 리포트에 한계를 명시한다.
