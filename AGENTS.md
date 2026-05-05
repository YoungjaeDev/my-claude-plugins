# AGENTS.md

## 기본 원칙

- 이 저장소는 Claude Code 플러그인 marketplace 저장소입니다. 변경 전에는 루트 `CLAUDE.md`, `README.md`, 관련 플러그인의 `plugins/<name>/CLAUDE.md`를 먼저 확인하세요.
- 사용자가 한국어로 요청하면 한국어로 응답하세요.
- 변경은 요청 범위에만 한정하고, 관련 없는 파일이나 기존 사용자 변경 사항은 되돌리지 마세요.
- 파일 탐색과 검색은 우선 `rg`, `rg --files`를 사용하세요.
- 문서와 매니페스트가 함께 움직이는 저장소이므로 코드 변경뿐 아니라 README, 루트 `CLAUDE.md`, marketplace manifest의 동기화 필요성을 항상 확인하세요.

## 저장소 구조

- `CLAUDE.md`: 플러그인 목록과 전체 구조 요약.
- `README.md`: 사용자용 설치 및 플러그인 문서.
- `.claude/settings.json`: 로컬 플러그인 로드 설정.
- `.claude-plugin/marketplace.json`: marketplace 레지스트리와 플러그인 버전 목록.
- `.claude/rules/`: 특정 경로에 적용되는 상세 규칙.
- `plugins/<name>/`: 각 플러그인의 원본 디렉터리.
- `plugins/<name>/.claude-plugin/plugin.json`: 플러그인별 매니페스트와 버전.
- `plugins/codex-bridge/scripts/sync.mjs`: OMC 플러그인 skill/command/guideline을 Codex용 artifact로 변환하는 동기화 엔진.

## 플러그인 변경 규칙

- 플러그인 버전을 올릴 때는 `plugins/<name>/.claude-plugin/plugin.json`과 `.claude-plugin/marketplace.json`의 해당 항목을 같은 변경에 포함하세요.
- 어떤 플러그인 버전이든 변경하면 `.claude-plugin/marketplace.json`의 `metadata.version`도 marketplace release 버전으로 올리세요.
- 플러그인을 추가하거나 제거하면 루트 `CLAUDE.md`의 플러그인 수와 구조, `README.md`의 플러그인 수와 목록도 갱신하세요.
- 버전은 semver를 따릅니다. 버그 수정은 PATCH, 하위 호환 기능은 MINOR, 깨지는 변경은 MAJOR입니다.
- Claude Code 플러그인 캐시 이슈 때문에 사용자 문서나 릴리스 안내에는 필요 시 `rm -rf ~/.claude/plugins/cache/my-claude-plugins/` 후 marketplace update 및 Claude Code 재시작 절차를 유지하세요.

## codex-bridge 작업 규칙

- `plugins/codex-bridge/**`를 수정할 때는 `.claude/rules/codex-bridge-sync.md`를 먼저 읽고 따르세요.
- `plugins/*/skills/**/SKILL.md`와 `plugins/*/commands/*.md`가 원본입니다. `~/.agents/skills/`는 재생성되는 산출물입니다.
- sync 엔진은 `~/.agents/skills/`만 대상으로 합니다. `~/.codex/skills/`는 OMX 관리 영역이므로 건드리지 마세요.
- frontmatter는 보존해야 합니다. 변환 규칙은 body에만 적용하고, `bridge_source` provenance marker를 유지하세요.
- `bridge_source`가 없는 기존 대상 파일은 외부 소유로 보고 덮어쓰거나 삭제하지 마세요.
- sync 엔진은 Node 18+ built-in만 사용합니다. 런타임 의존성을 추가하지 마세요.
- `--plugin <list>`를 사용할 때는 자동 prune으로 다른 플러그인 산출물이 삭제될 수 있으므로 `--no-prune`과 함께 사용하세요.

## 검증

- 전체 codex-bridge 테스트:

```bash
node --test plugins/codex-bridge/tests/*.test.mjs
```

- codex-bridge 변경 전후 dry run:

```bash
node plugins/codex-bridge/scripts/sync.mjs --dry-run --verbose
```

- Python 테스트가 필요한 경우 해당 플러그인 디렉터리에서 `uv run pytest`를 우선 사용하세요.

## 문서 작성 스타일

- 사용자-facing 문서는 한국어 설명을 자연스럽게 유지하고, 명령어와 경로는 코드 포맷으로 표기하세요.
- README류 문서는 실제 설치/사용 흐름을 우선하고, 플러그인 수, 플러그인 이름, 명령어 예시는 매니페스트와 일치시켜야 합니다.
- 큰 구조 변경 없이 문서만 보강하는 경우에도 관련 count, badge, 목록이 stale하지 않은지 확인하세요.
