#!/usr/bin/env node
// SessionStart hook (.claude/settings.json): warn when the installed plugin cache
// lags this source tree. The Skill tool loads skills from
// ~/.claude/plugins/cache/my-claude-plugins/<plugin>/<version>/, and a cache that
// still holds an older version serves that one silently: a session ran dev 3.6.4's
// post-merge and had no review-loop at all while the tree was at 5.0.0.
//
// Prints one hook JSON line on drift, nothing otherwise. Never fails the session:
// any read error means "could not look", which is reported, not swallowed.
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const cache = process.env.PLUGIN_CACHE_DIR
  || join(homedir(), '.claude', 'plugins', 'cache', 'my-claude-plugins');

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

if (stale.length || unreadable) {
  const what = stale.length
    ? `plugin cache lags the source tree: ${stale.join('; ')}.`
    : `plugin cache check could not run: ${unreadable}.`;
  const fix = 'Refresh: rm -rf ~/.claude/plugins/cache/my-claude-plugins/, '
    + '/plugin marketplace update my-claude-plugins, restart Claude Code. '
    + 'Until then read skills from plugins/<name>/skills/<skill>/SKILL.md in this repo.';
  process.stdout.write(JSON.stringify({
    systemMessage: `my-claude-plugins: ${what} ${fix}`,
    hookSpecificOutput: { hookEventName: 'SessionStart', additionalContext: `${what} ${fix}` },
  }) + '\n');
}
