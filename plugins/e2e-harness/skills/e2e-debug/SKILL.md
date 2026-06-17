---
name: e2e-debug
description: Close the Playwright self-healing loop — diagnose and repair a failing or flaky E2E run using the trace and the official healer agent. Use when the user points at a failed CI run or PR, asks to fix a broken or flaky E2E test, debug a Playwright failure, or repair the suite. Downloads the CI trace artifact, inspects it headlessly via npx playwright trace (actions/requests/console/errors), then runs the healer agent to find the root cause and patch the test, bounded to 3 attempts before quarantining the test with test.skip plus a reason comment. Re-runs to verify green before reflecting the fix on the PR. Requires e2e-setup to have generated the agents. Run from the user's project root.
allowed-tools: Read Write Edit Bash Glob Grep Task AskUserQuestion
---

# E2E Debug — trace analysis + healer (close the loop)

The third leg of the harness. A CI failure is a sensor reading; this skill turns it back into a green test (or an honest quarantine), closing the planner -> generator -> **healer** self-improving loop.

> **Verified against Playwright 1.61.0.** The headless `npx playwright trace` CLI was introduced in 1.59; the subcommand set below is confirmed on 1.61. The GUI viewer `npx playwright show-trace <trace.zip>` is also available if a human wants to look.

## Precondition check

- Confirm the healer exists: `.claude/agents/playwright-test-healer.md`. If missing, route to `e2e-harness:e2e-setup`.
- Need `gh` CLI authenticated to fetch CI artifacts.

## Workflow

1. **Identify the failing run**:
   - Input is a failed CI run URL/ID or a PR. Resolve the run:
     ```bash
     gh run list --branch <branch> --workflow E2E --json databaseId,conclusion -L 5
     # or, from a PR:  gh pr checks <PR>
     ```
   - Read the failing step log to get the failing test name(s): `gh run view <run-id> --log-failed`.

2. **Fetch + inspect the trace (headless)**:
   - Download the artifact written by the CI template (`playwright-report-<run-id>`, which carries `playwright-report/` + `test-results/` with the `trace.zip` files):
     ```bash
     gh run download <run-id> -n playwright-report-<run-id> -D ./_e2e-artifacts
     ```
   - Inspect the trace from the command line (no GUI needed — this is the agent-friendly path):
     ```bash
     TRACE=$(find ./_e2e-artifacts -name trace.zip | head -1)
     npx playwright trace open "$TRACE"      # extract for inspection
     npx playwright trace actions            # list actions (find the failing one)
     npx playwright trace action <action-id> # details of the failing action
     npx playwright trace requests           # network requests (catch a 4xx/5xx)
     npx playwright trace console            # console messages
     npx playwright trace errors             # errors with stack traces
     npx playwright trace close              # clean up extracted data
     ```
   - Form a hypothesis: is it a **real regression** (app changed), a **selector drift** (UI moved), an **environment/data** issue, or a **genuine flake** (timing/race)? The fix differs per class — heal selector/timing issues; escalate real regressions to the user.

3. **Heal (bounded loop)**:
   - Dispatch the healer with the diagnosis: `Task(subagent_type="playwright-test-healer", prompt="Test <name> fails: <trace findings>. Replay the failing steps, find equivalent current elements, patch the test, and re-run until green.")`.
   - **Bounded to 3 attempts** (the cr-fix MAX_ITER pattern): after 3 healer attempts that do not produce a green run, **stop**. Do not loop indefinitely on a stubborn test.
   - If a real regression is suspected (the app behavior genuinely changed, not the test), do **not** auto-patch the test to pass — surface it to the user; the test may be correctly failing.

4. **Verify**:
   - Re-run the specific test, then burn it in:
     ```bash
     npx playwright test e2e/<flow>.spec.ts --repeat-each=3
     ```
   - Green on every repeat -> the fix holds. A pass-then-fail = still flaky -> back to step 3 (within the attempt budget).

5. **Resolve or quarantine**:
   - **Fixed**: stage the patched spec, summarize the root cause, and reflect on the PR (comment or push the fix per the user's flow).
   - **Not fixed after 3 attempts**: quarantine honestly — mark `test.skip` (or `test.fixme`) with a comment stating the reason and a link to a tracking issue. Never leave the suite red or silently drop coverage. Report the quarantine explicitly so it is visible, not buried.

## Notes

- The healer drives the browser via the `playwright-test` MCP server; if its tool calls fail, verify `.mcp.json` is approved (`/mcp`).
- This skill does not author new tests (`e2e-author`) or set up the harness (`e2e-setup`).
