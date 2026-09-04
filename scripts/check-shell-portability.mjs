#!/usr/bin/env node
// Flag GNU-only shell constructs that ship WITHOUT a BSD/macOS fallback.
//
// Usage: node scripts/check-shell-portability.mjs [--check]
//        (--check is accepted for symmetry with the other guards; the script
//         always just reports and exits non-zero on a finding)
//
// This exists because code_review.md P1 has forbidden these constructs for a
// while and nothing enforced it: `md5sum` shipped in translator's
// download_image.sh and silently collapsed every image to one filename on
// macOS (issue #172). A denylist would have caught it in a second.
//
// It scans SHELL WORDS, not raw text. The first version matched regexes against
// the line, and every review round produced another spelling it had not
// anticipated -- `grep -oP`, then `-Pio`, then `--perl-regexp`, then
// `--color=always -P`, then `-n --perl-regexp`. Emulating option syntax with
// regexes is a losing game; tokenizing ends it. Quote awareness comes free with
// the tokenizer, which is what stops a STRING like `printf 'md5'` from counting
// as a BSD alternative.
//
// The hard part is not finding the constructs, it is not crying wolf. This repo
// is full of correct uses -- `stat -c %Y f || stat -f %m f`, `sha256sum ||
// shasum -a 256`, `sed -i` inside a `sed --version` probe branch -- and a guard
// that flags those gets switched off in a week. A construct counts only when
// nothing nearby makes it portable:
//
//   - the BSD counterpart on the far side of a same-line `||`
//   - the BSD counterpart on a nearby line (in code, never in a comment)
//   - a `case "$(uname ...)"` branch, which covers any construct
//   - an explicit `# portability-ok: <reason>` in the line's comment
//
// A construct with no BSD counterpart at all (grep -P, timeout, bash 4 syntax)
// has no portable alternative to point at, so only the exemption clears it.
//
// Node 18 builtins only, per the repo's generator convention.

import { execFileSync } from 'node:child_process'
import { readFileSync } from 'node:fs'

// --- rules -----------------------------------------------------------------
// Command rules name the command plus the GNU-only flag in both spellings.
// `bare: true` means the command itself is the problem, flags irrelevant.
// `bsd` lists the tokens that, when present nearby, prove a fallback exists.
const CMD_RULES = [
  { id: 'md5sum',      cmd: 'md5sum',   bare: true, bsd: ['cksum', 'md5'],
    alt: 'cksum (POSIX) or `md5sum || md5`' },
  { id: 'sha256sum',   cmd: 'sha256sum', bare: true, bsd: ['shasum'],
    alt: '`sha256sum || shasum -a 256`' },
  { id: 'timeout',     cmd: 'timeout',  bare: true,
    alt: 'a bash watchdog (see cr-fix tests run_capped) -- stock macOS has no timeout(1)' },
  { id: 'tac',         cmd: 'tac',      bare: true, bsd: ['tail'],
    alt: 'tail -r' },
  { id: 'nproc',       cmd: 'nproc',    bare: true, bsd: ['sysctl'],
    alt: '`nproc || sysctl -n hw.ncpu`' },
  { id: 'sed -i',      cmd: 'sed',  short: 'i', long: ['--in-place'], sedInPlace: true, bsdFn: sedBsdForm,
    alt: "a sed_inplace() helper branching on `sed --version` (GNU takes `-i`, BSD takes `-i ''`)" },
  { id: 'sed -r',      cmd: 'sed',  short: 'r', long: ['--regexp-extended'],
    alt: 'sed -E (accepted by both GNU and BSD)' },
  { id: 'grep -P',     cmd: 'grep', short: 'P', long: ['--perl-regexp'],
    alt: "sed -n 's/…/\\1/p' or awk (BSD grep has no PCRE at all)" },
  { id: 'date -d',     cmd: 'date', short: 'd', long: ['--date'], bsd: ['-j'],
    alt: '`date -d … || date -j -f FMT …`' },
  { id: 'stat -c',     cmd: 'stat', short: 'c', long: ['--format', '--printf'], bsd: ['-f'],
    alt: '`stat -c … || stat -f …`' },
  { id: 'realpath -m', cmd: 'realpath', short: 'm', long: ['--canonicalize-missing'],
    alt: 'cd + pwd -P on the parent, then re-append the basename (see cr-fix path-trust.sh)' },
  { id: 'readlink -f', cmd: 'readlink', short: 'f', long: ['--canonicalize'],
    alt: 'a readlink loop, or guard on macOS >= 12.3' },
]

// Syntax rules are not commands; they match the unquoted text of a line.
const SYNTAX_RULES = [
  { id: 'bash4-case',    re: /\$\{[A-Za-z_][A-Za-z0-9_]*(,,|\^\^)\}/,
    alt: "tr '[:upper:]' '[:lower:]' -- macOS /bin/bash is 3.2" },
  { id: 'bash4-mapfile', re: /(^|[\s;&|(])(mapfile|readarray)(\s|$)/,
    alt: 'a while read -r loop -- mapfile is bash 4+' },
  { id: 'bash4-assoc',   re: /\bdeclare\s+(-[a-zA-Z]+\s+)*-A(\s|$)/,
    alt: 'parallel indexed arrays -- associative arrays are bash 4+' },
  { id: 'bash4-nameref', re: /\b(declare|local)\s+(-[a-zA-Z]+\s+)*-n(\s|$)/,
    alt: 'pass the value, not the name -- namerefs are bash 4.3+' },
]

const WINDOW = 4
// Only a real branch counts. A bare `uname -s` is often just logging, and
// accepting it let `printf '%s\n' "$(uname -s)"` clear every construct within
// four lines of it.
const UNAME_BRANCH = /\bcase\s+"?\$\((uname|\s*uname)/
const ESCAPE = /#\s*portability-ok:\s*\S/

const SKIP_FILES = ['code_review.md', 'AGENTS.md', 'scripts/check-shell-portability.mjs']
const SKIP_PREFIXES = ['.llmwiki/', '.claude/spec/', 'docs/superpowers/']

// --- tokenizer -------------------------------------------------------------
// Splits a shell line into words, tracking which characters were quoted.
// `code` is the unquoted-only text (what a rule may match against) and
// `comment` is the trailing unquoted `#` remainder (where an exemption lives).
function lex(line) {
  const tokens = []
  let text = '', bare = '', hadQuote = false, open = false
  let i = 0
  const flush = () => {
    if (!open) return
    tokens.push({ text, bare, hadQuote, empty: hadQuote && text === '' })
    text = ''; bare = ''; hadQuote = false; open = false
  }
  for (; i < line.length; i++) {
    const c = line[i]
    if (!open && /\s/.test(c)) continue
    if (open && /\s/.test(c)) { flush(); continue }
    if (c === '#' && !open) break              // comment starts a new word
    if (c === '"' || c === "'") {
      open = true; hadQuote = true
      const q = c
      for (i++; i < line.length && line[i] !== q; i++) {
        if (q === '"' && line[i] === '\\' && i + 1 < line.length) i++
        text += line[i]
      }
      continue
    }
    if (';&|()'.includes(c)) { flush(); tokens.push({ text: c, bare: c, op: true }); continue }
    open = true; text += c; bare += c
  }
  flush()
  const hash = unquotedHash(line)
  return { tokens, code: line.slice(0, hash === -1 ? line.length : hash), comment: hash === -1 ? '' : line.slice(hash) }
}

// Index of the `#` that opens a comment, skipping quoted ones.
function unquotedHash(line) {
  let q = null
  for (let i = 0; i < line.length; i++) {
    const c = line[i]
    if (q) { if (c === q) q = null; continue }
    if (c === '"' || c === "'") { q = c; continue }
    if (c === '#' && (i === 0 || /\s/.test(line[i - 1]))) return i
  }
  return -1
}

// `sed -i ''` -- the BSD spelling. Used as the nearby-counterpart test for the
// sed -i rule, whose counterpart is a call SHAPE rather than a distinct token.
function sedBsdForm(tokens) {
  for (let i = 0; i < tokens.length; i++) {
    if (tokens[i].op || tokens[i].hadQuote || tokens[i].bare !== 'sed') continue
    for (let j = i + 1; j < tokens.length; j++) {
      const a = tokens[j]
      if (a.op) break
      if (a.bare === '-i' || a.bare === '--in-place') {
        const next = tokens[j + 1]
        if (next && next.hadQuote && next.bare === '' && next.text === '') return true
      }
    }
  }
  return false
}

// A `case` branch lists patterns, it does not run them: `iteration_cap|timeout|x)`
// names timeout, it never invokes it. The shape is an unmatched `)` closing a
// pattern list, optionally followed by `;;`.
function isCasePattern(code) {
  const opens = (code.match(/\(/g) || []).length
  const closes = (code.match(/\)/g) || []).length
  return closes > opens && /\)\s*($|[^(]*;;)/.test(code)
}

// Which token indexes sit in command position? A command name is the first word
// of a simple command -- after a separator, or after `VAR=value` prefixes. This
// is what separates INVOKING a command from NAMING it: in `command -v timeout`,
// timeout is an argument, and the old regex version only tolerated it because it
// happened to read `command -v` as a capability probe.
function commandPositions(tokens) {
  const pos = new Set()
  let atCmd = true
  for (let i = 0; i < tokens.length; i++) {
    const t = tokens[i]
    if (t.op) { atCmd = true; continue }
    if (!atCmd) continue
    if (!t.hadQuote && /^[A-Za-z_][A-Za-z0-9_]*=/.test(t.bare)) continue  // VAR=val prefix
    pos.add(i)
    atCmd = false
  }
  return pos
}

// Does `tokens` invoke rule.cmd with the GNU-only flag (or bare, for bare rules)?
function cmdUsed(tokens, rule, cmdPos) {
  for (let i = 0; i < tokens.length; i++) {
    const t = tokens[i]
    if (t.op || t.hadQuote || t.bare !== rule.cmd) continue
    if (!cmdPos.has(i)) continue
    if (rule.bare) return true
    for (let j = i + 1; j < tokens.length; j++) {
      const a = tokens[j]
      if (a.op) break                    // command boundary
      if (a.bare === '--') break         // end of options
      if (a.hadQuote && a.bare === '') { // e.g. the `''` in BSD `sed -i ''`
        continue
      }
      if (a.bare.startsWith('--')) {
        if (rule.long?.includes(a.bare.split('=')[0])) return true
        continue
      }
      if (a.bare.startsWith('-') && a.bare.length > 1) {
        if (!rule.short || !a.bare.slice(1).includes(rule.short)) continue
        if (!rule.sedInPlace) return true
        // `sed -i ''` is the BSD spelling; `-i` alone (or `-i''`, which the shell
        // collapses to `-i`) is the GNU one. An attached extension (`-i.bak`)
        // is accepted by both.
        const attached = a.bare.slice(a.bare.indexOf('i') + 1)
        if (attached) return false
        const next = tokens[j + 1]
        if (next && next.hadQuote && next.bare === '' && next.text === '') return false
        return true
      }
    }
  }
  return false
}

// Is a counterpart present as an unquoted token? Two things this must NOT do:
// a quoted `'md5'` is a string, not a call; and the match is exact, never a
// prefix -- `'md5sum'.startsWith('md5')` made every md5sum line count as the BSD
// fallback for the md5sum line next to it, so the construct cleared itself.
function hasBsdToken(tokens, bsd) {
  return tokens.some((t) => !t.hadQuote && bsd.includes(t.bare))
}

// --- file discovery --------------------------------------------------------
function tracked(patterns) {
  return execFileSync('git', ['ls-files', ...patterns], { encoding: 'utf8' })
    .split('\n').filter(Boolean)
}

// Extension is not what makes a file shell. `.githooks/pre-commit` is bash with
// no suffix -- and it is the hook that RUNS this guard, so leaving it unscanned
// made the guard blind to the file that invokes it. Restricted to sh/bash to
// match what the rules actually encode; a ksh or zsh script would need its own
// dialect rules before it could be judged here.
function shebangShellFiles() {
  const out = []
  for (const f of tracked([])) {
    if (/\.(sh|bash|md)$/.test(f)) continue
    let head
    try { head = readFileSync(f, 'utf8').slice(0, 120).split('\n')[0] } catch { continue }
    if (/^#!.*\b(ba)?sh\b/.test(head)) out.push(f)
  }
  return out
}

// For .md, only fenced bash/sh blocks are executable; the rest is prose.
function executableLines(path, text) {
  const out = []
  const lines = text.split('\n')
  if (!path.endsWith('.md')) {
    lines.forEach((l, i) => out.push({ n: i + 1, text: l }))
    return out
  }
  let inBlock = false
  lines.forEach((l, i) => {
    const fence = l.match(/^\s*```+\s*(\w+)?/)
    if (fence) {
      if (inBlock) inBlock = false
      else inBlock = ['bash', 'sh', 'shell', 'zsh'].includes((fence[1] || '').toLowerCase())
      return
    }
    if (inBlock) out.push({ n: i + 1, text: l })
  })
  return out
}

// --- scan ------------------------------------------------------------------
const files = [...tracked(['*.sh', '*.md', '*.bash']), ...shebangShellFiles()]
  .filter((f) => !SKIP_FILES.includes(f) && !SKIP_PREFIXES.some((p) => f.startsWith(p)))

const findings = []
for (const file of files) {
  let text
  try { text = readFileSync(file, 'utf8') } catch { continue }
  const lines = executableLines(file, text)
  const lexed = new Map(lines.map((l) => [l.n, lex(l.text)]))

  for (const { n } of lines) {
    const here = lexed.get(n)
    if (ESCAPE.test(here.comment)) continue
    if (!here.code.trim()) continue

    if (isCasePattern(here.code)) continue

    const cmdPos = commandPositions(here.tokens)
    const hits = []
    for (const rule of CMD_RULES) if (cmdUsed(here.tokens, rule, cmdPos)) hits.push(rule)
    for (const rule of SYNTAX_RULES) if (rule.re.test(here.code)) hits.push(rule)
    if (hits.length === 0) continue

    for (const rule of hits) {
      let handled = false
      for (let k = -WINDOW; k <= WINDOW && !handled; k++) {
        const near = lexed.get(n + k)
        if (!near) continue
        if (ESCAPE.test(near.comment)) { handled = true; break }
        if (UNAME_BRANCH.test(near.code)) { handled = true; break }
        if (rule.bsdFn && k !== 0 && rule.bsdFn(near.tokens)) { handled = true; break }
        if (!rule.bsd) continue
        if (k === 0) {
          // same line: the counterpart must sit past the `||`
          const idx = near.tokens.findIndex((t) => t.op === true && t.bare === '|')
          if (idx !== -1 && hasBsdToken(near.tokens.slice(idx), rule.bsd)) handled = true
          continue
        }
        if (hasBsdToken(near.tokens, rule.bsd)) handled = true
      }
      if (handled) continue
      findings.push({ file, n, id: rule.id, alt: rule.alt, code: here.code.trim() })
    }
  }
}

if (findings.length === 0) {
  console.log(`shell-portability OK — ${files.length} files scanned, no unguarded GNU-only construct.`)
  process.exit(0)
}

console.error(`shell-portability: ${findings.length} unguarded GNU-only construct(s)\n`)
for (const f of findings) {
  console.error(`  ${f.file}:${f.n}  [${f.id}]`)
  console.error(`    ${f.code}`)
  console.error(`    use: ${f.alt}`)
}
console.error(`
Each of these runs on a contributor's machine. Stock macOS ships BSD userland and
bash 3.2, so an unguarded GNU-only call either errors or -- worse -- succeeds with
the wrong result (see code_review.md P1, "종료 상태가 사라지는 자리").

Add a portable fallback, branch on a capability probe, or -- when the construct is
genuinely fine here -- annotate the line with "# portability-ok: <reason>".`)
process.exit(1)
