# VALIDATION — skill-forge

## 필수 검증

골 완료로 마크하기 전 다음 명령을 반드시 실행한다.

```bash
node scripts/sync-codex-manifests.mjs --check
node scripts/sync-hermes-manifests.mjs --check
node scripts/check-skill-tool-portability.mjs --check
node scripts/check-doc-consistency.mjs
node scripts/check-shell-portability.mjs
node scripts/check-skill-contract.mjs
node plugins/docs-forge/skills/skill-forge/scripts/measure-skills.mjs
```

엄격도 `엄격` — 위 7개는 모든 마일스톤 종료 시점과 최종 완료 판정 시점에 전부 재실행한다. **이미 존재하는** 검증이 하나라도 실패하면 다음 마일스톤에 진입하지 않는다.

목록의 마지막 2개(`check-skill-contract.mjs`, `measure-skills.mjs`)는 이 골 자신의 산출물이라 각각 마일스톤 4·2 이전에는 존재할 수 없다. 그 시점에는 실패가 아니라 `미생성` 으로 기록하고 진행한다 — 그렇지 않으면 마일스톤 1 에서 교착한다. **최종 완료 판정 시점에는 7개 전부 통과를 요구한다.** blocking set 은 "그 시점에 파일이 존재하는 명령 전부" 다.

앞의 5개는 `.githooks/pre-commit` 이 매 커밋마다 도는 것과 같은 집합이다 (`check-skill-prose` 는 비차단 측정이라 제외). 이 목록에서 하나를 빼면 골이 통과시킨 변경이 커밋 시점에 막힌다.

## 마일스톤별 검증

각 마일스톤 종료 시 실행한다.

```bash
# M0 — 선행 확인
grep -rn "argument-hint" plugins/*/skills/*/SKILL.md
grep -c "HERMES_ELIGIBLE" scripts/manifest-eligibility.mjs
ls plugins/*/plugin.yaml 2>/dev/null | wc -l

# M1 — skill-forge
test -f plugins/docs-forge/skills/skill-forge/SKILL.md
ls plugins/docs-forge/skills/skill-forge/references/ | wc -l          # 4 이어야 함
test -f plugins/docs-forge/skills/skill-forge/scripts/measure-skills.mjs
node --check plugins/docs-forge/skills/skill-forge/scripts/measure-skills.mjs
grep -rniE "skill-creator|superpowers:|hermes-agent-skill-authoring" \
  plugins/docs-forge/skills/skill-{forge,audit,fleet-review}/ | wc -l  # 0 이어야 함
grep -rn 'CLAUDE_PLUGIN_ROOT' plugins/docs-forge/skills/skill-*/SKILL.md
wc -l plugins/docs-forge/skills/skill-*/SKILL.md                       # 각 300 이하

# M2 — 자기검수
# 소멸한 플러그인 14종 = PR #164/#191 이 지운 3종 + PR #200 이 흡수한 11종.
# --hidden 없이는 rg 가 .claude/ · .github/ · .githooks/ · .llmwiki/ 를 통째로 건너뛴다.
# 제외 대상은 "docs 전체"가 아니라 **이력 아카이브**다: .llmwiki, .claude/spec,
# docs/audit(과거 감사), docs/superpowers(날짜 박힌 spec·plan), tests/fixtures.
# 여기에 섞어 넣고 0건을 강요하면 과거 기록을 지우게 된다.
# docs/prd 는 활성 문서이므로 스캔한다 — docs/** 를 통째로 빼면 활성 문서에 들어온
# 향후 live 참조가 "0건" 결과에서 조용히 빠진다.
GONE='slidev|ppt-yeong-style|anti-slop-design|brightdata-guide|gws-sync|interview|notebook|plaud-note-taking|rules-forge|spec-state|tally-form|tcrei-prompt|translator|voice-prompt'
rg --hidden -n "\b($GONE):[a-z0-9-]+" \
  --glob '!.git/**' --glob '!docs/audit/**' --glob '!docs/superpowers/**' \
  --glob '!.claude/spec/**' --glob '!.llmwiki/**' --glob '!**/tests/fixtures/**'
# 위 출력의 각 hit 를 live / 이력 으로 판정한다. live 는 0건이어야 하고,
# 이력으로 판정한 hit 는 근거와 함께 감사 문서에 남긴다.
# 2026-08-10 기준 알려진 이력 hit 3건: plugins/docs-forge/CLAUDE.md:243 의 rules-forge
# 제거 안내(한 줄에 2회), 그리고 PROGRESS.md:75,80 — 이 감사가 그 판정을 서술하며
# 같은 문자열을 인용한 것이다.
# 이 PR 의 산출물을 검사하므로 경로를 고정한다. $(date +%Y-%m-%d) 를 쓰면 작성일 다음 날부터,
# 그리고 CI 와 로컬의 타임존이 다르면 파일이 있어도 실패한다.
test -f docs/audit/2026-08-10-absorption-check.md

# M3 — 가드
node --check scripts/check-skill-contract.mjs
node scripts/check-skill-contract.mjs
grep -c 'check-skill-contract' .githooks/pre-commit
grep -c 'check-skill-contract' .github/workflows/validate-codex.yml
```

## 수동 확인 절차

1. `plugins/docs-forge/skills/skill-forge/SKILL.md` 를 열어 외부 스킬을 읽으라는 지시가 없는지 육안 확인한다. grep 은 문구를 바꾼 우회를 못 잡는다.
2. `references/frontmatter.md` 의 각 필드 규칙이 M0 결과와 일치하는지 확인한다. 확인 못 한 항목이 `unverified` 로 표시돼 있고 금지 문구로 단정하지 않았는지 본다.
3. `docs-forge` 전 스킬(M1 이후 11개)의 `description` 을 나란히 놓고 같은 트리거 브랜치를 두 스킬이 주장하지 않는지 읽는다.
4. `check-skill-contract.mjs` 의 fixture 테스트가 5종 각각에 대해 RED 를 실제로 만드는지 한 번 돌려본다.

## 완료 기준 매핑

| PRD 완료 기준 | 검증 방식 | 상태 |
| --- | --- | --- |
| Hermes 어댑터 생존 여부 확정 | 수동 조사 + 근거 기록 | 완료 (2026-08-06, PRD M0 참조) |
| `argument-hint` 스킬 인식 여부 확정 | 수동 조사 + 근거 기록 | 미착수 |
| `disable-model-invocation` 동작 여부 확정 | 수동 조사 + 근거 기록 | 미착수 |
| 세 결과를 `references/frontmatter.md` 에 반영 | 수동 검토 절차 2 | 미착수 |
| `skill-forge/SKILL.md` 생성, frontmatter 는 `name` + `description` 만 | `test -f` + frontmatter 키 grep | 미착수 |
| `references/` 4종 존재, 깊이 1 | `ls \| wc -l` = 4 + `check-skill-prose` | 미착수 |
| `scripts/measure-skills.mjs` 생성, 런타임 의존성 0 | `node --check` + import 문 grep | 미착수 |
| `measure-skills.mjs` 가 7개 측정 항목 출력 | 실행 후 출력 필드 확인 | 미착수 |
| `skill-audit`, `skill-fleet-review` 생성 | `test -f` | 미착수 |
| 외부 마켓플레이스 스킬 참조 0건 | `grep -rniE ... \| wc -l` = 0 | 미착수 |
| bare `${CLAUDE_PLUGIN_ROOT}` 없음 | `grep -rn` + resolver 블록 육안 확인 | 미착수 |
| 각 SKILL.md 300줄 이하 | `wc -l` | 미착수 |
| `description` 1024자 이하 + `: ` 인용 | `check-skill-contract.mjs` | 미착수 |
| `docs-forge` 버전 MINOR + marketplace + `metadata.version` | `check-doc-consistency.mjs` | 미착수 |
| `sync-codex-manifests.mjs --check` 통과 | 명령 exit 0 | 미착수 |
| `sync-hermes-manifests.mjs --check` 통과 | 명령 exit 0 (M0 결과 조건부) | 미착수 |
| `check-skill-tool-portability.mjs --check` 통과 | 명령 exit 0 | 미착수 |
| `check-doc-consistency.mjs` 통과 | 명령 exit 0 | 미착수 |
| `check-shell-portability.mjs` 통과 | 명령 exit 0 | 미착수 |
| `AGENTS.md` + `README.md` 가 새 스킬 반영 | `check-doc-consistency.mjs` + 육안 | 미착수 |
| 흡수된 스킬 전체에 `skill-audit` 실행 + 기록 | `docs/audit/<date>-absorption-check.md` 존재 | 미착수 |
| 소멸한 플러그인을 가리키는 **live** 참조 0건 | M2 grep 의 hit 를 live / 이력 으로 판정 + 근거 기록 | 미착수 |
| `docs-forge` 전 스킬 트리거 충돌 검토 완료 | 수동 검토 절차 3 | 미착수 |
| 본문의 플러그인·경로 서술이 새 위치와 일치 | 육안 + grep | 미착수 |
| rename 판정 수행, 적용분·보류분 근거 기록 | 감사 문서에 기록 | 미착수 |
| `-guide` 4종은 rename 하지 않음 | 파일명 확인 | 미착수 |
| `check-skill-contract.mjs` 생성, built-in 만 | `node --check` + import 문 grep | 미착수 |
| 5종 검사 구현, 위반 시 exit 1 + 사유 출력 | fixture 실행 | 미착수 |
| fixture 기반 RED / GREEN 테스트 | 수동 검토 절차 4 | 미착수 |
| `.githooks/pre-commit` 배선 | `grep -c` ≥ 1 | 미착수 |
| `.github/workflows/validate-codex.yml` 배선 | `grep -c` ≥ 1 | 미착수 |
| 전 스킬 실행, 통과 또는 위반 목록 보고 | 명령 실행 + 결과 기록 | 미착수 |
| 기존 가드 4종과 검사 항목 비중복 문서화 | 스크립트 상단 주석 + PR 본문 | 미착수 |

## 완료로 보지 않는 조건

- 필수 검증 중 하나라도 실패
- PLAN.md 밖의 scope 로 변경됨
- 명시적 승인 없이 public API 가 변경됨
- 수동 재현이 여전히 실패함
- 산출물이 생성됐지만 검토되지 않음
- 검증을 통과시키기 위해 테스트가 삭제·skip 됨
- 진단 없이 에러가 침묵 처리됨
- 가드는 통과했지만 fixture 테스트가 없어 회귀를 못 잡는 상태
- SKILL.md는 썼지만 `plugin.json` / `marketplace.json` 범프가 빠짐
- M0 의 미확인 3건을 확인 없이 단정해 규칙으로 적음
- skill-forge 본문이 외부 스킬을 읽으라고 지시함
- 플러그인 흡수·rename 을 이 골이 직접 수행함 (#198 영역 침범)
