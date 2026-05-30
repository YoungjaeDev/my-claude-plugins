import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';

import {
  applyTransforms,
  transformSkillContent,
  generatePluginJson,
  generateMarketplaceJson,
  buildPluginAgentsDoc,
  emitPlugins,
  parseArgs,
  loadConfig,
  DEFAULT_RULES,
  DEFAULT_CONFIG,
} from '../scripts/sync.mjs';

// ---------------------------------------------------------------------------
// transform scope (external-only)
// ---------------------------------------------------------------------------

test('applyTransforms: scope external-only preserves plugin-local ref in plugin mode', () => {
  const out = applyTransforms('see /llm-wiki:query-wiki here', DEFAULT_RULES, {
    emitMode: 'plugin',
    currentPlugin: 'llm-wiki',
  });
  assert.equal(out, 'see /llm-wiki:query-wiki here');
});

test('applyTransforms: scope external-only flattens other-plugin ref in plugin mode', () => {
  const out = applyTransforms('chains /github-dev:post-merge after', DEFAULT_RULES, {
    emitMode: 'plugin',
    currentPlugin: 'llm-wiki',
  });
  assert.equal(out, 'chains $post-merge after');
});

test('applyTransforms: mixed refs — local preserved, external flattened', () => {
  const out = applyTransforms('/llm-wiki:ingest-finding then /github-dev:cr-fix', DEFAULT_RULES, {
    emitMode: 'plugin',
    currentPlugin: 'llm-wiki',
  });
  assert.equal(out, '/llm-wiki:ingest-finding then $cr-fix');
});

test('applyTransforms: user mode (default) flattens every ref (backward compat)', () => {
  const out = applyTransforms('run /llm-wiki:query-wiki now', DEFAULT_RULES, {
    emitMode: 'user',
    currentPlugin: 'llm-wiki',
  });
  assert.equal(out, 'run $query-wiki now');
});

test('applyTransforms: no context behaves like user mode', () => {
  assert.equal(
    applyTransforms('run /llm-wiki:query-wiki now', DEFAULT_RULES),
    'run $query-wiki now',
  );
});

test('transformSkillContent: scope threads through body only', () => {
  const src = [
    '---',
    'name: ingest-finding',
    'description: mentions /llm-wiki:query-wiki',
    '---',
    'local /llm-wiki:query-wiki and external /github-dev:post-merge',
  ].join('\n');
  const out = transformSkillContent(src, DEFAULT_RULES, { emitMode: 'plugin', currentPlugin: 'llm-wiki' });
  // frontmatter untouched
  assert.match(out, /description: mentions \/llm-wiki:query-wiki/);
  // body: local preserved, external flattened
  assert.match(out, /local \/llm-wiki:query-wiki and external \$post-merge/);
});

// ---------------------------------------------------------------------------
// generatePluginJson
// ---------------------------------------------------------------------------

test('generatePluginJson: maps name/version/description, sets skills', () => {
  const out = generatePluginJson('council', {
    name: 'council',
    version: '1.1.0',
    description: 'LLM Council',
    skills: ['./skills/council-setup'],
    commands: ['./commands/council.md'],
  });
  assert.deepEqual(out, {
    name: 'council',
    version: '1.1.0',
    description: 'LLM Council',
    skills: './skills/',
  });
});

test('generatePluginJson: falls back when source fields missing', () => {
  const out = generatePluginJson('foo', {});
  assert.equal(out.name, 'foo');
  assert.equal(out.version, '0.0.0');
  assert.match(out.description, /foo plugin/);
  assert.equal(out.skills, './skills/');
});

// ---------------------------------------------------------------------------
// generateMarketplaceJson
// ---------------------------------------------------------------------------

test('generateMarketplaceJson: source uses {source:"local", path} repo-root relative', () => {
  const mp = generateMarketplaceJson([
    { name: 'council', description: 'desc', category: 'ai-models' },
  ]);
  assert.equal(mp.plugins.length, 1);
  assert.deepEqual(mp.plugins[0].source, { source: 'local', path: './codex/plugins/council' });
  assert.equal(mp.plugins[0].description, 'desc');
  assert.equal(mp.plugins[0].category, 'ai-models');
});

test('generateMarketplaceJson: omits empty description/category, flattens block scalar', () => {
  const mp = generateMarketplaceJson([{ name: 'x', description: '|\n  multi\n  line' }]);
  assert.equal(mp.plugins[0].description, 'multi line');
  assert.ok(!('category' in mp.plugins[0]));
});

test('generateMarketplaceJson: name/displayName options', () => {
  const mp = generateMarketplaceJson([], { name: 'my-claude-plugins', displayName: 'X' });
  assert.equal(mp.name, 'my-claude-plugins');
  assert.equal(mp.interface.displayName, 'X');
});

// ---------------------------------------------------------------------------
// buildPluginAgentsDoc
// ---------------------------------------------------------------------------

test('buildPluginAgentsDoc: documents agents table and toml note', () => {
  const md = buildPluginAgentsDoc('code-scout', {
    skillCount: 2,
    agents: [{ agentName: 'github-scout', description: 'GitHub research' }],
  });
  assert.match(md, /# code-scout — Codex package notes/);
  assert.match(md, /Subagents/);
  assert.match(md, /~\/\.codex\/agents\/<plugin>-<agent>\.toml/);
  assert.match(md, /\| github-scout \| code-scout-github-scout \| GitHub research \|/);
});

test('buildPluginAgentsDoc: documents hooks as Codex-inert', () => {
  const md = buildPluginAgentsDoc('core-config', {
    skillCount: 0,
    hooks: ['PostToolUse (1 command)', 'Stop (1 command)'],
  });
  assert.match(md, /Hooks \(Claude Code only/);
  assert.match(md, /PostToolUse \(1 command\)/);
});

test('buildPluginAgentsDoc: no agents/hooks → skills-only note', () => {
  const md = buildPluginAgentsDoc('translator', { skillCount: 1 });
  assert.match(md, /bundles 1 skill/);
  assert.doesNotMatch(md, /Subagents/);
  assert.doesNotMatch(md, /Hooks/);
});

// ---------------------------------------------------------------------------
// parseArgs / loadConfig
// ---------------------------------------------------------------------------

test('parseArgs: --emit defaults to null (→ config/user)', () => {
  assert.equal(parseArgs([]).emit, null);
});

test('parseArgs: --emit plugin / user', () => {
  assert.equal(parseArgs(['--emit', 'plugin']).emit, 'plugin');
  assert.equal(parseArgs(['--emit', 'user']).emit, 'user');
});

test('parseArgs: --emit rejects invalid mode', () => {
  assert.throws(() => parseArgs(['--emit', 'bogus']), /user.*plugin|plugin.*user/i);
  assert.throws(() => parseArgs(['--emit']), /--emit/);
});

test('loadConfig: defaults emitMode user, pluginBuildRoot null', async () => {
  const cfg = await loadConfig(null);
  assert.equal(cfg.emitMode, 'user');
  assert.equal(cfg.pluginBuildRoot, null);
});

test('loadConfig: merges emitMode + pluginBuildRoot', async () => {
  const tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-cfg-'));
  try {
    const p = path.join(tmp, 'config.json');
    await fs.writeFile(p, JSON.stringify({ emitMode: 'plugin', pluginBuildRoot: '/build' }));
    const cfg = await loadConfig(p);
    assert.equal(cfg.emitMode, 'plugin');
    assert.equal(cfg.pluginBuildRoot, '/build');
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

// ---------------------------------------------------------------------------
// emitPlugins integration
// ---------------------------------------------------------------------------

async function makePlugin(repoRoot, name, { version = '1.0.0', description = `${name} plugin`, skills = {}, commands = {}, agents = {}, hooks = null } = {}) {
  const base = path.join(repoRoot, 'plugins', name);
  const pj = { name, version, description };
  if (hooks) pj.hooks = hooks;
  await fs.mkdir(path.join(base, '.claude-plugin'), { recursive: true });
  await fs.writeFile(path.join(base, '.claude-plugin', 'plugin.json'), JSON.stringify(pj, null, 2));
  for (const [sName, content] of Object.entries(skills)) {
    const d = path.join(base, 'skills', sName);
    await fs.mkdir(d, { recursive: true });
    await fs.writeFile(path.join(d, 'SKILL.md'), content);
  }
  for (const [cName, content] of Object.entries(commands)) {
    await fs.mkdir(path.join(base, 'commands'), { recursive: true });
    await fs.writeFile(path.join(base, 'commands', `${cName}.md`), content);
  }
  for (const [aName, content] of Object.entries(agents)) {
    await fs.mkdir(path.join(base, 'agents'), { recursive: true });
    await fs.writeFile(path.join(base, 'agents', `${aName}.md`), content);
  }
}

test('emitPlugins: builds plugin packages, marketplace, AGENTS.md, scope-correct refs', async () => {
  const repo = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-emit-'));
  try {
    await makePlugin(repo, 'llm-wiki', {
      version: '2.0.0',
      description: 'LLM wiki system',
      skills: {
        'query-wiki': '---\nname: query-wiki\ndescription: query\n---\nbody\n',
        'ingest-finding': '---\nname: ingest-finding\ndescription: ingest\n---\nsee /llm-wiki:query-wiki and /github-dev:post-merge and CLAUDE.md\n',
      },
      hooks: { PostToolUse: [{ matcher: 'Write', hooks: [{ type: 'command', command: 'x' }] }] },
    });
    await makePlugin(repo, 'github-dev', {
      version: '1.5.0',
      description: 'GitHub workflow',
      commands: { 'post-merge': '---\ndescription: cleanup\n---\nrun /github-dev:cr-fix here\n' },
      agents: { worker: '---\nname: worker\ndescription: does work\n---\nagent body\n' },
    });

    const config = JSON.parse(JSON.stringify(DEFAULT_CONFIG));
    const report = await emitPlugins({
      pluginsDir: path.join(repo, 'plugins'),
      buildRoot: repo,
      config,
      logger: { warn() {}, info() {} },
    });

    assert.equal(report.errors.length, 0);
    assert.equal(report.catalogCount, 2);

    // plugin.json
    const pj = JSON.parse(await fs.readFile(path.join(repo, 'codex/plugins/llm-wiki/.codex-plugin/plugin.json'), 'utf-8'));
    assert.deepEqual(pj, { name: 'llm-wiki', version: '2.0.0', description: 'LLM wiki system', skills: './skills/' });

    // skill body: local ref preserved, external flattened, CLAUDE.md → AGENTS.md
    const ingest = await fs.readFile(path.join(repo, 'codex/plugins/llm-wiki/skills/ingest-finding/SKILL.md'), 'utf-8');
    assert.match(ingest, /\/llm-wiki:query-wiki/);     // local preserved
    assert.match(ingest, /\$post-merge/);              // external flattened
    assert.match(ingest, /AGENTS\.md/);                // literal transform
    assert.match(ingest, /bridge_source: llm-wiki\/ingest-finding/);

    // wrapped command → skill
    const wrapped = await fs.readFile(path.join(repo, 'codex/plugins/github-dev/skills/github-dev-post-merge/SKILL.md'), 'utf-8');
    assert.match(wrapped, /name: github-dev-post-merge/);
    // local ref to own plugin preserved
    assert.match(wrapped, /\/github-dev:cr-fix/);

    // AGENTS.md documents the subagent + hooks
    const wikiAgents = await fs.readFile(path.join(repo, 'codex/plugins/llm-wiki/AGENTS.md'), 'utf-8');
    assert.match(wikiAgents, /Hooks \(Claude Code only/);
    const ghAgents = await fs.readFile(path.join(repo, 'codex/plugins/github-dev/AGENTS.md'), 'utf-8');
    assert.match(ghAgents, /github-dev-worker/);

    // marketplace.json
    const mp = JSON.parse(await fs.readFile(path.join(repo, '.agents/plugins/marketplace.json'), 'utf-8'));
    assert.equal(mp.plugins.length, 2);
    const names = mp.plugins.map(p => p.name).sort();
    assert.deepEqual(names, ['github-dev', 'llm-wiki']);
    for (const p of mp.plugins) {
      assert.equal(p.source.source, 'local');
      assert.match(p.source.path, /^\.\/codex\/plugins\//);
    }
  } finally {
    await fs.rm(repo, { recursive: true, force: true });
  }
});

test('emitPlugins: respects exclude list (no package, not in catalog)', async () => {
  const repo = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-emit-'));
  try {
    await makePlugin(repo, 'keep', { skills: { s: '---\nname: s\ndescription: d\n---\nx\n' } });
    await makePlugin(repo, 'drop', { skills: { s: '---\nname: s\ndescription: d\n---\nx\n' } });
    const config = JSON.parse(JSON.stringify(DEFAULT_CONFIG));
    config.exclude = ['plugins/drop/**'];
    const report = await emitPlugins({
      pluginsDir: path.join(repo, 'plugins'),
      buildRoot: repo,
      config,
      logger: { warn() {}, info() {} },
    });
    assert.equal(report.catalogCount, 1);
    const mp = JSON.parse(await fs.readFile(path.join(repo, '.agents/plugins/marketplace.json'), 'utf-8'));
    assert.deepEqual(mp.plugins.map(p => p.name), ['keep']);
    await assert.rejects(() => fs.access(path.join(repo, 'codex/plugins/drop')));
  } finally {
    await fs.rm(repo, { recursive: true, force: true });
  }
});

test('emitPlugins: prunes orphan plugin package on full rebuild', async () => {
  const repo = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-emit-'));
  try {
    // pre-existing orphan package dir
    const orphan = path.join(repo, 'codex/plugins/ghost');
    await fs.mkdir(orphan, { recursive: true });
    await fs.writeFile(path.join(orphan, 'marker'), 'x');

    await makePlugin(repo, 'real', { skills: { s: '---\nname: s\ndescription: d\n---\nx\n' } });
    const config = JSON.parse(JSON.stringify(DEFAULT_CONFIG));
    const report = await emitPlugins({
      pluginsDir: path.join(repo, 'plugins'),
      buildRoot: repo,
      config,
      logger: { warn() {}, info() {} },
    });
    assert.ok(report.removed.includes('ghost'));
    await assert.rejects(() => fs.access(orphan));
  } finally {
    await fs.rm(repo, { recursive: true, force: true });
  }
});

test('emitPlugins: dry-run writes nothing', async () => {
  const repo = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-emit-'));
  try {
    await makePlugin(repo, 'real', { skills: { s: '---\nname: s\ndescription: d\n---\nx\n' } });
    const config = JSON.parse(JSON.stringify(DEFAULT_CONFIG));
    await emitPlugins({
      pluginsDir: path.join(repo, 'plugins'),
      buildRoot: repo,
      config,
      dryRun: true,
      logger: { warn() {}, info() {} },
    });
    await assert.rejects(() => fs.access(path.join(repo, 'codex')));
    await assert.rejects(() => fs.access(path.join(repo, '.agents')));
  } finally {
    await fs.rm(repo, { recursive: true, force: true });
  }
});
