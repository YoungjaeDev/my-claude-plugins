---
name: diagnose
description: "Diagnose a bug by capturing a failing command before touching code, then falsify ranked hypotheses instead of guessing. Use when the user asks to diagnose or debug something broken, throwing, failing, or slow, or says '버그 원인', '디버깅', '왜 실패', '원인 분석'. Procedure: (1) capture one failing command that reproduces the user's exact symptom, (2) minimize the repro to its load-bearing parts, (3) rank 3-5 falsifiable hypotheses, (4) add tagged instrumentation that targets one hypothesis at a time, (5) write a regression test at a real seam before the fix, (6) run a cleanup checklist (remove instrumentation, confirm the fix, state the cause). Not for authoring new tests (dev:e2e-author) or healing a known-flaky Playwright run (dev:e2e-debug): those start after a cause is already known."
---

# diagnose

A discipline for bugs that resist a guess-and-check fix: get a failing command first, then falsify hypotheses against it instead of reading code and theorizing.

Adapted from mattpocock/skills `diagnosing-bugs` (commit `74ca5fe`).

## Redact

Every command, output, and captured artifact shown in this skill's steps gets secrets redacted first: replace a credential with `<REDACTED>` before it appears in chat, a log, or a commit message. Prefer reading credentials from env vars at run time over embedding them in a script.

## Step 1: Capture a failing command

This is the step that matters; everything after it just consumes the signal this step produces. Before reading code or forming a theory, get **one command** that:

- reproduces the user's exact reported symptom, not a nearby-looking failure
- fails (red) right now, and will pass (green) once the bug is fixed
- runs unattended, in seconds

In rough order of preference: a failing test at the seam that reaches the bug, a CLI invocation or curl against a fixture, a headless browser script, a replayed captured trace, or a minimal throwaway harness. For "sometimes wrong" bugs, loop the trigger N times and report the failure rate instead of chasing a single clean repro.

If no such command exists yet, building it is the task; do not skip to Step 3. If it genuinely cannot be built (needs an environment or access you do not have), stop and say so explicitly, listing what was tried and what is missing.

**Done when:** you can show the command and its actual output (redacted), and it failed.

## Step 2: Minimize the repro

Shrink the failing case to the smallest input, config, and call chain that still fails. Cut one element at a time and re-run the Step 1 command after each cut; keep only what is load-bearing (removing it turns the command green). A smaller repro narrows Step 3's hypothesis space and becomes the regression test in Step 5.

## Step 3: Rank 3-5 falsifiable hypotheses

Generate 3-5 hypotheses before testing any of them: a single first guess anchors on whatever is most visible, not most likely. Each hypothesis states a falsifiable prediction: "if `<cause>` is true, then `<change>` makes the failing command pass; `<other change>` makes it worse."

Show the ranked list to the user before testing when they are reachable; domain knowledge often re-ranks it instantly. Do not block on it if they are unavailable.

## Step 4: Tagged instrumentation

Add probes that target one hypothesis at a time (never "log everything and grep"). Prefer a debugger or REPL breakpoint over logs where the environment supports it. Every debug log carries a unique tag, e.g. `[DEBUG-a4f2]`, so Step 6 cleanup is one grep. For performance regressions, measure with a timing harness or profiler before touching logs: establish the baseline number first, then bisect against it.

## Step 5: Regression test at a seam

Before applying the fix, turn the minimized repro into a test at a seam that actually exercises the bug as it occurs in production (not a shallow single-caller test standing in for a multi-caller path). Watch it fail, apply the fix, watch it pass, then re-run the Step 1 command against the original unminimized scenario.

If no correct seam exists, that absence is itself a finding: note it in the PR/commit instead of writing a test that gives false confidence.

## Step 6: Cleanup checklist

- [ ] The Step 1 failing command now passes.
- [ ] The regression test from Step 5 passes (or the seam gap is documented).
- [ ] Every `[DEBUG-...]` tag is removed (`grep` the tag to confirm zero hits).
- [ ] Any throwaway harness is deleted or moved to a clearly marked debug location.
- [ ] The confirmed cause is stated in the commit or PR message.

## Related skills

- `dev:e2e-debug` picks up once a Playwright CI failure needs a self-healing repair loop; its hypothesis step points here for the general procedure.
- `dev:resolve-issue` points here from its Step 1 (bug-labeled issues): run this skill before its implementation step.
