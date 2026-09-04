---
name: e2e-debug
description: Close the Playwright self-healing loop — diagnose and repair a failing or flaky E2E run using the trace and the official healer agent. Use when the user points at a failed CI run or PR, asks to fix a broken or flaky E2E test, debug a Playwright failure, or repair the suite. Downloads the CI trace artifact, inspects it headlessly via npx playwright trace (actions/requests/console/errors), then runs the healer agent to find the root cause and patch the test, bounded to 3 attempts before quarantining the test with test.skip plus a reason comment. Re-runs to verify green before reflecting the fix on the PR. Requires e2e-setup to have generated the agents. Run from the user's project root.
allowed-tools: Read Write Edit Bash Glob Grep Task AskUserQuestion
---

# E2E Debug: trace analysis + healer (close the loop)

The third leg of the harness. A CI failure is a sensor reading; this skill turns it back into a green test (or an honest quarantine), closing the planner -> generator -> **healer** self-improving loop.

Two runtime families, three execution paths, same bounded loop: on **Claude Code** the healer is the named agent `e2e-setup` generated (**Path A**); on **Codex 0.135** that agent file is not registerable, so the healer runs as a **generic subagent** carrying the bundled contract from `references/role-contracts.md` (**Path B**), or in-agent sequentially when no delegation is available (**Path C**).

> **Verified against Playwright 1.61.0.** The headless `npx playwright trace` CLI was introduced in 1.59; the subcommand set below is confirmed on 1.61. The GUI viewer `npx playwright show-trace <trace.zip>` is also available if a human wants to look.

## Precondition check

- Need `gh` CLI authenticated to fetch CI artifacts.
- **Path A only**: confirm the named healer exists (`.claude/agents/playwright-test-healer.md`). If missing **and you are on Claude Code**, route to `dev:e2e-setup`. **Do not** demand this Claude agent file under Codex; there the bundled healer contract stands in (see Step 0).
- **Requires Playwright >= 1.59** for the headless `npx playwright trace` CLI used in Step 2 (`npx playwright --version` to check). On older versions there is no headless trace CLI: fall back to the GUI viewer `npx playwright show-trace <trace.zip>`.

## Workflow

0. **Resolve the plugin root + pick the execution path**: run once. The resolver reaches the bundled healer contract on Path B/C; the path decision governs Step 3. Tell the user which path you took in one sentence.
   ```bash
   # Claude exports CLAUDE_PLUGIN_ROOT; Codex 0.135 does not. Each branch verifies
   # the target (CHK) exists before committing, so a stale env falls through.
   CHK="references/role-contracts.md"
   PLUGIN_ROOT=""
   [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -e "$CLAUDE_PLUGIN_ROOT/$CHK" ] && PLUGIN_ROOT="$CLAUDE_PLUGIN_ROOT"
   [ -z "$PLUGIN_ROOT" ] && [ -e "plugins/dev/$CHK" ] && PLUGIN_ROOT="plugins/dev"
   if [ -z "$PLUGIN_ROOT" ]; then
     cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
     while IFS= read -r d; do
       [ -e "$d/$CHK" ] && { PLUGIN_ROOT="$d"; break; }
     done < <(ls -1d "$cache_root"/*/dev/*/ 2>/dev/null | awk -F/ '{print $(NF-1)"\t"$0}' | sort -t. -k1,1rn -k2,2rn -k3,3rn | cut -f2- | sed 's#/$##')
   fi
   { [ -n "$PLUGIN_ROOT" ] && [ -e "$PLUGIN_ROOT/$CHK" ]; } || { echo "e2e-debug: role contracts not resolved (need $CHK)" >&2; exit 1; }
   echo "PLUGIN_ROOT=$PLUGIN_ROOT"
   ```
   - **Path A**: named `playwright-test-healer` is registered (Claude Code). Dispatch it by name (Step 3, unchanged).
   - **Path B**: named agent not registerable but a generic subagent tool is available (Codex `Task`). Dispatch a generic subagent carrying the `healer` contract from `${PLUGIN_ROOT}/references/role-contracts.md` inline.
   - **Path C**: no delegation available. Run the healer role yourself per the same contract.

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
   - Inspect the trace from the command line (no GUI needed; this is the agent-friendly path):
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
   - Form a hypothesis: is it a **real regression** (app changed), a **selector drift** (UI moved), an **environment/data** issue, or a **genuine flake** (timing/race)? The fix differs per class: heal selector/timing issues; escalate real regressions to the user.

3. **Heal (bounded loop)**. Dispatch the healer with the diagnosis via the Step 0 path:
   - **Path A**: `Task(subagent_type="playwright-test-healer", prompt="Test <name> fails: <trace findings>. Replay the failing steps, find equivalent current elements, patch the test, and re-run until green.")`.
   - **Path B** (Codex generic subagent): `Task(prompt="You are the Playwright healer role. Contract (from ${PLUGIN_ROOT}/references/role-contracts.md, 'healer'): test <name> fails: <trace findings>. Replay the failing steps via the playwright-test MCP server, find equivalent current elements, patch the test, re-run until green then burn-in --repeat-each=3. Bounded to 3 attempts; do not auto-pass a suspected real regression.")`. Paste the `healer` contract inline.
   - **Path C**: run the healer role yourself per the contract.
   - **Bounded to 3 attempts** (all paths, the cr-fix MAX_ITER pattern): after 3 healer attempts that do not produce a green run, **stop**. Do not loop indefinitely on a stubborn test.
   - If a real regression is suspected (the app behavior genuinely changed, not the test), do **not** auto-patch the test to pass. Surface it to the user; the test may be correctly failing.

4. **Verify**:
   - Re-run the specific test, then burn it in:
     ```bash
     npx playwright test e2e/<flow>.spec.ts --repeat-each=3
     ```
   - Green on every repeat -> the fix holds. A pass-then-fail = still flaky -> back to step 3 (within the attempt budget).

5. **Resolve or quarantine**:
   - **Fixed**: stage the patched spec, summarize the root cause, and reflect on the PR (comment or push the fix per the user's flow).
   - **Not fixed after 3 attempts**: quarantine honestly by marking `test.skip` (or `test.fixme`) with a comment stating the reason and a link to a tracking issue. Never leave the suite red or silently drop coverage. Report the quarantine explicitly so it is visible, not buried.

## Notes

- The healer role drives the browser via the `playwright-test` MCP server; if its tool calls fail, verify `.mcp.json` is approved (`/mcp`).
- This skill does not author new tests (`e2e-author`) or set up the harness (`e2e-setup`).
