import { test } from 'node:test';
import assert from 'node:assert/strict';

import { applyTransforms, transformSkillContent, DEFAULT_RULES } from '../scripts/sync.mjs';

test('applyTransforms: .omc/ → .omx/ (literal)', () => {
  assert.equal(applyTransforms('path .omc/state', DEFAULT_RULES), 'path .omx/state');
});

test('applyTransforms: CLAUDE.md → AGENTS.md (literal)', () => {
  assert.equal(applyTransforms('see CLAUDE.md for details', DEFAULT_RULES), 'see AGENTS.md for details');
});

test('applyTransforms: /oh-my-claudecode: → $ (literal)', () => {
  assert.equal(applyTransforms('run /oh-my-claudecode:autopilot now', DEFAULT_RULES), 'run $autopilot now');
});

test('applyTransforms: oh-my-claudecode → oh-my-codex (literal)', () => {
  assert.equal(applyTransforms('this is oh-my-claudecode docs', DEFAULT_RULES), 'this is oh-my-codex docs');
});

test('applyTransforms: ~/.claude/ → ~/.codex/ (literal)', () => {
  assert.equal(applyTransforms('cd ~/.claude/plugins', DEFAULT_RULES), 'cd ~/.codex/plugins');
});

test('applyTransforms: omc → omx (word-boundary only)', () => {
  assert.equal(applyTransforms('omc project', DEFAULT_RULES), 'omx project');
  assert.equal(applyTransforms('use omc, then', DEFAULT_RULES), 'use omx, then');
  // word-boundary means alphanumeric-adjacent "omc" is NOT replaced
  assert.equal(applyTransforms('economic', DEFAULT_RULES), 'economic');
});

test('applyTransforms: OMC → OMX (word-boundary, case-sensitive)', () => {
  assert.equal(applyTransforms('OMC runtime', DEFAULT_RULES), 'OMX runtime');
  // case-sensitive: "Omc" not matched (only OMC caps or omc lowercase)
  assert.equal(applyTransforms('mixed Omc', DEFAULT_RULES), 'mixed Omc');
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
    'description: mentions omc and CLAUDE.md on purpose',
    '---',
    '# Body',
    'use CLAUDE.md and .omc/ here',
  ].join('\n');

  const out = transformSkillContent(src, DEFAULT_RULES);

  // frontmatter MUST be unchanged (bodyOnly=true)
  assert.match(out, /^---\nname: foo\ndescription: mentions omc and CLAUDE\.md on purpose\n---\n/);
  // body MUST be transformed
  assert.match(out, /use AGENTS\.md and \.omx\/ here/);
});

test('transformSkillContent: content without frontmatter transforms whole body', () => {
  const src = '# Plain\nuse .omc/ here';
  const out = transformSkillContent(src, DEFAULT_RULES);
  assert.match(out, /\.omx\//);
});

test('transformSkillContent: preserves frontmatter with bridge_source marker', () => {
  const src = [
    '---',
    'name: bar',
    'description: desc',
    'bridge_source: sample/bar',
    '---',
    'body omc text',
  ].join('\n');

  const out = transformSkillContent(src, DEFAULT_RULES);

  assert.match(out, /bridge_source: sample\/bar/);
  assert.match(out, /body omx text/);
});

test('DEFAULT_RULES: has 7 entries as per spec', () => {
  assert.equal(DEFAULT_RULES.length, 7);
  const modes = new Set(DEFAULT_RULES.map(r => r.mode));
  assert.ok(modes.has('literal'));
  assert.ok(modes.has('word-boundary'));
});
