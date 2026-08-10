#!/usr/bin/env node
// measure-skills — mechanical measurement of every SKILL.md in a plugin tree.
//
// Measurement-first: a fleet review that runs a model over 50 skills costs more than it
// learns. This produces the numbers first, so the expensive judgment goes only to the
// skills the numbers single out.
//
// Per skill it reports: line count, approximate body tokens, description length,
// section count, references/ depth, whether scripts/ is bundled, and the frontmatter
// keys present. It aggregates the frontmatter keys into a fleet-wide inventory, which
// is how schema drift (a key on three skills and nowhere else) becomes visible.
//
// This measures. It does not judge, and it is not a gate — for the blocking checks see
// scripts/check-skill-contract.mjs at the repository root.
//
// Zero-dep: Node 18+ builtins only. Self-contained — it reads no file outside the tree
// it is pointed at.
//
// Usage:
//   node measure-skills.mjs                 # scan ./plugins (or . when that is absent)
//   node measure-skills.mjs path [path...]  # scan the given roots
//   node measure-skills.mjs --csv           # CSV to stdout
//   node measure-skills.mjs --json          # JSON to stdout
//   node measure-skills.mjs --selftest      # parser self-check, no filesystem scan

import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const CHARS_PER_TOKEN = 4; // rough English-prose ratio; comparative only, never a budget

// ---------------------------------------------------------------- pure core

// Both delimiters must be a line that is exactly `---`. A prefix match would accept
// `---invalid` as an opener and `----` as a closer, counting a file whose frontmatter
// never parses as having one — and folding the closer's extra characters into the body.
const isDelimiter = (line) => line.replace(/\r$/, '') === '---';

/** Split a SKILL.md into its frontmatter block and body. */
export function splitFrontmatter(content) {
  const lines = content.split('\n');
  if (lines.length < 2 || !isDelimiter(lines[0])) return { frontmatter: null, body: content };
  const end = lines.findIndex((l, i) => i > 0 && isDelimiter(l));
  if (end === -1) return { frontmatter: null, body: content };
  return { frontmatter: lines.slice(1, end).join('\n'), body: lines.slice(end + 1).join('\n') };
}

/** Top-level `key:` names, in file order, from a frontmatter block. */
export function frontmatterKeys(frontmatter) {
  if (frontmatter === null) return [];
  const keys = [];
  for (const line of frontmatter.split('\n')) {
    const m = line.match(/^([A-Za-z][A-Za-z0-9_-]*)\s*:/);
    if (m && !keys.includes(m[1])) keys.push(m[1]);
  }
  return keys;
}

/**
 * Decode a block scalar the way YAML would. Chomping changes the length, and the 1024
 * threshold is a hard cliff: `description: |` over a 1024-character body decodes to
 * 1025 because clipping keeps one trailing newline. `|`/`>` clip to one trailing
 * newline, `|-`/`>-` strip it, `|+`/`>+` keep every trailing blank line. Folded scalars
 * join lines within a paragraph using a space and separate paragraphs with a newline.
 */
function decodeBlockScalar(header, rawLines) {
  // Strip a trailing comment first, or a `-` inside it reads as strip chomping.
  const h = header.replace(/\s*#.*$/, '');
  const folded = h[0] === '>';
  const chomp = (h.match(/[-+]/) || [])[0] || 'clip';
  // An explicit indentation indicator (`|2`, `|-2`, `|2-`) fixes the block indent, so
  // auto-detecting it from the first line strips content YAML would keep.
  const explicit = (h.match(/[1-9]/) || [])[0];
  const first = rawLines.find((l) => l.trim() !== '');
  const indent = explicit ? Number(explicit) : (first ? first.match(/^\s*/)[0].length : 0);
  const body = rawLines.map((l) => (l.length >= indent ? l.slice(indent) : l.trim()));
  let trailing = 0;
  while (body.length && body[body.length - 1].trim() === '') { body.pop(); trailing++; }
  let text;
  if (folded) {
    const paras = [];
    let cur = [];
    for (const l of body) {
      if (l.trim() === '') { paras.push(cur.join(' ')); cur = []; } else cur.push(l);
    }
    paras.push(cur.join(' '));
    text = paras.join('\n');
  } else {
    text = body.join('\n');
  }
  if (text === '') return '';
  if (chomp === '-') return text;
  if (chomp === '+') return text + '\n'.repeat(trailing + 1);
  return text + '\n';
}

/**
 * The decoded `description` value, or null when absent. Handles a plain scalar, a
 * quoted scalar, and a `>`/`|` block scalar — the three forms in use here. The length
 * of this string is what the 1024-character Codex limit applies to.
 */
export function frontmatterDescription(frontmatter) {
  if (frontmatter === null) return null;
  const lines = frontmatter.split('\n');
  const i = lines.findIndex((l) => /^description\s*:/.test(l));
  if (i === -1) return null;
  // Indented continuation lines belong to the scalar whatever its style. A plain or
  // quoted scalar may legally span lines, so reading only the first one under-reports
  // the length that the 1024-character Codex threshold applies to.
  const continuation = [];
  for (const line of lines.slice(i + 1)) {
    if (line.trim() !== '' && !/^\s/.test(line)) break; // next top-level key
    continuation.push(line);
  }
  const head = lines[i].replace(/^description\s*:\s*/, '');
  // Both indicator orders (`|2-`, `|-2`) plus a trailing comment on the header.
  if (/^[>|]([1-9][-+]?|[-+][1-9]?)?\s*(#.*)?$/.test(head)) return decodeBlockScalar(head, continuation);
  let value = [head.trim(), ...continuation.map((l) => l.trim())].join(' ').trim();
  if (value.length >= 2 && ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'")))) {
    value = value.slice(1, -1);
  }
  return value;
}

/** Every measurement derivable from the file contents alone. */
export function measureContent(content) {
  const { frontmatter, body } = splitFrontmatter(content);
  const description = frontmatterDescription(frontmatter);
  return {
    lines: content.split('\n').length,
    bodyTokens: Math.ceil(body.length / CHARS_PER_TOKEN),
    descriptionChars: description === null ? 0 : description.length,
    hasFrontmatter: frontmatter !== null,
    sections: (body.match(/^#{2,6} /gm) || []).length,
    frontmatterKeys: frontmatterKeys(frontmatter),
  };
}

// ---------------------------------------------------------------- filesystem

// Paths this run could not read. A sweep that quietly drops an unreadable subtree
// reports a repository-wide result it does not have, and the gap looks identical to
// "there was nothing there" — so every failure is collected and printed as unverified
// scope rather than swallowed.
export const unreadable = [];

function walk(dir, keep) {
  if (!existsSync(dir)) return [];
  const out = [];
  let entries;
  try {
    entries = readdirSync(dir, { withFileTypes: true });
  } catch (err) {
    unreadable.push(`${dir} (${err?.code ?? err?.message ?? 'unreadable'})`);
    return out;
  }
  for (const ent of entries) {
    const p = join(dir, ent.name);
    if (ent.isDirectory()) out.push(...walk(p, keep));
    else if (keep(ent.name)) out.push(p);
  }
  return out;
}

/** Deepest nesting under `dir`: 0 when absent, 1 when flat, 2+ when nested. */
function maxDepth(dir, depth = 1) {
  if (!existsSync(dir)) return 0;
  let deepest = 0;
  let entries;
  try {
    entries = readdirSync(dir, { withFileTypes: true });
  } catch (err) {
    unreadable.push(`${dir} (${err?.code ?? err?.message ?? 'unreadable'})`);
    return 0;
  }
  for (const ent of entries) {
    const here = ent.isDirectory() ? maxDepth(join(dir, ent.name), depth + 1) : depth;
    if (here > deepest) deepest = here;
  }
  return deepest;
}

function measureSkillFile(abs, root) {
  const dir = abs.slice(0, -('/SKILL.md'.length));
  const rel = relative(root, abs).split(sep).join('/');
  const parts = rel.split('/');
  const pluginIdx = parts.indexOf('skills') - 1;
  return {
    path: rel,
    plugin: pluginIdx >= 0 ? parts[pluginIdx] : '',
    skill: dir.split(sep).pop(),
    ...measureContent(readFileSync(abs, 'utf8')),
    referencesDepth: maxDepth(join(dir, 'references')),
    hasScripts: existsSync(join(dir, 'scripts')),
  };
}

export function measureTree(roots, cwd) {
  const rows = [];
  for (const root of roots) {
    const abs = resolve(cwd, root);
    if (!existsSync(abs)) {
      // A typo'd or since-deleted root used to vanish here. With any other root holding
      // skills the run still exited 0, so the caller took a CSV missing an entire
      // requested tree for a complete one.
      unreadable.push(`${root} (ENOENT — requested root does not exist)`);
      continue;
    }
    const base = statSync(abs).isDirectory() ? abs : cwd;
    for (const file of walk(abs, (n) => n === 'SKILL.md')) rows.push(measureSkillFile(file, base));
  }
  return rows.sort((a, b) => a.path.localeCompare(b.path));
}

// ---------------------------------------------------------------- output

function renderTable(rows) {
  const head = ['plugin', 'skill', 'lines', 'tokens~', 'desc', 'sect', 'refs', 'scripts', 'frontmatter keys'];
  const body = rows.map((r) => [
    r.plugin,
    r.skill,
    String(r.lines),
    String(r.bodyTokens),
    String(r.descriptionChars),
    String(r.sections),
    String(r.referencesDepth),
    r.hasScripts ? 'yes' : '-',
    r.frontmatterKeys.join(' '),
  ]);
  const widths = head.map((h, i) => Math.max(h.length, ...body.map((row) => row[i].length)));
  const line = (cells) => cells.map((c, i) => c.padEnd(widths[i])).join('  ').trimEnd();
  return [line(head), line(widths.map((w) => '-'.repeat(w))), ...body.map(line)].join('\n');
}

function renderCsv(rows) {
  const q = (v) => (/[",\n]/.test(v) ? `"${v.replace(/"/g, '""')}"` : v);
  const out = ['path,plugin,skill,lines,body_tokens,description_chars,sections,references_depth,has_scripts,frontmatter_keys'];
  for (const r of rows) {
    out.push([
      r.path, r.plugin, r.skill, r.lines, r.bodyTokens, r.descriptionChars,
      r.sections, r.referencesDepth, r.hasScripts ? 'yes' : 'no', r.frontmatterKeys.join(' '),
    ].map((v) => q(String(v))).join(','));
  }
  return out.join('\n');
}

function renderInventory(rows) {
  const counts = new Map();
  for (const r of rows) for (const k of r.frontmatterKeys) counts.set(k, (counts.get(k) || 0) + 1);
  const sorted = [...counts.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
  const lines = sorted.map(([k, n]) => `  ${String(n).padStart(3)}  ${k}`);
  const noFm = rows.filter((r) => !r.hasFrontmatter).map((r) => r.path);
  if (noFm.length) lines.push('', `  no parsable frontmatter: ${noFm.join(', ')}`);
  return `frontmatter key inventory (${rows.length} skills):\n${lines.join('\n')}`;
}

// ---------------------------------------------------------------- self-check

function selftest() {
  const assert = (cond, msg) => { if (!cond) { console.error(`selftest FAIL: ${msg}`); process.exitCode = 1; } };

  const plain = measureContent('---\nname: a\ndescription: hello\n---\n\n# T\n\n## One\ntext\n');
  assert(plain.hasFrontmatter, 'plain: frontmatter detected');
  assert(plain.descriptionChars === 5, `plain: description length 5, got ${plain.descriptionChars}`);
  assert(plain.sections === 1, `plain: one section, got ${plain.sections}`);
  assert(plain.frontmatterKeys.join(',') === 'name,description', `plain: keys, got ${plain.frontmatterKeys}`);

  const quoted = measureContent('---\nname: a\ndescription: "x: y"\n---\nbody\n');
  assert(quoted.descriptionChars === 4, `quoted: quotes stripped, got ${quoted.descriptionChars}`);

  const block = measureContent('---\nname: a\ndescription: >-\n  one\n  two\nversion: 1\n---\nbody\n');
  assert(block.descriptionChars === 7, `block scalar: folded to "one two", got ${block.descriptionChars}`);
  assert(block.frontmatterKeys.includes('version'), 'block scalar: key after block still seen');

  const none = measureContent('# no frontmatter\n\n## a\n');
  assert(!none.hasFrontmatter, 'missing frontmatter reported');
  assert(none.descriptionChars === 0, 'missing frontmatter has no description');

  const prefixed = measureContent('---invalid\nname: a\ndescription: x\n---\nbody\n');
  assert(!prefixed.hasFrontmatter, '`---invalid` is not an opening delimiter');

  const overlong = measureContent('---\nname: a\ndescription: x\n----\nbody\n');
  assert(!overlong.hasFrontmatter, '`----` is not a closing delimiter');

  const folded = measureContent('---\nname: a\ndescription: one\n  two\n---\nbody\n');
  assert(folded.descriptionChars === 7, `multi-line plain scalar folds to "one two", got ${folded.descriptionChars}`);

  for (const header of ['|2-', '>2-', '|-2', '>- # trailing comment']) {
    const h = measureContent(`---\nname: a\ndescription: ${header}\n  abcd\n---\nbody\n`);
    assert(h.descriptionChars === 4, `block header "${header}" folds to the body, got ${h.descriptionChars}`);
  }

  const clip = measureContent('---\nname: a\ndescription: |\n  abcd\n---\nbody\n');
  assert(clip.descriptionChars === 5, `clip chomping keeps one newline, got ${clip.descriptionChars}`);
  const keep = measureContent('---\nname: a\ndescription: |+\n  abcd\n  \n---\nbody\n');
  assert(keep.descriptionChars === 6, `keep chomping preserves trailing blanks, got ${keep.descriptionChars}`);

  const at = measureContent(`---\nname: a\ndescription: ${'z'.repeat(1024)}\n---\nbody\n`);
  assert(at.descriptionChars === 1024, `1024-char boundary, got ${at.descriptionChars}`);
  const over = measureContent(`---\nname: a\ndescription: ${'z'.repeat(1025)}\n---\nbody\n`);
  assert(over.descriptionChars === 1025, `1025-char boundary, got ${over.descriptionChars}`);

  if (!process.exitCode) console.log('measure-skills selftest OK (15 cases)');
}

// ---------------------------------------------------------------- main

// Guard the CLI behind an is-main check: the pure core above is exported, and without
// this an `import` of this module runs a full filesystem scan as a side effect.
const isMain = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
const argv = process.argv.slice(2);
if (!isMain) {
  // imported as a library — expose the parsers, run nothing
} else if (argv.includes('--selftest')) {
  selftest();
} else {
  const flags = new Set(argv.filter((a) => a.startsWith('--')));
  const roots = argv.filter((a) => !a.startsWith('--'));
  const cwd = process.cwd();
  const defaults = existsSync(join(cwd, 'plugins')) ? ['plugins'] : ['.'];
  const rows = measureTree(roots.length ? roots : defaults, cwd);

  if (!rows.length) {
    console.error(`measure-skills: no SKILL.md found under ${(roots.length ? roots : defaults).join(', ')}`);
    process.exit(1);
  }
  if (flags.has('--json')) console.log(JSON.stringify({ rows, unreadable }, null, 2));
  else if (flags.has('--csv')) console.log(renderCsv(rows));
  else {
    console.log(renderTable(rows));
    console.log('');
    console.log(renderInventory(rows));
    console.log('');
    console.log('tokens~ is body chars / 4 — comparative only. desc is the decoded description length (Codex skips over 1024).');
  }
  if (unreadable.length) {
    console.error(`measure-skills: ${unreadable.length} path(s) could not be read — this run does NOT cover them:`);
    for (const u of unreadable) console.error(`  ${u}`);
    console.error('Report these as unverified scope; do not call the sweep repository-wide.');
    process.exitCode = 2;
  }
}
