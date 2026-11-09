---
name: e2e-setup
description: Onboard a full Playwright E2E test harness in the current project — verify/install Playwright, check playwright-cli availability for the planner/generator roles, generate the official planner/generator/healer agents via npx playwright init-agents --loop=claude (Claude Code Path A; Codex Path B/C skips agent generation and uses the bundled role contracts instead), scaffold auth separation (storageState + setup project), network route mocking, an E2E operating SSOT doc, and a gated GitHub Actions CI workflow with trace artifacts and PR-failure comments. Use when the user asks to set up E2E, add Playwright AI agents, bootstrap end-to-end testing, wire E2E into CI, "E2E 셋업", "E2E 테스트 설치", or "플레이라이트 설정해줘". Never overwrites an existing playwright.config (merge proposal + backup). Degrades gracefully when Playwright is absent. Run from the user's project root, not this marketplace repo.
allowed-tools: Read Write Edit Bash Glob Grep AskUserQuestion
---

# E2E Setup: full Playwright harness onboarding

Stand up Playwright's official AI test harness (planner -> generator -> healer) plus auth separation, deterministic mocking, an E2E SSOT doc and gated CI, in 8 steps. It does not re-implement the roles. The official agents alone skip auth setup and lack codebase context; Steps 3-7 give them that context.

- **Two runtime paths (Step 2)**: on Claude Code, `init-agents --loop=claude` generates registerable `.claude/agents/*.md` that `e2e-author` / `e2e-debug` dispatch by name (Path A). On Codex those files are not registerable, so setup skips them and the later skills run each role as a generic subagent carrying `references/role-contracts.md` (Path B), or sequentially (Path C). Steps 3-7 and every gate are identical on both.
- **Check the installed Playwright, not this file**: `npx playwright init-agents --help` and `npx playwright trace --help` must print that subcommand's own usage. Read `init-agents --help` and `npx playwright --version` before relying on any flag or output filename below, and re-run init-agents after a Playwright upgrade.
- **Bundled files** resolve through Step 0's `PLUGIN_ROOT`, never a bare `${CLAUDE_PLUGIN_ROOT}`, which Codex does not export.

## Preconditions

- Run in the user's project, not the marketplace repo. Confirm a project root with a `package.json`, or offer `npm init`.
- If Node/npm is missing, stop and report; do not guess an install path.
- Never assume the other `dev` skills or a sibling plugin are installed.

## Workflow

0. **Resolve the plugin root (cross-runtime)**: run once and reuse `PLUGIN_ROOT` in Steps 2-7; re-run it in a fresh shell.
   ```bash
   # Claude exports CLAUDE_PLUGIN_ROOT; Codex does not. Every branch verifies
   # its target (CHK) exists before committing, so a stale env or an incomplete
   # cache version falls through instead of winning. The cache branch walks
   # versions high-to-low and takes the first COMPLETE one.
   CHK="assets"
   PLUGIN_ROOT=""
   [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -e "$CLAUDE_PLUGIN_ROOT/$CHK" ] && PLUGIN_ROOT="$CLAUDE_PLUGIN_ROOT"
   [ -z "$PLUGIN_ROOT" ] && [ -e "plugins/dev/$CHK" ] && PLUGIN_ROOT="plugins/dev"
   if [ -z "$PLUGIN_ROOT" ]; then
     cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
     while IFS= read -r d; do
       [ -e "$d/$CHK" ] && { PLUGIN_ROOT="$d"; break; }
     done < <(ls -1d "$cache_root"/*/dev/*/ 2>/dev/null | awk -F/ '{print $(NF-1)"\t"$(0)}' | sort -t. -k1,1rn -k2,2rn -k3,3rn | cut -f2- | sed 's#/$##')
   fi
   { [ -n "$PLUGIN_ROOT" ] && [ -e "$PLUGIN_ROOT/$CHK" ]; } || { echo "e2e-setup: plugin root not resolved (need $CHK)" >&2; exit 1; }
   echo "PLUGIN_ROOT=$PLUGIN_ROOT"
   ```

1. **Detect / install Playwright**:
   - Check for `@playwright/test` in `package.json` and a `playwright.config.*`. If absent, propose `npm init playwright@latest` (interactive) or `npm i -D @playwright/test && npx playwright install --with-deps`. Always ensure browsers with `npx playwright install --with-deps`.
   - If the user declines installation, stop here: the rest of the harness needs Playwright.
   - Check `playwright-cli`: the planner and generator explore the app with it, while the healer keeps the `playwright-test` MCP server.
     ```bash
     # Order from the microsoft/playwright-cli README: global binary, then the
     # project's local `npx playwright cli`, then the published package. No
     # version is pinned here; `--help` on whichever resolves is the reference.
     # A resolution failure (offline, registry down) falls through to `missing`.
     if command -v playwright-cli >/dev/null 2>&1 && playwright-cli --version >/dev/null 2>&1; then
       PW_CLI_MODE=global
     # `cli --help` exits 0 even where `cli` is not a subcommand (the top-level
     # help comes back), so match the playwright-cli banner instead of the status.
     elif npx --no-install playwright cli --help 2>/dev/null | grep -q '^playwright-cli'; then
       PW_CLI_MODE=local
     elif npx --yes @playwright/cli@latest --version >/dev/null 2>&1; then
       PW_CLI_MODE=npx
     else
       PW_CLI_MODE=missing
     fi
     echo "playwright-cli: $PW_CLI_MODE"
     ```
   - `global`, `local` or `npx`: report the mode; the later skills use `playwright-cli <cmd>`, `npx playwright cli <cmd>` or `npx @playwright/cli <cmd>`, with commands from `--help`. `<that invocation> install --skills` installs Playwright's agent skill into `.claude/skills/`; on Codex pass `--skills=agents`.
   - `missing`: never force a global install. Print `npm install -g @playwright/cli@latest` and continue degraded: the planner and generator use the `playwright-test` MCP server until `playwright-cli` exists.

2. **Set up the roles**: pick the path once by capability and tell the user which in one sentence. The same gates apply on every path (`${PLUGIN_ROOT}/references/role-contracts.md`, "Gates that hold on every path").

   | Path | Condition | How the roles are set up |
   |---|---|---|
   | **A: Claude generated agents** | Running under Claude Code (init-agents can generate registerable `.claude/agents/*.md`). | `init-agents --loop=claude` + verify the generated files. Default on Claude Code. |
   | **B/C: Codex bundled contracts** | Running under Codex (or any runtime that cannot register generated agent files as named subagents). | Do **not** generate/rely on named agents. Ensure the `.mcp.json` `playwright-test` entry and point `e2e-author` / `e2e-debug` at the bundled role contracts. |

   - **Path A**: confirm the loop is still offered (`npx playwright init-agents --help | grep -qw claude`); if not, stop and report the `--loop` values the help lists. Then run `npx playwright init-agents --loop=claude`.
   - **Path A, verify the output** (init-agents prints one path per line; else `git status --porcelain -uall`, plus `--ignored`). Expect agents named `playwright-test-planner`, `playwright-test-generator` and `playwright-test-healer`, or stop and report the names it wrote. Also expect `.mcp.json`, `seed.spec.ts` and `specs/`.
   - **Path B/C**: feature-detect `--loop=codex` as `role-contracts.md` "`--loop=codex`" says; never version-guess and never invent a loop. Write the seed and `specs/README.md` from `${PLUGIN_ROOT}/references/e2e-setup-scaffolds.md` unless they exist. The contracts are read in place from `${PLUGIN_ROOT}/references/role-contracts.md`; no per-project copy.
   - **Both paths**: run the `.mcp.json` merge block in `${PLUGIN_ROOT}/references/role-contracts.md` verbatim; it never clobbers unrelated servers. If it reported a failure, stop and fix `.mcp.json`. Otherwise tell the user to approve the MCP server (`/mcp` or restart); a conflicting `playwright-test` definition is a review-gated merge proposal, never a silent replace.

3. **playwright.config, never clobber**: `init-agents` writes none on either path.
   - If one exists, do not overwrite it. Back it up (`cp playwright.config.ts playwright.config.ts.bak`) and propose a merge (the `setup` project + `dependencies`, a `webServer` if local, `trace: 'on-first-retry'`, CI `retries`); show the diff and let the user accept.
   - If none exists, write the config from `e2e-setup-scaffolds.md`.

4. **Auth separation** (one login, reused via `storageState`): write `e2e/auth.setup.ts` from `e2e-setup-scaffolds.md`. Add `playwright/.auth/` to `.gitignore`; credentials come from `E2E_USER` / `E2E_PASS`, never hardcoded.

5. **E2E operating SSOT doc**: copy `${PLUGIN_ROOT}/assets/e2e-guidelines.template.md` to `e2e/AGENTS.md` (offer `.claude/e2e-guidelines.md` instead), separate from the repo-wide `AGENTS.md`. Walk the user through the `<...>` placeholders, at least the CUF list `e2e-author` uses.

6. **Network route-mock scaffold**: copy `${PLUGIN_ROOT}/assets/route-mock.scaffold.ts` to `e2e/` (e.g. `e2e/_route-mock.example.ts`) as a `page.route` + `route.fulfill` reference. On Next.js or another SSR/BFF stack (`next` in `package.json`), say prominently that `page.route` intercepts browser requests only; server-side fetches need an E2E-only env flag, a stubbed upstream or a seeded test DB, which the scaffold documents.

7. **Gated CI workflow**: copy `${PLUGIN_ROOT}/assets/playwright-ci.yml` to `.github/workflows/e2e.yml` and narrow its `paths:` filter to the app and test dirs (an `e2e` label force-runs it). It uploads `playwright-report/` + `test-results/` and posts a PR comment on failure via `gh pr comment`. Remind the user to set the `E2E_USER` / `E2E_PASS` secrets and the `E2E_BASE_URL` variable; validate with `actionlint` if available, otherwise say it is unvalidated.

8. **Report**: the runtime path (A or B/C), the `playwright-cli` mode, every file created or modified, whether `.mcp.json` was present, merged or written, the SSOT doc location, and the next step (`dev:e2e-author`). This skill does not write tests (`e2e-author`), repair failures (`e2e-debug`) or configure non-GitHub CI.
