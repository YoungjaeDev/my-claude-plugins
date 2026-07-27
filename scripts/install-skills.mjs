#!/usr/bin/env node
// Skills installer TUI — pick this marketplace's skills and install them to
// Hermes Agent / Codex by wrapping `npx skills` (vercel-labs/skills).
//
// This is the ONLY delivery path for Hermes: since #166 there is no generated
// Hermes adapter, so `npx skills` reading .claude-plugin/marketplace.json in place
// is what puts skills in ~/.hermes/skills/ (where Hermes indexes them into
// skills_list() and exposes them as slash commands). Codex additionally has the
// generated .codex-plugin manifests, which carry hooks and MCP servers that skills
// alone cannot.
//
// Zero-dep: Node builtins only. Run directly:
//   node scripts/install-skills.mjs            interactive install
//   node scripts/install-skills.mjs --selftest pure-logic self-check (no TTY/network)
//
// We add exactly two things over `npx skills`: (1) a plugin-grouped selector,
// (2) hermes profile targeting via a HERMES_HOME env bridge (npx skills has no
// profile concept). Conflicts / symlink / copy / remove / update / lockfile are
// all inherited from `npx skills` — not reimplemented here.

import { readFileSync, statSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { createInterface } from 'node:readline';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const MARKETPLACE = join(ROOT, '.claude-plugin', 'marketplace.json');
const PLUGINS_DIR = join(ROOT, 'plugins');
// hermes home — honor an existing HERMES_HOME (npx skills reads it too) so a
// relocated install isn't wrongly reported as "not installed".
const HERMES_BASE = process.env.HERMES_HOME?.trim() || join(homedir(), '.hermes');

// --- tiny fs helpers (same shape as scripts/sync-codex-manifests.mjs) ---
function readJSON(path) { return JSON.parse(readFileSync(path, 'utf8')); }
function isDir(path) { try { return statSync(path).isDirectory(); } catch { return false; } }
function isFile(path) { try { return statSync(path).isFile(); } catch { return false; } }

// Minimal frontmatter reader — pulls `name` + a one-line display `description`.
// (sync-codex-manifests' extractor returns description only; we also need name.)
// For block scalars (`|` / `>`) we take the first continuation line for display.
function parseFrontmatter(md) {
  const out = {};
  md = md.replace(/\r\n?/g, '\n'); // tolerate CRLF/CR (e.g. cv-explorer/SKILL.md)
  if (!md.startsWith('---')) return out;
  const end = md.indexOf('\n---', 3);
  if (end === -1) return out;
  const lines = md.slice(3, end).split('\n');
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^(name|description):\s*(.*)$/);
    if (!m) continue;
    let val = m[2];
    if (/^[|>][+-]?\d*\s*$/.test(val)) { // block scalar → first non-empty indented line
      val = '';
      for (let j = i + 1; j < lines.length; j++) {
        if (lines[j].trim() === '') continue;
        if (/^\S/.test(lines[j])) break; // dedent ends the block
        val = lines[j].trim();
        break;
      }
    } else {
      val = val.trim().replace(/^["']|["']$/g, '');
    }
    out[m[1]] = val;
  }
  return out;
}

// Read marketplace.json plugins[], scan plugins/<name>/skills/*/SKILL.md, and
// group by plugin. Plugins with 0 skills (e.g. core-config) drop out naturally.
function discover() {
  const groups = [];
  for (const entry of readJSON(MARKETPLACE).plugins) {
    const skillsDir = join(PLUGINS_DIR, entry.name, 'skills');
    if (!isDir(skillsDir)) continue;
    const skills = [];
    for (const dir of readdirSync(skillsDir).sort()) {
      const md = join(skillsDir, dir, 'SKILL.md');
      if (!isFile(md)) continue;
      const fm = parseFrontmatter(readFileSync(md, 'utf8'));
      if (!fm.name) continue; // a skill with no name can't be -s targeted
      skills.push({ id: fm.name, name: fm.name, desc: fm.description || '', path: md });
    }
    if (skills.length) groups.push({ plugin: entry.name, skills });
  }
  return groups;
}

// --- ANSI / terminal ---
const ESC = '\x1b[';
const out = (s) => process.stdout.write(s);
const truncate = (s, n) => (s.length > n ? s.slice(0, n - 1) + '…' : s);

// Raw-mode grouped checkbox selector. Returns a flat list of selected skill
// names (frontmatter `name`), or null on cancel.
function selectSkills(groups) {
  return new Promise((resolveSel) => {
    // rows: interleaved plugin headers + indented skills
    const rows = [];
    groups.forEach((g, gi) => {
      rows.push({ kind: 'plugin', gi });
      g.skills.forEach((_, si) => rows.push({ kind: 'skill', gi, si }));
    });
    const sel = groups.map((g) => g.skills.map(() => false));
    let cursor = 0;
    let lastLines = 0;

    const groupState = (gi) => {
      const flags = sel[gi];
      const on = flags.filter(Boolean).length;
      return on === 0 ? ' ' : on === flags.length ? 'x' : '~';
    };
    const toggleGroup = (gi) => {
      const all = sel[gi].every(Boolean);
      sel[gi] = sel[gi].map(() => !all);
    };

    const render = () => {
      const lines = [];
      lines.push('Select skills — ↑/↓ move · space toggle · a toggle plugin · enter confirm · q cancel');
      lines.push('');
      rows.forEach((row, i) => {
        const here = i === cursor ? '>' : ' ';
        if (row.kind === 'plugin') {
          const g = groups[row.gi];
          lines.push(`${here} [${groupState(row.gi)}] ${g.plugin} (${g.skills.length})`);
        } else {
          const sk = groups[row.gi].skills[row.si];
          const box = sel[row.gi][row.si] ? 'x' : ' ';
          lines.push(`${here}     [${box}] ${sk.name}  ${ESC}2m${truncate(sk.desc, 60)}${ESC}0m`);
        }
      });
      const total = sel.flat().filter(Boolean).length;
      lines.push('');
      lines.push(`${total} skill(s) selected`);
      if (lastLines) out(`${ESC}${lastLines}A`);
      out(`\r${ESC}J`);
      out(lines.join('\n'));
      lastLines = lines.length - 1;
    };

    const stdin = process.stdin;
    const cleanup = () => {
      stdin.setRawMode(false);
      stdin.pause();
      stdin.removeListener('data', onKey);
      out(`\n${ESC}?25h`); // show cursor
    };
    const onKey = (key) => {
      if (key === '\x03' || key === 'q') { cleanup(); resolveSel(null); return; } // Ctrl-C / q
      if (key === '\x1b[A' || key === 'k') cursor = (cursor - 1 + rows.length) % rows.length;
      else if (key === '\x1b[B' || key === 'j') cursor = (cursor + 1) % rows.length;
      else if (key === ' ') {
        const row = rows[cursor];
        if (row.kind === 'plugin') toggleGroup(row.gi);
        else sel[row.gi][row.si] = !sel[row.gi][row.si];
      } else if (key === 'a') {
        toggleGroup(rows[cursor].gi);
      } else if (key === '\r' || key === '\n') {
        cleanup();
        const picked = [];
        groups.forEach((g, gi) => g.skills.forEach((sk, si) => { if (sel[gi][si]) picked.push(sk.name); }));
        resolveSel(picked);
        return;
      }
      render();
    };

    out(`${ESC}?25l`); // hide cursor
    stdin.setRawMode(true);
    stdin.resume();
    stdin.setEncoding('utf8');
    stdin.on('data', onKey);
    render();
  });
}

// --- line-mode prompts (after the raw-mode selector exits) ---
function ask(question) {
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((res) => rl.question(question, (a) => { rl.close(); res(a.trim()); }));
}

// hermes profiles live under <HERMES_BASE>/profiles/<name>; "default" = <HERMES_BASE>/skills.
function hermesProfiles() {
  const dir = join(HERMES_BASE, 'profiles');
  if (!isDir(dir)) return [];
  return readdirSync(dir).filter((n) => isDir(join(dir, n))).sort();
}
const hermesInstalled = () => isDir(HERMES_BASE);

// One `npx skills add` spawn per (agent, profile). Selection passed as repeated
// `-s <name>` flags (comma is NOT a valid separator for this CLI).
function installFor(agent, skills, globalScope, profile) {
  const args = ['--yes', 'skills', 'add', ROOT, '-a', agent];
  for (const s of skills) args.push('-s', s);
  if (globalScope) args.push('-g');
  args.push('-y');
  const env = { ...process.env };
  if (agent === 'hermes-agent' && profile && profile !== 'default') {
    env.HERMES_HOME = join(HERMES_BASE, 'profiles', profile);
  }
  const label = agent === 'hermes-agent' && profile ? `${agent} [${profile}]` : agent;
  out(`\n→ installing ${skills.length} skill(s) to ${label}${globalScope ? ' (global)' : ' (project)'}\n`);
  const r = spawnSync('npx', args, { stdio: 'inherit', env });
  return { agent: label, ok: r.status === 0, code: r.status };
}

async function interactive() {
  if (!process.stdin.isTTY) {
    console.error('install-skills: interactive mode needs a TTY. Run in a terminal.');
    process.exit(1);
  }
  const groups = discover();
  if (groups.length === 0) { console.log('no discoverable skills found — nothing to do.'); return; }
  const skills = await selectSkills(groups);
  if (skills === null) { console.log('cancelled.'); return; }
  if (skills.length === 0) { console.log('no skills selected — nothing to do.'); return; }

  // targets
  const hermesOk = hermesInstalled();
  let targets = [];
  while (targets.length === 0) {
    const def = hermesOk ? '1,2' : '1';
    const a = (await ask(`\nTargets — [1] codex  [2] hermes-agent${hermesOk ? '' : ' (not installed — unavailable)'}\nchoose (e.g. 1,2) [${def}]: `)) || def;
    const set = new Set(a.split(',').map((x) => x.trim()));
    if (set.has('1')) targets.push('codex');
    if (set.has('2') && hermesOk) targets.push('hermes-agent');
    if (set.has('2') && !hermesOk) console.log('  hermes-agent skipped: ~/.hermes not found.');
  }

  // scope
  const sc = (await ask('\nScope — [1] global (~/)  [2] project (./)  [1]: ')) || '1';
  const globalScope = sc.trim() !== '2';

  // hermes profile (only if hermes targeted)
  let profile = 'default';
  if (targets.includes('hermes-agent')) {
    const profiles = hermesProfiles();
    if (profiles.length) {
      const list = ['default', ...profiles];
      const menu = list.map((p, i) => `[${i + 1}] ${p}`).join('  ');
      const p = (await ask(`\nHermes profile — ${menu}  [1]: `)) || '1';
      const idx = Math.max(1, Math.min(list.length, parseInt(p, 10) || 1)) - 1;
      profile = list[idx];
    }
  }

  // spawn
  const results = [];
  for (const agent of targets) {
    results.push(installFor(agent, skills, globalScope, agent === 'hermes-agent' ? profile : null));
  }

  // summary
  out('\n=== summary ===\n');
  for (const r of results) out(`  ${r.ok ? 'OK  ' : 'FAIL'} ${r.agent}${r.ok ? '' : ` (exit ${r.code})`}\n`);
  out(`  ${skills.length} skill(s): ${skills.join(', ')}\n`);
  out(`  lockfile: global → ~/.agents/.skill-lock.json · project → ./skills-lock.json (managed by npx skills)\n`);
  if (results.some((r) => !r.ok)) process.exitCode = 1;
}

// --- pure-logic self-check (no TTY, no network) ---
function selftest() {
  const groups = discover();
  const totalSkills = groups.reduce((n, g) => n + g.skills.length, 0);
  const plugins = groups.map((g) => g.plugin);
  const assert = (cond, msg) => { if (!cond) { console.error('FAIL:', msg); process.exit(1); } };

  assert(groups.length === 23, `expected 23 skill-bearing plugins, got ${groups.length}`);
  assert(totalSkills === 52, `expected 52 skills total, got ${totalSkills}`);
  assert(!plugins.includes('core-config'), 'core-config (0 skills) should be excluded');
  assert(new Set(groups.flatMap((g) => g.skills.map((s) => s.id))).size === 52, 'skill names must be globally unique for -s targeting');

  const gh = groups.find((g) => g.plugin === 'github-dev');
  assert(gh && gh.skills.length === 8, 'github-dev should have 8 skills');
  const cr = gh.skills.find((s) => s.name === 'cr-fix');
  assert(cr && cr.desc.length > 0, 'cr-fix must parse both name and description');

  console.log(`selftest OK — ${groups.length} plugins, ${totalSkills} skills, name+desc parsed.`);
}

function help() {
  out([
    "install-skills — pick this marketplace's skills and install them to Codex / Hermes Agent.",
    '',
    'Usage:',
    '  node scripts/install-skills.mjs            interactive install (needs a TTY)',
    '  node scripts/install-skills.mjs --selftest pure-logic self-check (no TTY/network)',
    '  node scripts/install-skills.mjs --help     show this help',
    '',
  ].join('\n'));
}

if (process.argv.includes('--help') || process.argv.includes('-h')) help();
else if (process.argv.includes('--selftest')) selftest();
else interactive();
