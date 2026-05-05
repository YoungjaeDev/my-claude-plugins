import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';

import { resolvePluginsDir, isVersionedCacheChild } from '../scripts/sync.mjs';

async function freshTmp() {
  return fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-resolve-'));
}

test('isVersionedCacheChild: matches semver MAJOR.MINOR.PATCH', () => {
  assert.equal(isVersionedCacheChild('1.0.0'), true);
  assert.equal(isVersionedCacheChild('1.3.1'), true);
  assert.equal(isVersionedCacheChild('10.20.30'), true);
});

test('isVersionedCacheChild: matches semver with prerelease/build metadata', () => {
  assert.equal(isVersionedCacheChild('1.0.0-rc.1'), true);
  assert.equal(isVersionedCacheChild('1.2.3+build.42'), true);
  assert.equal(isVersionedCacheChild('1.2.3-alpha+meta'), true);
});

test('isVersionedCacheChild: rejects plugin-like names', () => {
  assert.equal(isVersionedCacheChild('codex-bridge'), false);
  assert.equal(isVersionedCacheChild('github-dev'), false);
  assert.equal(isVersionedCacheChild('1.0'), false);
  assert.equal(isVersionedCacheChild('v1.0.0'), false);
  assert.equal(isVersionedCacheChild(''), false);
});

test('resolvePluginsDir: monorepo layout returns candidateA (one level above plugin dir)', async () => {
  const tmp = await freshTmp();
  try {
    // tmp/plugins/{alpha,beta}/scripts/sync.mjs
    const pluginsDir = path.join(tmp, 'plugins');
    for (const name of ['alpha', 'beta']) {
      await fs.mkdir(path.join(pluginsDir, name, 'scripts'), { recursive: true });
    }
    const scriptPath = path.join(pluginsDir, 'alpha', 'scripts', 'sync.mjs');

    const result = await resolvePluginsDir(scriptPath, null);
    assert.equal(result, pluginsDir);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('resolvePluginsDir: versioned cache layout jumps one more level up', async () => {
  const tmp = await freshTmp();
  try {
    // tmp/cache/codex-bridge/{1.2.0,1.3.0}/scripts/sync.mjs
    const cacheRoot = path.join(tmp, 'cache');
    const pluginCacheDir = path.join(cacheRoot, 'codex-bridge');
    for (const ver of ['1.2.0', '1.3.0']) {
      await fs.mkdir(path.join(pluginCacheDir, ver, 'scripts'), { recursive: true });
    }
    const scriptPath = path.join(pluginCacheDir, '1.3.0', 'scripts', 'sync.mjs');

    const result = await resolvePluginsDir(scriptPath, null);
    assert.equal(result, cacheRoot);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('resolvePluginsDir: explicit override is returned verbatim (resolved)', async () => {
  const tmp = await freshTmp();
  try {
    const custom = path.join(tmp, 'custom-plugins');
    await fs.mkdir(custom, { recursive: true });
    const scriptPath = path.join(tmp, 'irrelevant', 'scripts', 'sync.mjs');

    const result = await resolvePluginsDir(scriptPath, custom);
    assert.equal(result, path.resolve(custom));
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('resolvePluginsDir: override resolves relative paths', async () => {
  const result = await resolvePluginsDir('/somewhere/scripts/sync.mjs', './my/plugins');
  assert.equal(result, path.resolve('./my/plugins'));
});

test('resolvePluginsDir: ENOENT (no candidate directory) falls back to candidateA', async () => {
  const tmp = await freshTmp();
  try {
    // scriptPath points to a path whose grandparent does not exist
    const scriptPath = path.join(tmp, 'never-created', 'subdir', 'scripts', 'sync.mjs');
    const expectedFallback = path.resolve(path.dirname(scriptPath), '..', '..');

    const result = await resolvePluginsDir(scriptPath, null);
    assert.equal(result, expectedFallback);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('resolvePluginsDir: candidateA with mixed children (some semver, some not) treated as monorepo', async () => {
  const tmp = await freshTmp();
  try {
    // plugins-like dir with both 'real-plugin' and a coincidentally-semver-named subdir
    const pluginsDir = path.join(tmp, 'plugins');
    await fs.mkdir(path.join(pluginsDir, 'real-plugin'), { recursive: true });
    await fs.mkdir(path.join(pluginsDir, '1.2.3'), { recursive: true });
    const scriptPath = path.join(pluginsDir, 'real-plugin', 'scripts', 'sync.mjs');

    const result = await resolvePluginsDir(scriptPath, null);
    assert.equal(result, pluginsDir, 'mixed children should NOT trigger versioned-cache fallback');
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('resolvePluginsDir: empty candidateA directory falls back to candidateA (no false positive)', async () => {
  const tmp = await freshTmp();
  try {
    const pluginsDir = path.join(tmp, 'plugins');
    await fs.mkdir(pluginsDir, { recursive: true });
    const scriptPath = path.join(pluginsDir, 'phantom-plugin', 'scripts', 'sync.mjs');

    const result = await resolvePluginsDir(scriptPath, null);
    assert.equal(result, pluginsDir);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});
