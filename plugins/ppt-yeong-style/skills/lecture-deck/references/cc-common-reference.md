# 강의 덱 레퍼런스 — cc-common 47장 (투디제로 클로드 코드 공통 교안)

완성·실강의 검증까지 마친 3시간 강의 덱의 구조 실례. 새 강의 덱 설계의 출발점으로 참조한다(장수·부 구성은 인터뷰 우선). **실물 PPTX/PDF 바이너리는 이 플러그인에 동봉하지 않는다** — 소스·산출물은 `github.com/YoungjaeDev/cc-lesson-deck` `projects/cc-common_ppt169_20260623/`(deck.md·spec_lock·svg_output·notes·handouts·exports), 배포본은 Drive `투디제로-클로드코드-강의교안/`.

## 개요

| 항목 | 값 |
|---|---|
| 과정 | 비개발 임직원 대상 클로드 코드 입문, 대면 3시간 |
| 장수 | 47장 (표지·목차 + 부 6개 + divider 5 + 실습 4 + 즉석 실습 1 + 용어표) |
| 캔버스 | ppt169 1280×720, C3 에디토리얼 시그니처("Editorial restraint, one committed accent") |
| 색 | warm off-white `#FAF8F3` + ink + 주황 `#D97757`/`#C2410C` 액센트 ≤10% |
| 관통 철학 | 자립 — "블랙박스가 아니다 → .claude 폴더 안 텍스트 몇 개 → 직접 열고 고친다" |
| 버전 이력 | v1(34장) → v2(43→45→47장, 사실검증 5축+페르소나 16인) → v2.3(실강의 전사 회고 반영) |

## 로스터·리듬 배분 (47장)

| 구간 | 장 | 리듬 |
|---|---|---|
| 표지·목차 | P01–P02 | anchor 2 |
| 1부 개념 | P03(div)–P06 | anchor 1 + breathing 2 + dense 1 |
| 2부 설치·시작 | P07(div)–P13 | anchor 1 + breathing 4 + dense 2 |
| 3부 설정·운영 | P14(div)–P28 | anchor 1 + breathing 9 + dense 5 |
| 4부 실습 | P29(div)–P35 | anchor 1 + breathing 6 |
| 5부 기능 넓히기 | P36(div)–P44 | anchor 1 + breathing 8 |
| 6부 큰 그림·마무리 | P45–P47 | anchor 2 + dense 1 |

- 리듬 총계: anchor 9 / breathing 29 / dense 9 — dense는 표·비교 장에만, 3연속 없음.
- 실습 배치: 실습 1(P18, 3부 안 — 개념 직후 첫 손운동) → 실습 2·3·4(P31·P33·P35, 4부 집중) + 즉석 실습(P26 CLAUDE.md — 개념 장을 실습으로 승격한 사례).
- 도식 변주: radial-hub(MCP)·flow-stepper(Hooks)·org-diagram(서브에이전트)·folder-tree(.claude)·2단 비교 카드(프로젝트vs글로벌)·타임라인(Git)·before/after(실습2) — 인접 장 형태 중복 회피.

## 대표 렌더 (동봉 PNG, 800px 저용량)

| 파일 | 장 | 보여주는 것 |
|---|---|---|
| `../assets/cc-common/P01_cover.png` | 표지 | anchor pop(codex bg+마스코트) + 담백 명사구 제목 |
| `../assets/cc-common/P14_divider.png` | 3부 divider | 부 번호 hero_number + 한 줄 약속 |
| `../assets/cc-common/P41_diagram-radial.png` | MCP | radial-hub 개념 도식 + 한계 각주 + 팁 칩 |
| `../assets/cc-common/P23_table.png` | 보안 표 | 걱정→사실 6행 표(행 밴드 정렬) + footer 각주 2줄 |
| `../assets/cc-common/P18_exercise.png` | 실습 1 | 실습 배지 + checklist + 실물 스크린샷 프레임 + 팁 칩 |

## 검증 게이트 이력 (이 덱이 실제로 통과한 것)

1. **빌드 게이트**: ppt-master quality check 0 error + 대괄호 글리프 grep 0 (매 라운드).
2. **사실검증 5축**: 공식 docs(code.claude.com/docs) 대조 — 컨텍스트=모델 결정(플랜 아님), 권한 데스크톱 5종, `/clear` 데스크톱 부재 → + 버튼, 플랜모드 수정=댓글, 보안=data-usage. 공식 vs 실사용 병기(병렬 세션 규모 한계 등).
3. **페르소나 검증**: 비개발자 16인 페르소나 통독(v2) — GO 판정 후 출고.
4. **렌더 QA**: Playwright dsf=2 렌더 육안(수정 장 전수) + PPTX 장수 대조.
5. **전사 회고(v2.3)**: 실강의 55분+2시간 전사 fork 분석 → 커버리지 맵 → 기존 장 11개 보강(신규 장 0) + notes 운영 태그 + handouts 프롬프트 카드 신설.

## 재사용 포인트

- 3시간 과정의 부·실습 교차 골격과 리듬 배분은 그대로 출발점이 된다.
- handouts 4종(회의메모·공지·roster·프롬프트 카드)은 §2 생성 규약의 실물 예시.
- placeholder 슬롯 2종(S_usage_5h·P31_diff)이 출고를 막지 않고 v2.3에서 실캡처로 해소된 것이 §3 슬롯 운영의 실증.
