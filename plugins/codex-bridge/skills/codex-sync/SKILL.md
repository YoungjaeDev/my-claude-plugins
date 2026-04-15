---
name: codex-sync
description: Sync OMC plugin skills to Codex `~/.agents/skills/` (OpenAI USER scope) with body-only transform rules and `bridge_source` provenance marker. Use when user says "codex sync", "sync skills to codex", "/codex-sync", or after adding/modifying OMC plugin skills that should also be available in independent Codex CLI sessions. Idempotent — safe to re-run.
---

# codex-sync

OMC (`plugins/*/skills/**/SKILL.md`) skill 들을 Codex CLI 가 네이티브로 로드하는 `~/.agents/skills/` 로 변환·복사한다.

## 언제 쓰나

- OMC 쪽에서 skill 을 새로 추가했거나 고쳤을 때
- 독립 Codex CLI 세션 (`codex` 터미널 직접 실행) 에서 OMC skill 을 `$<skill-name>` 으로 호출하고 싶을 때
- `omx doctor` 전에 skill 상태 정합성 맞출 때

양방향 sync 가 아님. OMC 가 SSOT, `~/.agents/skills/` 는 derived artifact — 매 실행마다 다시 생성된다.

## 핵심 원칙

1. **Safety**: `bridge_source` 마커 없는 `~/.agents/skills/*/SKILL.md` 는 **절대 건드리지 않는다** (사용자 / OMX 파일 보호)
2. **Body-only transform**: frontmatter 는 불변, body 만 7 개 rule 로 치환
3. **Orphan prune**: `bridge_source` 마커 있고 원본이 없어진 skill 만 자동 삭제
4. **Atomic write**: 임시 staging 디렉토리에 렌더링 후 atomic rename 으로 부분 쓰기 방지

## 진입점 (3 가지)

### 1. Claude Code skill (이것)

```
$codex-sync
$codex-sync --dry-run
$codex-sync --plugin github-dev,core-config
```

Claude Code 가 이 SKILL.md 를 읽은 뒤, 아래 Bash 명령을 실행한다.

### 2. Direct CLI

```bash
node plugins/codex-bridge/scripts/sync.mjs [options]
```

### 3. npm (V2 예정)

```bash
npx @youngjaedev/omc-codex-sync [options]
```

## CLI Options

| Flag | 동작 |
|------|-----|
| `--dry-run` | 파일 변경 없이 계획만 출력 |
| `--verbose` | 파일별 행위 상세 출력 |
| `--config <path>` | 커스텀 config 경로 (기본: `codex-bridge.config.json`) |
| `--plugin <list>` | 쉼표 구분 플러그인 필터 (예: `--plugin github-dev,core-config`) |
| `--no-prune` | auto-prune 비활성화 |
| `--report <path>` | JSON 리포트 파일 출력 |
| `-h`, `--help` | 도움말 |

Exit codes: `0` 성공 · `1` 부분 실패 · `2` 치명적 (config 파싱 실패, 권한 없음, 알 수 없는 인자)

## Transform Rules (body-only)

| From | To | Mode |
|------|-----|------|
| `.omc/` | `.omx/` | literal |
| `CLAUDE.md` | `AGENTS.md` | literal |
| `/oh-my-claudecode:` | `$` | literal |
| `oh-my-claudecode` | `oh-my-codex` | literal |
| `~/.claude/` | `~/.codex/` | literal |
| `omc` (word-boundary) | `omx` | regex `\bomc\b` |
| `OMC` (word-boundary) | `OMX` | regex `\bOMC\b` |

**Text-only** 확장자 화이트리스트에 맞는 파일만 치환: `.md`, `.yml`, `.yaml`, `.json`, `.sh`, `.mjs`, `.js`, `.py`, `.ts`. 이 외 (이미지, 바이너리) 는 그대로 복사.

**frontmatter 면제**: `---` 구분자 사이는 불변. `bridge_source` 마커 보호, skill 이름/description 오염 방지.

## 실행 방법

사용자가 `$codex-sync` 로 호출하면 다음 Bash 로 delegate:

```bash
node plugins/codex-bridge/scripts/sync.mjs "$@"
```

사용자가 `--dry-run` 을 지정하지 않았고 `~/.agents/skills/` 에 OMC-managed skill 이 없다면, 먼저 `--dry-run --verbose` 로 변경사항을 미리 보여준 뒤 사용자 확인을 받고 실제 실행한다.

## Safety Checks

실행 전 다음을 확인:

1. Node 18+ 설치 여부: `node --version`
2. `~/.agents/skills/` 쓰기 권한
3. Target 에 비-OMC skill 이 있는 경우, 충돌 탐지 후 skip + stderr warning

실행 후:

1. 각 synced SKILL.md frontmatter 에 `bridge_source: <plugin>/<skill>` 존재 확인
2. body 에서 `.omc/` / `CLAUDE.md` / `oh-my-claudecode` 등이 변환되었는지 spot check
3. `~/.codex/skills/` (OMX 관리) 가 **침범되지 않았음** 확인

## 충돌 처리

- `~/.agents/skills/<name>/SKILL.md` 가 이미 있고 `bridge_source` 마커가 **없음** → skip + stderr warn ("not managed by OMC, inspect with `omx doctor`")
- 마커 있음 → overwrite (OMC-managed 이므로 안전)
- 다른 OMC 플러그인에서 동일 이름 → last-wins (경고)

## Out of Scope (V1)

V2 에서 예정:
- `Task(subagent_type=...)` → Codex native subagent 매핑
- `AGENTS.md` 섹션 inject (OMX 마커 외부)
- 파일 변경 hook 으로 auto-sync
- Project-level `.agents/skills/` 타깃
- Collision-fallback 프리픽스 자동 부여

## 참조

- Spec: `.claude/spec/2026-04-14-codex-bridge-skill-sync.md`
- OpenAI Codex Skills: https://developers.openai.com/codex/skills
- OpenAI Codex Customization: https://developers.openai.com/codex/concepts/customization
