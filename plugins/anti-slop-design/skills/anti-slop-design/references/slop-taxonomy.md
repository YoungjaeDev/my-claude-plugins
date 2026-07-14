# slop-taxonomy

A catalog of AI-slop visual/structural fingerprints. Distilled from a source-grounded synthesis of 6 OSS repos (impeccable 44-rule / hallmark 58-gate / frontend-design / huashu / stop-slop / frontend-slides). Source substance: the repo analysis in `docs/references/anti-slop-design-oss-synthesis.md`.

Each item is a **detector (what is the tell) + Instead (how to fix)** pair. **[CORE]** = a high-confidence universal fingerprint pointed at independently by 3 or more repos. Every ban has an escape hatch — **an explicit requirement in the brief wins** (if the brand is purple, purple is allowed, etc.).

---

## 1. VISUAL fingerprints

### Color & Contrast
- **[CORE] purple/violet gradient (purple->pink->blue, the "AI palette")** — pointed at first by every visual repo. CSS hue 260-310 on headings/large text. Instead: a single flat committed accent color, no gradient.
- **[CORE] gradient text (`background-clip:text` on a gradient, including Tailwind `bg-clip-text`)** — "decorative, zero meaning conveyed". Instead: solid-color text.
- **cream/beige "tasteful default" surface** — OKLCH L 0.84-0.97 / C<0.06 / hue 40-100. The token name `--paper/--cream/--sand/--bone/--linen/--ivory` is itself the tell (the model's own house-style default). Instead: a committed surface derived from the brief.
- **GitHub-dark lazy preset** — uniform `#0D1117` + a generic cyan/purple neon glow. (Only this is banned — an authored cinematic/warm-cyber dark is allowed.) Instead: an intentional dark palette.
- **pure `#000` / `#fff` base** — reads as flat (the modern-minimal genre is a `#fff` exception). Instead: a slight tint toward an anchor hue.
- **zero-chroma neutral** — pure grey looks dead. Instead: tint every neutral toward the anchor hue by >=0.005 chroma.
- **too many colors** — Instead: <=3-4 (1 primary + 1 secondary + 1 accent + grays), or **maximum restraint with monochrome (a single hue + grays)**. A high color count is itself slop (color restraint is credibility, especially for slide decks). An accent footprint over ~5% of the viewport is a tell (the atmospheric genre allows ~20% radial bloom).
- gray text on a colored bg, cyan-on-dark glow — washed out. Instead: sufficient contrast.

### Typography
- **[CORE] an overused font as display/body** — Inter, Roboto, Open Sans, Lato, Montserrat, Arial, Helvetica, Poppins, the system stack + AI-favored display faces (Geist, Space Grotesk, Plus Jakarta Sans, Fraunces, Instrument, Mona Sans, Recoleta). A brand-domain allowlist exists (Geist on vercel.com, Mona Sans on github.com are fine). Instead: a characterful display + a separate body in a deliberate pairing.
- **[CORE] one-font page** — a single family = a template page. Instead: a display+body pairing.
- **the model-convergent font Space Grotesk** — the choice the tool habitually reaches for. Suspect not only the generic but "the one I picked as a default".
- **italic serif/display headers** — `font-style:italic` on h1-h6/hero title/wordmark/stat (the "top AI tell"). An oversized italic serif hero (Fraunces/Playfair/Cormorant/Garamond/Canela/Ogg, including the generic `serif` fallback). Instead: roman weight.
- **flat type hierarchy** — ratio <1.25 between size steps. Instead: >=1.25 (slides: title >=2.5x body, ideally 3x).
- **oversized H1** — a full-sentence headline at display size. clamp() max <=6rem (~96px). A short 1-2 word headline is OK at that size.
- **>3 font families** — the "2+1 rule": `--font-display` + `--font-body` + at most 1 outlier (in non-code contexts, mono counts as a family too).
- **extreme negative tracking** — body letter-spacing <=-0.05em (letters touching), display floor >=-0.04em. body wide-tracking >0.05em is also a tell.
- **all-caps display, line-height <1.0** — cap-top collision on wrap. floor 1.0 (recommended 1.02-1.08). all-caps body is banned for loss of word-shape recognition.
- tiny text (body <12px = a sure tell; recommended floor is 14px — see §4 numeric floor), tight leading (line-height <1.3x).

### Visual Details (component cliches)
- **[CORE] side-stripe / left-border-accent card** — the most-pointed-at component tell ("the most identifiable fingerprint of AI UI"). Signature: `border-radius:12px; border-left:4px solid #3b82f6` (a border >=3px, or any border-width on a rounded element). Instead: distinguish by bg/weight contrast, remove the stripe.
- **[CORE] icon-tile-above-heading feature card** — stacking a small rounded-square icon container above the heading, the "universal AI feature-card template". Instead: vary size·content per card.
- **[CORE] nested card (card-in-card)** — no semantic reason. Instead: flatten.
- **[CORE] emoji as icons** — sparkle/rocket/lightning/fire/target/check as feature/step/pricing icons. (Exception if the brand uses them or the audience is children.) Instead: one real icon set.
- mixed icon libraries (Material+Heroicons+Lucide). Instead: 1 set.
- **glassmorphism as default / purposeless drop shadow** — an absolute ban. Instead: shadow only when elevation has meaning.
- **hero-metric template** — "a big number + a small label + a supporting stat + a gradient accent" is the template answer. A huge bare number as a hero headline. Instead: a real narrative.
- bounce/elastic/overshoot easing (`cubic-bezier(0.34,1.56,...)`). Instead: ease-out-quart/quint/expo.

### Imagery & Decoration
- **[CORE] hand-drawn figurative SVG (people/scenes/products)** — huashu's top ban. AI-drawn SVG people have misaligned features; a CSS-silhouette product is a "generic tech animation" (every product looks the same, zero brand recognition). **Allowed SVG: true icons (16-32px), geometric decoration, data-viz/diagram only.** Instead: "a gray rectangle + a '1200x800 illustration slot' label is 100x better than a bad SVG hero."
- **decorative imagery on text content** — the honesty test: if removing the image loses no information, it is slop (a banner on an essay list, a landscape header on a profile). On par with a purple gradient.
- **redrawn UI chrome** — a fake browser bar (traffic-light dots), a phone notch, terminal/IDE chrome, a self-drawn iOS Dynamic Island. "Self-writing is 99% a position bug." Instead: a real screenshot in a `<figure>`.
- aurora-blob / floating-orb / mesh background (>1 accent, >~5% footprint, or a full-page animating mesh). In decks, "abstract shapes only, no illustration".
- decorative SVG/canvas with no `aria-label`/`aria-hidden` ("the new accessibility tell").

### Motion
- **[CORE] over-animation / scattered micro-interactions** — "extra animation amplifies the AI-generated feel". Instead: one orchestrated moment (e.g. a single staggered page-load), a continuous narrative with 1-2 persisting hero elements.
- `transition-all` / uniform `hover:scale-105` / more than 1 simultaneous hover effect on an element.
- animating layout props (width/height/top/left/margin/padding). Instead: transform/opacity only.
- no `prefers-reduced-motion` fallback (required).
- an auto-rotating carousel with no pause-on-hover/focus (WCAG 2.2.2).

---

## 2. STRUCTURAL patterns

Structures of hierarchy·density·decoration·"the default that is not a choice".

- **[CORE] generic AI macrostructure: Hero -> 3 features -> testimonials -> CTA -> footer** — a skeleton that shows up regardless of topic. Instead: a brief-specific structure (each section has a reason to exist).
- **[CORE] 3-equal-column card grid (icon-above-heading, ~24px gap)** — Instead: asymmetric/size variation, some image·some text, some column-span.
- **[CORE] everything-centered / full-viewport centered hero** — `min-height:100vh` all centered = auto-fail. Instead: centered elements <=2, introduce asymmetry.
- **[CORE] decorative numbered markers (01/02/03)** — allowed only when it is a real sequence (ordering information). Decorative numbering is slop.
- **[CORE] a tiny uppercase tracked eyebrow chip above every section** — "AI editorial scaffolding". Placing the eyebrow on the same line as the heading is an auto-fail (it must be a single vertical column stack). A structural device must encode the truth of the content, not be decoration.
- **[CORE] invented metrics / quote-slop / data-slop** — invented "10x faster", "trusted by 50,000+ teams", "99.9% uptime", fake testimonials, placeholder names (Jane Doe/John Smith/Acme/Nexus). Instead: real numbers, labeled placeholders, or a question to the user.
- **AI nav fingerprint** — wordmark-left + 4-5 inline links + button-right + full-width + a 1px hairline border-bottom + white bg.
- **AI footer fingerprint** — 4 columns (Product/Company/Resources/Legal) + a social icon row + tiny copyright + a 1px top-border + grey bg.
- **monotonous spacing** — the same spacing value everywhere, no rule/ornament/color transition between sections, arbitrary padding off the 4px-multiple scale (`17px`). Instead: a spacing scale with rhythm.
- **bento-grid overuse**, **decoration > content** (a decorative icon on every heading). But **density itself is not slop** — keep density that carries a differentiating product signal (data/reasoning/status), remove only the decoration.
- **default-attractor sameness** — the same macrostructure fingerprint as the last build, reusing the archetype without changing the variation knob. **This is the root thesis**: slop = a choice made independently of the brief.
- horizontal scroll (anywhere from 320-1920px). Instead: `overflow-x:clip`, use `minmax(0,1fr)` for image grid tracks.

---

## 3. Per-lane quick rules

### Web / SaaS landing (covered most deeply)
Apply all the VISUAL/STRUCTURAL bans above + the §4 numeric floor. The hero has eyebrow+headline+lede+CTA with no scroll at 1280x800, `padding-block-end >= 1.3x padding-block-start`. No AI nav/footer fingerprint·aurora-blob·redrawn chrome. Apply the honesty test to every decorative image.

### PPT / decks
- Apply all web font/color/gradient/decoration bans.
- **fixed-stage discipline**: a fixed 1920x1080 canvas uniformly scaled, keeping 16:9 on every screen (letterbox/pillarbox, no reflow). Slide transitions use `.active`/`.visible` (visibility/opacity/pointer-events), no `display:none/block`.
- **density modes**: speaker-led = 1 idea + 1-3 bullets, large type / reading-first = 4-8 bullets or 4-6 cards. **"split, don't shrink"** — on overflow, add a new slide, do not shrink.
- slide body >=24px (ideally 28-36), title-to-body >=2.5x, contrast >=4.5:1.
- **never expose scaffolding** (NON-NEGOTIABLE): do not render "preview"/"template"/"Option A/B/C"/file paths/requirement notes/style-preset names on screen. Check visible text before delivery. Only real deck chrome (title/section/date/author/page number).
- the page number is owned by the deck shell — no self-drawing on a single page (which causes double numbering `02/03` + `6/16`).
- one continuous motion narrative (no per-scene fade-up "voiced PowerPoint"). Do not repeat the same image on every slide (except the logo on title/closing).
- **color restraint (especially slides)**: <=3 committed hues or monochrome. Encode a positive/negative delta with color + a direction symbol (↑/↓) rather than adding a hue. Limit tint to a single zone-fill.
- **generation-consistency methodology** (build execution is ppt-master; consistency is anti-slop's domain): when generating many slides in parallel via per-slide agents, share a literal chrome-snippet bundle (BUILDKIT) + 1-2 gold reference slides (anchor slides) so the same chrome is replicated. Fix the chrome·vary only the content (a variation that changes only the color does not count as variety, in the same spirit).
- **pre-delivery verification pitfalls** (slop reveals itself in the render): (1) layout truth is PowerPoint/cairosvg, not LibreOffice — LibreOffice hides overflow with its spAutoFit-preview limitation. (2) run a batch XML well-formed check on the SVG before build (an HTML named entity `&nbsp;`·a mismatched font-family quote is common). (3) verifying text/numbers in the output pptx needs **recursion** through group shapes (`<g>` -> PPTX group; a shallow walk is a false-negative).

### Dashboard / Admin UI -- evidence GAP (stated honestly)
**None of the 6 repos has a dashboard-specific ruleset.** All are landing/deck/prose lanes. So this lane has the thinnest basis and is a reinforcement target once dedicated sources are secured. For now it runs on transferred rules:
- impeccable's component/contrast/density rules apply directly to a data-dense UI: WCAG contrast (4.5:1 / 3:1), gray-on-color, monotonous-spacing, nested-card, cramped-padding (a threshold proportional to font size), **clipped-overflow-container** (the common dashboard bug where `overflow:hidden` clips a tooltip/menu/popover), text-overflow/horizontal-scroll, tight-leading, side-tab border, design-system drift.
- hallmark form-state gates (transferred): border-width shifts between states, a focus-ring as a border instead of an outline, input height != adjacent button height (44px floor), collapse of an empty helper-text slot (reserve with `min-height:1lh`), signaling disabled by opacity alone.
- **huashu density inversion (the key guardrail)**: a dashboard's job is dense data — anti-slop must not flatten information density. **No "increase whitespace" reflex.** Remove only decoration, keep the product-signal density.

---

## 4. Numeric floor sweep (auto-verifiable)

| Item | floor |
|---|---|
| contrast | body >=4.5:1, large (>=24px or >=18.67px bold) >=3:1 |
| body font | >=14px (mobile 16px, slide body >=24px) |
| type-scale ratio | >=1.25 (slide title >=2.5x body) |
| line-length | <=80ch (ideally 65-75ch) |
| line-height | body >=1.3 |
| color count | <=3-4 (1 primary + 1 secondary + 1 accent + grays) |
| touch target | 44x44px |
| accent footprint | <=~5% of viewport (atmospheric genre exception ~20%) |
| honesty test | every decorative image — remove it if information does not decrease |
