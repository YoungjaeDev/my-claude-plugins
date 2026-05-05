import { test } from 'node:test';
import assert from 'node:assert/strict';

import { applyTransforms, transformSkillContent, DEFAULT_RULES } from '../scripts/sync.mjs';

test('applyTransforms: CLAUDE.md → AGENTS.md (literal)', () => {
  assert.equal(applyTransforms('see CLAUDE.md for details', DEFAULT_RULES), 'see AGENTS.md for details');
});

test('applyTransforms: .claude/ → .codex/ (literal, also covers ~/.claude/)', () => {
  assert.equal(applyTransforms('open .claude/settings.json', DEFAULT_RULES), 'open .codex/settings.json');
  assert.equal(applyTransforms('cd ~/.claude/plugins', DEFAULT_RULES), 'cd ~/.codex/plugins');
});

test('applyTransforms: namespace regex /<plugin>:<skill> → $<skill>', () => {
  assert.equal(applyTransforms('run /superpowers:brainstorming now', DEFAULT_RULES), 'run $brainstorming now');
  assert.equal(applyTransforms('try /github-dev:cr-fix here', DEFAULT_RULES), 'try $cr-fix here');
});

test('applyTransforms: namespace regex lookbehind blocks URL false positives', () => {
  assert.equal(
    applyTransforms('see https://x.io/foo:bar in docs', DEFAULT_RULES),
    'see https://x.io/foo:bar in docs',
  );
  assert.equal(
    applyTransforms('git@github.com:owner/repo.git', DEFAULT_RULES),
    'git@github.com:owner/repo.git',
  );
});

test('applyTransforms: leaves unrelated text unchanged', () => {
  const src = 'no special tokens here, just plain text.';
  assert.equal(applyTransforms(src, DEFAULT_RULES), src);
});

test('applyTransforms: empty string safe', () => {
  assert.equal(applyTransforms('', DEFAULT_RULES), '');
});

test('transformSkillContent: body transformed, frontmatter unchanged (bodyOnly contract)', () => {
  const src = [
    '---',
    'name: foo',
    'description: mentions CLAUDE.md and /plugin:skill on purpose',
    '---',
    '# Body',
    'use CLAUDE.md and .claude/ here',
  ].join('\n');

  const out = transformSkillContent(src, DEFAULT_RULES);

  assert.match(out, /^---\nname: foo\ndescription: mentions CLAUDE\.md and \/plugin:skill on purpose\n---\n/);
  assert.match(out, /use AGENTS\.md and \.codex\/ here/);
});

test('transformSkillContent: content without frontmatter transforms whole body', () => {
  const src = '# Plain\nuse .claude/ here';
  const out = transformSkillContent(src, DEFAULT_RULES);
  assert.match(out, /\.codex\//);
});

test('transformSkillContent: preserves frontmatter with bridge_source marker', () => {
  const src = [
    '---',
    'name: bar',
    'description: desc',
    'bridge_source: sample/bar',
    '---',
    'body /superpowers:brainstorming text',
  ].join('\n');

  const out = transformSkillContent(src, DEFAULT_RULES);

  assert.match(out, /bridge_source: sample\/bar/);
  assert.match(out, /body \$brainstorming text/);
});

test('DEFAULT_RULES: has 3 entries (literal x2, regex x1)', () => {
  assert.equal(DEFAULT_RULES.length, 3);
  const modes = new Set(DEFAULT_RULES.map(r => r.mode));
  assert.ok(modes.has('literal'));
  assert.ok(modes.has('regex'));
});
