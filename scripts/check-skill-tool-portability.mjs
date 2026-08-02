#!/usr/bin/env node
// Skill tool-portability guard: shared skill bodies read verbatim by three runtimes
// (Claude Code, Codex 0.135, Hermes Agent) must not assume a single interactive-input
// tool exists. Claude uses AskUserQuestion, Hermes uses clarify (via each body's compat
// table), and Codex exposes request_user_input only when available — so a body that just
// says "use AskUserQuestion" leaves Codex with no documented fallback.
//
// This guard scans every plugins/**/SKILL.md body for AskUserQuestion and requires each
// one to be EITHER a pilot carrying the standardized cross-runtime interaction mapping,
// OR an explicitly reviewed baseline-debt path. It FAILS on:
//   - a new/unaccounted skill that uses AskUserQuestion (neither pilot nor baseline)
//   - a pilot missing the standardized mapping
//   - a malformed or duplicate baseline entry, or one that overlaps a pilot
//   - a stale baseline entry (file gone, or debt removed — no AskUserQuestion left)
//
// FOLLOW-UP DEBT (issue #123): only the PILOTS below are migrated. The BASELINE paths
// still hardcode AskUserQuestion; migrating them to the standardized mapping is deferred
// fleet work. Move a path from BASELINE to PILOTS as it is migrated. The counts are
// deliberately not restated here — the arrays are the SoT and this run prints both live,
// so a number in this comment only goes stale on every migration and every plugin removal.
//
// Zero-dep: Node 18+ builtins only. Run: node scripts/check-skill-tool-portability.mjs --check

import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');

// A pilot PASSES when its body carries the standardized mapping: the section marker
// plus the Codex capability-aware tool name (only the pilots reference it).
const MARKER = 'Cross-runtime interactive input';
const CODEX_TOOL = 'request_user_input';

// Migrated skills — must carry the standardized mapping.
const PILOTS = [
  'plugins/interview/skills/interview-methodology/SKILL.md',
  'plugins/github-dev/skills/decompose-issue/SKILL.md',
  'plugins/council/skills/convene/SKILL.md',
  'plugins/voice-prompt/skills/voice-prompt/SKILL.md',
  'plugins/plaud-note-taking/skills/plaud-note-taking/SKILL.md',
];

// Reviewed baseline debt — skills that still hardcode AskUserQuestion, migration deferred.
const BASELINE = [
  'plugins/code-scout/skills/research-orchestrator/SKILL.md',
  'plugins/e2e-harness/skills/e2e-author/SKILL.md',
  'plugins/e2e-harness/skills/e2e-debug/SKILL.md',
  'plugins/github-dev/skills/cr-fix/SKILL.md',
  'plugins/github-dev/skills/post-merge/SKILL.md',
  'plugins/github-dev/skills/resolve-issue/SKILL.md',
  'plugins/gws-sync/skills/gws-sync/SKILL.md',
  'plugins/llm-wiki/skills/bootstrap-wiki/SKILL.md',
  'plugins/llm-wiki/skills/migrate-wiki/SKILL.md',
  'plugins/mem0-ops/skills/cleanup/SKILL.md',
  'plugins/project-init/skills/wiring/SKILL.md',
  'plugins/rules-forge/skills/write-rules/SKILL.md',
  'plugins/spec-state/skills/state-tracker/SKILL.md',
  'plugins/tcrei-prompt/skills/tcrei-prompt/SKILL.md',
  'plugins/translator/skills/translate-web-article/SKILL.md',
];

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

// Pure, testable core. Returns collected error strings (empty = pass).
export function checkSkillToolPortability({ root, pilots, baseline }) {
  const errors = [];
  const pilotSet = new Set(pilots);
  const body = (rel) => {
    const abs = join(root, rel);
    return existsSync(abs) ? readFileSync(abs, 'utf8') : null;
  };
  // AskUserQuestion appears in two NON-interactive contexts that must not count as
  // interactive debt: a Hermes compat-table row (`| AskUserQuestion | clarify |`) and a
  // frontmatter `allowed-tools:` list. A skill carrying only those (no actual gate in the
  // body) is not interactive — strip those lines before detecting real usage, else every
  // skill that merely documents the mapping gets pulled into the baseline / flagged.
  const stripMappingRefs = (b) =>
    b
      .split('\n')
      .filter((line) => !/^\s*\|\s*AskUserQuestion\s*\|/.test(line)) // Hermes compat-table row
      .filter((line) => !/^\s*allowed-tools\s*:/i.test(line)) // frontmatter tool list
      .join('\n');
  const usesAsk = (b) => stripMappingRefs(b).includes('AskUserQuestion');
  const hasMapping = (b) => b.includes(MARKER) && b.includes(CODEX_TOOL);

  // 1. Baseline hygiene — shape, duplicates, pilot overlap.
  const baseSet = new Set();
  for (const rel of baseline) {
    if (!/^plugins\/[^/]+\/skills\/.+\/SKILL\.md$/.test(rel)) {
      errors.push(`baseline: malformed entry "${rel}" (expected plugins/<plugin>/skills/<skill>/SKILL.md)`);
      continue;
    }
    if (baseSet.has(rel)) { errors.push(`baseline: duplicate entry "${rel}"`); continue; }
    baseSet.add(rel);
    if (pilotSet.has(rel)) errors.push(`baseline: "${rel}" is a pilot, not debt — remove it from the baseline`);
  }

  // 2. Pilots — must exist, still use AskUserQuestion, and carry the standardized mapping.
  for (const rel of pilots) {
    const b = body(rel);
    if (b === null) { errors.push(`pilot: missing file "${rel}"`); continue; }
    if (!usesAsk(b)) errors.push(`pilot: "${rel}" no longer references AskUserQuestion — update PILOTS`);
    if (!hasMapping(b)) {
      errors.push(`pilot: "${rel}" missing the standardized cross-runtime interaction mapping (needs "${MARKER}" + ${CODEX_TOOL})`);
    }
  }

  // 3. Baseline — each entry must still carry the debt, else it is stale.
  for (const rel of baseSet) {
    const b = body(rel);
    if (b === null) { errors.push(`baseline: stale entry "${rel}" — file not found`); continue; }
    if (!usesAsk(b)) errors.push(`baseline: stale entry "${rel}" — no longer uses AskUserQuestion (debt removed; drop from baseline)`);
  }

  // 4. Scan — every AskUserQuestion skill must be a pilot or a baseline entry.
  const accounted = new Set([...pilots, ...baseSet]);
  for (const abs of walkSkillFiles(join(root, 'plugins'))) {
    const b = readFileSync(abs, 'utf8');
    if (!usesAsk(b)) continue;
    const rel = relative(root, abs).split(sep).join('/');
    if (!accounted.has(rel)) {
      errors.push(`unaccounted: "${rel}" uses AskUserQuestion but is neither a pilot nor a reviewed baseline entry — add the cross-runtime interaction mapping or record it in the baseline`);
    }
  }

  return { errors };
}

const isMain = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  const { errors } = checkSkillToolPortability({ root: ROOT, pilots: PILOTS, baseline: BASELINE });
  if (errors.length) {
    console.error('skill tool-portability drift detected:');
    for (const e of errors) console.error(`  ${e}`);
    console.error('\nsee scripts/check-skill-tool-portability.mjs header for the pilot/baseline contract.');
    process.exit(1);
  }
  console.log(`skill tool-portability OK — ${PILOTS.length} pilots mapped, ${BASELINE.length} baseline debt paths, no unaccounted AskUserQuestion skills.`);
}
