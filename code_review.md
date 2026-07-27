# Code Review Guidelines

> 이 파일은 이 저장소의 **상세 코드 리뷰 룰**이다. 루트 `AGENTS.md` 의 `## Review guidelines` 섹션이 이 파일을 참조한다. OpenAI Codex best-practices 문서 기준, `AGENTS.md` 가 참조하는 `code_review.md` 를 리뷰어가 리뷰 시 따라가 읽을 수 있다(소프트 개런티): *"If you and your team have a `code_review.md` file and reference it from `AGENTS.md`, Codex can follow that guidance during review as well."* (출처: <https://developers.openai.com/codex/learn/best-practices>). GitHub cloud reviewer 는 이 중 **P0 / P1 만 코멘트로 표면화**한다 (<https://developers.openai.com/codex/code-review>).
>
> 한국어로 리뷰한다. 발견사항은 영향 + 근거 (파일/라인) + 수정 방향 순서로 제시한다. 근거가 부족하면 `unverified` 로 표시한다.
>
> 유지보수 노트: `AGENTS.md` 의 `## Review guidelines` 는 여기 P0/P1 **should-block 룰의 하드 주입 최소본**을 함께 싣는다 (soft-follow 는 소프트 개런티라 should-block 을 이 파일로만 두지 않는다). 이 파일에 P0/P1 should-block 룰을 추가·삭제하면 그 하드 최소본에도 반영하라. Domain-specific 체크리스트·rationale·elaboration 은 이 파일에만 둔다.

## Do not flag (린터/포매터 영역)
- 들여쓰기, 따옴표 스타일, trailing whitespace — 포매터 영역.
- import 순서, 한 줄 helper 추출 — 결함이 아니면 skip.
- 단순 typo / 영문 문법 — 의미 오류 아니면 skip.
- Markdown 줄바꿈 / 줄간격 micro-optimization — 가독성 문제 아니면 skip.
- 루트 `CLAUDE.md` 부재 — 이 저장소에서 `CLAUDE.md` 는 `@AGENTS.md` 한 줄을 import 하는 포인터 파일이다. "CLAUDE.md 가 AGENTS.md 와 다르다 / 없다 / 내용이 없다" 는 지적은 오탐.

## P0 — Correctness / Security
- Secret / API key / token 노출 (사용자 GitHub PAT, OpenAI/Anthropic key 등).
- `gh api` / `gh pr merge` / `gh repo create` 류 destructive 명령이 사용자 확인 없이 실행되는 흐름.
- Codex 매니페스트 손으로 편집 — `.agents/plugins/marketplace.json` / `plugins/*/.codex-plugin/plugin.json` 는 `scripts/sync-codex-manifests.mjs` 출력. 수동 편집은 다음 `--check` 에서 drift 로 잡혀야 함.
- Shell injection — 사용자 입력을 quote 없이 shell 명령에 합치는 경우.

## P1 — Performance / Maintainability
- **Plugin versioning 위반** — `plugins/<name>/.claude-plugin/plugin.json` 와 `.claude-plugin/marketplace.json` 의 version 불일치, `metadata.version` 누락.
- **Plugin count drift** — `AGENTS.md` 의 플러그인 수 / 목록, `README.md` 의 플러그인 수 / badge / 트리가 marketplace.json 과 어긋남.
- **`gh api --paginate` + `--jq` 조합에 `--slurp` 누락** — multi-page 응답에서 jq 가 multiple JSON document 받음. 단, `gh` 는 `--slurp` 와 `--jq` 동시 사용을 거부하므로 `gh api --paginate --slurp ENDPOINT | jq ...` 패턴을 쓴다.
- **Idempotency 회귀** — 같은 디렉토리 재실행 시 사용자 파일 덮어쓰기, `git commit` 이 변경 없을 때 `nothing to commit` 으로 abort, 이미 등록된 `origin` remote 에 `gh repo create --remote=origin` 충돌, 등. `[ -f X ] || cp ...` / `git diff --cached --quiet` / `git remote get-url origin` 류 가드를 한 곳에 모아 점검.
- **Cross-platform shell 가정** — `sed -i 'cmd'` 는 GNU-only, BSD/macOS 는 `sed -i '' 'cmd'` 시그니처. `${VAR,,}` 는 Bash 4+ 전용이라 macOS 기본 `/bin/bash` 3.2 에서 bad substitution 으로 깨짐. `realpath -m` 도 GNU-only (BSD 는 `illegal option`) 이고, 맨 `realpath` 는 GNU/BSD 양쪽 다 미존재 경로에서 실패하므로 대체재가 아니다 — 아직 없는 경로까지 다루려면 `cd` + `pwd -P` 로 부모를 해석하되, 최종 컴포넌트 symlink 도 `readlink` 로 따라가야 containment 검사가 뚫리지 않는다. 전부 detect+branch (`sed --version`) 또는 POSIX alternative (`tr '[:upper:]' '[:lower:]'`) 사용.
- **이식성 검증은 stock 유저랜드에서** — 대화형 셸이 `grep` 을 shim (예: ugrep) 으로 라우팅하면 `grep -P` 가 동작하는 것처럼 보여 BSD 파손이 리뷰를 통과한다. 훅은 자식 프로세스라 shim 을 상속받지 않고 Codex/Hermes 에는 아예 없으므로, 이식성 주장은 `env -i PATH=/usr/bin:/bin` 로 재확인한다.
- **사용자 입력 substitution safety** — `sed` replacement 에서 `&` 는 매치 전체로 확장되고 `\` / 구분자 (`|` 등) 도 escape 필요. 사용자 입력을 placeholder 로 sed 에 넣기 전 `sed 's/[\\&|]/\\&/g'` 류로 정화. `AskUserQuestion` 라벨 (`"X (Recommended)"`) 을 그대로 변수에 넣어 파일 경로 / CLI 플래그 토큰으로 쓰지 말 것 — case-match 로 도메인 토큰 (`general` / `private` 등) 추출 후 사용.
- **API 실패와 빈 결과 구분** — `gh api ... || echo "[]"` 같은 패턴은 네트워크 / rate-limit / 권한 에러를 "결과 없음" 으로 삼켜 사용자가 잘못된 결정을 내리게 함. 실패 시 명시적 `exit 2` 또는 stderr 로그 + 호출자 통보.
- Skill / command 의 frontmatter 누락 또는 잘못된 `name:` / `description:` (Codex 가 skill 을 인식 못 함).
- `Read` / `Edit` 가능한 영역을 `Bash cat` / `Bash sed` 로 우회 (Claude Code 도구 우선 규칙 위반).
- 새 dependency, GitHub Actions, CI/CD 권한 변경 — 최소 권한, lockfile, supply-chain.

## Domain-specific (Claude Code plugin marketplace)
- 새 플러그인 추가 / 제거 PR 은 `AGENTS.md`의 플러그인 수, `README.md` badge + 표 + detail + 트리, `AGENTS.md` / `README.md` 의 Codex-eligible count (total − 2 excluded: core-config·codex-image), `marketplace.json` entry + `metadata.version`, `.claude/settings.json` 의 `plugins.local` entry, 그리고 `node scripts/sync-codex-manifests.mjs` 재실행 — 동시 업데이트 필수 (Hermes 는 생성 산출물이 없어 재실행 대상이 아니다). Codex-eligible count 는 version 파일도 `--check` 도 못 잡으니 수동 확인.
- 기존 플러그인에 **skill 추가** PR 은 plugin 수를 바꾸지 않지만 문서 동기화가 필요하다 — 해당 플러그인의 `plugins/<name>/CLAUDE.md` skill 목록, 그리고 version bump 이 `description` 도 바꿨다면 `AGENTS.md` / `README.md` 의 한 줄 설명. 매니페스트 재생성 + `metadata.version` bump 은 그대로 적용.
- **플러그인 제거 PR 추가 주의** — (a) `git grep -niE '<name>'` 로 레포 전체(다른 플러그인 skill 본문·`docs/` 포함, 과거 `.claude/spec/*` 제외)에서 live 참조를 훑어 제거. count 파일만으론 부족하다 (예: `code-scout` 의 `agent-routing.md` 라우팅). 살아남은 참조는 존재하지 않는 플러그인으로 사용자를 안내한다. (b) 삭제된 플러그인이 생성하던 tracked 산출물(예: `workflow-viz` → `docs/architecture/*`)은 orphaned 이니 같은 변경에서 제거. (c) 플러그인 제거는 `metadata.version` **MINOR** bump (MAJOR 아님 — metadata.version 은 per-release counter, semver-breaking 규칙은 per-plugin 스코프; `midjourney` 삭제 선례가 MINOR). 리뷰어의 "breaking→MAJOR" 지적보다 이 컨벤션 우선.
- Codex 매니페스트 (`plugins/*/.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`) 가 `--check` 통과해야 함. 수동 편집 흔적 검토.
- **도입-버전 마커는 bump 하지 않는다** — `스킬 3종 (0.7.0)`·`0.7.0부터 ...`·SKILL.md `(0.7.0)` 절 태그처럼 *기능이 언제 들어왔는지* 표기하는 버전 주석은 현재-버전 진술이 아니라 이력이므로 이후 릴리스에서 그대로 둔다. 현재 버전을 추적하는 건 per-plugin `version`·`metadata.version`·description 개수 문자열뿐. grep 기반 버전 sweep과 패턴매칭 리뷰어(CodeRabbit)가 stale 로 오탐하니 그 사유로 skip.
- Plugin 캐시 이슈 ([anthropics/claude-code#17361](https://github.com/anthropics/claude-code/issues/17361), [anthropics/claude-code#19197](https://github.com/anthropics/claude-code/issues/19197)) — version bump 만으로는 사용자 캐시 갱신 보장 안 됨. 사용자 안내에 `rm -rf ~/.claude/plugins/cache/my-claude-plugins/` 절차 유지.
