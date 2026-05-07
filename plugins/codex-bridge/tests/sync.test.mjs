import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';

import {
  syncOne,
  syncAll,
  syncAgent,
  injectBridgeSource,
  DEFAULT_RULES,
  DEFAULT_CONFIG,
} from '../scripts/sync.mjs';

async function makeSourceSkill(sourceRoot, pluginName, skillName, skillMdContent, extraFiles = {}) {
  const dir = path.join(sourceRoot, 'plugins', pluginName, 'skills', skillName);
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(dir, 'SKILL.md'), skillMdContent);
  for (const [relPath, content] of Object.entries(extraFiles)) {
    const full = path.join(dir, relPath);
    await fs.mkdir(path.dirname(full), { recursive: true });
    await fs.writeFile(full, content);
  }
  return {
    pluginName,
    skillName,
    skillDir: dir,
    skillPath: path.join(dir, 'SKILL.md'),
  };
}

async function freshTmp() {
  return fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-sync-'));
}

test('injectBridgeSource: appends field when absent', () => {
  const src = '---\nname: foo\ndescription: bar\n---\n# Body';
  const out = injectBridgeSource(src, 'pluginA/foo');
  assert.match(out, /bridge_source: pluginA\/foo/);
  assert.match(out, /^---\nname: foo\ndescription: bar\nbridge_source: pluginA\/foo\n---\n/);
});

test('injectBridgeSource: replaces existing bridge_source', () => {
  const src = '---\nname: foo\nbridge_source: old/path\n---\nbody';
  const out = injectBridgeSource(src, 'new/path');
  assert.match(out, /bridge_source: new\/path/);
  assert.doesNotMatch(out, /bridge_source: old\/path/);
});

test('injectBridgeSource: wraps content in frontmatter if absent', () => {
  const src = '# Plain body\nno frontmatter';
  const out = injectBridgeSource(src, 'p/s');
  assert.match(out, /^---\nbridge_source: p\/s\n---\n/);
});

test('syncOne: creates target when not exists, injects bridge_source, transforms body', async () => {
  const tmp = await freshTmp();
  try {
    const source = await makeSourceSkill(
      tmp,
      'pluginA',
      'my-skill',
      [
        '---',
        'name: my-skill',
        'description: Does things with CLAUDE.md',
        '---',
        '# Body',
        'use CLAUDE.md and .claude/ here',
      ].join('\n')
    );
    const targetRoot = path.join(tmp, 'target', '.agents', 'skills');

    const result = await syncOne(source, targetRoot, DEFAULT_RULES);

    assert.equal(result.status, 'synced');
    const written = await fs.readFile(path.join(targetRoot, 'my-skill', 'SKILL.md'), 'utf-8');
    // frontmatter unchanged (description preserved verbatim)
    assert.match(written, /description: Does things with CLAUDE\.md/);
    // bridge_source injected
    assert.match(written, /bridge_source: pluginA\/my-skill/);
    // body transformed
    assert.match(written, /use AGENTS\.md and \.codex\/ here/);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('syncOne: skips when target has no bridge_source marker (collision guard)', async () => {
  const tmp = await freshTmp();
  try {
    const source = await makeSourceSkill(
      tmp, 'pluginA', 'shared-name',
      '---\nname: shared-name\ndescription: bridge version\n---\nbridge body'
    );
    const targetRoot = path.join(tmp, 'target', '.agents', 'skills');
    const targetSkillDir = path.join(targetRoot, 'shared-name');
    await fs.mkdir(targetSkillDir, { recursive: true });
    await fs.writeFile(
      path.join(targetSkillDir, 'SKILL.md'),
      '---\nname: shared-name\ndescription: external version (not managed)\n---\npre-existing'
    );

    const result = await syncOne(source, targetRoot, DEFAULT_RULES);

    assert.equal(result.status, 'skipped');
    assert.equal(result.reason, 'non-managed-collision');
    const existing = await fs.readFile(path.join(targetSkillDir, 'SKILL.md'), 'utf-8');
    // untouched
    assert.match(existing, /external version \(not managed\)/);
    assert.match(existing, /pre-existing/);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('syncOne: overwrites when target has bridge_source marker', async () => {
  const tmp = await freshTmp();
  try {
    const source = await makeSourceSkill(
      tmp, 'pluginA', 'updatable',
      '---\nname: updatable\ndescription: v2\n---\nnew body'
    );
    const targetRoot = path.join(tmp, 'target', '.agents', 'skills');
    const targetSkillDir = path.join(targetRoot, 'updatable');
    await fs.mkdir(targetSkillDir, { recursive: true });
    await fs.writeFile(
      path.join(targetSkillDir, 'SKILL.md'),
      '---\nname: updatable\nbridge_source: pluginA/updatable\n---\nold body'
    );

    const result = await syncOne(source, targetRoot, DEFAULT_RULES);

    assert.equal(result.status, 'synced');
    const written = await fs.readFile(path.join(targetSkillDir, 'SKILL.md'), 'utf-8');
    assert.match(written, /new body/);
    assert.match(written, /bridge_source: pluginA\/updatable/);
    assert.doesNotMatch(written, /old body/);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('syncOne: copies additional files in skill dir', async () => {
  const tmp = await freshTmp();
  try {
    const source = await makeSourceSkill(
      tmp, 'pluginA', 'with-assets',
      '---\nname: with-assets\ndescription: x\n---\nbody',
      {
        'scripts/helper.sh': '#!/bin/bash\necho .claude/',
        'references/notes.md': '# Reference\nsee CLAUDE.md',
        'assets/icon.txt': 'binary-ish payload',
      }
    );
    const targetRoot = path.join(tmp, 'target', '.agents', 'skills');

    await syncOne(source, targetRoot, DEFAULT_RULES);

    const out = path.join(targetRoot, 'with-assets');
    const script = await fs.readFile(path.join(out, 'scripts/helper.sh'), 'utf-8');
    assert.match(script, /\.codex\//); // transformed (text ext)

    const notes = await fs.readFile(path.join(out, 'references/notes.md'), 'utf-8');
    assert.match(notes, /AGENTS\.md/); // transformed (.md ext)

    const icon = await fs.readFile(path.join(out, 'assets/icon.txt'), 'utf-8');
    assert.equal(icon, 'binary-ish payload'); // .txt not in transform whitelist → copied raw
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('syncOne: skipped when source frontmatter is missing (source defect)', async () => {
  const tmp = await freshTmp();
  try {
    const source = await makeSourceSkill(tmp, 'pluginA', 'broken', '# No frontmatter\nbody');
    const targetRoot = path.join(tmp, 'target', '.agents', 'skills');

    const result = await syncOne(source, targetRoot, DEFAULT_RULES);

    assert.equal(result.status, 'skipped');
    assert.equal(result.reason, 'source-missing-frontmatter');
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('syncOne: current behavior — overwrites even if bridge_source points to different plugin (last-wins)', async () => {
  // This test locks the current spec P1 "last-wins" semantics.
  // Collision warning is emitted at syncAll level (see syncAll collision test below).
  const tmp = await freshTmp();
  try {
    const source = await makeSourceSkill(
      tmp, 'pluginA', 'duplicate-name',
      '---\nname: duplicate-name\ndescription: from A\n---\nA body'
    );
    const targetRoot = path.join(tmp, 'target', '.agents', 'skills');
    const targetSkillDir = path.join(targetRoot, 'duplicate-name');
    await fs.mkdir(targetSkillDir, { recursive: true });
    await fs.writeFile(
      path.join(targetSkillDir, 'SKILL.md'),
      '---\nname: duplicate-name\nbridge_source: pluginB/duplicate-name\n---\nB body'
    );

    const result = await syncOne(source, targetRoot, DEFAULT_RULES);

    // Spec P1: last-wins. bridge_source presence authorizes overwrite regardless of plugin owner.
    assert.equal(result.status, 'synced');
    const written = await fs.readFile(path.join(targetSkillDir, 'SKILL.md'), 'utf-8');
    assert.match(written, /A body/);
    assert.match(written, /bridge_source: pluginA\/duplicate-name/);
    assert.doesNotMatch(written, /B body/);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('syncAll: emits collision warning when same skillName appears in multiple plugins', async () => {
  const tmp = await freshTmp();
  try {
    await makeSourceSkill(tmp, 'alpha', 'clash', '---\nname: clash\ndescription: A\n---\nA');
    await makeSourceSkill(tmp, 'beta', 'clash', '---\nname: clash\ndescription: B\n---\nB');

    const warnings = [];
    const logger = {
      warn: (m) => warnings.push(m),
      info: () => {},
    };

    const report = await syncAll({
      pluginsDir: path.join(tmp, 'plugins'),
      targetDir: path.join(tmp, 'target', '.agents', 'skills'),
      config: DEFAULT_CONFIG,
      dryRun: true,
      prune: false,
      logger,
    });

    assert.equal(report.collisions.length, 1);
    assert.equal(report.collisions[0].skillName, 'clash');
    assert.deepEqual(report.collisions[0].plugins.sort(), ['alpha', 'beta']);
    assert.ok(warnings.some(w => /collision.*clash/.test(w)), `expected warning about 'clash', got: ${warnings.join(' | ')}`);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('syncAll: no collision warning when all skill names unique', async () => {
  const tmp = await freshTmp();
  try {
    await makeSourceSkill(tmp, 'alpha', 'one', '---\nname: one\n---\nbody');
    await makeSourceSkill(tmp, 'beta', 'two', '---\nname: two\n---\nbody');

    const warnings = [];
    const logger = { warn: (m) => warnings.push(m), info: () => {} };

    const report = await syncAll({
      pluginsDir: path.join(tmp, 'plugins'),
      targetDir: path.join(tmp, 'target', '.agents', 'skills'),
      config: DEFAULT_CONFIG,
      dryRun: true,
      prune: false,
      logger,
    });

    assert.equal(report.collisions.length, 0);
    assert.equal(warnings.filter(w => /collision/.test(w)).length, 0);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('syncAll: prune is SKIPPED when validSources is empty (defends against pluginsDir misresolution)', async () => {
  // Regression test for the destructive prune bug fixed in 1.3.1.
  // If discovery returns 0 results (e.g. wrong pluginsDir under Claude Code's
  // versioned cache layout), pruneOrphans must NOT run — otherwise every
  // bridge-managed entry in ~/.agents/skills/ would be deleted.
  const tmp = await freshTmp();
  try {
    // Empty plugins dir (no plugins/* under it) — discovery returns []
    const pluginsDir = path.join(tmp, 'plugins');
    await fs.mkdir(pluginsDir, { recursive: true });

    // Pre-populate target with a bridge-managed skill that WOULD be pruned
    // under the old behavior (orphan with no matching source).
    const targetDir = path.join(tmp, 'target', '.agents', 'skills');
    const preExisting = path.join(targetDir, 'previously-synced');
    await fs.mkdir(preExisting, { recursive: true });
    await fs.writeFile(
      path.join(preExisting, 'SKILL.md'),
      '---\nname: previously-synced\nbridge_source: somePlugin/previously-synced\n---\nold body'
    );

    const warnings = [];
    const logger = { warn: (m) => warnings.push(m), info: () => {} };

    const report = await syncAll({
      pluginsDir,
      targetDir,
      config: DEFAULT_CONFIG,
      dryRun: false,
      prune: true,
      logger,
    });

    // Guard fired: nothing pruned, warning emitted, file still present.
    assert.deepEqual(report.removed, []);
    assert.ok(
      warnings.some(w => /prune skipped: 0 valid sources/.test(w)),
      `expected prune-skip warning, got: ${warnings.join(' | ')}`
    );
    assert.ok(
      report.warnings.some(w => /prune skipped: 0 valid sources/.test(w)),
      'expected report.warnings to include prune-skip warning'
    );

    const survivor = await fs.readFile(path.join(preExisting, 'SKILL.md'), 'utf-8');
    assert.match(survivor, /bridge_source: somePlugin\/previously-synced/);
    assert.match(survivor, /old body/);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('syncAll: empty discoverSkills emits warning into report.warnings (early signal)', async () => {
  const tmp = await freshTmp();
  try {
    const pluginsDir = path.join(tmp, 'plugins');
    await fs.mkdir(pluginsDir, { recursive: true });

    const warnings = [];
    const logger = { warn: (m) => warnings.push(m), info: () => {} };

    const report = await syncAll({
      pluginsDir,
      targetDir: path.join(tmp, 'target', '.agents', 'skills'),
      config: DEFAULT_CONFIG,
      dryRun: true,
      prune: false,
      logger,
    });

    assert.ok(
      warnings.some(w => /discoverSkills returned 0 results/.test(w)),
      `expected discoverSkills-empty warning, got: ${warnings.join(' | ')}`
    );
    assert.ok(
      report.warnings.some(w => /discoverSkills returned 0 results/.test(w)),
      'expected report.warnings to include discoverSkills-empty warning'
    );
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('syncAll: prune still runs normally when validSources non-empty', async () => {
  // Sanity check: the safety guard must NOT block legitimate prunes.
  const tmp = await freshTmp();
  try {
    // One source plugin/skill — validSources will include it.
    await makeSourceSkill(tmp, 'alpha', 'kept', '---\nname: kept\ndescription: x\n---\nbody');

    const targetDir = path.join(tmp, 'target', '.agents', 'skills');
    // Pre-populate an orphan (bridge-managed but no matching source).
    const orphan = path.join(targetDir, 'orphan-skill');
    await fs.mkdir(orphan, { recursive: true });
    await fs.writeFile(
      path.join(orphan, 'SKILL.md'),
      '---\nname: orphan-skill\nbridge_source: deleted/orphan-skill\n---\ngone'
    );

    const logger = { warn: () => {}, info: () => {} };

    const report = await syncAll({
      pluginsDir: path.join(tmp, 'plugins'),
      targetDir,
      config: DEFAULT_CONFIG,
      dryRun: false,
      prune: true,
      logger,
    });

    assert.equal(report.removed.length, 1);
    assert.equal(report.removed[0].skillName, 'orphan-skill');
    // Orphan dir is gone
    await assert.rejects(fs.access(orphan));
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

async function makeAgentFile(root, plugin, agent, content) {
  const dir = path.join(root, 'plugins', plugin, 'agents');
  await fs.mkdir(dir, { recursive: true });
  const filePath = path.join(dir, `${agent}.md`);
  await fs.writeFile(filePath, content);
  return { pluginName: plugin, agentName: agent, sourcePath: filePath, targetTomlName: `${plugin}-${agent}` };
}

test('syncAgent: writes <plugin>-<agent>.toml with bridge_source comment marker', async () => {
  const tmp = await freshTmp();
  try {
    const agent = await makeAgentFile(
      tmp, 'code-scout', 'scout',
      [
        '---',
        'name: scout',
        'description: |',
        '  Code and ML resource scout. Finds boilerplates.',
        'model: haiku',
        '---',
        '# Scout Agent',
        'use CLAUDE.md and .claude/ paths',
      ].join('\n')
    );
    const targetDir = path.join(tmp, 'target', '.codex', 'agents');

    const result = await syncAgent(agent, targetDir, DEFAULT_RULES);

    assert.equal(result.status, 'synced');
    const tomlPath = path.join(targetDir, 'code-scout-scout.toml');
    const written = await fs.readFile(tomlPath, 'utf-8');
    // bridge_source comment as first line
    assert.match(written, /^# bridge_source = "code-scout\/agents\/scout"/m);
    // model preserved as comment
    assert.match(written, /^# original-model = "haiku"$/m);
    // canonical TOML fields
    assert.match(written, /^name = "code-scout-scout"$/m);
    assert.match(written, /^description = "Code and ML resource scout\. Finds boilerplates\."$/m);
    assert.match(written, /^developer_instructions = """$/m);
    // body transformed
    assert.match(written, /AGENTS\.md/);
    assert.match(written, /\.codex\//);
    assert.doesNotMatch(written, /CLAUDE\.md/);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('syncAgent: idempotent — running twice produces identical output', async () => {
  const tmp = await freshTmp();
  try {
    const agent = await makeAgentFile(
      tmp, 'p', 'a',
      '---\nname: a\ndescription: x\n---\nbody\n'
    );
    const targetDir = path.join(tmp, 'target', '.codex', 'agents');

    await syncAgent(agent, targetDir, DEFAULT_RULES);
    const after1 = await fs.readFile(path.join(targetDir, 'p-a.toml'), 'utf-8');
    await syncAgent(agent, targetDir, DEFAULT_RULES);
    const after2 = await fs.readFile(path.join(targetDir, 'p-a.toml'), 'utf-8');
    assert.equal(after1, after2);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('syncAgent: skipped when target .toml exists without bridge_source marker (safety guard)', async () => {
  const tmp = await freshTmp();
  try {
    const agent = await makeAgentFile(
      tmp, 'p', 'a',
      '---\nname: a\ndescription: bridge version\n---\nbridge body'
    );
    const targetDir = path.join(tmp, 'target', '.codex', 'agents');
    await fs.mkdir(targetDir, { recursive: true });
    const tomlPath = path.join(targetDir, 'p-a.toml');
    await fs.writeFile(
      tomlPath,
      'name = "p-a"\ndescription = "external user-managed"\ndeveloper_instructions = "..."\n'
    );

    const result = await syncAgent(agent, targetDir, DEFAULT_RULES);

    assert.equal(result.status, 'skipped');
    assert.equal(result.reason, 'non-managed-collision');
    const still = await fs.readFile(tomlPath, 'utf-8');
    assert.match(still, /external user-managed/);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('syncAgent: overwrites when target .toml has bridge_source marker', async () => {
  const tmp = await freshTmp();
  try {
    const agent = await makeAgentFile(
      tmp, 'p', 'a',
      '---\nname: a\ndescription: v2\n---\nnew body\n'
    );
    const targetDir = path.join(tmp, 'target', '.codex', 'agents');
    await fs.mkdir(targetDir, { recursive: true });
    const tomlPath = path.join(targetDir, 'p-a.toml');
    await fs.writeFile(
      tomlPath,
      '# bridge_source = "p/agents/a"\nname = "p-a"\ndescription = "v1"\ndeveloper_instructions = """\nold body\n"""\n'
    );

    const result = await syncAgent(agent, targetDir, DEFAULT_RULES);
    assert.equal(result.status, 'synced');
    const written = await fs.readFile(tomlPath, 'utf-8');
    assert.match(written, /description = "v2"/);
    assert.match(written, /new body/);
    assert.doesNotMatch(written, /old body/);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('syncAgent: creates target directory when missing', async () => {
  const tmp = await freshTmp();
  try {
    const agent = await makeAgentFile(tmp, 'p', 'a', '---\nname: a\ndescription: x\n---\nbody');
    const targetDir = path.join(tmp, 'never', 'created', 'agents');

    const result = await syncAgent(agent, targetDir, DEFAULT_RULES);
    assert.equal(result.status, 'synced');
    await fs.access(path.join(targetDir, 'p-a.toml'));
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('syncAgent: leaves no .staging-* file behind on success', async () => {
  const tmp = await freshTmp();
  try {
    const agent = await makeAgentFile(tmp, 'p', 'a', '---\nname: a\ndescription: x\n---\nbody');
    const targetDir = path.join(tmp, 'target', '.codex', 'agents');

    await syncAgent(agent, targetDir, DEFAULT_RULES);
    const entries = await fs.readdir(targetDir);
    const staging = entries.filter(e => e.includes('.staging-'));
    assert.deepEqual(staging, []);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('syncAll: discovers and syncs agents alongside skills/commands', async () => {
  const tmp = await freshTmp();
  try {
    // one of each kind
    await makeSourceSkill(tmp, 'plg', 'sk', '---\nname: sk\ndescription: x\n---\nskill body');
    const cmdDir = path.join(tmp, 'plugins', 'plg', 'commands');
    await fs.mkdir(cmdDir, { recursive: true });
    await fs.writeFile(path.join(cmdDir, 'cmd.md'), '---\ndescription: cmd desc\n---\ncmd body');
    await makeAgentFile(tmp, 'plg', 'ag', '---\nname: ag\ndescription: agent desc\n---\nagent body');

    const skillsTarget = path.join(tmp, 'target', '.agents', 'skills');
    const agentsTomlTarget = path.join(tmp, 'target', '.codex', 'agents');

    const report = await syncAll({
      pluginsDir: path.join(tmp, 'plugins'),
      targetDir: skillsTarget,
      agentsTomlDir: agentsTomlTarget,
      config: DEFAULT_CONFIG,
      dryRun: false,
      prune: false,
      logger: { warn: () => {}, info: () => {} },
    });

    assert.equal(report.discoveredAgents, 1);
    assert.equal(report.consideredAgents, 1);
    // synced array contains all three (skill + command + agent)
    const sources = report.synced.map(s => s.bridgeSource).sort();
    assert.deepEqual(sources, ['plg/agents/ag', 'plg/commands/cmd', 'plg/sk']);
    // toml file actually written
    await fs.access(path.join(agentsTomlTarget, 'plg-ag.toml'));
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('parseArgs: --plugins-dir captures path', async () => {
  const { parseArgs } = await import('../scripts/sync.mjs');
  const args = parseArgs(['--plugins-dir', '/custom/path']);
  assert.equal(args.pluginsDir, '/custom/path');
});

test('parseArgs: --plugins-dir without value throws', async () => {
  const { parseArgs } = await import('../scripts/sync.mjs');
  assert.throws(() => parseArgs(['--plugins-dir']), /requires a path/);
});

test('parseArgs: --plugins-dir followed by another flag is rejected (does not silently consume the flag)', async () => {
  const { parseArgs } = await import('../scripts/sync.mjs');
  // Without the dash-prefix guard, this would parse pluginsDir="--dry-run"
  // and consume the actual --dry-run flag.
  assert.throws(() => parseArgs(['--plugins-dir', '--dry-run']), /requires a path/);
  assert.throws(() => parseArgs(['--plugins-dir', '-h']), /requires a path/);
});
