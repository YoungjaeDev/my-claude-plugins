import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

import { discoverSkills, discoverCommands, parseFrontmatter, resolvePluginContentDir, compareSemver } from '../scripts/sync.mjs';

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

test('compareSemver: orders by major, minor, patch', () => {
  assert.equal(compareSemver('1.0.0', '1.0.0'), 0);
  assert.ok(compareSemver('1.0.0', '2.0.0') < 0);
  assert.ok(compareSemver('1.2.0', '1.10.0') < 0);
  assert.ok(compareSemver('1.0.10', '1.0.2') > 0);
  assert.ok(compareSemver('2.0.0', '1.99.99') > 0);
});

test('compareSemver: pre-release sorts before stable at the same numeric core (semver §11)', () => {
  assert.ok(compareSemver('1.3.1-rc.1', '1.3.1') < 0, 'pre-release < stable');
  assert.ok(compareSemver('1.3.1', '1.3.1-rc.1') > 0, 'stable > pre-release');
});

test('compareSemver: pre-release identifiers compared per semver spec', () => {
  // numeric identifiers compare numerically
  assert.ok(compareSemver('1.0.0-rc.1', '1.0.0-rc.2') < 0);
  assert.ok(compareSemver('1.0.0-rc.10', '1.0.0-rc.9') > 0);
  // alphanumeric identifiers compare lexically
  assert.ok(compareSemver('1.0.0-alpha', '1.0.0-beta') < 0);
  // shorter identifier list sorts before longer when prefixes match
  assert.ok(compareSemver('1.0.0-rc', '1.0.0-rc.1') < 0);
  // numeric < alphanumeric per spec
  assert.ok(compareSemver('1.0.0-1', '1.0.0-a') < 0);
});

test('compareSemver: numeric core wins over pre-release ordering', () => {
  assert.ok(compareSemver('1.0.0-rc.1', '1.0.1') < 0);
  assert.ok(compareSemver('1.0.1-rc.1', '1.0.0') > 0);
});

test('compareSemver: build metadata is ignored for ordering', () => {
  assert.equal(compareSemver('1.0.0+build1', '1.0.0+build2'), 0);
  assert.equal(compareSemver('1.0.0', '1.0.0+meta'), 0);
});

test('resolvePluginContentDir: monorepo plugin (.claude-plugin/ present) returns plugin dir as-is', async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-disc-'));
  try {
    const pluginDir = path.join(tmpDir, 'my-plugin');
    await fs.mkdir(path.join(pluginDir, '.claude-plugin'), { recursive: true });
    await fs.mkdir(path.join(pluginDir, 'skills'), { recursive: true });

    const result = await resolvePluginContentDir(pluginDir);
    assert.equal(result, pluginDir);
  } finally {
    await fs.rm(tmpDir, { recursive: true, force: true });
  }
});

test('resolvePluginContentDir: monorepo plugin without .claude-plugin/ but with skills/ falls back to plugin dir', async () => {
  // Existing tests rely on this fallback (test fixtures don't always create .claude-plugin/).
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-disc-'));
  try {
    const pluginDir = path.join(tmpDir, 'my-plugin');
    await fs.mkdir(path.join(pluginDir, 'skills'), { recursive: true });

    const result = await resolvePluginContentDir(pluginDir);
    assert.equal(result, pluginDir);
  } finally {
    await fs.rm(tmpDir, { recursive: true, force: true });
  }
});

test('resolvePluginContentDir: cache layout (all children semver) returns latest version subdir', async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-disc-'));
  try {
    const pluginDir = path.join(tmpDir, 'codex-bridge');
    for (const v of ['1.2.0', '1.13.0', '1.3.0', '1.3.1']) {
      await fs.mkdir(path.join(pluginDir, v, '.claude-plugin'), { recursive: true });
    }

    const result = await resolvePluginContentDir(pluginDir);
    assert.equal(result, path.join(pluginDir, '1.13.0'));
  } finally {
    await fs.rm(tmpDir, { recursive: true, force: true });
  }
});

test('resolvePluginContentDir: ENOENT returns null', async () => {
  const result = await resolvePluginContentDir('/nonexistent/path/that/should/not/exist');
  assert.equal(result, null);
});

test('resolvePluginContentDir: empty plugin dir falls back to plugin dir (downstream walker handles ENOENT)', async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-disc-'));
  try {
    const pluginDir = path.join(tmpDir, 'empty-plugin');
    await fs.mkdir(pluginDir, { recursive: true });

    const result = await resolvePluginContentDir(pluginDir);
    assert.equal(result, pluginDir);
  } finally {
    await fs.rm(tmpDir, { recursive: true, force: true });
  }
});

test('discoverSkills: handles versioned cache layout, picks latest version per plugin', async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-disc-'));
  try {
    // Simulate ~/.claude/plugins/cache/my-claude-plugins/<plugin>/<version>/skills/<skill>/SKILL.md
    const cacheRoot = path.join(tmpDir, 'my-claude-plugins');
    const writeSkill = async (plugin, version, skill, body = 'body') => {
      const p = path.join(cacheRoot, plugin, version, 'skills', skill);
      await fs.mkdir(path.join(cacheRoot, plugin, version, '.claude-plugin'), { recursive: true });
      await fs.mkdir(p, { recursive: true });
      await fs.writeFile(path.join(p, 'SKILL.md'), `---\nname: ${skill}\n---\n${body}`);
    };
    await writeSkill('codex-bridge', '1.2.0', 'codex-sync', 'old');
    await writeSkill('codex-bridge', '1.3.0', 'codex-sync', 'mid');
    await writeSkill('codex-bridge', '1.3.1', 'codex-sync', 'latest');
    await writeSkill('other-plugin', '2.0.0', 'foo');

    const skills = await discoverSkills(cacheRoot);
    assert.equal(skills.length, 2);

    const codexSync = skills.find(s => s.pluginName === 'codex-bridge');
    assert.ok(codexSync, 'expected codex-bridge entry');
    assert.equal(codexSync.skillName, 'codex-sync');
    // Verify the LATEST version was picked (1.3.1, not 1.2.0 / 1.3.0)
    assert.match(codexSync.skillPath, /\/1\.3\.1\/skills\/codex-sync\/SKILL\.md$/);
    const body = await fs.readFile(codexSync.skillPath, 'utf-8');
    assert.match(body, /latest/);

    const foo = skills.find(s => s.pluginName === 'other-plugin');
    assert.ok(foo, 'expected other-plugin entry');
    assert.equal(foo.skillName, 'foo');
  } finally {
    await fs.rm(tmpDir, { recursive: true, force: true });
  }
});

test('discoverCommands: handles versioned cache layout, picks latest version per plugin', async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-disc-'));
  try {
    const cacheRoot = path.join(tmpDir, 'my-claude-plugins');
    const writeCmd = async (plugin, version, name, body = '# cmd') => {
      const dir = path.join(cacheRoot, plugin, version, 'commands');
      await fs.mkdir(path.join(cacheRoot, plugin, version, '.claude-plugin'), { recursive: true });
      await fs.mkdir(dir, { recursive: true });
      await fs.writeFile(path.join(dir, `${name}.md`), `---\ndescription: x\n---\n${body}`);
    };
    await writeCmd('github-dev', '1.13.0', 'commit-and-push', 'old');
    await writeCmd('github-dev', '1.14.0', 'commit-and-push', 'latest');

    const commands = await discoverCommands(cacheRoot);
    assert.equal(commands.length, 1);
    assert.equal(commands[0].pluginName, 'github-dev');
    assert.equal(commands[0].commandName, 'commit-and-push');
    assert.match(commands[0].sourcePath, /\/1\.14\.0\/commands\/commit-and-push\.md$/);
  } finally {
    await fs.rm(tmpDir, { recursive: true, force: true });
  }
});

test('discoverSkills: monorepo plugin with coincidentally-semver-named subdir is NOT misclassified', async () => {
  // If a plugin has both .claude-plugin/ AND a child like '1.2.3', the .claude-plugin
  // marker wins and we treat as monorepo.
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-disc-'));
  try {
    const pluginsDir = path.join(tmpDir, 'plugins');
    const pluginDir = path.join(pluginsDir, 'mixed-plugin');
    await fs.mkdir(path.join(pluginDir, '.claude-plugin'), { recursive: true });
    await fs.mkdir(path.join(pluginDir, '1.2.3'), { recursive: true }); // distractor
    const skillDir = path.join(pluginDir, 'skills', 'real-skill');
    await fs.mkdir(skillDir, { recursive: true });
    await fs.writeFile(path.join(skillDir, 'SKILL.md'), '---\nname: real-skill\n---\nbody');

    const skills = await discoverSkills(pluginsDir);
    assert.equal(skills.length, 1);
    assert.equal(skills[0].pluginName, 'mixed-plugin');
    assert.equal(skills[0].skillName, 'real-skill');
    // skill is from monorepo path, NOT the 1.2.3 subdir
    assert.match(skills[0].skillPath, /\/mixed-plugin\/skills\/real-skill\/SKILL\.md$/);
  } finally {
    await fs.rm(tmpDir, { recursive: true, force: true });
  }
});
