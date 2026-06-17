# ChatGPT 공유 대화 — 전체 복원본

> 출처: https://chatgpt.com/share/6a31408f-7008-83e8-bd59-f28bb3fb854e  
> 복원 방식: firecrawl `rawHtml` 페이로드(React Router stream)에서 메시지 원문 추출 — 화면 가상화로 빠졌던 코드블록까지 100% 복원. 인용 각주 마커는 제거.


---

### ChatGPT — thinking

먼저 GitHub 중심으로 실제 사용성과 최신성이 있는 자료를 걸러 PPT, 웹, 문구, Skill·프롬프트 관점으로 나눠 핵심만 정리하겠습니다. Star 수와 유지보수 여부는 가능한 현재 기준으로 확인해 출처를 붙이겠습니다.

---

### ChatGPT — thinking

초기 검색상 프롬프트 단독보다 DESIGN.md, agent용 SKILL.md, UI 감사 guideline/linter가 더 직접적입니다. 1K+ 기준에서 빠지는 신생 anti-slop 특화 도구는 별도로 표시하겠습니다.

---

### ChatGPT

조사 결과, 지금 이 분야는 **프롬프트 단독**보다 **`DESIGN.md` + `SKILL.md` + audit loop** 쪽으로 가는 게 훨씬 강합니다. 특히 개인 플러그인으로 쓰려면 “좋은 디자인을 생성하는 프롬프트”보다, 매번 AI가 참고할 **디자인 컨텍스트 파일**, **생성 스킬**, **slop 검사 규칙**을 묶는 구조가 맞습니다.

단, GitHub star는 1차 필터로만 봐야 합니다. 최근 GitHub star 조작 연구에서 수백만 단위의 의심 fake star가 보고됐고, 특히 2024년 이후 AI/LLM 관련 저장소에서 fake-star 활동이 늘었다는 분석이 있습니다. 그래서 아래 평가는 star뿐 아니라 최근성, 문서화, 사용 구조, 실제 `SKILL.md`/`DESIGN.md` 존재 여부, 목적 적합성을 같이 봤습니다. 

```text
최종 추천 구조

사용자 요구사항 / 브랜드 자료 / 참고 이미지
        ↓
brand-spec.md + DESIGN.md
        ↓
웹 UI Skill
Hallmark / frontend-design / Huashu
        ↓
PPT Skill
frontend-slides / guizang-ppt / html-ppt / open-slide
        ↓
Copy Skill
stop-slop
        ↓
Audit Loop
slop gates / visual critique / rewrite checklist
```

## 1. 먼저 봐야 할 핵심 흐름: DESIGN.md

Google이 2026년 4월 Stitch에 `DESIGN.md` 개념을 도입하면서, AI가 단순히 색상값을 복사하는 게 아니라 **디자인 시스템의 의도, 색상 용도, 접근성 기준, 브랜드 규칙**까지 읽도록 하는 방향이 공식화됐습니다. Google은 `DESIGN.md` draft spec도 공개했고, AI agent가 WCAG 기준까지 검증할 수 있게 하는 예시를 들었습니다. 

개인 플러그인 관점에서는 이게 가장 중요합니다. 매번 프롬프트에 “AI스럽지 않게 해줘”라고 쓰는 대신, 프로젝트 루트에 아래 같은 파일들을 두는 방식입니다.

```text
/project
  DESIGN.md
  brand-spec.md
  AGENTS.md 또는 SKILL.md
  /references
    anti-slop-rules.md
    ppt-rules.md
    copy-rules.md
    layout-patterns.md
```

### 추천 리소스

| 리소스 | 성격 | 핵심 내용 | 가져올 것 |
|---|---:|---|---|
| Google `DESIGN.md` spec | 공식 흐름 | AI가 브랜드 색상, 역할, 접근성, 디자인 의도를 이해하도록 하는 디자인 명세 개념 | 개인 플러그인의 최상위 디자인 컨텍스트 형식  |
| `VoltAgent/awesome-design-md` | DESIGN.md 모음 | 유명 브랜드/사이트의 디자인 토큰, 타이포그래피, 컴포넌트, spacing 등을 `DESIGN.md` 형태로 모은 큐레이션. GitHub상 약 90.5k stars로 표시됨 | 레퍼런스 DESIGN.md 샘플 추출용  |
| `VoltAgent/awesome-claude-design` | Claude Design용 DESIGN.md | Claude Design에서 바로 쓸 수 있는 `DESIGN.md` inspiration 모음. 문서상 68개 디자인 inspiration을 제공하고, token/rule/rationale을 한 파일에 유지하는 구조를 설명함 | “브랜드별 look & feel 템플릿” 샘플로 좋음  |
| `alexpate/awesome-design-systems` | 디자인 시스템 큐레이션 | 디자인 시스템, UI 라이브러리, 패턴 라이브러리, voice/tone 자료를 모은 오래된 큐레이션. 약 25.1k stars | DESIGN.md 작성 시 신뢰도 높은 원천 레퍼런스  |

내 판단으로는 `awesome-design-md`와 `awesome-claude-design`은 그대로 믿기보다는, **좋은 DESIGN.md 포맷을 훔쳐오는 샘플 저장소**로 쓰는 게 맞습니다. 특히 star 수가 매우 높게 보이는 신생 AI 관련 저장소는 popularity signal로만 보고, 실제 내용은 직접 검토하는 편이 안전합니다.

## 2. 웹사이트 / SaaS 랜딩 / UI anti-slop 후보

### 2.1 Anthropic 공식 `frontend-design` skill

Anthropic의 공식 skills 저장소는 약 151k stars로 표시되고, Skills를 “Claude가 동적으로 로드하는 instructions, scripts, resources 폴더”로 설명합니다. Anthropic 문서에서도 Skill은 `SKILL.md`와 YAML frontmatter, progressive disclosure, optional scripts/resources를 갖는 모듈형 능력으로 설명됩니다. 

그 안의 `frontend-design` skill은 “distinctive, intentional visual design”과 “templated defaults가 아닌 선택”을 강조합니다. 또 “generic AI aesthetics를 피하고, 코딩 전에 bold aesthetic direction을 먼저 정하라”는 방향성을 갖고 있습니다. 

**가져올 핵심:**

```text
1. 코딩 전에 aesthetic direction을 먼저 정한다.
2. 기본 SaaS 템플릿으로 시작하지 않는다.
3. 색상/타이포/spacing/texture/motion을 의도적으로 선택한다.
4. 컴포넌트 조립보다 visual point of view를 먼저 만든다.
```

### 2.2 `nutlope/hallmark`

현재 목적에 가장 직접적으로 맞는 저장소입니다. 문서상 Hallmark는 Claude Code, Cursor, Codex용 design skill이며 “refuses to look AI-generated”를 전면에 둡니다. 특징은 macrostructure 선택, 20개 theme, 57개 slop-test gate, pre-emit self-critique, `build/audit/redesign/study` 네 가지 동작, 그리고 `study`를 통해 portable `design.md`를 만들 수 있다는 점입니다. 약 3.1k stars로 표시됩니다. 

설치도 Codex/Claude/Cursor 계열에 맞춰 되어 있습니다.

```bash
npx skills add nutlope/hallmark
```

**가져올 핵심:**

```text
Hallmark에서 훔칠 것
- slop-test gate 구조
- build / audit / redesign / study verb 구조
- theme만 바꾸는 수준이 아니라 macrostructure를 바꾸는 방식
- 생성 전에 자기 비판하는 pre-emit critique
- 결과물에서 design.md를 역추출하는 흐름
```

이건 영재님 목적의 “개인 plugin”에 거의 바로 들어갈 만합니다.

### 2.3 `alchaincyf/huashu-design`

Huashu는 웹, 앱 프로토타입, PPT, 모션, 인포그래픽까지 다루는 다목적 디자인 skill입니다. 약 18.9k stars로 표시되며, 문서에서 “brand assets가 있으면 logo, palette, UI screenshot을 읽어서 brand character를 잡고, 없으면 40개 HTML-native style library로 AI slop을 피한다”고 설명합니다. Claude Code, Cursor, Codex, OpenClaw, Hermes 지원도 명시되어 있습니다. 

특히 중요한 건 **brand asset protocol**입니다. Huashu는 브랜드 색을 기억으로 추측하지 말고, ask/search/download/grep/write 흐름으로 `brand-spec.md`를 만들라고 합니다. 이건 anti-slop에서 매우 중요합니다. AI스러운 결과물의 큰 원인이 “구체적 근거 없이 그럴듯한 브랜드 톤을 꾸며내는 것”이기 때문입니다. 

```bash
npx skills add alchaincyf/huashu-design
```

**가져올 핵심:**

```text
1. 브랜드 자료를 먼저 수집한다.
2. brand-spec.md를 만든다.
3. 브랜드 색상/폰트/무드를 기억으로 추측하지 않는다.
4. 최소 3개 variant를 만든 뒤 고른다.
5. 5차원 디자인 리뷰를 수행한다.
```

### 2.4 `Owl-Listener/designer-skills`

이건 생성기라기보다는 디자이너 업무 전체를 agent skill로 쪼갠 저장소입니다. 문서상 239 skills, 88 commands, 33 plugins를 포함하고, design research, design systems, UX strategy, UI design, interaction design, prototyping/testing, design ops, visual critique 등을 나눠 둡니다. 약 1.6k stars입니다. 

**가져올 핵심:**

```text
- anti-slop을 단일 프롬프트로 보지 않고,
  research / system / UI / interaction / critique로 쪼개는 구조
- visual critique plugin 구조
- design system plugin 구조
```

## 3. PPT / 발표자료 anti-slop 후보

PPT 쪽은 흥미롭게도 “PowerPoint 파일을 바로 만들기”보다 **HTML 기반 slide system → export** 흐름이 강합니다. 이유는 레이아웃, 타이포그래피, 모션, preview, 반응형 조정이 더 쉽기 때문입니다.

```text
AI brief
  ↓
HTML / React slide
  ↓
preview 선택
  ↓
visual polish
  ↓
PDF / PPTX export
```

### 3.1 `zarazhangrui/frontend-slides`

PPT 쪽에서 가장 강한 후보 중 하나입니다. 문서상 “coding-agent skill for stunning HTML presentations”이고, scratch 제작과 PowerPoint conversion을 지원합니다. 또 `show-don’t-tell` 방식으로 preview를 생성하고 사용자가 aesthetic을 선택하게 하는 흐름이 있습니다. 약 21.9k stars로 표시됩니다. 

**가져올 핵심:**

```text
- 먼저 여러 visual direction preview를 만든다.
- 사용자가 aesthetic을 선택한다.
- 선택된 방향으로 전체 deck을 확장한다.
- PPT를 문서가 아니라 visual artifact로 다룬다.
```

이건 “AI가 만든 밋밋한 슬라이드”를 줄이는 데 꽤 직접적입니다.

### 3.2 `op7418/guizang-ppt-skill`

Guizang PPT Skill은 Claude Code/Codex에서 single-file HTML horizontal deck, cover image 등을 만드는 skill입니다. 문서상 editorial magazine/e-ink, Swiss International 같은 visual system을 내장하고 있고, 약 17.6k stars로 표시됩니다. 

```bash
npx skills add https://github.com/op7418/guizang-ppt-skill --skill guizang-ppt-skill
```

**가져올 핵심:**

```text
- editorial / Swiss 같은 명확한 시각 언어를 먼저 정한다.
- 슬라이드를 단순 bullet list가 아니라 editorial page로 다룬다.
- single-file HTML로 결과물을 관리한다.
```

### 3.3 `lewislulu/html-ppt-skill`

이 저장소는 36 themes, 15 full-deck templates, 31 layouts, 47 animations, presenter mode를 제공하는 HTML presentation skill이라고 설명합니다. 약 6.1k stars입니다. 

**가져올 핵심:**

```text
- full-deck template과 layout library를 명시적으로 둔다.
- 슬라이드 타입별 layout을 강제한다.
- presenter mode까지 고려한다.
```

### 3.4 `1weiho/open-slide`

Open Slide는 agent를 위한 slide framework로, 자연어 brief를 입력하면 coding agent가 React slide를 만들고, canvas/scaling/navigation/hot reload/present mode를 처리합니다. 1920x1080 canvas와 arbitrary React component를 지원한다고 설명합니다. 약 5.4k stars입니다. 

**가져올 핵심:**

```text
- 장기적으로는 HTML보다 React slide가 더 강력하다.
- chart, diagram, animation, interaction을 component로 다룬다.
- 고정 16:9 canvas를 기준으로 시각 품질을 통제한다.
```

### 3.5 `zarazhangrui/beautiful-html-templates`

이건 HTML slide template 모음입니다. 문서상 agent가 `AGENTS.md`를 읽고 brief에 맞는 template을 선택한 뒤 내용을 clone/adapt하는 구조입니다. 34개 template과 cover/mid/later screenshot을 제공한다고 설명하며, 약 2.9k stars입니다. 

**가져올 핵심:**

```text
- template을 “랜덤 장식”이 아니라 brief와 matching한다.
- cover / mid / later slide를 한 세트로 본다.
- screenshot preview 기반으로 선택하게 한다.
```

### 3.6 `slidevjs/slidev`

Slidev는 AI anti-slop 전용은 아니지만, Markdown 기반 발표자료 프레임워크로 매우 성숙합니다. 문서상 Markdown 기반, developer-friendly, themable, interactive, presenter mode, drawing, LaTeX, diagrams, icons, editor, recording, PDF/PNG/PPTX export 등을 지원합니다. 약 47.2k stars이고, 최근 릴리즈도 2026년 6월로 표시됩니다. 

**가져올 핵심:**

```text
- PPT 생성 결과물을 git-friendly하게 관리한다.
- content와 visual theme를 분리한다.
- diagram, LaTeX, export를 안정적으로 처리한다.
```

## 4. 문구 / 카피 anti-slop 후보

### 4.1 `hardikpandya/stop-slop`

문구 쪽에서는 이 저장소가 가장 직접적입니다. “AI tells”를 제거하는 skill이고, predictable phrases, structures, rhythms를 다룹니다. 폴더 구조도 `SKILL.md`, `references/phrases.md`, `structures.md`, `examples.md`로 나뉘어 있습니다. 평가 차원은 directness, rhythm, trust, authenticity, density이고, 50점 만점 기준 35점 미만이면 revise하는 방식입니다. 약 10.8k stars입니다. 

**가져올 핵심:**

```text
- 문구 anti-slop은 디자인 anti-slop과 별도 skill로 둔다.
- 금지어 목록만 두지 말고 sentence rhythm, trust, density를 본다.
- 점수화 후 threshold 아래면 재작성한다.
```

AI스러운 문구의 대표 증상은 아래처럼 정리할 수 있습니다.

```text
AI copy slop
├─ 과장어: innovative, seamless, cutting-edge, unlock, transform
├─ 빈 문장: designed to help you ..., empowers teams to ...
├─ 대칭 구조 남발: not only A, but also B
├─ 추상 명사 과다: efficiency, productivity, insights, solutions
└─ 증거 없음: 숫자, 사례, 제약, trade-off가 없음
```

### 4.2 DAIR `Prompt Engineering Guide`

DAIR의 Prompt Engineering Guide는 디자인 전용은 아니지만, prompt engineering, context engineering, AI agents 관련 자료를 체계적으로 모은 대형 저장소입니다. 약 75.7k stars로 표시됩니다. 

**가져올 핵심:**

```text
- anti-slop prompt를 만들 때 structure, examples, evaluation을 분리한다.
- 단순 지시보다 few-shot / rubric / critique loop를 넣는다.
- Skill 내부 reference 문서 설계에 참고한다.
```

## 5. 보조 인프라: 디자인 시스템, UI 컴포넌트, 검증

여기 있는 것들은 “AI slop을 제거하는 skill”은 아니지만, 개인 플러그인의 기반으로 쓸 수 있습니다.

| 리소스 | 용도 | 주의점 |
|---|---|---|
| `storybookjs/storybook` | UI 컴포넌트를 isolated 환경에서 build/document/test하는 industry-standard workshop. 약 90.4k stars이고 2026년 6월 최신 릴리즈가 표시됨 | 생성 결과를 실제 컴포넌트 단위로 검수할 때 좋음  |
| `shadcn-ui/ui` | accessible component와 code distribution platform. 약 117k stars | raw default 그대로 쓰면 오히려 AI SaaS 느낌이 강해질 수 있음  |
| `tailwindlabs/tailwindcss` | utility-first CSS framework. 약 95.6k stars | 속도는 좋지만, `rounded-2xl + shadow + gradient + card grid` 남발하면 slop화됨  |
| `nicobailon/visual-explainer` | 복잡한 terminal output을 styled HTML, diagram, diff review로 바꾸는 skill. 약 8.8k stars | 기술 설명용 diagram/page 생성에 좋음  |

## 6. 전체 스킬 카탈로그로 볼 만한 것

`VoltAgent/awesome-agent-skills`는 official/community agent skills를 모은 큐레이션이고, Claude Code, Codex, Antigravity, Gemini CLI, Cursor, GitHub Copilot, OpenCode, WindSurf 호환을 언급합니다. 문서상 “AI-slop generated가 아닌 hand-picked”를 강조하며 약 25.5k stars로 표시됩니다. 

`travisvn/awesome-claude-skills`는 Claude skill의 기본 구조를 설명하는 데 좋습니다. Skill을 instructions, scripts, resources가 들어 있는 폴더로 보고, progressive disclosure를 강조합니다. 약 13.5k stars입니다. 

`ComposioHQ/awesome-claude-skills`는 1000개 이상의 production-ready practical skills/plugins를 모은 큐레이션이라고 설명하며, Claude.ai, Claude Code, Codex, Cursor, Gemini, Antigravity 등을 함께 언급합니다. 약 64.8k stars로 표시됩니다. 

이 세 개는 직접 anti-slop 엔진이라기보다는, **설치 방식과 skill packaging 관례를 보는 용도**가 좋습니다.

## 7. 내 기준 Top 후보

개인 plugin으로 실제 합칠 때의 우선순위입니다.

| 우선순위 | 후보 | 이유 |
|---:|---|---|
| 1 | `nutlope/hallmark` | 웹/랜딩 anti-slop 목적과 가장 직접적으로 맞음. 57 slop-test gate, audit/redesign/study 구조가 핵심  |
| 2 | Anthropic `frontend-design` | 공식 skill이며 “generic AI aesthetics 회피”를 명시적으로 다룸  |
| 3 | `alchaincyf/huashu-design` | 브랜드 자료 기반 `brand-spec.md`, 40 style library, PPT/프로토타입/인포그래픽까지 커버  |
| 4 | `zarazhangrui/frontend-slides` | PPT 쪽에서 preview-first, show-don’t-tell 방식이 강함  |
| 5 | `op7418/guizang-ppt-skill` | editorial/Swiss visual system 기반 HTML deck 생성에 좋음  |
| 6 | `hardikpandya/stop-slop` | 카피 anti-slop을 별도 평가축으로 분리하기 좋음  |
| 7 | Google `DESIGN.md` spec | 장기적으로 모든 agent가 읽을 디자인 명세의 중심축이 될 가능성이 큼  |
| 8 | `awesome-design-md` / `awesome-claude-design` | 브랜드별 DESIGN.md 샘플을 뽑아 plugin reference로 쓰기 좋음  |

## 8. Anti-slop plugin으로 합칠 때의 설계안

```text
anti-ai-slop-design/
  SKILL.md
  DESIGN.md
  brand-spec.md

  references/
    visual-slop-taxonomy.md
    website-rules.md
    ppt-rules.md
    copy-rules.md
    banned-phrases.md
    layout-patterns.md
    brand-protocol.md

  scripts/
    audit_html.ts
    audit_copy.py
    screenshot_compare.ts
    contrast_check.ts

  examples/
    good-landing-pages.md
    good-decks.md
    bad-ai-slop-examples.md
```

`SKILL.md`는 이런 방향이 좋습니다.

```markdown
---
name: anti-ai-slop-design
description: Use when creating, auditing, or redesigning websites, SaaS landing pages, slide decks, UI prototypes, visual reports, or marketing copy. This skill removes generic AI aesthetics, weak visual hierarchy, templated SaaS layouts, vague copy, and decorative filler.
---

# Anti AI-Slop Design Skill

## Operating Principle

Do not generate immediately.

First identify:
1. Audience
2. artifact type
3. brand context
4. visual direction
5. information hierarchy
6. proof points
7. constraints

Then produce:
1. design direction
2. structure
3. draft
4. critique
5. revision
6. final output

## Hard Rules

- Never use generic SaaS copy without specific proof.
- Never use gradients, cards, icons, or 3D objects as filler.
- Never use a layout unless it has an information hierarchy reason.
- Never infer brand colors from memory.
- Prefer one strong visual idea over many decorative effects.
- Every slide needs a single job.
- Every section needs a reason to exist.
- Every claim needs evidence, specificity, or removal.

## Required Audit

Score every output on:
1. visual specificity
2. hierarchy
3. typography
4. information density
5. copy directness
6. brand fit
7. originality
8. accessibility
9. production readiness

If below threshold, revise before showing final.
```

## 9. 이번 리서치에서 뽑은 핵심 원칙

첫째, **AI slop은 스타일 문제가 아니라 컨텍스트 문제**입니다. 좋은 결과물은 “예쁘게”라는 지시보다 `DESIGN.md`, `brand-spec.md`, visual references, component rules를 통해 반복 가능한 기준을 가집니다. Google의 `DESIGN.md` 방향과 Anthropic Skill 구조가 이 흐름을 잘 보여줍니다. 

둘째, **웹사이트 anti-slop은 macrostructure가 핵심**입니다. 단순히 색상, border-radius, gradient를 바꾸는 게 아니라 hero, proof, narrative, CTA, comparison, demo, trust section의 순서와 밀도를 다르게 설계해야 합니다. Hallmark가 이 부분을 가장 직접적으로 다룹니다. 

셋째, **PPT anti-slop은 HTML/React 기반 preview-first 흐름이 유리**합니다. `frontend-slides`, `guizang-ppt-skill`, `html-ppt-skill`, `open-slide` 모두 PowerPoint를 직접 만지는 것보다 HTML/React deck을 먼저 만들고 preview/export하는 흐름이 강합니다. 

넷째, **문구 anti-slop은 디자인과 별도 레이어로 둬야 합니다**. 좋은 UI라도 “혁신적인 솔루션으로 생산성을 극대화하세요” 같은 문장이 들어가면 바로 AI 냄새가 납니다. `stop-slop`처럼 phrases, structures, examples, scoring을 분리하는 구조가 좋습니다. 

다섯째, **shadcn/Tailwind는 기반이지 취향 엔진이 아닙니다**. 빠르게 만들기에는 좋지만, 아무 규칙 없이 쓰면 오히려 가장 흔한 AI SaaS landing look으로 수렴합니다. 그래서 component library 위에 `DESIGN.md`, anti-slop rules, audit loop를 반드시 얹는 게 맞습니다. 

## 10. 바로 적용할 추천 조합

가장 현실적인 1차 조합은 이겁니다.

```text
Core
├─ Google DESIGN.md spec 개념
├─ awesome-design-md에서 reference 추출
└─ brand-spec.md 직접 생성

Website
├─ Anthropic frontend-design
├─ Hallmark
└─ Huashu brand protocol

Slides
├─ frontend-slides
├─ guizang-ppt-skill
└─ open-slide 또는 html-ppt-skill

Copy
└─ stop-slop

Audit
├─ Hallmark slop gates
├─ Huashu 5D review
└─ 자체 anti-slop checklist
```

내 결론은 이렇습니다.

**영재님이 만들 플러그인은 “프롬프트 모음”으로 만들면 약하고, `anti-ai-slop-design`이라는 Skill 패키지로 만들어야 합니다.**  
그 안에 `DESIGN.md`, `brand-spec.md`, `ppt-rules.md`, `copy-rules.md`, `slop-taxonomy.md`, `audit checklist`를 넣고, Hallmark/Huashu/frontend-slides/stop-slop의 구조를 흡수하는 방식이 가장 좋아 보입니다.

---

### You

perplexity는 위와 같이 답변 줬는데, 그럼 너가 인터뷰 해서 스킬 만들어줄 수 있어? pbakaus/impeccable 이걸 추천해주는 것 같네

---

### ChatGPT — thinking

가능합니다. 먼저 Perplexity 자료와 `pbakaus/impeccable`의 실제 방향을 확인해서, 그대로 복제하지 않고 영재님 개인 플러그인용으로 재구성하겠습니다. 인터뷰는 길게 끌지 않고 “스킬 설계에 필요한 결정값”만 뽑는 방식으로 하겠습니다.

---

### ChatGPT

가능해. 그리고 `pbakaus/impeccable` 추천은 꽤 타당해 보여. 다만 Perplexity 자료에는 `41개 결정론적 규칙`이라고 되어 있는데, 현재 공식 GitHub/사이트 기준으로는 **44개 deterministic detector rules**, **23 commands**, **PRODUCT.md + DESIGN.md 기반 context flow**가 핵심으로 보인다.  

내가 만들 방향은 `impeccable`을 그대로 복제하는 게 아니라, 영재님 용도에 맞춰 **PPT + 홈페이지 + 문구 + 디자인 감사까지 포함한 개인용 anti-slop skill**로 재구성하는 게 맞다.

```text
impeccable 참고 구조
        ↓
영재님 개인 plugin 구조로 재설계
        ↓
SKILL.md
DESIGN.md template
PRODUCT.md template
anti-slop checklist
ppt-rules.md
copy-rules.md
audit-gates.md
```

`impeccable`은 특히 좋은 점이 있다. 웹/프론트엔드에서 AI가 자주 만드는 “Inter 폰트, 보라-파랑 그라데이션, 카드 안의 카드, 모든 헤딩 위 아이콘” 같은 흔한 패턴을 명시적으로 겨냥하고, `/impeccable init`으로 `PRODUCT.md`와 `DESIGN.md`를 만들어 이후 명령이 계속 그 맥락을 읽게 한다. 

그럼 인터뷰 시작하자. 아래 답변만 주면 내가 다음 단계에서 바로 **1차 `SKILL.md` 초안**으로 만들어줄게.

## 1차 인터뷰

### 1. 스킬 이름

개인 plugin 이름을 뭐로 할까?

예시:

```text
anti-slop-design
non-ai-design
taste-guard
impeccable-lite
human-design-skill
2dzero-design
```

나는 개인적으로는 **`anti-slop-design`** 또는 **`taste-guard`**가 좋아 보인다.

### 2. 주요 사용 환경

어디에서 제일 많이 쓸 예정이야?

```text
1. Claude Code
2. Codex CLI
3. Cursor
4. ChatGPT
5. 전부
```

### 3. 최우선 산출물

우선순위만 정해줘.

```text
A. 홈페이지 / SaaS 랜딩
B. PPT / 발표자료
C. 기술 제안서 / 리포트
D. 포트폴리오 / 회사소개
E. UI 대시보드 / 관리자 페이지
F. 마케팅 문구
```

예: `A > B > C > F`

### 4. 디자인 성향

영재님이 싫어하는 건 어느 쪽에 가까워?

```text
1. 너무 SaaS 템플릿 같은 디자인
2. 너무 미래지향적/네온/그라데이션 과한 디자인
3. 너무 기업용 무료 템플릿 같은 디자인
4. 너무 토스/리니어/버셀 흉내낸 디자인
5. 너무 카드형 UI만 반복하는 디자인
6. 전부
```

### 5. 좋아하는 방향

반대로 원하는 느낌은?

```text
1. 미니멀하지만 날카로운 느낌
2. 기술회사답지만 과장 없는 느낌
3. 편집디자인/매거진 같은 느낌
4. 공공기관/제안서에도 납품 가능한 안정감
5. 스타트업 랜딩처럼 임팩트 있는 느낌
6. 포트폴리오처럼 개성 있는 느낌
```

### 6. 금지하고 싶은 AI 냄새

아래 중 “무조건 막고 싶은 것” 골라줘.

```text
- Inter / Roboto 기본 폰트 남발
- 보라색/파란색 그라데이션 히어로
- rounded card grid 3개 반복
- 의미 없는 Lucide 아이콘
- glassmorphism / blur 남발
- “혁신적인”, “최적화된”, “미래지향적” 문구
- “Learn More”, “Get Started” 같은 CTA
- 내용 없는 다이어그램
- bullet만 많은 PPT
- AI 생성 이미지/3D 오브젝트 티 나는 것
```

### 7. PPT 스타일

PPT는 어느 쪽이 필요해?

```text
1. 정부과제 / 제안서형
2. 기술 발표 / 세미나형
3. 스타트업 pitch deck형
4. 회사소개서형
5. 강의자료형
6. HTML slide → PDF/PPT export형
```

### 8. 홈페이지 스타일

홈페이지는 어떤 용도에 가까워?

```text
1. 개인/회사 포트폴리오
2. AI 개발 외주 랜딩
3. SaaS 제품 랜딩
4. 연구소/Labs 페이지
5. 강의/교육 판매 페이지
6. 공공기관 납품용 신뢰형 페이지
```

### 9. 카피 문체

문구는 어느 정도로 다듬을까?

```text
1. 매우 담백하게
2. 개발자스럽게 정확하게
3. 영업/마케팅 느낌 약간 포함
4. 공공기관 제안서처럼 신뢰감 있게
5. 스타트업처럼 짧고 강하게
```

### 10. 스킬의 동작 방식

스킬이 결과물을 만들 때 어떤 방식이 좋아?

```text
1. 바로 결과물 생성
2. 먼저 디자인 방향 3개 제안 후 선택
3. 먼저 anti-slop audit 후 수정
4. 초안 생성 → 스스로 비판 → 개선안 생성
5. 항상 PRODUCT.md / DESIGN.md부터 만들기
```

내 추천은 `5 → 2 → 4 → 결과물` 흐름이다.

```text
PRODUCT.md / DESIGN.md 생성
        ↓
디자인 방향 3개 제안
        ↓
초안 생성
        ↓
anti-slop audit
        ↓
수정본 생성
```

### 11. 최종 패키지 형태

내가 만들어줄 결과물을 어떤 형태로 원해?

```text
1. SKILL.md 하나
2. SKILL.md + references/*.md
3. Claude Code / Codex용 폴더 구조 전체
4. 설치 가능한 GitHub repo 템플릿 형태
```

추천은 **3번**이다.

### 12. 개인 브랜드 반영 여부

`2dzero`, 개인 AI 외주, 컴퓨터비전/LLM/RAG/Agent, 강의/컨설팅 같은 영재님 개인 맥락을 스킬에 반영할까?

```text
1. 반영
2. 반영하지 않고 범용으로
3. 기본은 범용, 예시만 영재님용
```

나는 **3번**이 좋아 보인다. 그래야 나중에 고객사/프로젝트별로 재사용하기 쉽다.

답변은 짧게 이렇게 줘도 돼.

```text
1. anti-slop-design
2. 1,2,3
3. A > B > F > C
4. 6
5. 2,4
6. 전부
7. 1,2,4,6
8. 2,4,6
9. 2,4
10. 5
11. 3
12. 3
```

---

### You

1. anti-slop-design 2. claude code, codex, hermes agent
3. A>B,E,F>D>C
4. 2번! 나머진 엔터프라이즈 급으로만 만들고, 내용 전달이 괜찮으면 상관없어 
5. 전부다 ㅋㅋ 
6. 전부다 ㅋㅋ 

일단 여기까지만 답해줄게

---

### ChatGPT

좋아. 여기까지 답변 기준으로는 방향이 꽤 명확해졌어.

`impeccable`을 참고하는 건 맞고, 여기에 **PPT / 대시보드 / 마케팅 문구 / Hermes Agent 호환성**까지 얹는 형태가 맞다. `impeccable`은 공식적으로 “1 skill, 23 commands, curated anti-patterns”를 내세우고 Claude Code, Codex CLI 등 주요 AI coding harness에서 동작한다고 설명한다.  Perplexity 자료에서도 `pbakaus/impeccable`은 Anthropic `frontend-design`을 확장한 도구이며 typography, color, motion, spatial, interaction, responsive, UX writing 같은 레퍼런스를 포함한다고 정리되어 있다. 

## 지금까지 확정된 스킬 방향

```text
anti-slop-design
├─ Target Agent
│  ├─ Claude Code
│  ├─ Codex
│  └─ Hermes Agent
│
├─ Priority
│  ├─ A. 홈페이지 / SaaS 랜딩
│  ├─ B. PPT / 발표자료
│  ├─ E. UI 대시보드 / 관리자 페이지
│  ├─ F. 마케팅 문구
│  ├─ D. 포트폴리오 / 회사소개
│  └─ C. 기술 제안서 / 리포트
│
├─ Main Enemy
│  └─ 과한 미래지향 / 네온 / 그라데이션 / AI 생성 티
│
└─ Desired Quality
   ├─ 엔터프라이즈급
   ├─ 정보 전달력 우선
   ├─ 기술회사다운 신뢰감
   ├─ 디자인적으로는 밋밋하지 않음
   └─ AI스러운 장식과 문구는 강하게 차단
```

Hermes Agent까지 고려하면 구조는 잘 맞다. Hermes 공식 문서 기준으로 Hermes의 Skill은 필요할 때 로드되는 지식 문서이고, `agentskills.io` open standard와 호환되며 기본 경로는 `~/.hermes/skills/`다.  그래서 Claude Code / Codex / Hermes Agent 공통으로 쓰려면 **특정 툴 전용 명령보다 `SKILL.md + references/*.md` 중심**으로 만드는 게 안전하다.

## 내가 해석한 디자인 톤

영재님이 싫어하는 건 “디자인을 아예 하지 말자”가 아니라, 아래 쪽이다.

```text
싫은 것
├─ 보라/파랑 네온 그라데이션
├─ AI SaaS 랜딩 특유의 반짝이는 히어로
├─ 내용 없이 멋있는 척하는 3D 오브젝트
├─ 의미 없는 glassmorphism
├─ 기술력 있어 보이려는 가짜 미래감
└─ 혁신/최적화/미래지향 같은 빈 문구

허용되는 것
├─ 엔터프라이즈 SaaS처럼 정돈된 구조
├─ 공공기관/기업 납품에도 무리 없는 안정감
├─ 기술 설명이 잘 되는 시각화
├─ 적당히 세련된 레이아웃
└─ 내용 전달이 명확한 카드/표/다이어그램
```

즉 이 스킬은 “튀는 디자인 생성기”가 아니라 **enterprise anti-slop design guard**가 되어야 한다.

## 스킬 컨셉 초안

아래는 지금까지 답변을 반영한 1차 설계 브리프야.

:::writing{variant=\"document\" id=\"72841\"}
# anti-slop-design

## Purpose

`anti-slop-design` is a cross-agent design skill for Claude Code, Codex, and Hermes Agent.

It is used when creating, auditing, or improving:

- SaaS landing pages
- Product websites
- Presentation decks
- Dashboards and admin UI
- Marketing copy
- Portfolio and company introduction pages
- Technical proposal or report visuals

The skill removes generic AI design patterns and replaces them with enterprise-grade, intentional, brand-aware, content-first design.

## Core Design Position

Do not make things look futuristic just because they are AI-related.

Avoid:

- Neon gradients
- Purple-blue futuristic hero sections
- Decorative 3D AI objects
- Glassmorphism used as filler
- Generic SaaS cards
- Meaningless icons
- Over-polished marketing copy
- Empty visual diagrams
- Bullet-heavy presentation slides

Prefer:

- Enterprise-grade clarity
- Strong information hierarchy
- Precise technical communication
- Mature visual restraint
- Specific brand decisions
- Evidence-backed copy
- Diagrams that explain real structure
- Layouts that support reading and decision-making

## Priority Order

1. Website / SaaS landing page
2. Presentation / PPT
3. Dashboard / admin UI
4. Marketing copy
5. Portfolio / company intro
6. Technical proposal / report

## Default Aesthetic

The default style is:

- Enterprise technical
- Calm but sharp
- Mature
- Trustworthy
- Content-first
- Low-noise
- High-signal

The skill must not default to \"clean, modern, professional\" as a vague direction.

Instead, it must choose a concrete direction such as:

- Enterprise editorial
- Technical minimal
- Industrial product
- Research-lab calm
- Operator dashboard
- Public-sector credible
- Developer-tool precise

## Hard Anti-Slop Rules

Never use these unless the user explicitly requests them:

- Purple-to-blue gradient hero
- Neon AI glow
- Generic 3D robot/brain/chip imagery
- Inter/Roboto/system-ui as the lazy default
- `grid-cols-3` as the only layout pattern
- Large icon above every section heading
- Card inside card
- `transition: all 300ms ease-in-out`
- Gradient text
- Glassmorphism as decoration
- \"혁신적인\", \"최적화된\", \"미래지향적\" as empty copy
- \"Learn More\" / \"Get Started\" as generic CTA
- Diagrams that do not explain actual relationships
- Slides that are just bullet lists

## Operating Flow

Before generating output:

1. Identify artifact type.
2. Identify audience.
3. Identify decision context.
4. Identify brand or domain constraints.
5. Select a concrete aesthetic direction.
6. Define information hierarchy.
7. Draft the structure.
8. Generate output.
9. Run anti-slop audit.
10. Revise before final delivery.

## Required Self-Check

Before delivering any design, ask:

\"Would a user immediately recognize this as AI-generated?\"

If yes, identify the causes and revise them.

Check especially:

- Color cliché
- Layout cliché
- Typography cliché
- Empty copy
- Decorative components
- Weak hierarchy
- Unnecessary visual effects
- Generic SaaS structure
- Slide density problems

## Output Requirement

Every output must include:

1. The design direction used
2. The information hierarchy
3. The anti-slop decisions applied
4. The final artifact or implementation
5. Remaining risks or trade-offs
:::

## `impeccable`에서 가져오고 싶은 핵심

`impeccable`의 핵심은 “예쁘게 만들어라”가 아니라 **AI가 자주 내는 시각적 지문을 명시적으로 차단하는 것**이다. 공식 GitHub 설명도 Inter, purple-to-blue gradients, cards nested in cards, rounded-square icon tile 같은 반복 패턴을 대표적인 문제로 지적한다. 

우리 스킬은 여기서 한 단계 더 넓혀야 한다.

```text
impeccable
  └─ frontend 중심 anti-slop

anti-slop-design
  ├─ frontend anti-slop
  ├─ PPT anti-slop
  ├─ dashboard anti-slop
  ├─ copywriting anti-slop
  └─ enterprise communication guard
```

## 다음에 필요한 결정값

남은 질문은 3개만 받으면 바로 `SKILL.md` 본문까지 만들 수 있다.

1. PPT는 어떤 쪽 비중이 커?
```text
1. 정부과제 / 제안서형
2. 기술 발표 / 세미나형
3. 회사소개서형
4. 강의자료형
5. 스타트업 pitch deck형
6. HTML slide → PDF/PPT export형
```

2. 홈페이지는 어떤 용도가 제일 많아?
```text
1. AI 개발 외주 랜딩
2. 연구소 / Labs 페이지
3. SaaS 제품 랜딩
4. 강의 / 교육 판매 페이지
5. 공공기관 납품용 신뢰형 페이지
6. 개인 / 회사 포트폴리오
```

3. 최종 패키지는 어떤 형태로 만들까?
```text
1. SKILL.md 하나
2. SKILL.md + references/*.md
3. Claude Code / Codex / Hermes Agent 호환 폴더 구조 전체
4. GitHub repo 템플릿 형태
```

내 추천 기본값은 이거야.

```text
PPT: 1, 2, 3, 6
홈페이지: 1, 2, 5, 6
패키지: 3번
```

이렇게 가면 `anti-slop-design`은 단순 프롬프트가 아니라, 실제로 agent가 계속 참고할 수 있는 **개인용 디자인 품질 게이트**가 된다.