#!/usr/bin/env node
// Version-bump helper. Every pair of parallel or stacked PRs used to conflict on the
// version lines of .claude-plugin/marketplace.json and plugins/<name>/.claude-plugin/
// plugin.json, and each conflict was resolved by hand. This computes the versions from
// the base ref instead, so after a merge you take either side and re-run it.
//
//   node scripts/bump-version.mjs <plugin>... [--minor|--major] [--base origin/main]
//   node scripts/bump-version.mjs --selftest
//   node scripts/bump-version.mjs --check [--base origin/main]
//
// --check is the guard (verify chain, pre-commit, CI): it fails when a plugin's files
// changed against base and its version is not above base's, including a commit that
// goes straight onto base (review-loop's base push). See check() for what "changed" is.
//
// Each named plugin goes to max(current, base bumped at the level): patch by default.
// metadata.version goes to max(current, base MINOR+1). Re-running is a no-op, and a
// base that moved past this branch pushes both above it. Writes plugin.json and the
// marketplace entry together. Zero-dep: Node 18+ builtins only.

import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const MARKET = '.claude-plugin/marketplace.json';
const manifest = (name) => `plugins/${name}/.claude-plugin/plugin.json`;

const parse = (v) => {
  const m = /^(\d+)\.(\d+)\.(\d+)$/.exec(v || '');
  if (!m) throw new Error(`not a MAJOR.MINOR.PATCH version: ${v}`);
  return m.slice(1).map(Number);
};
const cmp = (a, b) => { const x = parse(a); const y = parse(b); return x[0] - y[0] || x[1] - y[1] || x[2] - y[2]; };
const max = (...vs) => vs.reduce((a, b) => (cmp(a, b) >= 0 ? a : b));
const next = (v, level) => {
  const [M, m, p] = parse(v);
  return level === 'major' ? `${M + 1}.0.0` : level === 'minor' ? `${M}.${m + 1}.0` : `${M}.${m}.${p + 1}`;
};

/** Returns the change lines; throws on an unknown plugin or an unreadable base. */
function bump(root, names, level, base, env = process.env) {
  const read = (rel) => JSON.parse(readFileSync(join(root, rel), 'utf8'));
  const save = (rel, obj) => writeFileSync(join(root, rel), JSON.stringify(obj, null, 2) + '\n');
  const atBase = (rel) => {
    try {
      return JSON.parse(execFileSync('git', ['-C', root, 'show', `${base}:${rel}`], { env, stdio: ['ignore', 'pipe', 'pipe'] }).toString());
    } catch (err) {
      if (rel === MARKET) throw new Error(`cannot read ${base}:${rel}: ${String(err.stderr || err.message).trim()}`);
      return null; // plugin added on this branch: no base version to bump past
    }
  };
  const market = read(MARKET);
  const baseMarket = atBase(MARKET);
  const changes = [];
  const plugins = [];
  // Compute and validate everything first: a bad later name must leave every file untouched.
  for (const name of names) {
    const entry = market.plugins.find((p) => p.name === name);
    if (!entry) throw new Error(`no plugin "${name}" in ${MARKET}`);
    const plugin = read(manifest(name));
    const baseVer = atBase(manifest(name))?.version;
    const cur = max(entry.version, plugin.version);
    const want = baseVer ? max(cur, next(baseVer, level)) : cur;
    if (entry.version !== want || plugin.version !== want) changes.push(`${name}: ${cur} -> ${want}`);
    entry.version = want;
    plugin.version = want;
    plugins.push([name, plugin]);
  }
  const [M, m] = parse(baseMarket.metadata.version);
  const meta = max(market.metadata.version, `${M}.${m + 1}.0`);
  if (meta !== market.metadata.version) changes.push(`metadata: ${market.metadata.version} -> ${meta}`);
  market.metadata.version = meta;
  for (const [name, plugin] of plugins) save(manifest(name), plugin);
  save(MARKET, market);
  return changes;
}

/**
 * The guard (--check): every plugin this branch changed must be above base. Returns
 * the failure lines. "Changed" is a path under plugins/<name>/ that differs both from
 * the merge-base (this branch touched it) and from base (it is not just base's own
 * newer content): a branch that merged base in, or one base moved past, is not blamed
 * for base's changes. Versions are read from the index, which is the commit a
 * pre-commit hook is checking (the verify chain stages everything first). A plugin new
 * on this branch has no base version to exceed. Throws when base cannot be read.
 */
function check(root, base, env = process.env) {
  const git = (...a) => execFileSync('git', ['-C', root, ...a], { env, stdio: ['ignore', 'pipe', 'pipe'] }).toString();
  let mb;
  try { mb = git('merge-base', base, 'HEAD').trim(); } catch (err) {
    throw new Error(`cannot find the merge-base with ${base} (fetch it, or pass --base): ${String(err.stderr || err.message).trim()}`);
  }
  // --no-renames: a file moved between plugins must count for both, not just the new one.
  const touched = (ref) => new Set(git('diff', '--cached', '--no-renames', '--name-only', '-z', ref, '--', 'plugins/')
    .split('\0').map((p) => /^plugins\/([^/]+)\//.exec(p)?.[1]).filter(Boolean));
  const fromBase = touched(base);
  const names = [...touched(mb)].filter((n) => fromBase.has(n)).sort();
  const show = (spec) => { try { return JSON.parse(git('show', spec)); } catch { return null; } };
  const failures = [];
  const market = show(`:${MARKET}`);
  const baseMarket = show(`${base}:${MARKET}`);
  if (!baseMarket) throw new Error(`cannot read ${base}:${MARKET}`);
  let bumped = false;
  for (const name of names) {
    const baseVer = show(`${base}:${manifest(name)}`)?.version;
    const plugin = show(`:${manifest(name)}`);
    // Added or removed on this branch: no version pair to compare, but the release
    // counter (metadata.version) still has to move.
    if (!baseVer || !plugin) { if (baseVer || plugin) bumped = true; continue; }
    const entry = market?.plugins?.find((p) => p.name === name)?.version;
    for (const [where, v] of [[manifest(name), plugin.version], [`${MARKET} (${name})`, entry]]) {
      if (!v || cmp(v, baseVer) <= 0) {
        failures.push(`plugins/${name}/ changed since ${base} but ${where} is ${v || 'missing'}, not above ${base}'s ${baseVer}: run node scripts/bump-version.mjs ${name}`);
      }
    }
    bumped = true;
  }
  // metadata.version against the merge-base: did this branch move it at all. Against
  // base it would fail every commit on a branch a sibling release overtook.
  const mbMeta = show(`${mb}:${MARKET}`)?.metadata?.version || '0.0.0';
  if (bumped && cmp(market?.metadata?.version || '0.0.0', mbMeta) <= 0) {
    failures.push(`a plugin version moved but metadata.version ${market?.metadata?.version} is not above ${mbMeta}: run node scripts/bump-version.mjs <plugin>`);
  }
  return failures;
}

/** {names, level, base} from argv; throws on an unknown option, two levels, or no plugin. */
function parseArgs(args) {
  const out = { names: [], level: 'patch', base: 'origin/main' };
  let levels = 0;
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--minor' || a === '--major') { out.level = a.slice(2); levels++; }
    else if (a === '--base') {
      out.base = args[++i];
      if (!out.base || out.base.startsWith('--')) throw new Error('--base needs a ref');
    } else if (a.startsWith('-')) throw new Error(`unknown option ${a}`);
    else out.names.push(a);
  }
  if (levels > 1) throw new Error('only one of --minor, --major');
  if (!out.names.length) throw new Error('no plugin named');
  return out;
}

function selftest() {
  const dir = mkdtempSync(join(tmpdir(), 'bump-version-'));
  // The pre-commit hook exports GIT_INDEX_FILE / GIT_DIR; a throwaway repo must not inherit them.
  const env = { ...process.env };
  for (const k of Object.keys(env)) if (k.startsWith('GIT_')) delete env[k];
  // No global/system git config, so a local commit.gpgsign or hook cannot change the result.
  Object.assign(env, { GIT_CONFIG_GLOBAL: '/dev/null', GIT_CONFIG_NOSYSTEM: '1' });
  const git = (...a) => execFileSync('git', ['-C', dir, ...a], { env, stdio: ['ignore', 'pipe', 'pipe'] }).toString();
  const write = (rel, obj) => {
    mkdirSync(join(dir, rel, '..'), { recursive: true });
    writeFileSync(join(dir, rel), JSON.stringify(obj, null, 2) + '\n');
  };
  const market = (meta, a, b) => ({ name: 'm', metadata: { version: meta }, plugins: [{ name: 'a', version: a }, { name: 'b', version: b }] });
  const state = () => {
    const m = JSON.parse(readFileSync(join(dir, '.claude-plugin/marketplace.json'), 'utf8'));
    const pa = JSON.parse(readFileSync(join(dir, 'plugins/a/.claude-plugin/plugin.json'), 'utf8'));
    return `${m.metadata.version} a=${m.plugins[0].version}/${pa.version} b=${m.plugins[1].version}`;
  };
  const failures = [];
  const expect = (name, want) => { const got = state(); if (got !== want) failures.push(`${name}: got "${got}", want "${want}"`); };
  try {
    git('init', '-q', '-b', 'main');
    write('.claude-plugin/marketplace.json', market('2.59.0', '5.0.5', '1.0.0'));
    write('plugins/a/.claude-plugin/plugin.json', { name: 'a', version: '5.0.5' });
    write('plugins/b/.claude-plugin/plugin.json', { name: 'b', version: '1.0.0' });
    const commit = (msg) => git('-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-qam', msg);
    git('add', '-A');
    commit('base');
    // A sibling PR that landed first: base moved past this branch.
    git('checkout', '-qb', 'ahead');
    write('.claude-plugin/marketplace.json', market('2.60.0', '5.1.3', '1.0.0'));
    write('plugins/a/.claude-plugin/plugin.json', { name: 'a', version: '5.1.3' });
    commit('sibling');
    git('checkout', '-q', 'main');

    bump(dir, ['a'], 'patch', 'main', env);
    expect('patch bump', '2.60.0 a=5.0.6/5.0.6 b=1.0.0');
    bump(dir, ['a'], 'patch', 'main', env);
    expect('idempotent re-run', '2.60.0 a=5.0.6/5.0.6 b=1.0.0');
    bump(dir, ['a'], 'minor', 'main', env);
    expect('minor over an earlier patch', '2.60.0 a=5.1.0/5.1.0 b=1.0.0');
    bump(dir, ['a'], 'patch', 'ahead', env);
    expect('base moved ahead', '2.61.0 a=5.1.4/5.1.4 b=1.0.0');
    bump(dir, ['a'], 'patch', 'main', env);
    expect('never lower than the branch', '2.61.0 a=5.1.4/5.1.4 b=1.0.0');
    const files = ['.claude-plugin/marketplace.json', 'plugins/a/.claude-plugin/plugin.json', 'plugins/b/.claude-plugin/plugin.json'];
    const snapshot = () => files.map((f) => readFileSync(join(dir, f), 'utf8')).join('\0');
    const before = snapshot();
    let threw = false;
    try { bump(dir, ['b', 'nope'], 'patch', 'main', env); } catch { threw = true; }
    if (!threw) failures.push('unknown plugin was accepted');
    if (snapshot() !== before) failures.push('unknown plugin after a valid one still wrote files');
    bump(dir, ['a', 'b'], 'major', 'main', env);
    expect('several plugins, major', '2.61.0 a=6.0.0/6.0.0 b=2.0.0');
  } catch (err) {
    failures.push(`setup: ${err.message}`);
  }
  rmSync(dir, { recursive: true, force: true });
  failures.push(...checkSelftest(env));
  const argv = (a) => { try { return JSON.stringify(parseArgs(a)); } catch (err) { return `error: ${err.message}`; } };
  const argCases = [
    [['a', 'b'], '{"names":["a","b"],"level":"patch","base":"origin/main"}'],
    [['a', '--minor', '--base', 'origin/dev'], '{"names":["a"],"level":"minor","base":"origin/dev"}'],
    [['a', '--minro'], /unknown option --minro/],
    [['a', '--major', '--minor'], /only one of --minor, --major/],
    [['a', '--base'], /--base needs a ref/],
    [['--minor'], /no plugin named/],
  ];
  for (const [a, want] of argCases) {
    const got = argv(a);
    if (typeof want === 'string' ? got !== want : !want.test(got)) failures.push(`args ${a.join(' ')}: got ${got}`);
  }
  return failures;
}

/** --check against a throwaway repo: base `main`, a feature branch, a sibling release. */
function checkSelftest(env) {
  const dir = mkdtempSync(join(tmpdir(), 'bump-check-'));
  const git = (...a) => execFileSync('git', ['-C', dir, ...a], { env, stdio: ['ignore', 'pipe', 'pipe'] }).toString();
  const put = (rel, text) => { mkdirSync(join(dir, rel, '..'), { recursive: true }); writeFileSync(join(dir, rel), text); };
  const json = (rel, obj) => put(rel, JSON.stringify(obj, null, 2) + '\n');
  const commit = (msg) => git('-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-qm', msg);
  const failures = [];
  const expect = (name, want) => {
    let got;
    try { got = check(dir, 'main', env); } catch (err) { got = [`threw: ${err.message}`]; }
    const ok = want instanceof RegExp ? got.length > 0 && got.every((l) => want.test(l)) : got.length === 0;
    if (!ok) failures.push(`check ${name}: got ${JSON.stringify(got)}`);
  };
  try {
    git('init', '-q', '-b', 'main');
    json('.claude-plugin/marketplace.json', { name: 'm', metadata: { version: '1.0.0' }, plugins: [{ name: 'a', version: '1.0.0' }, { name: 'b', version: '1.0.0' }] });
    json('plugins/a/.claude-plugin/plugin.json', { name: 'a', version: '1.0.0' });
    json('plugins/b/.claude-plugin/plugin.json', { name: 'b', version: '1.0.0' });
    put('plugins/a/x.md', 'x\n'); put('plugins/b/y.md', 'y\n'); put('README.md', 'r\n');
    git('add', '-A'); commit('base');
    git('checkout', '-qb', 'feat');
    expect('nothing changed', null);
    put('README.md', 'root docs bump nothing\n'); git('add', '-A');
    expect('root file only', null);
    put('plugins/a/x.md', 'changed\n'); git('add', '-A');
    expect('plugin file changed, no bump', /plugins\/a\/ changed since main|metadata\.version/);
    // The pre-commit hook checks the commit, which is the index.
    bump(dir, ['a'], 'patch', 'main', env);
    expect('bump in the working tree only (not staged)', /plugins\/a\/ changed since main|metadata\.version/);
    git('add', '-A');
    expect('bumped above base', null);
    commit('feat');
    // A sibling release lands on main: b changed and bumped.
    git('checkout', '-q', 'main');
    put('plugins/b/y.md', 'sibling\n'); bump(dir, ['b'], 'patch', 'main', env);
    git('add', '-A'); commit('sibling');
    git('checkout', '-q', 'feat');
    expect('base moved on another plugin', null);
    git('-c', 'user.name=t', '-c', 'user.email=t@t', 'merge', '-q', '--no-commit', '--no-ff', 'main');
    expect('merging base in, before the merge commit', null);
    git('merge', '--abort');
    // A later release moves metadata.version past the branch's: not this branch's to fix.
    git('checkout', '-q', 'main');
    json('.claude-plugin/marketplace.json', { ...JSON.parse(readFileSync(join(dir, '.claude-plugin/marketplace.json'), 'utf8')), metadata: { version: '1.2.0' } });
    git('add', '-A'); commit('release');
    git('checkout', '-q', 'feat');
    expect('base metadata moved past the branch', null);
    // The base push: base plus a fix to a plugin, committed straight onto base.
    git('checkout', '-q', 'main'); git('checkout', '-qb', 'direct');
    put('plugins/b/y.md', 'direct fix\n'); git('add', '-A');
    expect('a fix straight onto base without a bump', /plugins\/b\/ changed since main|metadata\.version/);
    git('checkout', 'HEAD', '--', 'plugins/b/y.md');
    put('plugins/c/.claude-plugin/plugin.json', '{"name":"c","version":"0.1.0"}\n'); git('add', '-A');
    expect('a plugin new on the branch, metadata not moved', /metadata\.version/);
    const m = JSON.parse(readFileSync(join(dir, '.claude-plugin/marketplace.json'), 'utf8'));
    json('.claude-plugin/marketplace.json', { ...m, metadata: { version: '1.3.0' }, plugins: [...m.plugins, { name: 'c', version: '0.1.0' }] });
    git('add', '-A');
    expect('a plugin new on the branch, metadata moved', null);
    let threw = false;
    try { check(dir, 'no-such-ref', env); } catch { threw = true; }
    if (!threw) failures.push('check: an unreadable base did not fail');
  } catch (err) {
    failures.push(`check setup: ${err.message}`);
  }
  rmSync(dir, { recursive: true, force: true });
  return failures;
}

// --- main

const args = process.argv.slice(2);
if (args.includes('--selftest')) {
  const failures = selftest();
  if (failures.length) {
    console.error('bump-version SELFTEST FAILED:');
    for (const f of failures) console.error(`  ${f}`);
    process.exit(1);
  }
  console.log('bump-version selftest OK');
  process.exit(0);
}
if (args[0] === '--check') {
  const rest = args.slice(1);
  if (!(rest.length === 0 || (rest.length === 2 && rest[0] === '--base' && rest[1] && !rest[1].startsWith('--')))) {
    console.error('usage: node scripts/bump-version.mjs --check [--base origin/main]');
    process.exit(2);
  }
  const base = rest[1] || 'origin/main';
  // The repo the caller is in (a base-push worktree runs this file from its own checkout).
  const root = execFileSync('git', ['rev-parse', '--show-toplevel']).toString().trim();
  try {
    const failures = check(root, base);
    if (failures.length) {
      console.error('bump-version --check: plugin files changed without a version bump:');
      for (const f of failures) console.error(`  ${f}`);
      process.exit(1);
    }
    console.log(`bump-version --check OK (against ${base})`);
  } catch (err) {
    console.error(`bump-version --check: ${err.message}`);
    process.exit(1);
  }
  process.exit(0);
}
let opts;
try {
  opts = parseArgs(args);
} catch (err) {
  console.error(`bump-version: ${err.message}`);
  console.error('usage: node scripts/bump-version.mjs <plugin>... [--minor|--major] [--base origin/main]');
  process.exit(2);
}
const { names, level, base } = opts;
try {
  const changes = bump(resolve(dirname(fileURLToPath(import.meta.url)), '..'), names, level, base);
  console.log(changes.length ? changes.join('\n') : `unchanged (already above ${base})`);
} catch (err) {
  console.error(`bump-version: ${err.message}`);
  process.exit(1);
}
