# Spec: matt-front-dev-back

Date: 2026-10-06
Status: draft
Owner: YoungjaeDev

## Context

2026-10-04 클래스 준비에서 `mattpocock-skills` 1.3.1 (4588b32) 흐름을 썼다 (`/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement-spec`). 써 보니 dev 플러그인 앞단보다 짜임새가 낫다고 판단했다. 분석은 Workflow `wf_1d3eb1d0-7c1` 로 했다 (에이전트 14개: 읽기 8, 종합 2, 반박 검증 4). 결론을 떠받치는 주장은 원본 파일로 다시 확인했다.

- **Matt 의 장점은 내용이 아니라 구조다.**
  - 스킬 하나가 일 하나만 한다. `implement` 는 tdd → code-review → commit 을 부르는 15줄이다. dev 의 `decompose-issue` 는 책임이 약 17개·게이트가 9개이고, `resolve-issue` 는 책임이 약 18개·플래그가 11개다.
  - 단계마다 다음 스킬이 읽을 산출물이 있다 (spec 이슈 → blocking 링크가 걸린 티켓 → integration branch). dev 는 interview 에서 decompose 로 넘어갈 때 입력 계약이 없다.
  - 같은 범위로 맞추면 줄 수 차이는 1.2-1.3배뿐이다. 짧아서가 아니라 잘게 쪼개져 있어서 낫다.
  - 9/18 차용은 내용만 가져오고 구조는 안 가져왔다. `dev:diagnose` 는 원본 138줄을 59줄로 줄이면서 bisect·fuzz·HITL 루프를 뺐다.
- **Matt 흐름은 "PR ready for review" 에서 끝난다.** 리뷰 봇·머지·post-merge·release 는 다루지 않는다. dev 의 사용량은 바로 그 구간에 몰려 있다 (Claude transcript 기준: post-merge 32회, cr-fix 24회, orchestrate 24회). 앞단은 decompose-issue 5회, resolve-issue 10회이고, 9/21 이후로는 0회다.
- **cr-fix 는 자기 마지막 push 에 대한 리뷰를 기다리지 않고 끝난다.**
  - minor_floor 분기 주석이 "Safe: Step 12 already pushed them" 이다 (`references/run-blocks.md:321`).
  - Codex 리뷰는 68-726초 걸리는데 (중앙 224초, n=47), Codex grace 기본값은 30초다 (`references/arguments.md:13`).
  - PR #269 의 두 run 은 push 38초·22초 뒤에 끝났다. 그 뒤 도착한 Codex P1 은 손으로 고쳤다 (6857e93). PR #223 은 Codex 가 HEAD 를 Running 중일 때 clean 으로 아카이브했고, 5분 뒤 P1 3개가 왔다. Codex 만 따로 돌린 패스가 더 잘해 보인 주원인이 이것이다.
  - PR #223 의 잘못된 clean 에는 CodeRabbit 쪽 원인도 있다. "Review rate limited" success status 를 리뷰 완료로 읽었고 (`scripts/poll-cr-status.sh:88-91`), engagement-gate 는 rate-limit 공지 편집을 리뷰 활동(engagement)으로 셌다.
  - 빌드·테스트가 실패해도 push 한다 (`SKILL.md:243`).
  - 루프 본문은 셸 하나가 계속 살아 있다고 가정하지만, Bash 도구는 호출 사이에 변수를 유지하지 않는다. 그래서 모델이 루프를 손으로 굴리고 state 가 어긋난다 (PR #223: iteration 커밋 6개, 로그 5개).
- **CodeRabbit 은 빼면 안 된다.**
  - 제품 repo 3곳(drone-ai, lotte-vlm, langgraph)은 Codex 리뷰가 0건이다. 9/15-18 사이 Codex 사용량 한도 공지가 83건 달렸다.
  - 9개 repo 합계 적용된 수정은 CodeRabbit 174, Codex 66 이다. 이 repo 에서 둘 다 리뷰할 때는 59 대 56 이다.
  - 클래스 repo 의 `codex-pr-review` 는 이 Mac 에서 실제 루프를 한 번도 돌지 않았다. 이 repo 의 Codex 는 clean/failed 를 PR summary 댓글(수정되는 표)로만 알린다.
- **post-merge 에는 세 가지 일이 섞여 있다.**
  - (A) 머지 뒤 정리
  - (B) 교훈 반영: Step 6 은 CLAUDE.md/AGENTS.md/rules, Step 7 은 Serena, Step 8 은 wiki
  - (C) 문서 손질: Step 9 는 README·About, Step 9.5 는 CHANGELOG
  - (B) 는 Matt `/retro` 와 겹치는데 방향이 반대다. retro 는 기계적인 실수를 자동 검사로 바꾸고, 항상 로드되는 문서는 최소로 둔다. Step 6 은 교훈을 문장으로 쌓는다. 그 결과 AGENTS.md 는 약 20KB, dev/CLAUDE.md 는 약 30KB 가 됐다.
- **llmwiki 는 성격이 다른 두 가지 일을 같이 하고 있다.**
  - 이 repo 의 9페이지 중 약 7개는 사실상 ADR 이다 (결정 + 이유 + 트레이드오프). 나머지 2개는 AGENTS.md 규칙과 내용이 같다. 이 repo 에서는 wiki 를 쓴 세션이 9개, 질문하려고 읽기만 한 세션이 4개다.
  - 제품·연구 repo 에는 밖에서 들어온 지식이 쌓여 있다. tofu 는 광학·조달 조사와 회의록, forensic 은 고객 협상과 파이프라인 조사, xion 은 제품 논지, thezero 는 모델·디바이스 사실이다. 이건 ADR(결정)에도 GLOSSARY(용어)에도 맞지 않는다. 그리고 실제로 읽힌다. 다른 작업 없이 질문하려고 wiki 를 읽은 세션이 26개다 (서브에이전트 포함, transcript 스캔 기준).
  - 군더더기가 많다.
    - 자동 수집 파일 약 200건이 처리되지 않은 채 쌓여 있다.
    - `insight/` 층이 규칙을 두는 네 번째 장소가 됐다.
    - 관계 타입 10종 중 실제로 쓰이는 건 See-also(244회)와 Evidence(120회)뿐이다. Contradicts·Superseded-by 는 0회다.
    - query 는 2026-08 에 없앴다.
    - 플러그인은 훅 5개·스킬 6개·스크립트 5개로 3,265줄이다. 그중 cleanup·fleet-scan 은 한 번도 쓰이지 않았다.
  - Claude 쪽 훅은 동작한다. Codex 쪽 `~/.codex/hooks.json` 은 6개 항목이 모두 `wiki/1.0.0/` 을 가리키는데, 캐시에는 `1.0.2/` 만 있어서 동작하지 않는다.
- **9/18 결정 하나를 번복한다.** 2026-09-18-pocock-borrow 의 Non-goals 는 "CONTEXT.md/ADR 은 `.llmwiki` 와 겹친다" 고 했다. 이는 절반만 맞다. GLOSSARY 는 겹치지 않고, ADR 은 일부만 겹친다.

## Goal

아래 PR 4개가 머지되면 다음이 성립한다.
- 아이디어부터 PR 까지는 Matt 스킬이 원본 그대로 맡고, PR 부터 머지·정리까지는 dev 가 맡는다.
- dev 에 앞단을 중복하는 스킬(decompose-issue, resolve-issue, diagnose, state-tracker)이 없다.
- `dev:flow` 가 Matt 앞단과 dev 뒷단을 함께 안내한다.
- `dev:review-loop` (구 cr-fix) 는 켜져 있는 리뷰어 전원이 현재 HEAD 에 결과를 낸 뒤에만 멈추거나 머지한다.
- post-merge 는 머지 뒤 정리만 한다.
- 지식마다 둘 곳이 하나씩 정해져 있다.
  - 결정 → `docs/adr`
  - 용어 → `GLOSSARY.md`
  - 같은 실수 막기 → 자동 검사·CODING_STANDARDS·포인터 (`/retro`)
  - 밖에서 들어온 지식 → `.llmwiki`
- wiki 는 raw → 개념 페이지 구조이고 ingest·query·lint 만 한다. 훅은 없다.
- 이 repo 의 결정 기록은 `docs/adr` 에 있다.

## Non-goals

- Matt 스킬의 fork·vendor·수정. 원본을 auto-update 로 그대로 쓴다.
- 트래커를 GitHub 으로 고정하는 것. repo 마다 Matt setup 이 고르는 대로 둔다.
- 리뷰 루프 상태를 파일 기반 CLI 로 옮기는 2단계 작업.
- 클래스 repo 의 `codex-pr-review` 변경.
- 제품 repo 에 이미 있는 wiki 페이지를 ADR 로 옮기는 일. 새 결정부터 ADR 로 남긴다.

## Decisions

| # | Question | Choice | Rationale |
|---|----------|--------|-----------|
| 1 | 앞단 흐름 | Matt 를 쓴다: `/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement-spec` 또는 `/implement`. dev 는 PR 이후를 맡는다 | 구조가 낫고 dev 앞단은 거의 안 쓰인다 (Context) |
| 2 | trial | 하지 않는다. PR1 머지 전에 Codex 에서 `$to-spec` → `$to-tickets` → `$implement-spec` 을 한 번만 돌려 확인한다 | 사용자: Matt 완성도가 더 좋다. 확인은 기획 스킬을 지운 뒤 Codex 에 기획 수단이 하나도 없는 상황을 막기 위함 |
| 3 | Matt 설치 | Claude·Codex 양쪽에 설치한다. 버전을 고정하지 않고 auto-update 로 둔다. Claude 는 지금처럼 user scope | 사용자 지정. #9·#10 때문에 특정 repo 에서만 켜면 나머지 repo 에서 진단·grill 스킬이 비어 버린다 |
| 4 | Codex 동등성 | 필요하다. Matt 를 Codex 에도 설치하고, setup 블록을 AGENTS.md 에도 둔다 | 사용자 지정. setup 은 CLAUDE.md 가 있으면 거기에만 쓴다 (`setup-matt-pocock-skills/SKILL.md:76-80`). Codex 문서에는 marketplace 자동 갱신이 안 보이고 `codex plugin marketplace upgrade` 수동 명령만 있다 (UNVERIFIED) |
| 5 | 트래커·PR 인계 | 트래커를 고정하지 않고 Matt 설정도 수정하지 않는다. PR 이 필요하면 implement-spec 에 "draft PR 열어줘" 라고 요청한다. PR 이 없으면 dev 뒷단을 건너뛴다 | 사용자: Matt 원본을 최대한 유지. implement-spec step 3, 클래스 `brief.md:81` 과 같은 방식 |
| 6 | PR 단위 | 사용자가 그때그때 정한다 | 사용자 지정. implement-spec 은 요청하면 spec 당 draft PR 1개를 연다 |
| 7 | 결정·용어 저장소 | 제품 repo 에 `GLOSSARY.md` 와 `docs/adr` 를 둔다 | to-tickets·tdd·diagnosing-bugs 가 정해진 단계에서 이 파일들을 읽는다. 9/18 Non-goal 번복 |
| 8 | 진행 추적 | 없앤다: decompose-issue 의 milestone·다이어그램, post-merge 5.5 + `references/update-progress.md` | 추적 파일 10개의 갱신이 9/20 에서 멈췄다 |
| 9 | 버그 진단 | Matt `diagnosing-bugs` 를 쓰고 `dev:diagnose` 는 지운다 | dev:diagnose 는 138줄 원본을 59줄로 줄인 축약본이고, 같은 요청에 두 스킬이 경쟁한다 |
| 10 | 'grill me' | Matt `grilling` 이 맡는다. interview-methodology 에서는 relentless 모드와 그 트리거를 빼고, 모호한 점 확인·breadth-first·TCREI 만 남긴다 | 두 스킬이 같은 문구로 경쟁한다. grilling 을 막으면 grill-with-docs 가 깨진다 |
| 11 | spec 위치 | Matt to-spec 기본 동작을 따른다 (트래커를 따라감) | 기본값. Matt 원본 유지 |
| 12 | 병렬 작업 | spec 단위는 implement-spec, spec 없이 즉석으로 나눌 때는 orchestrate | orchestrate 의 파일 소유 분리가 implement-spec 병렬 충돌을 막는다 (Matt `docs/engineering/implement-spec.md:54`) |
| 13 | CodeRabbit | 루프에 남기고 버그를 고친다 | 제품 repo 는 CodeRabbit 만 리뷰한다 (Context) |
| 14 | auto-merge | 켜져 있는 리뷰어 전원이 HEAD 에 결과를 냈고, 꼭 확인해야 하는(gated) 지적이 모두 반영됐거나 follow-up 이슈로 넘어갔을 때만 머지한다 | 지금 gate 는 CodeRabbit 상태만 본다 |
| 15 | Codex P2 | 첫 iteration 에서만 판단하고, 이후 나오는 P2 는 follow-up 이슈로 넘긴다 | 적용한 P2 가 다음 라운드의 지적거리가 된다. 지금까지 8개 중 7개를 적용했다 |
| 16 | Codex Failed | PR 에 댓글을 달지 않고 `final_state=codex_failed` 로 멈춘 뒤 알린다 | 사용자 지정. `@codex` 댓글 금지 유지 |
| 17 | 이름 | `cr-fix` → `dev:review-loop`. state 접두사도 새 이름으로 바꾸고, post-merge 는 옛 `cr-fix-` 접두사도 읽는다. description 에 옛 이름 "cr-fix" 를 남긴다 | code-review·pr·codex-pr-review 와 이름이 겹치지 않는다. 9개 repo 에 옛 이름의 state 기록이 있다 |
| 18 | post-merge 범위 | 정리 단계(1-5, 10, 11)만 남긴다. Step 6·7 은 Matt `/retro` 로 대체하고 Step 8 은 지운다. Step 9·9.5 는 `docs:readme`·`docs:changelog` 를 가리키는 한 줄로 줄이고, About 불일치 체크 한 줄은 남긴다 | retro 원칙(자동 검사 우선, 상시 로드 문서는 최소)이 맞다. 지식 ingest 는 머지 때가 아니라 원본이 들어올 때 한다 |
| 19 | wiki 훅 | 5개 전부 지운다. Codex `~/.codex/hooks.json` 의 wiki 항목도 뺀다. 쌓인 staging 은 지운다 | 수집된 파일이 처리되지 않는다. index 포인터는 전역 지침 한 줄로 충분하다 |
| 20 | writing-for-agents 충돌 (이 repo) | deny 하지 않는다. 스킬 계약은 기존 가드(`check-skill-contract.mjs` 등)가 잡는다 | `/retro` step 1 이 writing-for-agents 를 부르므로, deny 하면 이 repo 에서 retro 가 깨진다 |
| 21 | wiki 역할 | 밖에서 들어온 지식 전용으로 줄인다 (회의록·리서치·고객 문서·플랫폼 사실). raw → 개념 페이지 구조로, 작업은 ingest·query·lint 와 plaud 만 둔다. insight 층, staging, cleanup·fleet-scan·bootstrap 스킬은 지운다. 관계 타입은 링크와 Sources 만 남긴다 | 결정은 ADR, 용어는 GLOSSARY, 실수 방지는 retro 가 맡는다. 남는 일은 밖에서 들어온 지식이고, 이건 실제로 읽힌다 (26세션) |
| 22 | 이 repo 의 wiki | 9페이지를 ADR 3-게이트로 판정한다. 통과하면 `docs/adr`, AGENTS.md 규칙과 같으면 삭제한다 (약 7 / 2). `.llmwiki/` 는 정리한다 | 내용이 사실상 ADR 이고, 쓰기 세션이 읽기 세션보다 많다 |

## Plan

PR 4개로 나눠 순서대로 진행한다. 버전은 `.claude/rules/plugin-versioning.md` 를 따른다 (스킬·훅 삭제와 스킬 이름 변경은 MAJOR).

### PR1. 앞단 정리 (dev, docs, scout, wiki, deck)
- **삭제:**
  - `plugins/dev/skills/{decompose-issue,resolve-issue,diagnose,state-tracker}` 와 `plugin.json` 의 skills 항목.
  - post-merge Step 5.5·5.7 과 `references/update-progress.md`.
  - post-merge Step 6·7·8 과 `references/learning-integration.md`, `references/wiki-ingest.md`. `references/core-principle.md` 는 wiki 쪽에서 참조하므로 PR2 에서 처리한다.
- **참조 정리:** 지운 스킬을 가리키는 live 파일을 고친다.
  - `.claude/rules/state-envelope.md`, `AGENTS.md`, `README.md`, `plugins/dev/CLAUDE.md` (flags 표, worktree 예시)
  - `plugins/dev/references/new-procedure.md`
  - `plugins/dev/skills/{commit-and-push,cr-fix,e2e-debug,new,post-merge,release,wiring}`
  - `plugins/scout/skills/research-orchestrator/` (SKILL.md, `references/agent-routing.md`)
  - `plugins/wiki/CLAUDE.md`, `plugins/wiki/skills/bootstrap-wiki/` (SKILL.md, spec 템플릿)
  - 과거 기록 문서(docs/audit, .claude/spec)는 바꾸지 않는다.
  - 확인 명령: `rg -l 'decompose-issue|resolve-issue|dev:diagnose|state-tracker' plugins README.md AGENTS.md .claude/rules`
- **e2e-debug:** 가설 단계(`:68`)가 Matt `diagnosing-bugs` 를 가리키게 바꾼다.
- **interview-methodology:**
  - description 에서 'grill me', 'poke holes in this', '집요하게 캐물어' 를 빼고, relentless 모드 절을 지운다.
  - relentless 모드를 가리키던 곳을 Matt `grilling` 으로 바꾼다: `deck-ask:38-39`, `plaud-note-taking:82,120`, `vp` description, `plugins/docs/CLAUDE.md:11,271`.
  - `orchestrate:38` (모호한 작업 확인 용도)은 그대로 둔다.
- **dev:flow 재작성:** 아래 흐름을 담는다.
  - 앞단의 자세한 규칙(컨텍스트 관리, prototype·wayfinder 같은 갈래)은 `/ask-matt` 에 맡기고 복사하지 않는다. Matt 스킬 이름은 5-6개만 적는다.
  - 한국어 트리거는 유지한다. 지금처럼 다음에 무엇을 입력할지만 알려 주고, 직접 실행하지는 않는다.

  ```
  [Matt] /grill-with-docs → /to-spec → /to-tickets    한 컨텍스트 창에서, 중간에 /compact 금지
  [Matt] /implement-spec ("draft PR 열어줘" 하면 PR 1개) 또는 티켓마다 /implement (사이에 /clear)
  ── PR 이 있으면 ──
  [dev]  /dev:review-loop → 머지 → /dev:post-merge → 빌드한 세션에서 /retro [Matt]
  [dev]  필요할 때 /dev:release
  곁가지: 버그 → /diagnosing-bugs → /retro · PR 없음 → 뒷단 생략
         spec 없이 즉석 병렬 작업 → /dev:orchestrate · 작은 요청인데 모호함 → /docs:interview-methodology
         회의록·리서치 같은 원본이 들어옴 → /wiki:ingest, 그 지식이 궁금함 → /wiki:query
         worktree · non-default base · E2E → 지금과 같음
  ```
- **post-merge 줄이기:**
  - Step 9 의 README 손질은 `docs:readme` 를 가리키는 한 줄로 줄이고, About 불일치 체크(`repo-about:` 한 줄)는 남긴다.
  - Step 9.5 는 `docs:changelog` 를 가리키는 한 줄로 줄인다.
  - Guidelines·References 에서 지운 단계와 관련된 항목을 정리한다.
- **머지 전:** Decision 2 의 Codex 1회 확인.

### PR2. wiki 를 바깥 지식 전용으로 (wiki, dev 일부, 루트 문서)
- **구조:**
  - `raw/` 는 원본을 두고 고치지 않는다.
  - `wiki/index.md` 는 페이지당 한 줄, `wiki/log.md` 는 작업 기록이다.
  - `wiki/<주제>/<개념>.md` 는 여러 raw 를 묶은 개념 페이지이고, `## Sources` 에서 raw 를 인용한다.
  - 개념 페이지가 곧 wiki 페이지라서 concept 전용 폴더는 따로 두지 않는다.
- **스킬:**
  - `wiki:ingest` (구 `ingest-finding`): 원본이나 발견을 받아 개념 페이지를 만들거나 고치고, index·log 를 갱신한다. wiki 가 없으면 뼈대를 만든다 (bootstrap 기능 흡수).
  - `wiki:query` (신규): index → 페이지 → 필요하면 raw 순으로 읽고 인용을 달아 답한다. 새로 정리된 답은 사용자가 승인하면 페이지로 저장한다. 다루는 페이지가 없으면 어떤 원본을 넣어야 하는지 알려 준다.
  - `wiki:lint` (구 `lint-wiki`): 오래된 페이지, 깨진 링크·Sources, 고아 페이지, index 불일치를 찾는다.
  - `wiki:plaud-note-taking` 은 남기고, 넘기는 곳을 `wiki:ingest` 로 바꾼다.
  - `bootstrap-wiki`, `cleanup`, `fleet-scan` 스킬은 지운다. 함께 `scripts/` 5개, `tests/test_cleanup_targets.py`, bootstrap 의 insight-skeleton 도 지운다. 남는 스크립트가 없으면 `tests/resolver_smoke.sh` 도 지운다.
- **지우는 것:**
  - `plugin.json` 의 hooks 블록, `hooks/` 디렉터리 (Decision 19).
  - `insight/` 층과 graduation 단계.
  - `.staging/` 처리.
  - 관계 타입 10종 문법 (See-also·Evidence 는 일반 링크로 남긴다).
  - CLAUDE.md 의 memory overlay 절.
  - `wiki-conventions.md` 에서 필요한 부분은 wiki 쪽으로 옮긴다. 그다음 `plugins/dev/skills/post-merge/references/core-principle.md` 를 지운다.
- **이 repo (Decision 22):**
  - `.llmwiki/wiki` 9페이지를 ADR 3-게이트로 판정한다. 통과하면 Matt `ADR-FORMAT.md` 형식(`docs/adr/NNNN-slug.md`, 1-3문장)으로 옮기고, AGENTS.md 규칙과 같으면 지운다.
  - `insight/review-loop-churn.md` 는 AGENTS.md cr-fix churn 규칙과 내용이 같으니 지운다.
  - `.llmwiki/` (raw·staging 포함)를 지운다. 근거는 git 이력과 ADR 의 출처(PR·커밋)로 남는다.
- **루트 문서:**
  - AGENTS.md 기본 원칙의 lore 줄과 저장소 구조의 `.llmwiki/` 항목을 `docs/adr`·`GLOSSARY.md` 기준으로 고친다. Plugins 표의 wiki 분류명도 고친다.
  - `CLAUDE.md.global:64` 는 "`.llmwiki/wiki/index.md` 가 있으면 바깥 지식 질문 전에 읽는다. 결정은 `docs/adr`, 용어는 `GLOSSARY.md`" 로 바꾼다. 그다음 `cp` 로 `~/.claude/CLAUDE.md`·`~/.codex/AGENTS.md` 를 갱신한다.
  - README 의 wiki 절과 marketplace.json 의 wiki description 을 갱신한다.
- **Codex:** `~/.codex/hooks.json` 에서 wiki 항목 6개를 지운다. 사용자 로컬 파일이므로 README 안내에 적는다.

### PR3. 리뷰 루프 수정 (이름은 아직 cr-fix)
- **최종 결과 대기:**
  - push 뒤에 멈추는 경우(minor_floor, iteration_cap, 반영이 있었던 churn)와 Step 15 직전에는, 기존 상한 안에서 켜져 있는 리뷰어 전원이 HEAD 에 결과를 낼 때까지 기다린다.
  - 새 gated 지적이 오면 상한이 허락하는 한 한 번 더 돈다. 상한에 걸리면 follow-up 이슈로 넘기고 auto-merge 를 끈다.
  - 대상 파일: `references/run-blocks.md:313-329`, `SKILL.md` Steps 13-15.
- **Codex 결과 판정:**
  - `<!-- codex-pull-request-review-summary -->` 댓글(Running/Completed/Failed + short SHA)과 `commit_id == HEAD` 인 리뷰로 판정한다.
  - 파싱에 실패하면 review-id 폴링으로 돌아가고, clean 으로 치지 않는다.
  - 모든 gate 에서 Codex 대기 시간은 `max(CODEX_GRACE, CODEX_PREFLIGHT_TIMEOUT - push_age)` 다.
  - 대상 파일: `probe-codex-state.sh`, `poll-codex-grace.sh`, `pre-flight.sh`, `codex-state-machine.md`.
- **Codex Failed:** Decision 16. `final_state` enum, `assets/final-output.schema.json`, `auto-merge-gate.sh` 에 반영한다.
- **CodeRabbit:**
  - success status 의 description 이 rate limited 면 `rate_limited` 로 분류한다 (`poll-cr-status.sh:88-91`).
  - engagement-gate 는 rate-limit 공지 편집을 리뷰 활동으로 세지 않는다.
  - CodeRabbit 의 결과는 success status 가 아니라 HEAD 에 대한 리뷰로 판정한다.
- **push 전 검증:**
  - Step 11 빌드·테스트를 커밋 전에 돌린다. 실패하면 그 수정을 되돌리고 defer(`verification-failed`)로 기록한 뒤, 통과한 코드만 push 한다.
  - 시작할 때 기준선(baseline)을 한 번 돌린다. 처음부터 실패하는 repo(GPU·데이터가 필요한 테스트 등)는 이 규칙에서 빼고 그 사실을 기록한다.
- **auto-merge:** Decision 14. `auto-merge-gate.sh` 가 Codex 결과도 확인한다.
- **P2:** Decision 15. 두 번째 iteration 부터 나오는 Codex P2 는 defer 로 기록하고 follow-up 이슈로 넘긴다.
- **작은 수정:**
  - badge regex 를 `[0-3]` 로, P0 를 gated 최상위로, `line // original_line` 사용.
  - clean 판정에 `review_this_cycle == 0` 조건 추가.
  - Codex 댓글을 가져오다 gh 에러가 나면 `[]` 로 넘기지 않는다.
  - draft PR 이면 `gh pr ready` 를 안내하고 멈춘다.
  - 지워진 wiki 페이지를 가리키는 스크립트 주석 4곳을 PR2 에서 만든 ADR 경로로 바꾼다 (`auto-merge-gate.sh:51-52`, `cr-commit-state.sh:38`, `fetch-cr-threads.sh:48`, `query-cr-rate-limit.sh:23`).
- **문서:** AGENTS.md "CodeRabbit / Codex 조율" 절에 auto-merge·P2·codex_failed 를 반영한다. "per-issue 확인" 문구는 실제 동작에 맞춘다. 같은 내용을 `plugins/dev/CLAUDE.md` 에도 반영한다.
- **테스트:** `tests/run-tests.sh` 에 fixture 를 추가한다: summary 댓글 수정 이력, rate-limit success status, P0 배지, gh 에러, 처음부터 실패하는 baseline.
- **하지 않는 것:** `auto-merge-gate.sh` 의 errexit 수정. 검증에서 반박됐다 (`gh pr checks --json` 은 pending·failed 에도 exit 0).

### PR4. 이름 변경 cr-fix → review-loop
- **스킬:**
  - `git mv plugins/dev/skills/cr-fix plugins/dev/skills/review-loop` 로 옮기고 frontmatter `name` 을 바꾼다.
  - description 에는 옛 이름 "cr-fix" 와 기존 한국어 트리거를 남긴다.
- **state 파일:** 새 접두사는 `review-loop-<PR>` 이다. post-merge Step 1.5 와 worktree 복사(Step 1)는 `review-loop-` 과 옛 `cr-fix-` 를 둘 다 읽는다.
- **참조 갱신 (현재 쓰이는 파일):**
  - `AGENTS.md` (조율 절, 검증 체인), `README.md`
  - `plugins/dev/CLAUDE.md`, `plugins/dev/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
  - `.githooks/pre-commit`, `.github/workflows/validate-codex.yml`, `scripts/check-shell-portability.mjs`
  - `.coderabbit.yaml`, `.claude/rules/state-envelope.md`
  - dev 의 스킬·assets·docs·references, scout, write-rules 템플릿, `docs/adr`
- **바꾸지 않는 것:** 과거 기록 문서 (docs/audit, docs/prd, docs/superpowers, .claude/spec).

### 제품 repo 마다 (사용자, 필요할 때)
- `/setup-matt-pocock-skills` 를 한 번 실행한다. 블록이 CLAUDE.md 에만 쓰였으면 AGENTS.md 에도 복사한다 (Codex 용).
- `/retro` 가 `CODING_STANDARDS.md` 를 만들면, 봇도 읽도록 `.coderabbit.yaml` 의 `knowledge_base.code_guidelines.filePatterns` 에 등록하고 AGENTS.md `## Code Review Rules` 에서 그 파일을 가리킨다. 이 파일은 Matt code-review 외에는 읽지 않는다.
- `.llmwiki/insight/` 가 있는 repo (thezero, jaywalk, forensic, kankord, cc-lesson-deck, local-ai-course, xion, langgraph) 는 그 규칙을 AGENTS.md 나 자동 검사로 옮긴다. PR2 이후에는 전역 지침이 insight 를 읽지 않는다.
- 쌓인 `.llmwiki/.staging/` 을 지운다 (forensic-video-search 110건, cc-lesson-deck 27건 등).

## Verification

- **매 PR:** AGENTS.md `## 검증` 체인이 `verify: ok` 로 끝난다. PR4 이후 체인의 테스트 경로는 `plugins/dev/skills/review-loop/tests/run-tests.sh` 다.
- **PR1:**
  - Plan 의 `rg` 결과가 과거 기록 문서 밖에서 0건이다.
  - 임시 `CODEX_HOME` 카탈로그 레시피(8 entries)가 통과한다.
  - Codex 에서 Matt 체인을 한 번 돌려 확인했다.
- **PR2:**
  - `jq .hooks plugins/wiki/.claude-plugin/plugin.json` 이 `null` 이다.
  - `rg -n 'insight|staging|fleet-scan|bootstrap-wiki' plugins/wiki` 에서 현재 쓰이는 참조가 0건이다.
  - 새 세션 시작 메시지에 `[wiki-` 로 시작하는 줄이 없다.
  - 제품 repo 한 곳에서 `/wiki:query` 가 인용을 단 답을 낸다.
  - 이 repo 에 `.llmwiki/` 가 없고 `docs/adr/` 가 있다.
  - 전역 지침 사본 두 개가 정본과 같다.
- **PR3:**
  - 새 fixture 테스트가 통과한다.
  - 실제 PR 1건에서 확인한다: 마지막 push 뒤 Codex 결과(Completed/Failed)가 HEAD 에 붙기 전에는 루프가 끝나지 않는다. 빌드가 실패하면 push 가 없다.
- **PR4:**
  - `rg -n 'cr-fix' --glob '!docs/audit/**' --glob '!docs/prd/**' --glob '!docs/superpowers/**' --glob '!.claude/spec/**'` 결과에 description 의 옛 이름과 post-merge 호환 접두사만 남는다.
  - 옛 `cr-fix-<PR>.json` 만 있는 repo 에서 post-merge Step 1.5 가 남은 리뷰를 찾는다.

## Out of scope

- 리뷰 루프 2단계 (`loop-state`·`codex-state` CLI, `codex_pr.py` 방식). PR3 뒤 PR 3-5개를 돌려 보고 판단한다.
- 티켓마다 `/implement` 한 뒤 PR 을 여는 dev 스텝. 필요해지면 추가한다.
- Matt 스킬 이름 변경을 감지하는 가드. auto-update 로 이름이 바뀌면 dev:flow 를 손으로 고친다.
- Codex 가 marketplace 를 자동으로 갱신하는지 확인하는 일.
- 쌓인 staging 내용 정리. 지우기만 한다.
- 제품 repo 에 이미 있는 wiki 페이지를 ADR·GLOSSARY 로 옮기는 일.

## Sources

- Workflow `wf_1d3eb1d0-7c1` 결과 (이 세션): 27쌍 매트릭스, 반박 검증 3개, cr-fix 판정과 그에 대한 반박 1개
- mattpocock/skills 1.3.1 (4588b32): `ask-matt` (+`PHASE-BOUNDARIES.md`), `grill-with-docs`, `to-spec`, `to-tickets`, `implement`, `implement-spec`, `tdd`, `code-review`, `pr`, `diagnosing-bugs`, `retro`, `domain-modeling` (+`ADR-FORMAT.md`), `setup-matt-pocock-skills`; `docs/engineering/grill-with-docs.md:49`, `docs/engineering/implement-spec.md:54`
- cr-fix: `references/run-blocks.md:321`, `SKILL.md:243`, `references/arguments.md:13`, `scripts/poll-cr-status.sh:88-91`
- PR #223, #254, #269 의 리뷰 타이밍. 클래스 repo `brief.md:81`, `codex-pr-review` (commit 0522dd9)
- wiki 측정 (이 세션): transcript 스캔 (질문용으로만 읽은 세션 26 / 유지보수 세션 33), 12개 repo 의 페이지·staging 개수, 관계 타입 집계, `plugins/wiki` 3,265줄, `~/.codex/hooks.json` (`wiki/1.0.0` 경로)
- Claude Code docs: discover-plugins (marketplace `#ref`, auto-update 기본값), skills (`Skill(name)` 권한 문법). Codex docs: plugin marketplace (`--ref`, `upgrade`)
- `.claude/spec/2026-09-18-pocock-borrow.md` (Non-goal 번복)
