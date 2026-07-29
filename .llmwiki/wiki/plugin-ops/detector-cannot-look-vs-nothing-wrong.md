---
id: detector-cannot-look-vs-nothing-wrong
aliases: [pipefail-kills-detector, jq-failure-in-command-substitution, argjson-strict-json, read-only-detector-silent-failure, fetcher-false-clean, guard-exemption-too-wide, comment-as-evidence]
last_verified: 2026-07-29
status: active
volatility: stable
sources: 11
---

# A detector must never report "nothing wrong" when it means "could not look"

Read-only detectors — the scripts that answer "is this repo wired up?" — have two failure modes that both look like success. One kills the whole run and produces no output; the other produces confident output that is wrong. Both were found in `plugins/project-init/scripts/project_state.sh`, one per release.

## Mode 1: one axis fails, the whole diagnostic disappears

`set -euo pipefail` turns any non-zero exit inside a command substitution into a script abort. Two commands routinely exit non-zero on perfectly normal input:

- `find` signals "no match" with exit 1. `MATCHES=$(find . -name '*.py' | wc -l)` therefore kills the script on a repo that happens to have no Python.
- `jq` exits non-zero on a corrupt input file. `KEYS=$(jq -r '.mcpServers|keys[]' ~/.claude.json)` kills the script when the user's config is malformed.

The user sees no JSON, no partial report, and no obvious cause. The symptom reads as "the tool is broken", not "one of your config files is". Measured: a `~/.claude.json` containing `NOT JSON` made the script exit 5 with zero bytes of output; every other axis was healthy.

The fix is not `|| true` at the top level. It is to **contain the failure inside the axis that owns it** and surface the fact that the axis could not be evaluated:

```bash
mcp_readable() { jq -e 'type=="object" and ((.mcpServers // {})|type)=="object"' "$1" >/dev/null 2>&1; }
# ...
if ! mcp_readable "$f"; then unreadable+=("$f"); fi
```

## Mode 2: `|| true` turns a failure into a false clean

Once the abort is patched with `|| true`, the failure becomes invisible instead of fatal. `jq -r '.mcpServers // {} | keys[]' "$f" 2>/dev/null | sort || true` returns **zero keys** for a corrupt file, a file whose `.mcpServers` is `"x"` (jq errors on `keys` of a string), and a file whose `.mcpServers` is `[]` (jq returns array *indices*). All three then report **"no duplicate MCP servers"**, which is a lie: the truth is "I could not compare them."

Guard on the question you are actually asking. "Is this valid JSON?" is not the question — an empty file is valid input to `jq`, and `{"mcpServers": []}` is valid JSON. The question is "can I enumerate `mcpServers` as an object?", and everything else is `unreadable`, reported as its own state.

The sharper form of this mode is not "someone forgot the guard" but **the guard absorbed more than it was written to absorb**. `command -v python3 >/dev/null 2>&1 && python3 hook.py || true` reads as "no-op when python3 is missing", and that is what its author intended; the trailing `|| true` in fact covers the whole `&&` chain, so "python3 is not installed" and "python3 ran the hook and it died" both exit 0. Formatting or notifications stop working entirely and the hook runner still sees success. Measured on the shipped command: a hook script exiting 3 reported rc 0 before and rc 3 after rewriting to `if command -v python3 …; then python3 hook.py; fi` — an `if` whose condition is false yields 0, and the taken branch's status propagates, so the syntax itself bounds what is swallowed. Prefer the form whose absorption is limited by structure over the one that depends on reading operator precedence correctly.

The provenance is worth keeping: the rule that caught this (`code_review.md` P1 — do not put `|| true` where the exit status *is* the signal) had been added two merges earlier by the same author, and the Codex reviewer cited that exact line back at them. A written invariant does not stop you from violating it in a shape you have not seen yet; the reviewer that reads your rules is what closes that gap.

## Mode 3: the value crosses into `--argjson`

`jq --argjson name "$v"` demands strict JSON. Values scraped out of foreign config formats are not JSON:

- TOML permits an inline comment after a value, so `project_doc_max_bytes = 65536 # bytes` yields `65536 # bytes`.
- TOML permits `_` digit separators, so `65_536` is a valid integer that `--argjson` rejects.

Both spellings are *correct configuration* and both aborted the script before it printed anything. Normalize (cut at the first space-hash, strip separators), validate (`case "$v" in *[!0-9]*)`), and fall back to the documented default. Never hand a foreign format's raw bytes to a strict parser.

Related trap in the same family: `${f#$HOME/}` is a **pattern** expansion, so a `$HOME` containing glob characters mangles the stripped path. Quote the prefix: `${f#"$HOME/"}`.

## Mode 4: the same family in remote fetchers — a degraded API answer read as "clean"

PR #122 found five instances of the identical invariant in `cr-fix`'s GitHub fetchers, where "could not look" arrives as a *well-formed but degraded* API response rather than a non-zero exit:

- **Null envelope**: a GraphQL reply of `{"data":{"repository":null}}` (bad repo coordinates, auth loss) flowed through `.repository.pullRequest.reviewThreads // []` into a confident empty thread list — which the convergence loop read as "all findings resolved" and declared the PR clean. The detector must require the full expected shape (a `nodes` *array*, not merely a non-error reply) and fail loudly otherwise.
- **Missing `pageInfo`**: asking for `nodes` without `pageInfo { hasNextPage endCursor }` silently truncates to the first page — an incomplete answer indistinguishable from a complete one.
- **Cursorless `hasNextPage`**: paginating on `hasNextPage` without threading `endCursor` refetches page one forever (reproduced as an rc-124 hang in the RED fixture).
- **Probe rc 0 as 404**: `auto-merge-gate.sh` read a *failed* branch-protection probe (network rc 0-bytes) as the 404 "unprotected" answer. Only definitive HTTP codes (200/404) may drive the merge decision; anything else is "could not look" → refuse to merge.
- **Fetch failure as `none`**: `cr-commit-state.sh` reported gh/auth/rate-limit failures as the clean `none` state; its poller then spun silently to the outer timeout. Fixed as a distinct `state:"error"` channel, terminal after `ERROR_STREAK_MAX` consecutive errors (a single transient still self-heals).
- **Reading the wrong surface entirely**: `auto-merge-gate.sh` derived CR state from the commit-status API alone, but CodeRabbit reports through *either* commit-status *or* a check-run per install. On a check-run repo the status endpoint is empty forever, so the gate saw `cr_state:unknown` and `--auto-merge` could never fire — an all-clear-shaped block. This is the missed sibling of the exact trap `cr-commit-state.sh` already fixed for `pre-flight`/`poll-cr-status`/`sniff`; the fix was to delegate to that one dual-surface reader instead of re-deriving. "Could not look" here was "looked at the wrong window", not a parse failure.

Local detectors (Modes 1-3) fail via exit codes and `pipefail`; remote fetchers fail via degraded payloads that still parse. Same rule both ways: **an answer you could not fully retrieve is not an answer of "nothing there".**

## Mode 5: the detector's own tool is non-portable — "clean" because it could not run

The first four modes all fail on *ugly input*. Mode 5 fails on a *healthy input the tool cannot examine on this platform*. `cr-fix`'s per-finding gate `scripts/path-trust.sh` used GNU-only `realpath -m`; on BSD/macOS realpath rejects `-m` (`illegal option`), and under `set -euo pipefail` the command substitution aborted the script — for *every* path, including legitimate in-repo ones. The Step 9c gate is `path-trust.sh ... || { log "untrusted path"; auto_judge_skip++; continue; }`, so a tool that cannot run on this OS reads as "every finding is untrusted." A skip touches neither `applied_this_cycle` nor `deferred_this_cycle`, so Step 13's `applied==0 && deferred==0` fired `final_state=clean` — the one state that is auto-merge eligible. A reviewer's CRITICAL finding could ride an auto-merge through a gate that never read it, and the run is indistinguishable from a genuinely clean one (same `final_state`; the only tell is a `skip` count that shares its counter with legitimate YAGNI skips; the disambiguating `auto_judge_log` entry is never written because `continue` jumps past it).

Two compounding traps found fixing it:

- **Bare `realpath` is not the portable substitute.** GNU *and* BSD realpath both error on a path that does not exist yet, and cr-fix must validate paths for files a fix is about to *create* — which is exactly what `-m` allowed. The portable form resolves the parent with `cd` + `pwd -P` and re-appends the basename.
- **Resolving only the parent reopened the trust boundary.** A symlinked *final* component pointing outside the repo then looks in-repo and passes containment (the first fix's own review, #153, caught this as a Critical). The resolver must follow a final-component symlink chain (`readlink`, re-resolving the parent each hop, with a loop cap) — which `realpath -m` had done for free.

The trap is not confined to detectors. In a *producer* the same missing tool is swallowed by pipeline **position** rather than by `set -e`: `H=$(printf %s "$url" | md5sum | cut -d' ' -f1 | head -c 12)` takes its exit status from `head`, so on a machine without `md5sum` the substitution succeeds with `H` empty, every URL collapses to one filename, and the script reports success. `set -e` cannot help — it is looking at the wrong command. Guard the extracted value, or set `pipefail`. And the test that guards such a call must not spend the signal it is testing: `g=$(run_capped 3 …) || true` erased the exit status that distinguishes "the watchdog killed a still-waiting poll" (143, the pass) from "setup broke and the child died instantly" (127, a false green) — both leave stdout empty, so the assertion held either way.

The meta-lesson beyond containment: **a detector written and tested on one platform can be a silent no-op on another, and a no-op detector reports "nothing wrong."** The break is invisible in an interactive shell where a `grep` shim masks it — see [[stock-userland-verification]] — so portability claims for detector tooling must be re-verified under `env -i PATH=/usr/bin:/bin`, and the gate itself given test coverage (path-trust.sh had none, which is why CI passed clean while it rejected every path).

## Mode 6: the search tool's default scope excludes part of the target — "0 hits" because it never looked

Modes 1-5 are committed detector *scripts*; Mode 6 is the same trap in an ad-hoc verification *command*. A removal/parity gate over this repo — "prove the retired vendor token is gone" — was run as `rg -i firecrawl --glob '!docs/**' …`, which returned 0 hits and read as "fully removed." But **recursive ripgrep skips dot-directories by default**, so the grep never looked in `.claude-plugin/marketplace.json`, `.agents/`, or `.claude/settings.json` — exactly where the generated manifests and the tracked load-list live. A stale `firecrawl tier-3` string survived in the code-scout manifest description and passed the parity gate; it was caught only by re-running with `rg --hidden`. A true parity/removal gate over this repo must pass `--hidden` (the generated Codex/Hermes manifests + settings live under dot-dirs). Sibling trap in the same PR: a plugin CHANGELOG that names the retired vendor token *in prose* re-breaks a repo-wide token-parity check — describe a removed dependency by its slot ("the tier-3 fetch tool"), not its vendor name. Distinct from the `rg`-is-a-shell-function shadowing in [[stock-userland-verification]]: here the tool runs fine, its **default coverage** is the blind spot.

## Mode 7: the recommender checked the documented enforcement surface, not the one in use

Modes 1-6 all answer "is anything wrong?" Mode 7 is the same trap in a diagnostic that answers "is this safe to **delete**?" — and there the uninspected axis is not where the target lives but *what enforces it*.

A `/doctor` run over this repo proposed cutting the 31-line ASCII directory tree from `AGENTS.md` as content a session could reconstruct from `ls plugins/`. Derivable it is; removable it was not. `scripts/check-doc-consistency.mjs` — reached through `git config core.hooksPath .githooks` — asserts that tree lists all 24 marketplace plugins, so the trim was rejected at `git commit` with `doc-consistency drift detected: AGENTS.md tree: missing core-config, github-dev, …`. The diagnostic's own instructions *did* say to cross-check removal candidates against a pre-commit hook and the lint/format configs, and it did check `.pre-commit-config.yaml` and the lint configs. This repo enforces through a **git-native `core.hooksPath` hook directory** instead, so the documented cross-check named a surface the repo does not use and never enumerated the one it does.

The verdict was therefore confidently wrong on an axis that was never read — an all-clear for enforcement the check did not look for. The general form: **before calling content redundant, enumerate every mechanism that could be consuming it, not just the mechanisms your checklist happens to name.** For a "is this file/block still needed?" question in any repo that means, at minimum, `core.hooksPath` and `.githooks/`, `.github/workflows/`, and the standard lint/format configs — a hook directory is invisible to a check that only greps for `.pre-commit-config.yaml`.

A second lesson from the fix, on the way out: when the guard *is* found and the enforced content still deserves to go, delete the assertion only after proving the coverage is redundant. Here the adjacent `## Plugins`-table assertion already compared the same canonical name-set bidirectionally, verified by removing one table row and confirming the guard still exits 1 — so dropping the tree assertion cost no detection. Deleting a guard because it blocked you, without that proof, converts Mode 7 into a self-inflicted Mode 1.

## Mode 8: the fix reached one consumer of the signal, not its siblings

Modes 1-7 are each a fresh instance. Mode 8 is about why the *same* instance keeps coming back: the repair is applied where the bug was reported, and the other readers of the same signal are never swept.

`cr-fix` decides "has CodeRabbit looked at this push?" from comment timestamps. CodeRabbit does not post a new comment when a re-review finds nothing — it **edits its existing walkthrough in place**, so `created_at` stays pinned to the first review and only `updated_at` moves. That was discovered once and fixed once: `sniff-cr-rate-limit.sh:25` anchors on `created_at > $t or updated_at > $t` and says why at line 18. `engagement-gate.sh` reads the same comment stream for the same question and was left on `created_at` alone.

The consequence is the inverse of a false clean and just as bad. A genuine convergence — CR re-reviewed, found nothing, edited the walkthrough — returned `cr_engagement = 0`, which Step 8c defines as "CR has not started reviewing this push". The loop waits out its iteration budget and ends in `cr_inactive`, and since `--auto-merge` runs only on `final_state=clean`, **auto-merge could never fire on the normal converged path**. Measured on PR #183: commit status recorded `Review queued 14:20:43 → in progress 14:20:45 → completed 14:23:22 (success)` and CR's own body said "No actionable comments were generated in the recent review… between 86b604f and 3e5ee3e", while the gate returned 0 through a 15-minute wait.

This is the third appearance of Mode 4's "reading the wrong surface" inside one skill (`cr-commit-state.sh` dual-surface, then `auto-merge-gate.sh` re-deriving instead of delegating, now `engagement-gate.sh`). The pattern is not that the surface is hard to find — it is that **widening a signal's definition is not done when the reporting caller is fixed.** Grep every consumer of that signal and sweep them in the same change; a sibling left on the narrow definition is a latent recurrence with a different symptom.

Second occurrence, one merge later: every hook command in the two Claude plugin manifests spelled its path `bash ${CLAUDE_PLUGIN_ROOT}/...` unquoted, while the paired Codex descriptors — same scripts, same repo, source-controlled beside them — already quoted all seven of theirs, with the reason written out in `plugins/core-config/CLAUDE.md`. The rule had been derived and recorded; it was applied to one of the two surfaces that needed it.

## Mode 9: the audit's own question bounds what it can find

Modes 1-8 are all about a *check* that cannot look. Mode 9 is about the *question* the check was given: a portability audit scoped to one platform is blind to two classes by construction, and neither shows up as a gap in its own report.

**A defect that breaks everywhere never answers "what breaks on BSD?"** The `project-init` plugin-cache resolver sorted whole paths, so the marketplace directory name was compared before the version was ever reached: measured with `zeta/project-init/0.4.0` against `alpha/project-init/0.10.0`, both plain `sort` **and `sort -V`** return `zeta/0.4.0`. That is simply wrong, on GNU as much as on BSD — which is exactly why a macOS-shaped question did not surface it. The audit found the adjacent half (a lexicographic fallback ranking `0.6.1` above `0.10.0`), because that half *is* platform-flavored.

**The fix's reverse regression is invisible to the same question.** "macOS 12.3+ has no `python`" is true, and `python` → `python3` follows from it — but a python.org Windows install ships `python.exe` and the `py` launcher and no `python3`, so the same edit breaks the platform it was not asked about. It happened twice in one PR (a venv-creation line whose block carries a Windows branch two rows down, and a CUDA memory-check call site) and both were caught by the reviewer, not the audit. No single interpreter name is correct; the answer is a probe (`python3` → `python` → `py -3`) or per-OS spellings, held in an indexed array so `py -3` survives quoting.

**A severity derived inside the lens does not transfer.** That CUDA call site was rated *cosmetic*, reasoned as "macOS has no CUDA, so the script exits either way and only the message changes". Correct for macOS, and void everywhere else: Windows has CUDA, the feature is real there, and the same edit is a functional break rather than a message change. When a rating's justification is a property of one platform, the rating is scoped to that platform too.

The practical rule: **before shipping a portability fix, ask what the changed line does on every platform the surrounding block serves — not only the one that prompted the change.** A block that carries an `# Windows` comment is telling you its audience; the audit's title is not.

## Mode 10: the guard leaks through its own exemption

Modes 1-9 are checks that could not look. Mode 10 is a check that looked, and then let the finding go — because the mechanism that suppresses false positives was wider than intended. Every non-trivial guard needs one: a denylist that also fires on correct code is turned off within a week. That exemption is where the guard leaks.

**Prose is not evidence of a code property.** `check-shell-portability.mjs` counts a GNU-only token only when nothing *nearby* makes it portable — a same-line `||`, a capability probe, a BSD counterpart within a few lines, or an explicit `# portability-ok:` marker. The first version also accepted a nearby **comment**. The repo had a comment mentioning `cksum` sitting above a `md5sum` line, so the guard cleared the exact defect it had been built to catch — the one that collapsed every image in an article into a single file on macOS and reported success. A comment describes an intention; the guard's question is what the code does. Comments are now stripped before counting.

**An exemption stated loosely admits the case it excludes.** The same guard skipped `sed -i` "when followed by a quote", meaning to admit BSD's mandatory-empty-argument `sed -i ''`. Written that way it also admitted `sed -i "s/a/b/"` — the GNU form, the thing being hunted. Only the empty-argument shape is BSD; the exclusion has to say so.

The generalization: **state the exemption as narrowly as the thing it must admit, and require evidence of the same kind as the property being checked.** A guard is only as good as its allowlist, and an allowlist is tested by feeding it the defects the guard exists for — this one was verified in both directions, 0 findings on the clean tree and exactly 6 on a worktree with the six real defects from this PR series reinjected.

**Scope is the second way the wrong evidence gets in.** The same leak reappears when a check searches a wider scope than the property lives in. A `convene` assertion for "the session id is charset-validated" grepped the whole document, so deleting the real `case "$RUN_KEY" in` guard from one of four blocks left the suite green — a sibling block's copy satisfied the search. Narrowing it to per-block coverage was not enough either: the replacement matched the charset string *anywhere in the block*, and a comment explaining the charset counted as the gate. It took a third version — track the guard statement itself, and require it to appear **before** the first use in that block — to fail on either removal. Both earlier versions were written as the fix for the version before them, which is the tell: when an assertion is satisfied by something other than the thing it names, tightening the *pattern* is usually the wrong axis. Tighten the *scope*, then assert the construct, then assert its position.

## Why this recurs

Each instance arrives disguised as an edge case ("who has a corrupt config?", "who greps a dot-dir?"), and each one is discovered only by running the check against the input it silently skips rather than reading it. The invariant is cheap to state and hard to remember: **a diagnostic that cannot evaluate an axis — whether because it aborted, degraded, could not run, or never looked there — says so, keeps going, and never converts ignorance into an all-clear.**

> See-also: [[jq-capture-yields-empty]]
> See-also: [[worktree-squash-merge-gotchas]]
> See-also: [[stock-userland-verification]]
> See-also: [[brightdata-cli-preflight-quirks]]
> Evidence: plugins/project-init/scripts/project_state.sh
> Evidence: plugins/project-init/CLAUDE.md
> Evidence: plugins/github-dev/skills/cr-fix/scripts/path-trust.sh
> Evidence: plugins/github-dev/skills/cr-fix/scripts/engagement-gate.sh
> Evidence: plugins/core-config/.claude-plugin/plugin.json

## Sources

1. **PR #104** (`feat(project-init): add wiring skill with shared state detector`) — the `find` / `pipefail` instance. `find ... | wc -l` killed the script on an empty match; `find | head -1 | grep -q .` inverted its own result via SIGPIPE(141). Fixed with `find_or_empty` / `count_files` helpers and `-print -quit`.
2. **PR #106** (`feat(project-init): ASK verdict class + three efficacy axes for wiring`) — the `jq` instances. Reproduced across corrupt / empty / `[]` / `"x"` / top-level-array `~/.claude.json`, and across `65536`, `65536 # bytes`, `65_536`, `"65536"`, `abc`, key-absent, config-absent for `project_doc_max_bytes`. Before the fix: exit 2 or exit 5, zero output. After: exit 0 in every case, with `mcp.unreadable` naming the file it could not read.
3. **PR #122** (`fix(github-dev): cr-fix correctness repair set`) — the remote-fetcher instances (Mode 4): `fetch-cr-threads.sh` null-envelope false-clean + pagination coherence (fixtures `gql-null-repository` / `gql-null-pullrequest` / `gql-missing-pageinfo` / `gql-cursorless-next`), `auto-merge-gate.sh` probe rc 0 (`probe failure -> protection_http 0`), `cr-commit-state.sh` `state:"error"` channel + `ERROR_STREAK_MAX` terminal poller test.
4. **PR #153** (`fix(github-dev): cr-fix path-trust works on BSD/macOS userland`) — the non-portable-tool instance (Mode 5): `path-trust.sh` `realpath -m` aborted under `set -e` on BSD/macOS for every path, so the Step 9c gate skipped every finding and Step 13 converged `final_state=clean` (auto-merge eligible). Fixed with a POSIX `cd`+`pwd -P`+`readlink` resolver that also follows a final-component symlink chain (a Critical the fix's own review surfaced), plus the first test coverage for the gate (12 cases, RED-verified against both prior revisions). Surfaced by a macOS-26 compatibility audit of all 24 plugins.
5. **PR #164** (`feat(search-stack): replace firecrawl with brightdata, remove slidev plugin`) — the default-scope instance (Mode 6): a `rg -i firecrawl` removal/parity gate returned 0 hits while a stale `firecrawl tier-3` string survived in `.claude-plugin/`/`.agents/` (recursive ripgrep skips dot-dirs by default); caught only by `rg --hidden`. See [[brightdata-cli-preflight-quirks]] for the migration's other lore.
6. **PR #167** (`docs(agents): drop derivable directory tree`) — the enforcement-surface instance (Mode 7): a `/doctor` trim proposal judged the `AGENTS.md` directory tree derivable-and-removable after cross-checking `.pre-commit-config.yaml` + lint configs, but this repo enforces via `core.hooksPath` → `.githooks/pre-commit` → `scripts/check-doc-consistency.mjs`, which asserts the tree's 24-plugin name-set; the cut was caught only at `git commit` (exit 1). Resolved by dropping the now-redundant `AGENTS.md tree` assertion after proving the adjacent `## Plugins`-table assertion covers the same canonical set bidirectionally (negative test: removing one table row still exits 1), keeping the `README.md tree` assertion, and adding the guard to the `AGENTS.md` `## 검증` list.
7. **PR #183** (`fix: macOS/BSD broken 2건`) — the unswept-sibling instance (Mode 8): `engagement-gate.sh` counted CR comments by `created_at` only while `sniff-cr-rate-limit.sh:25` had already been widened to `created_at or updated_at`, so a clean re-review (CR edits its walkthrough in place) read as `cr_engagement=0` and `--auto-merge` was unreachable on the converged path; fixtures `issue-comments-cr-edited-in-place` / `issue-comments-cr-stale-only` guard both directions. Same PR carried the Mode 5 producer variant (`md5sum` mid-pipeline exits 0 from `head`, collapsing every image to `img_.png`) and the `|| true`-erases-the-asserted-status false green.
8. **PR #185** (`fix(core-config,llm-wiki): hook wiring`) — the guard-scope instance (Mode 2): `command -v python3 && python3 hook.py || true` absorbed both "python3 absent" and "python3 present, hook failed" (measured rc 0 vs 3), fixed with an `if` branch whose absorption is bounded by syntax. Caught by the Codex reviewer citing the `code_review.md` P1 rule that PR #183 had added two merges earlier. Same PR carried Mode 8's second occurrence (11 unquoted `${CLAUDE_PLUGIN_ROOT}` hook commands against 7 already-quoted Codex descriptors) and a macOS notification path that fired on every Stop and displayed nothing (OSC 777 is an rxvt extension Terminal.app does not implement).
9. **PR #186** (`fix: 이식성 잔여`) — the audit-lens instance (Mode 9): a macOS-scoped portability audit missed a resolver bug that breaks identically on GNU (whole-path sort lets the marketplace name outrank the version, `sort -V` included), and missed both reverse regressions its own fixes introduced on Windows (`python3` is absent from a python.org install) — the reviewer caught both. Also showed a severity rating inheriting the lens's scope: a call site rated cosmetic on "macOS has no CUDA anyway" is a real functional break on Windows, where CUDA exists. Fixed with a `python3`/`python`/`py -3` probe in an indexed array and a basename sort key.
10. **PR #187** (`feat(ci): 셸 이식성 가드 + macOS 레그`) — the exemption-leak instance (Mode 10), found while building `scripts/check-shell-portability.mjs`, the guard that finally gives `code_review.md` P1's cross-platform rule enforcement. Its false-positive suppression counted a nearby comment as evidence of a fallback, and a `cksum`-mentioning comment above a fixed `md5sum` line made the guard pass the very defect from PR #172 that motivated it; the `sed -i` exclusion, written as "followed by a quote" to admit BSD's `sed -i ''`, admitted GNU `sed -i "s/a/b/"` too. Both closed, then verified in both directions — 245 files with 0 findings, and exactly 6 findings on a worktree with this PR series' six real defects reinjected.
11. **PR #189** (`feat(council): 이종 벤더 3인 심의 플러그인`) — the scope variant of Mode 10, and the first instance where the leak survived two repairs. A `convene` assertion for the `RUN_KEY` charset gate first searched the whole document (a sibling block's copy kept it green when one of four gates was deleted), then searched per-block but matched the charset string anywhere in the block (a comment explaining the charset counted as the gate). Only the third version — track the `case "$RUN_KEY" in` statement and require it before the first use — failed on either removal, verified by deleting each gate in turn. The same PR's suite showed the inverse of the whole family: a check that *looked perfectly, at a copy* (a hand-mirrored TTL implementation in the test file) — see [[testing-shell-embedded-in-docs]].
