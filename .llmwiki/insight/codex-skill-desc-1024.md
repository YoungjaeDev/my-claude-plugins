---
id: codex-skill-desc-1024
aliases: [codex-1024-description, skill-description-length-cap, codex-silent-skill-skip]
tier: insight
promoted_from: [[shared-source-codex-manifests]]
evidence_count: 2
last_verified: 2026-06-23
status: active
volatility: stable
sources: 2
---

# Keep skill `description` frontmatter under 1024 chars

Codex 0.135 silently skips any skill whose `description` exceeds 1024 characters — no warning, no manifest error, the skill just never loads on the Codex side. Claude Code has no such cap, so the violation is invisible from the Claude surface. When a description trips the cap, do not truncate meaning: move the full trigger list / per-tool rationale into the skill **body** (and `references/`) and keep the description a tight routing summary.

**When to apply**: writing or editing any skill `description`; especially when *adding* to one already near the cap (swapping a referenced name for a longer one, appending triggers). Check the length before committing — `node scripts/sync-codex-manifests.mjs --check` and the `.githooks/pre-commit` hook (`git config core.hooksPath .githooks`) both enforce it.

**Why**: the failure is a silent, asymmetric skill loss — the skill keeps working for Claude while vanishing for Codex, so nothing surfaces the break until someone notices a missing Codex capability. Recurred twice: PR #46 (`research-orchestrator` at 1214 chars was dropped) and PR #51 (the `post-merge` skill at 1019 chars would have hit 1026 on a `humanizer`→`humanize-korean` swap; offset by trimming elsewhere to 1014).

The three-layer guard mechanics (generator `SKILL_DESC_MAX`, pre-commit, CI) and the silent-skip rationale stay in the `promoted_from:` wiki page — not inlined here.

## CodeRabbit byte-count false positive (skip it)

The enforced limit is 1024 **characters** — `sync-codex-manifests.mjs` measures `desc.length` (JS string length ≈ characters; Hangul syllables are one BMP code unit each), matching Codex's own char-based cap. CodeRabbit's description-length finding measures **bytes**, so a Korean (multibyte, ~3 B/char in UTF-8) description well under the char cap can exceed 1024 *bytes* and be flagged spuriously — `ppt-yeong-style`'s description is 594 chars / 1049 bytes: within the real limit, over a byte count. This recurred in PR #72 and PR #74. `cr-fix` should **skip** the finding when `node scripts/sync-codex-manifests.mjs --check` already passes (the generator is the authority), not trim a description that is in budget. This is a distinct facet from the real-violation graduation basis above (`evidence_count` unchanged), so it is recorded as a skip-rule, not a new recurrence.

## Sources

- `.llmwiki/wiki/plugin-ops/shared-source-codex-manifests.md` — the promoted source page (the length-guard section: silent-skip behavior, three-layer enforcement, both recurrences).
- `scripts/sync-codex-manifests.mjs` — the `SKILL_DESC_MAX = 1024` guard and `--check` gate itself.

> Evidence: .llmwiki/wiki/plugin-ops/shared-source-codex-manifests.md
> See-also: [[codex-manifest-regen]]
> See-also: [[shared-source-codex-manifests]]
