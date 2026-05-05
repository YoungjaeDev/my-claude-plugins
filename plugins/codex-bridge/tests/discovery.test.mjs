import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

import { discoverSkills, parseFrontmatter } from '../scripts/sync.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const FIXTURES = path.join(__dirname, 'fixtures');

test('parseFrontmatter: normal frontmatter returns {name, description, body}', async () => {
  const content = await fs.readFile(path.join(FIXTURES, 'normal.md'), 'utf-8');
  const result = parseFrontmatter(content);
  assert.ok(result, 'expected non-null result');
  assert.equal(result.name, 'test-skill');
  assert.equal(result.description, 'A normal test skill for fixtures');
  assert.match(result.body, /# Body/);
  assert.match(result.body, /\.claude\//);
});

test('parseFrontmatter: no frontmatter returns null', async () => {
  const content = await fs.readFile(path.join(FIXTURES, 'no-frontmatter.md'), 'utf-8');
  const result = parseFrontmatter(content);
  assert.equal(result, null);
});

test('parseFrontmatter: missing name field returns null name', async () => {
  const content = await fs.readFile(path.join(FIXTURES, 'missing-name.md'), 'utf-8');
  const result = parseFrontmatter(content);
  assert.ok(result, 'expected non-null result');
  assert.equal(result.name, null);
  assert.equal(result.description, 'Missing name field, description only');
});

test('parseFrontmatter: preserves raw frontmatter for re-serialization', async () => {
  const content = await fs.readFile(path.join(FIXTURES, 'normal.md'), 'utf-8');
  const result = parseFrontmatter(content);
  assert.match(result.raw, /^name: test-skill/m);
  assert.ok(result.fields);
  assert.equal(result.fields.name, 'test-skill');
});

test('discoverSkills: finds SKILL.md files one level deep', async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-disc-'));
  try {
    const p = path.join(tmpDir, 'plugins', 'alpha', 'skills', 'my-skill');
    await fs.mkdir(p, { recursive: true });
    await fs.writeFile(path.join(p, 'SKILL.md'), '---\nname: my-skill\ndescription: x\n---\nbody');

    const skills = await discoverSkills(path.join(tmpDir, 'plugins'));
    assert.equal(skills.length, 1);
    assert.equal(skills[0].pluginName, 'alpha');
    assert.equal(skills[0].skillName, 'my-skill');
    assert.equal(skills[0].skillDir, p);
    assert.equal(skills[0].skillPath, path.join(p, 'SKILL.md'));
  } finally {
    await fs.rm(tmpDir, { recursive: true, force: true });
  }
});

test('discoverSkills: finds SKILL.md in nested subdir', async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-disc-'));
  try {
    const p = path.join(tmpDir, 'plugins', 'beta', 'skills', 'group', 'nested');
    await fs.mkdir(p, { recursive: true });
    await fs.writeFile(path.join(p, 'SKILL.md'), '---\nname: nested\n---\n');

    const skills = await discoverSkills(path.join(tmpDir, 'plugins'));
    assert.equal(skills.length, 1);
    assert.equal(skills[0].pluginName, 'beta');
    assert.equal(skills[0].skillName, 'nested');
  } finally {
    await fs.rm(tmpDir, { recursive: true, force: true });
  }
});

test('discoverSkills: returns [] when plugins dir missing', async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-disc-'));
  try {
    const skills = await discoverSkills(path.join(tmpDir, 'does-not-exist'));
    assert.deepEqual(skills, []);
  } finally {
    await fs.rm(tmpDir, { recursive: true, force: true });
  }
});

test('discoverSkills: skips plugins with no skills/ dir', async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-disc-'));
  try {
    await fs.mkdir(path.join(tmpDir, 'plugins', 'no-skills-plugin'), { recursive: true });
    const skills = await discoverSkills(path.join(tmpDir, 'plugins'));
    assert.deepEqual(skills, []);
  } finally {
    await fs.rm(tmpDir, { recursive: true, force: true });
  }
});

test('discoverSkills: returns deterministically sorted results (pluginName, skillName)', async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-disc-'));
  try {
    const pluginsDir = path.join(tmpDir, 'plugins');
    const mk = async (plugin, skill) => {
      const p = path.join(pluginsDir, plugin, 'skills', skill);
      await fs.mkdir(p, { recursive: true });
      await fs.writeFile(path.join(p, 'SKILL.md'), `---\nname: ${skill}\n---\n`);
    };
    await mk('zebra', 'zeta');
    await mk('alpha', 'beta');
    await mk('alpha', 'alpha-skill');
    await mk('mango', 'skill-x');

    const skills = await discoverSkills(pluginsDir);
    const order = skills.map(s => `${s.pluginName}/${s.skillName}`);
    assert.deepEqual(order, [
      'alpha/alpha-skill',
      'alpha/beta',
      'mango/skill-x',
      'zebra/zeta',
    ]);
  } finally {
    await fs.rm(tmpDir, { recursive: true, force: true });
  }
});
