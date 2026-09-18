# Spec: pocock-borrow

Date: 2026-09-18
Status: draft
Owner: YoungjaeDev

## Context

`mattpocock/skills` (commit 74ca5fe, 38개 스킬)와 이 저장소 7개 플러그인(38개 스킬)을 비교했다. 조사는 Workflow `wf_b12a5c87-32f` (에이전트 7개, 비평 1회)로 했고, 근거는 각 항목의 file:line 이다.

- **공백:**
  - 버그 진단 스킬이 없다.
  - merge conflict 처리가 없다.
  - 테스트 seam 을 미리 합의하는 단계가 없다.
  - 수직 슬라이스 이슈 규칙이 없다.
  - dev 흐름 전체를 안내하는 문서가 없다.
- **운영 문제:**
  - `dev:orchestrate` 의 haiku 프리셋을 쓰지 않기로 했다.
  - `dev:post-merge` 는 worktree 안에서 실패한다. 임시 저장소 실험에서 base checkout 과 branch 삭제가 실패했다.
  - CodeRabbit 은 base 가 default branch 가 아닌 PR 을 자동 리뷰하지 않는다 (https://docs.coderabbit.ai/configuration/auto-review).
- **비용 제약:** 이슈 하나가 PR 하나가 되고, PR 하나는 CodeRabbit·Codex 리뷰 사이클을 하나 이상 쓴다. 리뷰 쿼터가 한정돼 있으므로 이슈를 잘게 쪼개지 않는다.

## Goal

아래 Plan 의 이슈 8개가 머지되면 다음이 성립한다.
- dev 워커 프리셋이 standard/deep/max 3개다.
- post-merge 가 worktree 안에서 끝까지 돈다.
- cr-fix 가 non-default base PR, merge conflict, 리뷰어 쿼터 소진을 처리한다.
- decompose-issue 가 수직 슬라이스 이슈를 만든다.
- resolve-issue 가 seam 을 합의한 뒤 테스트를 쓴다.
- `dev:diagnose` 와 dev 흐름 라우터가 있다.
- 부작용 있는 스킬은 Codex 에서 자동 호출되지 않는다.
- 긴 SKILL.md 가 references/ 로 분리돼 있다.

## Non-goals

- CONTEXT.md 용어집과 ADR 스킬: `.llmwiki` 와 역할이 겹친다.
- prototype, retro, 구조 개선(improve-codebase-architecture), git guardrail 설치, triage 스킬.
- 스킬 목록 예산 조정: 사용자 전역 settings 의 일이라 저장소 변경이 아니다.
- council 좌석 모델 목록의 haiku: council 이 받을 수 있는 모델 이름 목록일 뿐이고, 워커 프리셋이 아니다.

## Decisions

| # | Question | Choice | Rationale |
|---|----------|--------|-----------|
| 1 | worker-fast 처리 | 삭제, standard 가 흡수 | 사용자가 haiku 를 쓰지 않기로 함 |
| 2 | haiku 직접 호출 4곳 | sonnet 으로 교체 | "대부분 소넷으로 이전" (`commit-and-push:83`, `resolve-issue:168,174,334`) |
| 3 | orchestrate 의 Workflow 전환 | Agent 루프 유지, Workflow 기준만 좁힘 | 거절·재질의 루프가 대화형이고 Codex 에 Workflow 가 없다. `/dev:orchestrate` 호출은 Workflow 도구 규칙상 opt-in 으로 인정되므로 유지 |
| 4 | post-merge in worktree | main 저장소 경로로 작업, worktree 제거와 branch 삭제만 마지막 한 줄로 넘김 | Windows 에서 cwd 안의 worktree 는 자기 제거가 반쯤만 된다 (실험). 먼저 `/exit` 하면 cr-fix state 가 사라진다 |
| 5 | non-default base | push 마다 `@coderabbitai review`, 리뷰 부재를 수렴으로 보지 않음 | 수동 명령은 설정과 무관하게 동작 (공식 문서). cr-fix `:24` 의 댓글 금지 규칙에 예외로 명시 |
| 6 | `base_branches: [".*"]` 추가 | 이 저장소 `.coderabbit.yaml` 에 추가. cr-fix 의 수동 요청 지침은 설정 없는 저장소용 폴백으로 유지 | `base_branches` 는 default branch 에 대상을 더할 뿐이라 main 향 PR 리뷰 수는 그대로다. 늘어나는 것은 non-default base PR 뿐이고, 그 PR 은 어차피 수동 요청으로 리뷰하므로 쿼터 차이가 거의 없다 |
| 7 | 이슈 분할 기준 | 기능별 수직 슬라이스. 파일 소유가 겹치지 않는 선에서 나누고, 잘게 쪼개지 않음. 최소 개수로 편향하지 않음 | 리뷰 쿼터와 orchestrate 의 disjoint 소유 원칙 |
| 8 | 이슈 본문의 파일별 변경·스니펫 (`decompose-issue:178-184`) | 파일 경로는 "시작점 힌트"로만, 스니펫은 뺀다 | 본문 중심을 사용자 관점 완료 조건과 테스트 seam 으로 옮김 |
| 9 | 자동 호출 차단 | `agents/openai.yaml` `policy.allow_implicit_invocation: false` | `disable-model-invocation` 은 Codex validator 가 거부 (`validate_plugin.py:469-475`). Claude 쪽은 description 의 "ONLY when explicitly" 문구 유지 |
| 10 | PR 구성 | 이슈별 PR, 아래 순서 | 사용자가 여러 PR 허용 |
| 11 | CodeRabbit 지침 전달 | 고정 지침은 파일로, PR 별 맥락은 PR 본문과 `Closes #N` 으로 | CodeRabbit 은 `**/AGENTS.md`, `**/CLAUDE.md` 를 디렉터리 범위로 자동 적용한다. `.claude/rules/*.md` 와 `code_review.md` 는 기본 패턴 밖이라 `knowledge_base.code_guidelines.filePatterns` 로 등록한다 (https://docs.coderabbit.ai/knowledge-base/code-guidelines). PR 마다 설정을 바꾸는 방식은 쓰지 않는다 |
| 12 | 라벨이 없을 때 | decompose-issue 가 이슈 생성 직전에 `gh label list` 로 확인하고, 없으면 같은 스킬의 Labels 섹션을 실행 | 규칙(`:230-234`)은 있으나 번호 매긴 실행 단계(`:20-34`)에 없어 건너뛰어질 수 있다 |
| 13 | 사용자 결정의 시점 | decompose-issue 에서 최대한 앞당겨 확정하고 이슈 본문에 기록 | 서브에이전트는 `AskUserQuestion` 을 쓸 수 없다. 이슈 생성 시점(메인 세션)에 묻는 것이 한 번의 대화로 끝나고, 이후 resolve-issue 는 비대화형으로 돈다 |
| 14 | E2E 도입 시점 | 기본은 로컬 단위·기능 테스트. 이슈에 핵심 사용자 흐름이 있을 때만 decompose-issue 가 E2E 여부를 묻고, 승인되면 `dev:e2e-setup`(CI 포함)과 `dev:e2e-author` 로 이어간다 | 사용자 지정. 큰 병목이 없으면 로컬 테스트로 충분하다 |
| 15 | Playwright 구동 방식 | planner·generator 탐색은 `playwright-cli`, healer 는 `playwright-test` MCP 유지 | `microsoft/playwright-cli` README: 코딩 에이전트에는 CLI 가 토큰 효율적이고, MCP 는 self-healing 같은 장시간 루프에 맞다. CLI 는 v0.1.20 (2026-09-14) 으로 0.x |
| 16 | CLI 우선, 정량 평가는 스크립트 | 전역 지침(`CLAUDE.md.global`)에 두 줄 추가 | 사용자 지정. 모든 프로젝트와 두 런타임에 적용 |
| 17 | 리뷰어 사용 불가 조기 감지 | cr-fix 가 iter 1 대기 전에 PR 댓글에서 리뷰어의 "리뷰 안 함" 신호를 찾는다. 두 리뷰어 모두 불가면 대기 없이 `final_state=reviewers_unavailable` 로 멈추고, 이 상태는 수렴이 아니므로 auto-merge 대상이 아니다. `auto_review.enabled: false` 인 저장소에서는 `@coderabbitai review` 를 자동으로 남기지 않는다 (Decision 5 보다 우선) | 2026-09-18 PR #237 에서 두 신호가 PR 생성 2초 안에 댓글로 달렸다. 지금 cr-fix 는 이 신호를 모르고 grace·poll 예산을 다 쓴 뒤 timeout 으로 끝난다. 자동 리뷰를 끈 이유가 쿼터 절약이라 자동 요청은 그 의도를 거스른다 |

## Plan

이슈 8개로 나눈다 (번호는 식별자이고 실행 순서는 Blocked by 를 따른다). 같은 파일을 만지는 이슈는 앞 이슈가 머지된 뒤 시작한다 (Blocked by). dev 버전은 PR 마다 범프한다.

### I1. orchestrate: haiku 제거와 Workflow 기준 (dev 3.0.0, MAJOR)
- `plugins/dev/agents/worker-fast.md` 를 삭제하고, `plugin.json:22` 의 agents 항목을 뺀다.
- `orchestrate/SKILL.md` 수정:
  - `:42` fast 행을 삭제한다.
  - `:43` standard 의 Pick when 에 lookup, listing, grep, mechanical rename 을 흡수한다.
  - `:47` 문구를 "toward standard" 로 바꾼다.
- `orchestrate/SKILL.md` 의 Workflow 기준(`:60,64,134`)을 좁힌다. Workflow 는 "단계가 많고 중간에 사용자 판단이 없는 파이프라인이거나 resume 이 필요한 경우"에만 쓰고, 사용자 질문이 필요한 slice 가 나오면 Agent 루프로 복귀한다.
- haiku 직접 호출 4곳을 sonnet 으로 바꾼다. `dev/CLAUDE.md:17,121` 도 함께 고친다.
- 문서 동기화: `README.md:104,141`, `.llmwiki/wiki/runtimes/agent-definition-effort.md:16`, `marketplace.json` (dev 3.0.0, metadata MINOR).

### I2. post-merge worktree 지원 + CodeRabbit non-default base + merge conflict (dev MINOR). Blocked by I1
- **post-merge:**
  - 가드(`:33-44`)는 abort 대신 다음을 기록한다: `MAIN_REPO=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")`, `WT_PATH`, `IN_WT=1`.
  - Step 1 직후 worktree 의 `.claude/state/cr-fix-<PR>*.json` 을 `$MAIN_REPO/.claude/state/archive/` 로 복사한다.
  - Step 2-10 의 git 호출은 `git -C "$MAIN_REPO"` 로, 파일 경로는 `$MAIN_REPO/` 절대경로로 바꾼다.
  - Step 4 는 `IN_WT=1` 이면 branch 삭제를 미룬다.
  - 새 Step 11 은 `cd "<MAIN_REPO>" && git worktree remove "<WT_PATH>" && git branch -d "<branch>"` 를 출력만 한다.
  - `:11` 의 "`/exit` cleanup 먼저" 안내를 삭제한다.
- **cr-fix non-default base:**
  - `:96` 직후에 BASE 와 `defaultBranchRef` 를 비교하고, `base_branches` 와도 매치되지 않으면 push 마다 `@coderabbitai review` 를 남긴다. 단, `auto_review.enabled: false` 면 남기지 않는다 (Decision 17).
  - `:24` 에 이 경우를 예외로 적는다.
  - resolve-issue 와 post-merge Guidelines 에는 한 줄 포인터만 둔다.
- **`.coderabbit.yaml` (루트 파일, 버전 범프 없음):**
  - `reviews.auto_review.base_branches: [".*"]` 를 추가한다 (Decision 6).
  - `knowledge_base.code_guidelines.filePatterns` 에 `files`/`applyTo` 쌍을 추가한다 (Decision 11):
    - `.claude/rules/plugin-versioning.md` → 매니페스트 경로
    - `.claude/rules/state-envelope.md` → `.claude/state/**`
    - `code_review.md` → `**`
  - 지침 파일 이름을 `path_instructions` 에 넣지 않는다. 넣으면 지침이 아니라 리뷰 대상이 된다.
- **리뷰어 사용 불가 조기 감지 (Decision 17):**
  - 감지할 신호 (2026-09-18 PR #237 실측):
    - Codex: `chatgpt-codex-connector[bot]` 의 issue comment 본문 "You have reached your Codex usage limits for code reviews".
    - CodeRabbit: `coderabbitai[bot]` 의 issue comment 에 `auto-generated comment: skip review by coderabbit.ai` 마커와 "Auto reviews are disabled on this repository".
  - 작성자 매칭은 양끝 고정 (`^chatgpt-codex-connector(\[bot\])?$`, `^coderabbitai(\[bot\])?$`). AGENTS.md P1 봇 신원 규칙.
  - 한쪽만 불가면 그 리뷰어를 이번 run 에서 끄고(Codex grace 대기 생략, CR poll 생략) 나머지로 진행한다. 둘 다 불가면 `final_state=reviewers_unavailable` 로 즉시 멈추고 각 신호의 댓글 URL 을 보고한다.
  - 판정은 번들 스크립트로 두고 `tests/run-tests.sh` 에 위 두 본문을 fixture 로 넣는다 (둘 다 불가, 한쪽만, 사칭 로그인 `coderabbitai-evil`).
  - `final_state` enum(`references/failure-modes.md`)과 `assets/final-output.schema.json` 에 새 값을 추가하고, `auto-merge-gate.sh` 에서 ineligible 로 둔다.
- **merge conflict:**
  - cr-fix pre-flight 에서 `gh pr view --json mergeable` 이 `CONFLICTING` 이면 base 를 merge 하고 hunk 단위로 해결한다.
  - 해결 기준은 양쪽 원래 의도다. `--abort` 는 쓰지 않는다. 해결 후 체크를 재실행한다.
  - 절차는 `cr-fix/references/merge-conflicts.md` 로 둔다. 출처: Matt `resolving-merge-conflicts/SKILL.md`.

### I3. 기획·TDD: 수직 슬라이스, 이슈 분할, seam (dev MINOR, docs PATCH). Blocked by I2
- **decompose-issue:**
  - Issue Sizing(`:160-186`)에 비용 모델(이슈 = PR = 리뷰 사이클)과 Decision 7 의 분할 기준을 적는다.
  - Content Depth(`:178-184`)를 Decision 8 로 바꾼다.
  - 템플릿 완료 조건(`:268-272`)은 사용자 관점 acceptance criteria 로 바꾼다.
  - TDD 판정 단계(`:22-27`) 옆에 E2E 판정을 추가한다 (Decision 14). 핵심 사용자 흐름이 있는 이슈에만 묻고, 승인되면 이슈 본문에 E2E 대상 흐름과 `dev:e2e-author` 포인터를 적는다. E2E 하네스가 없는 저장소면 `dev:e2e-setup` 을 선행 이슈로 둔다.
  - 실행 단계(`:20-34`)에 라벨 확인 단계를 추가한다: 이슈 생성 직전 `gh label list` 로 type/area 라벨을 확인하고, 없으면 Labels 섹션을 실행한다 (Decision 12).
  - 참조: Matt `to-tickets/SKILL.md:25-40,84-105`.
- **resolve-issue:**
  - TDD 분기(`:120-127`)에 seam 확정 단계를 넣는다. 확정 순서:
    1. 이슈 본문의 합의된 seam 을 쓴다.
    2. 없고 `AskUserQuestion` 이 있으면 사용자에게 묻는다.
    3. 둘 다 안 되면(서브에이전트 실행) 테스트를 쓰지 않고 seam 제안을 결과로 반환한 뒤 멈춘다.
  - 근거: 서브에이전트에서는 `AskUserQuestion` 이 제거된다 (https://code.claude.com/docs/en/sub-agents, Available tools).
  - decompose-issue 이슈 템플릿에 "테스트 seam" 항목을 추가한다. 합의는 메인 세션에서 이슈를 만들 때 한다.
  - decompose-issue 는 이슈를 만들기 전에 구현 중 사용자에게 물을 결정을 최대한 앞당겨 확정한다 (Decision 13): 테스트 seam, 선택지가 갈리는 설계 결정, 범위 경계. 확정한 내용은 이슈 본문의 "결정 사항" 항목에 적고, 남은 미결정은 "Open questions" 로 명시한다. 목적은 resolve-issue 가 워커에서도 묻지 않고 끝까지 돌게 하는 것이다.
  - orchestrate 의 job card 규칙에 한 줄 추가: seam 이 필요한 슬라이스는 dispatch 전에 합의해서 Inputs 에 넣는다. orchestrate 파일은 I1 이 만지므로 I3 에서 이어서 수정한다.
  - "four built-in rules" 와 실제 5개 항목의 불일치를 고친다.
  - Step 8(`:150-157`)의 사후 커버리지 80% 목표를 "합의된 seam 에서의 행동 검증"으로 바꾼다.
  - 참조: Matt `tdd/SKILL.md:18-38`.
- **interview-methodology (docs):** spec 템플릿(`:276-316`)에 Testing Decisions 섹션(seam, 테스트 대상 동작, 제외 대상)을 추가한다.

### I4. 새 스킬 `dev:diagnose` (dev MINOR). Blocked by I1
- 출처는 Matt `diagnosing-bugs/SKILL.md`(138줄)이고, 영어로 쓴다.
- 절차:
  1. 이 버그에서 실패하는 명령 하나를 먼저 확보한다.
  2. 재현을 최소화한다.
  3. 반증 가능한 가설 3-5개를 순위화한다.
  4. 태그 달린 계측을 넣는다.
  5. seam 에 회귀 테스트를 건다.
  6. 정리 체크리스트를 돈다.
- `e2e-debug` 의 가설 단계(`:68`)와 resolve-issue 의 bug 분기에서 이 스킬을 가리킨다.
- `plugin.json` skills 와 description, README 에 등록한다.
- 번들 스크립트가 생기면 PLUGIN_ROOT resolver 를 쓴다.

### I5. dev 흐름 라우터 + Codex 자동 호출 차단 (dev MINOR, docs·wiki PATCH). Blocked by I3, I4
- **라우터 스킬:**
  - 새 스킬(이름은 구현 시 결정, 예: `dev:flow`). 형식은 Matt `ask-matt` 의 짧은 라우터다.
  - 담을 흐름: decompose-issue → resolve-issue(→ diagnose) → cr-fix → post-merge.
  - 담을 분기: worktree, non-default base, orchestrate 로 넘기는 기준.
- **Codex 자동 호출 차단:**
  - 부작용 있는 스킬에 `agents/openai.yaml` 을 두고 `policy.allow_implicit_invocation: false` 로 설정한다.
  - 1차 대상: `dev:release`, `dev:new`, `dev:decompose-issue`, `dev:resolve-issue`, `dev:post-merge`, `dev:commit-and-push`, `docs:gws-sync`. 최종 목록은 구현 시 확정한다.
- **먼저 확인할 것:** Codex 가 플러그인 안의 `skills/<name>/agents/openai.yaml` 을 읽는지 일회용 `CODEX_HOME` 에서 확인한다. 읽지 않으면 이 부분은 빼고 이슈에 기록한다.
- `AGENTS.md` 의 Codex 통합 절에 규칙 한 줄을 추가한다.

### I7. E2E 스킬: playwright-cli 전환과 호출 경로 (dev MINOR). Blocked by I3
- 현황: 세 스킬 모두 이 PC 세션 기록에서 호출 0회다. 다른 dev 스킬이 가리키지 않는다 (`git grep` 0건). description 에 한국어 트리거가 없다.
- planner·generator 역할의 앱 탐색을 `playwright-cli` 로 바꾼다 (`references/role-contracts.md:62,67`, `e2e-author`). healer(`:82`)는 MCP 를 유지한다 (Decision 15).
- `e2e-setup` 에 `playwright-cli` 설치 확인을 넣는다. 전역 설치(`npm install -g`)를 강제하지 않는다. `npx` 사용 가능 여부는 구현 시 확인한다.
- 세 스킬 description 에 한국어 트리거를 추가한다 (예: "E2E 테스트", "플레이라이트", "E2E 깨졌어").
- I5 라우터에 E2E 분기(처음 한 번 setup, 기능별 author, CI 실패 시 debug)를 넣는다. I5 가 먼저 머지되면 여기서 추가한다.

### I8. 전역 지침: CLI 우선과 스크립트 기반 정량 평가 (루트 파일, 버전 범프 없음)
- `CLAUDE.md.global` 에 두 줄을 추가한다 (Decision 16). 위치와 문구는 구현 시 기존 절에 맞춘다.
  - 같은 일을 하는 CLI 와 MCP 가 있으면 CLI 를 쓴다. 이유는 도구 스키마와 긴 출력이 컨텍스트에 실리지 않기 때문이다.
  - 정량 평가는 도메인에 맞는 작은 스크립트를 쓰고 명령으로 돌려서 판정한다. 모델이 눈으로 세거나 비교하지 않는다.
- 설치 사본을 동기화한다: `cp CLAUDE.md.global ~/.claude/CLAUDE.md`, Codex 사본.
  - 2026-09-18 확인 결과 `~/.claude/CLAUDE.md` 는 정본보다 오래됐다. 6절이 없고 옛 이름 `github-dev` 가 남아 있다.
  - `~/.codex/AGENTS.md` 와 `$CODEX_HOME/AGENTS.md`(orca 런타임 홈)는 둘 다 0바이트다 (2026-08-04 이후).
  - Codex 가 실제로 읽는 경로가 어느 쪽인지 확인한 뒤 복사한다.

### I6. 긴 SKILL.md 분리. Blocked by I1-I5, I7 (같은 파일을 만짐)
- 대상은 300줄 이상 스킬이다. 줄 수는 2026-09-18 기준이다.
  - `council:convene` 637줄
  - `dev:cr-fix` 573줄
  - `docs:write-rules` 403줄
  - `dev:resolve-issue` 401줄
  - `docs:interview-methodology` 327줄
  - `wiki:lint-wiki` 305줄
- 본문에는 판단 규칙과 흐름만 남기고, 세부 절차·표·예시는 `references/` 로 옮긴다. 의미는 바꾸지 않는다.
- PR 은 플러그인 단위(dev, docs, council, wiki)로 나눌 수 있다. 분할 여부는 I6 착수 시 decompose-issue 기준으로 정한다.

## Verification

- 매 PR: AGENTS.md `## 검증` 체인이 `verify: ok` 로 끝난다.
- **I1:**
  - `git grep -n -i 'worker-fast\|model="haiku"'` 결과가 이력 문서만 남긴다.
  - Codex 카탈로그 7 entries 레시피가 통과한다.
- **I2:**
  - scratchpad 임시 저장소에서 worktree 를 만들고 그 안에서 post-merge 의 git 단계를 재현한다. base 전환 오류가 사라지고, Step 11 한 줄로 worktree 와 branch 가 제거돼야 한다.
  - cr-fix 테스트(`plugins/dev/skills/cr-fix/tests/run-tests.sh`)에 non-default base 판정 케이스와 리뷰어 사용 불가 fixture 케이스를 추가한다.
- **I3:** decompose-issue 를 샘플 기능 설명에 dry-run 한다. 수직 슬라이스 이슈가 나오고, 스니펫이 없어야 한다.
- **I4:** 이 저장소의 과거 버그 1건으로 `dev:diagnose` 절차를 따라간다. 실패하는 명령을 먼저 확보하는지 본다.
- **I5:** 일회용 `CODEX_HOME` 에서 `allow_implicit_invocation` 이 적용되는지 확인한다.
- **I6:** 분리 전후 스킬별로 규칙 집합을 대조한다 (삭제된 규칙 0).

## Out of scope

- CONTEXT.md/ADR, prototype, retro, 구조 개선, git guardrail, triage (Non-goals 참조).
- `session-handoff` 의 파일형 전환: worktree 인계는 I2 의 한 줄 출력으로 대신한다.
- 스킬 목록 예산: `skillListingBudgetFraction`, `skillOverrides`, `skillListingMaxDescChars` 로 사용자 설정에서 조정한다 (https://code.claude.com/docs/en/skills).

## Sources

- Workflow `wf_b12a5c87-32f` 리포트 6건과 비평 1건 (이 세션)
- mattpocock/skills 74ca5fe: `ask-matt`, `tdd`, `to-tickets`, `to-spec`, `diagnosing-bugs`, `resolving-merge-conflicts`
- https://docs.coderabbit.ai/configuration/auto-review, https://docs.coderabbit.ai/reference/configuration
- https://code.claude.com/docs/en/sub-agents, https://code.claude.com/docs/en/skills
- https://developers.openai.com/codex/skills (`allow_implicit_invocation`)
