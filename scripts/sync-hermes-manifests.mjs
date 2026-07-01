#!/usr/bin/env node
// Generate Hermes Agent adapters from the Claude marketplace source-of-truth.
// One source tree, three runtimes — Claude (native), Codex (.codex-plugin via
// sync-codex-manifests.mjs), Hermes (plugin.yaml + __init__.py, this file).
//
// Each eligible plugin gets two derived files in its root:
//   plugin.yaml   — Hermes manifest; name/version/description from marketplace.json
//   __init__.py   — generic Python entrypoint that registers every SKILL.md as a
//                   `<plugin>:<skill>` Hermes skill. No per-plugin logic.
//
// Modes:
//   (default)    write/overwrite adapters on disk
//   --check      diff against on-disk; exit 1 with diff on drift (CI guard)
//   --dry-run    print what would be written, exit 0

import { readFileSync, writeFileSync, existsSync, statSync, readdirSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SOURCE = join(ROOT, '.claude-plugin', 'marketplace.json');
const PLUGINS_DIR = join(ROOT, 'plugins');

// Plugins that ship a Hermes adapter. Allowlist (mirror of the Codex generator's
// EXCLUDED denylist) — add a name here to extend Hermes coverage in a later round.
// Intentionally absent: core-config (no skills to register), codex-image (codex
// CLI dependency + redundant with Hermes native image generation).
const HERMES_ELIGIBLE = new Set([
  'github-dev',
  'interview',
  'anti-slop-design',
  'tcrei-prompt',
  'ppt-yeong-style',
  'ml-toolkit',
]);

const AUTHOR = 'YoungjaeDev';

const args = new Set(process.argv.slice(2));
const MODE = args.has('--check') ? 'check' : args.has('--dry-run') ? 'dry' : 'write';

function readJSON(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

function isFile(path) {
  try { return statSync(path).isFile(); } catch { return false; }
}

function isDir(path) {
  try { return statSync(path).isDirectory(); } catch { return false; }
}

// Minimal YAML double-quote scalar — escape backslash + double-quote only; the
// marketplace descriptions contain no control chars, so this is sufficient.
function yamlQuote(value) {
  return '"' + String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
}

function buildPluginYaml(entry) {
  return [
    `name: ${entry.name}`,
    `version: ${yamlQuote(entry.version)}`,
    `description: ${yamlQuote(entry.description)}`,
    `author: ${yamlQuote(AUTHOR)}`,
    `kind: standalone`,
  ].join('\n') + '\n';
}

// Generic Hermes entrypoint. Identical structure for every plugin (only the
// plugin name is templated into the docstrings) — matches the pilot github-dev
// adapter byte-for-byte so absorbing it into this generator is a no-op.
function buildInitPy(name) {
  const lines = [
    `"""Hermes Agent adapter for the ${name} plugin.`,
    ``,
    `The upstream plugin already ships skills for Claude Code and Codex. Hermes loads`,
    `plugin-provided skills through a small Python entrypoint, so this module simply`,
    'registers the existing SKILL.md files under the ``' + name + ':<skill>`` namespace.',
    `"""`,
    ``,
    `from __future__ import annotations`,
    ``,
    `from pathlib import Path`,
    `from typing import Any`,
    ``,
    `import yaml`,
    ``,
    ``,
    `def _frontmatter_from_skill(skill_md: Path) -> dict[str, Any]:`,
    `    """Decode the YAML frontmatter from a SKILL.md file."""`,
    `    text = skill_md.read_text(encoding="utf-8", errors="replace")`,
    `    if not text.startswith("---"):`,
    `        return {}`,
    `    try:`,
    `        _, frontmatter, _ = text.split("---", 2)`,
    `    except ValueError:`,
    `        return {}`,
    `    try:`,
    `        data = yaml.safe_load(frontmatter) or {}`,
    `    except yaml.YAMLError:`,
    `        return {}`,
    `    return data if isinstance(data, dict) else {}`,
    ``,
    ``,
    `def _description_from_skill(skill_md: Path) -> str:`,
    `    """Extract the decoded frontmatter description from a SKILL.md file."""`,
    `    description = _frontmatter_from_skill(skill_md).get("description", "")`,
    `    if description is None:`,
    `        return ""`,
    `    if isinstance(description, str):`,
    `        return description.strip()`,
    `    return str(description).strip()`,
    ``,
    ``,
    `def register(ctx) -> None:`,
    '    """Register ' + name + ' skills with Hermes.',
    ``,
    '    Hermes automatically qualifies these as ``' + name + ':<name>`` based on the',
    `    plugin manifest name, matching the existing Claude/Codex command namespace.`,
    `    """`,
    `    skills_root = Path(__file__).resolve().parent / "skills"`,
    `    for skill_md in sorted(skills_root.glob("*/SKILL.md")):`,
    `        ctx.register_skill(`,
    `            skill_md.parent.name,`,
    `            skill_md,`,
    `            _description_from_skill(skill_md),`,
    `        )`,
  ];
  return lines.join('\n') + '\n';
}

function compare(path, next) {
  if (!existsSync(path)) return { drift: true, reason: 'missing' };
  return readFileSync(path, 'utf8') === next ? { drift: false } : { drift: true, reason: 'changed' };
}

// An adapter file (plugin.yaml or __init__.py) under a plugin dir that is NOT in
// HERMES_ELIGIBLE is an orphan — left behind when a plugin leaves the allowlist
// or is removed from the marketplace. Flagged in --check, removed in write mode.
function findOrphanAdapters(expectedPaths) {
  if (!isDir(PLUGINS_DIR)) return [];
  const expected = new Set(expectedPaths);
  const orphans = [];
  for (const name of readdirSync(PLUGINS_DIR)) {
    for (const file of ['plugin.yaml', '__init__.py']) {
      const path = join(PLUGINS_DIR, name, file);
      if (isFile(path) && !expected.has(path)) orphans.push(path);
    }
  }
  return orphans;
}

function main() {
  const source = readJSON(SOURCE);
  const eligible = source.plugins.filter((p) => HERMES_ELIGIBLE.has(p.name));

  const outputs = [];
  for (const entry of eligible) {
    const pluginDir = join(PLUGINS_DIR, entry.name);
    outputs.push({ path: join(pluginDir, 'plugin.yaml'), content: buildPluginYaml(entry) });
    outputs.push({ path: join(pluginDir, '__init__.py'), content: buildInitPy(entry.name) });
  }

  const orphans = findOrphanAdapters(outputs.map((o) => o.path));

  if (MODE === 'check') {
    const drifted = [];
    for (const { path, content } of outputs) {
      const cmp = compare(path, content);
      if (cmp.drift) drifted.push({ path, reason: cmp.reason });
    }
    for (const path of orphans) drifted.push({ path, reason: 'orphan' });
    if (drifted.length === 0) {
      console.log(`up to date (${outputs.length} adapter files, ${eligible.length} plugins)`);
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
    console.log(`\n${outputs.length} adapter files, ${orphans.length} orphans (dry-run, no writes).`);
    return;
  }

  let created = 0, updated = 0, unchanged = 0;
  for (const { path, content } of outputs) {
    const cmp = compare(path, content);
    if (!cmp.drift) { unchanged++; continue; }
    writeFileSync(path, content);
    if (cmp.reason === 'missing') created++; else updated++;
  }
  let removed = 0;
  for (const path of orphans) {
    rmSync(path, { force: true });
    removed++;
  }
  console.log(`wrote ${outputs.length} adapter files: ${created} created, ${updated} updated, ${unchanged} unchanged, ${removed} orphans removed.`);
}

main();
