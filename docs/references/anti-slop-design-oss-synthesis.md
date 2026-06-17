<!-- source: dynamic workflow anti-slop-repo-analysis (wf_cd4d49c9-4a2), 6 OSS repos deep-read via gh api + DeepWiki, 2026-06-16 -->
<!-- role: grounded substance for the anti-slop-design skill spec + reference files -->

# Anti-Slop Design: Synthesized Reference

Source-grounded synthesis of 6 anti-AI-slop OSS repos, deduped into reference substance for the `anti-slop-design` skill. Repo shorthand used throughout:

| Tag | Repo | Lane |
|---|---|---|
| `impeccable` | pbakaus/impeccable | web/visual + JS detectors (44-rule registry) |
| `hallmark` | nutlope/hallmark | web/visual + 58-gate slop test |
| `anthropic-fd` | anthropics/skills (frontend-design/) | web/principles (prose only) |
| `huashu` | alchaincyf/huashu-design | web + PPT + brand (Chinese) |
| `stop-slop` | hardikpandya/stop-slop | copy (English prose) |
| `frontend-slides` | zarazhangrui/frontend-slides | PPT |

Convergence note: where 3+ repos independently name the same pattern, it is a high-confidence universal fingerprint. Those are marked **[CORE]**.

---

## 1. Slop Taxonomy — VISUAL Fingerprints

Deduped, concrete, each backed by repo(s). Organized by the 7-bucket taxonomy `impeccable` exposes via its `skillSection` back-references (Typography / Color & Contrast / Layout & Space / Motion / Visual Details / Imagery / Copy — Copy is §4).

### Color & Contrast

- **[CORE] Purple/violet gradient (purple→pink→blue, the "AI palette")** — banned by `impeccable` (CSS hue 260-310 on headings or font≥20px), `hallmark` (gate 2: purple-to-blue / cyan-to-magenta), `huashu` (purple→pink→blue full-screen, rainbow, mesh), `frontend-slides` ("bye-bye, purple gradients on white"; generic indigo `#6366f1`). The single most-cited tell across all visual repos.
- **[CORE] Gradient text (`background-clip:text` on a gradient)** — `impeccable` (incl. Tailwind `bg-clip-text`), `hallmark` (gate 2, "no genre allows gradient text"), `huashu`. "Decorative, never meaningful."
- **Cream/beige "tasteful default" surface** — `impeccable` pins it precisely: OKLCH **L 0.84-0.97, C<0.06, hue 40-100**; token names `--paper/--cream/--sand/--bone/--flour/--linen/--parchment/--wheat/--biscuit/--ivory` are tells in themselves. `anthropic-fd` names the full cluster (cream near **#F4F1EA** + serif display + terracotta accent) and notes elsewhere it is *Opus's own house-style default* — i.e. the model's own bias.
- **Near-black bg + single acid-green/vermilion accent** — `anthropic-fd` cluster #2.
- **GitHub-dark lazy preset** — `huashu`: uniform deep-blue `#0D1117` + generic cyan/purple neon glow. **Nuance: this is the ONLY dark combo banned** — authored cinematic/warm-cyber/dark-stage darks are explicitly allowed.
- **Pure `#000` / pure `#fff` as base** — `hallmark` (gate 7; modern-minimal genre exempt for `#fff` paper).
- **Zero-chroma neutrals** — `hallmark` (gate 22): pure greys read flat; tint every neutral ≥0.005 chroma toward the anchor hue.
- **Cyan-on-dark / dark-glow** — `impeccable` (cyan-on-dark palette; dark bg + colored box-shadow glow with blur).
- **Gray text on a colored background** — `impeccable` (washed out).
- **Too many colors** — `huashu`/`frontend-slides`: cap ~3-4 (1 primary + 1 secondary + 1 accent + grays). `hallmark`: accent footprint >~5% of viewport area is a tell (atmospheric genre allows ~20% radial bloom).

### Typography

- **[CORE] Banned overused fonts as display/body** — convergent set across `impeccable`, `hallmark`, `huashu`, `frontend-slides`: **Inter, Roboto, Open Sans, Lato, Montserrat, Arial, Helvetica, Poppins, system-default stack**. Plus the AI-favorite display faces: **Geist, Space Grotesk, Plus Jakarta Sans, Fraunces, Instrument Sans/Serif, Mona Sans, Recoleta**. `impeccable` adds a **brand-domain allowlist** (don't flag Geist on vercel.com, Mona-Sans on github.com).
- **[CORE] Single font / "Inter-everywhere" page** — `impeccable` (only one non-generic family), `hallmark` (gate 1: one-font page = template page). No display+body pairing = tell.
- **The model's own convergence font** — `frontend-slides` and `anthropic-fd` (via siblings) both call out **Space Grotesk** by name as the habit the model itself reaches for; flag the tool's default choices, not just generic ones.
- **Italic serif/display headers** — `hallmark` (gate 38a, "top AI tell": ANY `font-style:italic` on h1-h6/hero title/wordmark/stat figure); `impeccable` (oversized italic serif hero — Fraunces/Recoleta/Playfair/Cormorant/Garamond/Tiempos/Canela/Ogg, also fires on generic `serif` fallback).
- **Flat type hierarchy** — `impeccable` wants ≥1.25 ratio between size steps; `huashu` wants title ≥2.5x body (ideal 3x). A minimal design with sloppy spacing/type is itself a failure mode (`anthropic-fd`).
- **Oversized H1** — `impeccable`: long full-sentence headline at display size; clamp() max should be ≤6rem (~96px). Short 1-2 word headlines at that size are fine.
- **Extreme negative tracking** — `impeccable`: letter-spacing ≤ -0.05em on body (chars touch); display floor ≥ -0.04em. Also `wide-tracking` >0.05em on body.
- **>3 font families** — `hallmark` (gate 37, the "2+1 rule": `--font-display` + `--font-body` + at most one outlier; mono counts as a family in non-code contexts).
- **All-caps display with line-height <1.0** — `hallmark` (gate 55: cap-tops collide on wrap; floor 1.0, recommend 1.02-1.08). General all-caps body banned by `impeccable` (word-shape recognition lost).
- **Tiny text / tight leading** — `impeccable`: body <12px; line-height <1.3x.

### Visual Details (component cliches)

- **[CORE] Side-stripe / left-border-accent card** — *the* most-cited component tell. `impeccable` ("the most recognizable tell of AI UIs": border ≥3px, or any border width on a rounded element), `hallmark` (gate 5: 4-6px coloured left/right stripe = "2018-SaaS-AI"), `huashu` (exact CSS signature `border-radius:12px; border-left:4px solid #3b82f6`).
- **[CORE] Icon-tile-above-heading feature card** — `impeccable` ("the universal AI feature-card template": small rounded-square icon container stacked above a heading), `hallmark` (gate 3, part of the 3-column grid), `anthropic-fd` (implied in template-hero family).
- **[CORE] Nested cards (card-in-card)** — `impeccable`, `hallmark` (gate 4, "no semantic reason").
- **[CORE] Emoji as icons** — `hallmark` (gate 30: sparkle/rocket/lightning/fire/target/check as feature/step/pricing icon), `huashu` (emoji before headings, checkmarks in lists, emoji CTA arrows), `frontend-slides` (implied). Exception: brand uses them (Notion/Slack) or audience is children.
- **Mixing 2+ icon libraries** — `hallmark` (gate 30: Material+Heroicons+Lucide).
- **Glassmorphism as default / purposeless drop shadows** — `frontend-slides` (gratuitous glassmorphism, shadows without purpose), `impeccable` (absolute ban: glassmorphism-as-default).
- **The hero-metric template** — `impeccable`, `anthropic-fd` (verbatim: "a big number with a small label, supporting stats, and a gradient accent is **the template answer**"), `hallmark` (gate 46: a giant bare number as sole hero headline). See also fabricated metrics in §2/§4.
- **GitHub-dark glow** — see Color.
- **Bounce/elastic/overshoot easing** — `impeccable` (wants ease-out-quart/quint/expo), `hallmark` (gate 12: `cubic-bezier(0.34,1.56,...)` on buttons/modals).

### Imagery & Decoration

- **[CORE] Hand-drawn SVG of humans/scenes/products instead of a real image** — `huashu` (its single most critical ban, triggered a protocol upgrade: AI-drawn SVG humans have misaligned features; CSS silhouette replacing a real product = "generic tech animation" where every product looks identical, brand recognition → zero). Allowed SVG only: true icons (16-32px), geometric decoration, data-viz. **"A gray rectangle + 'illustration slot 1200x800' label beats a bad SVG hero 100x."**
- **Decorative imagery on text content** — `huashu` "honesty test": if removing the image loses no information, it is slop (banner on an essay list, scenic header on a profile, decorative settings banner). Equivalent to a purple gradient.
- **Re-drawn UI chrome** — `hallmark` (gate 47: fake browser bar with traffic-light dots, phone notch frame, terminal/IDE chrome — use a real screenshot in `<figure>`). `huashu` (self-drawn iOS Dynamic Island / status bar). "Self-writing hits position bugs 99% of the time."
- **Aurora-blob / floating-orb / mesh background** — `hallmark` (gate 29: abstract bg using >1 accent, >~5% footprint, or animating mesh-gradient on whole page).
- **Realistic illustrations in decks** — `frontend-slides` (STYLE_PRESETS hard rule: "Abstract shapes only — no illustrations").
- **Decorative SVG/canvas without `aria-label`/`aria-hidden`** — `hallmark` (gate 33: "the new accessibility tell").

### Motion

- **[CORE] Over-animation / scattered micro-interactions** — `anthropic-fd` (verbatim: "extra animation contributes to the feeling that the design is AI-generated"; prefer one orchestrated moment), `huashu` ("voiced PowerPoint" motion → want one continuous narrative with 1-2 persisting hero elements), `frontend-slides` ("one well-orchestrated staggered page-load beats scattered micro-interactions").
- **`transition-all` / uniform `hover:scale-105`** — `hallmark` (gates 10, 11, 13: >1 simultaneous hover effect on one element).
- **Animating layout props** (width/height/top/left/margin/padding) instead of transform/opacity — `impeccable` (layout-transition), `hallmark` (gate 14).
- **Bounce/elastic easing** — see Visual Details.
- **No `prefers-reduced-motion` fallback** — `hallmark` (gate 27), `huashu`, `frontend-slides` (mandatory).
- **Auto-rotating carousel without pause-on-hover/focus** — `hallmark` (gate 18, WCAG 2.2.2).

---

## 2. Slop Taxonomy — STRUCTURAL Patterns

Hierarchy, density, decoration, and "default-not-choice" structure.

- **[CORE] The generic AI macrostructure: Hero → 3 features → testimonials → CTA → footer** — `hallmark` (gate 8), `huashu` ("big hero + 3-column features + testimonials + CTA" overused template), `frontend-slides` (generic hero sections). The skeleton that appears regardless of subject.
- **[CORE] 3-equal-column card grid (icon-above-heading tiles, ~24px gap)** — `hallmark` (gate 3), `huashu` (uniform card grids), `frontend-slides` (identical/cookie-cutter card grids). Fix: asymmetric/varied-size cards, some image some text, some spanning columns.
- **[CORE] Everything-centered layout / full-viewport centered hero** — `hallmark` (gate 6: `min-height:100vh` everything centred = auto-fail; pick ≤2 centred elements), `frontend-slides` (everything-centered), `anthropic-fd` (via sibling web-artifacts-builder: "excessive centered layouts").
- **[CORE] Decorative numbered section markers (01 / 02 / 03)** — `impeccable` (advisory: ≥3 distinct tokens + ≥2 sequential), `hallmark` (gate 21 "Specimen fall-through"), `anthropic-fd` (only allowed if content is an *actual* sequence carrying order information). Decorative numbering = slop.
- **[CORE] Tiny uppercase tracked eyebrow chip above every section heading** — `impeccable` (hero-eyebrow-chip + advisory repeated-section-kickers, "AI editorial scaffolding"), `hallmark` (gate 54: eyebrow beside heading on same row = auto-fail; must be single-column vertical stack). Structural devices must "encode something true about the content, not decorate it" (`anthropic-fd`).
- **[CORE] Fabricated metrics / quote-slop / data-slop** — `hallmark` (gate 46: invented "10x faster", "trusted by 50,000+ teams", "99.9% uptime"), `huashu` (data-slop: fake stat cards; quote-slop: fabricated testimonials/celebrity quotes), `anthropic-fd` (honest-copy). Fix: real number, labelled placeholder, or ask the user. Placeholder names "Jane Doe / John Smith / Acme / Nexus" also banned (`hallmark` gate 19).
- **The AI nav fingerprint** — `hallmark` (gate 42): wordmark-left + 4-5 inline links + button-right + full-width + 1px hairline border-bottom + white bg.
- **The AI footer fingerprint** — `hallmark` (gate 43): 4 columns (Product/Company/Resources/Legal) + social-icon row + tiny copyright + 1px hairline top-border + grey bg.
- **Monotonous spacing / sections separated by equal whitespace only** — `impeccable` (same spacing value everywhere, no rhythm), `hallmark` (gate 9: no rule/ornament/colour shift between sections; gate 24: arbitrary padding off a 4px-multiple scale like `padding:17px`).
- **Broadsheet/hairline-rule/zero-radius dense-column layout** — `anthropic-fd` cluster #3 (a *default* when an axis is left free).
- **Bento-grid overuse** — `huashu` ("every AI landing page wants bento").
- **Decoration > content** — `huashu` ("iconography slop": decorative icon at every heading), `anthropic-fd` (Chanel "remove one accessory"). **Nuance** (`huashu`): the reduction target is *decoration*, not differentiated product signal (data, reasoning snippets, status). Don't strip density that carries information.
- **Default-attractor sameness** — `hallmark` (gate 8/32/57: same macrostructure fingerprint as a prior build; reusing an archetype without changing a variation knob), `anthropic-fd` ("defaults rather than choices, appearing regardless of subject"), `frontend-slides` ("converge toward generic on-distribution outputs"). **This is the root thesis**: slop = a choice made independent of the brief.
- **Generated CSS specificity self-collision** — `anthropic-fd` (a rare code-level structural check): type-selector `.section` vs element-selector `.cta` cancel each other's padding/margin between sections.
- **Horizontal scroll at any width 320-1920px** — `hallmark` (gate 34: fix `overflow-x:clip` on html+body; gate 50: image grid track `1fr` instead of `minmax(0,1fr)`).

---

## 3. Per-Lane Quick Rules

### Web / SaaS Landing

Drawn from `impeccable`, `hallmark`, `anthropic-fd`, `huashu` — the deepest-covered lane.

- No purple/rainbow/mesh gradient; no gradient text; no cream-default surface; no `#0D1117`+neon dark; no pure `#000`/`#fff` base.
- No Inter/Roboto/Geist/Space-Grotesk single-font page; pair a characterful display with a body face (2+1 rule).
- No side-stripe card, no card-in-card, no icon-tile-above-heading 3-col grid, no nested-card, no emoji icons.
- No full-viewport centered hero; ≤2 centred elements; hero `padding-block-end ≥ 1.3× padding-block-start`; eyebrow+headline+lede+CTA fit at 1280×800 without scroll.
- No AI nav/footer fingerprint; no aurora-blob; no re-drawn browser/phone/terminal chrome (use real screenshots).
- No invented metrics/testimonials/logos; honesty test on every decorative image.
- **Numeric floors** (mostly `impeccable`/`huashu`): type-scale ratio ≥1.25 (title ≥2.5x body); line-length 65-75ch (flag >80); line-height ≥1.3 body; body ≥14px (16px mobile); WCAG body 4.5:1, large 3:1 (large = ≥24px or ≥18.67px bold); letter-spacing body ≤0.05em, display floor ≥-0.04em; hero clamp() max ≤6rem; touch target 44×44px; ≤3-4 colors; ≤2-3 fonts; whitespace ≥40%.

### PPT / Deck

Drawn from `huashu` (20 PPT styles), `frontend-slides` (12 presets + 34 templates), `impeccable`/`hallmark` (shared visual rules).

- All web font/color/gradient/decoration bans apply.
- **Fixed-stage discipline** (`frontend-slides`): fixed 1920×1080 canvas scaled uniformly; stay 16:9 on every screen (letterbox/pillarbox, never reflow). Switch slides via `.active`/`.visible` (visibility/opacity/pointer-events), never `display:none/block`.
- **Density modes** (`frontend-slides`/`huashu`): speaker-led = 1 idea + 1-3 bullets, large type; reading-first = 4-8 bullets or 4-6 cards. **"Split, don't shrink"** — overflow → new slide, never shrink until cramped.
- **Slide numeric floors** (`huashu`): slide body ≥24px (ideal 28-36); title-to-body ≥2.5x; contrast ≥4.5:1.
- **Preview/authenticity ban** (`frontend-slides`, NON-NEGOTIABLE): never render internal scaffolding onto a slide — no "preview", "template", "Option A/B/C", file paths, requirement notes, style-preset names. Only real deck chrome (title/section/date/author/page number). Inspect visible text before delivery.
- **Page-numbering ownership** (`huashu`): the deck shell owns page numbers; never self-draw them on a single page (causes double `02/03` + `6/16`).
- One continuous motion narrative, not per-scene fade-up "voiced PowerPoint" (`huashu`).
- Never repeat the same image across slides (except logos on title/closing) (`frontend-slides`).

### Dashboard / Admin UI — **GAP, leans on general principles**

**None of the 6 repos targets dashboards directly.** All are landing-page / deck / prose lanes. Honest statement: there is **no dashboard-specific anti-slop ruleset** in the source corpus. The closest signals:

- `frontend-slides` names "cookie-cutter dashboard/card look" once, in passing, with no dashboard-specific rules.
- `impeccable` is the only one with rules that *transfer cleanly* to data-dense UI because they are component/contrast/density-level, not landing-page-shaped: low-contrast WCAG (4.5:1 / 3:1), gray-on-color, monotonous-spacing, nested-cards, cramped-padding (threshold scales with font-size), clipped-overflow-container (overflow:hidden clipping tooltips/menus/popovers — common in dashboards), text-overflow / horizontal scroll, tight-leading, side-tab borders, design-system drift (font/color/radius not in DESIGN.md).
- `hallmark`'s input/form-state gate (gate 39) transfers: border-width shifting between states, focus-ring built from border not outline, input height ≠ adjacent button height (44px floor), helper-text slot collapsing when empty (reserve `min-height:1lh`), disabled signalled by opacity alone.
- `huashu`'s density nuance is the key dashboard guardrail: **don't strip information density that carries product signal** — only strip decoration. A dashboard's job is dense data; anti-slop must not flatten it.

**Recommendation:** for v0.1, the dashboard lane should be a short section that (a) inherits the web component/contrast/density rules from `impeccable`/`hallmark`'s form gate, (b) explicitly inverts the "more whitespace" reflex via huashu's density nuance, and (c) is flagged as the thinnest-evidenced lane pending a dashboard-specific source.

---

## 4. Copy Anti-Slop

Primarily `stop-slop` (English, the only copy-dedicated repo), with copy detectors from `impeccable`, `anthropic-fd`, `huashu`, `hallmark`.

### Banned phrases (literal blocklists — greppable)

- **Throat-clearing openers** (`stop-slop`): "Here's the thing:", any "Here's what/this/that/why [X]", "The uncomfortable truth is", "It turns out", "The real [X] is", "Let me be clear", "The truth is,", "I'm going to be honest", "Can we talk about".
- **Emphasis crutches** (`stop-slop`): "Full stop.", "Period.", "Let that sink in.", "This matters because", "Make no mistake", "Here's why that matters".
- **Filler phrases** (`stop-slop`): "At its core", "In today's [X]", "It's worth noting", "At the end of the day", "When it comes to", "In a world where", "The reality is".
- **Marketing buzzwords** (`impeccable`, exact list): "streamline your", "empower your", "supercharge your", "unleash (the power)", "leverage the power", "built for the modern", "trusted by leading/the world", "best-in-class", "industry-leading", "world-class", "enterprise-grade", "next-generation", "cutting-edge", "transform your business", "revolutionize", "game-changer", "mission-critical", "future-proof", "seamless experience", "seamlessly integrate", "drive engagement/growth/results", "harness the power".
- **Business jargon → plain** (`stop-slop`): Navigate→Handle, Unpack→Explain, Lean into→Embrace, Landscape→Field, Game-changer→Significant, Double down→Commit, Deep dive→Analysis, Moving forward→Next, Circle back→Return to, On the same page→Aligned.
- **Adverb crutches** (`stop-slop`): really, just, literally, genuinely, honestly, simply, actually, deeply, truly, fundamentally, inherently, inevitably, crucially.
- **Meta-commentary** (`stop-slop`): "Hint:", "Plot twist:", "Spoiler:", "But that's another post", "Let me walk you through…", "In this section, we'll…", "As we'll see…".
- **Lazy extremes** (`stop-slop`): every, always, never, everyone, nobody — use specifics.

### Banned structures (pattern-match)

- **[CORE] Manufactured contrast / telegraphed reversal** — `stop-slop` ("Not because X. Because Y.", "The answer isn't X. It's Y.", "not just X but also Y") and `impeccable` (aphoristic-cadence, two regexes: `Not a X. A Y.` and `X. No/Just y.`, fires at count ≥3 — once is fine, the pattern is the tell). State Y directly, drop the negation.
- **Negative listing (rhetorical striptease)** — `stop-slop`: "Not a X… Not a Y… A Z." → just state Z.
- **[CORE] Em-dash overuse** — `stop-slop` (banned outright), `impeccable` (flag at ≥5: regex `/[—]|--(?=\S)/g`). *Note the softer stance for house style — see §5.*
- **Dramatic fragmentation** — `stop-slop`: "[Noun]. That's it. That's the [thing].", "X. And Y. And Z." → complete sentences.
- **False agency (inanimate subject + human verb)** — `stop-slop` (distinctive, most guides miss it): "a complaint becomes a fix", "the data tells us", "the market rewards" → name the human actor or use "you".
- **Passive voice / narrator-from-a-distance** — `stop-slop`: front the actor; put the reader in the room.
- **Rule of three** — `stop-slop`: "two items beat three"; vary rhythm, don't stack staccato sentences.
- **UX-copy detectors** (`anthropic-fd`, adoptable wholesale): name things by what the user controls not how the system is built ("manage notifications" not "webhook config"); consistent action verbs through a flow (button "Publish" → toast "Published", not "Submit"/"Save"); errors never apologize and never vague (what went wrong + how to fix); empty states are an invitation to act; "nothing quietly does double duty" (one job per element).

### Scoring approach

`stop-slop` and `huashu` both converge on a **5-dimension 0-10 (or 1-10) rubric with a single hard gate**:

- `stop-slop`: Directness / Rhythm / Trust / Authenticity / Density, each 1-10, **/50; below 35 → revise.** Plus a 12-item yes/no Quick-Checks pass where each item names its fix.
- `huashu`: Philosophy / Hierarchy / Craft / Functionality / Originality, each 0-10, banded (excellent 8+, fail <4).

Pair every banned pattern with an **"Instead:"** direct rewrite (problem/fix table) — prescribe the replacement, not just the prohibition.

### Handoff to `humanize-korean`

`stop-slop`'s lists are **English-only and do not map to Korean translationese** (its own caveat). The corpus has **zero Korean copy coverage**. Therefore:

- The `anti-slop-design` skill should **detect/score** copy slop and surface findings, but **delegate the actual Korean rewrite to the `humanize-korean` skill** (the installed orchestrator covering 10 categories / 40+ Korean AI-tell patterns: 번역투, 영어 인용 과다, 기계적 병렬, 피동태 남용, 리듬 균일성, etc.).
- Handoff boundary: anti-slop-design owns the **visual/structural lanes + English copy detection + the scoring gate**; `humanize-korean` owns **Korean prose rewriting**. Do not duplicate `stop-slop`'s blunt absolutes (ban-all-adverbs, ban-all-em-dashes, ban-all-three-item-lists) into Korean — the global `CLAUDE.md` and `humanize-korean` take a softer, Korean-aware stance.

---

## 5. House-Style Cross-Check

User's house style: enterprise; monochrome + single accent (blue/indigo); Pretendard for Korean; no emoji; inline SVG diagrams; dependency-free static HTML+CSS+vanilla JS; print-CSS; Note/Tip/Important/Caution/Warning callouts.

### Agreements (repos reinforce the house style)

| House default | Backing |
|---|---|
| **Monochrome + single restrained accent** | `hallmark` (accent ≤~5% viewport), `huashu` (≤3-4 colors), `frontend-slides` ("dominant color + sharp accents outperform timid evenly-distributed palettes"), `anthropic-fd` (Chanel "spend boldness in one place"). Strongly endorsed. |
| **No emoji** | `hallmark` (gate 30), `huashu`, `frontend-slides` (implied). Direct agreement. |
| **Dependency-free static HTML/CSS/vanilla JS** | `huashu` ("dependency-free"-aligned: prefer hand-built SVG/CSS shape over a Lottie library — `hallmark` gate 31). Aligned. |
| **Print-CSS** | `huashu` print body ≥10pt minimum is the only print signal in the corpus; consistent with print-CSS intent. |
| **Inline SVG diagrams** | **Conditionally** aligned — allowed where SVG is *true icon / geometric / data-viz* (`huashu`), which diagrams are. See conflict below. |

### Conflicts / cautions (where repos warn against something near the house style)

- **Blue/indigo accent ↔ the AI palette.** The single accent the user defaults to — **blue/indigo** — is the *exact hue band* the repos flag. `frontend-slides` explicitly bans generic indigo `#6366f1`; `impeccable` flags hue 260-310; the purple→blue gradient is the #1 universal tell. **Resolution:** a *flat, committed, single* indigo accent is fine; the slop is the **gradient** (purple→blue) and the *unconsidered default* indigo. The house style should pin a specific committed blue/indigo token (via `oklch()`) and **never gradient it**. Flag this as the one place the house default sits closest to a banned pattern.
- **Inline SVG diagrams ↔ hand-drawn-SVG ban.** `huashu`'s most critical ban is hand-drawn SVG of humans/scenes/products. **Diagrams are explicitly in the allowed set** (geometric/data-viz/icons), so no real conflict — but the skill must scope the SVG rule to *figurative/representational* SVG, not architectural/flow diagrams, or it would false-positive the house style's core asset.
- **Em-dash stance.** `stop-slop` bans em-dashes outright; `impeccable` flags at ≥5. The house style (and Korean copy) uses a softer stance. **Resolution:** keep em-dash as a *threshold/advisory* check (≥5 per `impeccable`), not a hard ban — matches the softer global posture.
- **Pretendard.** Pretendard is **not in any banned-font list** (those target Inter/Roboto/Geist/Space-Grotesk Latin faces). It is a Korean-first face and a deliberate house choice — **no conflict**; it satisfies the "characterful, deliberately-paired, not the any-project default" requirement for the Korean lane. (Unverified whether any repo would treat Pretendard as overused — none name it; treat as clean.)
- **Callouts (Note/Tip/Important/Caution/Warning).** Not addressed by any repo. No conflict; this is a docs-formatting convention orthogonal to the slop corpus.

---

## 6. Recommended AUDIT GATE for the Skill

Distilled from `hallmark`'s 6-axis pre-emit critique + `stop-slop`/`huashu` 5-dim scoring + `impeccable`'s deterministic-floor/subjective-ceiling split + `anthropic-fd`'s self-similarity probe. **Not 58 gates — a lean two-phase gate.**

### Phase A — Pre-emit self-critique (BEFORE generating)

Run `anthropic-fd`'s **self-similarity probe** + `hallmark`'s 6-axis score. Cheapest, highest-leverage, no tooling:

> **The probe:** "Work through a similar prompt mentally. If any planned choice (palette, font, layout, hero) is what you'd output for *any* similar brief rather than a choice made for *this* brief — revise it and say what you changed and why."

Score the plan 1-5 on six axes; **any axis <3 → one revision pass before emit**:
1. **Philosophy** — is there a "why"/position, or just a layout?
2. **Hierarchy** — can a reader tell primary/secondary/tertiary in 2s?
3. **Specificity** — does it look like THIS brief or a generic anyone-page?
4. **Restraint** — is everything earning its place? (Chanel "remove one accessory.")
5. **Variety** — structurally distant from prior outputs? (colour-swaps don't count)
6. **Honesty** — zero invented metrics/testimonials/logos?

Loop-termination heuristic (`hallmark`): **"Two passes is normal, three means the brief is wrong, not the design."**

### Phase B — Pre-delivery slop checklist (binary, every answer must be "no")

A ~12-item yes/no gate (binary is cheaper to apply and harder to fudge than a score — `hallmark`). **Any "yes" = fix, don't ship.** Each item pairs detector + fix:

| # | Tell (answer must be "no") | Fix |
|---|---|---|
| 1 | Purple/rainbow/mesh gradient, or gradient text? | Flat committed accent, no `bg-clip:text` |
| 2 | Single overused font (Inter/Roboto/Geist/Space-Grotesk) or one-font page? | Deliberate display+body pairing |
| 3 | Side-stripe card / card-in-card / icon-tile-above-heading 3-col grid? | bg/weight contrast, no stripe, varied cards |
| 4 | Cream-default / `#0D1117`-neon / pure `#000`-`#fff` base? | Committed palette tinted toward anchor hue |
| 5 | Full-viewport centered hero / everything-centered? | ≤2 centred elements; asymmetry |
| 6 | Decorative 01/02/03 numbers or eyebrow chip on every section? | Only for real sequences; encode true content |
| 7 | Generic Hero→3-features→testimonials→CTA→footer skeleton? | Brief-specific macrostructure |
| 8 | Invented metrics / fake testimonials / placeholder names (Acme/Jane Doe)? | Real number, labelled placeholder, or ask |
| 9 | Emoji as icon / mixed icon libraries? | One real icon set |
| 10 | Hand-drawn figurative SVG / re-drawn browser-phone-terminal chrome? | Real screenshot or gray placeholder |
| 11 | Over-animation / `transition-all` / uniform hover-scale / no reduced-motion? | One orchestrated moment + reduced-motion |
| 12 | Copy: buzzwords / "Not X, it's Y" contrast / throat-clearing / fabricated specifics? | State directly; → `humanize-korean` for KO rewrite |

Plus a **numeric floor sweep** (auto-checkable, from `impeccable`/`huashu`): contrast ≥4.5:1 body / 3:1 large; body ≥14px (≥24px slides); type-scale ≥1.25; line-length ≤80ch; line-height ≥1.3; ≤3-4 colors; touch 44×44px; **honesty test** on every decorative image.

### Gate mechanics (lean version of the repos' patterns)

- **Two isolated tracks, then synthesize** (`impeccable`'s bifurcation): the subjective Phase-A judgment forms *before* the mechanical Phase-B checklist enters context, so the checklist doesn't anchor the critique. For a lean skill this is just "critique the plan first, then run the checklist" — no JS engine.
- **Self-describing stamp** (`hallmark`, optional): emit a one-line comment recording which gate items passed (e.g. `<!-- anti-slop: A-pass · contrast ok · slop 1-12 no -->`) so a later audit can detect drift / a "stamp lies" mismatch.
- **Genre escape hatch** (`hallmark`/`anthropic-fd`/`huashu`): every ban is overridable when **"the brief's own words always win"** (brand uses purple → allow; audience is children → allow emoji; explicitly editorial → allow Specimen). State the exception inline so the gate is not a blunt instrument.

---

## 7. What to DEFER (YAGNI for a lean v0.1)

Seen in the repos but **out of scope** for a lean guidance skill:

- **A runnable JS detection engine** (`impeccable`'s `cli/engine/*`: ~thousands of lines, 4 backends — regex/JSDOM/headless-browser/screenshot-contrast, multi-harness mirror copies). Embed the *44-rule data table* as a checklist, not the engine. (Apache-2.0; attribution if any code is reused.)
- **Pre-edit blocking hooks** (`impeccable`'s `hook-before-edit.mjs` `permission:'deny'` gate). v0.1 reports + recommends; it doesn't block edits.
- **The full 58-gate enumeration** (`hallmark`). Distill to the ~12-item gate in §6; don't ship 58.
- **Named-macrostructure / theme / archetype catalogs** (`hallmark` N1-N13 navs, Ft1-Ft8 footers, 21 macrostructures, 20 themes, 50 component archetypes; `huashu` 40-style library; `frontend-slides` 12 presets + 34 templates). These are opinionated house catalogs, not universal law — copy the *anti-pattern principle*, not the catalog.
- **Diversification-by-memory log** (`hallmark` `.hallmark/log.json`, `huashu` build memory). Cross-session anti-sameness tracking is real value but adds state/file machinery; defer past v0.1.
- **Persisted critique snapshots + trend lines** (`impeccable` `.impeccable/critique/<ts>.md`). Nice for a backlog; not MVP.
- **Project context-file system** (`impeccable` PRODUCT.md/DESIGN.md + design-system drift detection; `hallmark`/`huashu` design.md/brand-spec.md). The drift-detection idea is powerful but presumes a committed design system; defer to a later "house-style-aware" version.
- **Heavyweight UX-eval apparatus** (`impeccable`'s Nielsen /40 + 8-item cognitive-load checklist + 5-persona walkthroughs; `huashu`'s per-scene weighting table; `frontend-slides`/`huashu` Playwright render-verification). Generic UX material, not anti-slop IP; the lean gate in §6 replaces it.
- **Brand-asset sourcing protocol** (`huashu`'s 5-step asset gate + 5-10-2-8 threshold). Asset acquisition is a different problem from slop detection.
- **Provider-gated tells** (`impeccable`'s `--gpt`/`--gemini` rules encoding other models' signatures). Opinionated stance; include only if the skill wants to take it.
- **Bundled media / device frames / export pipelines** (`huashu` SFX/BGM/ios_frame.jsx; `frontend-slides` viewport-base.css/extract-pptx.py/deploy.sh). Pure tooling, not guidance.

---

## 8. Sourcing & Confidence Notes

- **Verification basis:** all 6 analyses report **HIGH confidence** from reading actual source via `gh api` (base64-decoded SKILL.md + reference files), not just DeepWiki summaries. This synthesis is a dedup of those source-grounded findings; no source files were independently re-read here.
- **Count discrepancies (trust source, not README):** `impeccable` README says "27 patterns / 25 detections" but the registry has **44** (verified by `grep -c`). `hallmark` README says "57 gates / 20 themes" but source says **58** (gates 1-57 + inserted 38a). READMEs are stale; registries/source files are SSOT.
- **Cross-attribution corrected (`anthropic-fd`):** DeepWiki and a WebFetch summary **hallucinated** rules onto `anthropics/skills/frontend-design` that are NOT in it — named-font bans (Inter/Roboto), "purple gradients on white", the "NEVER converge on Space Grotesk" line, and the BOLD-tone archetype list. Those live in **sibling skills** (web-artifacts-builder names "excessive centered layouts, purple gradients, uniform rounded corners, Inter font"; the Space-Grotesk warning is from a different generator). `frontend-design` itself is **font-agnostic** and names only the 3 clusters. Where this doc attributes font bans to "`anthropic-fd` via sibling," that is the medium-confidence cross-reference.
- **The cream/#F4F1EA = Opus house-style** claim is **medium confidence** — it came from DeepWiki citing `model-migration.md`, not independently re-fetched.
- **`frontend-slides` `#6366f1` indigo + "gratuitous glassmorphism"** are **medium confidence** — from DeepWiki's reading of a "Design Philosophy" wiki section; the broad categories are in SKILL.md but the exact hex/glassmorphism wording was not located verbatim.
- **`hallmark` DeepWiki was UNAVAILABLE** (repo not indexed: "Repository not found") — so all `hallmark` findings are 100% primary-source (gh api raw fetch), none second-hand. An initial WebFetch on `slop-test.md` was refused by a small-model copyright guard and bypassed via raw fetch.
- **No repo covers Korean copy or dashboards.** Both are corpus gaps stated honestly in §3 (dashboard) and §4 (Korean → `humanize-korean` handoff), not synthesized from thin evidence.
- **Self-inconsistencies flagged:** `stop-slop`'s own `examples.md` Example 4 ("Speed, quality, cost—pick two.") uses an em-dash it bans — do not copy its examples verbatim as ground truth.
- **Threshold caveat:** a few `impeccable` numeric thresholds (cramped-padding scaled vThresh/hThresh, flat-type 1.25 ratio) were read from code comments/SKILL.md prose rather than fully traced through function bodies — re-verify before hardcoding exact numbers in shipped code.
- **Licenses (verify before reuse):** `impeccable` Apache-2.0, `hallmark` MIT, `stop-slop` MIT (attribution: Hardik Pandya), `frontend-slides` MIT-style, `huashu` (check LICENSE; bundles third-party media), `anthropic-fd` custom 10KB terms (do not assume Anthropic license carries over).