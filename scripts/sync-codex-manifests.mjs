#!/usr/bin/env node
// sync-codex-manifests — keep the Codex plugin manifests in sync with the Claude source.
//
// Shared-source model: Codex loads the SAME plugins/<name>/skills/ tree that Claude
// auto-discovers. The only Codex-specific artifacts are small committed manifests,
// which this script (re)generates from the Claude `.claude-plugin/` manifests:
//
//   plugins/<name>/.codex-plugin/plugin.json   name/version/description + skills:"./skills/"
//   .agents/plugins/marketplace.json           repo-root catalog Codex reads on
//                                               `codex plugin marketplace add <repo>`
//
// A plugin is included when it ships >=1 skill and is not excluded. Command-only
// plugins (no skills) and EXCLUDE entries are Claude-only (Codex cannot load them).
// Idempotent — run after any skill / version / description change.
//
// Usage: node scripts/sync-codex-manifests.mjs [--check]
//   --check  exit 1 if anything would change (CI drift guard), write nothing.

import fs from 'node:fs/promises';
import path from 'node:path';
import url from 'node:url';

const REPO_ROOT = path.resolve(path.dirname(url.fileURLToPath(import.meta.url)), '..');
const PLUGINS_DIR = path.join(REPO_ROOT, 'plugins');
const CATALOG_PATH = path.join(REPO_ROOT, '.agents', 'plugins', 'marketplace.json');

// Plugins kept out of the Codex catalog even if they have skills (license / API specifics).
const EXCLUDE = new Set(['midjourney']);

const CATALOG_NAME = 'my-claude-plugins';
const CATALOG_DISPLAY = 'My Claude Plugins (Codex)';

async function readJson(p) {
  try { return JSON.parse(await fs.readFile(p, 'utf8')); }
  catch (err) { if (err.code === 'ENOENT') return null; throw err; }
}

async function hasSkill(skillsDir) {
  let entries;
  try { entries = await fs.readdir(skillsDir, { withFileTypes: true }); }
  catch (err) { if (err.code === 'ENOENT') return false; throw err; }
  for (const e of entries) {
    if (e.isDirectory()) { if (await hasSkill(path.join(skillsDir, e.name))) return true; }
    else if (e.name === 'SKILL.md') return true;
  }
  return false;
}

// Stable-stringify with trailing newline so --check diffs are deterministic.
const fmt = (obj) => `${JSON.stringify(obj, null, 2)}\n`;

async function writeIfChanged(p, content, check, changes) {
  const existing = await fs.readFile(p, 'utf8').catch((e) => { if (e.code === 'ENOENT') return null; throw e; });
  if (existing === content) return;
  changes.push(path.relative(REPO_ROOT, p));
  if (!check) {
    await fs.mkdir(path.dirname(p), { recursive: true });
    await fs.writeFile(p, content, 'utf8');
  }
}

async function main() {
  const check = process.argv.includes('--check');
  const changes = [];

  const rootMarketplace = await readJson(path.join(REPO_ROOT, '.claude-plugin', 'marketplace.json'));
  const metaByName = new Map();
  for (const p of rootMarketplace?.plugins ?? []) {
    metaByName.set(p.name, { description: p.description, category: p.category });
  }

  const entries = await fs.readdir(PLUGINS_DIR, { withFileTypes: true });
  const names = entries.filter((e) => e.isDirectory()).map((e) => e.name).sort();

  const catalog = [];
  for (const name of names) {
    const pluginDir = path.join(PLUGINS_DIR, name);
    const codexManifest = path.join(pluginDir, '.codex-plugin', 'plugin.json');
    const included = !EXCLUDE.has(name) && (await hasSkill(path.join(pluginDir, 'skills')));

    if (!included) {
      // Prune a stale Codex manifest if the plugin no longer qualifies.
      // Only ENOENT means "nothing to prune"; surface any other I/O error
      // (e.g. permissions) instead of silently passing the drift check.
      const codexManifestExists = await fs.access(codexManifest).then(
        () => true,
        (err) => { if (err.code === 'ENOENT') return false; throw err; },
      );
      if (codexManifestExists) {
        changes.push(path.relative(REPO_ROOT, codexManifest));
        if (!check) await fs.rm(path.join(pluginDir, '.codex-plugin'), { recursive: true, force: true });
      }
      continue;
    }

    // A skill-bearing plugin must have a readable source manifest. Failing loud
    // beats emitting a 0.0.0 fallback that hides SSOT drift in a committed artifact.
    const srcPath = path.join(pluginDir, '.claude-plugin', 'plugin.json');
    const src = await readJson(srcPath);
    if (!src) {
      throw new Error(`${name} ships skills but has no readable .claude-plugin/plugin.json (${path.relative(REPO_ROOT, srcPath)}); refusing to emit a fallback manifest.`);
    }
    await writeIfChanged(codexManifest, fmt({
      name: src.name ?? name,
      version: src.version ?? '0.0.0',
      description: src.description ?? `${name} plugin.`,
      skills: './skills/',
    }), check, changes);

    const meta = metaByName.get(name) ?? {};
    const entry = { name, source: { source: 'local', path: `./plugins/${name}` } };
    if (meta.description) entry.description = meta.description;
    if (meta.category) entry.category = meta.category;
    catalog.push(entry);
  }

  await writeIfChanged(CATALOG_PATH, fmt({
    name: CATALOG_NAME,
    interface: { displayName: CATALOG_DISPLAY },
    plugins: catalog,
  }), check, changes);

  if (check) {
    if (changes.length) {
      process.stderr.write(`[sync-codex-manifests] drift in ${changes.length} file(s):\n  ${changes.join('\n  ')}\n`);
      process.exit(1);
    }
    process.stderr.write('[sync-codex-manifests] up to date.\n');
    return;
  }

  process.stderr.write(`[sync-codex-manifests] ${catalog.length} plugins in Codex catalog; ${changes.length} file(s) updated.\n`);
}

main().catch((err) => { process.stderr.write(`[sync-codex-manifests] fatal: ${err.stack ?? err.message}\n`); process.exit(2); });
