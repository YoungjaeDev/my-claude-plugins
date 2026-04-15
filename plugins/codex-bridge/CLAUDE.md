# Codex Bridge Plugin

OMC 플러그인 skill 들을 Codex CLI 가 네이티브로 로드하는 `~/.agents/skills/` (OpenAI 공식 USER scope) 로 idempotent 하게 변환·복사한다.

## Skill

| Skill | Description |
|-------|-------------|
| `codex-sync` | Sync OMC plugin skills to `~/.agents/skills/` |

## 원칙

- **Single Source of Truth**: `plugins/*/skills/**` 이 원본, `~/.agents/skills/` 는 derived artifact. 양방향 sync 아님.
- **Body-only transform**: frontmatter 는 불변 (`bridge_source` 마커 보존). body 만 7개 rule 로 치환.
- **Safety guard**: `bridge_source` 없는 파일은 절대 건드리지 않음 (OMX · 사용자 파일 보호).
- **Orphan prune**: `bridge_source` 있고 원본 사라진 skill 만 자동 삭제.

## 진입점

1. Claude Code skill: `/codex-bridge:codex-sync` (이 플러그인 활성화 시)
2. Direct CLI: `node plugins/codex-bridge/scripts/sync.mjs [options]`
3. V2 npm (예정): `npx @youngjaedev/omc-codex-sync`

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
| `.omc/` | `.omx/` | literal |
| `CLAUDE.md` | `AGENTS.md` | literal |
| `/oh-my-claudecode:` | `$` | literal |
| `oh-my-claudecode` | `oh-my-codex` | literal |
| `~/.claude/` | `~/.codex/` | literal |
| `omc` (word-boundary) | `omx` | regex `\bomc\b` |
| `OMC` (word-boundary) | `OMX` | regex `\bOMC\b` |

## 경로 정설

- Target: `$HOME/.agents/skills/<name>/SKILL.md` — OpenAI 공식 USER scope
- `~/.codex/skills/` (OMX 관리) 는 **절대 건드리지 않음**
- `CODEX_HOME` env 는 state/log base 일 뿐, skill 디렉토리와 무관

## Dependencies

- Node 18+ (OMX 이미 요구)
- OMX 설치 (권장, 필수 아님)
- Codex CLI 0.120.0+

## 참조

- Spec: `.claude/spec/2026-04-14-codex-bridge-skill-sync.md`
- OpenAI Codex Skills: https://developers.openai.com/codex/skills
- OpenAI Codex Customization: https://developers.openai.com/codex/concepts/customization
