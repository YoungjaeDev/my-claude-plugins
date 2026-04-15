#!/usr/bin/env node
// codex-bridge — Sync OMC plugin skills to Codex ~/.agents/skills/
// Zero runtime dependencies. Node 18+.

import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const FRONTMATTER_RE = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/;

export const DEFAULT_RULES = [
  { from: '.omc/', to: '.omx/', mode: 'literal' },
  { from: 'CLAUDE.md', to: 'AGENTS.md', mode: 'literal' },
  { from: '/oh-my-claudecode:', to: '$', mode: 'literal' },
  { from: 'oh-my-claudecode', to: 'oh-my-codex', mode: 'literal' },
  { from: '~/.claude/', to: '~/.codex/', mode: 'literal' },
  { from: 'omc', to: 'omx', mode: 'word-boundary' },
  { from: 'OMC', to: 'OMX', mode: 'word-boundary' },
];

function escapeRegex(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export function applyTransforms(input, rules) {
  let out = input;
  for (const rule of rules) {
    if (rule.mode === 'literal') {
      out = out.split(rule.from).join(rule.to);
    } else if (rule.mode === 'word-boundary') {
      const re = new RegExp(`\\b${escapeRegex(rule.from)}\\b`, 'g');
      out = out.replace(re, rule.to);
    }
  }
  return out;
}

export function transformSkillContent(content, rules) {
  const match = FRONTMATTER_RE.exec(content);
  if (!match) {
    return applyTransforms(content, rules);
  }
  const [, raw, body] = match;
  return `---\n${raw}\n---\n${applyTransforms(body, rules)}`;
}

const TEXT_EXTENSIONS = new Set(['.md', '.yml', '.yaml', '.json', '.sh', '.mjs', '.js', '.py', '.ts']);
const BRIDGE_SOURCE_LINE_RE = /^bridge_source:\s*.*$/m;

export function injectBridgeSource(content, marker) {
  const match = FRONTMATTER_RE.exec(content);
  if (!match) {
    return `---\nbridge_source: ${marker}\n---\n${content}`;
  }
  const [, raw, body] = match;
  const newRaw = BRIDGE_SOURCE_LINE_RE.test(raw)
    ? raw.replace(BRIDGE_SOURCE_LINE_RE, `bridge_source: ${marker}`)
    : `${raw}\nbridge_source: ${marker}`;
  return `---\n${newRaw}\n---\n${body}`;
}

export async function syncOne(source, targetRoot, rules, options = {}) {
  const logger = options.logger ?? defaultLogger();
  const sourceContent = await fs.readFile(source.skillPath, 'utf-8');
  const parsed = parseFrontmatter(sourceContent);

  if (!parsed) {
    logger.warn(`[codex-bridge] ${source.pluginName}/${source.skillName}: source SKILL.md has no frontmatter, skipping`);
    return { status: 'skipped', reason: 'source-missing-frontmatter' };
  }

  const targetSkillDir = path.join(targetRoot, source.skillName);
  const targetSkillMd = path.join(targetSkillDir, 'SKILL.md');
  const marker = `${source.pluginName}/${source.skillName}`;

  try {
    const existing = await fs.readFile(targetSkillMd, 'utf-8');
    const existingParsed = parseFrontmatter(existing);
    const hasBridgeMarker = existingParsed && 'bridge_source' in existingParsed.fields;
    if (!hasBridgeMarker) {
      logger.warn(`[codex-bridge] skip ${targetSkillMd}: not managed by OMC (missing bridge_source marker). Inspect with 'omx doctor'.`);
      return { status: 'skipped', reason: 'non-managed-collision' };
    }
  } catch (err) {
    if (err.code !== 'ENOENT') throw err;
  }

  const transformed = transformSkillContent(sourceContent, rules);
  const withMarker = injectBridgeSource(transformed, marker);

  await fs.mkdir(targetRoot, { recursive: true });
  const stagingDir = await fs.mkdtemp(path.join(targetRoot, `.staging-${source.skillName}-`));

  try {
    await renderSkillTree(source.skillDir, stagingDir, rules, withMarker);
    await fs.rm(targetSkillDir, { recursive: true, force: true });
    await moveOrCopy(stagingDir, targetSkillDir);
  } catch (err) {
    await fs.rm(stagingDir, { recursive: true, force: true }).catch(() => {});
    throw err;
  }

  return { status: 'synced', path: targetSkillMd, bridgeSource: marker };
}

async function moveOrCopy(from, to) {
  try {
    await fs.rename(from, to);
  } catch (err) {
    if (err.code !== 'EXDEV') throw err;
    await fs.cp(from, to, { recursive: true, force: true });
    await fs.rm(from, { recursive: true, force: true });
  }
}

async function renderSkillTree(sourceDir, dstDir, rules, skillMdOverride) {
  const entries = await fs.readdir(sourceDir, { withFileTypes: true });
  await fs.mkdir(dstDir, { recursive: true });
  for (const entry of entries) {
    const srcPath = path.join(sourceDir, entry.name);
    const dstPath = path.join(dstDir, entry.name);
    if (entry.isDirectory()) {
      await renderSkillTree(srcPath, dstPath, rules, null);
    } else if (entry.isFile()) {
      if (entry.name === 'SKILL.md' && skillMdOverride != null) {
        await fs.writeFile(dstPath, skillMdOverride, 'utf-8');
      } else {
        await renderFile(srcPath, dstPath, rules);
      }
    }
  }
}

async function renderFile(srcPath, dstPath, rules) {
  const ext = path.extname(srcPath).toLowerCase();
  if (TEXT_EXTENSIONS.has(ext)) {
    const content = await fs.readFile(srcPath, 'utf-8');
    await fs.writeFile(dstPath, applyTransforms(content, rules), 'utf-8');
  } else {
    await fs.copyFile(srcPath, dstPath);
  }
  if (ext === '.sh' || ext === '.mjs' || ext === '.js' || ext === '.py') {
    try {
      const stat = await fs.stat(srcPath);
      await fs.chmod(dstPath, stat.mode);
    } catch { /* best-effort */ }
  }
}

function defaultLogger() {
  return {
    warn: (msg) => process.stderr.write(`${msg}\n`),
    info: (msg) => process.stderr.write(`${msg}\n`),
  };
}

export const DEFAULT_CONFIG = {
  target: {
    scope: 'user',
    agentsHome: null,
  },
  collisionFallbackPrefix: 'omc-',
  exclude: [],
  transform: {
    bodyOnly: true,
    rules: DEFAULT_RULES,
    textExtensions: [...TEXT_EXTENSIONS],
  },
};

export async function loadConfig(configPath) {
  if (!configPath) return cloneConfig(DEFAULT_CONFIG);
  let raw;
  try {
    raw = await fs.readFile(configPath, 'utf-8');
  } catch (err) {
    if (err.code === 'ENOENT') return cloneConfig(DEFAULT_CONFIG);
    throw err;
  }
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (err) {
    throw new Error(`Failed to parse config at ${configPath}: ${err.message}`);
  }
  return mergeConfig(DEFAULT_CONFIG, parsed);
}

function cloneConfig(cfg) {
  return JSON.parse(JSON.stringify(cfg));
}

function mergeConfig(base, override) {
  const out = cloneConfig(base);
  if (override.target && typeof override.target === 'object') {
    out.target = { ...out.target, ...override.target };
  }
  if (typeof override.collisionFallbackPrefix === 'string') {
    out.collisionFallbackPrefix = override.collisionFallbackPrefix;
  }
  if (Array.isArray(override.exclude)) {
    out.exclude = [...override.exclude];
  }
  if (override.transform && typeof override.transform === 'object') {
    if (typeof override.transform.bodyOnly === 'boolean') out.transform.bodyOnly = override.transform.bodyOnly;
    if (Array.isArray(override.transform.rules)) out.transform.rules = override.transform.rules.map(r => ({ ...r }));
    if (Array.isArray(override.transform.textExtensions)) out.transform.textExtensions = [...override.transform.textExtensions];
  }
  return out;
}

export function isExcluded(relPath, patterns) {
  if (!Array.isArray(patterns) || patterns.length === 0) return false;
  return patterns.some(pattern => globToRegex(pattern).test(relPath));
}

function globToRegex(pattern) {
  const DOUBLESTAR = '__CODEX_BRIDGE_DOUBLESTAR__';
  const escaped = pattern
    .replace(/[.+^${}()|[\]\\]/g, '\\$&')
    .split('**').join(DOUBLESTAR)
    .split('*').join('[^/]*')
    .split(DOUBLESTAR).join('.*');
  return new RegExp(`^${escaped}$`);
}

const KNOWN_FLAGS = new Set([
  '--dry-run', '--verbose', '--no-prune', '--help', '-h',
  '--config', '--plugin', '--report',
]);

export function parseArgs(argv) {
  const out = {
    dryRun: false,
    verbose: false,
    noPrune: false,
    help: false,
    configPath: null,
    plugins: null,
    reportPath: null,
  };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!KNOWN_FLAGS.has(arg)) {
      throw new Error(`Unknown argument: ${arg}`);
    }
    switch (arg) {
      case '--dry-run': out.dryRun = true; break;
      case '--verbose': out.verbose = true; break;
      case '--no-prune': out.noPrune = true; break;
      case '--help':
      case '-h':
        out.help = true;
        break;
      case '--config':
        out.configPath = argv[++i];
        if (!out.configPath) throw new Error('--config requires a path');
        break;
      case '--plugin': {
        const value = argv[++i];
        if (!value) throw new Error('--plugin requires a comma-separated list');
        out.plugins = value.split(',').map(s => s.trim()).filter(Boolean);
        break;
      }
      case '--report':
        out.reportPath = argv[++i];
        if (!out.reportPath) throw new Error('--report requires a path');
        break;
    }
  }
  return out;
}

export async function syncAll(options) {
  const {
    pluginsDir,
    targetDir,
    config,
    dryRun = false,
    pluginFilter = null,
    prune = true,
    logger = defaultLogger(),
  } = options;

  const allSkills = await discoverSkills(pluginsDir);
  const pluginsRoot = path.dirname(pluginsDir);

  const filtered = allSkills.filter((skill) => {
    if (pluginFilter && !pluginFilter.includes(skill.pluginName)) return false;
    const rel = path.relative(pluginsRoot, skill.skillDir).split(path.sep).join('/');
    if (isExcluded(rel, config.exclude)) return false;
    if (isExcluded(`${rel}/SKILL.md`, config.exclude)) return false;
    return true;
  });

  const report = {
    dryRun,
    targetDir,
    discovered: allSkills.length,
    considered: filtered.length,
    synced: [],
    skipped: [],
    removed: [],
    errors: [],
  };

  const validSources = new Set();
  for (const skill of filtered) {
    const marker = `${skill.pluginName}/${skill.skillName}`;
    validSources.add(marker);

    if (dryRun) {
      logger.info(`[dry-run] would sync ${marker}`);
      report.synced.push({ status: 'dry-run', bridgeSource: marker, skillName: skill.skillName });
      continue;
    }

    try {
      const result = await syncOne(skill, targetDir, config.transform.rules, { logger });
      if (result.status === 'synced') {
        logger.info(`[codex-bridge] synced ${marker} → ${result.path}`);
        report.synced.push(result);
      } else {
        report.skipped.push({ ...result, skillName: skill.skillName, bridgeSource: marker });
      }
    } catch (err) {
      logger.warn(`[codex-bridge] error syncing ${marker}: ${err.message}`);
      report.errors.push({ skillName: skill.skillName, bridgeSource: marker, error: err.message });
    }
  }

  if (prune && !dryRun) {
    const pruneResult = await pruneOrphans(targetDir, validSources);
    report.removed = pruneResult.removed;
    for (const r of pruneResult.removed) {
      logger.info(`[codex-bridge] pruned orphan ${r.skillName} (was ${r.bridgeSource})`);
    }
  } else if (prune && dryRun) {
    const existingEntries = await fs.readdir(targetDir, { withFileTypes: true }).catch((err) => {
      if (err.code === 'ENOENT') return [];
      throw err;
    });
    for (const entry of existingEntries) {
      if (!entry.isDirectory() || entry.name.startsWith('.staging-')) continue;
      try {
        const content = await fs.readFile(path.join(targetDir, entry.name, 'SKILL.md'), 'utf-8');
        const parsed = parseFrontmatter(content);
        if (parsed && 'bridge_source' in parsed.fields && !validSources.has(parsed.fields.bridge_source)) {
          report.removed.push({ skillName: entry.name, bridgeSource: parsed.fields.bridge_source, dryRun: true });
          logger.info(`[dry-run] would prune ${entry.name} (orphan ${parsed.fields.bridge_source})`);
        }
      } catch { /* skip */ }
    }
  }

  return report;
}

export async function main(argv) {
  let args;
  try {
    args = parseArgs(argv);
  } catch (err) {
    process.stderr.write(`${err.message}\n\n`);
    printHelp();
    return 2;
  }

  if (args.help) {
    printHelp();
    return 0;
  }

  const pluginRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const pluginsDir = path.resolve(pluginRoot, '..');
  const configPath = args.configPath ?? path.join(pluginRoot, 'codex-bridge.config.json');

  let config;
  try {
    config = await loadConfig(configPath);
  } catch (err) {
    process.stderr.write(`[codex-bridge] ${err.message}\n`);
    return 2;
  }

  const targetDir = config.target.agentsHome
    ?? path.join(os.homedir(), '.agents', 'skills');

  const logger = args.verbose ? defaultLogger() : quietLogger();

  const report = await syncAll({
    pluginsDir,
    targetDir,
    config,
    dryRun: args.dryRun,
    pluginFilter: args.plugins,
    prune: !args.noPrune,
    logger,
  });

  if (args.reportPath) {
    await fs.writeFile(args.reportPath, JSON.stringify(report, null, 2), 'utf-8');
  }

  printSummary(report);

  if (report.errors.length > 0) return 1;
  return 0;
}

function quietLogger() {
  return { warn: (msg) => process.stderr.write(`${msg}\n`), info: () => {} };
}

function printSummary(report) {
  const lines = [
    `[codex-bridge] target: ${report.targetDir}`,
    `  discovered: ${report.discovered}, considered: ${report.considered}`,
    `  synced: ${report.synced.length}, skipped: ${report.skipped.length}, removed: ${report.removed.length}, errors: ${report.errors.length}`,
  ];
  process.stderr.write(`${lines.join('\n')}\n`);
}

function printHelp() {
  const help = `Usage: node sync.mjs [options]

Options:
  --dry-run              Plan without writing files
  --verbose              Per-file logs
  --config <path>        Custom config path (default: codex-bridge.config.json)
  --plugin <list>        Comma-separated plugin filter (e.g. --plugin github-dev,core-config)
  --no-prune             Disable auto-prune of orphans
  --report <path>        Write JSON report to path
  -h, --help             Show this help

Exit codes:
  0  all skills processed successfully
  1  partial failures (some skills errored)
  2  fatal error (config parse failure, argument error)
`;
  process.stdout.write(help);
}

export async function pruneOrphans(targetDir, validSources) {
  const report = { removed: [], preserved: [] };

  let entries;
  try {
    entries = await fs.readdir(targetDir, { withFileTypes: true });
  } catch (err) {
    if (err.code === 'ENOENT') return report;
    throw err;
  }

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    if (entry.name.startsWith('.staging-')) continue;

    const skillMd = path.join(targetDir, entry.name, 'SKILL.md');
    let content;
    try {
      content = await fs.readFile(skillMd, 'utf-8');
    } catch (err) {
      if (err.code === 'ENOENT') {
        report.preserved.push({ skillName: entry.name, reason: 'no-skill-md' });
        continue;
      }
      throw err;
    }

    const parsed = parseFrontmatter(content);
    const hasMarker = parsed && 'bridge_source' in parsed.fields;
    if (!hasMarker) {
      report.preserved.push({ skillName: entry.name, reason: 'no-bridge-source' });
      continue;
    }

    const marker = parsed.fields.bridge_source;
    if (validSources.has(marker)) {
      report.preserved.push({ skillName: entry.name, reason: 'valid', bridgeSource: marker });
    } else {
      await fs.rm(path.join(targetDir, entry.name), { recursive: true, force: true });
      report.removed.push({ skillName: entry.name, bridgeSource: marker });
    }
  }

  return report;
}

export function parseFrontmatter(content) {
  const match = FRONTMATTER_RE.exec(content);
  if (!match) return null;

  const [, raw, body] = match;
  const fields = parseYamlKeyValues(raw);

  return {
    name: fields.name ?? null,
    description: fields.description ?? null,
    body,
    raw,
    fields,
  };
}

function parseYamlKeyValues(yamlText) {
  const out = {};
  let currentKey = null;
  for (const line of yamlText.split(/\r?\n/)) {
    if (!line.trim()) { currentKey = null; continue; }
    const kv = /^([A-Za-z_][\w.-]*)\s*:\s*(.*)$/.exec(line);
    if (kv) {
      currentKey = kv[1];
      out[currentKey] = stripYamlValue(kv[2]);
    } else if (currentKey && /^\s/.test(line)) {
      out[currentKey] = `${out[currentKey]} ${line.trim()}`.trim();
    } else if (currentKey) {
      out[currentKey] = `${out[currentKey]} ${line.trim()}`.trim();
    }
  }
  return out;
}

function stripYamlValue(value) {
  const trimmed = value.trim();
  if (trimmed.startsWith('"') && trimmed.endsWith('"') && trimmed.length >= 2) {
    return trimmed.slice(1, -1);
  }
  if (trimmed.startsWith("'") && trimmed.endsWith("'") && trimmed.length >= 2) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

export async function discoverSkills(pluginsDir) {
  const results = [];

  let pluginEntries;
  try {
    pluginEntries = await fs.readdir(pluginsDir, { withFileTypes: true });
  } catch (err) {
    if (err.code === 'ENOENT') return results;
    throw err;
  }

  for (const entry of pluginEntries) {
    if (!entry.isDirectory()) continue;
    const skillsRoot = path.join(pluginsDir, entry.name, 'skills');
    try {
      await walkForSkillMd(skillsRoot, entry.name, results);
    } catch (err) {
      if (err.code !== 'ENOENT') throw err;
    }
  }

  return results;
}

async function walkForSkillMd(dir, pluginName, out) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      await walkForSkillMd(full, pluginName, out);
    } else if (entry.isFile() && entry.name === 'SKILL.md') {
      const skillDir = path.dirname(full);
      out.push({
        pluginName,
        skillName: path.basename(skillDir),
        skillDir,
        skillPath: full,
      });
    }
  }
}

const isMainModule = (() => {
  try {
    return process.argv[1] === fileURLToPath(import.meta.url);
  } catch {
    return false;
  }
})();

if (isMainModule) {
  main(process.argv.slice(2)).then((code) => process.exit(code)).catch((err) => {
    process.stderr.write(`[codex-bridge] fatal: ${err.stack ?? err.message}\n`);
    process.exit(2);
  });
}
