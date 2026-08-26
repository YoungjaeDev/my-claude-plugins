---
name: e2e-setup
description: Onboard a full Playwright E2E test harness in the current project — verify/install Playwright, generate the official planner/generator/healer agents via npx playwright init-agents --loop=claude, scaffold auth separation (storageState + setup project), network route mocking, an E2E operating SSOT doc, and a gated GitHub Actions CI workflow with trace artifacts and PR-failure comments. Use when the user asks to set up E2E, add Playwright AI agents, bootstrap end-to-end testing, or wire E2E into CI. Never overwrites an existing playwright.config (merge proposal + backup). Degrades gracefully when Playwright is absent. Run from the user's project root, not this marketplace repo.
allowed-tools: Read Write Edit Bash Glob Grep AskUserQuestion
---

# E2E Setup — full Playwright harness onboarding

Stand up Playwright's official AI test harness (planner -> generator -> healer) plus the surrounding engineering (auth separation, deterministic mocking, an E2E SSOT doc, gated CI). The harness is the point: a test run is a sensor, a test file is a spec, and the three roles form a self-improving loop. This skill only does **setup + orchestration + CI + integration** — it does not re-implement the roles.

> **Two runtime paths (Step 2).** Under **Claude Code**, `init-agents --loop=claude` generates the planner/generator/healer as registerable `.claude/agents/*.md`, and `e2e-author` / `e2e-debug` dispatch them by name (**Path A**). Under **Codex 0.135**, those generated agent files are not registerable as named subagents, so setup skips them, ensures the `.mcp.json` `playwright-test` entry, and the author/debug skills run the same roles as **generic subagents** carrying the bundled `references/role-contracts.md` (**Path B**), or sequentially when no delegation is available (**Path C**). The engineering below (Steps 3-7) and every gate are identical on both paths.

> **Why this skill exists (the harness-engineering point).** Installing the official agents is NOT enough — out of the box they skip auth setup, can't resolve project-known API errors, and don't know test-account usage, because they lack codebase context. Steps 3-7 below *onboard them like a new hire*: the config, auth scaffold, route-mock guidance, and especially the E2E SSOT doc are the context an agent needs to work autonomously. Skipping them is the usual reason "the official agents didn't just work."

> Bundled templates live at `<plugin-root>/assets/`. Resolve `<plugin-root>` with the cross-runtime block in Step 0 (Claude `CLAUDE_PLUGIN_ROOT`, Codex plugin cache) — Codex 0.135 does not export `CLAUDE_PLUGIN_ROOT`, so a bare `${CLAUDE_PLUGIN_ROOT}/assets/...` copy fails there. The three template files are `playwright-ci.yml`, `e2e-guidelines.template.md`, `route-mock.scaffold.ts`.
>
> **Verified against Playwright 1.61.0** (init-agents introduced in 1.56; trace CLI in 1.59). Filenames/output below are current-version facts — Playwright's docs say agent definitions "should be regenerated whenever Playwright is updated," so re-run init-agents after upgrades.

## Preconditions / graceful degrade

- This runs in the **user's project**, not the marketplace repo. Confirm a project root with a `package.json` (or offer to `npm init`).
- If Node/npm is missing, stop and report — do not guess an install path.
- This skill never assumes `github-dev` or any sibling plugin is installed.

## Workflow

0. **Resolve the plugin root (cross-runtime)** — run once, reuse `PLUGIN_ROOT` in the `cp` steps below (Steps 5-7). Re-run the block if a later step runs in a fresh shell.
   ```bash
   # Claude exports CLAUDE_PLUGIN_ROOT; Codex 0.135 does not. Every branch verifies
   # its target (CHK) exists before committing, so a stale env or an incomplete
   # cache version falls through instead of winning. The cache branch walks
   # versions high-to-low and takes the first COMPLETE one.
   CHK="assets"
   PLUGIN_ROOT=""
   [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -e "$CLAUDE_PLUGIN_ROOT/$CHK" ] && PLUGIN_ROOT="$CLAUDE_PLUGIN_ROOT"
   [ -z "$PLUGIN_ROOT" ] && [ -e "plugins/e2e-harness/$CHK" ] && PLUGIN_ROOT="plugins/e2e-harness"
   if [ -z "$PLUGIN_ROOT" ]; then
     cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
     while IFS= read -r d; do
       [ -e "$d/$CHK" ] && { PLUGIN_ROOT="$d"; break; }
     done < <(ls -1d "$cache_root"/*/e2e-harness/*/ 2>/dev/null | awk -F/ '{print $(NF-1)"\t"$0}' | sort -t. -k1,1rn -k2,2rn -k3,3rn | cut -f2- | sed 's#/$##')
   fi
   { [ -n "$PLUGIN_ROOT" ] && [ -e "$PLUGIN_ROOT/$CHK" ]; } || { echo "e2e-setup: plugin root not resolved (need $CHK)" >&2; exit 1; }
   echo "PLUGIN_ROOT=$PLUGIN_ROOT"
   ```

1. **Detect / install Playwright**:
   - Check for `@playwright/test` in `package.json` and a `playwright.config.*`. If absent, propose `npm init playwright@latest` (interactive) or `npm i -D @playwright/test && npx playwright install --with-deps`.
   - Always ensure browsers are installed: `npx playwright install --with-deps`.
   - If the user declines installation, stop here — the rest of the harness needs Playwright.

2. **Set up the roles — runtime branch** (planner / generator / healer). Pick the path **once** by capability; the same gates apply on every path (`${PLUGIN_ROOT}/references/role-contracts.md`, "Gates that hold on every path"). Tell the user which path you took in one sentence.

   | Path | Condition | How the roles are set up |
   |---|---|---|
   | **A — Claude generated agents** | Running under Claude Code (init-agents can generate registerable `.claude/agents/*.md`). | `init-agents --loop=claude` + verify the generated files. Default on Claude Code. |
   | **B/C — Codex bundled contracts** | Running under Codex 0.135 (or any runtime that cannot register generated agent files as named subagents). | Do **not** generate/rely on named agents. Ensure the `.mcp.json` `playwright-test` entry and point `e2e-author` / `e2e-debug` at the bundled role contracts. |

   **Path A (Claude Code):**
   ```bash
   npx playwright init-agents --loop=claude
   ```
   - `--loop` accepts `vscode | claude | codex | opencode`. Use `claude` for Claude Code. (There is no `copilot` value.)
   - **Verify the actual output** (1.61 generates, at the project root):
     - `.claude/agents/playwright-test-planner.md`
     - `.claude/agents/playwright-test-generator.md`
     - `.claude/agents/playwright-test-healer.md`
     - `.mcp.json` — MCP config for the `playwright-test` server (`npx playwright run-test-mcp-server`). **Confirm this file exists**; init-agents creates it for the claude loop. If it is missing (older Playwright), merge it with the recipe below.
     - `seed.spec.ts` at the **repo root** (default environment seed the planner runs first) and `specs/README.md` (test-plan directory).

   **Path B/C (Codex — no registerable named agents):**
   - Do not invent an unsupported loop. Feature-detect `--loop=codex` rather than version-guessing (`npx playwright init-agents --help | grep -qw codex`). Even when it is advertised, Codex 0.135 cannot register the generated agent files as named subagents, so `e2e-author` / `e2e-debug` will dispatch **generic** subagents carrying the bundled contracts (or run the roles sequentially). Running `--loop=codex` is at most an optional scaffold for `.mcp.json` / `seed.spec.ts` / `specs/`; skip agent generation when it is not advertised.
   - The runtime-neutral planner/generator/healer contracts ship at `${PLUGIN_ROOT}/references/role-contracts.md` (PLUGIN_ROOT from Step 0 — same root that holds `assets/`). `e2e-author` / `e2e-debug` read them via their own Step 0 resolver; no per-project copy is needed.
   - **Seed the environment scaffold** — Path A gets `seed.spec.ts` + `specs/README.md` from `init-agents`, but Path B/C skip agent generation, so create the equivalents yourself (the planner runs `seed.spec.ts` first on every path, and `e2e-author` requires it — without this, Codex setup leaves authoring blocked). Skip either file if it already exists. Write `seed.spec.ts` at the repo root:
     ```ts
     // Default environment seed the planner runs first (Path B/C stand-in for the
     // init-agents output). Establishes baseline app state; expand per your app.
     import { test, expect } from "@playwright/test";

     test("seed: app reachable", async ({ page }) => {
       await page.goto(process.env.E2E_BASE_URL ?? "http://localhost:3000");
       await expect(page).toHaveTitle(/.*/);
     });
     ```
     and `specs/README.md` (the test-plan directory):
     ```md
     # specs/ — test plans

     Human-readable planner output, one Markdown file per critical user flow.
     The generator turns an approved `specs/<flow>.md` into `e2e/<flow>.spec.ts`.
     ```

   **Both paths — ensure the `playwright-test` `.mcp.json` entry (merge, never clobber unrelated servers):**
   ```bash
   PW_ENTRY='{"command":"npx","args":["playwright","run-test-mcp-server"]}'
   if ! command -v jq >/dev/null 2>&1; then
     echo "jq not found — cannot safely merge .mcp.json. Add this under .mcpServers[\"playwright-test\"] manually: $PW_ENTRY" >&2
   elif [ -f .mcp.json ]; then
     if jq -e '.mcpServers["playwright-test"]' .mcp.json >/dev/null 2>&1; then
       echo ".mcp.json already defines playwright-test — do NOT clobber; show a diff and let the user decide." >&2
     else
       tmp=$(mktemp ./.mcp.json.XXXXXX)  # same dir as target so mv is an atomic rename, not a cross-fs copy
       if jq --argjson e "$PW_ENTRY" '.mcpServers["playwright-test"] = $e' .mcp.json > "$tmp"; then
         mv "$tmp" .mcp.json
       else
         rm -f "$tmp"; echo ".mcp.json merge failed — left unchanged; add playwright-test manually: $PW_ENTRY" >&2
       fi
     fi
   else
     printf '{ "mcpServers": { "playwright-test": %s } }\n' "$PW_ENTRY" > .mcp.json
   fi
   ```
   If the merge above reported a failure, stop and fix `.mcp.json` before continuing — setup cannot proceed without the `playwright-test` server. Otherwise, tell the user to approve the MCP server (`/mcp` or restart) so the roles can drive the browser. A conflicting existing `playwright-test` definition is a review-gated merge proposal, never a silent replace.
   - `init-agents` does **not** generate `playwright.config.*` on either path — handle that in Step 3.

3. **playwright.config — never clobber**:
   - If a `playwright.config.*` already exists: **do not overwrite.** Back it up (`cp playwright.config.ts playwright.config.ts.bak`) and propose a *merge* (add the `setup` project + `dependencies`, a `webServer` if local, `trace: 'on-first-retry'`, `retries` for CI). Show the diff and let the user accept.
   - If none exists, create one with the setup-project pattern from Step 4 plus sensible reporter/trace defaults:
     ```ts
     import { defineConfig, devices } from "@playwright/test";
     export default defineConfig({
       testDir: "./e2e",
       retries: process.env.CI ? 2 : 0,
       reporter: [["html"], ["list"]],
       use: { baseURL: process.env.E2E_BASE_URL ?? "http://localhost:3000", trace: "on-first-retry" },
       projects: [
         { name: "setup", testMatch: /.*\.setup\.ts/ },
         { name: "chromium", use: { ...devices["Desktop Chrome"], storageState: "playwright/.auth/user.json" }, dependencies: ["setup"] },
       ],
       // webServer: { command: "npm run dev", url: "http://localhost:3000", reuseExistingServer: !process.env.CI },
     });
     ```

4. **Auth separation scaffold** (one-time login, reused via `storageState`):
   - Create `e2e/auth.setup.ts` (a `setup` project test that logs in once and saves state). Canonical pattern:
     ```ts
     import { test as setup, expect } from "@playwright/test";
     import path from "path";
     const authFile = path.join(__dirname, "../playwright/.auth/user.json");
     setup("authenticate", async ({ page }) => {
       await page.goto("/login");
       await page.getByLabel("Email").fill(process.env.E2E_USER!);
       await page.getByLabel("Password").fill(process.env.E2E_PASS!);
       await page.getByRole("button", { name: "Sign in" }).click();
       await expect(page.getByRole("button", { name: /account|profile/i })).toBeVisible();
       await page.context().storageState({ path: authFile });
     });
     ```
   - Add `playwright/.auth/` to `.gitignore` (never commit session state). Credentials come from env (`E2E_USER` / `E2E_PASS`), never hardcoded.

5. **E2E operating SSOT doc**:
   - Copy `${PLUGIN_ROOT}/assets/e2e-guidelines.template.md` (PLUGIN_ROOT from Step 0) to the project (default `e2e/AGENTS.md`; offer `.claude/e2e-guidelines.md` as an alternative). This is the single source of truth for *what* to test (CUFs), auth scenarios, environments, mocking policy, conventions, flake policy, CI gating — **distinct** from the repo-wide `AGENTS.md`/`CLAUDE.md`.
   - Walk the user through filling the `<...>` placeholders, at minimum the CUF list (used by `e2e-author`).

6. **Network route-mock scaffold**:
   - Copy `${PLUGIN_ROOT}/assets/route-mock.scaffold.ts` (PLUGIN_ROOT from Step 0) to `e2e/` (e.g. `e2e/_route-mock.example.ts`) as a reference for `page.route` + `route.fulfill`.
   - **Detect framework**: if Next.js (or another SSR/BFF stack — check `next` in `package.json`), surface the caveat prominently: `page.route` only intercepts **browser** requests; server-side fetches (Server Components, route handlers, `getServerSideProps`) bypass it. Mock those with an E2E-only env flag at the data layer, a stubbed upstream, or a seeded test DB. The scaffold documents all three.

7. **Gated CI workflow**:
   - Copy `${PLUGIN_ROOT}/assets/playwright-ci.yml` (PLUGIN_ROOT from Step 0) to `.github/workflows/e2e.yml`.
   - Customize the `paths:` filter to the project's app/test dirs (keep it narrow — avoid running the suite on every push). The template also supports `e2e`-label force-run.
   - It uploads `playwright-report/` + `test-results/` as artifacts and posts a **PR comment on failure** via `gh pr comment` (no official Playwright PR-comment step exists — this is custom). Remind the user to set `E2E_USER` / `E2E_PASS` secrets and the `E2E_BASE_URL` variable.
   - Validate the YAML if `actionlint` is available; otherwise note it is unvalidated.

8. **Report**: state the runtime path taken (A generated agents / B-C bundled contracts), list every file created/modified, whether `.mcp.json` was present, merged, or written, the SSOT doc location, and the next step — author CUF tests with `e2e-harness:e2e-author`.

## Out of scope

This skill does not write tests (that is `e2e-author`) or repair failures (that is `e2e-debug`). It does not configure non-GitHub CI.
