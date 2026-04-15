import { test } from 'node:test';
import assert from 'node:assert/strict';

import { commandToSkillContent, normalizeFrontmatterDescription } from '../scripts/sync.mjs';

test('commandToSkillContent: descriptions with colons are YAML-safe (quoted + colons preserved)', () => {
  const src = [
    '---',
    'description: Resolve GitHub Issue. Triggers: "bug", "fix"',
    '---',
    'body',
  ].join('\n');

  const out = commandToSkillContent(src, 'gh', 'resolve');
  // Must be double-quoted with internal quotes escaped
  assert.match(out, /description: "Resolve GitHub Issue\. Triggers: \\"bug\\", \\"fix\\""/);
});

test('commandToSkillContent: backslashes and quotes are escaped in description', () => {
  const src = '---\ndescription: Path C:\\foo with "quotes"\n---\nbody';
  const out = commandToSkillContent(src, 'p', 'c');
  assert.match(out, /description: "Path C:\\\\foo with \\"quotes\\""/);
});

test('normalizeFrontmatterDescription: multi-line description with colons gets quoted', () => {
  const src = [
    '---',
    'name: show-progress',
    'description: |',
    '  Display current workflow progress as ASCII visualization.',
    '  Trigger: "show progress"',
    'version: 1.0.0',
    '---',
    'body',
  ].join('\n');

  const out = normalizeFrontmatterDescription(src);
  const descLine = /^description: (.*)$/m.exec(out);
  assert.ok(descLine, 'expected description field');
  // Should be double-quoted and contain escaped inner quotes
  assert.ok(descLine[1].startsWith('"') && descLine[1].endsWith('"'),
    `expected quoted value, got: ${descLine[1]}`);
  assert.match(descLine[1], /Trigger: \\"show progress\\"/);
  // Other fields preserved
  assert.match(out, /name: show-progress/);
  assert.match(out, /version: 1\.0\.0/);
});

test('normalizeFrontmatterDescription: single-line description without special chars still works (idempotent-ish)', () => {
  const src = [
    '---',
    'name: simple',
    'description: Plain description, no colons or quotes',
    '---',
    'body',
  ].join('\n');

  const out = normalizeFrontmatterDescription(src);
  // Single-line non-block-scalar descriptions are left alone (no pipe indicator)
  assert.match(out, /description: Plain description, no colons or quotes/);
});
