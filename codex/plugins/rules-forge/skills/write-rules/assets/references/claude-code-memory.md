<!--
Source: Claude Code official docs — "Memory" page (KR translation)
URL: https://code.claude.com/docs/ko/memory
Snapshot date: 2026-05-12

Use: write-rules skill loads this on-demand to ground guidance about
AGENTS.md placement, .codex/rules/ semantics, auto-memory, AGENTS.md
coexistence, and troubleshooting. NOT loaded at session start —
referenced from skill body when the user asks "why this structure"
or when mode execution needs to cite official guidance.

Content trimmed to write-rules concerns; full doc available at the
URL above. Major edits: dropped enterprise managed-settings sections,
compressed claudeMdExcludes example to one block.
-->

# Claude 가 프로젝트를 기억하는 방법

각 Claude Code 세션은 새로운 컨텍스트 윈도우로 시작된다. 두 메커니즘이 세션 간에 지식을 전달한다:

- **AGENTS.md 파일**: 사용자가 작성하는 지속적 지침
- **자동 메모리**: Claude 가 자기 자신을 위해 작성하는 노트

## AGENTS.md vs 자동 메모리

|  | AGENTS.md | 자동 메모리 |
|---|---|---|
| 작성자 | 사용자 | Claude |
| 포함 내용 | 지침·규칙 | 학습·패턴 |
| 범위 | 프로젝트·사용자·조직 | 저장소당 |
| 로드 대상 | 모든 세션 (전체) | 모든 세션 (`MEMORY.md` 200줄 / 25KB) |
| 사용 목적 | 코딩 표준·워크플로우·아키텍처 | 빌드 명령·디버깅 인사이트·발견된 선호도 |

둘 다 강제된 구성이 아니라 컨텍스트. 지침이 더 구체적이고 간결할수록 일관되게 따른다.

## AGENTS.md 파일을 어디에 둘지

| 범위 | 위치 | 목적 |
|---|---|---|
| 관리 정책 | OS 별 시스템 경로 | IT/DevOps 조직 전체 지침 |
| **프로젝트** | `./AGENTS.md` 또는 `./.codex/AGENTS.md` | 팀 공유 |
| 사용자 | `~/.codex/AGENTS.md` | 개인 선호도 (모든 프로젝트) |
| 로컬 | `./CLAUDE.local.md` | 개인 프로젝트별 (`.gitignore` 권장) |

작업 디렉토리 위의 디렉토리 계층의 AGENTS.md 와 CLAUDE.local.md 는 시작 시 전체 로드된다. 하위 디렉토리 파일은 Claude 가 해당 디렉토리 파일을 읽을 때 필요에 따라 로드.

## 효과적인 지침 작성

AGENTS.md 는 모든 세션 시작 시 컨텍스트 윈도우에 로드되어 대화와 함께 토큰을 소비한다.

- **크기**: 파일당 200줄 이하 목표. 더 긴 파일은 더 많은 컨텍스트 소비 + 준수율 저하.
- **구조**: 마크다운 헤더와 글머리 기호로 관련 지침 그룹화.
- **구체성**: 검증 가능할 정도로 구체적:
  - "코드를 제대로 포맷합니다" → "2칸 들여쓰기 사용"
  - "변경 사항을 테스트합니다" → "커밋하기 전에 `npm test` 실행"
  - "파일을 정리된 상태로 유지합니다" → "API 핸들러는 `src/api/handlers/`"
- **일관성**: 충돌하는 지침이 있으면 Claude 가 임의로 하나 선택 가능. 정기 검토.

## 추가 파일 가져오기

AGENTS.md 는 `@path/to/import` 구문으로 다른 파일을 가져올 수 있다. 가져온 파일은 확장되어 시작 시 컨텍스트에 로드된다.

```text
프로젝트 개요는 @README 참조, npm 명령은 @package.json 참조.

# 추가 지침
- git 워크플로우 @docs/git-instructions.md
```

상대·절대 경로 모두 허용. 최대 5개 홉 깊이로 재귀 import 가능.

**중요**: `@import` 된 파일도 시작 시 컨텍스트에 전체 로드됨. 토큰 절약 효과 없음 — 단순히 파일을 조직적으로 분할하는 도구. 토큰 절약이 목적이면 [`.codex/rules/`](#claude-rules-로-규칙-구성) 의 path-scoped 규칙을 사용할 것.

## AGENTS.md

Claude Code 는 `AGENTS.md` 를 읽고 `AGENTS.md` 는 읽지 않는다. 저장소가 이미 다른 코딩 에이전트 (Codex / Cursor / Aider 등) 에 `AGENTS.md` 를 사용 중이면 `AGENTS.md` 를 만들어 import 하는 패턴이 권장:

```markdown
@AGENTS.md

## Claude Code

`src/billing/` 아래 변경 사항에 대해 Plan Mode 사용.
```

Windows 심볼릭 링크는 권한 이슈가 있어 `@AGENTS.md` import 사용. POSIX 환경에선:

```bash
ln -s AGENTS.md AGENTS.md
```

`/init` 은 기존 `AGENTS.md` / `.cursorrules` / `.windsurfrules` 등을 읽고 생성된 `AGENTS.md` 에 통합한다.

## `.codex/rules/` 로 규칙 구성

대규모 프로젝트의 경우 `.codex/rules/` 디렉토리로 지침을 여러 파일로 구성. 지침이 모듈식이 되고 팀 유지보수가 쉬워진다. 규칙을 **특정 파일 경로로 범위 지정** 가능 — Claude 가 일치하는 파일로 작업할 때만 컨텍스트에 로드되어 노이즈와 토큰 둘 다 절약.

### 규칙 설정

```text
your-project/
├── .codex/
│   ├── AGENTS.md           # 주 프로젝트 지침
│   └── rules/
│       ├── code-style.md   # 코드 스타일 가이드라인
│       ├── testing.md      # 테스트 규칙
│       └── security.md     # 보안 요구사항
```

모든 `.md` 파일은 재귀적으로 발견되므로 `frontend/` / `backend/` 같은 하위 디렉토리로 구성 가능.

`paths` frontmatter 가 없는 규칙은 `.codex/AGENTS.md` 와 동일한 우선순위로 시작 시 로드.

### 경로별 규칙 (Path-specific rules)

`paths` 필드가 있는 YAML frontmatter 로 특정 파일에 범위 지정. 이러한 조건부 규칙은 Claude 가 지정된 패턴과 일치하는 파일로 작업할 때만 적용:

```markdown
---
paths:
  - "src/api/**/*.ts"
---

# API 개발 규칙

- 모든 API 엔드포인트는 입력 검증 포함
- 표준 오류 응답 형식 사용
- OpenAPI 문서 주석 포함
```

`paths` 필드가 없는 규칙은 무조건 로드, 모든 파일에 적용.

**Glob 패턴 예시**:

| 패턴 | 일치 |
|---|---|
| `**/*.ts` | 모든 디렉토리의 모든 TypeScript 파일 |
| `src/**/*` | `src/` 아래의 모든 파일 |
| `*.md` | 프로젝트 루트의 마크다운 파일 |
| `src/components/*.tsx` | 특정 디렉토리의 React 컴포넌트 |

여러 패턴 지정 + 중괄호 확장:

```markdown
---
paths:
  - "src/**/*.{ts,tsx}"
  - "lib/**/*.ts"
  - "tests/**/*.test.ts"
---
```

### 사용자 수준 규칙

`~/.codex/rules/` 의 개인 규칙은 모든 프로젝트에 적용. 사용자 수준 규칙은 프로젝트 규칙 전에 로드되어 프로젝트 규칙에 더 높은 우선순위 부여.

## AGENTS.md 파일 로드 순서

Claude Code 는 현재 작업 디렉토리에서 디렉토리 트리를 올라가며 각 디렉토리 AGENTS.md 와 CLAUDE.local.md 를 읽는다. `foo/bar/` 에서 실행 시:

1. `foo/AGENTS.md`
2. `foo/CLAUDE.local.md`
3. `foo/bar/AGENTS.md`
4. `foo/bar/CLAUDE.local.md`

순서대로 컨텍스트에 추가 (서로 재정의하지 않고 누적). 더 가까운 디렉토리 지침이 마지막에 읽혀 우선.

하위 디렉토리의 AGENTS.md 는 시작 시 로드 안 되고, Claude 가 해당 하위 디렉토리 파일을 읽을 때 포함.

`<!-- ... -->` HTML 주석은 컨텍스트에 주입되기 전 제거 — 토큰 소비 없이 유지보수 노트 남기는 용도.

## 자동 메모리

자동 메모리는 Claude 가 세션 간에 지식을 축적하는 메커니즘 — 사용자 개입 없이.

- **저장 위치**: 프로젝트당 `~/.codex/projects/<project>/memory/`
- **활성 / 비활성**: `/memory` 메뉴 또는 `autoMemoryEnabled` 설정
- **로드**: `MEMORY.md` 의 처음 200줄 또는 25KB 가 모든 대화 시작 시 로드
- **주제 파일**: `MEMORY.md` 가 인덱스, 자세한 노트는 별도 주제 파일로 분리 (`debugging.md` / `patterns.md` 등). 주제 파일은 시작 시 로드 안 되고 필요 시 Read

```text
~/.codex/projects/<project>/memory/
├── MEMORY.md          # 간결한 인덱스, 모든 세션에 로드
├── debugging.md       # 디버깅 패턴
├── api-conventions.md # API 설계 결정
└── ...
```

자동 메모리는 컴퓨터 로컬. 동일한 git 저장소의 모든 worktree 와 하위 디렉토리는 하나의 자동 메모리 디렉토리 공유. 컴퓨터·클라우드 환경 간 공유 안 됨.

### `/memory` 로 보기·편집

`/memory` 명령은 현재 세션에 로드된 모든 AGENTS.md / CLAUDE.local.md / 규칙 파일 나열 + 자동 메모리 폴더 링크. 모든 파일은 일반 마크다운이라 직접 편집 가능.

## 모노레포: 특정 AGENTS.md 파일 제외

대규모 모노레포에서 상위 AGENTS.md 파일에 작업과 무관한 지침이 포함될 수 있다. `claudeMdExcludes` 설정으로 경로 또는 glob 패턴으로 특정 파일 건너뛰기:

```json
{
  "claudeMdExcludes": [
    "**/monorepo/AGENTS.md",
    "/home/user/monorepo/other-team/.codex/rules/**"
  ]
}
```

`.codex/settings.local.json` 에 추가하면 로컬로 유지. 절대 파일 경로에 glob 매칭. 설정 레이어 (사용자 / 프로젝트 / 로컬 / 관리 정책) 전체에서 배열 병합.

## 메모리 문제 해결

### Claude 가 AGENTS.md 를 따르지 않음

AGENTS.md 콘텐츠는 시스템 프롬프트의 일부가 아니라 시스템 프롬프트 후 사용자 메시지로 전달. Claude 는 읽고 따르려 하지만 엄격한 준수 보장 안 됨.

디버깅:

1. `/memory` 실행해 AGENTS.md 와 CLAUDE.local.md 가 로드되는지 확인
2. AGENTS.md 가 세션에 대해 로드되는 위치에 있는지 확인
3. 지침을 더 구체적으로 ("2칸 들여쓰기" > "코드를 제대로 포맷")
4. AGENTS.md 파일 전체에서 충돌하는 지침 찾기

특정 시점에 명령 실행 강제가 필요하면 **hook** 사용. 시스템 프롬프트 수준 지침은 `--append-system-prompt` 사용.

### AGENTS.md 가 너무 큼

200줄을 초과하는 파일은 더 많은 컨텍스트 소비 + 준수 저하. 해결:

1. **경로별 규칙** 사용 — Claude 가 일치하는 파일로 작업할 때만 지침 로드
2. 모든 세션에서 필요하지 않은 콘텐츠 정리
3. `@path` import 로 분할 — 단 import 된 파일도 시작 시 로드되므로 컨텍스트 줄이지는 않음, 조직화만

### `/compact` 후 지침이 손실된 것 같음

프로젝트 루트 AGENTS.md 는 압축을 완전히 생존: `/compact` 후 Claude 는 디스크에서 AGENTS.md 를 다시 읽고 세션에 새로 다시 주입. 하위 디렉토리의 중첩된 AGENTS.md 는 자동으로 다시 주입 안 됨 — 해당 하위 디렉토리 파일을 다시 읽을 때 다시 로드.

압축 후 사라진 것 같은 지침은:
- AGENTS.md 에 작성되지 않고 대화에서만 제공된 경우
- 아직 다시 로드되지 않은 중첩된 AGENTS.md 의 경우

세션 간 지속되도록 AGENTS.md 에 대화 전용 지침 추가.

## write-rules 가 사용하는 핵심 규칙

이 reference 의 위 내용을 write-rules skill 이 출력 결정에 적용하는 방식:

| 출력 결정 | 근거 |
|---|---|
| Root AGENTS.md ≤ 200줄 목표 | "200줄 이하 목표 + 더 긴 파일은 준수 저하" |
| `.codex/rules/*.md` 생성 시 `paths:` glob 권장 | "조건부 로드 → 컨텍스트 절약" |
| 생성 root 에 `@import` 디렉티브 자동 추가 안 함 | "import 도 시작 시 로드, 토큰 절약 효과 없음" |
| AGENTS.md 존재 시 `@AGENTS.md` import 패턴 hint | "다른 코딩 에이전트와 공존 권장 방식" |
| `CLAUDE.local.md` 는 `.gitignore` 권장으로만 hint | "개인 프로젝트별 선호도, 버전 제어 비공유" |
| 자동 메모리 디렉토리는 건드리지 않음 | "Claude 가 작성·관리하는 영역" |
| 하위 디렉토리 AGENTS.md 는 lazy load 됨을 사용자에게 통지 | "/compact 시 자동 재주입 안 됨 — 의존 시 주의" |
