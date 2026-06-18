# slop-taxonomy

AI-slop 시각/구조 지문 카탈로그. 6개 OSS repo(impeccable 44-rule / hallmark 58-gate / frontend-design / huashu / stop-slop / frontend-slides) source-grounded 합성에서 distill. 출처 substance: repo 분석 `docs/references/anti-slop-design-oss-synthesis.md`.

각 항목은 **detector(무엇이 tell인가) + Instead(어떻게 고치나)** 쌍. **[CORE]** = 3개 이상 repo가 독립적으로 지목한 고신뢰 universal fingerprint. 모든 ban은 escape hatch 보유 — **브리프의 명시 요구가 이긴다**(브랜드가 보라색이면 보라 허용 등).

---

## 1. VISUAL fingerprints

### Color & Contrast
- **[CORE] purple/violet gradient (purple->pink->blue, "AI 팔레트")** — 모든 visual repo가 1순위로 지목. CSS hue 260-310을 heading/큰 글자에. Instead: 평면 committed accent 1색, gradient 금지.
- **[CORE] gradient text (`background-clip:text` on gradient, Tailwind `bg-clip-text` 포함)** — "장식적, 의미 전달 0". Instead: 단색 텍스트.
- **cream/beige "tasteful default" surface** — OKLCH L 0.84-0.97 / C<0.06 / hue 40-100. 토큰명 `--paper/--cream/--sand/--bone/--linen/--ivory` 자체가 tell. (모델 자신의 house-style 기본값). Instead: 브리프에서 도출한 committed surface.
- **GitHub-dark lazy preset** — 균일 `#0D1117` + generic cyan/purple neon glow. (이것만 banned — authored cinematic/warm-cyber dark은 허용). Instead: 의도된 dark 팔레트.
- **순수 `#000` / `#fff` base** — flat하게 읽힘(modern-minimal 장르는 `#fff` 예외). Instead: anchor hue로 살짝 tint.
- **zero-chroma neutral** — 순수 grey는 죽어 보임. Instead: 모든 neutral을 anchor hue 쪽으로 >=0.005 chroma tint.
- **too many colors** — Instead: <=3-4 (1 primary + 1 secondary + 1 accent + grays), 또는 **monochrome(단일 hue + grays)으로 최대 절제**. 색 가짓수 자체가 많은 것도 slop(특히 슬라이드 덱은 색 절제가 신뢰도). accent footprint가 viewport의 ~5% 초과면 tell(atmospheric 장르는 ~20% radial bloom 허용).
- gray text on colored bg, cyan-on-dark glow — washed out. Instead: 충분한 대비.

### Typography
- **[CORE] 과용 폰트를 display/body로** — Inter, Roboto, Open Sans, Lato, Montserrat, Arial, Helvetica, Poppins, system stack + AI 선호 display(Geist, Space Grotesk, Plus Jakarta Sans, Fraunces, Instrument, Mona Sans, Recoleta). brand-domain allowlist 존재(vercel.com의 Geist, github.com의 Mona Sans는 정상). Instead: characterful display + 별도 body 의도적 pairing.
- **[CORE] one-font 페이지** — 단일 family = template 페이지. Instead: display+body pairing.
- **모델 수렴 폰트 Space Grotesk** — 도구 자신이 습관적으로 집는 선택. generic뿐 아니라 "내가 디폴트로 고른 것"을 의심.
- **italic serif/display 헤더** — h1-h6/hero title/wordmark/stat에 `font-style:italic`("top AI tell"). 오버사이즈 italic serif hero(Fraunces/Playfair/Cormorant/Garamond/Canela/Ogg, generic `serif` fallback 포함). Instead: roman weight.
- **flat type hierarchy** — size step 간 ratio <1.25. Instead: >=1.25 (slide는 title >=2.5x body, 이상 3x).
- **oversized H1** — display 크기의 풀문장 headline. clamp() max <=6rem(~96px). 짧은 1-2단어 headline은 그 크기 OK.
- **>3 font families** — "2+1 rule": `--font-display` + `--font-body` + outlier 최대 1(비코드 맥락에선 mono도 family로 카운트).
- **extreme negative tracking** — body letter-spacing <=-0.05em(글자 붙음), display floor >=-0.04em. body wide-tracking >0.05em도 tell.
- **all-caps display, line-height <1.0** — wrap 시 cap-top 충돌. floor 1.0(권장 1.02-1.08). all-caps body는 word-shape 인식 상실로 ban.
- tiny text(body <12px = 확실한 tell; 권장 floor는 14px — §4 numeric floor 참조), tight leading(line-height <1.3x).

### Visual Details (component cliches)
- **[CORE] side-stripe / left-border-accent card** — 가장 많이 지목된 컴포넌트 tell("AI UI의 가장 식별 가능한 지문"). 시그니처: `border-radius:12px; border-left:4px solid #3b82f6`(border >=3px 또는 rounded 요소의 모든 border-width). Instead: bg/weight 대비로 구분, stripe 제거.
- **[CORE] icon-tile-above-heading feature card** — 작은 rounded-square icon 컨테이너를 heading 위에 쌓는 "universal AI feature-card template". Instead: 카드별 크기·내용 변주.
- **[CORE] nested card (card-in-card)** — semantic 이유 없음. Instead: 평면화.
- **[CORE] emoji as icon** — sparkle/rocket/lightning/fire/target/check를 feature/step/pricing 아이콘으로. (브랜드가 쓰거나 청중이 어린이면 예외). Instead: 하나의 real icon set.
- icon library 혼용(Material+Heroicons+Lucide). Instead: 1개 set.
- **glassmorphism as default / 목적 없는 drop shadow** — absolute ban. Instead: shadow는 elevation 의미가 있을 때만.
- **hero-metric template** — "큰 숫자 + 작은 라벨 + 보조 stat + gradient accent"는 the template answer. 거대한 맨숫자를 hero headline으로. Instead: 실제 narrative.
- bounce/elastic/overshoot easing(`cubic-bezier(0.34,1.56,...)`). Instead: ease-out-quart/quint/expo.

### Imagery & Decoration
- **[CORE] 손그림 figurative SVG (사람/장면/제품)** — huashu 최우선 ban. AI가 그린 SVG 인물은 이목구비 어긋남, CSS 실루엣 제품은 "generic tech animation"(모든 제품이 똑같아 brand 인식 0). **허용 SVG: true icon(16-32px), geometric decoration, data-viz/diagram만.** Instead: "회색 사각형 + '1200x800 illustration slot' 라벨이 나쁜 SVG hero보다 100배 낫다."
- **decorative imagery on text content** — honesty test: 이미지를 빼도 정보가 안 줄면 slop(에세이 목록의 배너, 프로필의 풍경 헤더). purple gradient와 동급.
- **재그린 UI chrome** — 가짜 browser bar(traffic-light dots), phone notch, terminal/IDE chrome, self-drawn iOS Dynamic Island. "self-writing은 99% position bug." Instead: 실제 screenshot을 `<figure>`에.
- aurora-blob / floating-orb / mesh background(>1 accent, >~5% footprint, 또는 페이지 전체 animating mesh). 덱에선 "abstract shape만, illustration 금지".
- decorative SVG/canvas에 `aria-label`/`aria-hidden` 없음("the new accessibility tell").

### Motion
- **[CORE] over-animation / 흩뿌린 micro-interaction** — "추가 애니메이션은 AI 생성 느낌을 키운다". Instead: 하나의 orchestrated moment(예: 1회 staggered page-load), 1-2개 persisting hero 요소로 연속 narrative.
- `transition-all` / 균일 `hover:scale-105` / 한 요소에 동시 hover 효과 >1.
- layout prop(width/height/top/left/margin/padding) 애니메이션. Instead: transform/opacity만.
- `prefers-reduced-motion` fallback 없음(필수).
- auto-rotating carousel에 pause-on-hover/focus 없음(WCAG 2.2.2).

---

## 2. STRUCTURAL patterns

위계·밀도·장식·"선택 아닌 기본값" 구조.

- **[CORE] generic AI macrostructure: Hero -> 3 features -> testimonials -> CTA -> footer** — 주제와 무관하게 나오는 골격. Instead: 브리프 특정 구조(섹션마다 존재 이유).
- **[CORE] 3-equal-column card grid (icon-above-heading, ~24px gap)** — Instead: 비대칭/크기 변주, 일부 image·일부 text, 일부 column-span.
- **[CORE] everything-centered / full-viewport centered hero** — `min-height:100vh` 전부 centered = auto-fail. Instead: centered 요소 <=2, 비대칭 도입.
- **[CORE] 장식용 numbered marker (01/02/03)** — 실제 sequence(순서 정보)일 때만 허용. 장식 numbering은 slop.
- **[CORE] 모든 섹션 위 tiny uppercase tracked eyebrow chip** — "AI editorial scaffolding". eyebrow를 heading과 같은 줄에 두면 auto-fail(단일 column 수직 stack이어야). 구조 장치는 내용의 진실을 encode해야지 장식이면 안 됨.
- **[CORE] 지어낸 metric / quote-slop / data-slop** — invented "10x faster", "trusted by 50,000+ teams", "99.9% uptime", 가짜 testimonial, placeholder명(Jane Doe/John Smith/Acme/Nexus). Instead: 실제 수치, 라벨된 placeholder, 또는 사용자에게 질문.
- **AI nav 지문** — wordmark-left + 4-5 inline link + button-right + full-width + 1px hairline border-bottom + white bg.
- **AI footer 지문** — 4 column(Product/Company/Resources/Legal) + social icon row + tiny copyright + 1px top-border + grey bg.
- **monotonous spacing** — 어디나 같은 spacing 값, 섹션 간 rule/ornament/색 전환 없음, 4px 배수 scale 벗어난 arbitrary padding(`17px`). Instead: rhythm 있는 spacing scale.
- **bento-grid 남용**, **decoration > content**(heading마다 장식 icon). 단 **density 자체는 slop이 아니다** — 차별적 product signal(data/reasoning/status)을 담은 밀도는 유지, 장식만 제거.
- **default-attractor sameness** — 직전 build와 같은 macrostructure 지문, variation knob 안 바꾸고 archetype 재사용. **이것이 root thesis**: slop = 브리프와 독립적으로 내린 선택.
- horizontal scroll(320-1920px 어디서든). Instead: `overflow-x:clip`, image grid track은 `minmax(0,1fr)`.

---

## 3. Lane별 quick rules

### Web / SaaS landing (가장 깊게 커버됨)
위 VISUAL/STRUCTURAL ban 전부 적용 + §4 numeric floor. hero는 eyebrow+headline+lede+CTA가 1280x800에서 스크롤 없이, `padding-block-end >= 1.3x padding-block-start`. AI nav/footer 지문·aurora-blob·재그린 chrome 금지. 모든 장식 image에 honesty test.

### PPT / 덱
- web font/color/gradient/decoration ban 전부 적용.
- **fixed-stage discipline**: 고정 1920x1080 canvas를 uniform scale, 모든 화면에서 16:9 유지(letterbox/pillarbox, reflow 금지). 슬라이드 전환은 `.active`/`.visible`(visibility/opacity/pointer-events), `display:none/block` 금지.
- **density 모드**: speaker-led = 1 idea + 1-3 bullet, 큰 타입 / reading-first = 4-8 bullet 또는 4-6 card. **"split, don't shrink"** — 넘치면 새 슬라이드, 줄이지 말 것.
- slide 본문 >=24px(이상 28-36), title-to-body >=2.5x, contrast >=4.5:1.
- **scaffolding 노출 절대 금지**(NON-NEGOTIABLE): 화면에 "preview"/"template"/"Option A/B/C"/파일경로/요구사항 노트/style-preset 이름 렌더 금지. 납품 전 보이는 텍스트 점검. real 덱 chrome(title/section/date/author/page number)만.
- page number는 덱 셸이 소유 — 단일 페이지에 self-draw 금지(이중 번호 `02/03` + `6/16` 유발).
- 하나의 연속 motion narrative("voiced PowerPoint" 장면별 fade-up 금지). 같은 image를 슬라이드마다 반복 금지(title/closing의 logo 제외).
- **색 절제(슬라이드 특히)**: <=3 committed hue 또는 monochrome. 긍정/부정 델타는 hue 추가 없이 색+방향기호(↑/↓)로 인코딩. tint는 1종 zone-fill로 제한.
- **생성 일관성 방법론**(빌드 실행은 ppt-master, 일관성은 anti-slop 소관): 다수 슬라이드를 per-slide agent로 병렬 생성할 때 literal chrome snippet 묶음(BUILDKIT) + gold reference 1-2장(앵커 슬라이드)을 공유해 동일 chrome을 복제하게 한다. chrome 고정·콘텐츠만 변주(색만 바꾼 변주는 variety 불인정과 같은 맥락).
- **납품 전 검증 함정**(slop은 렌더에서 드러난다): (1) 레이아웃 진실은 PowerPoint/cairosvg 기준 — LibreOffice는 spAutoFit 미리보기 한계로 overflow를 숨긴다. (2) SVG는 빌드 전 XML well-formed 일괄 검사(HTML named entity `&nbsp;`·font-family 따옴표 짝 실수가 흔함). (3) 산출 pptx의 텍스트/수치 검증은 group shape **재귀** 필요(`<g>` -> PPTX group; 얕은 walk는 false-negative).

### Dashboard / Admin UI -- 증거 GAP (정직 표기)
**6개 repo 어디도 대시보드 전용 ruleset이 없다.** 모두 landing/덱/prose lane. 따라서 이 lane은 가장 얇은 근거이며, 전용 소스 확보 시 보강 대상. 현재는 transfer되는 규칙으로 운영:
- impeccable의 component/contrast/density 규칙이 data-dense UI에 그대로 적용: WCAG 대비(4.5:1 / 3:1), gray-on-color, monotonous-spacing, nested-card, cramped-padding(폰트 크기에 비례한 임계), **clipped-overflow-container**(`overflow:hidden`이 tooltip/menu/popover를 자르는 흔한 대시보드 버그), text-overflow/horizontal-scroll, tight-leading, side-tab border, design-system drift.
- hallmark form-state 게이트(transfer): 상태 간 border-width 변동, focus-ring을 outline 아닌 border로, input 높이 != 인접 button 높이(44px floor), 빈 helper-text slot 붕괴(`min-height:1lh` 예약), disabled를 opacity만으로 신호.
- **huashu density 역전(핵심 가드레일)**: 대시보드의 본분은 dense data — anti-slop이 정보 밀도를 평탄화하면 안 된다. **"여백 늘리기" 반사 금지.** 장식만 제거, product signal 밀도는 유지.

---

## 4. Numeric floor sweep (자동검증 가능)

| 항목 | floor |
|---|---|
| contrast | 본문 >=4.5:1, large(>=24px 또는 >=18.67px bold) >=3:1 |
| 본문 폰트 | >=14px (mobile 16px, slide 본문 >=24px) |
| type-scale ratio | >=1.25 (slide title >=2.5x body) |
| line-length | <=80ch (이상 65-75ch) |
| line-height | 본문 >=1.3 |
| 색 수 | <=3-4 (1 primary + 1 secondary + 1 accent + grays) |
| touch target | 44x44px |
| accent footprint | viewport의 ~5% 이하 (atmospheric 장르 예외 ~20%) |
| honesty test | 모든 장식 image — 빼도 정보 안 줄면 제거 |
