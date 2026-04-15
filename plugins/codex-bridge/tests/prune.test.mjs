import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';

import { pruneOrphans } from '../scripts/sync.mjs';

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
