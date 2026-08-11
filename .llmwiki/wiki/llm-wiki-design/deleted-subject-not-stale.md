---
id: deleted-subject-not-stale
aliases: [subject-deleted-lore, removed-plugin-lore, lore-outlives-its-subject, dangling-evidence-path]
last_verified: 2026-08-11
status: active
volatility: stable
sources: 4
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

## Triage the hits; never sweep them

That grep has an inverse failure, and it is the one that actually happened next. Run as a repo-wide find-and-replace — the same sweep that correctly repoints live `plugin:skill` references — it rewrites the wiki's historical evidence into self-contradiction.

A page recording "a review caught a **non-eligible** plugin's body advertising `skill_view("voice-prompt:voice-prompt")`" came out of the sweep saying `skill_view("docs-forge:voice-prompt")`. The new identifier is one the adapter now correctly mints, so the sentence contradicts the finding it exists to support, and the evidence for a settled rule reads as a mistake.

The asymmetry is the whole point. A live reference must be updated or it routes users at something gone; a historical one must be preserved or the record stops being a record. The table above already sorts these — the sweep is what skips the sorting.

Two habits keep them apart:

- **Exclude the record from mechanical rewrites.** `.llmwiki/wiki/`, `.llmwiki/raw/`, past specs, and test fixtures hold statements about the past. A sweep that reaches them is editing history, not references. (Excluding `docs/superpowers/` and `raw/audits/` while forgetting `.llmwiki/wiki/` is how this one landed.)
- **Append the move, don't rewrite the claim.** When a historical page's subject has since moved, keep the original identifier and add a dated follow-on sentence naming the new location. Both facts survive; neither is asserted in the other's tense.

## The deletion side: the test is subject-death, never link-absence

The page above is about lore that outlives its subject. The mirror case is the document you are about to *delete* because its subject is gone — and there the tempting test is the wrong one. "Nothing links to it" fails in both directions at once. It **over-deletes**: a freshly written audit report is an orphan by construction the second it is created, so a cleanup pass run right after a sweep eats the sweep's own evidence; and a design record for a plugin that shipped and is still installed has no reason to be linked from anywhere, yet deleting it turns a settled decision back into a debate. It also **under-protects**, missing exactly the case this page exists for: a document nothing *links* to may still be *cited* as `> Evidence:` by an active wiki page, which is a reference the link heuristic was never looking at.

Use the subject: **does the plugin, skill, or subsystem this document is about still exist?** That question has one answer, it is checkable against `marketplace.json` and `plugins/`, and it is indifferent to how many things happen to point at the file. Then, separately, run the inbound check against the surviving citations — with `--hidden`, because the wiki lives in a dot-directory (see [[detector-cannot-look-vs-nothing-wrong]] Mode 6). Anything still cited gets the annotation treatment from the section above, not a rescue from deletion.

> See-also: [[absorption-rehomes-the-body]]
> See-also: [[detector-cannot-look-vs-nothing-wrong]]
> See-also: [[insight-layer-via-hook]]
> See-also: [[skill-engine-layering]]
> Evidence: .llmwiki/wiki/plugin-ops/skill-engine-layering.md
> Evidence: .llmwiki/wiki/plugin-ops/shared-source-codex-manifests.md

## Sources

1. **PR #191 (merged `4f95949`)** — removal of `anti-slop-design` + `ppt-yeong-style`. Two active `plugin-ops/` pages kept present-tense assertions that the removed plugins were current: `skill-engine-layering.md` opened with "`ppt-yeong-style` **is** such a layer" and listed `anti-slop-design` in a live optional-dependency roster; `shared-source-codex-manifests.md` carried a `> Evidence:` at a path inside the deleted tree. Every manifest, count, and eligibility guard in the repo passed on that PR.
2. **Codex review on PR #191 (P2)** — flagged the surviving lore as "false operational guidance and dangling evidence paths" and proposed archiving the pages. The claim was correct; the proposed remedy was rejected against this repo's wiki lifecycle (`status: stale` requires a `> Superseded-by:` pair, and nothing supersedes the lesson), which is what produced the tense-not-lifecycle rule above.
3. **PR #200 (merged `c56bd25`)** — the inverse failure. A repo-wide rename sweep for the absorption reached `.llmwiki/wiki/`, rewriting the PR #193 evidence on `plugin-ops/hermes-plugin-adapter.md` and the PR #154/#156/#158 note on `plugin-ops/skill-authoring-source-grounded-then-audit.md` into claims that contradicted their own surrounding sentences. `docs/superpowers/` and `.llmwiki/raw/audits/` had been excluded from the sweep for exactly this reason; `.llmwiki/wiki/` was missed. Caught by Codex review (P2), restored to the original wording with the move recorded as a dated follow-on sentence.
4. **PR #206** (`chore: 스킬 전수 검토 + README 상세 절 재구성 + 죽은 문서 정리`) — the deletion-side rule, learned by getting it half right. The pruning pass correctly used subject-death to decide *what* to delete (and correctly spared `2026-07-07-mem0-ops-plugin.md`, a link-orphan whose plugin still ships), but its inbound-reference check used a dot-dir-blind `rg`, so two of the deleted files were still cited as `> Evidence:` by an `status: active` page. Both halves are needed: subject-death picks the candidates, a `--hidden` citation scan decides which dangling pointers need annotating.
