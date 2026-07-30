---
id: deleted-subject-not-stale
aliases: [subject-deleted-lore, removed-plugin-lore, lore-outlives-its-subject, dangling-evidence-path]
last_verified: 2026-07-30
status: active
volatility: stable
sources: 2
---

# A page whose subject was deleted is not a stale page

Deleting a plugin, module, or subsystem removes it from the code tree, the manifests, and the counts — all of which have guards. It does not touch the wiki, which has none. What is left behind is a page that is still `status: active`, still correct in its *lesson*, and now lying about what exists. An agent entering through the MOC is handed a removed subsystem as installable current functionality, with no signal that anything changed.

This is a distinct failure from age-based staleness. `volatility:` windows ask "has anyone re-checked this recently"; this asks "does the thing this page talks about still exist". A page can be verified yesterday and be wrong today because its subject was deleted this morning.

> Refines: [[volatility-over-decay]]

## The remedy is tense, not lifecycle

The reflex — mark the page `status: stale` and move on — is wrong, and it corrupts the wiki while looking like cleanup:

- `status: stale` means **superseded**: some newer claim replaced this one. A deleted subject supersedes nothing. The lesson the page distilled is usually still true and still the only place it is written down.
- The lifecycle is a **pair**. `ingest-finding`'s final self-check (and `lint-wiki`'s monotonic-relationships sweep) fail a page that is `status: stale` with no `> Superseded-by:` back-pointer. Marking a page stale with nothing to point at manufactures exactly the one-sided corruption those checks exist to catch.

The page stays `active`. What changes is the tense of the claims inside it.

## Which lines are wrong, and which are correctly historical

Not everything naming the deleted subject is a defect. Sort by what the line *asserts*:

| Line | Asserts | Action |
|---|---|---|
| Body prose in present tense — "`X` **is** a layer over `Y`", a live roster listing `X` among current optional dependencies | that `X` exists now | **Reframe.** Past tense, plus one explicit sentence at the top saying the subject was removed and the page is a past worked example. |
| Body narrative already in past tense and anchored to a dated change — "a re-audit **surfaced** two drift modes in `X`" | that this happened | Keep as-is. |
| `## Sources` entries citing a dated change | provenance | Keep. Provenance is historical by definition; rewriting it destroys the audit trail. |
| A `> Evidence:` pointing at a path inside the deleted tree | that a reader can go read it | **Annotate**, do not delete. Mark the path dead and name the merge where it can still be read. |

The one blanket sentence near the top is what does the work: it re-frames every remaining mention at once, so the rest of the page needs only the handful of genuinely present-tense assertions fixed rather than a line-by-line rewrite.

## Why it survives the removal PR

The removal itself is well guarded — manifest drift, doc counts, orphan adapters, and eligibility lists all have `--check`s, and they all pass while the lore rots. The wiki is the one surface with no mechanical guard, so a removal PR reads as fully green. It surfaced here only because a review agent read the wiki alongside the diff; nothing in the repo's own toolchain would have raised it.

Practical consequence: a plugin-removal change should grep the wiki root for the removed name as an explicit step, and triage the hits with the table above — the same way it greps scripts and settings.

> See-also: [[insight-layer-via-hook]]
> See-also: [[skill-engine-layering]]
> Evidence: .llmwiki/wiki/plugin-ops/skill-engine-layering.md
> Evidence: .llmwiki/wiki/plugin-ops/shared-source-codex-manifests.md

## Sources

1. **PR #191 (merged `4f95949`)** — removal of `anti-slop-design` + `ppt-yeong-style`. Two active `plugin-ops/` pages kept present-tense assertions that the removed plugins were current: `skill-engine-layering.md` opened with "`ppt-yeong-style` **is** such a layer" and listed `anti-slop-design` in a live optional-dependency roster; `shared-source-codex-manifests.md` carried a `> Evidence:` at a path inside the deleted tree. Every manifest, count, and eligibility guard in the repo passed on that PR.
2. **Codex review on PR #191 (P2)** — flagged the surviving lore as "false operational guidance and dangling evidence paths" and proposed archiving the pages. The claim was correct; the proposed remedy was rejected against this repo's wiki lifecycle (`status: stale` requires a `> Superseded-by:` pair, and nothing supersedes the lesson), which is what produced the tense-not-lifecycle rule above.
