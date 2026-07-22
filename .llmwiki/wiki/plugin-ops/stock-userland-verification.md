---
id: stock-userland-verification
aliases: [grep-ugrep-shim, interactive-shell-masks-portability, env-i-verification, portability-claim-unsound-in-shell]
last_verified: 2026-07-22
status: active
volatility: stable
sources: 2
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

## Why it recurs

The masking is invisible by construction — the whole point of a shim is that `grep` keeps working. You only see it by running the exact command the deploy target runs, in the environment it runs in. A detector broken this way is doubly dangerous because it also reports "nothing wrong" (see [[detector-cannot-look-vs-nothing-wrong]] Mode 5): a `grep -oP` that silently yields empty under BSD grep makes a staleness/lint check a permanent no-op, not an error.

> See-also: [[detector-cannot-look-vs-nothing-wrong]]
> Evidence: plugins/github-dev/skills/cr-fix/tests/run-tests.sh
> Evidence: plugins/llm-wiki/hooks/wiki_stale_check.sh

## Sources

1. **PR #153** (`fix(github-dev): cr-fix path-trust works on BSD/macOS userland`) — the RED verification of the first symlink-escape test falsely *passed* until re-run stock, because the runner's `grep` shim masked the BSD behavior; all findings re-checked under `env -i PATH=/usr/bin:/bin`.
2. **macOS-26 compatibility audit** (24-plugin sweep, 2026-07-22) — `grep -oP` found in 7 llm-wiki hook/skill sites, each `2>/dev/null`-suppressed so BSD grep's failure surfaced as a silent empty value rather than an error; the shim hid every one in interactive use.
