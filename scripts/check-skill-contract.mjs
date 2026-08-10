#!/usr/bin/env node
// Skill-contract guard: the five frontmatter/body violations that make a skill fail
// SILENTLY on at least one of the three runtimes this repo ships to. Every one of them
// is invisible from the Claude Code side, which is why none of them was ever caught by
// review.
//
//   1. `description` over 1024 characters      → Codex 0.135 skips the skill entirely
//   2. unquoted `: ` inside `description`      → YAML reads a nested mapping; frontmatter dies
//   3. bare ${CLAUDE_PLUGIN_ROOT} in a shell block, with no guarded form anywhere in the
//      file                                    → Codex does not export it; the call dies at step one
//   4. `name` non-kebab or over 64 characters  → the command name stops being derivable
//   5. frontmatter not starting at byte 0      → no runtime finds it; the skill never triggers
//
// Not covered here, on purpose — each already has an owner:
//   check-skill-prose.mjs            informational only: 500-line ceiling, references depth
//   check-skill-tool-portability.mjs blocking: AskUserQuestion cross-runtime migration
//   check-doc-consistency.mjs        blocking: README/AGENTS name-sets and count strings
//   check-shell-portability.mjs      blocking: GNU-only shell constructs without a fallback
// This guard adds no overlap with any of them.
//
// The RED/GREEN fixtures run on every invocation before the scan, so a detector that
// quietly stopped detecting fails the commit instead of passing it.
//
// Zero-dep: Node 18+ builtins only. Deliberately does NOT import the bundled
// measure-skills.mjs parser — that script ships inside a distributable plugin and must
// not become a dependency of a repository guard.
//
// Run: node scripts/check-skill-contract.mjs [--selftest]

import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const DESCRIPTION_MAX = 1024; // Codex 0.135 silent-skip threshold
const NAME_MAX = 64;
const KEBAB = /^[a-z0-9]+(-[a-z0-9]+)*$/;

// --- frontmatter parsing (line-based; a YAML dependency is not worth it for five checks)

function splitFrontmatter(content) {
  if (!content.startsWith('---')) return null; // check 5 owns this case
  const rest = content.slice(3);
  const nl = rest.indexOf('\n');
  if (nl === -1) return null;
  const end = rest.indexOf('\n---', nl);
  if (end === -1) return null;
  return { lines: rest.slice(nl + 1, end).split('\n'), offset: 2 };
}

/**
 * The `key:` entry as { raw, value, style, line }. `style` is 'block' for a `|`/`>`
 * scalar, 'quoted' for a fully quoted scalar, 'plain' otherwise. For a block scalar the
 * value is the folded body, which is what the length limit applies to.
 */
function readField(fm, key) {
  const i = fm.lines.findIndex((l) => new RegExp(`^${key}\\s*:`).test(l));
  if (i === -1) return null;
  const raw = fm.lines[i].replace(new RegExp(`^${key}\\s*:\\s*`), '');
  const line = i + fm.offset;
  if (/^[>|][-+]?\d*\s*$/.test(raw)) {
    const body = [];
    for (const l of fm.lines.slice(i + 1)) {
      if (l.trim() !== '' && !/^\s/.test(l)) break; // next top-level key
      body.push(l.trim());
    }
    return { raw, value: body.join(' ').trim(), style: 'block', line };
  }
  const t = raw.trim();
  const quoted = t.length >= 2 && ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'")));
  return { raw, value: quoted ? t.slice(1, -1) : t, style: quoted ? 'quoted' : 'plain', line };
}

/** Lines inside fenced code blocks, as [lineNumber, text]. */
function fencedLines(content) {
  const out = [];
  let inFence = false;
  content.split('\n').forEach((line, idx) => {
    if (/^\s*```/.test(line)) { inFence = !inFence; return; }
    if (inFence) out.push([idx + 1, line]);
  });
  return out;
}

// --- the five checks, over one file's content

export function checkSkillContent(rel, content) {
  const errors = [];
  const add = (line, msg) => errors.push(`${rel}:${line}: ${msg}`);

  // 5. frontmatter must open at byte 0 and close.
  const fm = splitFrontmatter(content);
  if (!fm) {
    add(1, 'frontmatter does not start with `---` at byte 0 (or is never closed) — no runtime finds it, so the skill never triggers');
    return errors; // nothing else is parseable
  }

  // 4. name.
  const name = readField(fm, 'name');
  if (!name || name.value === '') {
    add(fm.offset, 'frontmatter has no non-empty `name`');
  } else {
    if (name.value.length > NAME_MAX) add(name.line, `\`name\` is ${name.value.length} chars (max ${NAME_MAX})`);
    if (!KEBAB.test(name.value)) add(name.line, `\`name\` "${name.value}" is not lowercase-kebab`);
  }

  // 1 + 2. description.
  const desc = readField(fm, 'description');
  if (!desc || desc.value === '') {
    add(fm.offset, 'frontmatter has no non-empty `description` — the skill has no trigger mechanism');
  } else {
    if (desc.value.length > DESCRIPTION_MAX) {
      add(desc.line, `\`description\` is ${desc.value.length} chars (max ${DESCRIPTION_MAX}) — Codex 0.135 silently skips the skill`);
    }
    if (desc.style === 'plain' && /:(\s|$)/.test(desc.raw)) {
      add(desc.line, 'unquoted `: ` in `description` — YAML parses it as a nested mapping and the frontmatter fails to load; wrap the value in double quotes or use a `>-` block scalar');
    }
  }

  // 3. bare ${CLAUDE_PLUGIN_ROOT} inside a shell block with no guarded form anywhere.
  const hasGuard = /\$\{CLAUDE_PLUGIN_ROOT:-/.test(content);
  if (!hasGuard) {
    for (const [line, text] of fencedLines(content)) {
      if (/\$\{?CLAUDE_PLUGIN_ROOT\b/.test(text)) {
        add(line, 'bare ${CLAUDE_PLUGIN_ROOT} in a code block with no cross-runtime resolver in this file — Codex 0.135 does not export it, so the call resolves to an empty prefix and dies at step one');
        break; // one report per file is enough to act on
      }
    }
  }

  return errors;
}

// --- scan

function walkSkillFiles(dir) {
  if (!existsSync(dir)) return [];
  const out = [];
  for (const ent of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, ent.name);
    if (ent.isDirectory()) out.push(...walkSkillFiles(p));
    else if (ent.name === 'SKILL.md') out.push(p);
  }
  return out;
}

export function checkSkillContracts(root) {
  const files = walkSkillFiles(join(root, 'plugins'));
  const errors = [];
  for (const abs of files) {
    const rel = relative(root, abs).split(sep).join('/');
    errors.push(...checkSkillContent(rel, readFileSync(abs, 'utf8')));
  }
  return { errors, scanned: files.length };
}

// --- fixtures: one RED per check, plus a GREEN that must stay clean

const GREEN = `---
name: good-skill
description: "Does one thing: and quotes the colon so YAML survives."
---

# Good skill

\`\`\`bash
PLUGIN_ROOT="\${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && PLUGIN_ROOT=plugins/example
node "$PLUGIN_ROOT/scripts/thing.mjs"
\`\`\`
`;

const RED = [
  {
    check: '1 description over 1024',
    expect: /max 1024/,
    content: `---\nname: long-desc\ndescription: ${'x'.repeat(1100)}\n---\n\nbody\n`,
  },
  {
    check: '2 unquoted colon-space in description',
    expect: /unquoted/,
    content: '---\nname: colon-desc\ndescription: Do a thing: then another thing\n---\n\nbody\n',
  },
  {
    check: '3 bare CLAUDE_PLUGIN_ROOT in a code block',
    expect: /bare \$\{CLAUDE_PLUGIN_ROOT\}/,
    content: '---\nname: bare-root\ndescription: Runs a bundled script.\n---\n\n```bash\nnode "${CLAUDE_PLUGIN_ROOT}/scripts/thing.mjs"\n```\n',
  },
  {
    check: '4 non-kebab name',
    expect: /not lowercase-kebab/,
    content: '---\nname: Bad_Name\ndescription: A skill.\n---\n\nbody\n',
  },
  {
    check: '5 frontmatter not at byte 0',
    expect: /byte 0/,
    content: '\n---\nname: shifted\ndescription: A skill.\n---\n\nbody\n',
  },
];

export function runFixtures() {
  const failures = [];
  for (const { check, expect, content } of RED) {
    const errs = checkSkillContent('fixture', content);
    if (!errs.some((e) => expect.test(e))) {
      failures.push(`RED "${check}" was not detected (got: ${errs.length ? errs.join(' | ') : 'no errors'})`);
    }
  }
  const greenErrs = checkSkillContent('fixture-green', GREEN);
  if (greenErrs.length) failures.push(`GREEN fixture was flagged: ${greenErrs.join(' | ')}`);
  return failures;
}

// --- main

const isMain = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  const fixtureFailures = runFixtures();
  if (fixtureFailures.length) {
    console.error('skill-contract SELFTEST FAILED — the guard cannot be trusted to detect anything:');
    for (const f of fixtureFailures) console.error(`  ${f}`);
    process.exit(1);
  }

  if (process.argv.includes('--selftest')) {
    console.log(`skill-contract selftest OK — ${RED.length} RED cases detected, GREEN fixture clean.`);
  } else {
    const { errors, scanned } = checkSkillContracts(ROOT);
    if (errors.length) {
      console.error(`skill-contract violations (${errors.length}):`);
      for (const e of errors) console.error(`  ${e}`);
      console.error('\nsee plugins/docs-forge/skills/skill-forge/references/runtime-contract.md for each failure mode.');
      process.exit(1);
    }
    console.log(`skill-contract OK — ${scanned} skills scanned, 5 silent-failure checks, selftest ${RED.length} RED + 1 GREEN.`);
  }
}
