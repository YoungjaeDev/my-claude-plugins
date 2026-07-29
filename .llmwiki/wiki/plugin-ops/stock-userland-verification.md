---
id: stock-userland-verification
aliases: [grep-ugrep-shim, interactive-shell-masks-portability, env-i-verification, portability-claim-unsound-in-shell, env-i-tool-absence, assert-bsd-userland]
last_verified: 2026-07-29
status: active
volatility: stable
sources: 4
---

# Verify shell portability under stock userland, not the interactive shell

A portability claim ("this script runs on macOS") checked by running the script in your interactive shell is unsound. The interactive shell is not the environment the code actually runs in, and it can make a broken construct look healthy.

## The masking mechanism

Claude Code (and similar harnesses) install shell **functions** that shadow core utilities on `PATH` — most consequentially, a `grep` function routing to `ugrep`. ugrep accepts `-P` (PCRE); BSD `/usr/bin/grep` does not (`grep: invalid option -- P`, exit 2). So a `grep -oP '...\K...'` line that is dead on BSD userland **runs fine when you test it by hand**, because your hand-typed `grep` is not the `grep` the script gets.

Two facts make this a trap, not a curiosity:

- **Hooks do not inherit shell functions.** A hook script launched as `bash "$PLUGIN_ROOT/hook.sh"` is a child process; the parent shell's `grep` function is not exported to it, so the hook gets stock `/usr/bin/grep`. The construct you "verified" interactively breaks in the one place it matters.
- **Codex and Hermes have no shim at all.** They read skill bodies verbatim and run them under a plain shell. A body that depends on the harness's `grep` wrapper is broken for them from the start.

## The rule

Re-verify every portability-sensitive shell path under a stripped environment:

```bash
env -i PATH=/usr/bin:/bin bash script.sh    # what a hook / Codex / Hermes actually gets
```

`env -i` clears inherited functions and variables; the minimal `PATH` forces the OS-stock binaries. If it passes there, it passes for hooks and the other runtimes; if it only passes in your interactive shell, you verified nothing.

This is the empirical counterpart to the static rule in `code_review.md` ("cross-platform shell 가정"): the review rule says *don't write GNU-only constructs*, this says *and don't trust an interactive-shell test that a GNU-only construct is portable*.

### The rule's floor: the stripped environment must still contain the tools

`env -i PATH=/usr/bin:/bin` is sound only for a script whose entire tool set is in stock userland. When the script needs a tool that is *not* — and on macOS `jq` is not; it lives in the Homebrew prefix — the run dies on tool absence having verified nothing, and the failure is easy to misread as a portability finding. The trap is that this is platform-asymmetric: Linux ships `/usr/bin/jq`, so the same command passes there. Confirming the form locally on Linux proves it works on the platform you were not asking about.

For that case, invert the technique: keep `PATH` intact so the non-stock tool resolves, and instead **assert that the tools under test are the BSD builds**. GNU answers `--version`; BSD refuses. So `--version` *succeeding* means Homebrew coreutils have shadowed the system tools and the run is silently re-testing the GNU half that the Linux job already covers — fail loudly there, because a green that proves nothing is worse than a red. Two corollaries:

- **Invoke `/bin/bash`, not `bash`.** A CI image may put Homebrew bash 5 ahead on `PATH`, while the `/bin/bash` a real Mac user has is 3.2. Under `bash` a bash-4-only construct passes in CI and breaks for the user — the same "verified nothing" shape one layer up.
- **A BSD fallback branch that never executes is not evidence.** A suite full of `stat -c … || stat -f …` pairs asserts only the GNU half while it runs on GNU runners; the BSD leg is the only place the other half is exercised at all.

## Porting traps: `grep -oP` → POSIX

Replacing PCRE extraction with portable tooling has three traps, each caught in the #160 review after the mechanical conversion looked correct:

- **Greedy sed selects the LAST match, not the first.** `grep -oP '"command"…' | head -1` returns the *first* `"command"` on the line; the naive port `sed -n 's/.*"command"[^"]*"\([^"]*\)".*/\1/p'` has a greedy `.*` prefix that skips to the *last* `"command"`, silently inverting first-match semantics (a duplicate-key JSON yields SECOND, not FIRST). Use awk `match()` — it returns the first occurrence — then `substr` to the next quote and `exit`.
- **awk prints nothing on empty input.** `awk '{…; print s+0}'` only runs the block while there is input, so an empty `git diff --shortstat` yields an empty string, and a trailing `|| echo 0` never fires because awk exited 0. Move the print into `END{print s+0}` so a numeric zero is always emitted.
- **The `"`-terminated scan truncates escaped quotes.** Both the sed `[^"]*` and the awk "up to next `\"`" forms stop at the first quote, so `"echo \"hi\""` truncates at the escaped quote. This is pre-existing (the old `grep -oP '[^"]+'` truncated identically) and tolerated on the jq-absent fallback path, where the value feeds a hint trigger, not a gate — but a real JSON parse must not be built this way.

The through-line: a portability port is not done when it stops erroring — it is done when it returns the *same value* the original did, verified under stock userland against adversarial input (duplicate keys, empty input, escaped quotes).

## Why it recurs

The masking is invisible by construction — the whole point of a shim is that `grep` keeps working. You only see it by running the exact command the deploy target runs, in the environment it runs in. A detector broken this way is doubly dangerous because it also reports "nothing wrong" (see [[detector-cannot-look-vs-nothing-wrong]] Mode 5): a `grep -oP` that silently yields empty under BSD grep makes a staleness/lint check a permanent no-op, not an error.

> See-also: [[detector-cannot-look-vs-nothing-wrong]]
> Evidence: plugins/github-dev/skills/cr-fix/tests/run-tests.sh
> Evidence: plugins/llm-wiki/hooks/wiki_stale_check.sh

## Sources

1. **PR #153** (`fix(github-dev): cr-fix path-trust works on BSD/macOS userland`) — the RED verification of the first symlink-escape test falsely *passed* until re-run stock, because the runner's `grep` shim masked the BSD behavior; all findings re-checked under `env -i PATH=/usr/bin:/bin`.
2. **macOS-26 compatibility audit** (24-plugin sweep, 2026-07-22) — `grep -oP` found in 7 llm-wiki hook/skill sites, each `2>/dev/null`-suppressed so BSD grep's failure surfaced as a silent empty value rather than an error; the shim hid every one in interactive use.
3. **PR #160/#161** (`fix(llm-wiki,core-config): portable extraction for BSD/macOS userland`) — converted all 18 `grep -[oc]P` sites to sed/awk/exact-compare; the review surfaced the three porting traps above (greedy-sed last-match, awk empty-input, escaped-quote) after the mechanical conversion first looked correct. Each replacement re-verified under `env -i PATH=/usr/bin:/bin` to return the same value the PCRE form did.
4. **PR #187** (`feat(ci): 셸 이식성 가드 + macOS 레그`) — the macOS CI leg, the first place the suite's BSD fallback branches execute at all. `env -i PATH=/usr/bin:/bin` was the obvious wiring and was wrong here: the suite is built on `jq`, absent from macOS stock userland, so the leg would have died having tested nothing while passing on Linux. Replaced with an assert that `sed`/`date`/`stat` reject `--version` (= BSD builds), a loud failure when Homebrew coreutils shadow them, and `/bin/bash` to pin bash 3.2. The assert logic was checked for discriminating power by running it on GNU Linux, where it exits 1.
