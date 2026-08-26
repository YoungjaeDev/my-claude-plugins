# Feature Specification: 저장소 전면 재개편 (full-restructure)

## Overview
Claude Code 플러그인 marketplace 저장소(14 플러그인 / 53 스킬 / 3런타임)를 재개편한다. Hermes 연동과 Codex 생성기 계층을 삭제해 런타임 표면을 최소화하고, 병렬 에이전트 감사로 플러그인·스킬·지침·지식 축적 체계를 통합하거나 과감히 삭제한다. P0 축은 세션 컨텍스트의 바이어스/노이즈 제거다.

## 확정 결정 (2026-08-26 인터뷰, 2차 개정)

1. **Hermes**: 연동 전면 삭제. 병렬 검토 전에 선행 실행한다 (검토 에이전트가 죽을 표면을 분석하는 낭비 방지).
2. **Codex 생성 계층 삭제**: `sync-codex-manifests.mjs` + `.agents/` + 모든 `plugins/*/.codex-plugin/` 삭제. 최신 Codex(로컬 0.147.0)는 `.claude-plugin/marketplace.json` 과 `.claude-plugin/plugin.json` 을 네이티브 폴백으로 읽는다 (매니페스트 탐색 순서: `.codex-plugin` → `.claude-plugin` → `.cursor-plugin`; marketplace 탐색: `.agents/plugins/marketplace.json` → `.claude-plugin/marketplace.json`). 근거는 DeepWiki(openai/codex) 조회로, 로컬 검증 전까지 unverified. 번들 Codex hooks(core-config 프롬프트 주입, llm-wiki stale 체크)는 생성 매니페스트가 배선하므로 함께 사라지는 것을 수용한다.
3. **플러그인/스킬**: keep-list 없음. 14개 전체가 재검토 대상. 통합과 함께 과감한 삭제를 병행한다. 목표 플러그인 구성안은 검토 리포트가 제안하고 사용자가 승인.
4. **P0 판정 축**: 바이어스/노이즈 제거. 트리거 간섭(53개 description이 매 세션 로드), 과도한 지침, 실사용 없는 스킬이 1순위 판정 기준.
5. **내부 상태 삭제**: legacy spec 15개(`.claude/spec/2026-04-07` ~ `2026-08-05`, git 추적됨) 삭제. `.llmwiki/` 는 raw/ 포함 전면 삭제 후 제로베이스 bootstrap (복구는 git 히스토리로만).
6. **지침 재작성**: 제로베이스. 대상은 AGENTS.md + `.claude/rules/` 3개 + `code_review.md` + 전역 `CLAUDE.md.global` 쌍 + README. `CLAUDE.md → @AGENTS.md` redirect 구조는 유지. 문서 언어는 한글 전면 전환 (영어가 필요한 부분만 영어 — 스킬 트리거 문구 등 매칭에 걸리는 영어는 유지).
7. **지식 축적**: 축적 유지, 큐레이션 방식 교체. 날짜+행위 나열식 append 금지, 현재 상태만 기술하는 증류형으로. 새 wiki는 bootstrap 시점부터 이 규칙 적용.
8. **USER.md**: 저장소 루트에 생성. Honcho 스타일 사용자 표현 — mem0(397개) + `.remember/` 히스토리 + 기존 작성 문서를 소스로 "사용자가 어떻게 일하는지"를 기술. 용도는 사용자 열람용 (지침이 소비하는 문서 아님).
9. **진행 방식**: 감사 리포트 → 사용자 승인 → 실행. 착수는 사용자가 별도 지시.

## Requirements

### Must Have (P0)
- [ ] Hermes 선행 삭제: `plugins/*/plugin.yaml` + `__init__.py` (4개), `scripts/sync-hermes-manifests.mjs`, CI의 Hermes `--check` 레그, AGENTS.md의 Hermes 절·미러·호환 표 언급, 스킬 본문의 "Hermes Agent Compatibility" 블록, `check-skill-tool-portability.mjs`의 Hermes 매핑 전제 재검토
- [ ] Codex 생성 계층 삭제: `sync-codex-manifests.mjs`(+테스트) + `.agents/` + `plugins/*/.codex-plugin/` 제거, 삭제 후 `codex plugin marketplace add <로컬 경로>` + `codex plugin list` 로 네이티브 폴백 동작을 로컬 검증 (실패 시 이 항목만 롤백)
- [ ] 병렬 에이전트 감사 리포트: 플러그인/스킬별 keep · merge · **kill(과감한 삭제)** 판정표 + 근거(파일/라인) + 목표 플러그인 구성안 제안
- [ ] 바이어스 분석: description 트리거 충돌·과잉 트리거·컨텍스트 총량(53개 description) 정량화
- [ ] 실사용 근거: 세션 트랜스크립트/커밋 히스토리에서 스킬별 실제 호출 흔적 수집 (수집 불가 항목은 unverified로 표기)
- [ ] 내부 상태 삭제: legacy spec 15개 + `.llmwiki/` 전체(raw 포함) 삭제, wiki는 새 큐레이션 규칙으로 bootstrap

### Should Have (P1)
- [ ] 지침 제로베이스 재작성: `AGENTS.md`(257줄) + `.claude/rules/` 3개 + `code_review.md`, 한글 전면. `CLAUDE.md → @AGENTS.md` redirect 유지. Codex GitHub cloud reviewer가 읽는 `## Review guidelines` 절은 새 문서에도 존치 (이미 한국어 리뷰 정책이므로 한글 전환과 충돌 없음)
- [ ] 전역 지침 쌍 재검토: `CLAUDE.md.global` + `.ko` 미러 — 한글 전면 전환 시 영어 SoT + .ko 미러 구조 자체의 존폐 포함 (한글이 정본이면 미러 불필요)
- [ ] `README.md`(703줄) 재작성: 살아남는 플러그인 구성 기준, 한글
- [ ] post-merge 지식 축적 재설계: 증류형 큐레이션 규칙 (신규 wiki bootstrap 규약과 한 몸으로 설계)
- [ ] USER.md 생성: 루트, Honcho 스타일, mem0 + .remember + 기존 문서 소스

### Nice to Have (P2)
- [ ] 유지보수 오버헤드 축소안: 버전 범프 규칙 단순화, CI 가드 7종 중 생성기 삭제로 무의미해지는 것 정리 (`--check` 레그, `check-skill-tool-portability` 등)

## Technical Constraints
- Codex 사용 자체(GitHub cloud reviewer, council 의석, codex-rescue)는 유지 — 삭제 대상은 생성기 계층뿐
- 플러그인 제거/통합 시 semver 규칙: per-plugin은 semver, `metadata.version`은 릴리스 카운터(제거여도 MINOR)
- 스킬 흡수 시 흡수된 본문 감사 우선 (옛 플러그인명 grep, PLUGIN_ROOT resolver, 네임스페이스 예제)
- 문서 일관성 가드(`check-doc-consistency.mjs`)와 수기 카운트 미러는 재작성 문서 구조에 맞춰 존폐 재판단
- USER.md 는 개인 정보 문서 — 커밋 여부는 생성 시점에 사용자에게 확인 (공개 저장소면 gitignore 후보)

## Edge Cases
| Scenario | Expected Behavior |
|----------|------------------|
| Codex 네이티브 폴백 로컬 검증 실패 | 생성 계층 삭제만 롤백하고 최소 유지본으로 재설계, 나머지 재편은 계속 |
| `.claude-plugin/plugin.json` 의 Claude 전용 필드(commands/agents/hooks)를 Codex가 거부 | 검증 단계에서 확인, 거부 시 해당 필드 처리 방안을 리포트에 기록 (DeepWiki 상 무시 예상이나 unverified) |
| 실사용 근거를 수집할 수 없는 스킬 | 판정을 unverified로 표기하고 바이어스/중복 축으로만 판단 |
| 통합으로 council/codex-image가 다른 번들에 섞임 | Codex 순환 소환 문제는 여전히 유효 — 감사에서 재검토하되 기본은 격리 유지 |
| 검토 리포트가 특정 플러그인 전체 kill을 제안 | 실행 전 사용자 승인 필수 |
| .llmwiki/raw 삭제 후 과거 전사록 필요 | git 히스토리에서 복구 (`git log -- .llmwiki/raw`) |

## Out of Scope
- 이 저장소 밖 marketplace(superpowers, ponytail 등 외부 플러그인)의 감사
- 감사 리포트 승인 전의 플러그인 삭제/통합 실행 (Hermes·Codex 생성 계층·내부 상태 삭제는 선행 확정이므로 예외)
- Hermes 런타임 자체나 다른 저장소의 Hermes 사용

## Open Questions
- 목표 플러그인 구성(개수, 경계)은 감사 리포트의 제안으로 결정
- 새 wiki bootstrap의 큐레이션 규약 상세(페이지 단위, 증류 기준)는 post-merge 재설계와 함께 설계
- USER.md 커밋 여부 (생성 시점에 확인)

## 실행 순서 (승인 후)
1. 선행 삭제 묶음 (issue → branch → PR): Hermes 전체 + Codex 생성 계층(+로컬 검증) + legacy spec 15개 + `.llmwiki/` 전체
2. 병렬 에이전트 감사 (read-only) → 리포트 + USER.md 초안 산출
3. 사용자 승인 → 통합/과감한 삭제 실행 → 지침 한글 제로베이스 재작성 → wiki bootstrap
