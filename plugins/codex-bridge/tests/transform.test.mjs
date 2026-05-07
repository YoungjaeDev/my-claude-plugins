import { test } from 'node:test';
import assert from 'node:assert/strict';

import { applyTransforms, transformSkillContent, agentToCodexToml, DEFAULT_RULES } from '../scripts/sync.mjs';

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

test('agentToCodexToml: basic structure with name, description, developer_instructions', () => {
  const src = [
    '---',
    'name: scout',
    'description: A short description',
    '---',
    '# Body',
    'content here',
  ].join('\n');

  const out = agentToCodexToml(src, 'code-scout', 'scout', DEFAULT_RULES);

  assert.match(out, /^# bridge_source = "code-scout\/agents\/scout"/m);
  assert.match(out, /^name = "code-scout-scout"$/m);
  assert.match(out, /^description = "A short description"$/m);
  assert.match(out, /^developer_instructions = """$/m);
  assert.match(out, /# Body/);
  assert.match(out, /content here/);
});

test('agentToCodexToml: flattens multi-line description (block scalar |)', () => {
  const src = [
    '---',
    'name: a',
    'description: |',
    '  Code and ML resource scout. Finds boilerplates, starter templates, reference implementations,',
    '  and ML models/datasets across GitHub and Hugging Face.',
    '---',
    'body',
  ].join('\n');

  const out = agentToCodexToml(src, 'code-scout', 'a', DEFAULT_RULES);
  const m = /^description = (.+)$/m.exec(out);
  assert.ok(m, 'expected description field');
  // single line, no embedded newline literal
  assert.doesNotMatch(m[1], /\n/);
  assert.match(m[1], /^"Code and ML resource scout\. Finds boilerplates, starter templates, reference implementations, and ML models\/datasets across GitHub and Hugging Face\."$/);
});

test('agentToCodexToml: preserves model/skills/tools as # original-* comments', () => {
  const src = [
    '---',
    'name: scout',
    'description: x',
    'model: haiku',
    'skills: resource-finder',
    'tools: Bash, Read',
    '---',
    'body',
  ].join('\n');

  const out = agentToCodexToml(src, 'p', 'scout', DEFAULT_RULES);
  assert.match(out, /^# original-model = "haiku"$/m);
  assert.match(out, /^# original-skills = "resource-finder"$/m);
  assert.match(out, /^# original-tools = "Bash, Read"$/m);
  // and these are NOT real TOML keys
  assert.doesNotMatch(out, /^model = /m);
  assert.doesNotMatch(out, /^skills = /m);
  assert.doesNotMatch(out, /^tools = /m);
});

test('agentToCodexToml: omits # original-* comment when field missing', () => {
  const src = [
    '---',
    'name: a',
    'description: x',
    '---',
    'body',
  ].join('\n');

  const out = agentToCodexToml(src, 'p', 'a', DEFAULT_RULES);
  assert.doesNotMatch(out, /original-model/);
  assert.doesNotMatch(out, /original-skills/);
  assert.doesNotMatch(out, /original-tools/);
});

test('agentToCodexToml: body transforms applied (.claude/ -> .codex/)', () => {
  const src = [
    '---',
    'name: a',
    'description: x',
    '---',
    'see CLAUDE.md and .claude/ here',
  ].join('\n');

  const out = agentToCodexToml(src, 'p', 'a', DEFAULT_RULES);
  assert.match(out, /AGENTS\.md/);
  assert.match(out, /\.codex\//);
  assert.doesNotMatch(out, /CLAUDE\.md/);
});

test('agentToCodexToml: description fields with quotes escaped', () => {
  const src = [
    '---',
    'name: a',
    'description: contains "quotes" and \\backslash',
    '---',
    'body',
  ].join('\n');

  const out = agentToCodexToml(src, 'p', 'a', DEFAULT_RULES);
  const m = /^description = (.+)$/m.exec(out);
  assert.ok(m);
  // double-quote and backslash are escaped
  assert.match(m[1], /\\"quotes\\"/);
  assert.match(m[1], /\\\\backslash/);
});

test('agentToCodexToml: body backslashes escaped for TOML basic multiline string', () => {
  const src = [
    '---',
    'name: a',
    'description: x',
    '---',
    'regex: \\b\\w+\\b',
  ].join('\n');

  const out = agentToCodexToml(src, 'p', 'a', DEFAULT_RULES);
  // Original backslashes must be doubled (TOML basic string escape)
  assert.match(out, /regex: \\\\b\\\\w\+\\\\b/);
});

test('agentToCodexToml: body containing """ is escaped to not terminate the string', () => {
  const src = [
    '---',
    'name: a',
    'description: x',
    '---',
    'example: """python code"""',
  ].join('\n');

  const out = agentToCodexToml(src, 'p', 'a', DEFAULT_RULES);
  // First triple-quote must be escaped so it does not terminate the developer_instructions block
  // Output of literal `"""` is escape sequence `\"""` (backslash + three quotes)
  assert.match(out, /\\"""python code\\"""/);
  // structure: developer_instructions = """...""" still ends with a closing """
  const tail = out.trim().split('\n').slice(-2).join('\n');
  assert.match(tail, /"""\s*$/);
});

test('agentToCodexToml: developer_instructions block opens with triple-quote on its own line and closes likewise', () => {
  const src = '---\nname: a\ndescription: x\n---\nbody line 1\nbody line 2\n';
  const out = agentToCodexToml(src, 'p', 'a', DEFAULT_RULES);
  // TOML basic multi-line string trims the immediate newline after opening """,
  // so "body line 1" should appear immediately after a newline post-open.
  assert.match(out, /developer_instructions = """\nbody line 1\nbody line 2/);
  assert.match(out, /\n"""\s*$/);
});

test('agentToCodexToml: bridge_source comment uses agents/<name> path', () => {
  const src = '---\nname: scout\ndescription: x\n---\nbody';
  const out = agentToCodexToml(src, 'code-scout', 'scout', DEFAULT_RULES);
  // First line is the bridge_source marker (prune relies on this)
  assert.equal(out.split('\n')[0], '# bridge_source = "code-scout/agents/scout"');
});
