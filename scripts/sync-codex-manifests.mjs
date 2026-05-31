#!/usr/bin/env node
// Generate Codex 0.135 manifests from the Claude marketplace source-of-truth.
// One source tree, two runtimes — skills/commands/agents are read in place.
//
// Modes:
//   (default)    write/overwrite manifests on disk
//   --check      diff against on-disk; exit 1 with diff on drift (CI guard)
//   --dry-run    print what would be written, exit 0

import { readFileSync, writeFileSync, existsSync, mkdirSync, statSync, readdirSync, rmSync, rmdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SOURCE = join(ROOT, '.claude-plugin', 'marketplace.json');
const CATALOG_OUT = join(ROOT, '.agents', 'plugins', 'marketplace.json');
const PLUGINS_DIR = join(ROOT, 'plugins');

// Plugins intentionally not bridged to Codex.
//   core-config — Claude-only hooks / settings
//   midjourney  — image-gen workflow not portable
const EXCLUDED = new Set(['core-config', 'midjourney']);

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

function isFile(path) {
  try { return statSync(path).isFile(); } catch { return false; }
}

function readPluginLicense(pluginDir) {
  const claudeManifest = join(pluginDir, '.claude-plugin', 'plugin.json');
  if (!isFile(claudeManifest)) return LICENSE;
  try {
    const parsed = JSON.parse(readFileSync(claudeManifest, 'utf8'));
    return typeof parsed.license === 'string' && parsed.license.length > 0 ? parsed.license : LICENSE;
  } catch {
    return LICENSE;
  }
}

function buildPluginManifest(entry) {
  const pluginDir = join(PLUGINS_DIR, entry.name);
  const manifest = {
    name: entry.name,
    version: entry.version,
    description: entry.description,
    author: { name: AUTHOR },
    license: readPluginLicense(pluginDir),
  };
  for (const sub of COMPONENT_DIRS) {
    if (isDir(join(pluginDir, sub))) {
      manifest[sub] = `./${sub}/`;
    }
  }
  if (!manifest.mcpServers && isFile(join(pluginDir, '.mcp.json'))) {
    manifest.mcpServers = './.mcp.json';
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

function findOrphanManifests(expectedPaths) {
  if (!isDir(PLUGINS_DIR)) return [];
  const expected = new Set(expectedPaths);
  const orphans = [];
  for (const name of readdirSync(PLUGINS_DIR)) {
    const manifest = join(PLUGINS_DIR, name, '.codex-plugin', 'plugin.json');
    if (isFile(manifest) && !expected.has(manifest)) orphans.push(manifest);
  }
  return orphans;
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

  const orphans = findOrphanManifests(outputs.map((o) => o.path));

  if (MODE === 'check') {
    const drifted = [];
    for (const { path, content } of outputs) {
      const cmp = compare(path, content);
      if (cmp.drift) drifted.push({ path, reason: cmp.reason });
    }
    for (const path of orphans) drifted.push({ path, reason: 'orphan' });
    if (drifted.length === 0) {
      console.log(`up to date (${outputs.length} manifests)`);
      return;
    }
    console.error(`drift detected in ${drifted.length} file(s):`);
    for (const d of drifted) console.error(`  ${d.reason}: ${d.path}`);
    console.error('\nrun without --check to regenerate (orphans will be removed).');
    process.exit(1);
  }

  if (MODE === 'dry') {
    for (const { path, content } of outputs) {
      const cmp = compare(path, content);
      const tag = cmp.drift ? (cmp.reason === 'missing' ? 'CREATE' : 'UPDATE') : 'OK    ';
      console.log(`${tag} ${path} (${content.length} bytes)`);
    }
    for (const path of orphans) console.log(`REMOVE ${path} (orphan)`);
    console.log(`\n${outputs.length} manifests, ${orphans.length} orphans (dry-run, no writes).`);
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
  let removed = 0;
  for (const path of orphans) {
    rmSync(path, { force: true });
    try { rmdirSync(dirname(path)); } catch { /* dir not empty — leave */ }
    removed++;
  }
  console.log(`wrote ${outputs.length} manifests: ${created} created, ${updated} updated, ${unchanged} unchanged, ${removed} orphans removed.`);
}

main();
