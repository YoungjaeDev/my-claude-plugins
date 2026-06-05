---
id: cr-cli-false-positive-generated-files
aliases: [cr-cli-generated-file-revert, cr-manifest-manual-edit-false-positive]
last_verified: 2026-06-05
status: active
volatility: stable
sources: 2
---

# CR CLI flags a correctly-regenerated manifest as "manually edited" (false positive)

## The misread

When a PR's diff includes a regenerated Codex manifest (`.codex-plugin/plugin.json`
or `.agents/plugins/marketplace.json`), the local CodeRabbit CLI
(`coderabbit review --agent`) raises a **Major**: "you manually edited a generated
file; revert it (`git checkout HEAD -- ...`) and regenerate via the generator."

The CLI sees a diff to a file it recognizes as generated and infers a hand-edit. It
cannot see *how* the diff was produced.

## Why it is spurious

If the change followed the correct workflow, the finding is wrong:

- The canonical edits were made in the source (`.claude-plugin/plugin.json` +
  `.claude-plugin/marketplace.json`).
- `node scripts/sync-codex-manifests.mjs` was run, which *produced* the manifest diff.

The deciding test is the generator's own drift gate:

```bash
node scripts/sync-codex-manifests.mjs --check   # "up to date" → file IS generator output
```

If `--check` passes, the manifest is byte-identical to what the generator emits —
i.e. it is *not* a manual edit, and reverting it would re-introduce drift. The CR CLI
finding is then a false positive: **skip it** (do not revert, do not regenerate
again).

## cr-fix triage rule

In a `cr-fix` run, a CR/CLI finding on a generated manifest is `is_real: spurious`
once `--check` passes → action `skip`, reason "generator output, --check confirms
in-sync". Acting on it (the suggested `git checkout HEAD --`) would undo a correct
regeneration. Surface the skip + reason in the final report; do not silently drop it.

## Dogfood (PR #50)

CR PR-bot was disabled (free-tier), so cr-fix fell back to the CLI. The CLI's only
Major was this exact false positive on `plugins/github-dev/.codex-plugin/plugin.json`.
`--check` returned `up to date (20 manifests)` → skipped. The next iteration's CLI
review returned 0 findings (the spurious one did not even recur), so the loop
converged clean.

## Sources

1. `plugins/github-dev/.codex-plugin/plugin.json` — the regenerated manifest the CLI flagged (PR #50 cr-fix dogfood).
2. `scripts/sync-codex-manifests.mjs` — the generator + `--check` drift gate that disproves the "manual edit" claim.

> Evidence: plugins/github-dev/.codex-plugin/plugin.json
> See-also: [[codex-manifest-regen]]
> See-also: [[cr-rate-limit-progressive-refill]]
