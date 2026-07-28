---
id: detector-cannot-look
aliases: [could-not-look-false-clean, degraded-answer-not-nothing, pipefail-detector-silent-noop]
tier: insight
promoted_from: [[detector-cannot-look-vs-nothing-wrong]]
evidence_count: 6
last_verified: 2026-07-28
status: active
volatility: stable
sources: 1
---

# A detector must never convert "could not look" into "nothing wrong"

A read-only check that cannot evaluate an axis must say so, keep going, and never emit an all-clear for the part it could not inspect. The failure hides as success in six shapes, all observed in this repo across 6 PRs (the fifth inverts the symptom — a false block instead of a false clean — but has the same cause):

- **`pipefail` abort** — `find`/`jq` inside `$(...)` exits non-zero on normal input (`find` = no match, `jq` = corrupt file) and `set -euo pipefail` kills the whole diagnostic → no output, reads as "tool broken" not "your config is."
- **`|| true` false-clean, and its wider form: guard scope** — patching the abort with `|| true` turns it invisible (empty/`[]`/`"x"` all yield "no duplicates found," a lie for "I could not compare"). The subtler failure is a guard that absorbs more than intended: `cmd -v X && X … || true` covers the whole `&&` chain, so "X absent" (intended) and "X ran and failed" (must not be hidden) both exit 0. Use `if cmd -v X …; then X …; fi`, whose absorption is bounded by syntax rather than by operator precedence.
- **Degraded remote payload** — a well-formed but partial API answer (GraphQL null envelope, missing `pageInfo`, probe rc 0 read as 404) flows through `// []` into a confident empty result the convergence loop reads as clean.
- **Non-portable tool** — the check's own binary can't run on this OS (`realpath -m` on BSD aborts under `set -e`), so its gate skips every item and the loop converges `final_state=clean` — auto-merge eligible. Invisible in an interactive shell where a `grep`→ugrep shim masks it, so re-verify under `env -i PATH=/usr/bin:/bin`. Outside a detector the same missing tool hides in pipeline *position*: `$(… | md5sum | cut | head)` takes its status from `head`, so `set -e` never fires and the empty value ships as if computed.
- **Unswept sibling consumer** — the repair lands on the caller that reported the bug while other readers of the same signal keep the narrow definition, so the trap returns wearing a different symptom. `engagement-gate.sh` still counted CR comments by `created_at` after `sniff-cr-rate-limit.sh` was widened to `created_at or updated_at`; because CR edits its walkthrough in place on a clean re-review, a genuine convergence read as "CR never looked" and `--auto-merge` became unreachable. Widening a signal is not done until you grep every consumer of it.

- **The audit's own question** — a check scoped to one platform/dimension cannot report on the ones it never asked about, including the platform its own fix just broke. A defect that fails identically everywhere does not answer "what breaks on BSD?", and a severity justified by one platform's properties ("macOS has no CUDA, so it exits anyway") is scoped to that platform too. Before shipping a portability fix, ask what the changed line does on every platform the surrounding block serves.

**When to apply**: writing or reviewing any script that answers "is X wired up / clean / resolved?" — config detectors, review gates, convergence loops, merge gates. Guard on the exact question asked, require the full expected shape, give the gate test coverage, and verify tool portability under stock userland.

**Why**: every instance ships disguised as an edge case and is found only by running the script against the ugly input / wrong platform, not by reading it. The cost is real: a gate that can't look green-lit an auto-merge of unresolved CRITICAL findings.

Full mode-by-mode analysis, fixes, and per-PR provenance stay in the `promoted_from:` wiki page.

## Sources

- `.llmwiki/wiki/plugin-ops/detector-cannot-look-vs-nothing-wrong.md` — the promoted source page (Modes 1-9, PRs #104/#106/#122/#153/#164/#167/#183/#185/#186).

> Evidence: .llmwiki/wiki/plugin-ops/detector-cannot-look-vs-nothing-wrong.md
> See-also: [[detector-cannot-look-vs-nothing-wrong]]
> See-also: [[stock-userland-verification]]
