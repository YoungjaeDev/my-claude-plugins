#!/usr/bin/env node
// Regression cases for check-shell-portability.mjs.
//
// The guard has had nine holes found across three review rounds -- `grep -oP`
// caught but `-Pio` missed, then `--perl-regexp`, then `--color=always -P`, then
// `-n --perl-regexp`; a bare `||` accepted as a fallback; a quoted `'md5'`
// accepted as one; a logging `uname -s` accepted as a branch; `.githooks/`
// unscanned because it has no extension; and `md5sum` satisfying its own
// counterpart through prefix matching. Each round I re-injected the defects into
// a throwaway worktree by hand and read the output. This file is that, kept.
//
// Two directions, both of which matter: a construct that SHOULD be flagged, and
// correct code that must NOT be. The second half is what keeps the guard usable
// -- a guard that cries wolf on `stat -c … || stat -f …` gets switched off.
//
// Run: node scripts/check-shell-portability.test.mjs
// Node 18 builtins only, per the repo's generator convention.

import { execFileSync } from 'node:child_process'
import { mkdtempSync, writeFileSync, rmSync, mkdirSync, cpSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const GUARD = join(HERE, 'check-shell-portability.mjs')
let pass = 0, fail = 0
const ok = (m) => { pass++; console.log(`  ok   ${m}`) }
const bad = (m, d) => { fail++; console.log(`  FAIL ${m}\n       ${d}`) }

// The guard reads `git ls-files`, so a case is a throwaway git repo holding one
// shell file. Scanning a real checkout instead would make the cases depend on
// whatever else the repo happens to contain that day.
function scan(body, name = 'case.sh', mode = 0o644) {
  const dir = mkdtempSync(join(tmpdir(), 'shport-'))
  try {
    mkdirSync(join(dir, 'scripts'), { recursive: true })
    mkdirSync(join(dir, dirname(name)), { recursive: true })
    cpSync(GUARD, join(dir, 'scripts/check-shell-portability.mjs'))
    writeFileSync(join(dir, name), body, { mode })
    const git = (...a) => execFileSync('git', ['-C', dir, ...a], { stdio: 'pipe' })
    git('init', '-q')
    git('config', 'user.email', 't@t'); git('config', 'user.name', 't')
    git('add', '-A')
    let out = '', code = 0
    try {
      out = execFileSync('node', ['scripts/check-shell-portability.mjs'],
        { cwd: dir, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] })
    } catch (e) { code = e.status; out = (e.stdout || '') + (e.stderr || '') }
    return { out, code }
  } finally { rmSync(dir, { recursive: true, force: true }) }
}

const flags = (m, body, opts = {}) => {
  const r = scan(`#!/usr/bin/env bash\n${body}\n`, opts.name, opts.mode)
  r.code === 1 ? ok(m) : bad(m, `expected exit 1, got ${r.code}\n       ${r.out.trim().split('\n')[0]}`)
}
const clean = (m, body, opts = {}) => {
  const r = scan(`#!/usr/bin/env bash\n${body}\n`, opts.name, opts.mode)
  r.code === 0 ? ok(m) : bad(m, `expected exit 0, got ${r.code}\n       ${r.out.trim().split('\n').slice(1, 4).join('\n       ')}`)
}

console.log('option spellings — the same GNU flag, written every way')
flags('short flag',                     "grep -P 'x' f")
flags('clustered short flag',           "grep -Pio 'x' f")
flags('long flag',                      "grep --perl-regexp 'x' f")
flags('long flag after a short one',    "grep -n --perl-regexp 'x' f")
flags('long flag after --opt=value',    "grep --color=always -P 'x' f")
flags('date --date=value',              'date -u --date=@1 +%s')
flags('stat --format=value',            'stat -L --format=%Y f')
flags('sed --in-place after -e',        "sed -e 's/x/y/' --in-place f")
flags('sed -i with attached empty quote', "sed -i'' 's/a/b/' f")

console.log('\nevidence must be executable, not text that looks like it')
flags('a quoted counterpart is a string', "md5sum \"$f\" || printf '%s\\n' 'md5'")
flags('a quoted exemption is a string',   "printf '# portability-ok: nope'\nH=$(md5sum \"$g\")")
flags('a logging uname is not a branch',  'printf \'%s\\n\' "$(uname -s)"\nH=$(md5sum "$f")')
flags('a bare || is not a fallback',      'md5sum "$f" || exit 1')
flags('an unpaired probe is not a branch', "sed --version >/dev/null\nsed -i 's/a/b/' f")
flags('a construct does not clear itself', 'H=$(md5sum "$a")\nG=$(md5sum "$b")')

console.log('\ncommand position — naming a command is not running it')
clean('command -v <tool> is a mention',   'TMO=""; command -v timeout >/dev/null 2>&1 && TMO="timeout 10"')
clean('a case pattern lists, never runs', 'case "$s" in iteration_cap|timeout|x) echo cap;; esac')
flags('but an actual call still counts',  'timeout 10 sleep 1')

console.log('\nreal fallbacks must keep passing')
clean('|| with the counterpart',          'age=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")')
clean('sha256sum || shasum',              'h=$(sha256sum "$f" 2>/dev/null || shasum -a 256 "$f")')
clean('counterpart on a nearby line',     'ts=$(date -d "$x" +%s 2>/dev/null)\nts=$(date -j -u -f \'%Y\' "$x" +%s)')
clean('nproc || sysctl',                  'n=$(nproc 2>/dev/null || sysctl -n hw.ncpu)')
clean('uname case branch covers any tool', 'case "$(uname -s)" in Darwin) t_() { tail -r "$@"; };; *) t_() { tac "$@"; };; esac')
clean('sed --version branch, both spellings',
  "if sed --version >/dev/null 2>&1; then\n  f_() { sed -i \"$@\"; }\nelse\n  f_() { sed -i '' \"$@\"; }\nfi")
clean('sed -i.bak is accepted by both',   "sed -i.bak 's/a/b/' f")
clean('an exemption with a reason',       'G=$(md5sum f)  # portability-ok: fixture, never runs on a user machine')
flags('an exemption without one',         'G=$(md5sum f)  # portability-ok')

console.log('\nscan surface')
flags('extensionless shell file, by shebang', 'H=$(md5sum f)', { name: '.githooks/pre-commit', mode: 0o755 })
// Discovery is by shebang, not by extension -- so `.txt` carrying `#!/bin/bash`
// IS scanned, and only a file with neither is skipped. Written as its own case
// because the first draft asserted the opposite and the guard was right.
{
  const r = scan('H=$(md5sum f)\n', 'notes.txt')
  r.code === 0 ? ok('no shebang, no shell extension -> not scanned')
               : bad('no shebang, no shell extension -> not scanned', `expected 0, got ${r.code}`)
}
flags('shebang wins over extension', 'H=$(md5sum f)', { name: 'notes.txt' })

console.log(`\n${pass} passed, ${fail} failed`)
process.exit(fail === 0 ? 0 : 1)
