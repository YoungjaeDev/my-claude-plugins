import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';

import {
  discoverCommands,
  commandToSkillContent,
  syncCommand,
  DEFAULT_RULES,
} from '../scripts/sync.mjs';

async function freshTmp() {
  return fs.mkdtemp(path.join(os.tmpdir(), 'codex-bridge-cmd-'));
}

async function makeCommandFile(root, plugin, command, content) {
  const dir = path.join(root, 'plugins', plugin, 'commands');
  await fs.mkdir(dir, { recursive: true });
  const filePath = path.join(dir, `${command}.md`);
  await fs.writeFile(filePath, content);
  return { pluginName: plugin, commandName: command, sourcePath: filePath };
}

test('discoverCommands: finds commands/*.md in every plugin', async () => {
  const tmp = await freshTmp();
  try {
    await makeCommandFile(tmp, 'alpha', 'do-thing', '---\ndescription: A\n---\nbody');
    await makeCommandFile(tmp, 'alpha', 'other', '---\ndescription: B\n---\nbody');
    await makeCommandFile(tmp, 'beta', 'cmd', '---\ndescription: C\n---\nbody');

    const cmds = await discoverCommands(path.join(tmp, 'plugins'));
    assert.equal(cmds.length, 3);
    const keys = cmds.map(c => `${c.pluginName}/${c.commandName}`).sort();
    assert.deepEqual(keys, ['alpha/do-thing', 'alpha/other', 'beta/cmd']);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('discoverCommands: targetSkillName uses <plugin>-<command> prefix', async () => {
  const tmp = await freshTmp();
  try {
    await makeCommandFile(tmp, 'github-dev', 'resolve-issue', '---\ndescription: x\n---\n');

    const cmds = await discoverCommands(path.join(tmp, 'plugins'));
    assert.equal(cmds.length, 1);
    assert.equal(cmds[0].targetSkillName, 'github-dev-resolve-issue');
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('discoverCommands: returns sorted output (pluginName, commandName)', async () => {
  const tmp = await freshTmp();
  try {
    await makeCommandFile(tmp, 'zebra', 'z', '---\ndescription: z\n---\n');
    await makeCommandFile(tmp, 'alpha', 'b', '---\ndescription: b\n---\n');
    await makeCommandFile(tmp, 'alpha', 'a', '---\ndescription: a\n---\n');

    const cmds = await discoverCommands(path.join(tmp, 'plugins'));
    const order = cmds.map(c => c.targetSkillName);
    assert.deepEqual(order, ['alpha-a', 'alpha-b', 'zebra-z']);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('discoverCommands: returns [] when plugins dir missing', async () => {
  const tmp = await freshTmp();
  try {
    const cmds = await discoverCommands(path.join(tmp, 'nope'));
    assert.deepEqual(cmds, []);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('commandToSkillContent: builds Codex-compatible frontmatter from command with description', () => {
  const src = [
    '---',
    'description: Analyze Git changes and commit',
    '---',
    '# Commit & Push',
    'body here',
  ].join('\n');

  const out = commandToSkillContent(src, 'github-dev', 'commit-and-push');
  assert.match(out, /^---\nname: github-dev-commit-and-push\n/);
  assert.match(out, /description: "Analyze Git changes and commit"/);
  assert.match(out, /bridge_source: github-dev\/commands\/commit-and-push/);
  assert.match(out, /# Commit & Push/);
  assert.match(out, /body here/);
});

test('commandToSkillContent: synthesizes description when frontmatter missing', () => {
  const src = '# Heading\nbody';
  const out = commandToSkillContent(src, 'myplug', 'mycommand');
  assert.match(out, /name: myplug-mycommand/);
  // fallback description must exist and be single-line
  const descMatch = /^description: (.+)$/m.exec(out);
  assert.ok(descMatch, 'expected description field');
  assert.ok(descMatch[1].length > 0);
  assert.doesNotMatch(descMatch[1], /\n/);
});

test('commandToSkillContent: strips Claude Code-only fields (allowed-tools, argument-hint)', () => {
  const src = [
    '---',
    'description: X',
    'allowed-tools:',
    '  - Read',
    '  - Bash',
    'argument-hint: <path>',
    '---',
    'body',
  ].join('\n');

  const out = commandToSkillContent(src, 'p', 'c');
  assert.doesNotMatch(out, /allowed-tools:/);
  assert.doesNotMatch(out, /argument-hint:/);
  assert.match(out, /description: "X"/);
});

test('commandToSkillContent: flattens multi-line description to single line', () => {
  const src = [
    '---',
    'description: |',
    '  First line.',
    '  Second line.',
    '---',
    'body',
  ].join('\n');

  const out = commandToSkillContent(src, 'p', 'c');
  const descMatch = /^description: (.+)$/m.exec(out);
  assert.ok(descMatch, 'expected description field');
  assert.doesNotMatch(descMatch[1], /^\|/);
  assert.match(descMatch[1], /First line\. Second line\./);
});

test('syncCommand: writes <plugin>-<command>/SKILL.md with bridge_source marker', async () => {
  const tmp = await freshTmp();
  try {
    const cmd = await makeCommandFile(
      tmp, 'github-dev', 'resolve-issue',
      '---\ndescription: Resolve a GitHub issue\n---\n# Heading\nbody text with .claude/ path'
    );
    cmd.targetSkillName = 'github-dev-resolve-issue';
    const targetRoot = path.join(tmp, 'target', '.agents', 'skills');

    const result = await syncCommand(cmd, targetRoot, DEFAULT_RULES);

    assert.equal(result.status, 'synced');
    const skillDir = path.join(targetRoot, 'github-dev-resolve-issue');
    const written = await fs.readFile(path.join(skillDir, 'SKILL.md'), 'utf-8');

    assert.match(written, /^---\nname: github-dev-resolve-issue\n/);
    assert.match(written, /description: "Resolve a GitHub issue"/);
    assert.match(written, /bridge_source: github-dev\/commands\/resolve-issue/);
    // body transformed: .claude/ -> .codex/
    assert.match(written, /\.codex\// );
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test('syncCommand: skipped when target exists without bridge_source (collision guard)', async () => {
  const tmp = await freshTmp();
  try {
    const cmd = await makeCommandFile(
      tmp, 'p', 'c',
      '---\ndescription: x\n---\nnew body'
    );
    cmd.targetSkillName = 'p-c';
    const targetRoot = path.join(tmp, 'target', '.agents', 'skills');
    const existingDir = path.join(targetRoot, 'p-c');
    await fs.mkdir(existingDir, { recursive: true });
    await fs.writeFile(
      path.join(existingDir, 'SKILL.md'),
      '---\nname: p-c\ndescription: user-owned\n---\npre-existing'
    );

    const result = await syncCommand(cmd, targetRoot, DEFAULT_RULES);

    assert.equal(result.status, 'skipped');
    assert.equal(result.reason, 'non-managed-collision');
    const still = await fs.readFile(path.join(existingDir, 'SKILL.md'), 'utf-8');
    assert.match(still, /pre-existing/);
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }
});
