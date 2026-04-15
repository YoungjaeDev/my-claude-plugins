import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';

import {
  loadConfig,
  parseArgs,
  isExcluded,
  DEFAULT_RULES,
} from '../scripts/sync.mjs';

async function writeJson(p, obj) {
  await fs.mkdir(path.dirname(p), { recursive: true });
  await fs.writeFile(p, JSON.stringify(obj), 'utf-8');
}

test('loadConfig: returns defaults when no config path', async () => {
  const cfg = await loadConfig(null);
  assert.equal(cfg.target.scope, 'user');
  assert.deepEqual(cfg.exclude, []);
  assert.equal(cfg.transform.bodyOnly, true);
  assert.equal(cfg.transform.rules.length, DEFAULT_RULES.length);
});

test('loadConfig: returns defaults when config file missing', async () => {
  const tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-cfg-'));
  try {
    const cfg = await loadConfig(path.join(tmp, 'does-not-exist.json'));
    assert.equal(cfg.target.scope, 'user');
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('loadConfig: merges user exclude list', async () => {
  const tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-cfg-'));
  try {
    const p = path.join(tmp, 'config.json');
    await writeJson(p, { exclude: ['plugins/midjourney/**'] });

    const cfg = await loadConfig(p);
    assert.deepEqual(cfg.exclude, ['plugins/midjourney/**']);
    // Other defaults still present
    assert.equal(cfg.transform.bodyOnly, true);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('loadConfig: throws on invalid JSON', async () => {
  const tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-cfg-'));
  try {
    const p = path.join(tmp, 'bad.json');
    await fs.writeFile(p, '{ not: json, ');
    await assert.rejects(() => loadConfig(p), /parse/i);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('isExcluded: matches ** glob', () => {
  assert.equal(isExcluded('plugins/midjourney/skills/x/SKILL.md', ['plugins/midjourney/**']), true);
  assert.equal(isExcluded('plugins/github-dev/skills/x/SKILL.md', ['plugins/midjourney/**']), false);
});

test('isExcluded: matches single * glob (no path sep)', () => {
  assert.equal(isExcluded('plugins/github-dev/skills/commit-push/SKILL.md', ['plugins/*/skills/commit-push/**']), true);
  assert.equal(isExcluded('plugins/github-dev/skills/other/SKILL.md', ['plugins/*/skills/commit-push/**']), false);
});

test('isExcluded: empty pattern list excludes nothing', () => {
  assert.equal(isExcluded('plugins/any/path', []), false);
});

test('parseArgs: all flags default to off', () => {
  const a = parseArgs([]);
  assert.equal(a.dryRun, false);
  assert.equal(a.verbose, false);
  assert.equal(a.noPrune, false);
  assert.equal(a.configPath, null);
  assert.equal(a.plugins, null);
  assert.equal(a.reportPath, null);
  assert.equal(a.help, false);
});

test('parseArgs: --dry-run, --verbose', () => {
  const a = parseArgs(['--dry-run', '--verbose']);
  assert.equal(a.dryRun, true);
  assert.equal(a.verbose, true);
});

test('parseArgs: --config <path>', () => {
  const a = parseArgs(['--config', '/etc/codex-bridge.json']);
  assert.equal(a.configPath, '/etc/codex-bridge.json');
});

test('parseArgs: --plugin comma-separated', () => {
  const a = parseArgs(['--plugin', 'github-dev,core-config']);
  assert.deepEqual(a.plugins, ['github-dev', 'core-config']);
});

test('parseArgs: --no-prune, --report', () => {
  const a = parseArgs(['--no-prune', '--report', '/tmp/out.json']);
  assert.equal(a.noPrune, true);
  assert.equal(a.reportPath, '/tmp/out.json');
});

test('parseArgs: --help / -h', () => {
  assert.equal(parseArgs(['--help']).help, true);
  assert.equal(parseArgs(['-h']).help, true);
});

test('parseArgs: throws on unknown flag', () => {
  assert.throws(() => parseArgs(['--unknown']), /unknown/i);
});
