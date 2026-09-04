# 전면 재개편 감사 리포트 (2026-08-26)

- 대상: 14개 플러그인, 53개 스킬 (`plugins/*/skills/*/SKILL.md`)
- 증거: 플러그인별 감사 JSON + description 트리거 간섭 분석 + 로컬 transcript 실사용 스캔 (`C:/Users/yeong/.claude/projects/`, 읽기 전용)
- 결론 요약: **keep 31 / merge 13 / kill 9**. 플러그인 14 → 12 (e2e-harness, codex-image 삭제), 스킬 53 → 32. description 총량 26,065자 → 약 16,900자 (약 35% 감축).
- 증거 한계: transcript 스캔은 이 머신의 세션만 본다. 다른 머신·삭제된 세션·Skill 툴을 거치지 않는 호출 경로는 미집계. 따라서 **kill 은 전부 사용자 승인 후 실행** (특히 e2e-harness, voice-prompt).

## 1. 판정 요약표 (플러그인 14)

| 플러그인 | 판정 | keep/merge/kill | 한 줄 근거 |
|---|---|---|---|
| github-dev | restructure | 7/2/0 | 핵심 파이프라인(cr-fix 7히트, commit-and-push 6히트)은 증명됨. create-issue-label·update-progress 는 0히트에 기능이 형제 스킬에 이미 흡수돼 있음 |
| docs-forge | restructure | 5/4/2 | guide 4종은 커맨드가 결정적으로 로드하는 참조 카드라 통합. tcrei-prompt·voice-prompt 는 0히트 + 최고 바이어스 비용으로 kill |
| ml-toolkit | restructure | 4/2/0 | 6개 전부 0히트. cv-explorer/cv-notebook 중복 쌍, gpu-parallel-pipeline 은 ml-dev-principles §5 와 내용 모순까지 있는 중복 |
| code-scout | restructure | 1/3/0 | research-orchestrator(1히트)만 진짜 진입점. 나머지 3개는 scout 에이전트 내부 문서가 Skill 래퍼를 쓴 형태 |
| deepwiki | keep | 2/0/0 | 19·21줄짜리 좁은 트리거 스킬. ask 는 2히트 실사용 |
| paper-search-tools | restructure | 1/1/0 | setup(160줄 Docker 절차, 0히트/7개월)을 paper-search 트러블슈팅 절로 흡수 |
| llm-wiki | restructure | 4/0/2 | ingest-finding 3히트로 핵심. migrate-wiki 는 존재 이유(codex-bridge)가 은퇴, query-wiki 는 최광역 트리거에 3개월 0히트 |
| mem0-ops | restructure | 2/1/0 | 3개 모두 0히트지만 트리거가 좁음. 읽기 전용 진단 2개(doctor→fleet-scan)만 통합해 3→2 |
| core-config | keep | 0/0/0 | 스킬 없는 순수 hooks 플러그인. 스킬 discovery 바이어스와 무관 |
| project-init | keep* | 2/0/0 | new/wiring 은 반대 방향의 고유 기능. 단 wiring description 925자는 Codex 1024자 하드컷 근접으로 축소 필요 (3단계) |
| e2e-harness | **kill** | 0/0/3 | 3개 전부 0히트/약 2개월, setup→author→debug 강결합이라 부분 kill 불가. 도메인(Playwright 웹앱)이 관측된 작업 패턴과 무접점 |
| publish | restructure | 2/0/1 | gws-sync(wiring 통합축)·translate-web-article(routing 타깃)은 구조적 결합으로 keep. tally-form 은 기능적 호출자 0 + 최대 단일 footprint |
| council | keep | 1/0/0 | convene 7히트/6세션, 전체 최다 사용. prompt_inject.sh 가 매 프롬프트 포인터를 주입하는 상시 스캐폴드 |
| codex-image | **kill** | 0/0/1 | 0히트/11주, 기능적 의존 스킬 없음. 트리거 근거의 'deck builds' 시나리오가 repo 에 존재하지 않음 |

\* project-init 원 감사는 "restructure"였으나 스킬 판정은 둘 다 keep 이고 요구 작업이 description 축소뿐이라 keep(+trim)으로 정규화했다.

## 2. 스킬 단위 판정표 (53)

description 자수는 이 리포트 작성 시 소스트리에서 직접 재측정한 값이다 (총합 26,065자, 바이어스 분석과 일치). 플러그인별 감사 JSON 이 인용한 자수(post-merge ~1400, wiring 1000, plaud 820, tally-form 839 등)는 과대 추정으로, 실측값을 채택한다.[^1]

| 스킬 | 판정 | merge_target | 근거 (히트/세션, 핵심) | conf |
|---|---|---|---|---|
| github-dev:cr-fix | keep | | 7/7, 전체 최다. 모듈화된 637줄 + 좁은 트리거 | high |
| github-dev:commit-and-push | keep | | 6/6, 95줄 단일 책임 | high |
| github-dev:post-merge | keep | | 1/1. resolve-issue→cr-fix→post-merge 종점, state-envelope 배선. description 1,014자는 3단계 축소 대상 | med |
| github-dev:resolve-issue | keep | | 0/0, explicit-only 트리거. 유일한 issue→PR 오케스트레이터 | unv |
| github-dev:decompose-issue | keep | | 0/0. project-tracking state 의 유일 생산자, 하류 3곳이 소비 | unv |
| github-dev:release | keep | | 0/0, explicit-only. 대체 스킬 없는 릴리스 자동화 | unv |
| github-dev:state-tracker | keep | | 0/0이나 도입 2026-08-08(2~3주)로 무의미. post-merge Step 5.7 이 자동 호출 | unv |
| github-dev:create-issue-label | merge | decompose-issue | 0/0/3개월, 37줄. decompose-issue:266 이 이미 라벨 검증을 자체 수행 | med |
| github-dev:update-progress | merge | post-merge (references/화) | 0/0/3개월, 335줄이 post-merge Step 5.5 의 참조 문서로만 소비됨 | med |
| docs-forge:readme-guide | merge | 신규 doc-guides | 66줄 참조 카드, commands/readme.md 가 유일 실진입점 | high |
| docs-forge:changelog-guide | merge | 신규 doc-guides | 80줄, 동일 패턴, 0히트 | high |
| docs-forge:deploy-doc-guide | merge | 신규 doc-guides | 32줄 최단, 결정적 단일 호출자 | high |
| docs-forge:moc-guide | merge | 신규 doc-guides | 51줄, commands/moc.md 가 명시 로드 | high |
| docs-forge:interview-methodology | keep | | 2/2 실사용. 323줄로 형제 규범(300줄) 8% 초과, trim 대상 | high |
| docs-forge:tcrei-prompt | **kill** | (TCREI 템플릿만 interview-methodology references/로) | 0/0, 350줄 최장. 과거 깨진 subagent dispatch 를 패치로 제거한 이력. 'improve this prompt' 광역 트리거 | med |
| docs-forge:voice-prompt | **kill** | | 0/0, 본문에 bash 인라인(자체 scripts/ 규칙 위반). 음성 세션 블라인드스팟 있어 **삭제 전 사용자 확인 필수** | low |
| docs-forge:skill-forge | keep | | 0/0이나 도입 2026-08-10 직후. 형제 2종의 규칙 SoT | high |
| docs-forge:skill-audit | keep | | 0/0, 신규. 이 감사 자체의 모델 | high |
| docs-forge:skill-fleet-review | keep | | 0/0, 신규. measurement-first 설계 | high |
| docs-forge:write-rules | keep | | 0/0, 403줄 최대(trim + dead pointer 'claude-md-management' 수정 필요). project-init:new 와 구조적으로 비중복 | high |
| ml-toolkit:cv-explorer | merge | cv-notebook | 0/0/5.5개월. line 8 보일러플레이트·End Gate 스크립트가 cv-notebook 과 사실상 동일, viewer_type 파라미터 차이 | med |
| ml-toolkit:cv-notebook | keep | | 0/0이나 트리거가 notebook-qualified 로 더 좁음. cv-explorer 흡수처 | med |
| ml-toolkit:edit-notebook | keep | | 0/0, 도입 2.5주. .ipynb 가드레일 스킬, 53줄 | unv |
| ml-toolkit:gpu-parallel-pipeline | merge | ml-dev-principles | 0/0/6.8개월. ml-dev-principles §5 와 'GPU utilization' 트리거 리터럴 중복 + 권고 방향 모순 | med |
| ml-toolkit:gradio-cv-app | keep | | 0/0/6.8개월이나 유일 콘텐츠(다크모드 버그 우회 포함). 무자격 트리거('object detection') trim 대상 | low |
| ml-toolkit:ml-dev-principles | keep | | 0/0/2개월. 고유 고도(프로세스 규율). 광역 트리거('train' 등 19개) trim 대상 | med |
| code-scout:research-orchestrator | keep | | 1/1. negative trigger 5개 보유한 유일 진입점. 단 positive('업데이트','보완','재실행')가 오발동 위험 1위, trim 대상 | med |
| code-scout:brightdata-guide | merge | references/화 (web-scout 등이 경로로 읽음) | 0/0/2개월, 342줄 최장 본문 + "any URL" 최광역 트리거(P0 교과서 사례) | high |
| code-scout:exa-web-search | merge | references/화 | 0/0/3개월. 자기 스스로 'web-scout agent 가 primary consumer'라 기술 | med |
| code-scout:resource-finder | merge | references/화 | 0/0/7개월 최고령. 자칭 'shared hygiene reference' | med |
| deepwiki:ask | keep | | 2/2, 19줄, MCP 툴 결속 트리거 | high |
| deepwiki:generate-llmstxt | keep | | 0/0이나 21줄에 기계적 트리거, 충돌 후보 없음 | unv |
| paper-search-tools:paper-search | keep | | 0/0이나 paper-scout 가 cross-plugin 으로 MCP 툴을 소비(Skill 호출로 안 잡히는 경로) | unv |
| paper-search-tools:setup | merge | paper-search (트러블슈팅 절) | 0/0/7개월, 160줄 순수 Docker 절차. 실패 경로에서만 필요 | med |
| llm-wiki:ingest-finding | keep | | 3/3 + post-merge 필수 단계 배선 | high |
| llm-wiki:lint-wiki | keep | | 1/1, 주기 수동 트리거 성격상 저빈도 정상 | med |
| llm-wiki:bootstrap-wiki | keep | | 0/0이나 스펙 결정 #5(.llmwiki 제로베이스 재부트스트랩)가 실행을 구조적으로 요구 | unv |
| llm-wiki:migrate-wiki | **kill** | 잔여 분기만 bootstrap-wiki 안내문으로 | 0/0/3개월. 존재 이유인 codex-bridge 가 은퇴, 결정 #2로 신규 .codex/wiki 발생 경로 차단 | high |
| llm-wiki:query-wiki | **kill** | 'index.md 먼저 읽어라' 한 줄 규약을 AGENTS.md/CLAUDE.md 로 | 0/0/3개월(최고령 코호트). 사실상 모든 회상형 질문에 걸리는 최광역 트리거, 본문의 실질은 Read 안내뿐 | high |
| llm-wiki:plaud-note-taking | keep | | 0/0이나 도입 2.5주. description 753자는 3단계 축소 대상 | unv |
| mem0-ops:fleet-scan | keep | | 0/0/7주. 원격 API 집계라는 대체 불가 데이터 소스, doctor 흡수처 | unv |
| mem0-ops:doctor | merge | fleet-scan (로컬 posture 절로) | 0/0/7주. 동일 읽기 전용 진단 패턴 + upstream mem0:health 와 사용자 구분 비용 | med |
| mem0-ops:cleanup | keep | | 0/0. 유일한 파괴적 동작으로 별도 안전 게이트 유지가 안전 | unv |
| project-init:new | keep | | 0/0/3개월이나 저빈도 작업 + empty-dir 하드가드로 오발동 피해 0 | med |
| project-init:wiring | keep | | 0/0/7주. 4개 efficacy axis 는 대체 없음. description 925자는 Codex 1024자 하드컷의 90%, 3단계 축소 필수 | low |
| e2e-harness:e2e-setup | **kill** | | 0/0/2개월. 품질 문제 아닌 사용 부재 + 도메인 무관 | low |
| e2e-harness:e2e-author | **kill** | | 0/0, e2e-setup 종속이라 단독 생존 불가 | low |
| e2e-harness:e2e-debug | **kill** | | 0/0. 'failed CI run or PR' 트리거가 github-dev 영역과 충돌 위험까지 있음 | low |
| publish:gws-sync | keep | | 0/0이나 project-init:wiring 이 전용 verdict 표로 소비하는 1급 통합축 | med |
| publish:tally-form | **kill** | | 0/0/10주, 기능적 호출자 0. 194줄 + 참조 5 + asset 7 + 스크립트로 최대 단일 footprint | med |
| publish:translate-web-article | keep | | 0/0/7개월(최부정 신호)이나 research-orchestrator routing 타깃(위임은 Skill 호출로 안 잡힘) | low |
| council:convene | keep | | 7/6, prompt_inject 상시 포인터. 637줄 본문의 Step 0 쉘 블록(~절반)은 P2 references/화 후보 | high |
| codex-image:codex-image | **kill** | | 0/0/11주, 의존 호출자 0, 'deck builds' 근거 시나리오 부재. 잘 만든 미사용 스킬 | med |

[^1]: 판정 간 모순 처리: (a) github-dev 감사 JSON 의 post-merge 중복 항목은 가드 표기라 1건으로 계수. (b) 플러그인 감사자들의 description 자수 인용은 실측(JS string length, block scalar 공백 join)과 최대 386자 차이가 나 실측값으로 통일했다. 자수 차이는 어떤 판정의 방향도 바꾸지 않는다. (c) query-wiki 는 kill + 잔여 규약의 문서 흡수로, 감사 JSON 의 'kill'과 merge_target 병기를 그대로 따랐다.

## 3. 목표 구성안

### 안 1 (권고): 12 플러그인 / 32 스킬

| 플러그인 | 스킬 (재편 후) | 변경 |
|---|---|---|
| core-config | (hooks only) | 변경 없음 |
| github-dev | cr-fix, commit-and-push, post-merge, resolve-issue, decompose-issue, release, state-tracker (7) | create-issue-label→decompose-issue 본문, update-progress→post-merge references/ |
| docs-forge | doc-guides(신규 통합), interview-methodology, skill-forge, skill-audit, skill-fleet-review, write-rules (6) | guide 4종→doc-guides 1개, tcrei-prompt·voice-prompt 삭제(TCREI 템플릿은 interview-methodology references/로) |
| ml-toolkit | cv-notebook, edit-notebook, gradio-cv-app, ml-dev-principles (4) | cv-explorer→cv-notebook(viewer 모드), gpu-parallel-pipeline→ml-dev-principles §5 보강 |
| code-scout | research-orchestrator (1) | brightdata-guide·exa-web-search·resource-finder → references/ 파일 (scout 에이전트가 경로로 직접 읽음) |
| deepwiki | ask, generate-llmstxt (2) | 변경 없음 |
| paper-search-tools | paper-search (1) | setup→paper-search 트러블슈팅 절 |
| llm-wiki | bootstrap-wiki, ingest-finding, lint-wiki, plaud-note-taking (4) | migrate-wiki 삭제(legacy 분기는 bootstrap-wiki 안내문), query-wiki 삭제(규약 한 줄은 AGENTS.md) |
| mem0-ops | fleet-scan, cleanup (2) | doctor→fleet-scan '로컬 설정 posture' 절 |
| project-init | new, wiring (2) | wiring description 축소만 |
| publish | gws-sync, translate-web-article (2) | tally-form 삭제 |
| council | convene (1) | Step 0 쉘 블록 references/화 (P2) |
| ~~e2e-harness~~ | 삭제 | 3스킬 강결합, 전체 kill (사용자 승인 후) |
| ~~codex-image~~ | 삭제 | 단일 스킬 kill |

### 안 2 (보수 대안): 12 플러그인 / 44 스킬

kill 9건(e2e-harness 3, codex-image, tcrei-prompt, voice-prompt, tally-form, migrate-wiki, query-wiki)만 실행하고 merge 13건은 보류한다.

- 장점: 흡수 스킬 본문 감사(AGENTS.md 규칙)라는 고비용 작업이 없고, 13건의 버전 범프·회귀 위험이 0이다.
- 단점: description 총량이 약 21,030자에 그쳐 감축이 19% 수준이고, cv-explorer/cv-notebook·gpu-parallel-pipeline/ml-dev-principles 의 트리거 경합(리터럴 'GPU utilization' 중복 등)이 그대로 남는다.
- 판단: 바이어스 분석이 확인한 충돌 쌍 14개 중 절반 이상이 merge 로만 해소되므로 안 1 을 권고한다.

## 4. 바이어스 개선 수치

| 항목 | 현재 | 안 1 | 안 2 |
|---|---|---|---|
| 스킬 수 | 53 | 32 | 44 |
| description 총량 | 26,065자 | 약 16,900자 | 약 21,030자 |
| 감축률 | | 약 35% | 약 19% |

안 1 산출 근거 (실측 자수 기준):

- kill 9건 제거: 334+736+379+350+683+665+693+727+468 = **5,035자**
- merge 13건 제거: 401+543+(144+157+242+225)+372+480+709+304+334+237+465 = **4,613자**
- 신규/증가분 (추정): doc-guides 신규 description ~250자 + fleet-scan·cv-notebook·ml-dev-principles·paper-search 흡수 반영 ~250자 = **약 +500자**
- 26,065 − 5,035 − 4,613 + 500 ≈ **16,917자**

3단계 trim(아래) 까지 실행하면 추가 약 2,000자 감축 여지가 있다: post-merge 1,014 / wiring 925 / research-orchestrator 896 / plaud-note-taking 753 / council 644 / ml-dev-principles 633 을 각각 절반 수준으로 축소할 경우다 (미실행 추정치).

## 5. 실행 순서 (3단계)

### 1단계: kill (사용자 승인 게이트)

- 승인 대상을 먼저 확인한다: e2e-harness(다른 머신 사용 가능성), voice-prompt(음성 세션 블라인드스팟)는 transcript 스캔이 못 보는 경로가 명시돼 있어 사용자 확인 없이는 삭제하지 않는다.
- 플러그인 삭제: `plugins/e2e-harness/`, `plugins/codex-image/` + marketplace.json 항목 제거.
- 스킬 삭제: tcrei-prompt, voice-prompt, tally-form, migrate-wiki, query-wiki. 삭제 전 잔여 콘텐츠 이관(TCREI 템플릿, migrate 분기 안내문, query-wiki 규약 한 줄).
- 동기화: AGENTS.md `## Plugins (N)` 표·README 트리·카운트, 해당 플러그인 PATCH/MINOR 범프, `metadata.version` MINOR (플러그인 제거는 릴리스 카운터 규칙상 MINOR, `.claude/rules/plugin-versioning.md` 근거).
- 가드: `node scripts/check-doc-consistency.mjs` + `check-skill-contract.mjs` 통과 확인. 신규 파일이 있으면 `git add` 후 `check-shell-portability.mjs` 재실행.

### 2단계: merge (13건)

- AGENTS.md 흡수 규칙 준수: 배선 전에 **흡수된 스킬 본문을 먼저 감사**한다. 옮긴 트리에서 옛 플러그인/스킬명을 grep 하고, `PLUGIN_ROOT` resolver 의 옛 경로·네임스페이스 없는 `/skill-name` 예제를 잡는다.
- 순서는 저위험부터: (1) docs-forge guide 4종→doc-guides (결정적 호출자만 수정), (2) paper-search-tools:setup, mem0-ops:doctor, (3) github-dev 2건, (4) ml-toolkit 2건 (gpu-parallel-pipeline 흡수 시 ml-dev-principles §5 와의 내용 모순을 §5 기준으로 해소), (5) code-scout 3건 references/화 (agents/*.md 의 참조 경로 갱신 포함).
- 각 건마다 흡수처 플러그인 버전 범프 (미범프 시 캐시 게이트 사용자에게 이동이 안 내려감).

### 3단계: trim (description 축소)

- 필수: project-init:wiring 925자 (Codex 1024자 하드컷 여유 확보), github-dev:post-merge 1,014자 ('merged a PR' 암시 트리거 제거, explicit-invocation 위주로).
- 권고: research-orchestrator ('업데이트'·'보완'·'재실행' 등 범용 한국어 트리거 제거), ml-dev-principles (bare 'train' 등 무자격 트리거 삭제), plaud-note-taking (내용을 본문으로 이동), council:convene (본문 Step 0 references/화 포함).
- 각 편집 후 `check-skill-contract.mjs` 로 1024자 한도 재검증.
