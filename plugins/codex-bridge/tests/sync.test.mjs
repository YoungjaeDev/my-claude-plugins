import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';

import {
  syncOne,
  injectBridgeSource,
  DEFAULT_RULES,
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
        'description: Does things with omc',
        '---',
        '# Body',
        'use CLAUDE.md and .omc/ here',
      ].join('\n')
    );
    const targetRoot = path.join(tmp, 'target', '.agents', 'skills');

    const result = await syncOne(source, targetRoot, DEFAULT_RULES);

    assert.equal(result.status, 'synced');
    const written = await fs.readFile(path.join(targetRoot, 'my-skill', 'SKILL.md'), 'utf-8');
    // frontmatter unchanged (description mentions omc intentionally)
    assert.match(written, /description: Does things with omc/);
    // bridge_source injected
    assert.match(written, /bridge_source: pluginA\/my-skill/);
    // body transformed
    assert.match(written, /use AGENTS\.md and \.omx\/ here/);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('syncOne: skips when target has no bridge_source marker (collision guard)', async () => {
  const tmp = await freshTmp();
  try {
    const source = await makeSourceSkill(
      tmp, 'pluginA', 'shared-name',
      '---\nname: shared-name\ndescription: OMC version\n---\nomc body'
    );
    const targetRoot = path.join(tmp, 'target', '.agents', 'skills');
    const targetSkillDir = path.join(targetRoot, 'shared-name');
    await fs.mkdir(targetSkillDir, { recursive: true });
    await fs.writeFile(
      path.join(targetSkillDir, 'SKILL.md'),
      '---\nname: shared-name\ndescription: OMX version (not managed)\n---\npre-existing'
    );

    const result = await syncOne(source, targetRoot, DEFAULT_RULES);

    assert.equal(result.status, 'skipped');
    assert.equal(result.reason, 'non-managed-collision');
    const existing = await fs.readFile(path.join(targetSkillDir, 'SKILL.md'), 'utf-8');
    // untouched
    assert.match(existing, /OMX version \(not managed\)/);
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
        'scripts/helper.sh': '#!/bin/bash\necho .omc/',
        'references/notes.md': '# Reference\nsee CLAUDE.md',
        'assets/icon.txt': 'binary-ish payload',
      }
    );
    const targetRoot = path.join(tmp, 'target', '.agents', 'skills');

    await syncOne(source, targetRoot, DEFAULT_RULES);

    const out = path.join(targetRoot, 'with-assets');
    const script = await fs.readFile(path.join(out, 'scripts/helper.sh'), 'utf-8');
    assert.match(script, /\.omx\//); // transformed (text ext)

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
