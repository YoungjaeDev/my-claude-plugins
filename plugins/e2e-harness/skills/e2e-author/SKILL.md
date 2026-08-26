---
name: e2e-author
description: Author Playwright E2E tests for critical user flows by orchestrating the official planner and generator agents. Use when the user asks to write or add E2E tests, create a Playwright test plan, generate specs for a flow, or cover a critical user flow end-to-end. Selects CUFs (flows whose failure breaks revenue, data, or trust), runs the planner agent to produce a Markdown plan behind a user review gate, then the generator agent to produce spec files with live-verified semantic getByRole locators, and burns each new spec in with --repeat-each to block flakes before merge. Requires e2e-setup to have generated the agents first. Run from the user's project root.
allowed-tools: Read Write Edit Bash Glob Grep Task AskUserQuestion
---

# E2E Author — planner -> generator orchestration

Turn a critical user flow into a reliable Playwright spec by driving the planner and generator **roles**. This skill orchestrates; the roles do the exploration and code generation. A spec read is a behavior contract; a spec run is a sensor.

Two runtime families, three execution paths, same gates: on **Claude Code** the roles are the named agents `e2e-setup` generated via `init-agents --loop=claude` (**Path A**); on **Codex 0.135** those agent files are not registerable as named subagents, so each role runs as a **generic subagent** carrying the bundled contract from `references/role-contracts.md` (**Path B**), or in-agent sequentially when no delegation is available (**Path C**).

## Precondition check

- Read the E2E SSOT doc (`e2e/AGENTS.md` or `.claude/e2e-guidelines.md`) for the CUF list and conventions. If absent, run `e2e-setup` Step 5 or capture the CUFs inline.
- Confirm the `playwright-test` `.mcp.json` entry and `seed.spec.ts` exist (both paths need them). If missing, route the user to `e2e-harness:e2e-setup` first.
- **Path A only**: confirm the named agents exist (`.claude/agents/playwright-test-planner.md`, `playwright-test-generator.md`). If they are missing **and you are on Claude Code**, run `e2e-setup` — do not hand-roll them. **Do not** demand these Claude agent files under Codex; there the bundled contracts stand in (see Step 0).

## Workflow

0. **Resolve the plugin root + pick the execution path** — run once. The resolver reaches the bundled role contracts on Path B/C; the path decision governs Steps 2-3. Tell the user which path you took in one sentence.
   ```bash
   # Claude exports CLAUDE_PLUGIN_ROOT; Codex 0.135 does not. Each branch verifies
   # the target (CHK) exists before committing, so a stale env falls through.
   CHK="references/role-contracts.md"
   PLUGIN_ROOT=""
   [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -e "$CLAUDE_PLUGIN_ROOT/$CHK" ] && PLUGIN_ROOT="$CLAUDE_PLUGIN_ROOT"
   [ -z "$PLUGIN_ROOT" ] && [ -e "plugins/e2e-harness/$CHK" ] && PLUGIN_ROOT="plugins/e2e-harness"
   if [ -z "$PLUGIN_ROOT" ]; then
     cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
     while IFS= read -r d; do
       [ -e "$d/$CHK" ] && { PLUGIN_ROOT="$d"; break; }
     done < <(ls -1d "$cache_root"/*/e2e-harness/*/ 2>/dev/null | awk -F/ '{print $(NF-1)"\t"$0}' | sort -t. -k1,1rn -k2,2rn -k3,3rn | cut -f2- | sed 's#/$##')
   fi
   { [ -n "$PLUGIN_ROOT" ] && [ -e "$PLUGIN_ROOT/$CHK" ]; } || { echo "e2e-author: role contracts not resolved (need $CHK)" >&2; exit 1; }
   echo "PLUGIN_ROOT=$PLUGIN_ROOT"
   ```
   - **Path A** — the named agents `playwright-test-planner` / `-generator` are registered (Claude Code): dispatch them by name (Steps 2-3, unchanged).
   - **Path B** — named agents are not registerable but a generic subagent tool is available (Codex `Task`): dispatch one generic subagent per role, carrying the matching contract from `${PLUGIN_ROOT}/references/role-contracts.md` inline.
   - **Path C** — no delegation available: run each role yourself, in order, following the same contract with your own tools (`Bash` for `npx playwright`, the `playwright-test` MCP server for browser drive).

1. **Select the critical user flow(s)**:
   - A CUF is a flow where a regression breaks **revenue, data integrity, or user trust** (checkout, signup+login, create/edit/delete persistence, permissions). Prefer these over breadth.
   - If the SSOT doc lists CUFs, pick from it. Otherwise use AskUserQuestion to confirm the 1-3 flows in scope. Do not auto-pick everything — E2E breadth is a cost.

2. **Plan (planner role) + review gate** — dispatch via the Step 0 path:
   - **Path A**: `Task(subagent_type="playwright-test-planner", prompt="<the CUF + any PRD/notes>. Run seed.spec.ts to set up the environment, explore the app, and write a Markdown test plan under specs/.")`.
   - **Path B** (Codex generic subagent): `Task(prompt="You are the Playwright planner role. Contract (from ${PLUGIN_ROOT}/references/role-contracts.md, 'planner'): run seed.spec.ts first, explore the app via the playwright-test MCP server, write specs/<flow>.md (plan only, no code). CUF: <the CUF + any PRD/notes>.")` — paste the `planner` contract inline.
   - **Path C**: run the planner role yourself per the contract — run `seed.spec.ts`, explore via the `playwright-test` MCP server, write `specs/<flow>.md`.
   - The planner writes `specs/<flow>.md` (a plan, no code) on every path.
   - **MANDATORY user review gate** (all paths): present the plan and get explicit approval (AskUserQuestion) before generating any code. The plan is cheap to fix; generated specs are not. Incorporate edits into `specs/<flow>.md` before proceeding.

3. **Generate (generator role)** — dispatch via the Step 0 path:
   - **Path A**: `Task(subagent_type="playwright-test-generator", prompt="Turn specs/<flow>.md into Playwright spec files under e2e/. Verify every selector and assertion live as you go.")`.
   - **Path B** (Codex generic subagent): `Task(prompt="You are the Playwright generator role. Contract (from ${PLUGIN_ROOT}/references/role-contracts.md, 'generator'): turn specs/<flow>.md into e2e/<flow>.spec.ts, verifying every selector/assertion live via the playwright-test MCP server; semantic getByRole/getByLabel/getByText only, no CSS/XPath, no waitForTimeout.")` — paste the `generator` contract inline.
   - **Path C**: run the generator role yourself per the contract.
   - The generator verifies selectors/assertions against the running app as it writes.
   - **Enforce semantic locators** (all paths): specs must use `getByRole(role, { name })` / `getByLabel` / `getByText`, not CSS/XPath. If brittle selectors are emitted, send the role back to fix them (Playwright's own best-practice is role-first locators).

4. **Burn-in (flake gate)**:
   ```bash
   npx playwright test e2e/<flow>.spec.ts --repeat-each=3
   ```
   - `--repeat-each=N` runs each test N times unconditionally — it surfaces intermittent flakiness *before* merge.
   - **A single failure across the repeats = flaky = blocked.** Do not merge a spec that is not green on every repeat. If it flakes, hand it to `e2e-harness:e2e-debug` (or the healer) and re-burn. Catching flakes at authoring time is far cheaper than in CI.

5. **Convention cleanup**:
   - Split long flows into `test.step("...")` blocks for readable traces.
   - Match the project's conventions from the SSOT doc (step-name language — English or Korean —, file layout `e2e/<feature>.spec.ts`, fixture naming). Learn from existing specs rather than imposing a new style.
   - Ensure no arbitrary `waitForTimeout` — use web-first assertions (`expect(locator).toBeVisible()`).

6. **Report**: list the spec files written, the burn-in result (N/N green), and the locator/convention state. Stage only the new/changed E2E files.

## Notes

- **Test independence — set state via API, don't replay shared prefixes.** When flows share a long common prefix (e.g. consent -> phone auth) before branching, do NOT make each test re-run that prefix through the UI. Have the generator put the user at the branch's start state via a test API, then assert only that branch. This avoids cascade failures (a prefix change failing every test) and cumulative runtime, and keeps tests independent. This is distinct from `storageState` (auth only) — it sets mid-flow app state. Capture the available state-setup endpoints in the E2E SSOT doc.
- The planner/generator roles drive the browser through the `playwright-test` MCP server; if their tool calls fail, verify `.mcp.json` is approved (`/mcp`).
- This skill does not set up the harness (`e2e-setup`) or repair CI failures (`e2e-debug`).
