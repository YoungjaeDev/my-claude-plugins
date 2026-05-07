import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';

import { pruneOrphans, pruneAgentOrphans } from '../scripts/sync.mjs';

async function freshTmp() {
  return fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-prune-'));
}

async function mkSkill(root, name, content) {
  const dir = path.join(root, name);
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(dir, 'SKILL.md'), content);
  return dir;
}

test('pruneOrphans: keeps skill with valid bridge_source', async () => {
  const tmp = await freshTmp();
  try {
    const target = path.join(tmp, 'skills');
    await mkSkill(target, 'valid-skill',
      '---\nname: valid-skill\nbridge_source: plugA/valid-skill\n---\nbody');

    const report = await pruneOrphans(target, new Set(['plugA/valid-skill']));
    assert.deepEqual(report.removed, []);
    assert.ok(await fileExists(path.join(target, 'valid-skill', 'SKILL.md')));
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('pruneOrphans: removes skill when bridge_source source is gone', async () => {
  const tmp = await freshTmp();
  try {
    const target = path.join(tmp, 'skills');
    await mkSkill(target, 'gone',
      '---\nname: gone\nbridge_source: plugA/gone\n---\nbody');

    const report = await pruneOrphans(target, new Set(['plugA/other']));
    assert.equal(report.removed.length, 1);
    assert.equal(report.removed[0].skillName, 'gone');
    assert.equal(await fileExists(path.join(target, 'gone')), false);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('pruneOrphans: NEVER touches skill without bridge_source (safety)', async () => {
  const tmp = await freshTmp();
  try {
    const target = path.join(tmp, 'skills');
    await mkSkill(target, 'user-owned',
      '---\nname: user-owned\ndescription: a user skill\n---\nbody');

    const report = await pruneOrphans(target, new Set());
    assert.deepEqual(report.removed, []);
    assert.ok(await fileExists(path.join(target, 'user-owned', 'SKILL.md')));
    assert.equal(report.preserved.length, 1);
    assert.equal(report.preserved[0].reason, 'no-bridge-source');
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('pruneOrphans: mixed scenario — keeps valid, removes orphan, preserves unmanaged', async () => {
  const tmp = await freshTmp();
  try {
    const target = path.join(tmp, 'skills');
    await mkSkill(target, 'managed-valid',
      '---\nname: managed-valid\nbridge_source: plugA/managed-valid\n---\n');
    await mkSkill(target, 'managed-orphan',
      '---\nname: managed-orphan\nbridge_source: plugA/old-skill\n---\n');
    await mkSkill(target, 'omx-owned',
      '---\nname: omx-owned\ndescription: an OMX skill\n---\n');

    const report = await pruneOrphans(target, new Set(['plugA/managed-valid']));

    assert.equal(report.removed.length, 1);
    assert.equal(report.removed[0].skillName, 'managed-orphan');
    assert.ok(await fileExists(path.join(target, 'managed-valid', 'SKILL.md')));
    assert.ok(await fileExists(path.join(target, 'omx-owned', 'SKILL.md')));
    assert.equal(await fileExists(path.join(target, 'managed-orphan')), false);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('pruneOrphans: handles missing target directory gracefully', async () => {
  const tmp = await freshTmp();
  try {
    const report = await pruneOrphans(path.join(tmp, 'never-created'), new Set());
    assert.deepEqual(report.removed, []);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

async function fileExists(p) {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}

async function mkAgentToml(root, name, content) {
  await fs.mkdir(root, { recursive: true });
  await fs.writeFile(path.join(root, `${name}.toml`), content);
}

test('pruneAgentOrphans: keeps .toml with valid bridge_source comment', async () => {
  const tmp = await freshTmp();
  try {
    const target = path.join(tmp, 'agents');
    await mkAgentToml(target, 'plg-keep',
      '# bridge_source = "plg/agents/keep"\nname = "plg-keep"\ndescription = "x"\ndeveloper_instructions = """body"""\n');

    const report = await pruneAgentOrphans(target, new Set(['plg/agents/keep']));
    assert.deepEqual(report.removed, []);
    assert.ok(await fileExists(path.join(target, 'plg-keep.toml')));
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('pruneAgentOrphans: removes .toml when bridge_source source is gone', async () => {
  const tmp = await freshTmp();
  try {
    const target = path.join(tmp, 'agents');
    await mkAgentToml(target, 'plg-gone',
      '# bridge_source = "plg/agents/gone"\nname = "plg-gone"\n');

    const report = await pruneAgentOrphans(target, new Set(['plg/agents/other']));
    assert.equal(report.removed.length, 1);
    assert.equal(report.removed[0].tomlName, 'plg-gone.toml');
    assert.equal(await fileExists(path.join(target, 'plg-gone.toml')), false);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('pruneAgentOrphans: NEVER touches .toml without bridge_source comment (safety)', async () => {
  const tmp = await freshTmp();
  try {
    const target = path.join(tmp, 'agents');
    await mkAgentToml(target, 'user-owned',
      'name = "user-owned"\ndescription = "user wrote this"\ndeveloper_instructions = """body"""\n');

    const report = await pruneAgentOrphans(target, new Set());
    assert.deepEqual(report.removed, []);
    assert.ok(await fileExists(path.join(target, 'user-owned.toml')));
    assert.equal(report.preserved.length, 1);
    assert.equal(report.preserved[0].reason, 'no-bridge-source');
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('pruneAgentOrphans: mixed scenario — keeps valid, removes orphan, preserves unmanaged', async () => {
  const tmp = await freshTmp();
  try {
    const target = path.join(tmp, 'agents');
    await mkAgentToml(target, 'managed-valid',
      '# bridge_source = "plg/agents/valid"\nname = "managed-valid"\n');
    await mkAgentToml(target, 'managed-orphan',
      '# bridge_source = "plg/agents/dead"\nname = "managed-orphan"\n');
    await mkAgentToml(target, 'user-owned',
      'name = "user-owned"\ndescription = "x"\n');

    const report = await pruneAgentOrphans(target, new Set(['plg/agents/valid']));

    assert.equal(report.removed.length, 1);
    assert.equal(report.removed[0].tomlName, 'managed-orphan.toml');
    assert.ok(await fileExists(path.join(target, 'managed-valid.toml')));
    assert.ok(await fileExists(path.join(target, 'user-owned.toml')));
    assert.equal(await fileExists(path.join(target, 'managed-orphan.toml')), false);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('pruneAgentOrphans: handles missing target directory gracefully', async () => {
  const tmp = await freshTmp();
  try {
    const report = await pruneAgentOrphans(path.join(tmp, 'never-created'), new Set());
    assert.deepEqual(report.removed, []);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('pruneAgentOrphans: ignores .staging-* files', async () => {
  const tmp = await freshTmp();
  try {
    const target = path.join(tmp, 'agents');
    await fs.mkdir(target, { recursive: true });
    await fs.writeFile(path.join(target, '.staging-plg-x-12345.toml'),
      '# bridge_source = "plg/agents/x"\nname = "plg-x"\n');

    const report = await pruneAgentOrphans(target, new Set());
    assert.deepEqual(report.removed, []);
    assert.ok(await fileExists(path.join(target, '.staging-plg-x-12345.toml')));
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('pruneAgentOrphans: ignores non-.toml files', async () => {
  const tmp = await freshTmp();
  try {
    const target = path.join(tmp, 'agents');
    await fs.mkdir(target, { recursive: true });
    await fs.writeFile(path.join(target, 'README.md'), '# notes');

    const report = await pruneAgentOrphans(target, new Set());
    assert.deepEqual(report.removed, []);
    assert.ok(await fileExists(path.join(target, 'README.md')));
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});
