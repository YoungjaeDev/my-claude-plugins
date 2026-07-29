#!/usr/bin/env node
// Mechanical content-structure sweep for all plugin skills (issue #117).
// No LLM. Node 18+ built-ins only. Run from repo root:
//   node docs/audit/measure-skills.mjs            # prints CSV to stdout
//   node docs/audit/measure-skills.mjs --md       # prints a markdown table
// Metrics per plugins/<plugin>/skills/<skill>/SKILL.md:
//   lines        — SKILL.md line count (best-practice ceiling: 500)
//   body_tokens  — rough token estimate of the whole file (chars/4)
//   desc_chars   — frontmatter `description` length (Codex silent-skip cap: 1024)
//   desc_tokens  — description token estimate (chars/4); aggregate vs ~8k skills-list budget
//   sections     — count of `## ` / `### ` headings in the body
//   ref_files    — file count under references/ (0 = none)
//   ref_depth    — max path depth under references/ (must be 1; >1 = nested subdir)
//   has_scripts  — whether a scripts/ dir exists beside SKILL.md
// Violation flags (columns v_*): lines>500, desc>1024, ref_depth>1.

import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, relative } from 'node:path';

const LINE_CEIL = 500;
const DESC_CAP = 1024; // Codex 0.135 silently skips skills whose description exceeds this
const SKILLS_LIST_BUDGET_TOKENS = 8000; // aggregate skills-list budget (~2% of a 400k window)

function estTokens(str) {
  return Math.round(str.length / 4);
}

// Minimal frontmatter description extractor. Handles `description: ...`,
// double-quoted values, and `>-` / `|` block scalars. Good enough for a sweep.
function extractDescription(text) {
  text = text.replace(/\r\n/g, '\n'); // normalize CRLF so `$`-anchored regex matches
  if (!text.startsWith('---')) return '';
  const end = text.indexOf('\n---', 3);
  if (end === -1) return '';
  const fm = text.slice(3, end);
  const lines = fm.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^description:\s*(.*)$/);
    if (!m) continue;
    let val = m[1].trim();
    if (val === '>-' || val === '>' || val === '|' || val === '|-') {
      // block scalar: gather following more-indented lines
      const buf = [];
      for (let j = i + 1; j < lines.length; j++) {
        if (/^\S/.test(lines[j])) break; // dedent = key ended
        buf.push(lines[j].trim());
      }
      return buf.join(' ').trim();
    }
    // strip surrounding quotes
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1);
    }
    return val;
  }
  return '';
}

function walkDepth(dir, base, acc) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    // .DS_Store is gitignored, so it never shows in a diff -- but this script
    // walks the working tree, and on a Mac Finder leaves one in every visited
    // directory, inflating ref_files by one for the affected skill.
    if (entry.name.startsWith('.')) continue;
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      walkDepth(full, base, acc);
    } else {
      const rel = relative(base, full);
      const depth = rel.split('/').length; // file directly in references/ => depth 1
      acc.files.push(rel);
      acc.maxDepth = Math.max(acc.maxDepth, depth);
    }
  }
}

function findSkills(root) {
  const out = [];
  const pluginsDir = join(root, 'plugins');
  for (const plugin of readdirSync(pluginsDir)) {
    const skillsDir = join(pluginsDir, plugin, 'skills');
    if (!existsSync(skillsDir) || !statSync(skillsDir).isDirectory()) continue;
    for (const skill of readdirSync(skillsDir)) {
      const skillDir = join(skillsDir, skill);
      const md = join(skillDir, 'SKILL.md');
      if (existsSync(md)) out.push({ plugin, skill, skillDir, md });
    }
  }
  return out;
}

function measure(root) {
  const rows = [];
  for (const s of findSkills(root)) {
    const text = readFileSync(s.md, 'utf8');
    const lines = text.split('\n').length;
    const desc = extractDescription(text);
    const sections = (text.match(/^#{2,3}\s/gm) || []).length;
    const refDir = join(s.skillDir, 'references');
    let refFiles = 0, refDepth = 0;
    if (existsSync(refDir) && statSync(refDir).isDirectory()) {
      const acc = { files: [], maxDepth: 0 };
      walkDepth(refDir, refDir, acc);
      refFiles = acc.files.length;
      refDepth = acc.maxDepth;
    }
    const hasScripts = existsSync(join(s.skillDir, 'scripts'));
    rows.push({
      plugin: s.plugin,
      skill: s.skill,
      lines,
      body_tokens: estTokens(text),
      desc_chars: desc.length,
      desc_tokens: estTokens(desc),
      sections,
      ref_files: refFiles,
      ref_depth: refDepth,
      has_scripts: hasScripts ? 1 : 0,
      v_lines: lines > LINE_CEIL ? 1 : 0,
      v_desc: desc.length > DESC_CAP ? 1 : 0,
      v_refdepth: refDepth > 1 ? 1 : 0,
    });
  }
  return rows;
}

const root = process.cwd();
const rows = measure(root);
// Ties on `lines` used to keep readdir order, which differs between ext4 and
// APFS -- so regenerating skill-measurements.csv on a Mac produced a diff with
// no content change (there are real ties in it: 39, 52, 67, 81). Break ties on
// plugin+skill with plain byte comparison; localeCompare would swap one
// platform dependency for an ICU one.
const byLinesThenName = (a, b) =>
  b.lines - a.lines ||
  (a.plugin < b.plugin ? -1 : a.plugin > b.plugin ? 1 : 0) ||
  (a.skill < b.skill ? -1 : a.skill > b.skill ? 1 : 0);
const cols = ['plugin', 'skill', 'lines', 'body_tokens', 'desc_chars', 'desc_tokens',
  'sections', 'ref_files', 'ref_depth', 'has_scripts', 'v_lines', 'v_desc', 'v_refdepth'];

if (process.argv.includes('--md')) {
  console.log('| ' + cols.join(' | ') + ' |');
  console.log('|' + cols.map(() => '---').join('|') + '|');
  for (const r of rows.sort(byLinesThenName)) {
    console.log('| ' + cols.map((c) => r[c]).join(' | ') + ' |');
  }
} else {
  console.log(cols.join(','));
  for (const r of rows.sort(byLinesThenName)) {
    console.log(cols.map((c) => r[c]).join(','));
  }
}

// Summary to stderr so CSV/MD on stdout stays clean.
const totalDescTokens = rows.reduce((a, r) => a + r.desc_tokens, 0);
const viol = rows.filter((r) => r.v_lines || r.v_desc || r.v_refdepth);
console.error(`\n# skills measured: ${rows.length}`);
console.error(`# line-ceiling (>${LINE_CEIL}) violators: ${rows.filter((r) => r.v_lines).length}`);
console.error(`# desc-cap (>${DESC_CAP}) violators: ${rows.filter((r) => r.v_desc).length}`);
console.error(`# ref-depth (>1) violators: ${rows.filter((r) => r.v_refdepth).length}`);
console.error(`# any-violation skills: ${viol.length}`);
console.error(`# aggregate desc tokens: ${totalDescTokens} / ${SKILLS_LIST_BUDGET_TOKENS} skills-list budget`);
