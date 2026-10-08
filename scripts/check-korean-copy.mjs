#!/usr/bin/env node
// Translationese guard for README.md: the forbidden-phrase table, the comma after a
// connective ending, and native counting words where a number belongs. A README once
// shipped about 40 of these (21 in-text arrows, 13 connective commas) and nothing caught
// them, because the only checker lives in the deck plugin and reads slides, not Markdown.
//
// The phrase list is NOT copied here: it is parsed at run time from the
// "### 금지 표기" table in plugins/deck/templates/rules/deck-copy.md, so the deck rule
// and this guard cannot drift. The comma and native-count checks are ports of
// plugins/deck/scripts/check_copy.py (COMMA, COMMA_OK, NATIVE); keep them in step.
// deck's slide-tone rules (labels, source lines, tag chips) are out of scope.
//
// Scanned: text outside fenced code, inline code spans and HTML tags.
// The RED/GREEN fixtures run on every invocation before the scan.
//
// Zero-dep: Node 18+ builtins only.
// Run: node scripts/check-korean-copy.mjs [--selftest] [FILE...]   (default README.md)

import { readFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const RULES = join(ROOT, 'plugins/deck/templates/rules/deck-copy.md');
const TABLE_HEADING = '### 금지 표기';
const TABLE_COLUMNS = ['쓰지 않는다', '대신', '검사식'];
// Table rows that are deck vocabulary (slide labels, the instructor's own wording),
// not translationese. Keyed by the 검사식 cell.
const ALLOW = new Map([
  ['수업', 'deck calls a session 실습; README has no sessions'],
  ['따라 ?하기', 'slide label rule'],
  ['알아 ?두기', 'slide label rule'],
  ['꿀팁', 'slide label rule'],
  ['함께 해요', 'slide label rule'],
  ['중소기업', 'instructor bio rule'],
  ['고친다', 'agent-loop wording rule for slides; plain 고친다 is fine in prose'],
]);
const COMMA = /([가-힣]*(?:고|며|지만|면서|어서|아서|해서)),/g;
const COMMA_OK = new Set(['보고', '광고', '창고', '참고', '최고', '재고', '경고', '원고', '사고']);
const NATIVE = /(?<![가-힣])(셋|넷|다섯|여섯)(이|을|은|으로|에게|에|의|과|와|도|만|뿐|이다)?(?![가-힣])(?!\s*(?:다(?![가-힣])|번째))/g;

/** Split a markdown table row on | outside backtick spans; \\| stays a literal pipe. */
function cells(row) {
  let r = row.trim().replace(/^\|/, '');
  if (r.endsWith('|') && !r.endsWith('\\|')) r = r.slice(0, -1);
  const out = [];
  let cur = '';
  let tick = false;
  for (let i = 0; i < r.length; i++) {
    const c = r[i];
    if (c === '\\' && r[i + 1] === '|') { cur += '|'; i++; continue; }
    if (c === '`') tick = !tick;
    if (c === '|' && !tick) { out.push(cur.trim()); cur = ''; } else cur += c;
  }
  out.push(cur.trim());
  return out;
}

/** [{rx, re, label}] from the first table under TABLE_HEADING, minus ALLOW. */
function bannedPatterns(md) {
  const lines = md.split('\n');
  const start = lines.findIndex((l) => l.trim() === TABLE_HEADING);
  if (start < 0) throw new Error(`heading '${TABLE_HEADING}' not found`);
  const rows = [];
  for (const line of lines.slice(start + 1)) {
    if (line.startsWith('#')) break;
    if (line.trimStart().startsWith('|')) rows.push(cells(line));
    else if (rows.length) break;
  }
  if (rows.length < 2 || rows[0].slice(0, 3).join('|') !== TABLE_COLUMNS.join('|')) {
    throw new Error(`table under '${TABLE_HEADING}' must start with columns ${TABLE_COLUMNS.join(' | ')}`);
  }
  const out = [];
  for (const row of rows.slice(2)) {
    if (row.length < 3) continue;
    for (const [, rx] of row[2].matchAll(/`([^`]+)`/g)) {
      const re = new RegExp(rx); // a bad regex should fail loudly, not silently match nothing
      if (!ALLOW.has(rx)) out.push({ rx, re, label: row[0] });
    }
  }
  if (!out.length) throw new Error(`table under '${TABLE_HEADING}' has no regex in backticks`);
  return out;
}

/** [[lineNo, text]] for prose lines: fences dropped, code spans and HTML tags blanked. */
function proseLines(md) {
  const out = [];
  let fence = null;
  md.split('\n').forEach((line, i) => {
    const f = line.match(/^\s*(`{3,}|~{3,})/);
    if (fence) { if (f && f[1][0] === fence[0] && f[1].length >= fence.length) fence = null; return; }
    if (f) { fence = f[1]; return; }
    out.push([i + 1, line.replace(/(`+)[^`]*?\1/g, ' ').replace(/<[^>]*>/g, ' ')]);
  });
  return out;
}

/** Labels of every violation in one prose line. */
function lineHits(text, banned) {
  const hits = banned.filter((b) => b.re.test(text)).map((b) => b.label);
  for (const m of text.matchAll(COMMA)) if (!COMMA_OK.has(m[1])) hits.push(`쉼표: ${m[0]}`);
  for (const m of text.matchAll(NATIVE)) hits.push(`고유어 수사: ${m[0]}`);
  return hits;
}

const FIXTURE_RULES = [
  '# x', '### 금지 표기', '',
  '| 쓰지 않는다 | 대신 | 검사식 |', '|---|---|---|',
  '| ~에 대해(서) | 목적격 | `에 대해` |',
  '| 수업 | 실습 | `수업` |',
  '| 글 속 화살표 | 중간점 | `→` |',
  '| 둘 중 하나 | 하나로 | `가\\|나` |',
  '', '## next', '| 쓰지 않는다 | 대신 | 검사식 |', '|---|---|---|', '| x | y | `NOTME` |',
].join('\n');

function runFixtures() {
  const failures = [];
  const eq = (name, got, want) => {
    if (JSON.stringify(got) !== JSON.stringify(want)) failures.push(`${name}: got ${JSON.stringify(got)}, want ${JSON.stringify(want)}`);
  };
  const banned = bannedPatterns(FIXTURE_RULES);
  eq('table parse (allow-list drops 수업, next table ignored)', banned.map((b) => b.rx), ['에 대해', '→', '가|나']);
  const hits = (t) => lineHits(t, banned);
  eq('RED forbidden phrase', hits('모델에 대해 본다'), ['~에 대해(서)']);
  eq('RED arrow', hits('설치 → 실행'), ['글 속 화살표']);
  eq('RED escaped pipe', hits('다나'), ['둘 중 하나']);
  eq('RED connective comma', hits('파일을 읽고, 쓴다'), ['쉼표: 읽고,']);
  eq('RED native count', hits('플러그인 셋을 쓴다'), ['고유어 수사: 셋을']);
  eq('GREEN allowed comma word', hits('참고, 이것'), []);
  eq('GREEN native count before 다', hits('셋 다 본다'), []);
  eq('GREEN allow-listed row', hits('수업 자료'), []);
  const md = [
    '설치 → 실행',
    '```bash',
    'a → b 에 대해',
    '```',
    '`a → b` 는 코드다',
    '<img alt="에 대해" src="x"> 본문',
    '~~~',
    '셋을 쓴다',
    '~~~',
    '끝에 대해',
  ].join('\n');
  eq('prose extraction skips fences, code spans, HTML tags',
    proseLines(md).map(([n, t]) => [n, t.trim()]).filter(([, t]) => t),
    [[1, '설치 → 실행'], [5, '는 코드다'], [6, '본문'], [10, '끝에 대해']]);
  try {
    bannedPatterns('# none');
    failures.push('RED malformed rule file was accepted');
  } catch { /* expected */ }
  const real = bannedPatterns(readFileSync(RULES, 'utf8'));
  if (!real.some((b) => b.rx === '→')) failures.push('real deck-copy table yielded no `→` pattern');
  return failures;
}

// --- main

const failures = runFixtures();
if (failures.length) {
  console.error('korean-copy SELFTEST FAILED — the guard cannot be trusted to detect anything:');
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}
if (process.argv.includes('--selftest')) {
  console.log('korean-copy selftest OK');
  process.exit(0);
}
const banned = bannedPatterns(readFileSync(RULES, 'utf8'));
const files = process.argv.slice(2).filter((a) => !a.startsWith('--'));
const bad = [];
for (const file of files.length ? files : [join(ROOT, 'README.md')]) {
  const rel = relative(process.cwd(), resolve(file));
  const name = rel && !rel.startsWith('..') ? rel : file;
  for (const [n, text] of proseLines(readFileSync(file, 'utf8'))) {
    for (const h of lineHits(text, banned)) bad.push(`${name}:${n}: ${h}`);
  }
}
if (bad.length) {
  console.error(`korean-copy violations (${bad.length}), rules: ${relative(ROOT, RULES)} "${TABLE_HEADING}":`);
  for (const b of bad) console.error(`  ${b}`);
  process.exit(1);
}
console.log(`korean-copy OK — ${banned.length} table patterns + comma + native-count, selftest passed.`);
