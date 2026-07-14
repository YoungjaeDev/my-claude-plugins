#!/usr/bin/env node
// Fixture-driven self-check for the Codex hook-descriptor support in
// sync-codex-manifests.mjs. Builds throwaway plugin dirs in a temp dir and asserts:
//   - buildPluginManifest wires a source hooks/codex-hooks.json into manifest.hooks
//   - validatePluginHooks accepts a valid descriptor and rejects the malformed /
//     bad-shape / missing-script / orphan cases (mirrors the orphan-manifest guard).
// No framework, no deps. Run: node scripts/sync-codex-manifests.test.mjs

import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { buildPluginManifest, validatePluginHooks } from './sync-codex-manifests.mjs';

const root = mkdtempSync(join(tmpdir(), 'codex-hooks-'));

// Build a fixture plugin dir; returns its absolute path.
//   script     — relative script path to create (so a valid command resolves); null skips
//   descriptor — hooks/codex-hooks.json body (object -> JSON, string -> verbatim); undefined skips
//   gen        — .codex-plugin/plugin.json body (object); undefined skips
let seq = 0;
function fixture({ descriptor, script = 'hooks/prompt_inject.sh', gen } = {}) {
  const dir = join(root, `plugin-${seq++}`);
  mkdirSync(dir, { recursive: true });
  if (script) {
    mkdirSync(join(dir, 'hooks'), { recursive: true });
    writeFileSync(join(dir, script), '#!/usr/bin/env bash\n');
  }
  if (descriptor !== undefined) {
    mkdirSync(join(dir, 'hooks'), { recursive: true });
    writeFileSync(
      join(dir, 'hooks', 'codex-hooks.json'),
      typeof descriptor === 'string' ? descriptor : JSON.stringify(descriptor, null, 2),
    );
  }
  if (gen !== undefined) {
    mkdirSync(join(dir, '.codex-plugin'), { recursive: true });
    writeFileSync(join(dir, '.codex-plugin', 'plugin.json'), JSON.stringify(gen, null, 2));
  }
  return dir;
}

const VALID = {
  hooks: {
    UserPromptSubmit: [
      { hooks: [{ type: 'command', command: 'bash "$PLUGIN_ROOT/hooks/prompt_inject.sh" codex' }] },
    ],
  },
};

let passed = 0;
const scenario = (name, fn) => { fn(); passed++; console.log(`  ok  ${name}`); };

// 1. buildPluginManifest wires the descriptor into top-level hooks (path form).
scenario('descriptor is wired into manifest.hooks', () => {
  const dir = fixture({ descriptor: VALID });
  const manifest = buildPluginManifest({ name: 'demo', version: '1.0.0', description: 'd' }, dir);
  assert.equal(manifest.hooks, './hooks/codex-hooks.json', JSON.stringify(manifest));
});

// 1b. No descriptor -> no hooks field (guards a false-positive wiring).
scenario('no descriptor leaves manifest.hooks undefined', () => {
  const dir = fixture({});
  const manifest = buildPluginManifest({ name: 'demo', version: '1.0.0', description: 'd' }, dir);
  assert.equal(manifest.hooks, undefined, JSON.stringify(manifest));
});

// 2. Valid descriptor -> no violations.
scenario('valid descriptor passes', () => {
  const dir = fixture({ descriptor: VALID });
  assert.deepEqual(validatePluginHooks(dir), []);
});

// 3. Malformed JSON fails.
scenario('malformed descriptor fails', () => {
  const dir = fixture({ descriptor: '{ not json' });
  const v = validatePluginHooks(dir);
  assert.ok(v.some((e) => e.includes('malformed JSON')), JSON.stringify(v));
});

// 4. Unknown event name fails (bad shape).
scenario('unknown event fails', () => {
  const dir = fixture({ descriptor: { hooks: { NotAnEvent: [{ hooks: [{ type: 'command', command: 'echo hi' }] }] } } });
  const v = validatePluginHooks(dir);
  assert.ok(v.some((e) => e.includes('unknown hook event')), JSON.stringify(v));
});

// 4b. Non-array event value fails (bad shape).
scenario('non-array event fails', () => {
  const dir = fixture({ descriptor: { hooks: { Stop: 'nope' } } });
  const v = validatePluginHooks(dir);
  assert.ok(v.some((e) => e.includes('bad shape')), JSON.stringify(v));
});

// 4c. Entry missing command fails (bad shape).
scenario('entry without command fails', () => {
  const dir = fixture({ descriptor: { hooks: { Stop: [{ hooks: [{ type: 'command' }] }] } } });
  const v = validatePluginHooks(dir);
  assert.ok(v.some((e) => e.includes('bad shape')), JSON.stringify(v));
});

// 5. Referenced script that does not exist fails.
scenario('missing referenced script fails', () => {
  const dir = fixture({
    script: null,
    descriptor: { hooks: { Stop: [{ hooks: [{ type: 'command', command: 'bash "${PLUGIN_ROOT}/hooks/ghost.sh"' }] }] } },
  });
  const v = validatePluginHooks(dir);
  assert.ok(v.some((e) => e.includes('missing script')), JSON.stringify(v));
});

// 6. Orphan: generated manifest declares hooks but no source descriptor.
scenario('orphan generated hooks entry fails', () => {
  const dir = fixture({ gen: { name: 'demo', hooks: './hooks/codex-hooks.json' } });
  const v = validatePluginHooks(dir);
  assert.ok(v.some((e) => e.includes('orphan hooks')), JSON.stringify(v));
});

rmSync(root, { recursive: true, force: true });
console.log(`\nall ${passed} scenarios passed`);
