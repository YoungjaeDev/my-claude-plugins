#!/usr/bin/env node
// SessionStart hook (.claude/settings.json): warn when the installed plugin cache
// lags this source tree. The Skill tool loads skills from
// ~/.claude/plugins/cache/my-claude-plugins/<plugin>/<version>/, and a cache that
// still holds an older version serves that one silently: a session ran dev 3.6.4's
// post-merge and had no review-loop at all while the tree was at 5.0.0.
//
// Also warns when core.hooksPath is not the relative `.githooks`.
//
// Prints one hook JSON line when either check fires, nothing otherwise. Never fails the session:
// any read error means "could not look", which is reported, not swallowed.
import { readdirSync, readFileSync, existsSync, mkdtempSync, mkdirSync, rmSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { homedir, tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

if (process.argv.includes('--selftest')) { selftest(); process.exit(0); }

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
// CLAUDE_CODE_PLUGIN_CACHE_DIR is Claude Code's plugins root (the cache lives under
// it, despite the name); PLUGIN_CACHE_DIR overrides the full cache path.
const pluginRoot = process.env.CLAUDE_CODE_PLUGIN_CACHE_DIR || join(homedir(), '.claude', 'plugins');
const cache = process.env.PLUGIN_CACHE_DIR || join(pluginRoot, 'cache', 'my-claude-plugins');

const stale = [];
let unreadable = '';
try {
  for (const name of readdirSync(join(root, 'plugins'))) {
    const manifest = join(root, 'plugins', name, '.claude-plugin', 'plugin.json');
    if (!existsSync(manifest)) continue;
    const want = JSON.parse(readFileSync(manifest, 'utf8')).version;
    const dir = join(cache, name);
    if (!existsSync(dir)) continue; // not installed from the cache: nothing to lag
    const have = readdirSync(dir).filter((v) => !v.startsWith('.'));
    // Any other version left beside the current one can be the one that loads.
    if (!have.includes(want) || have.some((v) => v !== want)) {
      stale.push(`${name} (source ${want}, cache ${have.join(', ') || 'empty'})`);
    }
  }
} catch (err) {
  unreadable = String(err && err.message || err);
}

const notes = [];
if (stale.length || unreadable) {
  const what = stale.length
    ? `plugin cache lags the source tree: ${stale.join('; ')}.`
    : `plugin cache check could not run: ${unreadable}.`;
  notes.push(`${what} Refresh: rm -rf ~/.claude/plugins/cache/my-claude-plugins/, `
    + '/plugin marketplace update my-claude-plugins, restart Claude Code. '
    + 'Until then read skills from plugins/<name>/skills/<skill>/SKILL.md in this repo.');
}

// core.hooksPath must be the relative `.githooks`. An absolute path makes every
// worktree run the main checkout's hook (and its guards) instead of its own; unset
// means the pre-commit guards never run. Found set absolute twice in one session.
const project = process.env.CLAUDE_PROJECT_DIR || root;
const hooksFix = 'Fix: git config core.hooksPath .githooks';
try {
  const hooksPath = execFileSync('git', ['-C', project, 'config', 'core.hooksPath'], { stdio: ['ignore', 'pipe', 'pipe'] })
    .toString().trim();
  if (hooksPath.startsWith('/') || /^[A-Za-z]:[\\/]/.test(hooksPath)) {
    notes.push(`core.hooksPath is absolute (${hooksPath}), so worktrees run that checkout's hook. ${hooksFix}.`);
  } else if (hooksPath !== '.githooks') {
    notes.push(`core.hooksPath is "${hooksPath}", not .githooks, so the pre-commit guards do not run. ${hooksFix}.`);
  }
} catch (err) {
  // `git config` exits 1 with no output when the key is unset; anything else is a failure.
  if (err.status === 1 && !String(err.stderr || '').trim()) {
    notes.push(`core.hooksPath is unset, so the pre-commit guards do not run. ${hooksFix}.`);
  } else {
    notes.push(`core.hooksPath check could not run: ${String(err.stderr || err.message).trim()}.`);
  }
}

if (notes.length) {
  const text = notes.join(' ');
  process.stdout.write(JSON.stringify({
    systemMessage: `my-claude-plugins: ${text}`,
    hookSpecificOutput: { hookEventName: 'SessionStart', additionalContext: text },
  }) + '\n');
}

function selftest() {
  const tmp = mkdtempSync(join(tmpdir(), 'plugin-cache-'));
  const env = { ...process.env };
  for (const k of Object.keys(env)) if (k.startsWith('GIT_')) delete env[k];
  // Same result on every machine: no global/system git config (a global core.hooksPath
  // would fake the "unset" case), and the cache is always a fixture, never ~/.claude.
  Object.assign(env, { GIT_CONFIG_GLOBAL: '/dev/null', GIT_CONFIG_NOSYSTEM: '1' });
  delete env.CLAUDE_CODE_PLUGIN_CACHE_DIR;
  const repo = (name, hooksPath) => {
    const dir = join(tmp, name);
    mkdirSync(dir);
    execFileSync('git', ['init', '-q', dir], { env });
    if (hooksPath) execFileSync('git', ['-C', dir, 'config', 'core.hooksPath', hooksPath], { env });
    return dir;
  };
  const staleCache = join(tmp, 'stale');
  mkdirSync(join(staleCache, 'dev', '0.0.1'), { recursive: true });
  const emptyCache = join(tmp, 'empty');
  mkdirSync(emptyCache);
  const run = (cache, project) => execFileSync(process.execPath, [fileURLToPath(import.meta.url)], {
    env: { ...env, PLUGIN_CACHE_DIR: cache, CLAUDE_PROJECT_DIR: project },
  }).toString();
  const cases = [
    ['both fire: one merged line', staleCache, repo('unset'), [/plugin cache lags/, /core\.hooksPath is unset/]],
    ['clean: silent', emptyCache, repo('ok', '.githooks'), null],
    ['absolute hooksPath', emptyCache, repo('abs', '/elsewhere/.githooks'), [/core\.hooksPath is absolute/]],
    ['other relative hooksPath', emptyCache, repo('other', 'hooks'), [/core\.hooksPath is "hooks"/]],
    ['git failure reports, never throws', emptyCache, join(tmp, 'missing'), [/core\.hooksPath check could not run/]],
  ];
  const failures = [];
  for (const [name, cache, project, want] of cases) {
    let out;
    try { out = run(cache, project); } catch (err) { failures.push(`${name}: exited ${err.status}`); continue; }
    if (!want) { if (out) failures.push(`${name}: printed ${out}`); continue; }
    const lines = out.split('\n').filter(Boolean);
    if (lines.length !== 1) { failures.push(`${name}: ${lines.length} lines`); continue; }
    const msg = JSON.parse(lines[0]).systemMessage;
    for (const re of want) if (!re.test(msg)) failures.push(`${name}: ${re} not in "${msg}"`);
  }
  rmSync(tmp, { recursive: true, force: true });
  if (failures.length) {
    console.error('check-plugin-cache SELFTEST FAILED:');
    for (const f of failures) console.error(`  ${f}`);
    process.exit(1);
  }
  console.log(`check-plugin-cache selftest OK — ${cases.length} cases`);
}
