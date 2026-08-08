---
id: absorption-rehomes-the-body
aliases: [plugin-absorption, skill-rehome, absorbed-skill-audit, eligibility-blast-radius, bundle-wide-eligibility]
last_verified: 2026-08-08
status: active
volatility: stable
sources: 2
---

# Absorbing a plugin re-homes its skills; the bodies do not follow

Folding one plugin's skills into another bundle looks like a wiring job — move the directory, rewrite the `plugin:skill` references, regenerate the manifests, fix the counts. Every one of those has a guard, and all of them pass. What has no guard is the moved skill's own body, which goes on describing a plugin that no longer exists.

The distinction is where the two halves are written. The wiring lives *outside* the skill, in files the sweep touches by construction. The identity lives *inside* it, in prose and shell that names the old owner — and a reference rewrite keyed on `old-plugin:skill-name` never matches `plugins/old-plugin/` inside a resolver, or `hermes plugins install .../plugins/old-plugin`, or a sentence asserting the plugin is outside an allowlist.

**Audit the moved tree for the old plugin name before calling the absorption done.** That single grep is what the wiring guards cannot do for you.

> Refines: [[deleted-subject-not-stale]]

## The five classes, and why each is invisible until runtime

Each of these landed in a separate review round of one absorption PR, one per round, after the absorption itself looked finished:

| Class | What breaks | Why the sweep misses it |
|---|---|---|
| `PLUGIN_ROOT` resolver globbing `*/<old-plugin>/*` | Under Codex, where `CLAUDE_PLUGIN_ROOT` is unset and the plugin loads from the cache tree, every candidate misses and the skill dies at "script not resolved" | It is a path fragment in shell, not a `plugin:skill` token |
| `hermes plugins install .../plugins/<old-plugin>` | Installs a subdirectory the PR deleted | Same — a URL path, not a reference |
| An eligibility claim the move inverted | A body saying "this plugin is outside `HERMES_ELIGIBLE`, load it by bare name" is now false in both halves | It is prose about the *old* owner's properties |
| Un-namespaced `/skill-name` example | Does not resolve once the skill is one of several in a bundle | It was correct when the plugin had exactly one skill |
| Destination version left unbumped | Cache-gated users never receive the move at all | Only *reference* files changed in that plugin, so the bump looks unwarranted |

The last one deserves its own note: a plugin touched solely by a rename sweep is still a plugin whose shipped files changed. Skipping its bump strands users on instructions pointing at commands the same PR deleted.

## Eligibility is a property of the bundle, not the skill

The runtime allowlists (`HERMES_ELIGIBLE`, `CODEX_EXCLUDED` in `scripts/manifest-eligibility.mjs`) key on plugin name, so absorption moves a skill *across an eligibility boundary* as a side effect nobody wrote down.

Both directions bite:

- **Into an eligible bundle.** Adding `docs-forge` and `code-scout` to `HERMES_ELIGIBLE` published every skill under them through the generated adapter — including five that had never needed a Hermes tool-name mapping and so carried none. Each loads fine and then stalls on its first tool call. The fix is to audit the destination's *whole* skill set, not the moved skills.
- **Into an excluded bundle.** `CODEX_EXCLUDED` drops the entire plugin, so absorbing an excluded plugin would take its new bundle-mates with it. This is why `codex-image` and `council` stay standalone despite being single-skill plugins — the fragmentation is deliberate.

> See-also: [[hermes-plugin-adapter]]
> See-also: [[shared-source-codex-manifests]]

## Measure the destination before choosing it

The absorption that produced this page started from a plan to consolidate broadly, then narrowed once the reference counts were actually measured: bundling the plugins that were *already* bundles would have cost hundreds of cross-reference edits, while absorbing only the single-skill plugins cost 44. Counting first turned a large restructure into a small one.

The same measurement guards the destination choice. Each absorption here mapped onto a dependency that already existed — the skill that writes `.llmwiki/raw/transcripts/` went to `llm-wiki`, the one backing `web-scout`'s fetch fallback went to `code-scout` — so no route had to be invented, only re-pointed.

## A stale local checkout invents the whole problem

Worth stating because it wasted the first pass: the spec, PRD, and issue for this work were written against a local `main` that was 25 commits behind, so three plugins the plan proposed deleting had already been removed and two new ones it never mentioned had landed. Every downstream artifact inherited the wrong premise.

Repo state read for planning is a measurement like any other. `git fetch` before it, or the plan is fiction with citations.

## Sources

1. **PR #200 (merged `c56bd25`)** — 11 single-skill plugins absorbed into `docs-forge` / `github-dev` / `ml-toolkit` / `code-scout` / `llm-wiki` / a new `publish` bundle (24 → 14). Eight cr-fix rounds, 28 findings applied; every round surfaced at least one instance of an absorbed body still naming its old owner.
2. **Codex + CodeRabbit reviews on PR #200** — the five breakage classes above were each caught by a reviewer, not by the four `--check` guards, all of which passed on the initial absorption commit. The Hermes-mapping gap on the newly-eligible bundles was Codex P1 on the round that added the allowlist entries.
