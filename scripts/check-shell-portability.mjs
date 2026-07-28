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
// macOS (issue #172). A grep denylist would have caught it in a second.
//
// The hard part is NOT finding the tokens, it is not crying wolf. This repo is
// full of CORRECT uses -- `stat -c %Y f || stat -f %m f`, `sha256sum || shasum
// -a 256`, `sed -i` inside a `sed --version` probe branch -- and a guard that
// flags those gets switched off within a week. So a token only counts as a
// finding when nothing nearby makes it portable:
//
//   - a `||` alternative on the same line
//   - a capability probe (`command -v x`, `x --version`, `sort -V </dev/null`)
//     or the tool's BSD counterpart within 4 lines either way -- in CODE, not
//     in a comment that merely names the alternative
//   - an explicit `# portability-ok: <reason>` escape hatch
//
// Node 18 builtins only, per the repo's generator convention.

import { execFileSync } from 'node:child_process'
import { readFileSync } from 'node:fs'

// token: a regex matching the GNU-only construct
// alt:   the POSIX / portable replacement named in the failure message
// probe: extra regex whose presence nearby proves the author branched on it
const RULES = [
  { id: 'md5sum', tool: 'md5sum',      token: /(^|[\s|(`$])md5sum\b/,            bsd: /\b(cksum|md5)\b/,        alt: 'cksum (POSIX) or `md5sum || md5`' },
  { id: 'sha256sum', tool: 'sha256sum',   token: /(^|[\s|(`$])sha256sum\b/,         bsd: /\bshasum\b/,             alt: '`sha256sum || shasum -a 256`' },
  { id: 'sed -i', tool: 'sed',      token: /\bsed\s+(-[a-zA-Z]*\s+)*-i(\s|$)(?!\s*(''|""))/, bsd: /sed\s+-i\s+''/,           alt: "a sed_inplace() helper branching on `sed --version` (GNU takes `-i`, BSD takes `-i ''`)" },
  { id: 'sed -r', tool: 'sed',      token: /\bsed\s+(-[a-zA-Z]*\s+)*-[a-zA-Z]*r[a-zA-Z]*(\s|$)/, alt: 'sed -E (accepted by both GNU and BSD)' },
  { id: 'grep -P', tool: 'grep',     token: /\bgrep\s+(-[a-zA-Z]*\s+)*-[a-zA-Z]*P[a-zA-Z]*(\s|$)/, alt: "sed -n 's/…/\\1/p' or awk (BSD grep has no PCRE at all)" },
  { id: 'date -d', tool: 'date',     token: /\bdate\s+(-[a-zA-Z]+\s+)*-[a-zA-Z]*d[a-zA-Z]*(\s|=)/, bsd: /\bdate\s+-j\b/,          alt: '`date -d … || date -j -f FMT …`' },
  { id: 'stat -c', tool: 'stat',     token: /\bstat\s+(-[a-zA-Z]+\s+)*-[a-zA-Z]*c[a-zA-Z]*(\s|=)/, bsd: /\bstat\s+(-[a-zA-Z]+\s+)*-f\b/, alt: '`stat -c … || stat -f …`' },
  { id: 'timeout', tool: 'timeout',     token: /(^|[\s|(`$])timeout\s+\d/,        alt: 'a bash watchdog (see cr-fix tests run_capped) -- stock macOS has no timeout(1)' },
  { id: 'tac', tool: 'tac',         token: /(^|[\s|(`$])tac(\s|$)/,           bsd: /\btail\s+-r\b/,          alt: 'tail -r' },
  { id: 'nproc', tool: 'nproc',       token: /(^|[\s|(`$])nproc(\s|$)/,         bsd: /sysctl\s+-n\s+hw\.ncpu/, alt: '`nproc || sysctl -n hw.ncpu`' },
  { id: 'realpath -m', tool: 'realpath', token: /\brealpath\s+(-[a-zA-Z]+\s+)*-m(\s|$)/, alt: 'cd + pwd -P on the parent, then re-append the basename (see cr-fix path-trust.sh)' },
  { id: 'readlink -f', tool: 'readlink', token: /\breadlink\s+(-[a-zA-Z]+\s+)*-f(\s|$)/, alt: 'a readlink loop, or guard on macOS >= 12.3' },
  { id: 'bash4-case', tool: 'bash',  token: /\$\{[A-Za-z_][A-Za-z0-9_]*(,,|\^\^)\}/, alt: "tr '[:upper:]' '[:lower:]' -- macOS /bin/bash is 3.2" },
  { id: 'bash4-mapfile', tool: 'bash', token: /(^|[\s;&|(])(mapfile|readarray)(\s|$)/, alt: 'a while read -r loop -- mapfile is bash 4+' },
  { id: 'bash4-assoc', tool: 'bash', token: /\bdeclare\s+(-[a-zA-Z]+\s+)*-A(\s|$)/, alt: 'parallel indexed arrays -- associative arrays are bash 4+' },
  { id: 'bash4-nameref', tool: 'bash', token: /\b(declare|local)\s+(-[a-zA-Z]+\s+)*-n(\s|$)/, alt: 'pass the value, not the name -- namerefs are bash 4.3+' },
].map((r) => ({ ...r, probe: toolProbe(r.tool) }))

// A probe or an alternative anywhere in this window proves the author handled it.
// A GNU-first idiom often puts its BSD counterpart on the NEXT lines
// (`ts=$(date -d …) && return; ts=$(date -j -f …) && return`), so look both ways.
const WINDOW = 4
// A probe must name the tool it is probing. A generic /command -v/ let an
// UNRELATED probe nearby clear a finding: `command -v node || exit` two lines
// above an `md5sum` call marked the md5sum handled. `uname` branching is the one
// probe that legitimately covers any tool, so it stays generic.
const GENERIC_PROBE = /\bcase\s+"?\$\(uname|\buname\s+-s\b/
function toolProbe(tool) {
  const t = tool.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  return new RegExp(`(command\\s+-v\\s+${t}|type\\s+-P\\s+${t}|\\b${t}\\s+(-[a-zA-Z]+\\s+)*--version|${t}\\s+-V\\s*<\\s*/dev/null)`)
}
const ESCAPE = /#\s*portability-ok/

// Rule text and lore DESCRIBE these constructs; they never run them.
const SKIP_FILES = [
  'code_review.md',
  'AGENTS.md',
  'scripts/check-shell-portability.mjs',
]
const SKIP_PREFIXES = ['.llmwiki/', '.claude/spec/', 'docs/superpowers/']

function tracked(patterns) {
  return execFileSync('git', ['ls-files', ...patterns], { encoding: 'utf8' })
    .split('\n').filter(Boolean)
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

function stripComment(line) {
  // Good enough for shell: drop from an unquoted # to end of line.
  let q = null
  for (let i = 0; i < line.length; i++) {
    const c = line[i]
    if (q) { if (c === q && line[i - 1] !== '\\') q = null; continue }
    if (c === '"' || c === "'") { q = c; continue }
    if (c === '#' && (i === 0 || /\s/.test(line[i - 1]))) return line.slice(0, i)
  }
  return line
}

const files = tracked(['*.sh', '*.md', '*.bash'])
  .filter((f) => !SKIP_FILES.includes(f) && !SKIP_PREFIXES.some((p) => f.startsWith(p)))

const findings = []
for (const file of files) {
  let text
  try { text = readFileSync(file, 'utf8') } catch { continue }
  const lines = executableLines(file, text)
  const byIndex = new Map(lines.map((l) => [l.n, l.text]))
  for (const { n, text: raw } of lines) {
    if (ESCAPE.test(raw)) continue
    const code = stripComment(raw)
    if (!code.trim()) continue
    for (const rule of RULES) {
      if (!rule.token.test(code)) continue
      // same-line alternative
      if (code.includes('||')) continue
      // probe on this line or just above (comments included -- a `sed --version`
      // probe is often the line before, and its own comment names the tool)
      // Evidence has to be CODE. A comment that names the portable alternative
      // ("POSIX cksum, not md5sum: ...") is documentation, not a fallback -- and
      // counting it let the exact md5sum bug this guard exists for slip through.
      // The escape hatch is the one thing that IS a comment, by design.
      let handled = false
      for (let k = -WINDOW; k <= WINDOW; k++) {
        const near = byIndex.get(n + k)
        if (near === undefined) continue
        if (ESCAPE.test(near)) { handled = true; break }
        const nearCode = stripComment(near)
        if (GENERIC_PROBE.test(nearCode)) { handled = true; break }
        if (rule.probe.test(nearCode)) { handled = true; break }
        if (rule.bsd && k !== 0 && rule.bsd.test(nearCode)) { handled = true; break }
      }
      if (handled) continue
      findings.push({ file, n, id: rule.id, alt: rule.alt, code: code.trim() })
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
