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
const descriptorPath = join(root, 'plugins', 'wiki', 'hooks', 'codex-hooks.json');
const descriptor = JSON.parse(readFileSync(descriptorPath, 'utf8'));
const probeRoot = mkdtempSync(join(tmpdir(), 'wiki-codex-hooks-'));
const probeScript = '#!/usr/bin/env bash\nprintf \'CODEX_HOOK_PROBE:%s\\n\' "$*"\n';
const gitLookup = spawnSync('where.exe', ['git.exe'], { encoding: 'utf8' });
assert.equal(gitLookup.status, 0, `git.exe must be on PATH: ${gitLookup.stderr || gitLookup.error || ''}`);
const gitExecutable = gitLookup.stdout.trim().split(/\r?\n/)[0];
const shimDir = join(probeRoot, 'git-shim');
mkdirSync(shimDir, { recursive: true });
writeFileSync(join(shimDir, 'git.cmd'), `@echo off\r\n"${gitExecutable}" %*\r\n`);
const probePath = [
  shimDir,
  join(process.env.SystemRoot, 'System32'),
  join(process.env.SystemRoot, 'System32', 'WindowsPowerShell', 'v1.0'),
].join(';');

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
        assert.doesNotMatch(
          hook.commandWindows,
          /Program Files\\Git/i,
          `${label} must not assume Git Bash is installed in the machine-wide default directory`,
        );
        assert.match(
          hook.commandWindows,
          /Get-Command git(?:\.exe)?/,
          `${label} must derive Git Bash from the Git executable on PATH`,
        );
        assert.match(hook.commandWindows, /--exec-path/, `${label} must resolve Git installations behind PATH shims`);

        const scriptMatch = hook.command.match(/\$\{PLUGIN_ROOT\}\/([^"']+\.sh)/);
        assert.ok(scriptMatch, `${label} must reference a PLUGIN_ROOT-relative shell script`);
        const probeScriptPath = join(probeRoot, ...scriptMatch[1].split('/'));
        mkdirSync(dirname(probeScriptPath), { recursive: true });
        writeFileSync(probeScriptPath, probeScript);

        const result = spawnSync(
          'powershell.exe',
          ['-NoProfile', '-NonInteractive', '-Command', hook.commandWindows],
          {
            cwd: probeRoot,
            env: { ...process.env, PATH: probePath, PLUGIN_ROOT: probeRoot },
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
  console.log(`ok: ${checked} wiki Codex hooks execute through PowerShell`);
} finally {
  rmSync(probeRoot, { recursive: true, force: true });
}
