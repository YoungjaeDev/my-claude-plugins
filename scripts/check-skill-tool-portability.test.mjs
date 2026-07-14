#!/usr/bin/env node
// Fixture-driven self-check for check-skill-tool-portability.mjs. Builds throwaway
// plugin trees in a temp dir and asserts the guard's four failure modes fire (and the
// happy path passes). No framework, no deps. Run: node scripts/check-skill-tool-portability.test.mjs

import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { checkSkillToolPortability } from './check-skill-tool-portability.mjs';

const root = mkdtempSync(join(tmpdir(), 'skill-portability-'));
const write = (rel, body) => {
  const abs = join(root, rel);
  mkdirSync(dirname(abs), { recursive: true });
  writeFileSync(abs, body);
};

// A body with an unmapped interactive gate (Claude-only assumption).
const UNMAPPED = '# Fixture\n\nUse AskUserQuestion to confirm.\n';
// The same body once migrated to the standardized cross-runtime mapping.
const MAPPED =
  '# Fixture\n\n> Cross-runtime interactive input — Claude AskUserQuestion; ' +
  'Codex request_user_input when exposed; Hermes clarify.\n\nUse the gate to confirm.\n';
// A body with the debt removed entirely (no interactive gate at all).
const NO_GATE = '# Fixture\n\nNothing interactive here.\n';

let passed = 0;
const scenario = (name, fn) => { fn(); passed++; console.log(`  ok  ${name}`); };

// 1. A new/unmapped pilot FAILS before mapping, PASSES after (red -> green).
scenario('pilot unmapped fails, mapped passes', () => {
  const rel = 'plugins/demo/skills/demo/SKILL.md';
  write(rel, UNMAPPED);
  const red = checkSkillToolPortability({ root, pilots: [rel], baseline: [] });
  assert.ok(red.errors.some((e) => e.includes('missing the standardized')), `expected red, got ${JSON.stringify(red.errors)}`);

  write(rel, MAPPED);
  const green = checkSkillToolPortability({ root, pilots: [rel], baseline: [] });
  assert.equal(green.errors.length, 0, `expected green, got ${JSON.stringify(green.errors)}`);
});

// 2. A stale baseline entry (debt removed) FAILS.
scenario('stale baseline entry fails', () => {
  const rel = 'plugins/stale/skills/stale/SKILL.md';
  write(rel, NO_GATE);
  const { errors } = checkSkillToolPortability({ root, pilots: [], baseline: [rel] });
  assert.ok(errors.some((e) => e.includes('stale entry') && e.includes(rel)), JSON.stringify(errors));
});

// 2b. A baseline entry pointing at a missing file FAILS as stale.
scenario('missing-file baseline entry fails', () => {
  const rel = 'plugins/gone/skills/gone/SKILL.md';
  const { errors } = checkSkillToolPortability({ root, pilots: [], baseline: [rel] });
  assert.ok(errors.some((e) => e.includes('stale entry') && e.includes('file not found')), JSON.stringify(errors));
});

// 3. A duplicate baseline entry FAILS.
scenario('duplicate baseline entry fails', () => {
  const rel = 'plugins/dup/skills/dup/SKILL.md';
  write(rel, UNMAPPED);
  const { errors } = checkSkillToolPortability({ root, pilots: [], baseline: [rel, rel] });
  assert.ok(errors.some((e) => e.includes('duplicate entry')), JSON.stringify(errors));
});

// 4. An unaccounted skill in the tree (neither pilot nor baseline) FAILS.
scenario('unaccounted AskUserQuestion skill fails', () => {
  const sub = mkdtempSync(join(tmpdir(), 'skill-portability-sub-'));
  const rel = 'plugins/rogue/skills/rogue/SKILL.md';
  mkdirSync(join(sub, dirname(rel)), { recursive: true });
  writeFileSync(join(sub, rel), UNMAPPED);
  const { errors } = checkSkillToolPortability({ root: sub, pilots: [], baseline: [] });
  rmSync(sub, { recursive: true, force: true });
  assert.ok(errors.some((e) => e.includes('unaccounted') && e.includes(rel)), JSON.stringify(errors));
});

// 5. Malformed baseline entry FAILS.
scenario('malformed baseline entry fails', () => {
  const { errors } = checkSkillToolPortability({ root, pilots: [], baseline: ['not/a/skill/path.md'] });
  assert.ok(errors.some((e) => e.includes('malformed entry')), JSON.stringify(errors));
});

rmSync(root, { recursive: true, force: true });
console.log(`\nall ${passed} scenarios passed`);
