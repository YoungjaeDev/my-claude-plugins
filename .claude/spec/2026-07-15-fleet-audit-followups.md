# Fleet Audit 후속 조치 계획 (9건) — my-claude-plugins

> Status: proposed (2026-07-15). 아직 아무것도 구현 안 됨 — Fleet Audit 마일스톤(2.2.0 → 2.5.0 완료) 이후 의도적으로 미룬 9건을 다음 세션이 바로 착수할 수 있게 근거(파일:라인)와 함께 정리한 durable 계획. 착수 전 아래 "Open decisions" 해소가 필요하다. 근거는 조사 시점(2026-07-15) repo 실측이며 9건 전부 `confidence: high`.

## 한눈에 보기 (At a glance)

Fleet Audit 마일스톤(2.2.0→2.5.0)이 끝나면서 "이번엔 일부러 안 고치고 미뤄둔" 9건이 남았다. 이 문서는 그 9건을 **네 묶음(Wave)** 으로 나눠 언제 무엇을 손대야 하는지 정리한다.

쉬운 말로 요약하면 이렇다.

- **묶음 1 (게이트 정합성 버그 2건)**: "승인한 것과 실제로 올라가는 것이 다를 수 있다" 류의 진짜 버그다. `gws-sync` 는 파일 내용이 몰래 바뀌어도 크기·수정시각만 같으면 승인 게이트를 통과시켜 버린다. `cr-fix` 는 리뷰가 이미 성공으로 끝났는데도 "속도 제한 걸림"으로 잘못 판정한다. 둘 다 잘못된 신호로 통제를 우회하는 문제라 값어치가 가장 크다.
- **묶음 2 (state-envelope 실행기록 완결 2건)**: 파이프라인 스킬이 "몇 단계까지 했는지" 기계가 읽을 수 있게 남기는 기록 장치를, 정작 실제 실행 경로에 안 붙여 놓았다. `post-merge` 는 12단계 중 2단계만 기록하고, `project-init` 은 스킬 표면에만 붙고 정작 주 진입점인 커맨드 경로엔 안 붙었다. 원래 이 장치가 잡으려던 "조용한 단계 건너뜀"이 다시 안 보이게 된 상태다.
- **묶음 3 (문서/검증 위생 4건)**: 손이 거의 안 가는 문서·검증 정리다. `slidev` 다크모드 CSS의 주석-값 모순 2줄, 이미 고쳐졌는데 여전히 "미해결"이라고 적힌 `AGENTS.md` 스테일 노트, "고칠 게 없다"로 확인된 `code-scout` 비이슈, 사람이 대화형 세션에서 한 번 돌려봐야 끝나는 `compact` 훅 런타임 검증이다.
- **묶음 4 (설계 먼저 1건)**: `project-init:wiring` 에 15번째 축(언어 서버가 실제로 살아있는지 확인)을 넣자는 요청. 이건 코드를 쓰기 전에 **설계 결정부터** 받아야 한다 — 기존 14개 축은 전부 "파일만 보는" 정적 검사인데, LSP 살아있는지 확인은 프로세스를 띄우고 응답을 기다려야 해서 스킬의 기본 성격(1초 미만, 결정론적, 프로세스 안 띄움)을 깨기 때문이다.

**핵심 판단**: 9건 전부 서로 의존이 없다(`dependencies: []`). 그래서 Wave 순서는 실행 의존이 아니라 **가치·리스크·리뷰 주의도** 순이다. 병렬로 돌려도 되지만, 여러 플러그인이 같은 `.claude-plugin/marketplace.json`(각자의 엔트리 + `metadata.version`)을 건드리므로 그 파일이 유일한 직렬화 지점이다. 특히 `cr-fix`(W1-2)와 `post-merge`(W2-1)는 둘 다 `github-dev` 플러그인이라 같은 버전·같은 marketplace 엔트리를 공유한다 — 이 둘은 한 PR로 묶거나 엄격히 순차 처리해야 충돌이 안 난다.

**ponytail 관점 요약**: W3-3(code-scout)은 사다리 1단("존재할 필요가 있나?")에서 걸린다 — LLM만 읽는 문서의 `//` 주석이고 파서가 없으니 **건드리지 않는 것을 권장**. W3-4(compact 훅)는 에이전트가 스스로 못 돌리는 검증이라 자동화 하네스를 짜지 말고(YAGNI) 사람이 5단계를 한 번 수동 실행 + 한 줄 상태 기록으로 끝낸다.

---

## 의존/그룹 다이어그램 + 섹션 안내

모든 항목이 서로 독립(`dependencies: []`). Wave는 실행 순서 강제가 아니라 가치·리스크 우선순위다. 화살표는 "리뷰 주의도 우선"만 뜻하며, 병렬 실행이 가능하다.

```
가치·리스크 우선  ─────────────────────────────────────────────────────────────►

Wave 1 (게이트 정합성)    Wave 2 (state-envelope)    Wave 3 (문서/검증 위생)      Wave 4 (설계 먼저)
┌───────────────────┐    ┌───────────────────┐      ┌───────────────────┐        ┌───────────────────┐
│ W1-1 gws-sync     │    │ W2-1 post-merge   │      │ W3-1 slidev CSS   │        │ W4-1 wiring LSP   │
│   SHA-256 + mtime │    │   Steps 2-9.5     │      │ W3-2 AGENTS 스테일 │        │   축 "설계 노트"  │
│   [bug]           │    │   record_step [bug]│      │ W3-3 code-scout   │        │   (구현 금지 —   │
│ W1-2 cr-fix       │    │ W2-2 project-init │      │   비이슈 [verify] │        │   결정 먼저)      │
│   rate-limit 가드 │    │   command-path    │      │ W3-4 compact 훅   │        │ [design-first]    │
│   [bug, TDD]      │    │   [feature, TDD]  │      │   검증 [verify]   │        └───────────────────┘
└───────────────────┘    └───────────────────┘      └───────────────────┘
      │                        │                            │                          │
   github-dev·gws-sync    github-dev·project-init      slidev·root·code-scout·      project-init
                                                        core-config
        └── marketplace.json `metadata.version` = 전 항목 공통 직렬화 지점 ──┘
        └── github-dev 공유: W1-2 + W2-1 한 PR로 묶거나 순차 (같은 버전/엔트리) ──┘
```

| 섹션 | 답하는 질문 |
|---|---|
| Wave 1 | 잘못된 신호로 승인·리뷰 게이트를 우회하는 두 버그를 어떻게 막나 |
| Wave 2 | 미완성으로 남은 state-envelope 실행기록을 실제 실행 경로에 어떻게 완결하나 |
| Wave 3 | 손이 거의 안 가는 문서/검증 4건을 어떻게 정리하나 (하나는 "안 하는 게 정답") |
| Wave 4 | wiring 15번째 축은 왜 코드보다 설계 결정이 먼저인가 |
| 설계 먼저 콜아웃 | W4-1(그리고 부분적으로 W2-1/W2-2)에서 코딩 전에 확정해야 할 것 |
| Open decisions | 사용자에게 물어야 하는 결정 통합 목록 |
| 버전 범프 / 조율 | 플러그인 버전·marketplace.json·매니페스트 재생성 공통 규칙 |
| 용어집 | state-envelope, cr-fix 채널, wiring 축 등 |

**신뢰도 표기**: 9건 전부 원 조사에서 `confidence: high` 로 근거(파일:라인)가 확보돼 있다. **낮은 신뢰도 항목은 없다.** 다만 각 항목의 "잔여 리스크"는 정적 검사로 못 지우는 부분(예: slidev 테마 DOM의 다른 불투명 조상, compact 훅의 상류 드롭 버그, 셸에 `sha256sum` 부재)을 명시한다 — 이건 발견 자체의 신뢰도가 아니라 실행 시 확인이 필요한 미지수다.

---

## Wave 1 — 게이트 정합성 버그 (correctness-critical, 병렬 가능)

두 항목은 서로 다른 플러그인(`gws-sync`, `github-dev/cr-fix`)이라 완전 독립이며 동시에 진행 가능. 공통점은 "잘못된 신호가 통제를 우회한다"는 결함 성격.

### W1-1. gws-sync 승인 매니페스트를 파일 내용(SHA-256)에 바인딩 + mtime 비교 기준 명시

- **문제**: `§5b` 승인 매니페스트가 항목당 `{local, action, target, size, mtime}` 만 기록하고, `§6` 실행 직전 재확인도 같은 필드만 비교한다. `§5` 승인과 `§6` 실행 사이에 파일 내용이 바뀌었는데 크기·mtime이 우연히 같으면(`touch -r` 로 mtime 복원, mtime 안 올리는 파일시스템, 백업 복원 등) **승인받지 않은 내용이 조용히 업로드**된다 — diff+승인 게이트가 무력화된다. 별개로 `§3-3` "Changed" 규칙(로컬 mtime > Drive modifiedTime)이 서로 다른 포맷의 두 타임스탬프(로컬 epoch vs Drive RFC3339 UTC 문자열)를 공통 기준 없이 비교해 diff 누락 위험이 있다.
- **근거(확인됨)**: `plugins/gws-sync/skills/gws-sync/SKILL.md:62`(매니페스트 스키마), `:64-69`(JSON 예시), `:70`(§6 재검증 산문), `:57`("Changed" 규칙, 단위/타임존 정규화 없음). 파일 전체에 콘텐츠 해시 없음. CodeRabbit PR #144 코멘트 두 건이 verbatim 확인 — SKILL.md:70 (Data Integrity, Major, "SHA-256 같은 digest를 기록하고 실행 직전에 검증"), SKILL.md:60 (타임스탬프 기준). PR #144는 영어 산문 재작성 스코프였고 이 항목을 "Preserved intact"로 표시 → 병합된 파일에 여전히 열린 갭. `plugins/gws-sync/scripts/` 디렉터리 없음(스킬 본문 산문 + 인라인 `gws` CLI만) — 새 스크립트 불필요. Drive API v3의 `md5Checksum`/`sha256Checksum` 은 read-only·업로드 후 Drive측 값이라 pre-upload 로컬 재확인엔 못 씀.
- **근본 원인**: `§5b/§6` 는 파일이 *사라지거나 편집되는* 것을 잡으려 설계됐고 size+mtime을 "안 바뀜"의 충분한 대리값으로 취급했는데, 이는 충돌 저항성이 없다. 매니페스트가 페이로드가 아니라 메타데이터에 바인딩돼 있다.
- **접근 + 정확한 삽입점**: 한 파일·같은 스킬 안의 두 결함이므로 한 PR로 묶는다(같은 파일 번들 규약). (1) **콘텐츠 바인딩** — `SKILL.md:62` 매니페스트 항목 shape에 `sha256` 추가, `:64-69` JSON 예시에 필드 추가, `§5` 승인 직후·freeze 전에 로컬 파일에서 계산. `:70` 의 기존 "re-read the local file ... and compare" 문장에 `sha256` 재계산·비교를 추가하고, **기존 abort-and-return-to-§3 분기에 접어 넣는다**(별도 에러 경로 불필요, 같은 abort 시맨틱). 해시는 새 의존성 없는 한 줄 OS 명령: `sha256sum "$f" 2>/dev/null || shasum -a 256 "$f"`. (2) **mtime 정규화** — `SKILL.md:57` "Changed" 불릿에 두 타임스탬프를 같은 UTC epoch-seconds 기준으로 변환 후 비교한다고 명시(Drive `modifiedTime` RFC3339 → epoch 파싱). 순수 산문 명확화.
- **스코프 경계(surgical)**: In — `SKILL.md` §5b 스키마+예시, §6 산문(기존 abort 분기에 해시 비교 추가), §3-3 "Changed" 불릿, `gws-sync` 버전 범프. Out — 새 `scripts/` 파일, §7 verify의 Drive측 체크섬 사용, §2/§3-4/타 플러그인 변경, 같은 PR의 다른 두 CR 발견(위치승인 순서 `CLAUDE.md:32`, 캐시매핑 우회 `SKILL.md:46`)은 별개 항목.
- **리스크**: 낮음. 텍스트 전용 + 버전 범프, 제어 흐름 무변경(같은 abort-and-reapprove, 필드 하나 더 비교). 잔여 리스크: 드라이빙 에이전트 셸에 `sha256sum`·`shasum` 둘 다 없을 때(리눅스/맥 하네스에선 드묾) — 하드 실패가 아니라 **warn-and-skip-hash**로 degrade 하도록 명시해 비정상 환경에서 스킬이 벽돌 되는 것 방지.
- **의존성**: 없음. **TDD**: 불가(스킬 본문 산문, 자동 테스트 없음 — 검증은 SKILL.md 재독 + 스크립트 drift-check).
- **노력**: 1 PR, ~4-6 Edit(스키마 라인, JSON 예시, §6 산문, §3 mtime 불릿, plugin.json, marketplace.json), sync-codex 1 라운드, ~10-15분.
- **신뢰도**: high.

### W1-2. cr-fix rate-limit false positive 가드 (poll + pre-flight)

- **문제**: `poll-cr-status.sh` 의 EARLY_CHECK_WINDOW 분기(30초 자기-탈출)와 `pre-flight.sh` 의 rate-limit 게이트-오버라이드가, `sniff-cr-rate-limit.sh` 의 코멘트/리뷰-채널 텍스트 히트만으로 `rate_limited` 로 라우팅한다 — commit-status가 이미 terminal success("CodeRabbit: success — Review completed")로 바뀌었는지 재확인하지 않는다. 결과: 권위 신호(commit-status)는 성공인데 세션은 `rate_limited`(약 6분 리셋)로 오판하는 false positive.
- **근거(확인됨)**: `poll-cr-status.sh:94-104`(sniff 히트 직후 즉시 rate_limited, `s`는 :49에서 한 번 계산·재fetch 없이 :102 exit), `sniff-cr-rate-limit.sh:20-33`(채널 1+2가 PUSH_TIME 이후 매칭 코멘트/리뷰를 무조건 flag, supersession 개념 없음), `poll-cr-status.sh:71-86`(CR_SKIP_GRACE 분기는 매 루프 신선한 `s`/`desc` 재도출이라 자기 교정됨 — 대조군), `pre-flight.sh:172-175`(동일한 무조건 오버라이드), `references/pre-flight-rules.md:99`(결정 매트릭스 행 `success | none | yes(comment hit) | ... -> rate_limited`).
- **근본 원인**: `sniff-cr-rate-limit.sh` 채널 1+2 탐지에 supersession 개념이 없어, PUSH_TIME 이후 과거 매칭 코멘트를 권위-동급 신호로 취급하고, 두 호출 지점이 그 불리언 히트가 (곧 terminal success가 될 수 있는) commit-status 읽기를 덮어쓰게 둔다 — "commit-status가 권위"라는 규칙 위반.
- **접근 + 정확한 삽입점**: (1) `poll-cr-status.sh:~96-104` — sniff 히트 후 `fetch_cr_state()` 를 한 번 더 호출, 신선한 상태가 success/failure면 :88-92 블록처럼 terminal 상태를 emit, 여전히 non-terminal일 때만 `rate_limited` emit. (2) `pre-flight.sh:172-175` — `cr_actionable=true`(신선한 terminal success, free-tier grace 아님) **그리고** `rate_limit_source=='comment'` 일 때 게이트 오버라이드 skip(`description`/`both`는 commit-status description 유래라 권위 유지 → 그대로 오버라이드). (3) `tests/run-tests.sh` 에 stateful `gh` shim(카운터-파일 패턴, 기존 Codex grace-poll 테스트 재사용)으로 RED 테스트: 호출1=pending+rate-limit 코멘트, 호출2+=success/"Review completed" → poll이 `state=success` emit 주장. (4) `references/pre-flight-rules.md:99`, `references/rate-limit-fallback.md`, `SKILL.md:292`(Step 6 산문)에 재확인/억제 가드 반영.
- **스코프 경계(surgical)**: In — poll의 EARLY_CHECK_WINDOW 분기, pre-flight 게이트-오버라이드, 새 fixture 테스트 1개, 위 3개 레퍼런스 문서, `github-dev` 버전 범프. Out — `sniff-cr-rate-limit.sh` 매칭 로직(채널 1-3 유지, 호출자 신뢰만 변경), CR_SKIP_GRACE 분기(이미 자기 교정), active-query fallback(`query-cr-rate-limit.sh`).
- **리스크**: 낮음-중간. 너무 느슨한 가드는 CR이 flapping할 때(실제 rate-limit 코멘트 → 직전 실행의 stale success 행 잔존) 진짜 rate_limited를 억제할 수 있음 — 신선한 commit-status 읽기만 신뢰(캐시 금지) + comment-채널 히트만 억제(description/both는 승리)로 완화. 변경 후 `tests/run-tests.sh` 재실행 필수(`.githooks/pre-commit` + `validate-codex.yml`).
- **의존성**: 없음. **TDD**: 적용(fixture 기반 RED 테스트 선행).
- **노력**: 1 PR, ~8-12 라운드(스크립트 2 + 테스트 1 + 문서 3 + 버전 범프 + 테스트 스위트 실행), ~15-20분.
- **신뢰도**: high.

---

## Wave 2 — state-envelope 실행기록 완결 (병렬 가능)

두 항목은 같은 메커니즘(state-envelope v0, 공유 라이브러리 없이 스킬별 인라인 jq)의 미완성 채택을 마무리한다. 서로 다른 플러그인(`github-dev`, `project-init`)이라 독립. 둘 다 원래 PR(#138/#142)에서 "침습적이라 의도적으로 미룸"으로 defer된 후속.

### W2-1. post-merge: Steps 2-9.5 누락 record_step 추가

- **문제**: `github-dev:post-merge` SKILL.md의 "Recording contract"(`:99`)는 Step 2-10이 닫힐 때마다 `record_step` 를 append하라고 문서화하지만, 실제 코드는 Step 1(`:96`)과 Step 10(`:311-321` 인라인 append+finalize)만 존재. Steps 2,3,4,5,5.5,5.7,6,7,8,9,9.5에 기록 코드가 없어, 정상 실행 시 `steps[]` 가 12개 중 2개만 채워지고 그 사이의 조용한 건너뜀(이 메커니즘이 잡으려던 바로 그 문제)이 다시 안 보인다.
- **근거(확인됨)**: `git log --oneline` 상 b4973f8(#138)이 파일 마지막 커밋. 오늘 파일 읽기(335줄)에서 `record_step` 은 워크플로에 정확히 2회(라인 96, Step 10 블록)만 호출. (현재 확인: `grep -c record_step` = 6줄이나 함수 정의·contract 산문 포함, 워크플로 호출은 2회로 일치.) CR round 3(review id 4690730424, outside-diff SKILL.md 66-97) + round 1(inline id 3575722919, SKILL.md:99) 둘 다 갭 지적. PR 마지막 커밋 4c0059f는 skipped-needs-reason 가드만 추가, Step 2-9.5 호출은 미추가. Steps 1.5/4.5/4.6/6.5만 parent로 fold-in 문서화; 5.5/5.7/9.5는 자체 엔트리 필요로 명시.
- **근본 원인**: PR #138이 메커니즘(스키마/init/record_step/finalize)을 run을 여닫는 두 단계(Step 1 open, Step 10 close)로만 end-to-end 시연하고, 중간 단계용 "Recording contract" 산문만 추가했을 뿐 각 단계 본문에 호출을 기계적으로 삽입하지 않았다.
- **접근 + 정확한 삽입점**: Step 10(`:311-321`)이 이미 쓰는 인라인 4줄 jq append 패턴을 각 단계 종료 지점에 하나씩 추가(셸 상태가 툴 호출 간 유지 안 되므로 record_step() 재선언 대신 인라인 jq — contract `:99` 가 명시 허용). 삽입점: Step 2(`~157`) `record_step 2 done`; Step 3(`~165`); Step 4/4.5/4.6 종료(`~239`, fold-in 규칙에 따라 공유 엔트리 1개) `record_step 4 done`; Step 5(`~244`) done|`skipped "no GitHub Project"`; Step 5.5(`~248`) done|`skipped "no milestone"`; Step 5.7(`~254`) done|`skipped "no spec.json entry"`; Step 6(`~262`) done; Step 7(`~266`) done|`skipped "Codex — Serena unavailable"`(Codex)/`skipped "Serena unavailable"`(Claude); Step 8(`~279`, wiki-ingest 체크포인트 직후) done; Step 9(`~283`) done|`skipped "no README-relevant changes"`; Step 9.5(`~289`) done|`skipped "no CHANGELOG or not changelog-worthy"`. 각 삽입 블록은 `REC=".claude/state/post-merge-${PR_NUMBER}.json"` 를 먼저 재설정하고 Step 10의 `${PR_NUMBER:?...}` 가드 패턴 재사용(PR_NUMBER도 Bash 호출 간 유지 안 됨). `.claude/rules/state-envelope.md` 채택자-레퍼런스 노트 갱신 필요 여부 점검.
- **스코프 경계(surgical)**: In — `post-merge/SKILL.md` 만(Steps 2,3,4,5,5.5,5.7,6,7,8,9,9.5 종료에 record_step/인라인 jq 삽입) + `github-dev` 버전 범프. Out — 스키마/convention 변경, 타 스킬 retrofit, 공유 라이브러리(v0가 명시 거부), Step 1/Step 10 기존 코드.
- **리스크**: 낮음. 추가적 산문/명령. 주 리스크: skip 이유 문자열이 각 단계 실제 skip 조건 산문과 불일치하면 안 됨(grep으로 기존 문구 literal 유지), 그리고 PR_NUMBER가 매 중간 Bash 호출에 스코프 있음을 Step 10처럼 `${PR_NUMBER:?...}` 가드로 강제. 검증은 수동 jq dry-run(init + record_step 호출 + finalize, 유효 JSON/단계수/skip-reason 불변식) + `.githooks/pre-commit`.
- **의존성**: 없음. **TDD**: 불가(스킬 본문 산문 — 수동 dry-run).
- **노력**: 1 PR, ~12-15 라운드(단계별 Edit + 최종 Read 검증), ~15-20분.
- **신뢰도**: high.

### W2-2. project-init: state-envelope record_step를 공유 new-procedure.md에 배선 (command-path 갭)

- **문제**: state-envelope v0(PR #142)가 `skills/new/SKILL.md` Step 0.5(`:40-93`)에만 배선됐다. 주 진입점인 `/project-init:new` **커맨드** 표면(`commands/new.md`)과 두 표면이 공유하는 Phase 0-7 본문(`references/new-procedure.md`)엔 `record_step`/`REC`/finalize 호출이 0개다. `commands/new.md` 는 preflight 가드에서 곧장 "Phase 0-7 따라가라"로 넘어가 Step 0.5 언급이 없어, 커맨드 경로로 부트스트랩하면 run record가 아예 안 열린다 — #142가 선언한 채택이 그 경로에서 안 발화한다.
- **근거(확인됨)**: `skills/new/SKILL.md:40-93`(REC/record_step/finalize 정의처) + `:93` 자체 admission("공유 references/new-procedure.md 배선은 문서화된 후속 ... surgical 유지 위해 defer"). `commands/new.md:41-53`(가드→Phase 포인터, Step 0.5 없음). `grep -n record_step references/new-procedure.md` = .gitignore 주석(`:237-238`)만. PR #142 Codex P2 코멘트가 갭 확인. `cr-fix-142.json:28-43` action="defer"(사유: 8 phase 재도출/재선언이 침습적 + 동시 #118 rewrite 충돌). **차단 사유 소멸 확인**: #118은 커밋 09f780e로 이미 병합(commands/new.md·new-procedure.md 둘 다 건드림), project-init 현재 `0.4.4`(`plugin.json:3`).
- **근본 원인**: state-envelope v0는 공유 라이브러리 없이 채택자가 jq 인라인. project-init은 두 진입 표면이 하나의 공유 파일(`new-procedure.md`)에 실행을 위임하는데, #142는 open/record/finalize를 `skills/new/SKILL.md` 자체 Step 0.5에만 산문으로 넣고 공유 파일엔 안 넣음 → 커맨드 표면은 도달 경로가 없음.
- **접근 + 정확한 삽입점**: Step 0.5(record-open + `record_step()` 함수)를 `references/new-procedure.md` **자체**의 Phase 0 PLUGIN_ROOT resolver 블록 직후(`~라인 23-70` 영역)에 임베드 — 두 표면이 이미 이 파일에 Phase 0-7 실행을 위임하므로 단일 공유 위치 수정(플러그인 자체 precedent: `project-init/CLAUDE.md` "preflight 가드 수정 시 두 파일 동시 갱신"과 동형). 이어 8개 Phase(0-7) 블록 종료마다 `record_step <n> done|skipped "<reason>"` 추가(셸 상태 비유지이므로 각 phase bash 블록에서 SLUG/REC 재도출 + record_step 함수 재선언, `SKILL.md:82` 문서화 패턴 동일). new-procedure.md가 Step 0.5를 소유하면 `skills/new/SKILL.md:40-93` 사본은 공유 위치 포인터로 축소(동일 스키마-emit jq의 두 소유자 방지). **검증**: #142 데모(fresh init → interrupt → resume(완료 단계 나열) → finalize → 스키마 검증)를 이번엔 **커맨드 경로**로 재실행해 갭이 실제로 닫혔는지 확인.
- **스코프 경계(surgical)**: In — `references/new-procedure.md`(Phase 0 근처 Step 0.5 1회 + Phase 0-7 종료당 record_step 1개), `skills/new/SKILL.md`(중복 Step 0.5를 포인터로 trim, Step 1의 contract 산문 유지), project-init 버전 범프. Out — `wiring` 스킬, state-envelope 스키마/convention, 공유 라이브러리, `#138 CR3`(=W2-1, 다른 플러그인/파일 — 사용자가 명시 원할 때만 번들).
- **리스크**: 낮음-중간. 원 defer 사유(#118 충돌)는 소멸. 잔여는 기계적: 8개 phase 편집에서 한 phase 누락/step 번호 오기 시 불완전 run record가 조용히 생성됨 — state-envelope가 가시화하려던 바로 그 실패 모드라, #142와 동일한 fresh/interrupt/resume/finalize 데모 검증을 커맨드 경로로 재실행.
- **의존성**: 없음. **TDD**: 적용(jq 스키마 데모가 사실상 실행 검증 역할).
- **노력**: 1 PR, ~8-12 라운드(1 파일 ~9 bash 블록 편집 + SKILL.md trim + 데모 + 버전 범프 + 매니페스트 재생성 조건부).
- **신뢰도**: high.

---

## Wave 3 — 문서/검증 위생 (병렬 가능, 저리스크)

네 항목 전부 독립·저리스크. 하나(W3-3)는 "안 하는 게 정답", 하나(W3-4)는 에이전트가 못 끝내고 사람이 한 번 돌려야 완료.

### W3-1. slidev glow-background 다크모드 CSS 모순 수정 (두 곳)

- **문제**: `glow-background.md` 가 `.dark #slide-content { background-color: black !important; }` 를 지시하면서 주석은 "배경을 transparent로 만들어 glow가 보이게"라고 적어, 주석과 값이 정면 모순. 사용자가 이 레퍼런스를 그대로 복사하므로 다크모드에서 glow가 안 보인다.
- **근거(확인됨, 직접 재독)**: `glow-background.md:187`(주석 "transparent so the glow shows through"), `:189`(값 `black`), `:195-201`(동일 블록 반복, `:198` 재발). `.glow-container` 는 `position:fixed; inset:0; z-index:-1`(`:85-91`), global-bottom.vue는 "모든 슬라이드 아래 레이어"(`:27`). CSS 페인팅 시맨틱만으로 증명 가능: 불투명 `background-color` 는 스택 순서상 뒤 페인트를 완전 가림(어떤 `z-index`도 무관). `git show fee6651` 로 원 도입 시부터의 결함(번역 회귀 아님). CodeRabbit PR #144 `:193` Major 지적, 제시 diff `black → transparent`. `cr-fix-144.json` defer 사유: "pre-existing behavioral bug, needs slidev-render verification".
- **접근 + 정확한 삽입점**: `:189` 와 `:198` 의 `background-color: black !important;` → `transparent !important;` 2줄. 주석(`:187`)은 이미 정확하니 값만 맞추면 됨. CodeRabbit 제시 diff와 일치.
- **스코프 경계(surgical)**: In — `:189`, `:198` 두 줄만 + `slidev` 버전 범프. Out — 다른 CSS 값(glow 색/blur/transition 표 `:314-325`, "per spec — do not change"), global-bottom.vue z-index/레이어링, 타 slidev 레퍼런스.
- **리스크**: 낮음(2줄 텍스트, 실행 코드 아님). 잔여 리스크(정적 검사로 못 지움): 실제 Slidev/테마 DOM에 이 repo에 vendoring 안 된 다른 불투명 조상(테마 body/#app 래퍼)이 glow 레이어와 #slide-content 사이에 있으면 수정 후에도 여전히 가릴 수 있음.
- **의존성**: 없음. **TDD**: 불가(2줄 문서).
- **노력**: 1 PR, 1 Edit(2줄) + 버전 범프. 선택적 후속: slidev-render 1 라운드(npm init slidev + global-bottom.vue 복사 + 수정 CSS 적용 + 다크모드 육안 확인)로 다른 불투명 조상 여부 확정 후 defer 항목 종료.
- **신뢰도**: high.

### W3-2. AGENTS.md "Known limitation — cr-fix portability" 스테일 노트 정정

- **문제**: `AGENTS.md:250-253` 가 cr-fix에 marketplace-repo-relative 하드코딩 경로 ~36개가 남아 일반 user repo/Codex에서 깨진다며 `${CLAUDE_PLUGIN_ROOT}` resolver를 "미해결 후속"으로 서술 — 현재 트리에선 사실이 아니다. resolver가 이미 존재하고, 모든 실행 참조의 유일 경로이며, 회귀 테스트도 있다. 코드가 아니라 노트를 고쳐야 한다.
- **근거(확인됨)**: `"plugins/github-dev/skills/cr-fix"` literal은 `cr-fix/SKILL.md` 에 5회뿐이고 전부 Step 1 SKILL_DIR resolver 내부(`:76-87` source-tree fallback). 실행 bash 블록의 scripts/references 참조는 전부 `$SKILL_DIR` 경유(fenced ```bash 추출 후 $SKILL_DIR 제외 grep = 0줄). resolver 회귀 테스트 `cr-fix/tests/run-tests.sh:399-442`(69-케이스 스위트, pre-commit+CI 연동). 히스토리: 노트는 e06a2ef/PR #39(2026-05-31), resolver+라우팅은 이후 75f7c9d(#109)·e20f9f3(#110). github-dev 현재 2.9.1.
- **접근**: 문서 전용. `AGENTS.md` 에서 (a) `## Known limitation — cr-fix portability` 섹션(250-253) 삭제, 또는 (b) "PR #109/#110에서 SKILL_DIR resolver + $SKILL_DIR-라우팅 + tests:399-442 커버리지로 해소"라는 짧은 breadcrumb으로 교체. SKILL.md 편집 불필요(실행 코드에 unrouted 하드코딩 0).
- **스코프 경계(surgical)**: In — `AGENTS.md` 해당 섹션만. Out — SKILL.md/scripts(이미 완료), github-dev 버전 범프(**AGENTS.md는 루트 문서, 플러그인 콘텐츠 아님 → 범프 불필요**).
- **리스크**: 매우 낮음(루트 md 텍스트). 리스크는 기능이 아니라 신뢰성(스테일 "known limitation"이 실재 버그를 과장해 문서 신뢰 저하).
- **의존성**: 없음. **TDD**: 불가.
- **노력**: 1 라운드 편집, <5분, PR-worthy 코드 변경 없음.
- **신뢰도**: high.

### W3-3. code-scout axis-contracts.md JSON-with-comments — 비이슈 확인 (권장: 방치)

- **문제(조사 결과)**: `axis-contracts.md:18-36` fenced ```json 블록에 `//` 주석 3개(`:25`,`:27`,`:29`)가 있어 strict JSON이면 무효. 하지만 이 파일을 파싱하는 소비자가 코드베이스에 **하나도 없음**.
- **근거(확인됨)**: `rg "jq |json.load|JSON.parse" plugins/code-scout` 히트는 `resource-finder/scripts/search_github.py:76,107`(gh CLI 출력 파싱)뿐 — axis-contracts.md와 무관. markdown-JSON-fence extractor/linter 부재. `research-orchestrator/SKILL.md:102-158,213` 상 axis-contracts.md는 세 실행 경로(A/B/C) 전부 LLM 에이전트가 템플릿으로 읽고 런타임에 자기 `${workspace_dir}/${artifact_id}.json` 을 독립 작성 — fenced 블록 자체는 파서에 넘어가지 않음.
- **접근(ponytail 사다리 1단)**: **코드 변경 불필요. 방치 권장.** 굳이 pedantic 위생을 원하면 3개 주석 내용을 바로 아래 이미 있는 "Envelope rules that hold on every path" 불릿(`:38-43`, REQUIRED url/reliability·error-only-on-total-failure를 이미 커버)으로 흡수 = 주석당 1줄 cosmetic trim. 인라인 주석이 그 산문과 대체로 중복이라 삭제해도 정보 손실 없음.
- **스코프 경계**: (행동 시) In — `:25`,`:27`,`:29` 주석 fragment 삭제 + code-scout 버전 범프. Out — 스크립트/파서(없음), 타 파일.
- **리스크**: 현상 유지 시 없음(확인된 비이슈). 삭제 시도 0(순수 텍스트, 의존 파서 없음).
- **의존성**: 없음. **TDD**: 불가.
- **노력**: 방치 = 0분(권장). cosmetic 정리 시 1 라운드(Edit) + PATCH 범프 1 PR.
- **신뢰도**: high.

### W3-4. compact 훅 SessionStart 재주입 런타임 검증 (설정은 이미 정확 — 사람이 1회 수동 확인)

- **문제**: PR #145/이슈 #119가 core-config SessionStart(matcher "compact") 훅을 추가해 compaction 후 `prompt_inject.sh` 재실행으로 행동 블록을 복원. 이슈 #119 완료 기준 중 "강제 compaction 후 insight 포인터 재등장 확인"이 미체크. **조사가 바로잡는 핵심**: 태스크 브리프의 "compaction은 온디맨드 트리거 불가"라는 전제는 공식 문서상 **틀렸다** — `/compact` 슬래시 커맨드가 문서화된 수동 트리거다.
- **근거(확인됨)**: `plugin.json:16-25`(matcher/command/timeout 구성상 정확, no-arg → plain stdout), `prompt_inject.sh`(FMT=`${1:-claude}`, no-arg 시 plain stdout — SessionStart가 context로 자동 추가), `core-config/CLAUDE.md:17`(근거 + Claude-only 스코프). 공식 docs(code.claude.com/docs/en/hooks): `compact` matcher는 "Auto or manual compaction"에 발화, `/compact` 가 수동 트리거. `claude --debug hooks`(로컬 2.1.209 `--help` 확인)로 훅 실행·matcher·output 관찰 가능. 상류 리스크: anthropics/claude-code#15174·#13650(SessionStart compact stdout 드롭, v2.0.76+ 보고) — #13650은 v2.0.76 재현 테스트로 `startup` source에 대해 completed 종료했으나 `compact` source는 격리 검증 안 됨. 로컬은 2.1.209(보고 창 이후)라 적용 가능성 높으나 `compact` 한정 독립 확인은 미완.
- **근본 원인**: 코드 결함 아님 — 이 훅류의 내재 속성. SessionStart:compact는 대화형 세션 이벤트(임계 자동 compaction 또는 `/compact`)의 부수효과로만 발화하며, 비대화형 조사/서브에이전트 컨텍스트는 스스로 유발 불가. 부채는 실재하나 브리프가 "원리상 검증 불가"로 오기 — 실제론 사람 오퍼레이터가 온디맨드로 검증 가능, 자동 에이전트 실행만 불가.
- **접근(사람이 1회 실행할 5단계 절차)**: (1) core-config 설치된 repo에서 `claude --debug hooks` 대화형 세션; (2) 평범한 프롬프트 1회로 baseline UserPromptSubmit 블록 확인; (3) `/compact` 실행(온디맨드, 자동 compaction 대기 불필요); (4) 디버그 로그에서 `SessionStart` + `matcher: compact` 호출 + stdout/additionalContext 비어있지 않고 고정 블록(`[harness]` 라인 등) 포함 확인; (5) 후속 프롬프트로 모델에 `[harness]` 첫 줄 verbatim 인용 요청(behavioral 교차 확인, 단독 증거 아님). 4단계 로그가 non-empty면 런타임 확정. empty/dropped면 #13650/#15174 실패류 재현 → 상류 보고, interim fallback(항상 발화하는 UserPromptSubmit가 다음 프롬프트에 재주입)으로 사용자 영향은 compaction 직후 1턴 한정.
- **스코프 경계**: In — 위 절차 + 정정된 전제(`/compact` 온디맨드 가능)를 `core-config/CLAUDE.md` compact-matcher 문단에 한 줄 addendum("runtime-verified via /compact + --debug hooks: <date>, 또는 pending")으로 명시, 또는 이슈 #119 미체크 기준 종료 코멘트. Out — 자동 훅-테스트 하네스 구축(단일 훅에 YAGNI), plugin.json/prompt_inject.sh 코드 변경(구성상 이미 정확).
- **리스크**: 낮음. 코드 변경 없는 검증-부채 항목. 유일 리스크는 이 Claude Code 버전이 상류 드롭 버그를 재현하는 경우 — 그래도 다음 UserPromptSubmit로 1턴 내 복구되어 영향 bounded.
- **의존성**: 없음. **TDD**: 불가(대화형 세션 필요, 에이전트 self-실행 불가).
- **노력**: 조사 1 라운드(완료). 남은 검증은 사람 오퍼레이터 대화형 세션 ~5분 — **에이전트 실행 불가**. 에이전트가 할 일은 CLAUDE.md 한 줄 addendum 뿐.
- **신뢰도**: high.

---

## Wave 4 — 설계 먼저 (design-first, 구현 금지)

### W4-1. project-init:wiring LSP/language-server 검사 축 — "구현이 아니라 설계 노트"

- **문제**: 사용자가 wiring에 15번째 축(언어 서버가 실제 동작하는지 확인)을 원하지만, 기존 14축은 전부 — "config가 *발효*되나"를 보는 4개 efficacy 축 포함 — 정적 config/파일 구조에서 발효를 추론할 뿐 프로세스를 띄우거나 IPC를 기다리지 않는다. LSP liveness는 범주가 다르다: 서버 바이너리 기동 + stdio JSON-RPC 대화 + 응답 대기가 필요해, wiring의 암묵 불변식(1초 미만, 결정론, 프로세스 0 spawn)을 깬다.
- **근거(확인됨)**: `wiring/SKILL.md:14`("Detection is read-only. project_state.sh never writes. Run it first, always."), `:92-100`(4 efficacy 축은 전부 선언적 config 비교로 추론, downstream 도구 실행 없음), `project_state.sh:4-5`(순수 read-only 명시). 가장 가까운 precedent인 serena 축(`project_state.sh:127-138`)도 `.serena/project.yml` 존재+메모리 파일 수만 보고 Serena MCP를 실제 호출 안 함. `GWS_CLI=$(b command -v gws)`(`:180`)가 "바이너리 on PATH" 탐지의 유일 precedent — 싸고 즉시·결정론적, 현 contract가 LSP에 허용하는 상한. 세션의 `LSP` 도구 자체가 갭 문서화("configured"와 "실제 응답"은 별개 사실). 이슈 #115 NO-TOUCH 세트에 `wiring` 명시 — 의도적 보수 유지. `git grep 'language server|lsp'` = 0(기존 LSP config convention 없음 → 순수 신규 축 영역).
- **근본 원인**: wiring 아키텍처(verdict FAIL/WARN/ASK/INFO/SKIP/OK, Step1-detect→Step2-verdict, project_state.sh 단일 SSOT)는 안정·저렴·파일/git-config 파생 사실용으로 설계됐다. LSP liveness는 외부 프로세스의 런타임 사실이라 어느 verdict class에도 안 맞음: 프로브는 정확성과 무관한 이유(콜드 인덱스 빌드, 런타임 부재, 샌드박스/오프라인)로 timeout할 수 있어, "ASK는 결정, FAIL은 계속 실패"라는 모델이 가정하지 않는 flapping 신호가 된다.
- **접근**: **축 코드를 쓰지 말 것.** 두 후보 shape를 제시하고 owner가 고르게 하는 짧은 설계 노트를 산출. (A) **탐지 전용 축**(현 contract 내부) — `project_state.sh` 에 `lsp` 블록 추가, per-language config/등록 신호(`pyrightconfig.json`, `tsconfig.json`, `command -v <lsp-binary>` — 기존 GWS_CLI 패턴 미러)만 INFO/OK/SKIP 보고, liveness 주장 안 함. 런타임 무추가, 새 verdict class 불필요. (B) **진짜 liveness 프로브** — `project_state.sh` **밖**의 별도 스크립트(never-writes/never-spawns 불변식 보존 + "세 detector가 drift했다" 실패 모드 회피), 명시적 opt-in(Step 1 기본 실행 안 함), 영구 INFO-only(timeout이 false FAIL/WARN 안 되게), spawn-timeout-cleanup contract 명시(크로스플랫폼 `timeout` 가용성, orphan 서버 프로세스 kill, 첫 실행 인덱스/캐시 쓰기를 스킬이 통제 못 하는 실제 부작용으로 인정). A vs B vs "wiring에 안 넣음"을 아래 open decision 해소 후 선택 권장.
- **스코프 경계**: In — 긴장 특성화 + 두 후보 shape + 구현 차단 결정 열거. Out — `project_state.sh`/SKILL.md 축 표/새 프로브 스크립트 편집(명시적 design-first, 조사는 read-only).
- **리스크**: 조사 리스크 낮음(파일 무변경). 설계 단계 skip 시 구현 리스크: (1) project_state.sh에 프로브 접붙이면 sub-second/zero-spawn 프로파일 붕괴; (2) timeout 기반 liveness가 flapping verdict → 사용자가 wiring 출력 무시 학습; (3) spawn된 서버가 캐시/인덱스 파일 작성 → "read-only detection" contract 위반.
- **의존성**: 없음. **TDD**: 불가(설계 산출물).
- **노력**: design-first — 구현 PR 없음. 설계 노트 자체 ~10-15 라운드(생태계별 LSP config convention grep, liveness 프로브 관용 패턴 조사, 결정 목록 초안). 후속 구현 PR(축 코드 + SKILL.md 행)은 별개이며 open decision 해소 후에만 시작.
- **신뢰도**: high.

---

## 설계 먼저 콜아웃 (코딩 전에 결정 필요)

- **W4-1 (wiring LSP 축)** — **주요 design-first 항목.** 아래 6개 open decision이 전부 열려 있어 코드 착수 전 owner 결정이 필수. 특히 (a) 범위: 세션 내장 `LSP` 도구 한정 vs 임의 per-language 외부 서버(pyright/tsserver/rust-analyzer/gopls), (b) verdict shape: 새 class vs 영구 INFO-only, (c) 다언어 결과 shape(배열형), (d) 프로브 위치(project_state.sh 내부 vs 별도 sibling), (e) cadence(Step 1 기본 vs opt-in), (f) 부작용 억제(orphan cleanup + 첫 실행 캐시 쓰기).
- **W2-1 / W2-2 (부분적 결정 필요)** — 구현은 명확하나 삽입 전략(공유 파일 단일 소유 vs 표면별 복제)과 skip-reason 문자열이 확정 대상. 아래 open decisions 참조.

---

## Open decisions (사용자 결정 필요, 통합)

### 조율 / PR 번들링 (전체 걸침)
1. **github-dev 두 항목(W1-2 cr-fix, W2-1 post-merge) 번들 vs 순차**: 같은 플러그인 버전·같은 marketplace 엔트리를 공유하므로 별개 PR로 동시 진행 시 `marketplace.json` 충돌. AGENTS.md 번들링 규약(같은 모듈 → 한 PR 후보, AskUserQuestion 확인)상 한 PR 번들이 repo-선호. 사용자 선택: 한 github-dev PR로 번들 vs 엄격 순차.
2. **marketplace.json 직렬화**: 플러그인 콘텐츠를 건드리는 모든 항목(W1-1, W1-2, W2-1, W2-2, W3-1, 선택적 W3-3)이 `metadata.version` 을 올린다 — 이 값이 유일 직렬화 지점. 순차 랜딩 또는 리베이스로 해소(정상 워크플로).

### W1-1 (gws-sync)
3. SHA-256 fallback(`sha256sum` vs `shasum -a 256`)을 SKILL.md에 인라인 명시할지, "PATH의 checksum 도구 사용"으로 암묵 처리할지(스킬이 이미 유사 CLI-flag 불확실성 허용).
4. §7 post-upload Verify를 Drive측 `md5Checksum`/`sha256Checksum` 으로 defense-in-depth 강화할지, 별개 후속으로 둘지(CR 발견은 pre-upload 바인딩만 요구).

### W1-2 (cr-fix)
5. poll 재확인을 `fetch_cr_state()` 1회 추가 호출로 할지, `continue` 로 루프백해 top-of-loop 핸들러가 잡게 할지(추가 호출이 단순하고 rate-limit 경로에 sleep 사이클 미추가).
6. pre-flight 가드가 free-tier-skip-in-grace(`cr_free_tier_skip=true`)를 명시 특수처리할지, 이미 `cr_actionable=false` 가 grace를 배제하는지(현 `:151-162` 판독상 불필요 — 구현 시 case 블록 최종 재독).

### W2-1 (post-merge)
7. Step 4/4.5/4.6를 결합 엔트리 1개로 기록할지(fold-in 규칙), 4.5/4.6가 독립 선택 가능하니 자체 conditional skip 엔트리를 줄지.
8. 각 skip 경로 reason-string 문구 — 해당 단계 산문의 skip 조건과 literal 일치시킬 것(새로 창작 금지).

### W2-2 (project-init)
9. Step 0.5 삽입 전략: `new-procedure.md` 단일 공유 소유(권장, preflight 가드 precedent) vs `commands/new.md` 에 두 번째 사본 복제.
10. `skills/new/SKILL.md:40-93` 기존 Step 0.5를 포인터로 trim할지(동일 jq 두 소유자 방지).
11. sibling `#138 CR3`(=W2-1)를 같은 PR로 번들할지(기본은 별개 — 다른 플러그인/파일; #1과 동일 사안).

### W3 (문서/검증)
12. **W3-2**: known-limitation 섹션 outright 삭제 vs "PR #109/#110에서 해소" breadcrumb 교체(스타일 선호).
13. **W3-1**: black→transparent를 렌더링 없이 즉시 ship(CSS cascade로 증명 가능)할지, slidev-render 1 라운드로 다른 불투명 조상 부재를 육안 확인 후 defer 종료할지.
14. **W3-3**: 사다리 1단이 "no"라 함 — 그래도 1줄-per-주석 cosmetic 정리를 할지(권장: 방치).
15. **W3-4**: 5단계 수동 절차를 durable하게(예: `core-config/CLAUDE.md` addendum 또는 #119 종료 코멘트) 남길지, 이 조사 출력으로 충분한지(repo verification-rules 규율상 최소 한 줄 addendum 권장). #13650류 상류 리스크를 명시 추적할지.

### W4-1 (wiring LSP — 설계)
16. 축 범위: 세션 내장 `LSP` 도구 한정 vs 임의 per-language 외부 서버.
17. verdict shape: 새 class 신설 vs 영구 INFO-only(flapping 회피).
18. 다언어 결과 shape: single-valued 축 관례 깨고 per-language/list(배열형, `mcp.duplicates` 미러)로.
19. liveness 프로브 위치: `project_state.sh` 내부(never-spawns 불변식 파괴) vs 새 sibling 스크립트(두 번째 진입점 동기화 비용).
20. cadence: Step 1 기본 실행 vs 명시 opt-in(사실상 sibling 스킬화 — "wiring에 속하나, wiki/mem0처럼 위임해야 하나").
21. 부작용 억제: 프로브가 서버를 순간이라도 spawn하면 orphan 프로세스 cleanup + 스킬이 요청 안 한 첫 실행 캐시/인덱스 쓰기의 contract.

---

## 공통 실행 규칙 (버전 범프 / 매니페스트)

repo 규약(AGENTS.md "플러그인 변경 규칙")상, `plugins/<name>/` 아래 **어떤 파일이든** 바뀌면 해당 플러그인 PATCH 범프 대상:

- W1-1 → `gws-sync` `0.1.2 → 0.1.3` (`plugin.json:3` + `marketplace.json:169` + `metadata.version`). Codex 매니페스트 재생성(`node scripts/sync-codex-manifests.mjs`, description 무변경이면 no-op이나 버전 위해 실행). Hermes 재생성 불필요(gws-sync는 HERMES_ELIGIBLE 아님).
- W1-2, W2-1 → `github-dev` PATCH 범프(현재 2.9.1). **한 PR로 번들 시 한 번만 범프.** github-dev는 HERMES_ELIGIBLE → version 변경 시 `node scripts/sync-hermes-manifests.mjs` 재실행.
- W2-2 → `project-init` PATCH 범프(현재 0.4.4).
- W3-1 → `slidev` PATCH 범프.
- W3-3(행동 시) → `code-scout` PATCH 범프.
- **W3-2, W3-4 → 범프 불필요**: W3-2는 루트 `AGENTS.md`(플러그인 콘텐츠 아님), W3-4는 core-config CLAUDE.md 한 줄 addendum(범프 대상이나 문서 한 줄 — 사용자 확인 후 처리).
- 어떤 플러그인 버전이든 바뀌면 `marketplace.json` `metadata.version`(marketplace release 버전)도 올린다.
- Codex/Hermes drift 가드: 모든 PR에서 `node scripts/sync-codex-manifests.mjs --check` + `node scripts/sync-hermes-manifests.mjs --check`.

---

## 용어집

- **state-envelope (v0)**: 파이프라인 스킬이 자기 진행을 기계가 읽게 남기는 per-run 상태 파일 규약(`.claude/state/<pipeline>-<key>.json`). **공유 라이브러리 없음** — 각 채택 스킬이 본문에 jq 인라인. `spec.json`(spec→issue→PR 집계, owner spec-state)과는 직교.
- **record_step**: state-envelope에서 top-level 단계가 닫힐 때 `steps[]` 에 `{step, status:done|skipped, reason?}` 한 항목 append하는 인라인 jq(또는 동명 함수). `reason` 은 skipped에만·필수.
- **cr-fix**: PR 병합 전 CodeRabbit + Codex 자동 리뷰를 처리하는 github-dev 스킬. commit-status가 권위 신호, comment/review-채널은 보조.
- **commit-status vs comment-channel**: CR의 권위 신호는 GitHub commit-status("CodeRabbit: success"). `sniff-cr-rate-limit.sh` 채널 1+2는 코멘트/리뷰 본문 텍스트 히트 — supersession 개념이 없어 나중에 온 terminal success에 덮이지 않음(W1-2의 결함).
- **§5b 매니페스트 (gws-sync)**: `§5` 승인 직후 실제 승인된 항목만 freeze한 목록. 이후 모든 업로드는 이 매니페스트만 읽음. 현재 `{local, action, target, size, mtime}` — W1-1이 `sha256` 추가.
- **wiring 축 / efficacy 축**: `project-init:wiring` 이 검사하는 하네스 설정 차원(현 14개). efficacy 축 4개는 "config가 존재하나"가 아니라 "*발효*하나"를 보되, 여전히 정적 파일/git-config 추론이지 프로세스 실행이 아님.
- **verdict class**: wiring 결과 등급 FAIL/WARN/ASK/INFO/SKIP/OK. ASK = 아직 아무도 안 한 결정(1회 질문 후 `wiring.json` persist), FAIL = 계속 실패.
- **HERMES_ELIGIBLE / EXCLUDED**: Hermes 어댑터 생성 대상 allowlist(현 7개) / Codex sync 제외 denylist. gws-sync·slidev·code-scout는 Hermes 비대상, github-dev는 대상.
