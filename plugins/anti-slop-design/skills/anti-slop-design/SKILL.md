---
name: anti-slop-design
description: Anti-AI-slop design guard for websites/SaaS landing, presentation decks (PPT), dashboards/admin UI, and marketing/UI copy. Detects and blocks the AI-generated look before generation and audits it after: purple/gradient palettes, gradient text, Inter/Geist single-font pages, side-stripe cards, card-in-card, icon-tile 3-col grids, centered-hero macrostructure, fabricated metrics, emoji icons, over-animation, buzzword copy. Runs a clarify->context->plan->run->audit->revise flow with a two-phase audit gate (pre-emit self-critique + binary slop checklist) and hands Korean copy rewriting to humanize-korean. Triggers: 'AI 티 안 나게', 'slop 제거', 'anti-slop', '디자인 감사', '랜딩/덱/대시보드/카피 디자인', 'enterprise 디자인', 'make it not look AI-generated', 'audit this design', even when this skill is not named.
---

# anti-slop-design

웹/SaaS 랜딩, 발표 덱(PPT), 대시보드/admin UI, 마케팅·UI 카피를 만들거나 감사·개선할 때 "AI가 만든 티(slop)"를 **생성 전에 차단**하고 **생성 후에 감사**하는 enterprise anti-slop guard.

**핵심 명제:** slop = 브리프와 무관하게 나오는 기본값(**default-not-choice**). 모든 판정은 "이건 *이* 브리프를 위한 선택인가, *아무* 브리프에나 나올 선택인가"로 환원된다. 색·폰트·레이아웃이 "예쁜가"가 아니라 "선택인가"를 본다.

## 언제 쓰나

- 위 4개 artifact를 **새로 만들 때**(생성 전 Phase A + 생성 후 Phase B 게이트).
- 기존 산출물을 **감사/개선**할 때("이 랜딩 AI 티 나는지 봐줘", "덱 slop 잡아줘").
- 카피의 AI 티를 다룰 때 — 영문은 자체 탐지·스코어링, **한국어 재작성은 humanize-korean에 위임**.

## 안 하는 것 (scope)

- 디자인 "생성기"가 아니다. 방향·구조·게이트를 제공하고, 실제 구현은 호출자(또는 frontend-design 등)가 한다.
- 실행형 detection 엔진/편집 차단 hook 없음 — 리포트·권고만 한다.
- 덱 빌드 파이프라인(md->SVG->pptx) 미포함 — 원칙만, 빌드는 기존 도구(ppt-master/codex-image).
- 브랜드 색·폰트를 **기억으로 추측하지 않는다**. 자료 있으면 읽고, 없으면 `references/house-style.md` 기본값, 그래도 없으면 placeholder로 두고 사용자에게 묻는다.

## 흐름 (clarify -> context -> plan -> run -> audit -> revise)

### 1. Clarify
artifact 종류(web / ppt / dashboard / copy), 청중, 브랜드, 결정맥락을 식별. 모호하면 `AskUserQuestion`으로 좁힌다. 자동 가정 금지.

### 2. Context
- 해당 lane 규칙(`references/slop-taxonomy.md`의 lane 섹션) + `references/house-style.md` + `references/slop-taxonomy.md`의 VISUAL/STRUCTURAL을 로드.
- 카피가 범위면 `references/copy-rules.md`도 로드.
- 브랜드 자료(logo/palette/스크린샷) 있으면 읽어 brand-spec을 잡고, 없으면 house-style 기본값. **색을 지어내지 않는다.**

### 3. Plan
- "clean / modern / professional" 같은 **모호한 방향 금지**. 구체적 방향 1개를 고른다(예: enterprise editorial / technical minimal / research-lab calm / operator dashboard).
- 정보 위계(primary/secondary/tertiary)를 먼저 정의.
- **시각 산출물은 방향을 2~3개 제안하고 사용자가 택1**(show-don't-tell). 한 안만 밀지 않는다.

### 4. Run
택1 방향 + lane 규칙 + house-style 기본값으로 산출(또는 호출자에게 전달할 spec 작성). 모든 ban에는 **escape hatch**: 브리프의 명시 요구가 항상 이긴다(브랜드가 보라색이면 보라 허용, 청중이 어린이면 emoji 허용 등). 예외를 쓰면 그 줄에 이유를 명시.

### 5. Audit gate
아래 2단계 게이트(필수). 카피 포함 시 영문은 `references/copy-rules.md`로 탐지·스코어링하고, **한국어 산문 재작성은 `humanize-korean:humanize-korean`(fast 모드)로 핸드오프** 후 `final.md` 본문만 회수한다.

### 6. Revise
게이트에 걸린 항목을 고친 뒤 최종화. 출력은 항상 다음을 포함:
1. 사용한 design direction (구체 명칭)
2. 정보 위계
3. 적용한 anti-slop 결정 (무엇을 왜 피했나)
4. 산출물(또는 구현 spec)
5. 남은 리스크 / trade-off

## Audit gate (2단계)

### Phase A — 생성 전 self-critique (도구 불필요, 최고 레버리지)

**self-similarity probe:** "비슷한 브리프를 머릿속으로 처리했을 때 나올 선택과 같은가? 같다면 그건 *이* 브리프를 위한 선택이 아니다 — 교체하고 무엇을 왜 바꿨는지 적는다."

이어서 plan을 6축 1~5점으로 채점. **한 축이라도 3 미만이면 emit 전에 1회 수정:**
1. **Philosophy** — "왜"/관점이 있나, 아니면 그냥 레이아웃인가?
2. **Hierarchy** — 2초 안에 primary/secondary/tertiary가 읽히나?
3. **Specificity** — 이 브리프처럼 보이나, 아무-페이지처럼 보이나?
4. **Restraint** — 모든 요소가 제 값을 하나? (Chanel "악세서리 하나 빼기")
5. **Variety** — 직전 산출물과 구조적으로 다른가? (색만 바꾼 건 불인정)
6. **Honesty** — 지어낸 metric/testimonial/logo가 0인가?

루프 종료 휴리스틱: **"2회 수정은 정상, 3회면 디자인이 아니라 브리프가 틀린 것."** 3회째면 멈추고 브리프를 다시 묻는다.

### Phase B — 납품 전 binary 체크리스트

12항목, **모든 답이 "no"여야 통과**. 하나라도 "yes" = 고친다(납품 금지). 각 항목은 detector + fix 쌍.

| # | tell (답이 "no"여야 함) | fix |
|---|---|---|
| 1 | purple/rainbow/mesh gradient, 또는 gradient text? | flat committed accent, `bg-clip:text` 금지 |
| 2 | 단일 과용 font(Inter/Roboto/Geist/Space Grotesk) 또는 one-font 페이지? | display+body 의도적 pairing |
| 3 | side-stripe card / card-in-card / icon-tile-above-heading 3-col grid? | bg·weight 대비, stripe 제거, 카드 크기 변주 |
| 4 | cream-default / `#0D1117`-neon / 순수 `#000`·`#fff` base? | anchor hue로 tint한 committed palette |
| 5 | full-viewport centered hero / 전부 centered? | centered 요소 <=2, 비대칭 도입 |
| 6 | 장식용 `01/02/03` 번호 / 모든 섹션에 eyebrow chip? | 실제 sequence일 때만, 내용을 encode |
| 7 | generic Hero->3 features->testimonials->CTA->footer 골격? | 브리프 특정 macrostructure |
| 8 | 지어낸 metric / 가짜 testimonial / placeholder명(Acme/Jane Doe)? | 실제 수치, 라벨된 placeholder, 또는 사용자에게 질문 |
| 9 | emoji as icon / icon library 혼용? | 하나의 real icon set |
| 10 | 손그림 figurative SVG / 재그린 browser·phone·terminal chrome? | 실제 screenshot 또는 회색 placeholder |
| 11 | over-animation / `transition-all` / 균일 `hover:scale` / `prefers-reduced-motion` 없음? | 하나의 orchestrated moment + reduced-motion |
| 12 | copy: buzzword / "Not X, it's Y" 대비 / throat-clearing / 지어낸 specifics? | 직접 진술 후 한국어는 humanize-korean로 |

**numeric floor sweep** (자동검증 가능):
- contrast >=4.5:1 본문, >=3:1 large(>=24px 또는 >=18.67px bold)
- 본문 >=14px (slide 본문 >=24px)
- type-scale ratio >=1.25 (slide title >=2.5x body)
- line-length <=80ch, line-height >=1.3
- 색 <=3-4 (1 primary + 1 secondary + 1 accent + grays)
- touch target 44x44px
- 모든 장식 image에 honesty test (이미지를 빼도 정보가 안 줄면 slop)

### gate mechanics
- Phase A 주관 판단을 Phase B 체크리스트보다 **먼저** 형성한다(체크리스트가 비판을 anchoring하지 않도록).
- 선택: 산출물에 self-describing 스탬프(`<!-- anti-slop: A-pass · contrast ok · 1-12 no -->`)를 남겨 후속 drift 탐지.
- 모든 ban은 escape hatch 보유 — "브리프의 명시 요구가 항상 이긴다". 예외는 인라인으로 사유 표기.

## reference 로딩 가이드

| 상황 | 로드 |
|---|---|
| 모든 시각 작업 | `references/slop-taxonomy.md` (VISUAL + STRUCTURAL) |
| lane별 규칙 | `references/slop-taxonomy.md`의 web / ppt / dashboard 섹션 |
| 카피 포함 | `references/copy-rules.md` (+ 한국어는 humanize-korean 핸드오프) |
| 기본 제안값 | `references/house-style.md` |

자세한 detector 목록·수치·예시는 본문에 중복하지 말고 reference에서 progressive disclosure로 가져온다.

## humanize-korean 핸드오프 (카피)

- 경계: anti-slop-design = 시각/구조 + **영문 카피 탐지·스코어링** 소유. humanize-korean = **한국어 산문 재작성** 소유.
- 호출: 한국어 카피 재작성이 필요하면 `humanize-korean:humanize-korean`을 호출(기본 fast 모드, >=8000자 또는 정밀 필요 시 strict). 출력 `final.md`의 본문만 회수(HTML 주석 메타 제외).
- 금지: stop-slop류 무딘 절대금지(부사 전면금지, em-dash 전면금지, 3항목 리스트 금지)를 한국어로 복제하지 않는다 — 전역 가이드·humanize-korean의 한국어 친화 완화 스탠스를 따른다.
