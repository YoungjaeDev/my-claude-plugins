# PROGRESS

## 골 검토 요약 (Step 8 자동 생성)

- 이슈: #199 (이 골) / 선행 조건 #198 (플러그인 흡수, 수동), PR #200 `c56bd25` 로 해소됨
- 목표: 자립 스킬 `skill-forge` 를 `docs-forge` 안에 만들고 3런타임 silent failure 5종을 차단하는 가드를 붙인다
- 마일스톤: 선행 확인 / skill-forge / 자기검수 / 가드
- 필수 검증: `sync-codex-manifests --check`, `sync-hermes-manifests --check`, `check-skill-tool-portability --check`, `check-doc-consistency`, `check-shell-portability`, `check-skill-contract`, `measure-skills`
- scope 잠금: 플러그인 흡수·rename 실행 금지(#198), `docs/audit/` 기존 파일 수정 금지, 전수 검토 착수 금지, 외부 마켓플레이스 스킬 참조 금지

---

## 현재 골

스킬을 쓰고·진단하고·전수 검토하는 자립 스킬 `skill-forge` 를 `docs-forge` 안에 만들고, 3런타임에서 조용히 깨지는 위반 5종을 차단하는 가드를 붙인다.

## 현재 마일스톤

전체 완료 — 마일스톤 1·2·3·4 종료, 필수 검증 7/7 통과

## 완료

### 마일스톤 1 — 선행 확인 (2026-08-10)

**판정 1. Hermes 어댑터 생존 — 유효 (재확인)**

- `ls plugins/*/plugin.yaml | wc -l` = 4
- `node scripts/sync-hermes-manifests.mjs --check` → `up to date (8 adapter files, 4 plugins)`, exit 0
- `scripts/manifest-eligibility.mjs:17-22` `HERMES_ELIGIBLE` = `github-dev`, `docs-forge`, `code-scout`, `ml-toolkit`

**판정 2. `argument-hint` 는 스킬 프론트매터에서 인식된다 — 확인됨**

- Claude Code: 공식 문서 <https://code.claude.com/docs/en/skills> 의 frontmatter reference 표에 optional 필드로 문서화 — "Hint shown during autocomplete to indicate expected arguments."
- Codex 0.135: `~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py:414-453` 의 스킬 프론트매터 검증은 `name` / `description` / `disable-model-invocation` 만 본다. 스킬 쪽에는 allowed-key whitelist 가 없어 `argument-hint` 는 무시된다 (에러 아님).
- Hermes: 생성 어댑터 `plugins/<name>/__init__.py:32-39` 가 `description` 만 읽는다 — 무해.
- **단, Agent Skills 표준 배포 경로**(claude.ai 업로드 / Skills API / `package_skill.py`)는 `name`·`description`·`license`·`compatibility`·`metadata`·`allowed-tools` 6필드만 허용하고 초과 키는 hard error 다. 공식 문서가 그 에러 메시지 예시로 정확히 `argument-hint` 를 든다.
- 결론: 3런타임에서는 안전. 유일한 금지 근거는 "표준 외부 배포 경로에서 깨진다" 이며, 현재 2건(`codex-image:codex-image`, `publish:tally-form`)은 그 경로를 쓰지 않으므로 제거 강제 대상이 아니다. 스펙 D12 의 "`argument-hint` 는 커맨드 필드다" 는 근거가 **틀렸다** — 스킬 필드이기도 하다.

**판정 3. `disable-model-invocation` 은 Claude Code 에서 동작하나 Codex 검증과 충돌한다 — 확인됨(일부 unverified)**

- Claude Code: 공식 frontmatter 표에 optional 로 문서화 + `~/.claude/cache/changelog.md:99` / `:2366` 두 항목이 실동작 변경 이력을 남긴다 (`disable-model-invocation: true` 스킬의 `/<skill>` 호출 버그 수정, 모델이 호출 시도할 때의 거절 문구 개선).
- Codex 0.135: `validate_plugin.py:447-453` — 값이 `None`/`False` 가 아니면 `must be false` 검증 에러. Codex-eligible 플러그인(현재 12개)의 스킬에서 `true` 를 쓰면 Codex plugin validation 이 실패한다.
- `unverified` 로 남는 부분: 이 validator 는 Codex 의 **저작·검증** 도구다. Codex **런타임 로더**가 같은 규칙을 강제하는지(로드 시 skip 인지 단순 무시인지)는 확인하지 못했다.
- 결론: Codex-eligible 플러그인 스킬에서는 `true` 를 쓰지 않는다 (근거 있는 금지). `CODEX_EXCLUDED` 2개(`codex-image`, `council`)는 제약 밖.

**부수 실측** — `version` 은 Claude Code 공식 frontmatter 표에도, Agent Skills 6필드에도 없다. 어느 런타임도 읽지 않는 no-op 필드다 (현재 3건). `license` 는 공식 표에 있고 Claude 는 "accepts but doesn't act on it", Agent Skills 6필드 안에도 있다 — 유효하되 무동작 (현재 1건).

### 마일스톤 2 — skill-forge (2026-08-10)

착수 전 확정한 PRD Open questions 2건 (사용자 결정):

- **이식 범위** — 이 저장소 전용. `references/runtime-contract.md` 가 3런타임 계약을 분기 없이 그대로 서술한다.
- **fleet-review 팬아웃 축** — 7축 전부 절차까지 구현. 실행(스킬 50개 전수 검토)은 여전히 골 범위 밖이라 돌리지 않는다.

산출물 9개:

| 파일 | 비고 |
|---|---|
| `skills/skill-forge/SKILL.md` | 172줄, frontmatter `name` + `description` 만, description 793자 |
| `skills/skill-forge/references/frontmatter.md` | M1 판정 3건을 필드별 규칙으로 반영, `unverified` 1건 명시 |
| `skills/skill-forge/references/writing-levers.md` | 포인터·두 부하·정보 계층·완료 기준·leading word·negation·pruning 5종 |
| `skills/skill-forge/references/structure.md` | 섹션 순서·분량·번들 디렉터리·툴 프레이밍·품질 실패 5종·명명 |
| `skills/skill-forge/references/runtime-contract.md` | silent failure 7종 표 + resolver 블록 + 패키징 의무 |
| `skills/skill-forge/scripts/measure-skills.mjs` | Node 18+ built-in 만, `--csv` / `--json` / `--selftest` |
| `skills/skill-audit/SKILL.md` | 112줄, description 782자 |
| `skills/skill-fleet-review/SKILL.md` | 142줄, description 755자 |
| 버전·문서 | `plugin.json` 0.4.0 → 0.5.0, marketplace 엔트리 + `metadata.version` 2.13.0 → 2.14.0, Codex/Hermes 매니페스트 재생성, `README.md` 3곳 + `plugins/docs-forge/CLAUDE.md` |

`measure-skills.mjs --selftest` 4케이스 통과 (plain / quoted / block scalar / frontmatter 없음). 전 저장소 실행 결과 스킬 50 → 53, 프론트매터 키 인벤토리 `description 53 / name 53 / allowed-tools 15 / version 3 / argument-hint 2 / license 1`.

### 마일스톤 3 — 자기검수 (2026-08-10)

산출물: `docs/audit/2026-08-10-absorption-check.md`. 흡수 자체는 건드리지 않았고 rename 은 0건 실행했다.

- **live 참조 0건 확정.** VALIDATION 의 GONE grep 이 hit 1건(`plugins/docs-forge/CLAUDE.md:243`, write-rules Version History 의 `2.0.0 BREAKING` 항목 안 `/rules-forge:generate`·`/rules-forge:split` 제거 안내)을 냈고, **이력**으로 판정했다. 그 줄을 `docs-forge:` 로 고치면 그 커맨드가 docs-forge 아래 존재한 적 있다고 거짓 주장하게 된다. VALIDATION 이 예상한 "알려진 이력 hit 2건" 은 같은 줄 안의 2회 출현이었다.
- **P1 (스킬 본문) 1건** — `plugins/llm-wiki/skills/plaud-note-taking/SKILL.md:38-40` 이 Hermes eligibility 를 `plaud-note-taking` 이라는 플러그인 기준으로 서술한다. 그 플러그인은 없어졌고 검사 대상은 `llm-wiki` 다. 결론(어댑터 없음, bare 로드)은 우연히 여전히 맞지만 근거가 깨졌다.
- **P1 (본문 밖) 1건** — `README.md` 접이식 플러그인 카탈로그가 흡수된 11개 플러그인의 `<details>` 절을 그대로 갖고 있고, 신설 `publish` 절은 없다. 절 내부 커맨드는 새 네임스페이스로 치환됐는데 `<summary>` 제목만 남았다 → 의도된 이력이 아니라 잔재. `check-doc-consistency` 는 구조 트리·AGENTS 표·카운트 문자열만 봐서 이 영역을 못 본다. **이 골에서 고치지 않고 후속 이슈로 권고**했다 (12개 절 재작성은 별도 변경, 마일스톤 3 은 검수 범위).
- **트리거 충돌 0건** (docs-forge 11개 스킬). 근접 사례 2건을 근거와 함께 기록 — 인터뷰를 실제로 수행하는 스킬이 3개지만 트리거로 광고하는 건 `interview-methodology` 하나뿐이고, `voice-prompt` 의 명시적 부정 트리거가 `tcrei-prompt` 와의 충돌을 막고 있다(제거하면 충돌 발생).
- **rename 0건 실행 / 6건 후보 보류.** 골이 rename 실행을 금지하므로 판정만 기록. `-guide` 4종은 동명 커맨드 1:1 충돌 회피라 rename 대상 아님으로 확정.
- **P2 3건** — `tcrei-prompt:292` 의 "this plugin" 지시 대상 이동(내용은 여전히 참, docs-forge 에 `agents/` 없음), no-op `version` 키 3건, `license`/`argument-hint` 각 1건.

### 마일스톤 4 — 가드 (2026-08-10)

`scripts/check-skill-contract.mjs` — Node 18+ built-in 만 (외부 import 0). 차단 검사 5종:

| # | 검사 | 탐지 방식 |
|---|---|---|
| 1 | `description` > 1024자 | block scalar 는 folded 값 길이로 판정 |
| 2 | 인용 없는 `: ` | plain scalar 일 때만 `:(공백\|줄끝)` 검사. `\|` / `>` block scalar 와 따옴표 scalar 는 통과 (`tcrei-prompt` 가 `\|` 를 써서 실제로 안전) |
| 3 | 셸 블록의 bare `${CLAUDE_PLUGIN_ROOT}` | **펜스 코드블록 안**의 사용만 보고, 파일 어디든 `${CLAUDE_PLUGIN_ROOT:-` 형태(= resolver/capability probe)가 있으면 면제 |
| 4 | 비-kebab 또는 64자 초과 `name` | `^[a-z0-9]+(-[a-z0-9]+)*$` |
| 5 | frontmatter 가 byte 0 에서 `---` 로 시작하지 않음 | 시작·종료 both |

검사 3의 설계 근거: 산문에서 이 변수를 **위반 사례로 언급**하는 본문이 실제로 있다(`deepwiki:ask`, `project-init:new` 는 Claude 경로와 Codex 경로를 나란히 설명한다). 파일 단위로 리터럴만 보면 이 둘이 오탐이 되어 멀쩡한 서술을 고치게 만든다. 실패는 "셸이 빈 접두사로 실행된다" 이므로 코드블록으로 한정하고, resolver 존재를 면제 조건으로 삼았다. 현재 저장소 53개 스킬 위반 0건, 오탐 0건.

fixture 는 **매 실행 시 스캔보다 먼저** 돈다 (5 RED + 1 GREEN, 인메모리). 탐지기가 조용히 망가지면 스캔이 통과하는 대신 커밋이 막힌다. `--selftest` 로 단독 실행 가능.

배선: `.githooks/pre-commit` 1곳 + `.github/workflows/validate-codex.yml` 1곳. 기존 가드 4종과의 비중복은 스크립트 상단 주석과 `README.md` "CI 가드가 지키는 것"(6종 → 7종)에 명시.

## 마지막 검증 결과

```text
2026-08-10, 마일스톤 4 종료 = 최종 완료 판정 시점 (전 파일 staged 상태)

node scripts/sync-codex-manifests.mjs --check         OK  up to date (13 manifests)
node scripts/sync-hermes-manifests.mjs --check        OK  up to date (8 adapter files, 4 plugins)
node scripts/check-skill-tool-portability.mjs --check OK  5 pilots, 15 baseline, 0 unaccounted
node scripts/check-doc-consistency.mjs                OK  14 plugins, Codex 12, Hermes 4
node scripts/check-shell-portability.mjs              OK  240 files, no unguarded GNU-only construct
node scripts/check-skill-contract.mjs                 OK  53 skills, 5 checks, selftest 5 RED + 1 GREEN
node .../skill-forge/scripts/measure-skills.mjs       OK  exit 0

필수 검증 7/7 통과.

주의 — check-shell-portability 는 git-tracked 파일만 스캔한다. 신규 파일을 스테이징하기
전에는 232개, 스테이징 후 240개였다. untracked 상태로 이 가드를 돌리면 새 파일을 한 줄도
보지 않고 통과한다.
```

```text
2026-08-10, 마일스톤 3 종료 시점 — 기존 6종 전부 OK (출력은 마일스톤 2 와 동일),
docs/audit/2026-08-10-absorption-check.md 존재 확인.
check-skill-contract.mjs 는 여전히 미생성 (마일스톤 4 산출물).
```

```text
2026-08-10, 마일스톤 2 종료 시점

node scripts/sync-codex-manifests.mjs --check        OK  up to date (13 manifests)
node scripts/sync-hermes-manifests.mjs --check       OK  up to date (8 adapter files, 4 plugins)
node scripts/check-skill-tool-portability.mjs --check OK  5 pilots, 15 baseline, 0 unaccounted
node scripts/check-doc-consistency.mjs               OK  14 plugins, Codex 12, Hermes 4
node scripts/check-shell-portability.mjs             OK  232 files, no unguarded GNU-only construct
node .../skill-forge/scripts/measure-skills.mjs      OK  exit 0, --selftest 4/4
node scripts/check-skill-contract.mjs                미생성 — 마일스톤 4 산출물

부수: check-skill-prose 신규 스킬 관련 경고 0건. cr-fix / convene 테스트 통과.
mock-load-hermes 는 로컬 PyYAML 부재로 skip (pre-commit 설계상 skip, CI 가 강제).
```

```text
2026-08-10, 마일스톤 1 종료 시점

node scripts/sync-codex-manifests.mjs --check        OK  up to date (13 manifests)
node scripts/sync-hermes-manifests.mjs --check       OK  up to date (8 adapter files, 4 plugins)
node scripts/check-skill-tool-portability.mjs --check OK  5 pilots, 15 baseline, 0 unaccounted
node scripts/check-doc-consistency.mjs               OK  14 plugins, Codex 12, Hermes 4
node scripts/check-shell-portability.mjs             OK  232 files, no unguarded GNU-only construct
node scripts/check-skill-contract.mjs                미생성 — 마일스톤 4 산출물
node .../skill-forge/scripts/measure-skills.mjs      미생성 — 마일스톤 2 산출물
```

필수 검증 7종 중 2종은 이 골 자신의 산출물이라 해당 마일스톤 이전에는 존재할 수 없다. "매 마일스톤 종료 시 7종 전부 통과" 를 문자 그대로 적용하면 마일스톤 1 에서 교착한다. 채택한 해석: 매 마일스톤 종료 시 7종을 전부 시도하되, 아직 만들지 않은 산출물은 `미생성` 으로 기록하고 **최종 완료 판정 시점에는 7종 전부 통과**를 요구한다. 이미 존재하는 검증이 실패하면 다음 마일스톤에 진입하지 않는다 (엄격도 유지).

## 실패 시도

| 시도 | 변경 | 결과 | 배운 점 |
| --- | --- | --- | --- |
| M2-1 | 신규 스킬 3종의 진단 축 표와 pitfalls 표에 `AskUserQuestion` 을 실패 사례로 리터럴 표기 | `check-skill-tool-portability --check` 가 3건 전부 `unaccounted` 로 차단 (exit 1) | 이 가드의 탐지기는 "본문에 그 리터럴이 있는가" 다. compat-table 행과 `allowed-tools:` 줄만 예외라, **도구를 사용하는** 스킬과 **도구를 서술하는** 스킬을 구분하지 못한다. baseline 등록(= 부채가 있다고 거짓 기록)이나 PILOTS 등록(= 없는 게이트의 매핑 블록 추가)은 둘 다 가드에 거짓말을 하는 것이므로 기각. 대신 세 본문의 표 셀을 `references/runtime-contract.md` 포인터로 바꿔 리터럴을 references(가드 스캔 밖)로 옮겼다. 우연히 이 골 자신의 단일 진실 원천 규칙과 일치한다 — 표 셀은 그 표의 압축 재기술이었다 |

## 현재 가장 안정적인 상태

마일스톤 4 완료 — 필수 검증 7/7 통과, 전 산출물 staged.

## 다음 단계

커밋 → PR → 자동 리뷰(`/github-dev:cr-fix`). 이 골 범위 밖으로 남긴 후속 작업:

1. **README 플러그인 카탈로그 정리 (후속 이슈 권고)** — 흡수된 11개 플러그인의 `<details>` 절 제거·재배치 + 신설 `publish` 절 추가. 함께 `check-doc-consistency.mjs` 를 확장해 `<summary>` 이름 집합도 registry 와 대조하면 같은 drift 가 재발하지 않는다.
2. **`plaud-note-taking` P1 수정** — Hermes eligibility 서술의 주어를 `plaud-note-taking` → `llm-wiki` 로 (llm-wiki PATCH 범프 필요).
3. **스킬 50+ 전수 검토** — `docs-forge:skill-fleet-review` 는 이 골에서 만들었을 뿐 돌리지 않았다. 별도 이슈.
4. **rename 후보 6건** — `docs/audit/2026-08-10-absorption-check.md` §4 에 근거와 함께 보류로 기록.
5. **no-op `version` frontmatter 키 3건 제거** — 어느 런타임도 읽지 않는다.

## 리스크 / 블로커

해소됨:

- ~~이식 범위 미정~~ — 이 저장소 전용으로 확정 (사용자 결정, 마일스톤 2 착수 시).
- ~~fleet-review 팬아웃 축 범위 미정~~ — 7축 전부 절차까지 구현으로 확정 (사용자 결정).
- ~~"소멸 플러그인 참조 0건" 의 오작동 위험~~ — live 판정 1건, 이력 보존. `.llmwiki/` · `tests/fixtures/` · `docs/` · `.claude/spec/` 는 스캔에서 제외했고 한 줄도 수정하지 않았다.

남은 것:

- `README.md` 플러그인 카탈로그의 흡수 잔재 11건 + `publish` 누락 1건. 어떤 가드도 `<summary>` 영역을 보지 않아 머지를 통과했다. 이 골에서 고치지 않고 후속 이슈로 넘겼다 (마일스톤 3 은 검수 범위).
- `check-shell-portability` 가 git-tracked 파일만 스캔한다는 점. 신규 파일을 staged 하지 않고 검증하면 조용히 통과한다. 이번에는 스테이징 후 재실행으로 확인했다 (232 → 240 파일).
- `disable-model-invocation` 의 Codex **런타임 로더** 강제 여부는 여전히 `unverified`. 확인된 것은 Codex plugin **validator** 가 `true` 를 거부한다는 사실뿐이고, `references/frontmatter.md` 에 그 범위대로 적혀 있다.

## 인수인계 메모

이 PROGRESS.md는 골잡이가 생성했다. 골 실행 중 매 체크포인트마다 갱신된다.
