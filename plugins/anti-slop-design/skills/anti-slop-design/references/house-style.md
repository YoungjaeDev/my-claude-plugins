# house-style

Default suggestions and OSS cross-check. Source substance: `docs/references/anti-slop-design-oss-synthesis.md` §5.

**Principle: the default is generic; house-style is a worked example / default suggestion.** A brief or brand material, if present, wins. house-style is "a reasonable starting point when there is no material", not a mandatory norm.

---

## 1. Default suggestions (enterprise tone)

- **enterprise / calm but sharp** — the trust of a tech company without hype, information-transfer first, low-noise/high-signal.
- **monochrome + a single accent** — grayscale base + 1 accent color.
- **Pretendard** (Korean body/headings).
- **no emoji** (in code, docs, and UI alike).
- **inline SVG diagram** — architecture/flow/data-viz.
- **dependency-free static** — HTML + CSS + vanilla JS, no external dependency.
- **print-CSS** (body >=10pt).
- **callout** — Note / Tip / Important / Caution / Warning.

OSS reinforcement (consensus): a single restrained accent is supported by hallmark (accent <=~5% viewport), huashu (<=3-4 colors), frontend-slides ("a dominant color + a sharp accent beats a timid even palette"), and frontend-design ("spend boldness in one place"). no-emoji and dependency-free are directly agreed too.

---

## 2. Conflict resolution (where house-style approaches a banned pattern)

### blue/indigo accent <-> AI palette
The user's default accent (blue/indigo) is exactly the hue band the repos point at (frontend-slides explicitly bans generic indigo `#6366f1`, impeccable flags hue 260-310, and a purple->blue gradient is the #1 universal tell).

**Resolution:** slop is the **gradient** and the **thoughtless default indigo**, not a *flat single committed* indigo.
- house-style pins a specific committed indigo token in `oklch()` and **never turns it into a gradient**.
- This one spot is the only place house-style comes closest to a banned pattern — when using it, state inline that it is a "flat, single, committed accent".

### inline SVG diagram <-> hand-drawn SVG ban
huashu's top ban is **figurative/representational SVG** (people·scenes·products). **Diagrams·icons·data-viz are an explicitly allowed set.**

**Resolution:** scope the SVG ban **to figurative only**. Architecture/flow diagrams are a core house-style asset, so they must not produce false positives. That is, "hand-drawn person/product SVG" != "structural diagram".

### Pretendard / callout
The banned-font list (targeting Latin faces like Inter/Roboto/Geist/Space Grotesk) has no Pretendard — a Korean-first deliberate choice, no conflict (no repo names Pretendard as an overused font; treat it as clean). callout is covered by no repo — orthogonal to the slop corpus, no conflict.

---

## 3. Application rules

- Use the defaults above as a starting point only when there is no brand material. When material exists, the brand-spec wins.
- Accent is a single committed `oklch()` token; no gradient.
- SVG only for diagram/icon/data-viz — no figurative hand-drawing.
- When generic output is the goal, do not force house-style — present it only as a "default suggestion".
