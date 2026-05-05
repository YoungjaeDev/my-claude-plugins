---
name: codex-sync
description: "Use when syncing my-claude-plugins skills and commands to Codex (~/.agents/skills/) so they become callable as native $skill-name in independent Codex CLI sessions. Triggers: 'codex sync', 'sync skills to codex', '/codex-bridge:codex-sync', or after adding/modifying plugin skills that should also be available in Codex. Body-only transform with bridge_source provenance marker. Idempotent."
tools: Bash, Read, Glob, Edit, Write
---

# codex-sync

my-claude-plugins 의 skill (`plugins/*/skills/**/SKILL.md`) 과 command (`plugins/*/commands/*.md`) 을 Codex 로 이관한다.

- Skills + commands → `~/.agents/skills/` (Codex USER scope, 네이티브 `$skill-name` 호출 가능). Commands 는 `<plugin>-<command>` 네임스페이스로 wrap.

## 언제 쓰나

- plugin pack 쪽에서 skill 을 새로 추가했거나 고쳤을 때
- 독립 Codex CLI 세션 (`codex` 터미널 직접 실행) 에서 plugin skill 을 `$<skill-name>` 으로 호출하고 싶을 때

양방향 sync 가 아님. my-claude-plugins 가 SSOT, `~/.agents/skills/` 는 derived artifact — 매 실행마다 다시 생성된다.

## 핵심 원칙

1. **Safety**: `bridge_source` 마커 없는 `~/.agents/skills/*/SKILL.md` 는 **절대 건드리지 않는다** (사용자 / 외부 파일 보호)
2. **Body-only transform**: frontmatter 는 불변, body 만 3 개 rule 로 치환
3. **Orphan prune**: `bridge_source` 마커 있고 원본이 없어진 skill 만 자동 삭제
4. **Atomic write**: 임시 staging 디렉토리에 렌더링 후 atomic rename 으로 부분 쓰기 방지

## 진입점 (3 가지)

### 1. Claude Code skill (이것)

Claude Code 세션에서 slash command 로 호출:

```
/codex-bridge:codex-sync
/codex-bridge:codex-sync --dry-run
/codex-bridge:codex-sync --plugin github-dev,core-config
```

Claude Code 가 이 SKILL.md 를 읽은 뒤, 아래 Bash 명령을 실행한다.

### 2. Direct CLI (Bash)

```bash
node plugins/codex-bridge/scripts/sync.mjs [options]
```

### 3. Codex CLI (sync 후)

본 스킬이 sync 되면 Codex 터미널 세션에서도 호출 가능:

```
$codex-sync
$codex-sync --dry-run
```

## CLI Options

| Flag | 동작 |
|------|-----|
| `--dry-run` | 파일 변경 없이 계획만 출력 |
| `--verbose` | 파일별 행위 + 진단 출력 (resolved pluginsDir, layout 종류, plugin/skill/command counts) |
| `--config <path>` | 커스텀 config 경로 (기본: `codex-bridge.config.json`) |
| `--plugin <list>` | 쉼표 구분 플러그인 필터 (예: `--plugin github-dev,core-config`) |
| `--plugins-dir <path>` | plugins 디렉토리 명시 지정 (auto-detect 우회. 비표준 layout 디버깅 / 단위 테스트용) |
| `--no-prune` | auto-prune 비활성화 |
| `--report <path>` | JSON 리포트 파일 출력 |
| `-h`, `--help` | 도움말 |

Exit codes: `0` 성공 · `1` 부분 실패 · `2` 치명적 (config 파싱 실패, 권한 없음, 알 수 없는 인자)

## Transform Rules (body-only)

| From | To | Mode |
|------|-----|------|
| `CLAUDE.md` | `AGENTS.md` | literal |
| `.claude/` | `.codex/` | literal |
| `(?<![:/.\w])\/([a-z][a-z0-9-]*):([a-z][a-z0-9-]*)` | `$<skill>` (regex `$$$2`) | regex `g` |

**Text-only** 확장자 화이트리스트에 맞는 파일만 치환: `.md`, `.yml`, `.yaml`, `.json`, `.sh`, `.mjs`, `.js`, `.py`, `.ts`. 이 외 (이미지, 바이너리) 는 그대로 복사.

**frontmatter 면제**: `---` 구분자 사이는 불변. `bridge_source` 마커 보호, skill 이름/description 오염 방지.

namespace regex 는 lookbehind `(?<![:/.\w])` 가드로 `https://x.io/foo:bar` 같은 URL 표기 (직전 문자가 단어 문자) 를 false positive 에서 제외한다.

## 실행 방법

Claude Code 에서 사용자가 `/codex-bridge:codex-sync` 로 호출하면 다음 Bash 로 delegate:

```bash
node plugins/codex-bridge/scripts/sync.mjs "$@"
```

사용자가 `--dry-run` 을 지정하지 않았고 `~/.agents/skills/` 에 codex-bridge-managed skill 이 없다면, 먼저 `--dry-run --verbose` 로 변경사항을 미리 보여준 뒤 사용자 확인을 받고 실제 실행한다.

### 실행 위치 (plugin cache vs source checkout)

스크립트는 두 가지 layout 을 자동 인식한다:

- **Source checkout (monorepo)**: `<repo>/plugins/codex-bridge/scripts/sync.mjs` 직접 실행. `pluginsDir` 가 `<repo>/plugins` 로 자동 산출되어 모든 plugin 이 정상 발견됨.
- **Claude Code plugin cache**: `~/.claude/plugins/cache/my-claude-plugins/codex-bridge/<version>/scripts/sync.mjs` 가 호출되는 케이스. `pluginsDir` 가 `~/.claude/plugins/cache/my-claude-plugins/` 로 산출되며, plugin 별 `<plugin>/<latest-semver>/skills/` · `commands/` 까지 자동으로 descend 한다.

`--verbose` 출력 첫 줄에 어느 layout 인지 명시된다:

```
[codex-bridge] resolved pluginsDir: /path (auto-detected (monorepo))
[codex-bridge] resolved pluginsDir: /path (auto-detected (versioned-cache fallback))
[codex-bridge] resolved pluginsDir: /path (overridden via --plugins-dir)
```

비표준 layout 이거나 자동 인식이 잘못 동작하면 `--plugins-dir <path>` 로 명시:

```bash
node sync.mjs --dry-run --verbose --plugins-dir /custom/plugins
```

Windows 경로도 지원 (Node `path.resolve` 가 OS 별 separator 정규화).

## Safety Checks

실행 전 다음을 확인:

1. Node 18+ 설치 여부: `node --version`
2. `~/.agents/skills/` 쓰기 권한
3. Target 에 외부 관리 skill 이 있는 경우, 충돌 탐지 후 skip + stderr warning
4. `--plugin <list>` 사용 시 `--no-prune` 을 함께 사용 (미사용 시 선택되지 않은 플러그인의 bridge-managed skill 이 orphan prune 대상이 될 수 있음)
5. **Layout auto-detect**: monorepo / Claude Code cache 자동 인식. `--verbose` 출력 첫 줄로 검증 가능 (`auto-detected (monorepo)` / `auto-detected (versioned-cache fallback)` / `overridden via --plugins-dir`)
6. **Prune safety net** (1.3.1+): discovery 가 0 skill 을 반환하면 (잘못된 `pluginsDir` resolution 가능성) auto-prune 은 자동으로 skip 되고 stderr warning 출력. 이 가드가 있어도 비정상 출력을 보면 즉시 중단 권장

실행 후:

1. 각 synced SKILL.md frontmatter 에 `bridge_source: <plugin>/<skill>` 존재 확인
2. body 에서 `CLAUDE.md` / `.claude/` / `/<plugin>:<skill>` 등이 변환되었는지 spot check
3. `~/.codex/skills/` (외부 관리) 가 **침범되지 않았음** 확인

## 충돌 처리

- `~/.agents/skills/<name>/SKILL.md` 가 이미 있고 `bridge_source` 마커가 **없음** → skip + stderr warn ("not managed by codex-bridge")
- 마커 있음 → overwrite (codex-bridge-managed 이므로 안전)
- 다른 plugin 에서 동일 이름 → last-wins (경고)

## Out of Scope (V1)

V2 에서 예정:
- `Task(subagent_type=...)` → Codex native subagent 매핑
- 파일 변경 hook 으로 auto-sync
- Project-level `.agents/skills/` 타깃
- Collision-fallback 프리픽스 자동 부여

## 참조

- Spec: `.claude/spec/2026-04-14-codex-bridge-skill-sync.md`
- OpenAI Codex Skills: https://developers.openai.com/codex/skills
- OpenAI Codex Customization: https://developers.openai.com/codex/concepts/customization
