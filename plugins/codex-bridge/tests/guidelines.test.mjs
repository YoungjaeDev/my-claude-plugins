import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';

import {
  discoverGuidelines,
  renderGuidelinesBlock,
  injectGuidelinesIntoAgents,
  DEFAULT_RULES,
  GUIDELINES_MARKER_START,
  GUIDELINES_MARKER_END,
} from '../scripts/sync.mjs';

async function freshTmp() {
  return fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-guide-'));
}

async function mkGuideline(root, plugin, name, content) {
  const dir = path.join(root, 'plugins', plugin, 'guidelines');
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(dir, `${name}.md`), content);
}

test('discoverGuidelines: finds plugins/*/guidelines/*.md', async () => {
  const tmp = await freshTmp();
  try {
    await mkGuideline(tmp, 'core-config', 'work-guidelines', '# Work\nbody');
    await mkGuideline(tmp, 'core-config', 'ml-guidelines', '# ML\nbody');
    await mkGuideline(tmp, 'other', 'extra', '# Extra\nbody');

    const found = await discoverGuidelines(path.join(tmp, 'plugins'));
    assert.equal(found.length, 3);
    const keys = found.map(g => `${g.pluginName}/${g.guidelineName}`).sort();
    assert.deepEqual(keys, ['core-config/ml-guidelines', 'core-config/work-guidelines', 'other/extra']);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('discoverGuidelines: deterministically sorted', async () => {
  const tmp = await freshTmp();
  try {
    await mkGuideline(tmp, 'zeta', 'z', 'z');
    await mkGuideline(tmp, 'alpha', 'b', 'b');
    await mkGuideline(tmp, 'alpha', 'a', 'a');

    const found = await discoverGuidelines(path.join(tmp, 'plugins'));
    const order = found.map(g => `${g.pluginName}/${g.guidelineName}`);
    assert.deepEqual(order, ['alpha/a', 'alpha/b', 'zeta/z']);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('discoverGuidelines: returns [] when no guidelines dirs', async () => {
  const tmp = await freshTmp();
  try {
    await fs.mkdir(path.join(tmp, 'plugins', 'empty'), { recursive: true });
    const found = await discoverGuidelines(path.join(tmp, 'plugins'));
    assert.deepEqual(found, []);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('renderGuidelinesBlock: wraps with markers and applies body transforms', async () => {
  const tmp = await freshTmp();
  try {
    await mkGuideline(tmp, 'p', 'guide', '# Guide\nuse CLAUDE.md and .omc/ paths');
    const found = await discoverGuidelines(path.join(tmp, 'plugins'));

    const block = await renderGuidelinesBlock(found, DEFAULT_RULES);
    assert.ok(block.startsWith(GUIDELINES_MARKER_START));
    assert.ok(block.endsWith(GUIDELINES_MARKER_END));
    // body transformed
    assert.match(block, /AGENTS\.md/);
    assert.match(block, /\.omx\//);
    // source tag mentions plugin/name
    assert.match(block, /p\/guide/);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('renderGuidelinesBlock: empty list returns empty string', async () => {
  const block = await renderGuidelinesBlock([], DEFAULT_RULES);
  assert.equal(block, '');
});

test('injectGuidelinesIntoAgents: appends block when no existing marker', () => {
  const existing = '# My AGENTS\n\n<!-- omx:generated:agents-md -->\nOMX content\nmore omx\n';
  const block = `${GUIDELINES_MARKER_START}\nnew content\n${GUIDELINES_MARKER_END}`;

  const out = injectGuidelinesIntoAgents(existing, block);
  assert.ok(out.endsWith(`${block}\n`));
  assert.match(out, /<!-- omx:generated:agents-md -->/);
  assert.match(out, /OMX content/);
});

test('injectGuidelinesIntoAgents: replaces existing block idempotently', () => {
  const existing = [
    '# AGENTS',
    '<!-- omx:generated:agents-md -->',
    'OMX stuff',
    '',
    GUIDELINES_MARKER_START,
    'OLD guideline content',
    GUIDELINES_MARKER_END,
    '',
  ].join('\n');

  const newBlock = `${GUIDELINES_MARKER_START}\nNEW guideline content\n${GUIDELINES_MARKER_END}`;
  const out = injectGuidelinesIntoAgents(existing, newBlock);

  assert.match(out, /NEW guideline content/);
  assert.doesNotMatch(out, /OLD guideline content/);
  // OMX content preserved
  assert.match(out, /OMX stuff/);
  // Only one pair of markers
  const startCount = (out.match(new RegExp(GUIDELINES_MARKER_START.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&'), 'g')) ?? []).length;
  const endCount = (out.match(new RegExp(GUIDELINES_MARKER_END.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&'), 'g')) ?? []).length;
  assert.equal(startCount, 1);
  assert.equal(endCount, 1);
});

test('injectGuidelinesIntoAgents: NEVER touches OMX marker region', () => {
  const existing = [
    '<!-- omx:generated:agents-md -->',
    'critical omx content with CLAUDE.md reference',
    'another omx line',
    '<!-- /omx:generated:agents-md -->',
  ].join('\n');

  const block = `${GUIDELINES_MARKER_START}\nnew\n${GUIDELINES_MARKER_END}`;
  const out = injectGuidelinesIntoAgents(existing, block);

  // Full OMX region preserved
  assert.match(out, /<!-- omx:generated:agents-md -->\ncritical omx content with CLAUDE\.md reference\nanother omx line\n<!-- \/omx:generated:agents-md -->/);
});

test('injectGuidelinesIntoAgents: empty block removes existing section (deletion path)', () => {
  const existing = [
    'head',
    '',
    GUIDELINES_MARKER_START,
    'content',
    GUIDELINES_MARKER_END,
    '',
    'tail',
  ].join('\n');

  const out = injectGuidelinesIntoAgents(existing, '');
  assert.doesNotMatch(out, new RegExp(GUIDELINES_MARKER_START.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&')));
  assert.match(out, /head/);
  assert.match(out, /tail/);
});
