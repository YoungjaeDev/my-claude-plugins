# anti-slop-design 스킬 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `anti-slop-design` 가이던스 스킬을 신규 플러그인으로 만들어 marketplace에 등록하고 Codex manifest까지 동기화한다.

**Architecture:** 단일 `SKILL.md`(6단계 inline 흐름 + 2단계 audit gate) + 3 reference(`slop-taxonomy.md` / `copy-rules.md` / `house-style.md`). substance는 `docs/references/anti-slop-design-oss-synthesis.md`(source-grounded 합성)에서 distill. 코드 산출물이 아니라 콘텐츠라 검증은 grep/jq/char-count/`sync-codex-manifests --check`/dry-run으로 한다.

**Tech Stack:** Markdown, JSON(plugin.json/marketplace.json), Node(`scripts/sync-codex-manifests.mjs`), git. 브랜치 `feat/anti-slop-design`(이미 생성, spec 커밋 `ba83032`).

**작성 언어 규약(전 파일):** 설명 산문 한국어 + AI 인식 키워드(`gradient text`/`hero`/`audit gate`/`oklch()`/CSS·HTML·repo명 등) 영어 유지. description 트리거 한·영 병기. 이모지 금지.

**참조 문서:**
- spec: `docs/superpowers/specs/2026-06-16-anti-slop-design-skill-design.md`
- substance: `docs/references/anti-slop-design-oss-synthesis.md` (§1 VISUAL / §2 STRUCTURAL / §3 레인 / §4 카피 / §5 house-style / §6 audit gate / §7 DEFER / §8 sourcing)
- 규칙: `.claude/rules/plugin-versioning.md`, `.claude/rules/dual-integration.md`
- 패턴 참고: 기존 스킬 `plugins/github-dev/skills/*/SKILL.md`(frontmatter 형태), `plugins/llm-wiki`(references 구조)

---

### Task 1: 플러그인 스캐폴드 + plugin.json

**Files:**
- Create: `plugins/anti-slop-design/.claude-plugin/plugin.json`
- Create(dir): `plugins/anti-slop-design/skills/anti-slop-design/references/`

- [ ] **Step 1: 디렉토리 + plugin.json 작성**

`plugins/anti-slop-design/.claude-plugin/plugin.json`:

```json
{
  "name": "anti-slop-design",
  "version": "0.1.0",
  "description": "Anti-AI-slop design guard for websites/SaaS landing, presentation decks (PPT), dashboards/admin UI, and marketing/UI copy. Detects and blocks the AI-generated look before generation and audits it after: purple/gradient palettes, gradient text, Inter/Geist single-font pages, side-stripe cards, card-in-card, icon-tile 3-col grids, centered hero macrostructure, fabricated metrics, emoji icons, over-animation, buzzword copy. Runs a clarify->context->plan->run->audit->revise flow with a two-phase audit gate (pre-emit self-critique + binary slop checklist), hands Korean copy rewriting to humanize-korean. 트리거: 'AI 티 안 나게', 'slop 제거', 'anti-slop', '디자인 감사', '랜딩/덱/대시보드/카피 디자인', 'enterprise 디자인', 'make it not look AI-generated', 'audit this design', even when the skill is not named.",
  "skills": ["./skills/anti-slop-design"]
}
```

- [ ] **Step 2: JSON 유효성 + description 길이(<=1024, Codex 한도) 검증**

Run:
```bash
jq . plugins/anti-slop-design/.claude-plugin/plugin.json >/dev/null && echo "JSON OK"
python3 -c "import json;d=json.load(open('plugins/anti-slop-design/.claude-plugin/plugin.json'));n=len(d['description']);print('desc chars:',n);assert n<=1024,'TOO LONG'"
```
Expected: `JSON OK` + `desc chars: <=1024`. 1024 초과 시 트리거 문구를 줄여 SKILL.md 본문으로 이동.

- [ ] **Step 3: Commit**

```bash
git add plugins/anti-slop-design/.claude-plugin/plugin.json
git commit -m "feat(anti-slop-design): scaffold plugin manifest"
```

---

### Task 2: SKILL.md (오케스트레이팅 본문)

**Files:**
- Create: `plugins/anti-slop-design/skills/anti-slop-design/SKILL.md`

- [ ] **Step 1: SKILL.md 작성**

frontmatter + 본문. frontmatter `name: anti-slop-design`, `description:`(plugin.json과 동일 문구 재사용 — pushy, 한/영 트리거). 본문 구성(<500줄, 언어 규약 적용):

1. 한 줄 정체성 + 핵심 명제("slop = 브리프와 무관한 default-not-choice").
2. **6단계 흐름**: Clarify / Context(브랜드 색·폰트 기억 추측 금지) / Plan(모호한 'clean/modern' 금지, 구체 방향 1개 + 시각물은 2~3안 제안 후 택1) / Run(ban마다 브리프 우선 escape hatch) / Audit gate / Revise(출력 형식: 방향/위계/적용 결정/산출물/리스크).
3. **Audit gate 2단계**(spec §5 그대로):
   - Phase A 생성 전: self-similarity probe + 6축(Philosophy/Hierarchy/Specificity/Restraint/Variety/Honesty) 1~5점, 한 축 <3이면 1회 수정. "2회 정상, 3회면 브리프가 틀림".
   - Phase B 납품 전: 12항목 binary 체크리스트(spec §5 목록) + 수치 floor sweep(대비/폰트크기/타입스케일/행길이/line-height/색수/터치/honesty test).
4. 레인 분기 → `references/slop-taxonomy.md` 해당 섹션 로드 지시.
5. 카피 포함 시 → `references/copy-rules.md` + 한국어 재작성은 `humanize-korean:humanize-korean`(fast) 핸드오프 후 `final.md` 본문 회수.
6. 기본값 → `references/house-style.md` 로드.

상세 규칙은 본문에 중복하지 말고 reference로 progressive disclosure. 본문은 "흐름 + 게이트 + 언제 어느 reference를 여는가"만.

- [ ] **Step 2: 구조·규약 검증**

Run:
```bash
f=plugins/anti-slop-design/skills/anti-slop-design/SKILL.md
wc -l $f
grep -q "Clarify" $f && grep -q "Phase A" $f && grep -q "Phase B" $f && grep -q "humanize-korean" $f && grep -qi "slop-taxonomy" $f && echo "sections OK"
grep -nP "[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}]" $f && echo "EMOJI FOUND (fix)" || echo "no emoji OK"
```
Expected: 줄수 <500, `sections OK`, `no emoji OK`.

- [ ] **Step 3: Commit**

```bash
git add plugins/anti-slop-design/skills/anti-slop-design/SKILL.md
git commit -m "feat(anti-slop-design): add orchestrating SKILL.md with 6-stage flow and audit gate"
```

---

### Task 3: references/slop-taxonomy.md (VISUAL + STRUCTURAL + 레인)

**Files:**
- Create: `plugins/anti-slop-design/skills/anti-slop-design/references/slop-taxonomy.md`
- Source: `docs/references/anti-slop-design-oss-synthesis.md` §1, §2, §3

- [ ] **Step 1: 작성**

합성 §1(VISUAL: Color/Typography/Visual Details/Imagery/Motion), §2(STRUCTURAL), §3(레인: web/ppt/dashboard)를 distill. `[CORE]`(3+ repo 수렴) 패턴 보존. 각 항목은 detector + "Instead:" fix 쌍으로. dashboard 레인은 GAP을 정직하게 명시(web 컴포넌트/대비/density 상속 + hallmark form-state 게이트 + huashu density 역전 "여백 늘리기 반사 금지"). 수치 floor 표 포함.

- [ ] **Step 2: 핵심 substance 존재 검증**

Run:
```bash
f=plugins/anti-slop-design/skills/anti-slop-design/references/slop-taxonomy.md
grep -qi "side-stripe" $f && grep -qi "gradient text" $f && grep -qi "card-in-card" $f && echo "VISUAL OK"
grep -qi "default-not-choice\|macrostructure" $f && echo "STRUCTURAL OK"
grep -qi "dashboard" $f && grep -qi "density" $f && echo "lanes OK"
```
Expected: `VISUAL OK` / `STRUCTURAL OK` / `lanes OK`.

- [ ] **Step 3: Commit**

```bash
git add plugins/anti-slop-design/skills/anti-slop-design/references/slop-taxonomy.md
git commit -m "feat(anti-slop-design): add slop-taxonomy reference (visual/structural/lanes)"
```

---

### Task 4: references/copy-rules.md (카피 + humanize 핸드오프)

**Files:**
- Create: `plugins/anti-slop-design/skills/anti-slop-design/references/copy-rules.md`
- Source: 합성 §4 + spec §7(덱 8원칙)

- [ ] **Step 1: 작성**

합성 §4 distill: 영문 banned phrases(throat-clearing/emphasis/filler/buzzword/jargon→plain/adverb/meta/extremes), banned structures(manufactured contrast "Not X, it's Y", negative listing, em-dash ≥5 임계, false agency, rule-of-three), UX-copy detectors. 5-dim 스코어링(Directness/Rhythm/Trust/Authenticity/Density, /50, <35 수정). 핸드오프 전 체크리스트 = 덱 8원칙. **경계 명시**: 영문 탐지·스코어링은 자체, 한국어 재작성은 `humanize-korean` 위임 — stop-slop 무딘 절대금지(부사/em-dash/3항목 전면금지)를 한국어로 복제 금지.

- [ ] **Step 2: 검증**

Run:
```bash
f=plugins/anti-slop-design/skills/anti-slop-design/references/copy-rules.md
grep -qi "humanize-korean" $f && grep -qi "Not X\|manufactured contrast\|negative listing" $f && grep -qi "덱\|표지\|일반론" $f && echo "copy OK"
```
Expected: `copy OK`.

- [ ] **Step 3: Commit**

```bash
git add plugins/anti-slop-design/skills/anti-slop-design/references/copy-rules.md
git commit -m "feat(anti-slop-design): add copy-rules reference with humanize-korean handoff"
```

---

### Task 5: references/house-style.md (기본값 + 충돌 해소)

**Files:**
- Create: `plugins/anti-slop-design/skills/anti-slop-design/references/house-style.md`
- Source: 합성 §5 + spec §8

- [ ] **Step 1: 작성**

사용자 기본 제안값(enterprise / monochrome + 단일 accent / Pretendard / no emoji / inline SVG 다이어그램 / 무외부의존 static HTML+CSS+vanilla JS / print-CSS / 콜아웃). OSS 교차점검 충돌 2건 해소 명시:
- blue/indigo accent: 평면 단일 `oklch()` committed 토큰 OK, **그라데이션화 절대 금지**. house-style이 banned 패턴에 가장 근접한 유일 지점.
- inline SVG: ban은 figurative/representational(사람·장면·제품)에만, 다이어그램·아이콘·data-viz 허용 → 스코프 명시로 false-positive 방지.
"기본 범용 + 사용자 취향은 기본 제안값/worked example" 원칙 명시.

- [ ] **Step 2: 검증**

Run:
```bash
f=plugins/anti-slop-design/skills/anti-slop-design/references/house-style.md
grep -qi "oklch\|gradient" $f && grep -qi "figurative\|diagram" $f && grep -qi "Pretendard" $f && echo "house-style OK"
```
Expected: `house-style OK`.

- [ ] **Step 3: Commit**

```bash
git add plugins/anti-slop-design/skills/anti-slop-design/references/house-style.md
git commit -m "feat(anti-slop-design): add house-style reference with blue-indigo and SVG resolutions"
```

---

### Task 6: marketplace 등록 + plugin 카운트 동기화

**Files:**
- Modify: `.claude-plugin/marketplace.json` (플러그인 엔트리 추가 + `metadata.version` bump)
- Modify: `CLAUDE.md` (`## Plugins (21)` -> `(22)` + 구조 트리에 anti-slop-design 추가)
- Modify: `README.md` (설명문 개수 + 배지 + 상세 섹션)

- [ ] **Step 1: marketplace.json — 기존 엔트리 형태 확인**

Run:
```bash
jq '.plugins[0]' .claude-plugin/marketplace.json
jq '.metadata.version' .claude-plugin/marketplace.json
```
Expected: 엔트리 스키마(name/source/version/description 등)와 현재 metadata.version 확인.

- [ ] **Step 2: anti-slop-design 엔트리 추가 + metadata.version bump**

기존 엔트리와 동일 스키마로 `anti-slop-design`(version `0.1.0`, plugin.json description과 일치) 추가. `metadata.version`은 **`origin/main` 대비** 한 단계 bump(merge 직전 재확인 — `.claude/rules/plugin-versioning.md` 동시-브랜치 함정).

- [ ] **Step 3: 카운트 동기화**

`CLAUDE.md`: `## Plugins (21)` -> `## Plugins (22)`, Memory & Lore 인근에 anti-slop-design 행 + 구조 트리에 디렉토리 추가. `README.md`: 플러그인 수 문장 + 배지 숫자 + 상세 표/섹션에 anti-slop-design 추가.

- [ ] **Step 4: 검증**

Run:
```bash
jq '.plugins[] | select(.name=="anti-slop-design")' .claude-plugin/marketplace.json
jq -e '[.plugins[].name]|length' .claude-plugin/marketplace.json
grep -c "anti-slop-design" CLAUDE.md README.md
grep -n "Plugins (22)" CLAUDE.md
```
Expected: 엔트리 출력됨, 플러그인 수 = 22, CLAUDE.md/README.md에 anti-slop-design 등장, `Plugins (22)` 매치.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/marketplace.json CLAUDE.md README.md
git commit -m "feat(anti-slop-design): register plugin in marketplace and bump counts to 22"
```

---

### Task 7: Codex manifest 재생성 + drift 검증

**Files:**
- Generated: `plugins/anti-slop-design/.codex-plugin/plugin.json`
- Generated: `.agents/plugins/marketplace.json` (갱신)

- [ ] **Step 1: 매니페스트 생성**

Run:
```bash
node scripts/sync-codex-manifests.mjs
```
Expected: anti-slop-design용 `.codex-plugin/plugin.json` 생성 로그.

- [ ] **Step 2: drift + description 길이 가드 검증**

Run:
```bash
node scripts/sync-codex-manifests.mjs --check && echo "CHECK PASS"
ls plugins/anti-slop-design/.codex-plugin/plugin.json
```
Expected: `CHECK PASS`, 매니페스트 파일 존재. 실패 시 description 길이/frontmatter 수정 후 재생성.

- [ ] **Step 3: Commit**

```bash
git add plugins/anti-slop-design/.codex-plugin/plugin.json .agents/plugins/marketplace.json
git commit -m "build(anti-slop-design): sync Codex manifests"
```

---

### Task 8: 인수 검증 (dry-run audit gate)

**Files:**
- Temp(미커밋): `/tmp/anti-slop-dryrun.html`

- [ ] **Step 1: 의도적 slop 샘플 작성**

`/tmp/anti-slop-dryrun.html`에 심은 slop: 보라→파랑 gradient hero + gradient text + Inter 단일폰트 + 아이콘타일 3열 그리드 + side-stripe 카드 + 지어낸 "10x faster, trusted by 50,000+ teams" + 이모지 아이콘.

- [ ] **Step 2: 스킬 audit gate로 감사(메인 세션에서 SKILL.md 흐름 수동 적용)**

SKILL.md의 Phase B 12항목 + 수치 floor를 이 샘플에 적용. 기대: 최소 항목 1(gradient), 2(Inter 단일폰트), 3(side-stripe/3열), 8(지어낸 수치), 9(이모지) "yes"로 검출 → 수정 권고 출력.

Expected: 게이트가 위 5개 이상 plant를 잡고 각 "Instead:" fix를 제시. 못 잡으면 해당 항목을 slop-taxonomy/SKILL.md에 보강.

- [ ] **Step 3: 트리거 sanity(선택) + 정리**

`description`이 "이 랜딩 AI 티 안 나게 감사해줘" 류 발화에 트리거되는지 skill-creator description 평가(선택). temp 파일 삭제(`rm /tmp/anti-slop-dryrun.html`), 커밋 안 함.

- [ ] **Step 4: 최종 상태 확인**

Run:
```bash
git status --short && git log --oneline -8
node scripts/sync-codex-manifests.mjs --check && echo "FINAL CHECK PASS"
```
Expected: 워킹트리 clean(temp 제외), 커밋 이력 확인, `FINAL CHECK PASS`.

---

## Self-Review

**Spec coverage:** spec §3 레이아웃→T1-T5, §4 6단계→T2, §5 audit gate→T2, §6 레인→T3, §7 카피→T4, §8 house-style→T5, §9 dual-integration/카운트→T6-T7, §10 검증→T8, §11 sourcing→reference 인용으로 보존, §12 open questions(description 트리거 최종/dashboard 소스)→T2·T8에서 다룸. 누락 없음.

**Placeholder scan:** 콘텐츠 스킬이라 코드 TDD 대신 grep/jq/`--check`/char-count/dry-run으로 검증 구체화. "적절히/TBD" 없음. 각 reference의 실제 substance는 `docs/references/anti-slop-design-oss-synthesis.md`의 명시 섹션에서 distill(출처 명확, placeholder 아님).

**Type consistency:** 파일 경로·플러그인명(`anti-slop-design`)·버전(`0.1.0`)·reference 파일명 3종이 전 태스크에서 일치. plugin.json description ↔ SKILL.md frontmatter description ↔ marketplace 엔트리 description 동일 문구 재사용으로 drift 방지.

**비범위 재확인(spec §2):** sub-agent/JS 엔진/58 gate/카탈로그/hook/PPT 빌드 태스크 없음 — 의도된 YAGNI.
