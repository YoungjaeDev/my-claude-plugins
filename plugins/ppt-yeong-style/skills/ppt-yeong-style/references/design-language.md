# Design language — the yeong signature (§0 detail)

The aesthetic spine of the skill. anti-slop tells you what NOT to do; this tells you what TO do
so a deck reads as a deliberate high-end artifact, not a competent-but-generic AI house style.

> Derived from a reference corpus (enterprise/product decks, Seongsu·Hongdae pop, Hannam
> high-end, Apple-grade, Korean card-news), cross-extracted by Claude + Codex with near-total
> agreement. This file is the distilled ONE signature.

## The one signature

**"Editorial restraint, one committed accent."**
A disciplined warm-neutral editorial canvas, broken by exactly ONE committed loud moment per
page. Restraint that feels alive, not safe. The craft is making silence feel charged without
letting the composition become decorative noise.

Core proposition: **signature within trust.** The anti-slop trust floor stays fully intact
(every ban below is kept). The high-end differentiation is layered on top as deliberate *tonal
intent* — controlled by tone, not by adding more. This is the brand-asset escape hatch of
anti-slop, used deliberately: when there is a committed visual language, it wins over the
generic safe default.

## The six axes (apply every deck)

1. **Layout** — Swiss/editorial grid laid down, then broken with intent. ONE dominant anchor per
   page (oversized type/number OR one cropped image). Hard left-edge anchoring, baseline
   discipline, small metadata rails. Tension at edges/overlaps/crops, never a centered hero.
2. **Whitespace** — moderate→extreme, never evenly filled. Emptiness carries *pressure* (it
   frames the anchor), it is not just "clean space."
3. **Color** — neutral-FIRST, warm-tinted base + ONE committed high-saturation accent. Low base
   saturation, sharp accent. The accent is a *system*, not sprinkled. yeong house accent =
   Claude orange `#D97757` on warm off-white `#FAF8F3`; lock the exact tokens per project
   (`color-typography.md`), but the *philosophy* (warm neutral + single committed accent) is
   fixed. No rainbow, no gradient, no gradient text.
4. **Typography** — EXTREME header→body scale jump (**display ≥ 1.5× body, cover ≥ 3×**). Very
   high weight contrast (heavy display vs tiny light metadata). Sans-dominant; serif only as
   editorial seasoning. Tight, confident, poster-like tracking — not airy. **Type itself is a
   graphic element** (oversized, stacked, numbers-as-structure).
5. **Photo** — editorial material, not stock decoration. B&W / desaturated = authority;
   controlled color = immediacy. Single-color (accent) overlay, subtle grain, never
   glossy-clean. Aggressive intentional crops; type overlaps / frames the photo.
6. **Pop** — the loud break is ISOLATED to hierarchy peaks (cover, section divider, one giant
   number, one accent panel/burst). **Honesty test (tone version): a pop must carry an emotional
   or narrative signal. If it conveys no tone information, delete it.** One pop per spread, not
   per element.

## anti-slop ↔ high-end: both hold (banned stays banned, tone does the work)

| anti-slop ban (kept) | high-end move (how tone differentiates without breaking the ban) |
|---|---|
| no purple/blue gradient, no gradient text | ONE flat committed accent; depth via scale + whitespace, not gradient |
| no centered hero | off-center anchor, hard left-edge alignment, asymmetric tension |
| no icon-tile 3-col grid | one dominant anchor; supporting info as a small rail or table |
| no even rhythm across slides | deliberate quiet/loud/dense/sparse pacing (page_rhythm) |
| no emoji icons | one line/editorial icon family, fill-only |
| no fabricated metrics / fake symmetry | balance from tension; real numbers only |
| no body wall-of-text | extreme type-scale: huge anchor + tiny metadata |

## ppt-master lever lock (signature → engine values)

Encode these into `spec_lock.md` so the executor applies them every page (see
`ppt-master-craft.md` for the levers):

- **image rendering × palette** — warm-neutral base + single accent, ONE combo deck-wide.
- **page_rhythm** — uneven on purpose: anchor (extreme whitespace) / breathing / dense.
- **type-scale** — display ≥1.5× body, cover ≥3×; very high weight contrast.
- **icon** — one family, line/editorial, fill-only, never emoji.
- **photo** — B&W or single-accent overlay + grain; aggressive crop; type overlaps.
- **pop** — isolated to hierarchy peaks; honesty-test gated.

> Where this meets the rest: color/area discipline → `color-typography.md`; pop/photo honesty →
> `images-and-pop.md`; lever encoding → `ppt-master-craft.md`. This file is the *why*; those are
> the *how*.
