#!/usr/bin/env node
// Doc-consistency guard: keep README.md + AGENTS.md in sync with the marketplace
// plugin registry. Fails (exit 1) when a structure tree or the AGENTS plugin
// table lists a different plugin name-set than .claude-plugin/marketplace.json,
// or when a documented plugin-count string drifts from the real numbers.
//
// The version files and sync-*-manifests.mjs --check do NOT catch this class of
// drift (a plugin dropped from a doc tree, or a stale "N plugins" count).
//
// Zero-dep: Node 18+ builtins only. Run: node scripts/check-doc-consistency.mjs

import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const marketplace = JSON.parse(readFileSync(join(ROOT, '.claude-plugin', 'marketplace.json'), 'utf8'));

const canonical = marketplace.plugins.map((p) => p.name);
const canonicalSet = new Set(canonical);
const TOTAL = canonical.length;

// Mirrors of the two generators' scoping constants — kept here so the count
// checks are self-contained. Update alongside sync-{codex,hermes}-manifests.mjs.
const CODEX_EXCLUDED = new Set(['core-config', 'codex-image']); // sync-codex-manifests.mjs EXCLUDED
const HERMES_ELIGIBLE = 7; // sync-hermes-manifests.mjs HERMES_ELIGIBLE size
const CODEX_ELIGIBLE = canonical.filter((n) => !CODEX_EXCLUDED.has(n)).length;

const errors = [];

// --- plugin name-sets from the doc structure trees ---
// Collect the `plugins/` subtree children (│  ├── <name>/ …) until the next
// top-level sibling entry closes the block.
function treePluginNames(md) {
  const names = new Set();
  let inPlugins = false;
  for (const line of md.split('\n')) {
    if (!inPlugins) {
      if (/^[├└]──\s+plugins\//.test(line)) inPlugins = true;
      continue;
    }
    if (/^[├└]── /.test(line)) { inPlugins = false; continue; } // next top-level entry
    const m = line.match(/──\s+([a-z0-9][a-z0-9-]*)\/(?:\s|$)/);
    if (m) names.add(m[1]);
  }
  return names;
}

// AGENTS.md `## Plugins (N)` table: first-column backticked plugin name per row.
function agentsTablePlugins(md) {
  const start = md.indexOf('## Plugins');
  const end = md.indexOf('## 저장소 구조');
  const section = md.slice(start >= 0 ? start : 0, end >= 0 ? end : undefined);
  const names = new Set();
  for (const line of section.split('\n')) {
    const m = line.match(/^\|\s*`([a-z0-9][a-z0-9-]*)`\s*\|/);
    if (m) names.add(m[1]);
  }
  return names;
}

function compareSet(label, got) {
  const missing = canonical.filter((n) => !got.has(n));
  const extra = [...got].filter((n) => !canonicalSet.has(n));
  if (missing.length) errors.push(`${label}: missing ${missing.join(', ')}`);
  if (extra.length) errors.push(`${label}: unknown plugin(s) ${extra.join(', ')}`);
}

// --- documented count strings ---
// Each anchor must be present and equal the expected number, else it is drift.
function checkCount(label, md, regex, expected) {
  const matches = [...md.matchAll(regex)];
  if (matches.length === 0) { errors.push(`${label}: count anchor not found (${regex})`); return; }
  for (const m of matches) {
    const got = expected.map((_, i) => Number(m[i + 1]));
    if (got.some((g, i) => g !== expected[i])) {
      errors.push(`${label}: expected ${expected.join('/')}, found ${got.join('/')} in "${m[0]}"`);
    }
  }
}

const readme = readFileSync(join(ROOT, 'README.md'), 'utf8');
const agents = readFileSync(join(ROOT, 'AGENTS.md'), 'utf8');

compareSet('README.md tree', treePluginNames(readme));
compareSet('AGENTS.md tree', treePluginNames(agents));
compareSet('AGENTS.md ## Plugins table', agentsTablePlugins(agents));

checkCount('README.md badge', readme, /plugins-(\d+)-blue/g, [TOTAL]);
checkCount('README.md 플러그인 모음', readme, /(\d+)개 플러그인 모음/g, [TOTAL]);
checkCount('README.md Codex share', readme, /(\d+) \/ (\d+) 플러그인/g, [CODEX_ELIGIBLE, TOTAL]);
checkCount('AGENTS.md ## Plugins (N)', agents, /## Plugins \((\d+)\)/g, [TOTAL]);
checkCount('AGENTS.md eligible N개', agents, /eligible (\d+)개/g, [CODEX_ELIGIBLE]);
checkCount('AGENTS.md # N entries', agents, /# (\d+) entries/g, [CODEX_ELIGIBLE]);
checkCount('AGENTS.md 현재 N개', agents, /현재 (\d+)개/g, [HERMES_ELIGIBLE]);

if (errors.length) {
  console.error('doc-consistency drift detected:');
  for (const e of errors) console.error(`  ${e}`);
  console.error('\nfix README.md / AGENTS.md to match .claude-plugin/marketplace.json.');
  process.exit(1);
}
console.log(`doc-consistency OK — ${TOTAL} plugins, Codex-eligible ${CODEX_ELIGIBLE}, Hermes ${HERMES_ELIGIBLE}; trees + table + counts consistent.`);
