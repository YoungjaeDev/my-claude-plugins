# Codex Bridge Plugin

my-claude-plugins 의 skill 들을 Codex CLI 가 네이티브로 로드하는 `~/.agents/skills/` (OpenAI 공식 USER scope) 로 idempotent 하게 변환·복사한다.

## Skill

| Skill | Description |
|-------|-------------|
| `codex-sync` | Sync my-claude-plugins skills and commands to `~/.agents/skills/` |

## 원칙

- **Single Source of Truth**: `plugins/*/skills/**` 이 원본, `~/.agents/skills/` 는 derived artifact. 양방향 sync 아님.
- **Body-only transform**: frontmatter 는 불변 (`bridge_source` 마커 보존). body 만 3개 rule 로 치환.
- **Safety guard**: `bridge_source` 없는 파일은 절대 건드리지 않음 (외부 · 사용자 파일 보호).
- **Orphan prune**: `bridge_source` 있고 원본 사라진 skill 만 자동 삭제.

## 진입점

1. Claude Code skill: `/codex-bridge:codex-sync` (이 플러그인 활성화 시)
2. Direct CLI: `node plugins/codex-bridge/scripts/sync.mjs [options]`

## CLI Options

```
--dry-run              파일 변경 없이 계획만 출력
--verbose              파일별 행위 상세 출력
--config <path>        커스텀 config 경로
--plugin <list>        쉼표 구분 플러그인 필터
--no-prune             auto-prune 비활성화
--report <path>        JSON 리포트 파일 출력
--help                 도움말
```

Exit codes: `0` 성공 · `1` 부분 실패 · `2` 치명적 (config 파싱 실패, 권한 없음)

## Transform Rules (body-only)

| From | To | Mode |
|------|----|------|
| `CLAUDE.md` | `AGENTS.md` | literal |
| `.claude/` | `.codex/` | literal |
| `(?<![:/.\w])\/([a-z][a-z0-9-]*):([a-z][a-z0-9-]*)` | `$<skill>` (`$$$2`) | regex `g` |

namespace regex 는 lookbehind `(?<![:/.\w])` 가드로 `https://x.io/foo:bar` 같은 URL 표기 (직전 문자가 단어 문자) 에서의 false positive 를 차단한다.

## 경로 정설

- Target: `$HOME/.agents/skills/<name>/SKILL.md` — OpenAI 공식 USER scope
- `~/.codex/skills/` (외부 관리) 는 **절대 건드리지 않음**
- `CODEX_HOME` env 는 state/log base 일 뿐, skill 디렉토리와 무관

## Dependencies

- Node 18+
- Codex CLI 0.120.0+

## 참조

- Spec: `.claude/spec/2026-04-14-codex-bridge-skill-sync.md`
- OpenAI Codex Skills: https://developers.openai.com/codex/skills
- OpenAI Codex Customization: https://developers.openai.com/codex/concepts/customization
