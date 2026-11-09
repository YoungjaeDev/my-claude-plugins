#!/usr/bin/env node
// measure-skills: mechanical measurement for docs:md-audit.
//
// Two modes. The skill table measures every SKILL.md in a tree: line count, approximate
// body tokens, description length, section count, references/ depth, bundled scripts,
// and the frontmatter keys, aggregated into a key inventory so schema drift shows.
// The --md mode measures any markdown file against the shape rules in
// ../../../references/writing-standard.md (bytes, paragraph bytes and sentences,
// heading depth and short sections, bold), and reads its exception list from there.
//
// This measures; the model judges. Exit 1 in --md mode means a fail-level finding.
// Zero-dep: Node 18+ builtins only (git is used, when present, to list files).
//
// Usage:
//   node measure-skills.mjs                 # skill table for ./plugins (or .)
//   node measure-skills.mjs path [path...]  # skill table for the given roots
//   node measure-skills.mjs --csv | --json  # skill table as CSV / JSON
//   node measure-skills.mjs --md [path...]  # shape audit; no path = .md changed vs --base
//   node measure-skills.mjs --md --all      # shape audit of every tracked .md
//   node measure-skills.mjs --md --base <ref>  # changed vs merge-base with <ref> (default origin/main)
//   node measure-skills.mjs --selftest      # parser self-check, no filesystem scan

import { readFileSync, existsSync, readdirSync, realpathSync, statSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join, relative, resolve, sep } from 'node:path';
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

// ---------------------------------------------------------------- markdown shape
//
// The shape rules of plugins/docs/references/writing-standard.md, counted the way that
// file defines them. 1KB is 1000 bytes there, matching the `wc -c` figures in spec #377.

export const LIMITS = { skillHard: 10000, skillTarget: 5000, paraBytes: 600, paraSentences: 3, headingBodyLines: 3, boldPerFile: 1 };

const LIST_ITEM = /^\s*(?:[-*+]|\d+[.)])\s+/;
const FOOTNOTE_DEF = /^\[\^[^\]]+\]:/;
const HEADING = /^(#{1,6})\s+(.*?)\s*#*\s*$/;

/** Classify each line: frontmatter, fence, comment, heading, table, blank, or prose. */
export function classifyLines(content) {
  const lines = content.split('\n').map((l) => l.replace(/\r$/, ''));
  const out = [];
  let i = 0;
  if (isDelimiter(lines[0] ?? '')) {
    const end = lines.findIndex((l, k) => k > 0 && isDelimiter(l));
    if (end !== -1) {
      for (; i <= end; i++) out.push({ n: i + 1, text: lines[i], kind: 'frontmatter' });
    }
  }
  let fence = null;
  let comment = false;
  for (; i < lines.length; i++) {
    const text = lines[i];
    const t = text.trim();
    let kind;
    if (fence) {
      kind = 'fence';
      if (t.startsWith(fence) && t.replace(/[`~]/g, '') === '') fence = null;
    } else if (comment) {
      kind = 'comment';
      if (t.includes('-->')) comment = false;
    } else if (/^(`{3,}|~{3,})/.test(t)) {
      kind = 'fence';
      fence = t.match(/^(`{3,}|~{3,})/)[1];
    } else if (t.startsWith('<!--')) {
      kind = 'comment';
      if (!t.includes('-->')) comment = true;
    } else if (t === '') kind = 'blank';
    else if (HEADING.test(text)) kind = 'heading';
    else if (t.startsWith('|')) kind = 'table';
    else kind = 'prose';
    out.push({ n: i + 1, text, kind });
  }
  return out;
}

/** Prose paragraphs: blank-separated, with each list item and footnote its own paragraph. */
export function paragraphs(classified) {
  const paras = [];
  let cur = null;
  for (const l of classified) {
    const starts = l.kind === 'prose' && (LIST_ITEM.test(l.text) || FOOTNOTE_DEF.test(l.text.trim()) || /^>\s*$/.test(l.text.trim()));
    if (l.kind !== 'prose' || starts || !cur) {
      if (cur) paras.push(cur);
      cur = l.kind === 'prose' && !/^>\s*$/.test(l.text.trim()) ? { line: l.n, lines: [l.text] } : null;
      continue;
    }
    cur.lines.push(l.text);
  }
  if (cur) paras.push(cur);
  return paras.map((p) => ({ ...p, text: p.lines.join('\n'), bytes: Buffer.byteLength(p.lines.join('\n'), 'utf8') }));
}

// Inline code, link targets and URLs carry dots that end no sentence.
const stripInline = (s) => s.replace(/`[^`]*`/g, 'C').replace(/\]\([^)]*\)/g, ']').replace(/https?:\/\/\S+/g, 'U');

/** Sentence ends: `.`/`!`/`?` before whitespace or end of line, minus common abbreviations. */
export function countSentences(text) {
  const s = stripInline(text.replace(LIST_ITEM, ''))
    .replace(/\b(e\.g|i\.e|etc|vs|cf|approx|no)\./gi, '$1')
    .replace(/\.{2,}/g, '.');
  return Math.max(1, (s.match(/[.!?。](?=\s|$|["')\]])/g) || []).length);
}

/** Bold spans that are not a list lead. Returns [{ line }]. */
function extraBold(classified) {
  const out = [];
  for (const l of classified) {
    if (l.kind !== 'prose' && l.kind !== 'table' && l.kind !== 'heading') continue;
    const s = stripInline(l.text);
    let spans = (s.match(/\*\*[^*\s][^*]*\*\*|__[^_\s][^_]*__/g) || []).length;
    if (spans && l.kind === 'prose' && /^\s*(?:[-*+]|\d+[.)])\s+(\*\*|__)/.test(s)) spans -= 1;
    for (let k = 0; k < spans; k++) out.push({ line: l.n });
  }
  return out;
}

/** Shape findings for one markdown file. `rule` is one of the names in writing-standard.md. */
export function measureMarkdown(content, path, { skipLines = new Set() } = {}) {
  const classified = classifyLines(content).filter((l) => !skipLines.has(l.n));
  const findings = [];
  const add = (level, rule, line, detail) => findings.push({ level, rule, line, detail });
  const bytes = Buffer.byteLength(content, 'utf8');

  if (/(^|\/)SKILL\.md$/.test(path)) {
    if (bytes > LIMITS.skillHard) add('fail', 'size', 1, `${bytes}B SKILL.md (max ${LIMITS.skillHard})`);
    else if (bytes > LIMITS.skillTarget) add('warn', 'size', 1, `${bytes}B SKILL.md (target ${LIMITS.skillTarget})`);
  }

  for (const p of paragraphs(classified)) {
    if (p.bytes > LIMITS.paraBytes) add('fail', 'para', p.line, `${p.bytes}B paragraph (max ${LIMITS.paraBytes})`);
    const n = countSentences(p.text);
    if (n > LIMITS.paraSentences) add('warn', 'sentences', p.line, `${n} sentences (max ${LIMITS.paraSentences})`);
  }

  const heads = classified.map((l, idx) => ({ l, idx })).filter(({ l }) => l.kind === 'heading');
  for (const { l, idx } of heads) {
    const level = l.text.match(HEADING)[1].length;
    if (level >= 4) add('fail', 'h4', l.n, `H${level} heading (H3 is the deepest)`);
    if (level === 1) continue;
    let body = 0;
    for (const m of classified.slice(idx + 1)) {
      if (m.kind === 'heading') {
        if (m.text.match(HEADING)[1].length <= level) break;
        continue;
      }
      if (m.kind !== 'blank' && m.kind !== 'comment') body++;
    }
    if (body < LIMITS.headingBodyLines) add('fail', 'short', l.n, `${body} body line(s) under "${l.text.trim()}" (min ${LIMITS.headingBodyLines}); merge into the section above`);
  }

  const bold = extraBold(classified);
  if (bold.length > LIMITS.boldPerFile) {
    for (const b of bold.slice(LIMITS.boldPerFile)) add('warn', 'bold', b.line, `bold outside a list lead (${bold.length} in file, ${LIMITS.boldPerFile} allowed)`);
  }

  findings.sort((a, b) => a.line - b.line);
  return { path, bytes, findings };
}

/**
 * The exception list: the first fenced block under `## Exceptions` in writing-standard.md.
 * One entry per line, `#` lines are comments, `path#Heading` exempts one section of a file.
 * Returns null when the block is missing, so the caller can fail closed.
 */
export function parseExceptions(standardText) {
  const lines = standardText.split('\n').map((l) => l.replace(/\r$/, ''));
  const start = lines.findIndex((l) => /^##\s+Exceptions\s*$/.test(l));
  if (start === -1) return null;
  const open = lines.findIndex((l, k) => k > start && /^```/.test(l.trim()));
  if (open === -1 || lines.slice(start + 1, open).some((l) => /^#{1,2}\s/.test(l))) return null;
  const close = lines.findIndex((l, k) => k > open && /^```\s*$/.test(l.trim()));
  if (close === -1) return null;
  const files = [];
  const sections = [];
  for (const raw of lines.slice(open + 1, close)) {
    const t = raw.trim();
    if (!t || t.startsWith('#')) continue;
    const hash = t.indexOf('#');
    if (hash > 0) sections.push({ glob: globToRegExp(t.slice(0, hash)), heading: t.slice(hash + 1).trim() });
    else files.push(globToRegExp(t));
  }
  return { files, sections };
}

function globToRegExp(glob) {
  let re = '';
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === '*' && glob[i + 1] === '*') {
      if (glob[i + 2] === '/') { re += '(?:.*/)?'; i += 2; } else { re += '.*'; i += 1; }
    } else if (c === '*') re += '[^/]*';
    else if (c === '?') re += '[^/]';
    else re += c.replace(/[.+^${}()|[\]\\]/g, '\\$&');
  }
  return new RegExp(`^${re}$`);
}

export const isExemptPath = (rel, ex) => ex.files.some((re) => re.test(rel));
export const sectionsFor = (rel, ex) => ex.sections.filter((s) => s.glob.test(rel)).map((s) => s.heading);

/** Line numbers covered by the named headings (heading line through its last subsection). */
export function sectionLines(content, headings) {
  const skip = new Set();
  if (!headings.length) return skip;
  const classified = classifyLines(content);
  let level = 0;
  for (const l of classified) {
    const m = l.kind === 'heading' ? l.text.match(HEADING) : null;
    if (m && level && m[1].length <= level) level = 0;
    if (m && !level && headings.includes(m[2])) level = m[1].length;
    if (level) skip.add(l.n);
  }
  return skip;
}

// ---------------------------------------------------------------- filesystem

// Paths this run could not read. A sweep that quietly drops an unreadable subtree
// reports a repository-wide result it does not have, and the gap looks identical to
// "there was nothing there" — so every failure is collected and printed as unverified
// scope rather than swallowed.
export const unreadable = [];

function walk(dir, keep, seen = new Set()) {
  if (!existsSync(dir)) return [];
  // Key every directory on its real path, links and plain directories alike. Tracking
  // only link targets still let a link pointing at an ancestor re-walk the subtree and
  // emit each skill twice.
  try {
    const real = realpathSync(dir);
    if (seen.has(real)) return [];
    seen.add(real);
  } catch (err) {
    unreadable.push(`${dir} (${err?.code ?? err?.message ?? 'unresolvable'})`);
    return [];
  }
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
    // Dirent.isDirectory() is false for a symlink, so a skill installed as a directory
    // link used to vanish from the sweep with no warning while the run still exited 0.
    // Follow links, keyed on the real path so a cycle cannot spin.
    let isDir = ent.isDirectory();
    if (!isDir && ent.isSymbolicLink()) {
      try {
        if (statSync(realpathSync(p)).isDirectory()) isDir = true;
      } catch (err) {
        unreadable.push(`${p} (broken symlink: ${err?.code ?? err?.message ?? 'unresolvable'})`);
        continue;
      }
    }
    if (isDir) out.push(...walk(p, keep, seen));
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
  // One `seen` set across every root. A per-root set let overlapping inputs — say
  // `plugins/x/skills` together with `plugins/x/skills/y` — count the same SKILL.md
  // twice, skewing the key inventory, the top-decile cohort, and the CSV row count.
  const seen = new Set();
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
    for (const file of walk(abs, (n) => n === 'SKILL.md', seen)) rows.push(measureSkillFile(file, base));
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

  mdSelftest(assert);

  // A failed diff or untracked listing must be unread scope (exit 2), never "0 files ok".
  for (const failing of ['diff', 'ls-files']) {
    const stub = (args) => (args.includes(failing) ? null : args.includes('merge-base') ? 'abc\n' : '');
    const scope = mdTargets({ paths: [], all: false, base: 'origin/main' }, process.cwd(), process.cwd(), stub);
    assert(scope.error, `git ${failing} failure is reported as an error, got ${scope.files?.length} file(s)`);
  }

  if (!process.exitCode) console.log('measure-skills selftest OK (15 skill cases, md shape cases)');
}

function mdSelftest(assert) {
  const rules = (content, path = 'doc.md') => measureMarkdown(content, path).findings.map((f) => `${f.rule}@${f.line}`);
  const long = 'x'.repeat(601);
  const ok = 'y'.repeat(600);

  // Paragraph bytes: 601 fails, 600 passes; each list item is its own paragraph.
  assert(rules(`# T\n\n${long}\n`).includes('para@3'), 'para: 601B paragraph fails');
  assert(!rules(`# T\n\n${ok}\n`).some((r) => r.startsWith('para')), 'para: 600B paragraph passes');
  assert(!rules(`# T\n\n- ${'a'.repeat(400)}\n- ${'b'.repeat(400)}\n`).some((r) => r.startsWith('para')),
    'para: two 400B list items are two paragraphs, not one 800B block');
  assert(rules(`# T\n\n- ${'a'.repeat(300)}\n  ${'b'.repeat(300)}\n`).includes('para@3'),
    'para: a continuation line belongs to its list item');
  const kb = 'ㄱ'.repeat(201); // 3 bytes each in UTF-8: 603B
  assert(rules(`# T\n\n${kb}\n`).includes('para@3'), 'para: bytes, not characters');

  // Exempt from the 600B rule: table rows, fenced code, frontmatter, HTML comments.
  assert(!rules(`# T\n\n| ${long} |\n`).some((r) => r.startsWith('para')), 'para: table row exempt');
  assert(!rules(`# T\n\n\`\`\`\n${long}\n\`\`\`\n`).some((r) => r.startsWith('para')), 'para: fenced code exempt');
  assert(!rules(`---\ndescription: ${long}\n---\n# T\n`).some((r) => r.startsWith('para')), 'para: frontmatter exempt');
  assert(!rules(`# T\n\n<!-- ${long} -->\n`).some((r) => r.startsWith('para')), 'para: one-line HTML comment exempt');
  assert(!rules(`# T\n\n<!--\n${long}\n-->\n`).some((r) => r.startsWith('para')), 'para: multi-line HTML comment exempt');

  // Headings: H4 and deeper fail; a section needs 3 non-blank body lines up to the next
  // heading of the same or higher level, so a container counts its children's bodies.
  const three = 'a\nb\nc\n';
  assert(rules(`# T\n\n## A\n${three}\n#### Deep\n${three}`).includes('h4@8'), 'h4: level-4 heading fails');
  assert(rules(`# T\n\n## A\none\ntwo\n\n## B\n${three}`).includes('short@3'), 'short: 2-line section fails');
  assert(!rules(`# T\n\n## A\n${three}`).some((r) => r.startsWith('short')), 'short: 3-line section passes');
  assert(!rules(`# T\n\n## A\n### B\n${three}`).some((r) => r === 'short@3'), 'short: container counts child bodies');
  assert(!rules(`# T\n## A\n${three}`).some((r) => r === 'short@1'), 'short: H1 exempt');
  assert(!rules(`# T\n\n## A\n\`\`\`\n#### not a heading\n\`\`\`\n${three}`).some((r) => r.startsWith('h4')),
    'h4: a # line inside a fence is code');

  // SKILL.md budget is the whole file, frontmatter included: >10000 fails, >5000 warns.
  const fm = '---\nname: a\ndescription: b\n---\n';
  const sized = (n) => fm + '# T\n\n' + Array.from({ length: Math.ceil(n / 500) }, () => 'z'.repeat(499)).join('\n\n');
  const big = measureMarkdown(sized(10200), 'p/skills/a/SKILL.md').findings.map((f) => `${f.level}:${f.rule}`);
  assert(big.includes('fail:size'), `size: SKILL.md over 10000B fails, got ${big}`);
  const mid = measureMarkdown(sized(6000), 'p/skills/a/SKILL.md').findings.map((f) => `${f.level}:${f.rule}`);
  assert(mid.includes('warn:size') && !mid.includes('fail:size'), `size: SKILL.md over 5000B warns, got ${mid}`);
  assert(!measureMarkdown(sized(10200), 'p/README.md').findings.some((f) => f.rule === 'size'), 'size: only SKILL.md has a budget');

  // Sentences: more than 3 warns. Inline code and abbreviations do not end a sentence.
  assert(rules('# T\n\nOne. Two. Three. Four.\n').includes('sentences@3'), 'sentences: 4 sentences warn');
  assert(!rules('# T\n\nRun `a. b. c. d.` here, e.g. now. Two. Three.\n').some((r) => r.startsWith('sentences')),
    'sentences: code span and e.g. are not sentence ends');
  assert(rules('# T\n\n첫째다. 둘째다. 셋째다. 넷째다.\n').includes('sentences@3'), 'sentences: Korean 다. counts');

  // Bold: a list lead (`- **Name**: ...`) is free; one more is the document's warning; the
  // second extra bold warns.
  assert(!rules('# T\n\n- **A**: x\n- **B**: y\n\n**Warning** once.\n').some((r) => r.startsWith('bold')), 'bold: leads plus one');
  assert(rules('# T\n\n**One** and **two**.\n').includes('bold@3'), 'bold: two non-lead bolds warn');
  assert(!rules('# T\n\n`**not bold**` and `**x**`\n').some((r) => r.startsWith('bold')), 'bold: inside code is not bold');

  // Levels: para/h4/short/size fail; sentences/bold/target warn.
  const levels = measureMarkdown(`# T\n\n${long}\n\nOne. Two. Three. Four.\n`, 'd.md').findings.map((f) => `${f.level}:${f.rule}`);
  assert(levels.includes('fail:para') && levels.includes('warn:sentences'), `levels: got ${levels}`);

  // Exceptions come from the fenced block under `## Exceptions` in writing-standard.md.
  const std = '# S\n\n## Exceptions\n\nSkipped:\n\n```text\n# history\ndocs/adr/**\n**/CHANGELOG.md\nplugins/*/templates/*.md\nAGENTS.md#Agent skills\n```\n';
  const ex = parseExceptions(std);
  assert(ex.files.length === 3 && ex.sections.length === 1, `exceptions: 3 globs + 1 section, got ${JSON.stringify(ex)}`);
  assert(isExemptPath('docs/adr/0001-x.md', ex), 'exceptions: ** matches nested files');
  assert(isExemptPath('CHANGELOG.md', ex) && isExemptPath('plugins/a/CHANGELOG.md', ex), 'exceptions: **/ matches zero or more dirs');
  assert(isExemptPath('plugins/a/templates/t.md', ex) && !isExemptPath('plugins/a/templates/x/t.md', ex), 'exceptions: * stays in one segment');
  assert(!isExemptPath('docs/adrx/1.md', ex) && !isExemptPath('README.md', ex), 'exceptions: no prefix leak');
  assert(parseExceptions('# S\n\nno list\n') === null, 'exceptions: missing block is null, so the caller fails closed');
  const agents = '# A\n\n## Agent skills\n\n### Issue tracker\n\none line\n\n## Next\na\nb\nc\n';
  const skip = sectionLines(agents, sectionsFor('AGENTS.md', ex));
  const r = measureMarkdown(agents, 'AGENTS.md', { skipLines: skip }).findings.map((f) => `${f.rule}@${f.line}`);
  assert(!r.some((x) => x.startsWith('short')), `exceptions: an exempt section is skipped, got ${r}`);
  assert(sectionLines(agents, sectionsFor('README.md', ex)).size === 0, 'exceptions: section rule is per file');
}

// ---------------------------------------------------------------- md mode

const git = (args, cwd) => {
  try {
    return execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
  } catch {
    return null;
  }
};
const gitLines = (out) => (out === null ? null : out.split('\n').map((l) => l.trim()).filter(Boolean));

/** The .md files to measure, relative to `top`, or { error } when the scope cannot be known. */
function mdTargets({ paths, all, base }, cwd, top, run = git) {
  const toTop = (abs) => relative(top, abs).split(sep).join('/');
  if (paths.length) {
    const out = [];
    for (const p of paths) {
      const abs = resolve(cwd, p);
      if (!existsSync(abs)) { unreadable.push(`${p} (ENOENT: requested path does not exist)`); continue; }
      if (statSync(abs).isDirectory()) out.push(...walk(abs, (n) => n.endsWith('.md')).map(toTop));
      else out.push(toTop(abs));
    }
    return { files: out };
  }
  if (all) {
    const tracked = gitLines(run(['-c', 'core.quotePath=false', 'ls-files', '--', '*.md'], top));
    return { files: tracked ?? walk(top, (n) => n.endsWith('.md')).map(toTop) };
  }
  const mb = gitLines(run(['merge-base', 'HEAD', base], top));
  if (!mb) return { error: `cannot resolve the merge-base with ${base}; pass --base <ref>, a path, or --all` };
  const changed = gitLines(run(['-c', 'core.quotePath=false', 'diff', '--name-only', '--diff-filter=d', '--no-renames', mb[0], '--', '*.md'], top));
  if (!changed) return { error: `git diff against ${mb[0]} failed; pass a path or --all` };
  const untracked = gitLines(run(['-c', 'core.quotePath=false', 'ls-files', '--others', '--exclude-standard', '--', '*.md'], top));
  if (!untracked) return { error: 'git ls-files --others failed; pass a path or --all' };
  return { files: [...changed, ...untracked] };
}

function mdMain(args) {
  const flag = (name) => args.includes(name);
  const baseIdx = args.indexOf('--base');
  const base = baseIdx >= 0 ? args[baseIdx + 1] : 'origin/main';
  const paths = args.filter((a, i) => !a.startsWith('--') && (baseIdx < 0 || i !== baseIdx + 1));
  const cwd = process.cwd();
  const top = gitLines(git(['rev-parse', '--show-toplevel'], cwd))?.[0] ?? cwd;

  // The standard ships two directories above this script's skill; fail closed without it,
  // because an unread exception list would report exempt files as violations or worse.
  const standardPath = resolve(dirname(fileURLToPath(import.meta.url)), '../../../references/writing-standard.md');
  let ex = null;
  try { ex = parseExceptions(readFileSync(standardPath, 'utf8')); } catch { /* reported below */ }
  if (!ex) {
    console.error(`md-audit: cannot read the exception list in ${standardPath} (## Exceptions fenced block)`);
    process.exit(2);
  }

  const scope = mdTargets({ paths, all: flag('--all'), base }, cwd, top);
  if (scope.error) { console.error(`md-audit: ${scope.error}`); process.exit(2); }
  const files = [...new Set(scope.files)].sort();
  const results = [];
  const skipped = [];
  for (const rel of files) {
    if (isExemptPath(rel, ex)) { skipped.push(rel); continue; }
    let content;
    try { content = readFileSync(join(top, rel), 'utf8'); } catch (err) { unreadable.push(`${rel} (${err?.code ?? 'unreadable'})`); continue; }
    results.push(measureMarkdown(content, rel, { skipLines: sectionLines(content, sectionsFor(rel, ex)) }));
  }
  const fails = results.reduce((n, r) => n + r.findings.filter((f) => f.level === 'fail').length, 0);
  const warns = results.reduce((n, r) => n + r.findings.filter((f) => f.level === 'warn').length, 0);

  if (flag('--json')) {
    console.log(JSON.stringify({ results, skipped, unreadable, fails, warns }, null, 2));
  } else {
    for (const r of results) {
      if (!r.findings.length) continue;
      console.log(`${r.path} (${r.bytes}B)`);
      for (const f of r.findings) console.log(`  L${f.line} ${f.level} ${f.rule}: ${f.detail}`);
    }
    if (skipped.length) console.log(`skipped as exceptions (${skipped.length}): ${skipped.join(', ')}`);
    console.log(`md-audit: ${results.length} file(s) measured, ${fails} fail, ${warns} warn`);
  }
  if (unreadable.length) {
    console.error(`md-audit: ${unreadable.length} path(s) could not be read, so this run does NOT cover them:`);
    for (const u of unreadable) console.error(`  ${u}`);
    process.exitCode = 2;
  } else if (fails) process.exitCode = 1;
  if (!flag('--json')) console.log(process.exitCode ? 'md-audit: FAIL' : 'md-audit: ok');
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
} else if (argv.includes('--md')) {
  mdMain(argv.filter((a) => a !== '--md'));
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
