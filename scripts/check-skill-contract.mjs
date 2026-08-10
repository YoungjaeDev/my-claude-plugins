#!/usr/bin/env node
// Skill-contract guard: the six frontmatter/body violations that make a skill fail
// SILENTLY on at least one of the three runtimes this repo ships to. Every one of them
// is invisible from the Claude Code side, which is why none of them was ever caught by
// review.
//
//   1. `description` over 1024 characters      → Codex 0.135 skips the skill entirely
//   2. unquoted `: ` inside `description`      → YAML reads a nested mapping; frontmatter dies
//   3. bare ${CLAUDE_PLUGIN_ROOT} in a fenced block that carries no guarded form of its
//      own                                     → Codex does not export it; the call dies at step one
//   4. `name` non-kebab or over 64 characters  → the command name stops being derivable
//   5. frontmatter not starting at byte 0      → no runtime finds it; the skill never triggers
//   6. `name` != skill directory name          → Claude/Codex use one identity, the
//                                                generated Hermes adapter another
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
/**
 * The YAML type a PLAIN scalar resolves to. Enumerating "bad" spellings one regex at a
 * time loses: `0x10`, `1e3`, and `.inf` all slipped past an ad-hoc list. This instead
 * implements the resolver's own closed pattern set (core schema plus the YAML 1.1
 * booleans PyYAML still applies), so anything it calls `string` really is one.
 */
function yamlPlainType(v) {
  if (v === '' || /^(~|null)$/i.test(v)) return 'null';
  if (/^(y|n|yes|no|true|false|on|off)$/i.test(v)) return 'bool';
  if (/^[-+]?(0|[1-9][0-9_]*)$/.test(v)) return 'int';
  if (/^[-+]?0o?[0-7_]+$/.test(v) || /^[-+]?0x[0-9a-f_]+$/i.test(v)) return 'int';
  if (/^[-+]?(\.[0-9]+|[0-9][0-9_]*(\.[0-9_]*)?)([eE][-+]?[0-9]+)?$/.test(v)) return 'float';
  if (/^[-+]?\.(inf|nan)$/i.test(v)) return 'float';
  return 'string';
}

// --- frontmatter parsing (line-based; a YAML dependency is not worth it for six checks)

// Both delimiters must be a line that is exactly `---`. Matching a bare prefix would
// accept `---invalid` as an opener and `----` as a closer, so a skill whose frontmatter
// never parses would pass this guard — the opposite of what check 5 exists for.
const isDelimiter = (line) => line.replace(/\r$/, '') === '---';

function splitFrontmatter(content) {
  const lines = content.split('\n');
  if (lines.length < 2 || !isDelimiter(lines[0])) return null; // check 5 owns this case
  const end = lines.findIndex((l, i) => i > 0 && isDelimiter(l));
  if (end === -1) return null;
  return { lines: lines.slice(1, end), offset: 2 };
}

/** Continuation lines belonging to the scalar that starts at index `i`, untrimmed. */
function continuationLines(lines, i) {
  const out = [];
  for (const l of lines.slice(i + 1)) {
    if (l.trim() !== '' && !/^\s/.test(l)) break; // a new top-level key ends the scalar
    out.push(l);
  }
  return out;
}

const BLOCK_HEADER = /^[>|]([1-9][-+]?|[-+][1-9]?)?\s*(#.*)?$/;

/**
 * Drop a YAML inline comment — a `#` that starts the line or follows whitespace, outside
 * any quotes. Without this, `name: foo # rationale` was read as the value
 * "foo # rationale" and failed the kebab check, and a quoted description followed by a
 * comment stopped looking quoted and tripped the colon-space check. Both are valid YAML,
 * and this guard blocks commits, so a false positive here is worse than a miss.
 */
function stripInlineComment(s) {
  let quote = null;
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (quote) {
      if (c === quote) quote = null;
    } else if (c === '"' || c === "'") {
      quote = c;
    } else if (c === '#' && (i === 0 || /\s/.test(s[i - 1]))) {
      return s.slice(0, i);
    }
  }
  return s;
}

/**
 * Decode a block scalar to the string YAML would produce. The 1024 threshold is a hard
 * cliff, so an off-by-one at the boundary defeats the check: `description: |` over a
 * 1024-character body decodes to 1025 because clipping keeps one trailing newline, and
 * a naive join reports 1024 and lets Codex skip the skill anyway.
 *
 * `|`/`>` clip to exactly one trailing newline, `|-`/`>-` strip it, `|+`/`>+` keep every
 * trailing blank line. Folded scalars join lines within a paragraph using a space and
 * separate paragraphs with a newline.
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
 * The `key:` entry as { raw, value, style, line }. `style` is 'block' for a `|`/`>`
 * scalar, 'quoted' for a fully quoted scalar, 'plain' otherwise.
 *
 * Every style folds its indented continuation lines into `value`. A plain or quoted
 * scalar may legally span lines, and reading only the first one under-counts the
 * length: `description: short` followed by 1,100 indented characters decodes to 1,106
 * for YAML, so a first-line-only read passes the 1024 check and Codex still skips the
 * skill — the exact silent failure this guard exists to stop.
 */
function readField(fm, key) {
  const i = fm.lines.findIndex((l) => new RegExp(`^${key}\\s*:`).test(l));
  if (i === -1) return null;
  const head = fm.lines[i].replace(new RegExp(`^${key}\\s*:\\s*`), '');
  const line = i + fm.offset;
  if (BLOCK_HEADER.test(head)) {
    return { raw: head, value: decodeBlockScalar(head, continuationLines(fm.lines, i)), style: 'block', line };
  }
  const cont = continuationLines(fm.lines, i);
  const raw = stripInlineComment([head.trim(), ...cont.map((l) => l.trim())].join(' ')).trim();
  const quoted = raw.length >= 2 && ((raw.startsWith('"') && raw.endsWith('"')) || (raw.startsWith("'") && raw.endsWith("'")));
  // An empty head with indented lines under it is a nested node — a block sequence or a
  // mapping — not a scalar at all. Joining them produced text like "- first" that read
  // as a perfectly ordinary string.
  const nested = head.trim() === '' && cont.some((l) => l.trim() !== '');
  return { raw, value: quoted ? raw.slice(1, -1) : raw, style: quoted ? 'quoted' : 'plain', line, nested };
}

/**
 * Fenced code blocks, each as an array of [lineNumber, text]. Both CommonMark fence
 * characters are recognized, and a fence only closes on its own character at the same
 * or greater length — otherwise a ``` inside a ~~~ block silently ends it and every
 * later line reads as prose.
 */
function fencedBlocks(content) {
  const out = [];
  let cur = null;
  content.split('\n').forEach((line, idx) => {
    const m = line.match(/^\s*(`{3,}|~{3,})/);
    if (m) {
      if (!cur) cur = { char: m[1][0], len: m[1].length, lines: [] };
      else if (m[1][0] === cur.char && m[1].length >= cur.len) { out.push(cur.lines); cur = null; }
      return;
    }
    if (cur) cur.lines.push([idx + 1, line]);
  });
  if (cur) out.push(cur.lines); // unterminated fence — still worth inspecting
  return out;
}

// --- the six checks, over one file's content

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
    // A plain scalar that YAML reads as a boolean, null, or number is not a string, and
    // the runtime validators require one. `name: on` passes the kebab and directory
    // checks here as the text "on" while decoding to `true` — CI green, skill unloadable.
    const nameType = name.style === 'plain' ? yamlPlainType(name.value) : 'string';
    if (name.nested || nameType !== 'string' || (name.style === 'plain' && /^[[{]/.test(name.value))) {
      add(name.line, `\`name\` "${name.value}" is not a YAML string (${name.nested ? 'nested node' : /^[[{]/.test(name.value) ? 'flow collection' : nameType}) — quote it`);
    }
    // 6. name must equal the directory. Claude Code and Codex take the command's last
    // segment from the frontmatter name while the generated Hermes adapter registers by
    // directory name, so a mismatch splits one skill into two identities across runtimes.
    const dir = rel.match(/([^/]+)\/SKILL\.md$/);
    if (dir && name.value !== dir[1]) {
      add(name.line, `\`name\` "${name.value}" does not match the skill directory "${dir[1]}" — Claude/Codex would use the frontmatter name and the Hermes adapter the directory name`);
    }
  }

  // 1 + 2. description.
  const desc = readField(fm, 'description');
  if (!desc || desc.value === '') {
    add(fm.offset, 'frontmatter has no non-empty `description` — the skill has no trigger mechanism');
  } else if (desc.nested || (desc.style === 'plain' && (yamlPlainType(desc.value) !== 'string' || /^[[{]/.test(desc.value)))) {
    // Same trap as `name`: this line parser sees text where YAML sees a boolean, a
    // number, a flow collection, or a nested node. `description: true` reads as "true"
    // here and passes the emptiness and length checks, while the Codex skill validator
    // requires a non-empty string and rejects the plugin.
    const kind = desc.nested ? 'nested node' : /^[[{]/.test(desc.value) ? 'flow collection' : yamlPlainType(desc.value);
    add(desc.line, `\`description\` "${desc.value}" is not a YAML string (${kind}) — the Codex skill validator requires a string; quote it`);
  } else {
    if (desc.value.length > DESCRIPTION_MAX) {
      add(desc.line, `\`description\` is ${desc.value.length} chars (max ${DESCRIPTION_MAX}) — Codex 0.135 silently skips the skill`);
    }
    if (desc.style === 'plain' && /:(\s|$)/.test(desc.raw)) {
      add(desc.line, 'unquoted `: ` in `description` — YAML parses it as a nested mapping and the frontmatter fails to load; wrap the value in double quotes or use a `>-` block scalar');
    }
  }

  // 3. bare ${CLAUDE_PLUGIN_ROOT}, judged PER BLOCK. A file-wide exemption let one
  // correct resolver block vouch for every other block, so a later block running
  // ${CLAUDE_PLUGIN_ROOT}/scripts/x.sh directly still passed and still died on Codex.
  // The unit is the fenced block a reader would copy and run.
  for (const block of fencedBlocks(content)) {
    const guarded = block.some(([, t]) => /\$\{CLAUDE_PLUGIN_ROOT:-/.test(t));
    if (guarded) continue;
    const hit = block.find(([, t]) => /\$\{?CLAUDE_PLUGIN_ROOT\b/.test(t) && !/#\s*portability-ok:/.test(t));
    if (hit) {
      add(hit[0], 'bare ${CLAUDE_PLUGIN_ROOT} in a fenced block that carries no cross-runtime resolver — Codex 0.135 does not export it, so the path resolves to an empty prefix and the block dies at step one. Add the resolver to this block, or mark the line `# portability-ok: <reason>`');
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
    check: '1b multi-line plain scalar counts every line',
    expect: /max 1024/,
    content: `---\nname: folded-desc\ndescription: short\n  ${'y'.repeat(1100)}\n---\n\nbody\n`,
  },
  {
    check: '1c indicator order `|2-` is a block scalar header',
    expect: /max 1024/,
    content: `---\nname: block-order\ndescription: |2-\n  ${'z'.repeat(1100)}\n---\n\nbody\n`,
  },
  {
    check: '1e clip chomping pushes a 1024-char block body to 1025',
    expect: /is 1025 chars/,
    content: `---\nname: clip-chomp\ndescription: |\n  ${'z'.repeat(1024)}\n---\n\nbody\n`,
  },
  {
    check: '1f explicit indent `|-2` keeps the content YAML keeps',
    expect: /is 1026 chars/,
    content: `---\nname: explicit-indent\ndescription: |-2\n    ${'z'.repeat(1024)}\n---\n\nbody\n`,
  },
  {
    check: '1d 1025 chars is over, 1024 is not (boundary)',
    expect: /is 1025 chars/,
    content: `---\nname: boundary\ndescription: ${'z'.repeat(1025)}\n---\n\nbody\n`,
  },
  {
    check: '2 unquoted colon-space in description',
    expect: /unquoted/,
    content: '---\nname: colon-desc\ndescription: Do a thing: then another thing\n---\n\nbody\n',
  },
  {
    check: '2b plain `description` that YAML decodes as a boolean',
    expect: /is not a YAML string \(bool\)/,
    content: '---\nname: bool-desc\ndescription: true\n---\n\nbody\n',
  },
  {
    check: '2c plain `description` that YAML decodes as a flow collection',
    expect: /is not a YAML string \(flow collection\)/,
    content: '---\nname: flow-desc\ndescription: []\n---\n\nbody\n',
  },
  {
    check: '2d hex int slips past an ad-hoc numeric regex',
    expect: /is not a YAML string \(int\)/,
    content: '---\nname: hex-desc\ndescription: 0x10\n---\n\nbody\n',
  },
  {
    check: '2e exponent float',
    expect: /is not a YAML string \(float\)/,
    content: '---\nname: exp-desc\ndescription: 1e3\n---\n\nbody\n',
  },
  {
    check: '2f block sequence is a nested node, not a scalar',
    expect: /is not a YAML string \(nested node\)/,
    content: '---\nname: seq-desc\ndescription:\n  - first\n  - second\n---\n\nbody\n',
  },
  {
    check: '2g a `#` inside a quoted description is not a comment',
    expect: /is 1029 chars/,
    content: `---\nname: hash-desc\ndescription: "# ${'z'.repeat(1027)}" # trailing note\n---\n\nbody\n`,
  },
  {
    check: '3 bare CLAUDE_PLUGIN_ROOT in a code block',
    expect: /bare \$\{CLAUDE_PLUGIN_ROOT\}/,
    content: '---\nname: bare-root\ndescription: Runs a bundled script.\n---\n\n```bash\nnode "${CLAUDE_PLUGIN_ROOT}/scripts/thing.mjs"\n```\n',
  },
  {
    check: '3b guarded block does not vouch for a later unguarded block',
    expect: /bare \$\{CLAUDE_PLUGIN_ROOT\}/,
    content: '---\nname: two-blocks\ndescription: A skill.\n---\n\n```bash\nPLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"\n```\n\n```bash\nbash "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh"\n```\n',
  },
  {
    check: '3c tilde fence is a code block too',
    expect: /bare \$\{CLAUDE_PLUGIN_ROOT\}/,
    content: '---\nname: tilde-fence\ndescription: A skill.\n---\n\n~~~bash\nbash "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh"\n~~~\n',
  },
  {
    check: '4 non-kebab name',
    expect: /not lowercase-kebab/,
    content: '---\nname: Bad_Name\ndescription: A skill.\n---\n\nbody\n',
  },
  {
    check: '4b plain `name` that YAML decodes as a boolean',
    expect: /`name` "on" is not a YAML string \(bool\)/,
    rel: 'plugins/demo/skills/on/SKILL.md',
    content: '---\nname: on\ndescription: A skill.\n---\n\nbody\n',
  },
  {
    check: '4c plain `name` that YAML decodes as a number',
    expect: /`name` "123" is not a YAML string \(int\)/,
    rel: 'plugins/demo/skills/123/SKILL.md',
    content: '---\nname: 123\ndescription: A skill.\n---\n\nbody\n',
  },
  {
    check: '5 frontmatter not at byte 0',
    expect: /byte 0/,
    content: '\n---\nname: shifted\ndescription: A skill.\n---\n\nbody\n',
  },
  {
    check: '5b opener must be exactly `---`, not a prefix',
    expect: /byte 0/,
    content: '---invalid\nname: prefixed\ndescription: A skill.\n---\n\nbody\n',
  },
  {
    check: '5c closer must be exactly `---`, not `----`',
    expect: /byte 0/,
    content: '---\nname: unclosed\ndescription: A skill.\n----\n\nbody\n',
  },
  {
    check: '6 name does not match the skill directory',
    expect: /does not match the skill directory/,
    rel: 'plugins/demo/skills/foo/SKILL.md',
    content: '---\nname: bar\ndescription: A skill.\n---\n\nbody\n',
  },
];

export function runFixtures() {
  const failures = [];
  for (const { check, expect, content, rel } of RED) {
    const errs = checkSkillContent(rel ?? 'fixture', content);
    if (!errs.some((e) => expect.test(e))) {
      failures.push(`RED "${check}" was not detected (got: ${errs.length ? errs.join(' | ') : 'no errors'})`);
    }
  }
  // The GREEN path is checked at a real skill path so the name-vs-directory rule is
  // exercised in its passing direction too, not only when it fires.
  const greenErrs = checkSkillContent('plugins/demo/skills/good-skill/SKILL.md', GREEN);
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
    console.log(`skill-contract OK — ${scanned} skills scanned, 6 silent-failure checks, selftest ${RED.length} RED + 1 GREEN.`);
  }
}
