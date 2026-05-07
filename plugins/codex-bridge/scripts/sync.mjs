#!/usr/bin/env node
// codex-bridge — Sync my-claude-plugins skills and commands to Codex ~/.agents/skills/
// Zero runtime dependencies. Node 18+.

import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const FRONTMATTER_RE = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/;

export const DEFAULT_RULES = [
  { from: 'CLAUDE.md', to: 'AGENTS.md', mode: 'literal' },
  { from: '.claude/', to: '.codex/', mode: 'literal' },
  {
    from: '(?<![:/.\\w])\\/([a-z][a-z0-9-]*):([a-z][a-z0-9-]*)',
    to: '$$$2',
    mode: 'regex',
    flags: 'g',
  },
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
    } else if (rule.mode === 'regex') {
      const re = new RegExp(rule.from, rule.flags ?? 'g');
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

export function normalizeFrontmatterDescription(content) {
  const match = FRONTMATTER_RE.exec(content);
  if (!match) return content;
  const [, raw, body] = match;

  const descRe = /^description:\s*(.*)$/m;
  const descMatch = descRe.exec(raw);
  if (!descMatch) return content;
  const descValue = descMatch[1].trim();
  if (!descValue.startsWith('|') && !descValue.startsWith('>')) return content;

  const parsed = parseFrontmatter(content);
  if (!parsed || !parsed.description) return content;
  const flat = flattenDescription(parsed.description);

  const lines = raw.split(/\r?\n/);
  const out = [];
  let skipContinuation = false;
  for (const line of lines) {
    if (descRe.test(line)) {
      out.push(`description: ${yamlQuote(flat)}`);
      skipContinuation = true;
      continue;
    }
    if (skipContinuation) {
      if (/^\s/.test(line) || line.trim() === '') continue;
      skipContinuation = false;
    }
    out.push(line);
  }
  return `---\n${out.join('\n')}\n---\n${body}`;
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
      logger.warn(`[codex-bridge] skip ${targetSkillMd}: not managed by codex-bridge (missing bridge_source marker).`);
      return { status: 'skipped', reason: 'non-managed-collision' };
    }
  } catch (err) {
    if (err.code !== 'ENOENT') throw err;
  }

  const transformed = transformSkillContent(sourceContent, rules);
  const normalized = normalizeFrontmatterDescription(transformed);
  const withMarker = injectBridgeSource(normalized, marker);

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
    agentsTomlHome: null,
  },
  collisionFallbackPrefix: 'bridge-',
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
  '--config', '--plugin', '--report', '--plugins-dir',
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
    pluginsDir: null,
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
      case '--plugins-dir': {
        const value = argv[++i];
        if (!value || value.startsWith('-')) {
          throw new Error('--plugins-dir requires a path');
        }
        out.pluginsDir = value;
        break;
      }
    }
  }
  return out;
}

export async function syncAll(options) {
  const {
    pluginsDir,
    targetDir,
    agentsTomlDir = null,
    config,
    dryRun = false,
    pluginFilter = null,
    prune = true,
    logger = defaultLogger(),
  } = options;

  const allSkills = await discoverSkills(pluginsDir);
  const allCommands = await discoverCommands(pluginsDir);
  const allAgents = await discoverAgents(pluginsDir);
  const pluginsRoot = path.dirname(pluginsDir);

  const warnings = [];
  if (allSkills.length === 0) {
    const msg = `[codex-bridge] discoverSkills returned 0 results from ${pluginsDir} — likely pluginsDir misresolution under Claude Code's versioned cache layout. Inspect with --dry-run --verbose, or pass --plugins-dir <path> to override.`;
    logger.warn(msg);
    warnings.push(msg);
  }

  const filtered = allSkills.filter((skill) => {
    if (pluginFilter && !pluginFilter.includes(skill.pluginName)) return false;
    const rel = path.relative(pluginsRoot, skill.skillDir).split(path.sep).join('/');
    if (isExcluded(rel, config.exclude)) return false;
    if (isExcluded(`${rel}/SKILL.md`, config.exclude)) return false;
    return true;
  });

  const filteredCommands = allCommands.filter((cmd) => {
    if (pluginFilter && !pluginFilter.includes(cmd.pluginName)) return false;
    const rel = path.relative(pluginsRoot, cmd.sourcePath).split(path.sep).join('/');
    if (isExcluded(rel, config.exclude)) return false;
    if (isExcluded(`plugins/${cmd.pluginName}/**`, config.exclude)) return false;
    return true;
  });

  const filteredAgents = allAgents.filter((ag) => {
    if (pluginFilter && !pluginFilter.includes(ag.pluginName)) return false;
    const rel = path.relative(pluginsRoot, ag.sourcePath).split(path.sep).join('/');
    if (isExcluded(rel, config.exclude)) return false;
    if (isExcluded(`plugins/${ag.pluginName}/**`, config.exclude)) return false;
    return true;
  });

  const nameToPlugins = new Map();
  for (const skill of filtered) {
    const bucket = nameToPlugins.get(skill.skillName) ?? [];
    bucket.push(skill.pluginName);
    nameToPlugins.set(skill.skillName, bucket);
  }
  const collisions = [];
  for (const [skillName, plugins] of nameToPlugins) {
    if (plugins.length > 1) {
      logger.warn(`[codex-bridge] collision: skill '${skillName}' in plugins [${plugins.join(', ')}] — last-wins after deterministic sort: ${plugins[plugins.length - 1]}`);
      collisions.push({ skillName, plugins });
    }
  }

  const report = {
    dryRun,
    targetDir,
    agentsTomlDir,
    pluginsDir,
    discovered: allSkills.length,
    discoveredCommands: allCommands.length,
    discoveredAgents: allAgents.length,
    considered: filtered.length,
    consideredCommands: filteredCommands.length,
    consideredAgents: filteredAgents.length,
    collisions,
    synced: [],
    skipped: [],
    removed: [],
    removedAgents: [],
    errors: [],
    warnings,
  };

  const validSources = new Set();
  for (const skill of filtered) {
    const marker = `${skill.pluginName}/${skill.skillName}`;
    validSources.add(marker);

    if (dryRun) {
      logger.info(`[dry-run] would sync skill ${marker}`);
      report.synced.push({ status: 'dry-run', bridgeSource: marker, skillName: skill.skillName });
      continue;
    }

    try {
      const result = await syncOne(skill, targetDir, config.transform.rules, { logger });
      if (result.status === 'synced') {
        logger.info(`[codex-bridge] synced skill ${marker} → ${result.path}`);
        report.synced.push(result);
      } else {
        report.skipped.push({ ...result, skillName: skill.skillName, bridgeSource: marker });
      }
    } catch (err) {
      logger.warn(`[codex-bridge] error syncing ${marker}: ${err.message}`);
      report.errors.push({ skillName: skill.skillName, bridgeSource: marker, error: err.message });
    }
  }

  for (const cmd of filteredCommands) {
    const marker = `${cmd.pluginName}/commands/${cmd.commandName}`;
    validSources.add(marker);

    if (dryRun) {
      logger.info(`[dry-run] would sync command ${marker} → ${cmd.targetSkillName}`);
      report.synced.push({ status: 'dry-run', bridgeSource: marker, skillName: cmd.targetSkillName });
      continue;
    }

    try {
      const result = await syncCommand(cmd, targetDir, config.transform.rules, { logger });
      if (result.status === 'synced') {
        logger.info(`[codex-bridge] synced command ${marker} → ${result.path}`);
        report.synced.push(result);
      } else {
        report.skipped.push({ ...result, skillName: cmd.targetSkillName, bridgeSource: marker });
      }
    } catch (err) {
      logger.warn(`[codex-bridge] error syncing ${marker}: ${err.message}`);
      report.errors.push({ skillName: cmd.targetSkillName, bridgeSource: marker, error: err.message });
    }
  }

  const validAgentSources = new Set();
  for (const ag of filteredAgents) {
    const marker = `${ag.pluginName}/agents/${ag.agentName}`;
    validAgentSources.add(marker);

    if (!agentsTomlDir) continue;

    if (dryRun) {
      logger.info(`[dry-run] would sync agent ${marker} → ${ag.targetTomlName}.toml`);
      report.synced.push({ status: 'dry-run', bridgeSource: marker, tomlName: ag.targetTomlName });
      continue;
    }

    try {
      const result = await syncAgent(ag, agentsTomlDir, config.transform.rules, { logger });
      if (result.status === 'synced') {
        logger.info(`[codex-bridge] synced agent ${marker} → ${result.path}`);
        report.synced.push(result);
      } else {
        report.skipped.push({ ...result, tomlName: ag.targetTomlName, bridgeSource: marker });
      }
    } catch (err) {
      logger.warn(`[codex-bridge] error syncing ${marker}: ${err.message}`);
      report.errors.push({ tomlName: ag.targetTomlName, bridgeSource: marker, error: err.message });
    }
  }

  if (prune && !dryRun) {
    if (validSources.size === 0) {
      const msg = `[codex-bridge] prune skipped: 0 valid sources discovered (likely pluginsDir misresolution or over-restrictive --plugin filter). Inspect with --dry-run --verbose.`;
      logger.warn(msg);
      report.warnings.push(msg);
    } else {
      const pruneResult = await pruneOrphans(targetDir, validSources);
      report.removed = pruneResult.removed;
      for (const r of pruneResult.removed) {
        logger.info(`[codex-bridge] pruned orphan ${r.skillName} (was ${r.bridgeSource})`);
      }
    }
    if (agentsTomlDir) {
      if (pluginFilter) {
        const msg = `[codex-bridge] agent prune skipped: --plugin filter is active; rerun with --no-prune or full sync separately.`;
        logger.warn(msg);
        report.warnings.push(msg);
      } else if (filteredAgents.length === 0 && allAgents.length === 0) {
        // No agents discovered at all; mirror the same defensive guard as skills/commands.
        const msg = `[codex-bridge] agent prune skipped: 0 agents discovered. Inspect with --dry-run --verbose.`;
        logger.warn(msg);
        report.warnings.push(msg);
      } else {
        const agentPruneResult = await pruneAgentOrphans(agentsTomlDir, validAgentSources);
        report.removedAgents = agentPruneResult.removed;
        for (const r of agentPruneResult.removed) {
          logger.info(`[codex-bridge] pruned orphan agent ${r.tomlName} (was ${r.bridgeSource})`);
        }
      }
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
    if (agentsTomlDir) {
      const tomlEntries = await fs.readdir(agentsTomlDir, { withFileTypes: true }).catch((err) => {
        if (err.code === 'ENOENT') return [];
        throw err;
      });
      for (const entry of tomlEntries) {
        if (!entry.isFile() || !entry.name.endsWith('.toml') || entry.name.startsWith('.staging-')) continue;
        try {
          const content = await fs.readFile(path.join(agentsTomlDir, entry.name), 'utf-8');
          const marker = readTomlBridgeSource(content);
          if (marker && !validAgentSources.has(marker)) {
            report.removedAgents.push({ tomlName: entry.name, bridgeSource: marker, dryRun: true });
            logger.info(`[dry-run] would prune agent ${entry.name} (orphan ${marker})`);
          }
        } catch { /* skip */ }
      }
    }
  }

  return report;
}

export function isVersionedCacheChild(name) {
  return /^\d+\.\d+\.\d+(?:[-+].*)?$/.test(name);
}

export async function resolvePluginsDir(scriptPath, override) {
  if (override) return path.resolve(override);
  const candidateA = path.resolve(path.dirname(scriptPath), '..', '..');
  const entries = await fs.readdir(candidateA, { withFileTypes: true }).catch(() => []);
  const dirs = entries.filter(e => e.isDirectory()).map(e => e.name);
  if (dirs.length > 0 && dirs.every(isVersionedCacheChild)) {
    return path.resolve(candidateA, '..');
  }
  return candidateA;
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

  const scriptPath = fileURLToPath(import.meta.url);
  const pluginRoot = path.resolve(path.dirname(scriptPath), '..');
  const pluginsDir = await resolvePluginsDir(scriptPath, args.pluginsDir);
  const configPath = args.configPath ?? path.join(pluginRoot, 'codex-bridge.config.json');

  if (args.verbose) {
    let layout;
    if (args.pluginsDir) {
      layout = 'overridden via --plugins-dir';
    } else {
      const monorepoRoot = path.resolve(path.dirname(scriptPath), '..', '..');
      layout = pluginsDir === monorepoRoot
        ? 'auto-detected (monorepo)'
        : 'auto-detected (versioned-cache fallback)';
    }
    process.stderr.write(`[codex-bridge] resolved pluginsDir: ${pluginsDir} (${layout})\n`);
  }

  let config;
  try {
    config = await loadConfig(configPath);
  } catch (err) {
    process.stderr.write(`[codex-bridge] ${err.message}\n`);
    return 2;
  }

  const targetDir = config.target.agentsHome
    ?? path.join(os.homedir(), '.agents', 'skills');
  const agentsTomlDir = config.target.agentsTomlHome
    ?? path.join(os.homedir(), '.codex', 'agents');

  const logger = args.verbose ? defaultLogger() : quietLogger();

  const report = await syncAll({
    pluginsDir,
    targetDir,
    agentsTomlDir,
    config,
    dryRun: args.dryRun,
    pluginFilter: args.plugins,
    prune: !args.noPrune,
    logger,
  });

  if (args.verbose) {
    const pluginEntries = await fs.readdir(pluginsDir, { withFileTypes: true }).catch(() => []);
    const pluginCount = pluginEntries.filter(e => e.isDirectory()).length;
    process.stderr.write(`[codex-bridge] discovered ${pluginCount} plugins, ${report.discovered} skills, ${report.discoveredCommands ?? 0} commands, ${report.discoveredAgents ?? 0} agents\n`);
  }

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
  ];
  if (report.agentsTomlDir) {
    lines.push(`[codex-bridge] agents toml target: ${report.agentsTomlDir}`);
  }
  lines.push(`  skills: discovered ${report.discovered}, considered ${report.considered}`);
  lines.push(`  commands: discovered ${report.discoveredCommands ?? 0}, considered ${report.consideredCommands ?? 0}`);
  lines.push(`  agents: discovered ${report.discoveredAgents ?? 0}, considered ${report.consideredAgents ?? 0}`);
  lines.push(`  synced: ${report.synced.length}, skipped: ${report.skipped.length}, removed: ${report.removed.length}, removedAgents: ${report.removedAgents?.length ?? 0}, errors: ${report.errors.length}`);
  process.stderr.write(`${lines.join('\n')}\n`);
}

function printHelp() {
  const help = `Usage: node sync.mjs [options]

Options:
  --dry-run              Plan without writing files
  --verbose              Per-file logs + diagnostic (resolved pluginsDir, layout, counts)
  --config <path>        Custom config path (default: codex-bridge.config.json)
  --plugin <list>        Comma-separated plugin filter (e.g. --plugin github-dev,core-config)
  --plugins-dir <path>   Override plugins directory (skips auto-detect; use when running
                         from an unusual layout, e.g. Claude Code's versioned cache)
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

export function compareSemver(a, b) {
  const split = (v) => {
    const noBuild = v.split('+', 1)[0];
    const dashIdx = noBuild.indexOf('-');
    const main = dashIdx === -1 ? noBuild : noBuild.slice(0, dashIdx);
    const pre = dashIdx === -1 ? null : noBuild.slice(dashIdx + 1);
    const nums = main.split('.').map(n => parseInt(n, 10) || 0);
    return { nums, pre };
  };
  const A = split(a);
  const B = split(b);
  for (let i = 0; i < 3; i++) {
    const an = A.nums[i] ?? 0;
    const bn = B.nums[i] ?? 0;
    if (an !== bn) return an - bn;
  }
  // Numeric core equal — apply semver pre-release rule:
  // a version WITHOUT pre-release is greater than one WITH pre-release.
  if (A.pre === null && B.pre === null) return 0;
  if (A.pre === null) return 1;
  if (B.pre === null) return -1;
  // Both have pre-release: compare dot-separated identifiers per semver spec.
  const aParts = A.pre.split('.');
  const bParts = B.pre.split('.');
  const max = Math.max(aParts.length, bParts.length);
  for (let i = 0; i < max; i++) {
    const ai = aParts[i];
    const bi = bParts[i];
    if (ai === undefined) return -1;
    if (bi === undefined) return 1;
    const aNum = /^\d+$/.test(ai);
    const bNum = /^\d+$/.test(bi);
    if (aNum && bNum) {
      const diff = parseInt(ai, 10) - parseInt(bi, 10);
      if (diff !== 0) return diff;
    } else if (aNum) {
      return -1; // numeric identifiers sort before alphanumeric
    } else if (bNum) {
      return 1;
    } else {
      if (ai < bi) return -1;
      if (ai > bi) return 1;
    }
  }
  return 0;
}

// Per-plugin layout resolver: returns the directory that holds `skills/` and
// `commands/` for this plugin. Handles two layouts:
//
//   1. Monorepo / source checkout — `<plugin>/.claude-plugin/`, `<plugin>/skills/` …
//      sit directly under `<plugin>/`. Returns `<plugin>` itself.
//   2. Claude Code cache — `<plugin>/<semver>/.claude-plugin/`, `<plugin>/<semver>/skills/`
//      sit under a version subdirectory. Returns `<plugin>/<latest-semver>`.
//
// The presence of `.claude-plugin/` directly under `<plugin>` is the canonical
// monorepo signal. If absent and every direct child is semver-named, treat as
// cache layout and pick the highest semver. Otherwise return `<plugin>` as-is
// and let the downstream walker swallow ENOENT.
export async function resolvePluginContentDir(pluginDir) {
  let entries;
  try {
    entries = await fs.readdir(pluginDir, { withFileTypes: true });
  } catch (err) {
    if (err.code === 'ENOENT') return null;
    throw err;
  }
  const dirNames = entries.filter(e => e.isDirectory()).map(e => e.name);
  if (dirNames.includes('.claude-plugin')) return pluginDir;
  const semverDirs = dirNames.filter(isVersionedCacheChild);
  if (semverDirs.length > 0 && semverDirs.length === dirNames.length) {
    semverDirs.sort(compareSemver);
    return path.join(pluginDir, semverDirs[semverDirs.length - 1]);
  }
  return pluginDir;
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
    const contentRoot = await resolvePluginContentDir(path.join(pluginsDir, entry.name));
    if (!contentRoot) continue;
    const skillsRoot = path.join(contentRoot, 'skills');
    try {
      await walkForSkillMd(skillsRoot, entry.name, results);
    } catch (err) {
      if (err.code !== 'ENOENT') throw err;
    }
  }

  results.sort((a, b) => {
    if (a.pluginName !== b.pluginName) return a.pluginName < b.pluginName ? -1 : 1;
    if (a.skillName !== b.skillName) return a.skillName < b.skillName ? -1 : 1;
    return 0;
  });

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

export async function discoverCommands(pluginsDir) {
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
    const contentRoot = await resolvePluginContentDir(path.join(pluginsDir, entry.name));
    if (!contentRoot) continue;
    const commandsDir = path.join(contentRoot, 'commands');
    let files;
    try {
      files = await fs.readdir(commandsDir, { withFileTypes: true });
    } catch (err) {
      if (err.code === 'ENOENT') continue;
      throw err;
    }
    for (const f of files) {
      if (!f.isFile() || !f.name.endsWith('.md')) continue;
      const commandName = f.name.slice(0, -3);
      results.push({
        pluginName: entry.name,
        commandName,
        sourcePath: path.join(commandsDir, f.name),
        targetSkillName: `${entry.name}-${commandName}`,
      });
    }
  }

  results.sort((a, b) => {
    if (a.pluginName !== b.pluginName) return a.pluginName < b.pluginName ? -1 : 1;
    if (a.commandName !== b.commandName) return a.commandName < b.commandName ? -1 : 1;
    return 0;
  });

  return results;
}

export async function discoverAgents(pluginsDir) {
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
    const contentRoot = await resolvePluginContentDir(path.join(pluginsDir, entry.name));
    if (!contentRoot) continue;
    const agentsDir = path.join(contentRoot, 'agents');
    let files;
    try {
      files = await fs.readdir(agentsDir, { withFileTypes: true });
    } catch (err) {
      if (err.code === 'ENOENT') continue;
      throw err;
    }
    for (const f of files) {
      if (!f.isFile() || !f.name.endsWith('.md')) continue;
      const agentName = f.name.slice(0, -3);
      results.push({
        pluginName: entry.name,
        agentName,
        sourcePath: path.join(agentsDir, f.name),
        targetTomlName: `${entry.name}-${agentName}`,
      });
    }
  }

  results.sort((a, b) => {
    if (a.pluginName !== b.pluginName) return a.pluginName < b.pluginName ? -1 : 1;
    if (a.agentName !== b.agentName) return a.agentName < b.agentName ? -1 : 1;
    return 0;
  });

  return results;
}

function tomlBasicQuote(text) {
  return `"${String(text).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

function escapeTomlMultilineBody(body) {
  // TOML basic multi-line strings (""" ... """):
  // - backslashes must be doubled (\\)
  // - any literal """ would terminate the string; emit \""" to get a literal triple-quote
  const withDoubledBackslashes = body.replace(/\\/g, '\\\\');
  return withDoubledBackslashes.replace(/"""/g, '\\"""');
}

export function agentToCodexToml(sourceContent, pluginName, agentName, rules) {
  const fmMatch = FRONTMATTER_RE.exec(sourceContent);
  let parsed = null;
  let body = sourceContent;

  if (fmMatch) {
    parsed = parseFrontmatter(sourceContent);
    if (parsed) body = parsed.body;
  }

  const description = parsed && parsed.description
    ? flattenDescription(parsed.description)
    : `${agentName} agent from ${pluginName} plugin.`;

  const targetName = `${pluginName}-${agentName}`;
  const marker = `${pluginName}/agents/${agentName}`;

  const transformedBody = applyTransforms(body, rules);
  const escaped = escapeTomlMultilineBody(transformedBody);
  // Strip a single leading newline from body (keeps things tidy; the TOML
  // multi-line opener swallows the immediate newline after """ anyway).
  const trimmedBody = escaped.startsWith('\n') ? escaped.slice(1) : escaped;

  const lines = [`# bridge_source = ${tomlBasicQuote(marker)}`];
  if (parsed && parsed.fields) {
    if (parsed.fields.model) lines.push(`# original-model = ${tomlBasicQuote(parsed.fields.model)}`);
    if (parsed.fields.skills) lines.push(`# original-skills = ${tomlBasicQuote(parsed.fields.skills)}`);
    if (parsed.fields.tools) lines.push(`# original-tools = ${tomlBasicQuote(parsed.fields.tools)}`);
  }
  lines.push(`name = ${tomlBasicQuote(targetName)}`);
  lines.push(`description = ${tomlBasicQuote(description)}`);
  lines.push('developer_instructions = """');
  lines.push(trimmedBody.replace(/\n+$/, ''));
  lines.push('"""');
  lines.push('');

  return lines.join('\n');
}

const BRIDGE_SOURCE_COMMENT_RE = /^#\s*bridge_source\s*=\s*"([^"\r\n]*)"\s*(?:\r?\n|$)/;

export function tomlHasBridgeSource(content) {
  return BRIDGE_SOURCE_COMMENT_RE.test(content);
}

export function readTomlBridgeSource(content) {
  const m = BRIDGE_SOURCE_COMMENT_RE.exec(content);
  return m ? m[1] : null;
}

export async function syncAgent(agent, agentsTomlDir, rules, options = {}) {
  const logger = options.logger ?? defaultLogger();
  const sourceContent = await fs.readFile(agent.sourcePath, 'utf-8');

  const tomlName = agent.targetTomlName ?? `${agent.pluginName}-${agent.agentName}`;
  const tomlPath = path.join(agentsTomlDir, `${tomlName}.toml`);
  const marker = `${agent.pluginName}/agents/${agent.agentName}`;

  try {
    const existing = await fs.readFile(tomlPath, 'utf-8');
    if (!tomlHasBridgeSource(existing)) {
      logger.warn(`[codex-bridge] skip ${tomlPath}: not managed by codex-bridge (missing # bridge_source marker).`);
      return { status: 'skipped', reason: 'non-managed-collision' };
    }
  } catch (err) {
    if (err.code !== 'ENOENT') throw err;
  }

  const tomlContent = agentToCodexToml(sourceContent, agent.pluginName, agent.agentName, rules);

  await fs.mkdir(agentsTomlDir, { recursive: true });
  const stagingPath = path.join(agentsTomlDir, `.staging-${tomlName}-${process.pid}-${Date.now()}.toml`);
  try {
    await fs.writeFile(stagingPath, tomlContent, 'utf-8');
    await moveOrCopy(stagingPath, tomlPath);
  } catch (err) {
    await fs.rm(stagingPath, { force: true }).catch(() => {});
    throw err;
  }

  return { status: 'synced', path: tomlPath, bridgeSource: marker };
}

export async function pruneAgentOrphans(agentsTomlDir, validAgentSources) {
  const report = { removed: [], preserved: [] };

  let entries;
  try {
    entries = await fs.readdir(agentsTomlDir, { withFileTypes: true });
  } catch (err) {
    if (err.code === 'ENOENT') return report;
    throw err;
  }

  for (const entry of entries) {
    if (!entry.isFile() || !entry.name.endsWith('.toml')) continue;
    if (entry.name.startsWith('.staging-')) continue;

    const fullPath = path.join(agentsTomlDir, entry.name);
    let content;
    try {
      content = await fs.readFile(fullPath, 'utf-8');
    } catch (err) {
      if (err.code === 'ENOENT') continue;
      throw err;
    }

    const marker = readTomlBridgeSource(content);
    if (!marker) {
      report.preserved.push({ tomlName: entry.name, reason: 'no-bridge-source' });
      continue;
    }

    if (validAgentSources.has(marker)) {
      report.preserved.push({ tomlName: entry.name, reason: 'valid', bridgeSource: marker });
    } else {
      await fs.rm(fullPath, { force: true });
      report.removed.push({ tomlName: entry.name, bridgeSource: marker });
    }
  }

  return report;
}

export function commandToSkillContent(sourceContent, pluginName, commandName) {
  const fmMatch = FRONTMATTER_RE.exec(sourceContent);
  let origDescription = null;
  let body = sourceContent;

  if (fmMatch) {
    const parsed = parseFrontmatter(sourceContent);
    if (parsed) {
      origDescription = parsed.description;
      body = parsed.body;
    }
  }

  const description = origDescription
    ? flattenDescription(origDescription)
    : `Run ${commandName} command from ${pluginName} plugin.`;

  const targetName = `${pluginName}-${commandName}`;
  const marker = `${pluginName}/commands/${commandName}`;

  return [
    '---',
    `name: ${targetName}`,
    `description: ${yamlQuote(description)}`,
    `bridge_source: ${marker}`,
    '---',
    body.startsWith('\n') ? body.slice(1) : body,
  ].join('\n');
}

function flattenDescription(text) {
  return String(text)
    .replace(/^[|>][-+0-9]*\s*/, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function yamlQuote(text) {
  return `"${String(text).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

export async function syncCommand(cmd, targetRoot, rules, options = {}) {
  const logger = options.logger ?? defaultLogger();
  const sourceContent = await fs.readFile(cmd.sourcePath, 'utf-8');

  const targetSkillName = cmd.targetSkillName ?? `${cmd.pluginName}-${cmd.commandName}`;
  const targetSkillDir = path.join(targetRoot, targetSkillName);
  const targetSkillMd = path.join(targetSkillDir, 'SKILL.md');
  const marker = `${cmd.pluginName}/commands/${cmd.commandName}`;

  try {
    const existing = await fs.readFile(targetSkillMd, 'utf-8');
    const existingParsed = parseFrontmatter(existing);
    const hasBridgeMarker = existingParsed && 'bridge_source' in existingParsed.fields;
    if (!hasBridgeMarker) {
      logger.warn(`[codex-bridge] skip ${targetSkillMd}: not managed by codex-bridge (missing bridge_source marker).`);
      return { status: 'skipped', reason: 'non-managed-collision' };
    }
  } catch (err) {
    if (err.code !== 'ENOENT') throw err;
  }

  const synthesized = commandToSkillContent(sourceContent, cmd.pluginName, cmd.commandName);
  const transformed = transformSkillContent(synthesized, rules);

  await fs.mkdir(targetRoot, { recursive: true });
  const stagingDir = await fs.mkdtemp(path.join(targetRoot, `.staging-${targetSkillName}-`));

  try {
    await fs.writeFile(path.join(stagingDir, 'SKILL.md'), transformed, 'utf-8');
    await fs.rm(targetSkillDir, { recursive: true, force: true });
    await moveOrCopy(stagingDir, targetSkillDir);
  } catch (err) {
    await fs.rm(stagingDir, { recursive: true, force: true }).catch(() => {});
    throw err;
  }

  return { status: 'synced', path: targetSkillMd, bridgeSource: marker };
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
