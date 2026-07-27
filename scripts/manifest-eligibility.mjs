// Single source of truth for which plugins each downstream runtime covers.
// Imported by sync-codex-manifests.mjs (Codex EXCLUDED) and check-doc-consistency.mjs
// (doc count checks) so the two cannot drift. Update the eligibility HERE, never in a
// copy — the doc-consistency guard reads this same set, so a stale copy would silently
// pass stale counts.
//
// Hermes has no eligibility set: it consumes `plugins/<name>/skills/` through
// `npx skills` (scripts/install-skills.mjs), which covers every skill-bearing plugin
// with no per-plugin allowlist to keep in sync. The old HERMES_ELIGIBLE allowlist and
// its generated plugin.yaml / __init__.py adapters were retired in #166.

// Plugins intentionally not bridged to Codex.
//   codex-image — the Claude->Codex bridge itself (syncing it to Codex is circular)
// core-config was here but is now Codex-eligible: Codex plugins support bundled hooks
// (hooks/codex-hooks.json), so its prompt_inject UserPromptSubmit hook ships natively.
export const CODEX_EXCLUDED = new Set(['codex-image']);
