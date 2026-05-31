#!/usr/bin/env node
// Generate Codex 0.135 manifests from the Claude marketplace source-of-truth.
// One source tree, two runtimes — skills/commands/agents are read in place.
//
// Modes:
//   (default)    write/overwrite manifests on disk
//   --check      diff against on-disk; exit 1 with diff on drift (CI guard)
//   --dry-run    print what would be written, exit 0

import { readFileSync, writeFileSync, existsSync, mkdirSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SOURCE = join(ROOT, '.claude-plugin', 'marketplace.json');
const CATALOG_OUT = join(ROOT, '.agents', 'plugins', 'marketplace.json');
const PLUGINS_DIR = join(ROOT, 'plugins');

// Plugins intentionally not bridged to Codex.
//   codex-bridge — being retired by this very generator
//   core-config  — Claude-only hooks / settings
//   midjourney   — image-gen workflow not portable
const EXCLUDED = new Set(['codex-bridge', 'core-config', 'midjourney']);

const COMPONENT_DIRS = ['skills', 'commands', 'agents', 'mcpServers'];

const MARKETPLACE_NAME = 'my-claude-plugins';
const MARKETPLACE_DISPLAY = 'My Claude Plugins';
const AUTHOR = 'YoungjaeDev';
const LICENSE = 'MIT';

const args = new Set(process.argv.slice(2));
const MODE = args.has('--check') ? 'check' : args.has('--dry-run') ? 'dry' : 'write';

function readJSON(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

function isDir(path) {
  try { return statSync(path).isDirectory(); } catch { return false; }
}

function buildPluginManifest(entry) {
  const pluginDir = join(PLUGINS_DIR, entry.name);
  const manifest = {
    name: entry.name,
    version: entry.version,
    description: entry.description,
    author: { name: AUTHOR },
    license: LICENSE,
  };
  for (const sub of COMPONENT_DIRS) {
    if (isDir(join(pluginDir, sub))) {
      manifest[sub] = `./${sub}/`;
    }
  }
  return manifest;
}

function buildCatalog(entries) {
  return {
    name: MARKETPLACE_NAME,
    interface: { displayName: MARKETPLACE_DISPLAY },
    plugins: entries.map((e) => ({
      name: e.name,
      source: { source: 'local', path: `./plugins/${e.name}` },
      policy: { installation: 'AVAILABLE', authentication: 'ON_INSTALL' },
      category: e.category,
    })),
  };
}

function serialize(obj) {
  return JSON.stringify(obj, null, 2) + '\n';
}

function ensureDir(path) {
  mkdirSync(dirname(path), { recursive: true });
}

function compare(path, next) {
  if (!existsSync(path)) return { drift: true, reason: 'missing' };
  const current = readFileSync(path, 'utf8');
  return current === next ? { drift: false } : { drift: true, reason: 'changed', current };
}

function main() {
  const source = readJSON(SOURCE);
  const eligible = source.plugins.filter((p) => !EXCLUDED.has(p.name));

  const outputs = [];
  for (const entry of eligible) {
    const manifestPath = join(PLUGINS_DIR, entry.name, '.codex-plugin', 'plugin.json');
    outputs.push({ path: manifestPath, content: serialize(buildPluginManifest(entry)) });
  }
  outputs.push({ path: CATALOG_OUT, content: serialize(buildCatalog(eligible)) });

  if (MODE === 'check') {
    const drifted = [];
    for (const { path, content } of outputs) {
      const cmp = compare(path, content);
      if (cmp.drift) drifted.push({ path, reason: cmp.reason });
    }
    if (drifted.length === 0) {
      console.log(`up to date (${outputs.length} manifests)`);
      return;
    }
    console.error(`drift detected in ${drifted.length} file(s):`);
    for (const d of drifted) console.error(`  ${d.reason}: ${d.path}`);
    console.error('\nrun without --check to regenerate.');
    process.exit(1);
  }

  if (MODE === 'dry') {
    for (const { path, content } of outputs) {
      const cmp = compare(path, content);
      const tag = cmp.drift ? (cmp.reason === 'missing' ? 'CREATE' : 'UPDATE') : 'OK    ';
      console.log(`${tag} ${path} (${content.length} bytes)`);
    }
    console.log(`\n${outputs.length} manifests (dry-run, no writes).`);
    return;
  }

  let created = 0, updated = 0, unchanged = 0;
  for (const { path, content } of outputs) {
    const cmp = compare(path, content);
    if (!cmp.drift) { unchanged++; continue; }
    ensureDir(path);
    writeFileSync(path, content);
    if (cmp.reason === 'missing') created++; else updated++;
  }
  console.log(`wrote ${outputs.length} manifests: ${created} created, ${updated} updated, ${unchanged} unchanged.`);
}

main();
