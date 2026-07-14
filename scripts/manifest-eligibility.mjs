// Single source of truth for which plugins each downstream runtime covers.
// Imported by sync-codex-manifests.mjs (Codex EXCLUDED), sync-hermes-manifests.mjs
// (Hermes allowlist), and check-doc-consistency.mjs (doc count checks) so the three
// cannot drift. Update the eligibility HERE, never in a copy — the doc-consistency
// guard reads these same sets, so a stale copy would silently pass stale counts.

// Plugins intentionally not bridged to Codex.
//   core-config — Claude-only hooks / settings (no matching Codex hook surface)
//   codex-image — the Claude->Codex bridge itself (syncing it to Codex is circular)
export const CODEX_EXCLUDED = new Set(['core-config', 'codex-image']);

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
