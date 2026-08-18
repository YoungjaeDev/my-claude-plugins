#!/usr/bin/env node

import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

if (process.platform !== 'win32') {
  console.log('skip: Windows Codex hook execution test requires powershell.exe');
  process.exit(0);
}

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const descriptorPath = join(root, 'plugins', 'llm-wiki', 'hooks', 'codex-hooks.json');
const descriptor = JSON.parse(readFileSync(descriptorPath, 'utf8'));
const probeRoot = mkdtempSync(join(tmpdir(), 'llm-wiki-codex-hooks-'));
const probeScript = '#!/usr/bin/env bash\nprintf \'CODEX_HOOK_PROBE:%s\\n\' "$*"\n';

try {
  let checked = 0;
  for (const [event, groups] of Object.entries(descriptor.hooks)) {
    for (const [groupIndex, group] of groups.entries()) {
      for (const [hookIndex, hook] of group.hooks.entries()) {
        const label = `${event}[${groupIndex}].hooks[${hookIndex}]`;
        assert.equal(
          typeof hook.commandWindows,
          'string',
          `${label} must provide a PowerShell-compatible commandWindows override`,
        );

        const scriptMatch = hook.command.match(/\$\{PLUGIN_ROOT\}\/([^"']+\.sh)/);
        assert.ok(scriptMatch, `${label} must reference a PLUGIN_ROOT-relative shell script`);
        const probePath = join(probeRoot, ...scriptMatch[1].split('/'));
        mkdirSync(dirname(probePath), { recursive: true });
        writeFileSync(probePath, probeScript);

        const result = spawnSync(
          'powershell.exe',
          ['-NoProfile', '-NonInteractive', '-Command', hook.commandWindows],
          {
            cwd: probeRoot,
            env: { ...process.env, PLUGIN_ROOT: probeRoot },
            encoding: 'utf8',
            input: '{}\n',
          },
        );

        assert.equal(
          result.status,
          0,
          `${label} failed via PowerShell (${basename(scriptMatch[1])}): ${result.stderr || result.error || ''}`,
        );
        assert.match(result.stdout, /CODEX_HOOK_PROBE:/, `${label} did not execute its shell script`);
        checked++;
      }
    }
  }

  assert.ok(checked > 0, 'descriptor must contain at least one command hook');
  console.log(`ok: ${checked} llm-wiki Codex hooks execute through PowerShell`);
} finally {
  rmSync(probeRoot, { recursive: true, force: true });
}
