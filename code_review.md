# Code Review Guidelines

> 이 저장소의 상세 코드 리뷰 룰. `AGENTS.md`의 `## Review guidelines`가 이 파일을 참조하고, Codex 리뷰어는 참조를 따라 이 파일을 읽을 수 있다 (소프트 개런티, <https://developers.openai.com/codex/learn/best-practices>). GitHub cloud reviewer는 P0/P1만 코멘트로 표면화한다.
>
> 한국어로 리뷰한다. 발견사항은 영향, 근거(파일/라인), 수정 방향 순서로 쓴다. 근거가 부족하면 `unverified`로 표시한다.
>
> 유지보수: P0/P1 규칙을 추가·삭제하면 `AGENTS.md`의 하드 최소본에도 반영한다. 설명·예시는 이 파일에만 둔다.

## Do not flag

- 들여쓰기, 따옴표 스타일, trailing whitespace, import 순서, 단순 typo, Markdown 줄바꿈.
- 루트 `CLAUDE.md`가 `@AGENTS.md` 한 줄인 것. "내용이 없다"는 지적은 오탐이다. 역방향도 오탐이다: 이 규칙은 루트 한정이고, `plugins/<name>/CLAUDE.md`가 내용을 갖는 것은 정상이다.

## P0 — must block

- **Secret 노출.** GitHub PAT, OpenAI/Anthropic key, token이 코드·문서·로그에 나타나면 차단.
- **확인 없는 destructive `gh`.** `gh pr merge`, `gh repo create`, 상태를 바꾸는 `gh api`가 사용자 확인 없이 실행되는 흐름.
- **Shell injection.** 사용자 입력이 셸에 코드로 도달하는 경우. quote 유무가 기준이 아니다: 값이 명령문 텍스트로 치환되면 값 안의 `'`, 백틱, `$(...)`는 이미 코드다. 값은 데이터 채널로 넘긴다 — 변수에 바인딩해 `"$VAR"`로 쓰거나, quoted heredoc(`<<'EOF'`)에 써서 파일로 읽는다.

## P1 — should block

### 버전·문서 동기화

- `plugins/<name>/.claude-plugin/plugin.json`과 `.claude-plugin/marketplace.json`의 version 불일치, `metadata.version` 누락.
- `AGENTS.md` 플러그인 수·목록, `README.md` 수·badge·트리가 marketplace.json과 어긋남.
- 새 플러그인 추가/제거 PR은 `AGENTS.md` 카운트, `README.md` badge·표·detail·트리, `marketplace.json` entry + `metadata.version`, `.claude/settings.json`의 `plugins.local`을 같은 PR에서 갱신해야 한다.
- 기존 플러그인에 skill 추가 PR은 그 플러그인의 `plugins/<name>/CLAUDE.md` skill 목록을 갱신해야 한다. plugin 수는 안 바뀐다.

### 멱등성

- 같은 디렉토리 재실행이 사용자 파일을 덮어쓰는 경우.
- 변경이 없을 때 `git commit`이 `nothing to commit`으로 abort하는 경우 (`git diff --cached --quiet` 가드 필요).
- 이미 등록된 `origin`에 `gh repo create --remote=origin`이 충돌하는 경우.

### 셸 이식성

- GNU 전용 도구를 폴백 없이 쓰는 경우. 대체: `sed -i 'cmd'` → BSD는 `sed -i '' 'cmd'`, `md5sum` → `cksum`, `sha256sum` → `shasum -a 256`, `date -d` → `date -j -f`, `stat -c` → `stat -f`, `tac` → `tail -r`, `nproc` → `sysctl -n hw.ncpu`, `realpath -m` → `cd` + `pwd -P` (+ 최종 컴포넌트는 `readlink`).
- `${VAR,,}`, `mapfile`, `declare -A`는 Bash 4+ 전용. macOS 기본 `/bin/bash`는 3.2라서 깨진다.
- zsh는 인용 없는 파라미터를 단어 분리하지 않는다. `cmd $MULTI_VALUE`가 한 인자로 넘어가 조용히 아무것도 안 한다. `set -o shwordsplit 2>/dev/null || true`로 요청한다.
- 이식성 수정은 양방향으로 확인한다. `python` → `python3`는 macOS를 고치고 Windows(python.org 설치, `python` + `py`만 존재)를 깬다. 이름 고정이 아니라 후보 탐지(`python3` → `python` → `py -3`)가 정답이다.
- 이식성 검증은 stock 유저랜드에서 한다. 대화형 셸의 `grep` shim(ugrep)이 `grep -P`를 통과시켜도 훅·Codex의 stock grep에서는 깨진다. `env -i PATH=/usr/bin:/bin`로 재확인한다.

### 종료 상태

- 파이프라인 중간 명령의 실패는 `set -e`를 발동시키지 않는다. `H=$(cmd | cut | head)`는 `cmd`가 없어도 exit 0이고 `H`만 빈 값이 된다. 추출 파이프라인에는 `set -o pipefail` 또는 직후 빈 값 가드를 둔다.
- 종료 상태가 검사 신호인 자리에 `|| true`를 붙이지 않는다. SIGTERM(143)과 즉사(127)가 똑같은 "빈 출력"이 되어 검증이 false-green이 된다.
- `cmd -v X && X … || true`는 "X 없음"뿐 아니라 "X 실행 실패"까지 삼킨다. `if cmd -v X; then X …; fi`로 흡수 범위를 한정한다.
- `set -o pipefail`은 만능이 아니다. `for … done | sort`에서 루프 마지막 명령이 정상적인 거짓 테스트면 pipefail이 정상 케이스를 실패로 보고한다. 이 형태는 정렬을 루프 밖으로 뺀다.

### gh / API

- `gh api --paginate` + `--jq` 조합에 `--slurp` 누락. 단 `gh`는 둘의 동시 사용을 거부하므로 `gh api --paginate ENDPOINT | jq -s 'add'` 패턴을 쓴다.
- `gh api ... || echo "[]"`는 네트워크·rate-limit·권한 에러를 "결과 없음"으로 삼킨다. 실패는 명시적 exit 또는 stderr 통보로 구분한다.
- 읽기 실패 삼킴의 write 쌍도 잡는다: 변환 결과를 검사 없이 `gh issue/pr edit --body "$NEW"`로 내보내면 변환 실패가 원격 본문을 공백으로 파괴한다. 원격 write 앞에는 빈 값 가드.
- `sed` replacement의 사용자 입력은 정화한다: `&`는 매치 전체로 확장되고 `\`와 구분자도 escape가 필요하다 (`sed 's/[\\&|]/\\&/g'`). `AskUserQuestion` 라벨을 그대로 경로/플래그 토큰으로 쓰지 않는다 — case-match로 도메인 토큰을 추출한다.

### 스킬·의존성

- skill/command frontmatter의 `name`/`description` 누락·오류. Codex가 skill을 인식하지 못한다.
- `Read`/`Edit`로 가능한 편집을 `Bash cat`/`sed`로 우회하는 경우.
- 새 dependency, GitHub Actions, CI/CD 권한 변경은 최소 권한·lockfile·supply-chain 관점으로 검토.

## Domain-specific (plugin marketplace)

- **플러그인 제거 PR**: `git grep -niE '<name>'`로 저장소 전체(다른 플러그인 skill 본문, `docs/` 포함)에서 살아남은 참조를 제거한다. count 파일만으로는 부족하다. 제거된 플러그인이 생성하던 tracked 산출물도 같은 PR에서 지운다.
- **`metadata.version`은 릴리스 카운터다.** semver가 아니므로 플러그인 제거 같은 breaking 변경도 MINOR로 올린다. semver 규칙은 per-plugin `version`에만 적용된다. "breaking → MAJOR" 지적은 오탐.
- **도입-버전 마커는 bump하지 않는다.** `스킬 3종 (0.7.0)`, `0.7.0부터 ...` 같은 표기는 기능이 언제 들어왔는지의 이력이다. 현재 버전을 추적하는 것은 per-plugin `version`, `metadata.version`, description 카운트 문자열뿐이다.
- **캐시 안내 유지.** version bump만으로 사용자 캐시가 갱신되지 않는다 ([#17361](https://github.com/anthropics/claude-code/issues/17361), [#19197](https://github.com/anthropics/claude-code/issues/19197)). 사용자 안내에 `rm -rf ~/.claude/plugins/cache/my-claude-plugins/` 절차를 유지한다.
