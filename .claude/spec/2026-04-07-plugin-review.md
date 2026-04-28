# 플러그인 검토 리포트 — 2026-04-07

**범위**: 사용자가 자주 쓰는 7개 플러그인(`github-dev`, `core-config`, `code-scout`, `ml-toolkit`, `interactive-review`, `council`, `omc`) + 두 가지 구체 질문 심층 분석

**방법**: 3개 sub-agent 병렬 실행(claude-code-guide 1개 + Explore 2개) → 각 핵심 주장(critical claim) 직접 검증 후 합성

**상태**: 검토 의견만 제공. 코드 변경 없음. 모든 패치는 후속 `ralph` 세션을 위한 제안 형태로 정리

---

## Executive Summary

| # | 주제 | 심각도 | 조치 |
|---|------|--------|------|
| Q1 | post-merge에서 bypassPermissions가 풀리는 듯한 현상 | P1 (UX) | 원인이 두 가지로 분리됨 — Cause B(slash command 자체)만 수정, Cause A(Anthropic 보호 경로)는 사양으로 수용 |
| Q2 | resolve-issue에 PR 생성 전 codex review 통합 | P1 (개선) | 9.7 단계로 삽입. **Agent B가 제안한 패치에 schema-level 치명적 오류**가 있어 교정함 |
| A1 | core-config: 4개 hook이 시스템 `python3` 직접 호출 | P0 | `uv run` 마이그레이션 (work-guidelines 위반) |
| A2 | core-config: CLAUDE.md가 `.sh`를 언급하나 실제는 `.py` | P1 | 문서 정정 |
| A3 | settings.json 활성화 17개 vs 디스크 20개 plugin.json 불일치 | P0 | 활성화 또는 삭제 결정 |
| A4 | github-dev marketplace description이 너무 빈약 | P1 | worktree 학습 통합 등을 명시하도록 확장 |
| A5 | code-scout: `huggingface_hub` 설치 안내 누락 | P1 | `uv add huggingface_hub` 가이드 추가 |

---

## Q1 — `/post-merge`와 bypassPermissions: 원인이 한 개가 아니라 두 개입니다

사용자 질문: *"왜 post-merge 할 때 claude.md나 rules 파일 변경할 때 bypass permissions 모드가 풀리는지 모르겠어. 왜 계속 확인 받는지 말이야."*

기존 멘탈 모델은 단일 원인(Claude Code 권한 시스템 결함)을 가정합니다. 하지만 **실제로는 서로 독립된 두 가지 출처에서 confirmation 프롬프트가 발생**하고 있습니다. 이걸 분리해서 봐야 올바르게 고칠 수 있습니다.

### Cause A — Anthropic이 하드코딩한 보호 경로 (protected paths)

출처: Claude Code 공식 권한 모드 문서 — https://code.claude.com/docs/en/permission-modes.md

> Writes to a small set of paths are never auto-approved, in every mode. Protected directories include `.claude`, **except for** `.claude/commands`, `.claude/agents`, `.claude/skills`, and `.claude/worktrees`.

**의미**: `.claude/rules/*.md`는 예외 목록에 포함되지 않으므로, `bypassPermissions` 모드에서도 Edit/Write 시 **항상** 사용자 확인을 요구합니다. 이는 악의적 PR body가 워크스페이스 설정을 조용히 변경하는 prompt-injection 공격을 막기 위한 의도적 안전 장치입니다.

**해당 위치**:
- `plugins/github-dev/commands/post-merge.md:114` — `.claude/rules/*.md - Modular rule files`
- `plugins/github-dev/commands/post-merge.md:127` — 모듈별 rule 파일 매핑 테이블

**검증 결과**:
- `.claude/settings.json`에 `permissions` 블록 없음 → 프로젝트 레벨 `ask` 룰 때문이 아님 (확인됨)
- `core-config`의 PostToolUse hook(`auto-format-python.py:22`)은 `.py` 파일만 매칭함 → `.md` 작성을 가로채지 않음 (배제됨)
- 설치된 플러그인 어디에도 `.claude/rules/*`를 매칭하는 PreToolUse hook 없음 (배제됨)

### Cause B — 슬래시 커맨드 본문이 직접 사용자 확인을 요구함

이 부분이 놓치기 쉽습니다. `post-merge.md`는 본문 안에 의도적인 human-in-the-loop 문장을 박아 두었습니다. Claude는 그 문장을 충실히 따르므로, 권한 모드와 무관하게 계속 사용자에게 묻습니다.

| 줄 | 인용 | 효과 |
|----|------|------|
| `:148` | "**Always confirm with user before creating new rule files**" | Step 6에서 새 `.claude/rules/<module>.md` 생성 시 항상 확인 |
| `:150` | "Present the integration proposal to user as a diff-style summary **before applying**" | CLAUDE.md / AGENTS.md / GEMINI.md / rules 편집 전에 항상 확인 |
| `:234` | "If any configuration files were modified, **prompt user to confirm commit**" | git commit 단계에서 또 한 번 확인 |

이 confirmation들은 Claude Code 권한 엔진이 만든 게 아니라, **슬래시 커맨드 본문의 산문(prose) 지시사항**이 모델에게 시킨 것입니다. CLAUDE.md, AGENTS.md, GEMINI.md, `.claude/rules/*` 모두에 대해 발생하며 **권한 모드와 완전히 독립적**입니다.

### CLAUDE.md(루트)가 보호 경로가 아닌데도 프롬프트가 뜨는 이유

이 부분이 Agent A의 분석에서 갭으로 남았던 지점입니다. 직접 검증으로 해소했습니다:

- `CLAUDE.md`는 프로젝트 루트에 있고 `.claude/` 하위가 아님 → Cause A 적용 불가
- 그럼에도 프롬프트가 뜨는 이유는 **전적으로 Cause B** 때문 — `post-merge.md:150`이 모델에게 "어떤 config 파일 변경이든 적용 전에 diff 요약을 제시하라"고 지시하기 때문

즉 사용자의 멘탈 모델은 여기서 무너집니다: "bypassPermissions가 모든 걸 건너뛰어야 한다"고 생각하셨지만 — bypassPermissions는 **도구 권한 프롬프트**만 건너뛰지, **슬래시 커맨드 본문이 모델에게 명시적으로 시킨 사용자 질문**까지 건너뛰지는 않습니다.

### 권장 수정안 (안전성 순)

#### 옵션 1 (권장) — `post-merge.md`의 산문을 부드럽게 만들고 Cause A는 사양으로 수용

`plugins/github-dev/commands/post-merge.md`에 다음 4개 편집을 적용합니다:

```diff
- - **Always confirm with user before creating new rule files**
+ - 새 `.claude/rules/<module>.md` 파일을 *생성*할 때만 경로와 내용을 먼저 보여주고
+   확인. 기존 rule 파일을 *수정*하는 경우는 바로 적용한 뒤 diff를 보고만.
```

```diff
- - Present the integration proposal to user as a diff-style summary before applying:
+ - 통합 결과를 바로 적용한 뒤 diff 요약을 사후 보고. 사용자는 필요 시
+   `git restore <file>`로 한 번에 되돌릴 수 있음.
```

```diff
- 9. **Commit Changes (Optional)**
-    - If any configuration files were modified, prompt user to confirm commit
+ 9. **Commit Changes (Optional)**
+    - 설정 파일이 변경되었으면 다음으로 staging 후 Conventional Commits 형식으로
+      바로 commit. 사용자 확인 단계 생략.
+      `git add CLAUDE.md AGENTS.md GEMINI.md README.md .serena/memories/ 2>/dev/null || true`
```

**근거**: 이 패치는 *고칠 수 있는* 프롬프트(Cause B, 모든 루트 설정 파일 — CLAUDE.md 포함)만 정확히 제거합니다. Cause A는 건드리지 않으므로 `.claude/rules/*` 작성 시 여전히 Anthropic 측 프롬프트가 뜨지만, (a) 빈도가 낮고, (b) 안전망의 가치가 충분하며, (c) 일괄 승인 가능합니다.

**위험**: CLAUDE.md 편집에서 human-in-the-loop을 제거하면 부주의한 `/post-merge` 호출이 사용자가 보존하고 싶었던 내용을 덮어쓸 수 있습니다. 사후 diff 요약 + `git restore` 안내가 한 명령으로 복구를 보장하므로 완화됩니다.

#### 옵션 2 (우회책) — 학습 내용을 `.claude/rules/`가 아닌 곳에 저장

`.claude/rules/` 쪽 프롬프트까지 완전히 0으로 만들고 싶다면 보호되지 않는 경로에 저장합니다:

- `docs/architecture/learnings/`
- `.github/notes/`

대신 별도 수동 통합 단계가 필요해지고, `.claude/rules/*.md`의 path-based frontmatter 자동 로딩 기능을 잃습니다.

**권장하지 않음** — 프롬프트가 워크플로 throughput을 실제로 막고 있는 게 아니라면 트레이드오프가 나쁩니다.

#### 옵션 3 (권장 안 함) — `auto` 모드 전환

Agent A가 제안한 `claude --permission-mode auto`. 문서 기반 caveats:

- Claude Code v2.1.83+, Sonnet/Opus 4.6, Team/Enterprise 플랜 필요
- classifier가 `.claude/` 편집을 risky로 판정하면 여전히 막힐 수 있음
- Cause B는 전혀 다루지 않음 (산문 기반 confirmation은 모드와 무관)

따라서 `auto` 모드는 *조건이 맞을 때만 Cause A를 부분적으로 완화*하고 Cause B는 그대로 둡니다. 버전 핀 고통 대비 효과 부족.

#### 옵션 4 (작동 안 함) — `.claude/rules/**`를 settings.json `permissions.allow`에 추가

공식 문서로 확인됨: **보호 경로는 명시적 allow 룰조차 무시(override)**합니다. 시도할 가치 없음.

### Q1 액션 아이템

1. **`post-merge.md`에 옵션 1 패치 적용** — 작은 4건 편집, 단일 파일, 저위험, 사용자 페인의 대부분 해소
2. **`plugins/github-dev/CLAUDE.md`에 "Known prompts" 섹션 추가** — `.claude/rules/*` 잔여 confirmation은 Anthropic 보호 경로에 의한 의도적 동작임을 명시. 미래의 자기 자신이 같은 문제를 반복 디버깅하지 않도록
3. **(선택)** Anthropic에 피드백 요청 — `.claude/rules/`도 `commands/agents/skills/worktrees`처럼 보호 경로 예외 목록에 추가해 달라고 요청

---

## Q2 — `/resolve-issue`에 PR 생성 전 Codex Review 끼워 넣기

사용자 질문: PR 만들기 직전에 codex의 review/adversarial 모드를 백그라운드 없이 동기 실행으로 추가하면 좋겠다. coderabbit보다 codex가 코드베이스를 더 잘 알기 때문에 더 풍부한 사전 피드백을 줄 것 같다.

### 기존 워크플로 매핑 (검증 완료)

`plugins/github-dev/commands/resolve-issue.md` 단계 구성:

| 단계 | 줄 범위 | 내용 |
|------|---------|------|
| 1. Analyze Issue | 26–31 | 이슈 fetch, TDD 감지, checkpoint 저장 |
| 2. Verify Plan | 33–42 | 플랜 파일 정합성 확인 |
| 3. Create Branch | 44–50 | 피처 브랜치 생성 |
| 4. Update Project Status | 52–63 | "In Progress" 마킹 |
| 5. Analyze Codebase | 65–96 | explorer agent 분기 |
| 6. Plan Resolution | 98 | 작업 단계 정의 |
| 7. Implement | 100–126 | TDD 또는 직접 구현 |
| 8. Write Tests | 128–140 | 80% 커버리지 목표 |
| 9–9.5. Validate | 142–162 | BUILD / TEST / LINT 게이트 |
| **9.6. 2-Stage Review** | **164–168** | **agent 기반 spec 준수 + 코드 품질 리뷰** |
| **9.7. ← 삽입 지점** | **(신규)** | **Codex 사전 PR 리뷰** |
| 10. Create PR | 170–172 | `gh pr create` |
| 11. Update Issue | 174 | 체크박스 업데이트 |
| 12. Update Project State | 176–201 | PR 번호 기록 |
| 13. Cleanup | 203–204 | state 파일 archive |

자연스러운 삽입 지점은 **9.6과 10 사이의 새 9.7**입니다. 검증 게이트와 2-stage 리뷰가 통과한 직후, PR이 열리기 직전.

### Agent B 초안의 치명적 오류 — 교정

Agent B의 1차 패치는 `mcp__codex-cli__review` 호출 시 `uncommitted=true`와 custom `prompt`를 **함께** 사용하도록 제안했습니다. **이건 런타임에 깨집니다.**

검증을 위해 실제 `mcp__codex-cli__review` 스키마를 직접 fetch했습니다:

```json
{
  "prompt": {
    "description": "Custom review instructions or focus areas (cannot be used with uncommitted=true; use base/commit review instead)"
  },
  "uncommitted": {
    "description": "Review staged, unstaged, and untracked changes (working tree) - cannot be combined with custom prompt"
  }
}
```

**둘은 상호 배타적입니다.** soft한 권고가 아니라 하드 스키마 제약입니다. 유효한 호출 형태는 셋뿐:

1. `uncommitted: true` (custom prompt 없이 — codex 기본 리뷰 동작 사용)
2. `base: <branch>` (+ optional `prompt`)
3. `commit: <SHA>` (+ optional `prompt`)

검증 없이 그대로 합성 리포트에 넣었으면 패치가 첫 호출에서 깨졌을 겁니다. 이게 Agent 결과를 *evidence*로 다뤄야지 *truth*로 다루면 안 되는 이유의 가장 좋은 사례입니다.

### 권장 호출 패턴: pass-1-only, uncommitted

**결정: 위 옵션 1 사용** (`uncommitted: true`, custom prompt 없음)

근거:
- **commit 전에** 이슈 포착 — 수정 비용이 가장 낮은 시점
- **prompt 불필요** — codex의 기본 리뷰 동작이 이미 working tree 리뷰용으로 튜닝되어 있음
- **단일 API 호출**, ~10–30s 동기 wall time. PR 직전 게이트로 수용 가능
- 스키마 충돌 회피

나중에 정말 custom prompt가 필요하면 대안은 (a) 먼저 commit한 뒤 `commit: <SHA>` + prompt로 호출. 단, 이미 commit된 코드를 다시 리뷰하는 거라 비용이 높고 가치는 낮아집니다.

### Codex vs CodeRabbit (둘 다 쓰는 게 옳습니다)

| 측면 | Codex (resolve-issue 안에서, 사전 PR) | CodeRabbit (사후 PR) |
|------|---------------------------------------|----------------------|
| 컨텍스트 | 전체 로컬 codebase + CLAUDE.md + project memory | PR diff만 (token 예산 제한) |
| 지연 | 동기, ~10–30s | 비동기, 분 단위 |
| 시점 | `gh pr create` *전* | PR 오픈 *후* |
| 범위 | staged + unstaged + untracked working tree | committed PR diff |
| 강점 | PR이 만들어지기 전에 명백한 이슈 포착 | maintainer/community 관점 |
| 비용 모델 | resolve-issue 호출당 1 API call | PR당 CodeRabbit 1회 |

**둘 다 사용**합니다. Codex는 즉각 피드백 루프("부서진 PR 자체를 만들지 마")를 제공하고, CodeRabbit은 second-opinion 루프("maintainer가 우리가 놓친 걸 잡았나?")를 제공합니다. 보완재이지 대체재가 아닙니다.

### 9.7 단계의 verdict 게이팅

```
verdict == "approve"          → "Codex review passed" 로그 → step 10 진행
verdict == "needs-attention"  → severity in {critical, high} 인 findings 추출
                              → file:line + title + recommendation 사용자에게 제시
                              → 질문: "PR 생성 전에 이 사항들을 수정할까요? [y/n]"
                              → y: 사용자 수정 대기 → codex review 1회 재시도
                              → n: "사용자가 findings 수용" 로그 → step 10 진행
```

### Fallback 전략

```
mcp__codex-cli__review 가 사용 불가 / 에러 / 45s 초과:
  경고 로그: "Codex review skipped: <reason>"
  step 10 진행
  codex-rescue 로 escalate 하지 않음 (지연 누적, 본래 목적 훼손)
  PR 생성을 차단하지 않음 (advisory only)
```

이로써 Codex는 *advisory enhancement*에 머무르며 — 사용 불가 시에도 기존 워크플로를 깨뜨리지 못합니다.

### 구체 패치 (교정본, 복사-붙여넣기 가능)

`plugins/github-dev/commands/resolve-issue.md`의 step 9.6 다음(line 168), step 10 이전(line 170)에 삽입:

```markdown
9.7. **Codex Pre-PR Review** (`--skip-review` 플래그가 있으면 건너뜀):

   - **목적**: 코드베이스 인지 기반 시멘틱 리뷰를 PR 오픈 전에 수행. 수정
     비용이 가장 낮은 working tree(commit 전) 시점에 이슈를 포착함.
   - **호출** (동기, blocking):
     ```
     mcp__codex-cli__review:
       uncommitted: true
       title: "Pre-PR review for issue #${ISSUE_NUMBER}"
       workingDirectory: <repo root>
     ```
     주의: codex MCP 스키마에서 `prompt`와 `uncommitted`는 상호 배타적임.
     여기서 custom prompt를 추가하지 말 것 — codex 기본 리뷰 동작이 이미
     working tree 리뷰용으로 튜닝되어 있음.

   - **Verdict 처리**:
     - `verdict == "approve"`: "Codex review passed" 로그, step 10 진행
     - `verdict == "needs-attention"`:
       1. `findings[]`에서 `severity in {critical, high}`만 필터
       2. 각 finding을 사용자에게 제시: file:line + title + body + recommendation
       3. 질문: "PR 생성 전에 이 사항들을 수정할까요? [y/n]"
       4. yes: 사용자 수정 대기, 본 단계 1회 재시도
       5. no (또는 재시도 후): "사용자가 findings 수용" 로그, step 10 진행

   - **Fallback**: MCP 도구가 사용 불가 / 에러 / 45s 초과면 "Codex review
     skipped: <reason>" 로그 후 step 10 진행. codex-rescue로 escalate
     하지 않음. PR 생성 차단하지 않음. Codex는 advisory.

   - **Checkpoint 저장**: phase="codex-review"
```

### 사용자에게 확인 필요한 미해결 항목

1. Codex review를 기존 `--skip-review` 플래그에 묶을지, 별도 `--skip-codex` 플래그를 만들지?
2. `medium` severity findings도 노출할지 (더 시끄럽지만 더 꼼꼼함), 아니면 `critical`/`high`만?
3. 1회 재시도 한도를 설정 가능하게 할지, 하드코딩할지?

---

## Q3 — Top 7 플러그인 헬스체크

Agent C 감사 + 모든 P0 주장 직접 검증.

### P0 — 즉시 수정 (Critical)

#### P0.1 — `core-config`: 4개 hook 모두 시스템 `python3` 사용 (확인됨)

**증거** (`plugins/core-config/.claude-plugin/plugin.json`):
- Line 12: `python3 ${CLAUDE_PLUGIN_ROOT}/hooks/inject-guidelines.py`
- Line 24: `python3 ${CLAUDE_PLUGIN_ROOT}/hooks/auto-format-python.py`
- Line 35: `python3 ${CLAUDE_PLUGIN_ROOT}/hooks/notify_osc.py Claude "Task completed"`
- Line 47: `python3 ${CLAUDE_PLUGIN_ROOT}/hooks/notify_osc.py`

**왜 P0인가**: `work-guidelines.md`가 명시적으로 시스템 Python을 금지함:
> Virtual Environment (MANDATORY): Always use uv. NEVER use system Python directly.

**영향**: 모든 prompt submission, 모든 Edit/Write, 모든 Stop, 모든 Notification에서 시스템 python을 호출. PATH에 `python3`가 없거나 hook 스크립트가 요구하는 의존성이 시스템 python에 없는 환경에서 조용히(또는 시끄럽게) 실패.

**수정** (PEP 723 inline-deps 방식):

```diff
- "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/inject-guidelines.py",
+ "command": "uv run --script ${CLAUDE_PLUGIN_ROOT}/hooks/inject-guidelines.py",
```

…그리고 각 `hooks/*.py` 스크립트에 PEP 723 헤더 추가:

```python
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
```

(스크립트별 실제 의존성 추가 — `inject-guidelines.py`와 `notify_osc.py`는 외부 의존성 없을 가능성이 높고, `auto-format-python.py`는 `ruff`가 필요할 수 있음.)

**Caveat**: `uv run --script`는 `uv`가 PATH에 있어야 함. `plugins/core-config/CLAUDE.md`의 Requirements 섹션에 hard requirement로 명시 (현재도 `uv`와 `ruff`를 언급하므로 일관성 유지).

#### P0.2 — `.claude/settings.json` 플러그인 활성화 목록 표류

**증거**:
- `.claude/settings.json`에 활성화된 플러그인은 17개 (line 4–20)
- `plugins/` 디렉터리에는 20개 `plugin.json` 파일 존재 (`omc`는 marketplace 캐시 설치라 `~/.claude/plugins/cache/omc/`에 있고 `plugins/`에는 없음)
- **디스크에 있지만 비활성화**: `paper-search-tools`, `prd-suite`, `docs-forge`

**왜 P0인가**: 디스크에 있지만 비활성화된 플러그인은 유지보수 혼란을 야기함 (사용자가 편집해도 효과 없음). 프로젝트 루트 `CLAUDE.md`는 "Plugins (21)" 헤드라인을 주장하는데 — 이 자체가 잘못된 카운트(omc 포함하여 21로 셈)입니다. 실제 디스크 카운트는 20.

**중요한 nuance — 플러그인 비활성화 ≠ MCP 서버 비활성화**: `paper-search-tools`는 `.claude/settings.json`에 비활성 상태이지만 현재 세션에서는 paper-search MCP 서버가 여전히 등록되어 16개의 `mcp__plugin_paper-search-tools_*` 도구가 노출됩니다. "플러그인 자체 비활성화"와 "MCP 서버 로딩"은 별개 surface입니다 — D1 결정 시 두 레이어를 모두 정리해야 합니다.

**수정 옵션**:
1. 누락된 3개를 `settings.json`에 활성화 — 만약 활성 의도였다면
2. 디스크에서 삭제 — 만약 폐기됐다면
3. README.md에 "experimental, 기본 비활성화"로 명시

하나 골라서 일관되게 적용.

### P1 — 중요

#### `core-config` — CLAUDE.md 문서 표류

**증거** (`plugins/core-config/CLAUDE.md`):
- 표는 `inject-guidelines.sh` (shell script)라고 적혀 있음 — 실제는 `inject-guidelines.py`
- 표는 `notify_osc.sh` (shell script)라고 적혀 있음 — 실제는 `notify_osc.py`
- `auto-format-python.py`만 정확히 적혀 있음

**수정**: Hooks 표 재작성:

```diff
- | `inject-guidelines.sh` | UserPromptSubmit | Auto-inject work guidelines on every prompt |
- | `auto-format-python.py` | Post Write/Edit | Auto-format Python with ruff |
- | `notify_osc.sh` | Stop/Notification | Terminal OSC 777 notifications |
+ | `inject-guidelines.py` | UserPromptSubmit | Auto-inject work guidelines on every prompt |
+ | `auto-format-python.py` | PostToolUse (Write\|Edit) | Auto-format Python with ruff |
+ | `notify_osc.py` | Stop / Notification | Terminal OSC 777 notifications (cross-platform) |
```

#### `github-dev` — marketplace.json description이 너무 빈약

현재 `marketplace.json` 설명("GitHub workflow: commit, PR, issue, code review")은 너무 일반적. 실제로는 worktree 학습 통합, Mermaid 다이어그램 기반 milestone 진행 추적, 아키텍처 인지 프로젝트 추적까지 합니다. 어느 것도 description에 노출되지 않음.

**수정**:
> "GitHub workflow with worktree learning integration, code review feedback synthesis, milestone progress tracking, and architecture-aware project diagrams (CodeRabbit, Mermaid)."

description 품질이 높아지면 자동 로딩 트리거와 `find-skills` 결과가 개선됨.

#### `github-dev` — `CLAUDE.md`가 1840줄, quick-start 없음

이 플러그인의 CLAUDE.md는 매우 상세하지만 skim 가능한 onboarding 경로가 없음. 신규 사용자에게는 top 3 명령어와 라이프사이클 다이어그램만 담은 100줄 quick-start가 필요.

**수정**: `plugins/github-dev/QUICKSTART.md` (100줄) 추가, CLAUDE.md에서 링크.

#### `code-scout` — `huggingface_hub` 설치 안내 누락

Agent C가 발견 — code-scout의 resource-finder 스킬에 있는 `search_huggingface.py`가 `huggingface_hub`를 import하는데 플러그인 문서에는 설치 방법이 없음. 첫 사용 시 ImportError.

**수정**: `plugins/code-scout/CLAUDE.md`의 Requirements 섹션에 추가:
> `/code-scout:resource-finder` 사용 전 `uv add huggingface_hub` (또는 `uv tool install huggingface-cli`) 실행.

문서의 스크립트 호출도 `uv run python skills/resource-finder/scripts/search_huggingface.py`로 업데이트.

#### `ml-toolkit` — 템플릿이 Jupyter cell에서 `!pip install` 사용

`cv-notebook`과 `gpu-parallel-pipeline` 스킬 템플릿이 의존성 설치용으로 `!pip install` cell을 권장. work-guidelines가 시스템 Python을 금지하는데 — 이게 사용자 노트북까지 흘러나옴.

**수정**: `!pip install`을 `%pip install`(현재 활성 커널을 존중)로 교체하거나, uv 관리 커널 등록을 권장: `uv run --with <pkg> python -m ipykernel install --user --name <env>`.

core-config보다 시급도가 낮은 이유는 이 템플릿들이 사용자 커스터마이징 가능한 출력물이기 때문이지만, 나쁜 본보기를 설정함.

#### `interactive-review` — README가 deprecated `pip install mcp` 언급

`mcp-server/server.py`는 PEP 723 inline deps를 올바르게 사용하고, `.mcp.json`도 `uv run`을 올바르게 호출함. 그런데 README는 여전히 이전 버전의 `pip install mcp`를 언급.

**수정**: README install 섹션을 재작성해서 이미 적용된 PEP 723 + `uv run --directory` 셋업을 문서화. `mcp>=1.0.0,<2.0.0`로 핀하여 breaking change drift 방지.

#### `council` — 명령 description이 모호

`council.md`는 "LLM Council - Query multiple AI models..."로 시작하는데 *언제* 써야 하는지 명시하지 않음. 더 나은 형태:

> "Multi-round, anonymized deliberation across Claude / Codex / Gemini for architectural decisions, design disputes, or multi-perspective code reviews. Synthesizes a single recommendation."

description이 모호하면 auto-trigger 신뢰도가 떨어짐.

### P2 — 마무리 폴리시

| 플러그인 | 이슈 | 수정 |
|----------|------|------|
| `ml-toolkit` | `plugin.json`에 명시적 `skills` 배열 없음 | `["./skills/gpu-parallel-pipeline", "./skills/gradio-cv-app", "./skills/cv-notebook", "./skills/cv-explorer"]` 추가하여 명시적 자동 디스커버리 |
| `ml-toolkit` | SKILL.md description 포맷 일관성 부족 | 2-문장 포맷으로 표준화 |
| `interactive-review` | MCP 버전 핀이 느슨 (`>=1.0.0`) | 상한 `<2.0.0` 추가 |
| `council` | Codex/Gemini CLI 의존성 버전 제약 없음 | CLAUDE.md에 최소 버전 명시 |

### Cross-Plugin 관찰

1. **Python venv 처리가 플릿 전반에 걸쳐 일관성 없음**:
   - 정상: `interactive-review` (PEP 723 + `uv run --directory`)
   - 깨짐: `core-config` (시스템 `python3`) — P0
   - 부분: `code-scout`, `ml-toolkit` (문서가 `pip install` 언급)
   - **권장**: 프로젝트 레벨 lint 추가 — `grep -rE 'python3 |pip install' plugins/*/.claude-plugin/plugin.json plugins/*/**/*.md` — 매치 시 CI 실패

2. **description 품질이 들쭉날쭉**:
   - 특히 `github-dev`, `council`의 `marketplace.json` description이 모호 — auto-loading trigger 손해
   - 권장: 모든 `description` 필드를 한 번에 감사. 80–120자 + 구체 트리거 문구 목표

3. **`plugin.json`과 `marketplace.json` 사이 버전 표류는 감사 대상 6개에서 발견되지 않음** — 좋음. 이쪽 위험은 낮음

4. **문서 표류는 실제로 존재**: `core-config` CLAUDE.md (`.sh` vs `.py`)와 `interactive-review` README (`pip install` vs `uv run`) 모두 실제 코드와 모순. 다음 패스에서 `plugins/`의 모든 CLAUDE.md를 해당 `plugin.json`과 대조 감사할 것

5. **`__pycache__` 디렉터리가 untracked로 흘러나옴**: git status에 `plugins/interactive-review/mcp-server/__pycache__/`와 `plugins/workflow-viz/hooks/__pycache__/`가 untracked로 떠 있음. 프로젝트 루트 `.gitignore`에 `**/__pycache__/`와 `*.pyc` 추가 권장. PEP 723 마이그레이션과 무관하게 즉시 처리 가능

### Top 5 Quick Wins (impact ÷ effort 순)

1. **[P0, ~30분]** `core-config` plugin.json: 4× `python3`를 `uv run --script`로 교체, 3개 hook 스크립트에 PEP 723 헤더 추가. **최고 임팩트** — 모든 세션이 core-config hook을 로드함
2. **[P0, ~10분]** `core-config` CLAUDE.md: `.sh` → `.py` 문서 표류 수정. trivial, 사용자 혼란 즉시 제거
3. **[P1, ~15분]** `post-merge.md`: 사용자 confirmation 산문을 부드럽게 만드는 4건의 작은 편집 (위 Q1 옵션 1 패치). 사용자의 실제 페인을 직접 해소
4. **[P1, ~20분]** `interactive-review` README: install 섹션을 PEP 723 + `uv run`으로 재작성. `mcp<2.0.0`로 핀
5. **[P0, ~10분]** `.claude/settings.json`: 17 vs 21 표류 해소. 누락된 3개 활성화 또는 삭제

**총합: 5개 P0/P1 quick win에 ~85분.**

---

## Q4 — 후속 `ralph` 세션을 위한 작업 분해

이 리뷰를 작업으로 전환하려면, 아래 항목들이 독립적이며 병렬화 가능합니다. `ralph` 실행이 각 항목을 verifier로 검증한 뒤 완료를 선언할 수 있습니다.

### Stream A — 권한 ergonomics
- [ ] **A1** Q1 옵션 1에 따라 `plugins/github-dev/commands/post-merge.md` 편집 (line 148, 150, 234의 4건 편집)
- [ ] **A2** `plugins/github-dev/CLAUDE.md`에 "Known prompts" 섹션 추가 — 잔여 `.claude/rules/*` confirmation은 Anthropic 측 보호 경로에 의한 의도적 동작임을 명시

### Stream B — Codex review 통합
- [ ] **B1** `mcp__codex-cli__review` 도구가 호출 가능한지 검증 — `codex mcp list` 또는 `mcp__codex-cli__ping` 라운드트립으로 확인. 워크스페이스 `.mcp.json`에 항목이 없어도 사용자 레벨 codex CLI MCP 서버를 통해 노출될 수 있음 (codex-cli는 자체적으로 MCP 서버를 띄우는 구조)
- [ ] **B2** Q2의 패치 fragment를 `plugins/github-dev/commands/resolve-issue.md`의 9.7 단계로 삽입
- [ ] **B3** 작은 샘플 이슈로 dry-run: `resolve-issue` 실행 → verdict 게이팅 동작 확인 → MCP 도구를 중간에 죽여서 fallback 동작 확인
- [ ] **B4** `plugins/github-dev/CLAUDE.md`의 "resolve-issue Flags" 표에 새 단계 문서화 — 원하면 `--skip-codex` 플래그 추가

### Stream C — core-config 컴플라이언스 (P0)
- [ ] **C1** `plugins/core-config/hooks/*.py` 3개 파일에 PEP 723 헤더 추가
- [ ] **C2** `plugins/core-config/.claude-plugin/plugin.json`의 4× `python3`을 `uv run --script`로 교체
- [ ] **C3** `plugins/core-config/CLAUDE.md`의 Requirements 섹션을 업데이트하여 `uv`를 hard requirement로 명시 (현재도 부분 언급)
- [ ] **C4** 같은 CLAUDE.md의 `.sh` vs `.py` 문서 표류 수정
- [ ] **C5** 검증: 새 셸을 띄우고 이 워크스페이스에서 `claude` 실행 → 프롬프트 제출 → 마이그레이션 후에도 가이드라인 자동 주입이 동작하는지 확인

### Stream D — 설정 & 메타데이터 클린업
- [ ] **D1** `paper-search-tools`, `prd-suite`, `docs-forge`의 활성화 여부 결정 후 `.claude/settings.json` 업데이트
- [ ] **D2** Q3에 따라 `github-dev`와 `council`의 `marketplace.json` description 확장
- [ ] **D3** `code-scout` CLAUDE.md에 huggingface_hub 셋업 안내 추가
- [ ] **D4** `ml-toolkit` plugin.json에 명시적 `skills` 배열 추가
- [ ] **D5** `ml-toolkit` 노트북 템플릿의 `!pip install`을 `%pip install`로 교체
- [ ] **D6** 프로젝트 루트 `CLAUDE.md`의 "Plugins (21)" 헤드라인을 실제 디스크 카운트(20) 또는 D1 결정 이후의 새 활성화 카운트와 동기화. README.md와 marketplace.json 메타데이터도 함께 점검

### Stream 병렬화 맵

```
Stream A  ─┐
Stream B  ─┼─ 4개 stream 모두 독립 — 완전 병렬화 가능
Stream C  ─┤
Stream D  ─┘
```

`ralph` 호출이 stream당 1개 executor를 분기하고 각각 `verifier`로 독립 검증 가능. 어느 stream도 같은 파일을 건드리지 않으므로 merge 충돌 리스크 없음.

---

## 방법론 메모 (다음 번을 위해)

**잘 작동한 것**:
- 에이전트 분기 전에 4개 스코핑 질문을 먼저 물은 것 — 최소한 1개의 낭비된 agent run을 절약
- 3개 sub-agent 병렬 — 순차 실행 1개 분량의 wall time
- 모든 P0 주장과 모든 구체 API 계약을 합성 전에 자체 검증

**자체 검증이 잡아낸 두 가지 agent 오류**:
1. **Agent A**가 Cause B(슬래시 커맨드 자체의 confirmation 산문)를 놓침 — Anthropic 보호 경로만 봤음. `post-merge.md`를 직접 읽으니 두 번째 원인이 드러남
2. **Agent B**가 `mcp__codex-cli__review`를 `uncommitted=true` + `prompt`로 호출하는 패치를 제안. 실제 MCP 도구 스키마를 fetch해보니 둘은 상호 배타적 — 패치가 런타임에 깨졌을 것임. **이게 가장 중요한 방법론 교훈**: agent가 구체 API 호출을 제안할 땐 합성 전에 API 계약을 반드시 검증

**다음 번 플러그인 리뷰를 위한 권장**: agent가 제안한 어떤 MCP/도구 호출이든 신뢰하기 전에 ToolSearch + 실제 스키마 직독. Agent 출력은 *evidence*로 다루지 *truth*로 다루지 말 것.

---

## Appendix — 인용 파일

본 리포트에서 참조한 파일/문서:
- `plugins/github-dev/commands/post-merge.md` (line 114, 148, 150, 234)
- `plugins/github-dev/commands/resolve-issue.md` (line 26–204; 삽입 지점 168/170)
- `plugins/core-config/.claude-plugin/plugin.json` (line 12, 24, 35, 47)
- `plugins/core-config/CLAUDE.md` (Hooks 표 — `.sh` vs `.py` 표류)
- `.claude/settings.json` (활성화된 17개 플러그인)
- `~/.claude/plugins/cache/openai-codex/codex/1.0.1/schemas/review-output.schema.json` (review verdict / findings **출력** 스키마)
- `mcp__codex-cli__review` 라이브 MCP 도구 등록 (codex-cli 0.118.0) — `prompt`/`uncommitted` **입력** 인자 상호 배타성의 원전. 스키마 파일이 아닌 도구 등록 description에 명시되어 있으며 ToolSearch로 직접 fetch하여 검증함
- 공식 문서: `https://code.claude.com/docs/en/permission-modes.md` (보호 경로)
