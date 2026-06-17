# AGENTS.md

## 기본 원칙

- 이 저장소는 Claude Code 플러그인 marketplace 저장소입니다. 변경 전에는 루트 `CLAUDE.md`, `README.md`, 관련 플러그인의 `plugins/<name>/CLAUDE.md`를 먼저 확인하세요.
- 사용자가 한국어로 요청하면 한국어로 응답하세요.
- 변경은 요청 범위에만 한정하고, 관련 없는 파일이나 기존 사용자 변경 사항은 되돌리지 마세요.
- 파일 탐색과 검색은 우선 `rg`, `rg --files`를 사용하세요.
- 문서와 매니페스트가 함께 움직이는 저장소이므로 코드 변경뿐 아니라 README, 루트 `CLAUDE.md`, marketplace manifest의 동기화 필요성을 항상 확인하세요.

## 듀얼 통합 (Claude Code ↔ Codex)

이 저장소는 Claude Code 와 Codex CLI 둘 다로 구동된다. 지침/hook/lore 를 한쪽 표면에만 두면 다른 도구체인에는 안 보인다. 동작에 영향을 주는 변경은 짝 표면을 같은 변경에서 점검한다. (Claude 쪽 SSOT: `.claude/rules/dual-integration.md` — Codex 는 `.claude/rules/` 를 `@import` 못 하므로 이 블록이 미러다.)

| 관심사 | Claude Code 표면 | Codex 표면 |
|---|---|---|
| 최상위 지침 | `CLAUDE.md`, `.claude/rules/*.md` | `AGENTS.md` (inline / mirror) |
| 프롬프트 주입 hook | 플러그인 `UserPromptSubmit` (`plugin.json` → `hooks/*.sh`) | `~/.codex/hooks.json` → 같은 스크립트, `codex` 포맷 인자 |
| skill | `plugins/*/skills` (native) | 같은 `plugins/<name>/` 트리 in-place + generated `.codex-plugin/plugin.json` (아래 "Codex 통합 (shared-source)" 참조) |
| command / subagent | `plugins/*/{commands,agents}` (native) | Codex 0.135 미지원 (Claude-only — 매니페스트에 미방출) |
| 공유 중립 lore | `.llmwiki/` (양 에이전트 동일 루트, fork 금지) | `.llmwiki/` |

- 양 에이전트가 따라야 할 behavioral 지침은 `CLAUDE.md` 와 `AGENTS.md` 를 짝으로 수정한다.
- Claude hook 을 추가/변경하면 Codex `~/.codex/hooks.json` 대응을 점검한다 (Codex hook 은 별도 `/hooks` trust 필요, 자동 등록 안 됨).
- skill / 버전 / description 을 바꾸면 Codex 매니페스트 재생성(`node scripts/sync-codex-manifests.mjs`)이 필요한지 점검한다 ("Codex 통합 (shared-source)" 섹션 + `plugin-versioning.md`).
- wiki lore 는 `.claude/rules/` 로 승격하지 않는다 — Codex 가 못 읽는다. cross-agent insight 는 `.llmwiki/insight/` 로 graduate 후 공유 주입 hook 으로 노출한다.
- `.llmwiki/` 를 per-agent 로 fork 하지 않는다.

## 저장소 구조

- `CLAUDE.md`: 플러그인 목록과 전체 구조 요약.
- `README.md`: 사용자용 설치 및 플러그인 문서.
- `.claude/settings.json`: 로컬 플러그인 로드 설정.
- `.claude-plugin/marketplace.json`: marketplace 레지스트리와 플러그인 버전 목록.
- `.claude/rules/`: 특정 경로에 적용되는 상세 규칙.
- `plugins/<name>/`: 각 플러그인의 원본 디렉터리.
- `plugins/<name>/.claude-plugin/plugin.json`: 플러그인별 매니페스트와 버전.
- `plugins/<name>/.codex-plugin/plugin.json`: Codex 0.135 용 매니페스트 (generated, do not edit by hand).
- `.agents/plugins/marketplace.json`: Codex marketplace 카탈로그 (generated).
- `scripts/sync-codex-manifests.mjs`: Codex 매니페스트 생성기. `--check` 로 drift 가드, `--dry-run` 으로 출력 미리보기.

## 플러그인 변경 규칙

- 플러그인 버전을 올릴 때는 `plugins/<name>/.claude-plugin/plugin.json`과 `.claude-plugin/marketplace.json`의 해당 항목을 같은 변경에 포함하세요.
- 어떤 플러그인 버전이든 변경하면 `.claude-plugin/marketplace.json`의 `metadata.version`도 marketplace release 버전으로 올리세요.
- 플러그인을 추가하거나 제거하면 루트 `CLAUDE.md`의 플러그인 수와 구조, `README.md`의 플러그인 수와 목록도 갱신하세요.
- 버전은 semver를 따릅니다. 버그 수정은 PATCH, 하위 호환 기능은 MINOR, 깨지는 변경은 MAJOR입니다.
- Claude Code 플러그인 캐시 이슈 때문에 사용자 문서나 릴리스 안내에는 필요 시 `rm -rf ~/.claude/plugins/cache/my-claude-plugins/` 후 marketplace update 및 Claude Code 재시작 절차를 유지하세요.

## Known limitation — cr-fix portability

`plugins/github-dev/skills/cr-fix/SKILL.md` 의 36여 path 가 marketplace-repo-relative (`plugins/github-dev/skills/cr-fix/scripts/...`) 로 하드코딩되어 있어, marketplace repo 가 cwd 일 때 (dogfood) 만 동작합니다. 일반 user repo / Codex 양쪽에서 깨집니다 — 이건 shared-source bridge 이전부터 있던 cr-fix 자체의 구조적 결함이고, 별도 follow-up 으로 portable 화 예정 (`${CLAUDE_PLUGIN_ROOT}` 또는 동등한 env-var 사용으로 일관화).

## Codex 통합 (shared-source)

- Claude 와 Codex 0.135 가 **동일한** `plugins/<name>/` 트리를 직접 읽습니다. 별도 mirror / body transform 없음 (구 `codex-bridge` 플러그인은 1.40.0 에서 제거).
- Codex 매니페스트는 `scripts/sync-codex-manifests.mjs` 가 `.claude-plugin/marketplace.json` 으로부터 생성합니다. `.agents/` 와 `plugins/<name>/.codex-plugin/` 하위 파일은 손으로 편집하지 마세요 — `sync-codex-manifests.mjs` 가 진실의 원천입니다.
- 새 플러그인 추가 / 기존 플러그인의 `version` / `description` / `category` 변경 시 반드시 `node scripts/sync-codex-manifests.mjs` 를 실행해 매니페스트를 재생성하세요.
- Skill `description` frontmatter 는 1024자 미만으로 유지하세요. Codex 0.135 는 1024자 초과 description 을 가진 skill 을 **silent 하게 skip** 합니다 (Claude Code 는 제한이 없어 위반이 안 보임). `--check` 가 drift 외에 description 길이도 검증하고, 공유 `.githooks/pre-commit` 이 매 커밋마다 실행합니다 — clone 당 한 번 `git config core.hooksPath .githooks` 로 활성화하세요. 전체 trigger 목록 / per-tool rationale 는 description 이 아니라 skill 본문에 두세요.
- Skill `description` frontmatter 에 콜론+공백(`: `) 이 들어가면 반드시 따옴표로 감싸세요 (또는 `>-` block scalar). 안 하면 YAML frontmatter 가 nested mapping 으로 파싱돼 `mapping values are not allowed here` 로 실패하고 skill 이 양쪽 런타임에서 silent 하게 로드 안 됩니다. `plugin.json` / `marketplace.json` 은 JSON 이라 무관; lenient 매니페스트 생성기와 `--check` 는 못 잡습니다.
- Codex 0.135 manifest top-level 은 `skills` / `hooks` / `mcpServers` / `apps` 만 지원합니다 (참조: `~/.codex/skills/.system/plugin-creator/references/plugin-json-spec.md`). `commands` / `agents` 는 생성기가 emit 하지 않습니다 — Claude 만 인식하는 필드입니다.
- Codex 에서 제외할 플러그인은 `scripts/sync-codex-manifests.mjs` 의 `EXCLUDED` 셋에 등록하세요 (현재: `core-config`, `midjourney`, `codex-image`). `core-config` 는 Claude-only hooks 라 Codex 에 대응 surface 가 없고, `midjourney` 는 image-gen workflow 가 Codex 실행 모델과 맞지 않으며, `codex-image` 는 Claude->Codex 브리지라 Codex 로 sync 하면 순환입니다. 이후 marketplace 에서 제거된 플러그인은 EXCLUDED 에 남길 필요 없습니다 — drift 가드의 orphan 감지가 매니페스트 잔존을 잡아냅니다.
- 생성기는 Node 18+ built-in 만 사용합니다. 런타임 의존성을 추가하지 마세요.

## 검증

- Codex 매니페스트 drift 가드 (모든 PR 에서 실행):

```bash
node scripts/sync-codex-manifests.mjs --check
```

- 로컬 Codex CLI 에서 marketplace 등록 확인:

```bash
codex plugin marketplace add ~/.claude/plugins/marketplaces/my-claude-plugins
codex plugin list --marketplace my-claude-plugins   # 19 entries
codex plugin marketplace remove my-claude-plugins   # 검증 후 정리
```

- Python 테스트가 필요한 경우 해당 플러그인 디렉터리에서 `uv run pytest`를 우선 사용하세요.

## 문서 작성 스타일

- 사용자-facing 문서는 한국어 설명을 자연스럽게 유지하고, 명령어와 경로는 코드 포맷으로 표기하세요.
- README류 문서는 실제 설치/사용 흐름을 우선하고, 플러그인 수, 플러그인 이름, 명령어 예시는 매니페스트와 일치시켜야 합니다.
- 큰 구조 변경 없이 문서만 보강하는 경우에도 관련 count, badge, 목록이 stale하지 않은지 확인하세요.

## Review guidelines

> 이 섹션은 Codex GitHub cloud reviewer 가 자동으로 읽는 영역이다. 한국어로 리뷰한다. 발견사항은 영향 + 근거 (파일/라인) + 수정 방향 순서로 제시한다. 근거가 부족하면 `unverified` 로 표시한다.

### Do not flag (린터/포매터 영역)
- 들여쓰기, 따옴표 스타일, trailing whitespace — 포매터 영역.
- import 순서, 한 줄 helper 추출 — 결함이 아니면 skip.
- 단순 typo / 영문 문법 — 의미 오류 아니면 skip.
- Markdown 줄바꿈 / 줄간격 micro-optimization — 가독성 문제 아니면 skip.

### P0 — Correctness / Security
- Secret / API key / token 노출 (사용자 GitHub PAT, OpenAI/Anthropic key 등).
- `gh api` / `gh pr merge` / `gh repo create` 류 destructive 명령이 사용자 확인 없이 실행되는 흐름.
- Codex 매니페스트 손으로 편집 — `.agents/plugins/marketplace.json` / `plugins/*/.codex-plugin/plugin.json` 는 `scripts/sync-codex-manifests.mjs` 출력. 수동 편집은 다음 `--check` 에서 drift 로 잡혀야 함.
- Shell injection — 사용자 입력을 quote 없이 shell 명령에 합치는 경우.

### P1 — Performance / Maintainability
- **Plugin versioning 위반** — `plugins/<name>/.claude-plugin/plugin.json` 와 `.claude-plugin/marketplace.json` 의 version 불일치, `metadata.version` 누락.
- **Plugin count drift** — 루트 `CLAUDE.md` / `README.md` 의 플러그인 수 / badge / 트리가 marketplace.json 과 어긋남.
- **`gh api --paginate` + `--jq` 조합에 `--slurp` 누락** — multi-page 응답에서 jq 가 multiple JSON document 받음. 단, `gh` 는 `--slurp` 와 `--jq` 동시 사용을 거부하므로 `gh api --paginate --slurp ENDPOINT | jq ...` 패턴을 쓴다.
- **Idempotency 회귀** — 같은 디렉토리 재실행 시 사용자 파일 덮어쓰기, `git commit` 이 변경 없을 때 `nothing to commit` 으로 abort, 이미 등록된 `origin` remote 에 `gh repo create --remote=origin` 충돌, 등. `[ -f X ] || cp ...` / `git diff --cached --quiet` / `git remote get-url origin` 류 가드를 한 곳에 모아 점검.
- **Cross-platform shell 가정** — `sed -i 'cmd'` 는 GNU-only, BSD/macOS 는 `sed -i '' 'cmd'` 시그니처. `${VAR,,}` 는 Bash 4+ 전용이라 macOS 기본 `/bin/bash` 3.2 에서 bad substitution 으로 깨짐. 둘 다 detect+branch (`sed --version`) 또는 POSIX alternative (`tr '[:upper:]' '[:lower:]'`) 사용.
- **사용자 입력 substitution safety** — `sed` replacement 에서 `&` 는 매치 전체로 확장되고 `\` / 구분자 (`|` 등) 도 escape 필요. 사용자 입력을 placeholder 로 sed 에 넣기 전 `sed 's/[\\&|]/\\&/g'` 류로 정화. `AskUserQuestion` 라벨 (`"X (Recommended)"`) 을 그대로 변수에 넣어 파일 경로 / CLI 플래그 토큰으로 쓰지 말 것 — case-match 로 도메인 토큰 (`general` / `private` 등) 추출 후 사용.
- **API 실패와 빈 결과 구분** — `gh api ... || echo "[]"` 같은 패턴은 네트워크 / rate-limit / 권한 에러를 "결과 없음" 으로 삼켜 사용자가 잘못된 결정을 내리게 함. 실패 시 명시적 `exit 2` 또는 stderr 로그 + 호출자 통보.
- Skill / command 의 frontmatter 누락 또는 잘못된 `name:` / `description:` (Codex 가 skill 을 인식 못 함).
- `Read` / `Edit` 가능한 영역을 `Bash cat` / `Bash sed` 로 우회 (Claude Code 도구 우선 규칙 위반).
- 새 dependency, GitHub Actions, CI/CD 권한 변경 — 최소 권한, lockfile, supply-chain.

### Domain-specific (Claude Code plugin marketplace)
- 새 플러그인 추가 / 제거 PR 은 `CLAUDE.md` 플러그인 수, `README.md` badge + 표 + detail + 트리, `CLAUDE.md`/`README.md` 의 Codex-eligible count (total − 3 excluded: core-config·midjourney·codex-image), `marketplace.json` entry + `metadata.version`, `.claude/settings.json` 의 `plugins.local` entry, 그리고 `node scripts/sync-codex-manifests.mjs` 재실행 — 동시 업데이트 필수. Codex-eligible count 는 version 파일도 `--check` 도 못 잡으니 수동 확인.
- Codex 매니페스트 (`plugins/*/.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`) 가 `--check` 통과해야 함. 수동 편집 흔적 검토.
- Plugin 캐시 이슈 ([anthropics/claude-code#17361](https://github.com/anthropics/claude-code/issues/17361), [anthropics/claude-code#19197](https://github.com/anthropics/claude-code/issues/19197)) — version bump 만으로는 사용자 캐시 갱신 보장 안 됨. 사용자 안내에 `rm -rf ~/.claude/plugins/cache/my-claude-plugins/` 절차 유지.

## CodeRabbit / Codex 조율

이 저장소는 PR 머지 전 자동 리뷰로 **CodeRabbit + ChatGPT-Codex** 를 사용한다. `/github-dev:cr-fix` 스킬이 양쪽을 동시에 처리한다 (`plugins/github-dev/skills/cr-fix/SKILL.md` + `references/` + `scripts/`). PR-bot rate-limit 시 `--cr-source auto` 가 로컬 `coderabbit` CLI 또는 Codex-only 로 silent fallback (~30s 감지, 1800s spin 해소).

| Source | Tier 정책 |
|--------|-----------|
| CR `🚨 Bug` / `⚠️ Potential issue` / `🔒 Security` / `🔴 Critical-High` / `🟠 Major` | `gated` — per-issue 확인 |
| CR `🛠️ Refactor` (`🟡 Minor` / `🟢 Trivial` / `🟢 Info`) | `auto` — 자동 적용 |
| CR `📝 Nitpick` | `skip` |
| Codex P1 (red), P2 (yellow) | `gated` |
| Codex P3 (green) | `skip` |

cr-fix 기본 동작 (둘 다 default ON, opt-out flag): **minor soft-stop** — iter 2 부터 low-severity-only 사이클(deferred 0)이면 `final_state=minor_floor` 로 조기 정지(auto-merge 불가, `user_declined` 동급), `--no-minor-stop` 으로 비활성화. **same-file generalization** — `real` + high-confidence + grep 가능한 finding 은 같은 파일 내 동일 패턴 형제 위치도 같은 커밋에 수정(cross-file 절대 금지, `generalized_to` audit log), `--no-generalize` 으로 비활성화. `/github-dev:post-merge` 는 머지 후 cr-fix state 파일의 deferred/cap-stopped 항목을 `leftover-reviews:` 체크포인트 한 줄로 surface 한다 (informational, 정리 차단 안 함).
