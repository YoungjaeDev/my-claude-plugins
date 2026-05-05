import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';

import {
  syncOne,
  syncAll,
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
