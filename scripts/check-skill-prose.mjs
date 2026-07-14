#!/usr/bin/env node
// Skill-prose progressive-disclosure smell detector — INFORMATIONAL ONLY.
//
// Two post-measurement warnings, never a failure:
//   1. A skill SKILL.md or bundled reference/asset doc over ~500 lines — the
//      widely-cited progressive-disclosure ceiling. Over it, a body is almost
//      certainly carrying reference-grade material it should offload.
//   2. A SKILL.md that points at a bundled file nested deeper than one directory
//      level (e.g. references/templates/base.md) — the flat-references convention
//      is exactly one level (files directly under references/).
//
// This is a measurement aid, not a gate: it prints to stderr and ALWAYS exits 0,
// so it never blocks a commit or CI run. Wire it in as a non-blocking step.
//
// Zero-dep: Node 18+ builtins only. Run: node scripts/check-skill-prose.mjs

import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const LINE_CEILING = 500;

// Match a bundled-path reference with a subdirectory under references/ / assets/ /
// scripts/ (i.e. depth >= 2). One capture per whole path so the warning can quote it.
const DEEP_REF_RE = /\b(references|assets|scripts)\/[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+(?:\/[A-Za-z0-9._-]+)*/g;

function walkFiles(dir, filterName) {
  if (!existsSync(dir)) return [];
  const out = [];
  let entries;
  try {
    entries = readdirSync(dir, { withFileTypes: true });
  } catch {
    return out; // unreadable dir (permission / mid-walk delete) — skip, stay non-blocking
  }
  for (const ent of entries) {
    const p = join(dir, ent.name);
    if (ent.isDirectory()) out.push(...walkFiles(p, filterName));
    else if (!filterName || filterName(ent.name)) out.push(p);
  }
  return out;
}

// Read helper that never throws — a file removed mid-walk or an EACCES must not
// abort the informational sweep (the whole script is contractually exit-0).
function safeRead(abs) {
  try {
    return readFileSync(abs, 'utf8');
  } catch {
    return null;
  }
}

// Pure, testable core. Returns an array of warning strings.
export function collectSkillProseWarnings({ root, lineCeiling = LINE_CEILING }) {
  const warnings = [];
  const skillsRoot = join(root, 'plugins');
  const rel = (abs) => relative(root, abs).split(sep).join('/');

  // 1. Line-count sweep over every markdown doc under a plugin's skills/ tree.
  for (const abs of walkFiles(skillsRoot, (n) => n.endsWith('.md'))) {
    const r = rel(abs);
    if (!r.includes('/skills/')) continue;
    const content = safeRead(abs);
    if (content === null) continue;
    const lines = content.split('\n').length;
    if (lines > lineCeiling) {
      warnings.push(`line-ceiling: ${r} is ${lines} lines (> ${lineCeiling}) — consider offloading reference-grade detail`);
    }
  }

  // 2. Deep bundled-reference sweep over each SKILL.md body.
  for (const abs of walkFiles(skillsRoot, (n) => n === 'SKILL.md')) {
    const body = safeRead(abs);
    if (body === null) continue;
    const seen = new Set();
    for (const m of body.matchAll(DEEP_REF_RE)) {
      const path = m[0];
      if (seen.has(path)) continue;
      seen.add(path);
      warnings.push(`deep-reference: ${rel(abs)} points at "${path}" (nested > 1 level under ${m[1]}/) — flat-references convention is depth 1`);
    }
  }

  return warnings;
}

const isMain = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  try {
    const warnings = collectSkillProseWarnings({ root: ROOT });
    if (warnings.length) {
      console.error(`skill-prose: ${warnings.length} informational warning(s) (non-blocking):`);
      for (const w of warnings) console.error(`  ${w}`);
    } else {
      console.error('skill-prose: no progressive-disclosure warnings.');
    }
  } catch (err) {
    // Top-level exit-0 fallback — a scan error is still non-blocking by contract.
    console.error(`skill-prose: scan aborted (${err?.message ?? err}) — treated as non-blocking.`);
  }
  // Always non-blocking — this is a measurement aid, never a gate.
  process.exit(0);
}
