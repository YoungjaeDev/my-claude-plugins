<div align="center">

![oh-my-claudecode](https://raw.githubusercontent.com/Yeachan-Heo/oh-my-claudecode-website/main/social-preview.png)

# oh-my-claudecode

[![npm version](https://img.shields.io/npm/v/oh-my-claude-sisyphus?color=cb3837)](https://www.npmjs.com/package/oh-my-claude-sisyphus)
[![npm downloads](https://img.shields.io/npm/dm/oh-my-claude-sisyphus?color=blue)](https://www.npmjs.com/package/oh-my-claude-sisyphus)
[![GitHub stars](https://img.shields.io/github/stars/YoungjaeDev/oh-my-claudecode?style=flat&color=yellow)](https://github.com/YoungjaeDev/oh-my-claudecode/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

**Claude Code용 멀티 에이전트 오케스트레이션. 배울 거 없음.**

*zsh 커스터마이징 몇 년 걸리는데, 그냥 oh-my-zsh 쓰면 끝.*
*Claude Code 배우지 마. OMC 쓰면 됨.*

[시작하기](#시작하기-30초) • [문서](https://yeachan-heo.github.io/oh-my-claudecode-website) • [마이그레이션 가이드](docs/MIGRATION.md)

[English](README.md) | **한국어**

</div>

---

## 시작하기 (30초)

**Step 1:** 플러그인 설치
```
/plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode
/plugin install oh-my-claudecode
```

**Step 2:** 셋업 실행
```
/oh-my-claudecode:omc-setup
```

설정 끝. 나머지는 알아서 돌아감.

---

## 이제 뭐가 달라지나

| 내가 하면 | 자동으로 하는 것 |
|-------------|-------------------|
| 복잡한 작업 지시 | 전문 에이전트들한테 병렬 분산 |
| "plan this" 입력 | 기획 인터뷰 시작 |
| "끝날 때까지 멈추지 마" 입력 | 검증 완료까지 끈질기게 진행 |
| UI/프론트엔드 작업 | 디자인 센스 활성화 |
| 리서치나 탐색 필요 | 전문 에이전트한테 위임 |
| "build me..." 또는 autopilot 사용 | 완전 자율 워크플로우 실행 |

**명령어 외울 필요 없음.** 자연어로 의도 감지해서 알아서 적절한 동작 실행함.

---

## 매직 키워드 (선택 사항)

파워 유저가 명시적 제어 원할 때 쓰는 **선택 사항 단축키**임. 자연어로도 잘 됨 - 키워드는 정확도 원할 때만 쓰면 됨.

메시지 아무 데나 이 단어 넣으면 됨:

| 키워드 | 효과 |
|---------|--------|
| `ralph` | 끈질김 모드 - 끝날 때까지 안 멈춤 |
| `ralplan` | 합의 기반 반복 기획 |
| `ulw` / `ultrawork` | 최대 병렬 실행 |
| `ultrapilot` | 병렬 autopilot (3-5배 빠름) |
| `swarm` | N개 협동 에이전트 |
| `pipeline` | 순차 에이전트 체이닝 |
| `eco` / `ecomode` | 토큰 절약형 병렬 실행 |
| `plan` | 기획 인터뷰 시작 |
| `autopilot` / `ap` | 완전 자율 실행 |

**조합 가능:** `ralph ulw: migrate the database` 또는 `eco: refactor auth system`

---

## 실행 모드 (v3.4.0)

### Ultrapilot: 병렬 Autopilot

최대 5개 병렬 워커로 3-5배 빠른 실행. 멀티 컴포넌트 시스템이나 대규모 리팩토링에 적합:

```
/oh-my-claudecode:ultrapilot "build a fullstack todo app"
```

**작동 방식:**
- 병렬화 가능한 서브태스크로 자동 분해
- 파일 소유권 분리로 충돌 방지
- 지능적 조정하에 병렬 실행
- 충돌 자동 감지 및 해결

---

### Swarm: 협동 에이전트

공유 풀에서 태스크 클레임하는 N개 독립 에이전트:

```
/oh-my-claudecode:swarm 5:executor "fix all TypeScript errors"
```

**기능:**
- 원자적 태스크 클레임으로 중복 작업 방지
- 태스크당 5분 타임아웃 + 자동 릴리스
- 2~10개 워커 스케일

---

### Pipeline: 순차 체이닝

스테이지 간 데이터 전달하며 에이전트 체이닝:

```
/oh-my-claudecode:pipeline explore:haiku -> architect:opus -> executor:sonnet
```

**내장 프리셋:**
- `review` - explore → architect → critic → executor
- `implement` - planner → executor → tdd-guide
- `debug` - explore → architect → build-fixer
- `security` - explore → security-reviewer → executor

---

### Ecomode: 토큰 절약형

가능하면 Haiku로 최대 병렬화, 복잡한 추론은 Sonnet/Opus로 폴백:

```
/oh-my-claudecode:ecomode "refactor the authentication system"
```

기본 ultrawork 대비 **30-50% 토큰 절약**하면서 품질 유지.

---

## 자동 스킬 학습 (v3.5.0)

OMC가 문제 해결 패턴 자동 감지해서 재사용 가능한 스킬로 추출 제안함.

### 작동 방식

1. **패턴 감지** - 대화에서 문제-솔루션 쌍 인식
2. **스킬 추출** - `/oh-my-claudecode:learner`로 재사용 가능한 지식 추출
3. **자동 매칭** - 퍼지 매칭으로 새 문제에 스킬 적용 가능 여부 감지
4. **자동 호출** - 높은 신뢰도 매치 (80+)는 묻지 않고 자동 적용

### 로컬 스킬 관리

```
/oh-my-claudecode:skill list           # 학습된 스킬 전체 목록
/oh-my-claudecode:skill search "auth"  # 키워드로 스킬 검색
/oh-my-claudecode:skill edit <name>    # 스킬 편집
/oh-my-claudecode:skill sync           # 유저+프로젝트 스킬 동기화
```

### 스킬 저장 위치

- **유저 레벨**: `~/.claude/skills/sisyphus-learned/` (프로젝트 공유)
- **프로젝트 레벨**: `.omc/skills/` (프로젝트 전용)

스킬은 트리거, 태그, 품질 점수가 포함된 YAML frontmatter 사용.

---

## 분석 & 비용 추적 (v3.5.0)

모든 세션의 Claude Code 사용량 자동 트랜스크립트 분석으로 추적.

### 히스토리 데이터 백필

```
omc backfill                    # 모든 트랜스크립트 분석
omc backfill --from 2026-01-01  # 특정 날짜부터
omc backfill --project "*/myproject/*"  # 프로젝트 필터
```

### 통계 조회

```
omc stats                       # 모든 세션 집계
omc stats --session             # 현재 세션만
omc stats --json                # JSON 출력
```

**샘플 출력:**
```
📊 All Sessions Stats
Sessions: 18
Entries: 3356

💰 Token Usage & Cost
Total Tokens: 4.36M
Total Cost: $2620.49

🤖 Top Agents by Cost (All Sessions)
  (main session)              700.7k tokens  $1546.46
  oh-my-claudecode:architect    1.18M tokens  $432.68
  oh-my-claudecode:planner    540.9k tokens  $274.85
  oh-my-claudecode:executor   306.9k tokens  $77.43
```

**기능:**
- 첫 `omc stats` 실행 시 자동 백필
- `~/.omc/state/`에 글로벌 저장 (프로젝트 간 공유)
- 적절한 에이전트 귀속 (메인 세션 vs 스폰된 에이전트)
- 중복 방지로 이중 계산 안 함

---

## 데이터 분석 & 리서치 (v3.4.0)

### Scientist 에이전트 티어

정량 분석과 데이터 사이언스를 위한 3단계 scientist 에이전트:

| 에이전트 | 모델 | 용도 |
|-------|-------|---------|
| `scientist-low` | Haiku | 빠른 데이터 검사, 간단한 통계, 파일 열거 |
| `scientist` | Sonnet | 표준 분석, 패턴 감지, 시각화 |
| `scientist-high` | Opus | 복잡한 추론, 가설 검증, ML 워크플로우 |

**기능:**
- **영속적 Python REPL** - 호출 간 변수 유지 (pickle/reload 오버헤드 없음)
- **구조화된 마커** - 파싱된 출력용 `[FINDING]`, `[STAT:*]`, `[DATA]`, `[LIMITATION]`
- **품질 게이트** - 모든 발견은 통계적 증거 필요 (CI, effect size, p-value)
- **자동 시각화** - `.omc/scientist/figures/`에 차트 저장
- **리포트 생성** - 그림 임베딩된 마크다운 리포트

```python
# 호출 간 변수 유지됨!
python_repl(action="execute", researchSessionID="analysis",
            code="import pandas as pd; df = pd.read_csv('data.csv')")

# df 아직 존재 - 재로드 불필요
python_repl(action="execute", researchSessionID="analysis",
            code="print(df.describe())")
```

### /oh-my-claudecode:research 명령어 (신규)

포괄적 리서치 워크플로우를 위한 병렬 scientist 에이전트 오케스트레이션:

```
/oh-my-claudecode:research <goal>                    # 체크포인트 있는 표준 리서치
/oh-my-claudecode:research AUTO: <goal>              # 완료까지 완전 자율
/oh-my-claudecode:research status                    # 현재 세션 체크
/oh-my-claudecode:research resume                    # 중단된 세션 재개
/oh-my-claudecode:research list                      # 모든 세션 목록
/oh-my-claudecode:research report <session-id>       # 세션 리포트 생성
```

**리서치 프로토콜:**
1. **분해** - 목표를 3-7개 독립 스테이지로 분해
2. **병렬 실행** - scientist 에이전트 동시 실행 (최대 5개)
3. **교차 검증** - 발견 간 일관성 검증
4. **종합** - 포괄적 마크다운 리포트 생성

**스마트 모델 라우팅:**
- 데이터 수집 태스크 → `scientist-low` (Haiku)
- 표준 분석 → `scientist` (Sonnet)
- 복잡한 추론 → `scientist-high` (Opus)

**세션 관리:** 리서치 상태를 `.omc/research/{session-id}/`에 유지해서 중단 후 재개 가능.

---

## 중단하기

그냥 이렇게 말하면 됨:
- "stop"
- "cancel"
- "abort"

컨텍스트 기반으로 뭘 멈출지 알아서 판단함.

---

## MCP 서버 구성

MCP(Model Context Protocol) 서버로 Claude Code에 추가 도구 확장.

```
/oh-my-claudecode:mcp-setup
```

### 지원하는 MCP 서버

| 서버 | 설명 | API 키 필요 |
|--------|-------------|------------------|
| **Context7** | 인기 라이브러리 문서 및 코드 컨텍스트 | 아니오 |
| **Exa** | 향상된 웹 검색 (내장 websearch 대체) | 예 |
| **Filesystem** | 확장된 파일 시스템 액세스 | 아니오 |
| **GitHub** | 이슈, PR, 레포용 GitHub API | 예 (PAT) |

### 빠른 설정

셋업 명령어 실행하고 프롬프트 따라가면 됨:
```
/oh-my-claudecode:mcp-setup
```

또는 `~/.claude/settings.json`에서 수동 설정:
```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    },
    "exa": {
      "command": "npx",
      "args": ["-y", "exa-mcp-server"],
      "env": {
        "EXA_API_KEY": "your-key-here"
      }
    }
  }
}
```

설정 후 Claude Code 재시작해야 변경사항 적용됨.

---

## 내부에 뭐가 있나

- **32개 전문 에이전트** - architect, researcher, explore, designer, writer, vision, critic, analyst, executor, planner, qa-tester, scientist (explore-high 포함 티어 변형)
- **40개 스킬** - orchestrate, autopilot, ultrawork, ultrapilot, swarm, pipeline, ecomode, ralph, planner, ralplan, deepsearch, analyze, research, tdd, build-fix, code-review, security-review, git-master, frontend-ui-ux, learner, mcp-setup, cancel (통합형) 등
- **5가지 실행 모드** - Autopilot (자율), Ultrapilot (3-5배 병렬), Swarm (협동), Pipeline (순차), Ecomode (토큰 절약)
- **MCP 서버 지원** - Context7, Exa, GitHub, 커스텀 MCP 서버 간편 설정
- **영속적 Python REPL** - 데이터 분석용 진짜 변수 영속성
- **리서치 워크플로우** - `/oh-my-claudecode:research` 명령어로 병렬 scientist 오케스트레이션
- **HUD 상태바** - 오케스트레이션 상태 실시간 시각화
- **학습된 스킬** - `/oh-my-claudecode:learner`로 세션에서 재사용 가능한 인사이트 추출
- **메모리 시스템** - 압축 살아남는 영속적 컨텍스트

---

## HUD 상태바

Claude Code 상태바에 실시간 오케스트레이션 상태 표시:

```
[OMC] | 5h:0% wk:100%(1d6h) | ctx:45% | agents:Ae
todos:3/5 (working: Implementing feature)
```

**라인 1:** 핵심 메트릭
- 리셋 시간 포함 레이트 리밋 (예: `wk:100%(1d6h)` = 1일 6시간 후 리셋)
- 컨텍스트 윈도우 사용량
- 활성 에이전트 (타입과 모델 티어로 코딩)

**라인 2:** Todo 진행도
- 완료 비율 (`3/5`)
- 진행 중인 현재 작업

`/oh-my-claudecode:hud setup`으로 표시 옵션 설정 가능.

---

## 2.x에서 오나

**좋은 소식:** 옛날 명령어 그대로 작동함!

```
/oh-my-claudecode:ralph "task"      →  여전히 작동 (또는 그냥 "ralph: task")
/oh-my-claudecode:ultrawork "task"  →  여전히 작동 (또는 그냥 "ulw" 키워드)
/oh-my-claudecode:planner "task"    →  여전히 작동 (또는 그냥 "plan this")
```

차이점? 이제 *안 써도 됨*. 전부 자동 활성화됨.

자세한 건 [마이그레이션 가이드](docs/MIGRATION.md) 참고.

---

## 문서

- [전체 레퍼런스](docs/FULL-README.md) - 완전한 문서 (800줄 이상)
- [마이그레이션 가이드](docs/MIGRATION.md) - 2.x에서 3.0 전환
- [아키텍처](docs/ARCHITECTURE.md) - 기술 딥다이브
- [웹사이트](https://yeachan-heo.github.io/oh-my-claudecode-website) - 온라인 문서

---

## 요구사항

- [Claude Code](https://docs.anthropic.com/claude-code) CLI
- 다음 중 하나:
  - **Claude Max/Pro 구독** (개인 사용자 추천)
  - **Anthropic API 키** (API 기반 사용)

---

## 스타 히스토리

[![Star History Chart](https://api.star-history.com/svg?repos=Yeachan-Heo/oh-my-claudecode&type=Date)](https://star-history.com/#Yeachan-Heo/oh-my-claudecode&Date)

---

## 라이선스

MIT - [LICENSE](LICENSE) 참고

---

<div align="center">

**영감 받은 프로젝트:**

[oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) • [claude-hud](https://github.com/ryanjoachim/claude-hud) • [Superpowers](https://github.com/NexTechFusion/Superpowers) • [everything-claude-code](https://github.com/affaan-m/everything-claude-code)

**배울 거 없음. 최대 성능.**

</div>
