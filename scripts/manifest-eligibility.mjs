// Single source of truth for which plugins each downstream runtime covers.
// Imported by sync-codex-manifests.mjs (Codex EXCLUDED), sync-hermes-manifests.mjs
// (Hermes allowlist), and check-doc-consistency.mjs (doc count checks) so the three
// cannot drift. Update the eligibility HERE, never in a copy — the doc-consistency
// guard reads these same sets, so a stale copy would silently pass stale counts.

// Plugins intentionally not bridged to Codex.
//   codex-image — the Claude->Codex bridge itself (syncing it to Codex is circular)
//   council     — seats codex as a council member, so running it under Codex summons
//                 codex as its own seat; its Claude seat also needs the Agent tool,
//                 which Codex has no equivalent for
// core-config was here but is now Codex-eligible: Codex plugins support bundled hooks
// (hooks/codex-hooks.json), so its prompt_inject UserPromptSubmit hook ships natively.
export const CODEX_EXCLUDED = new Set(['codex-image', 'council']);

// Plugins that get generated Hermes adapters (plugin.yaml + __init__.py).
export const HERMES_ELIGIBLE = new Set([
  'github-dev',
  'interview',
  'anti-slop-design',
  'tcrei-prompt',
  'ppt-yeong-style',
  'ml-toolkit',
  'brightdata-guide',
]);
