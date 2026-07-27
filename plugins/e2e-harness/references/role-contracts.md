# Playwright Role Contracts (runtime-neutral)

Shared planner / generator / healer role contracts consumed by **all three execution paths** of `e2e-setup`, `e2e-author`, and `e2e-debug`:

- **Path A — Claude generated agents.** `e2e-setup` runs `npx playwright init-agents --loop=claude`, which writes `.claude/agents/playwright-test-{planner,generator,healer}.md`. Those generated agent definitions are the canonical detail; `e2e-author` / `e2e-debug` dispatch them by name (`Task(subagent_type="playwright-test-planner")` etc.). This file is not consulted on Path A.
- **Path B — generic subagents (Codex 0.135).** Codex exposes these skills but cannot register `.claude/agents/*.md` as named subagents, so it dispatches one **generic** subagent per role, carrying that role's contract from this file inline (`Task(prompt=...)`). This file is the portable condensation of the generated agents' behavior.
- **Path C — sequential in-agent.** When no delegation channel is available, the skill executes each role itself, one at a time, following the contract below.

> **Hermes takes Path B as well.** Its skills are installed with `npx skills` (`scripts/install-skills.mjs`), and like Codex it registers no `.claude/agents/*.md`, so the same generic dispatch applies — the tool is `delegate_task` under Hermes and `Task` under Codex (see the tool-name table at the end).

Keep these contracts in sync with the behavior of the init-agents-generated agents (verified on Playwright 1.61 — see `.llmwiki/wiki/e2e-harness-ops/playwright-ai-harness.md`) when either changes.

## Gates that hold on every path

The runtime branch only changes *how* a role is executed, never *which* gates apply. Path B and Path C enforce the identical gates Path A does:

- **CUF selection** — author only the critical user flows (a regression breaks revenue, data integrity, or user trust). Breadth is a cost; confirm 1-3 flows, never auto-pick everything.
- **User review gate between plan and generation** — the planner's Markdown plan is presented and explicitly approved before any spec code is generated. The plan is cheap to fix; generated specs are not.
- **Semantic locators** — generated specs use `getByRole(role, { name })` / `getByLabel` / `getByText`, never CSS/XPath. Send brittle selectors back to be fixed.
- **Burn-in flake gate** — every new/changed spec runs `npx playwright test e2e/<flow>.spec.ts --repeat-each=3`; a single failure across the repeats = flaky = blocked. (`--repeat-each` is an authoring-time gate, not a full-suite CI flag.)
- **Trace-first diagnosis** — a failure is diagnosed from its trace (headless `npx playwright trace` subcommands) before any patch, classifying it as real regression / selector drift / environment-data / genuine flake.
- **Bounded healer retries** — at most 3 heal attempts; do not loop indefinitely.
- **Skip-after-3 with reason** — if still red after 3 attempts, quarantine honestly (`test.skip` / `test.fixme`) with a comment stating the reason and a tracking link. Never leave the suite red or silently drop coverage.
- **Never auto-pass a real regression** — if the app behavior genuinely changed, surface it to the user; the test may be correctly failing.

## `.mcp.json` `playwright-test` entry — merge, never clobber

Both runtimes drive the browser through the `playwright-test` MCP server. On Path A, `init-agents --loop=claude` writes `.mcp.json` for you. On Path B/C (or any time `init-agents` did not generate it), create/merge the entry explicitly **without** overwriting unrelated servers or a conflicting `playwright-test` definition:

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

After writing/merging, tell the user to approve the MCP server (`/mcp` or restart) so the roles can drive the browser. A conflicting existing `playwright-test` definition is a review-gated merge proposal, never a silent replace.

## `--loop=codex` — feature-detect, never version-guess

Do **not** pass `--loop=codex` unless the installed Playwright explicitly advertises it. Feature-detect instead of guessing on the version number:

```bash
npx playwright init-agents --help 2>/dev/null | grep -qw codex && LOOP_CODEX_ADVERTISED=1 || LOOP_CODEX_ADVERTISED=0
```

Even when `--loop=codex` is advertised, Codex 0.135 cannot register the generated `.claude/agents/*.md` (or their codex-loop equivalents) as named subagents, so the reliable Codex path stays generic-subagent dispatch with the contracts below. `--loop=codex` is at most an optional scaffold for `.mcp.json` / `seed.spec.ts` / `specs/`; when it is not advertised, skip agent generation entirely and create `.mcp.json` with the merge recipe above.

## Role contracts

Each role drives the app through the approved `playwright-test` MCP server. A generic subagent (Path B) or the skill itself (Path C) must be handed the role's contract verbatim, because it lacks the native agent-definition context Path A relies on.

### planner
- **Role**: explore the live app for one CUF and write a Markdown test plan.
- **Inputs**: the CUF description + any PRD/notes; the E2E SSOT doc conventions.
- **Tool order**: run `seed.spec.ts` first to set up the environment → explore the app through the `playwright-test` MCP server → write `specs/<flow>.md`.
- **Output**: `specs/<flow>.md` — a human-readable plan, no code.
- **Gate**: stop here for the mandatory user review gate. Do not proceed to generation until the plan is approved; fold edits back into `specs/<flow>.md`.

### generator
- **Role**: turn an approved `specs/<flow>.md` into Playwright spec files.
- **Inputs**: the approved plan; the SSOT conventions (step-name language, file layout, fixtures).
- **Tool order**: read `specs/<flow>.md` → write specs under `e2e/` → verify every selector and assertion live against the running app as you go.
- **Output**: `e2e/<flow>.spec.ts` using semantic `getByRole` / `getByLabel` / `getByText` locators; no CSS/XPath, no arbitrary `waitForTimeout` (web-first assertions only). Split long flows into `test.step("...")` blocks.
- **Gate**: burn-in with `--repeat-each=3` before the spec is considered done; a single failing repeat blocks it.
- **Independence**: when flows share a long common prefix, set the branch start state via a test API rather than replaying the prefix through the UI (distinct from `storageState`, which is auth only).

### healer
- **Role**: diagnose a failing/flaky spec from its trace and patch it to green, or quarantine it.
- **Inputs**: the failing test name(s) + the trace findings (failing action, 4xx/5xx requests, console/errors).
- **Tool order**: replay the failing steps through the `playwright-test` MCP server → find equivalent current elements → patch the test → re-run until green, then burn-in with `--repeat-each=3`.
- **Output**: a patched `e2e/<flow>.spec.ts`, or a `test.skip`/`test.fixme` quarantine with a reason comment.
- **Gate**: bounded to 3 attempts; skip-after-3 with a stated reason and tracking link. Never auto-patch a suspected real regression to pass — surface it instead.

## Runtime tool names

These skills dispatch and read through whatever tools the host runtime exposes. Claude and Codex share tool names; Hermes maps as:

| Claude / Codex | Hermes | Used here for |
|---|---|---|
| `Task(subagent_type=...)` (Path A) / `Task(prompt=...)` (Path B) | `delegate_task` | dispatching planner / generator / healer |
| `Bash` | `terminal` | `npx playwright ...`, `jq`, `gh`, `find`, the `PLUGIN_ROOT` resolver |
| `Read` | `read_file` | reading this contract, `specs/<flow>.md`, existing specs |
| `Write` / `Edit` | `write_file` / `patch` | writing specs, `.mcp.json`, config |
| `AskUserQuestion` | `clarify` | CUF selection + the plan review gate |

## PLUGIN_ROOT

`e2e-author` / `e2e-debug` reach this file via the cross-runtime `PLUGIN_ROOT` resolver in their Step 0 (Claude `CLAUDE_PLUGIN_ROOT` → source-tree `plugins/e2e-harness` → Codex plugin cache → Hermes probes). Do not reference `${CLAUDE_PLUGIN_ROOT}` bare — Codex 0.135 does not export it, so the read fails at step one.
