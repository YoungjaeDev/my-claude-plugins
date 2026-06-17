---
id: playwright-ai-harness
aliases: [playwright-init-agents, playwright-test-agents, e2e-harness-facts, playwright-trace-cli]
last_verified: 2026-06-17
status: active
volatility: volatile
sources: 2
---

# Playwright AI test-harness — verified facts (1.61)

Ground truth for the `e2e-harness` plugin, which wraps Playwright's official planner/generator/healer agents. Secondary sources (blogs, even the official docs directory tree) are stale on the specifics — these were confirmed by **direct execution on Playwright 1.61.0**. Treat as version-pinned: Playwright's docs say agent definitions "should be regenerated whenever Playwright is updated."

## `npx playwright init-agents --loop=claude` actual output

Generated at the project root (1.61), NOT what blogs/docs claim:

- `.claude/agents/playwright-test-planner.md`, `playwright-test-generator.md`, `playwright-test-healer.md` — **filenames are `playwright-test-`-prefixed**, not bare `planner.md`/etc.
- `.mcp.json` — **IS generated** (the recurring uncertainty — confirmed yes). Server is `playwright run-test-mcp-server` (test-specific, distinct from the general `@playwright/mcp` browser server): `{"mcpServers":{"playwright-test":{"command":"npx","args":["playwright","run-test-mcp-server"]}}}`. The agents drive the browser through it — if their tool calls fail, the MCP server is unapproved.
- `seed.spec.ts` at the **repo root** (not `tests/seed.spec.ts` as the docs tree shows) + `specs/README.md` (test-plan dir).
- **Does NOT generate `playwright.config.*`** — setup must create/merge that separately.
- `--loop` values: `vscode | claude | codex | opencode`. **There is no `copilot` value.** Feature introduced in 1.56.

Agent roles: planner explores the app + writes a Markdown plan under `specs/`; generator turns the plan into spec files with live selector verification; healer replays failing tests, finds equivalent current elements, patches, re-runs, and marks `skip` if it cannot heal.

## Headless trace CLI (1.59+)

`npx playwright trace <sub>` inspects a trace from the terminal (agent-friendly, no GUI) — distinct from the GUI `npx playwright show-trace <trace.zip>`. Confirmed subcommands on 1.61: `open` / `close` / `actions` / `action <id>` / `requests` / `request <id>` / `console` / `errors` / `snapshot` / `screenshot` / `attachments` / `install-skill`. `open` extracts + starts a stateful session; later subcommands operate on the open trace.

## Burn-in vs CI flake tolerance

- `--repeat-each=N` runs every test N times unconditionally — an **authoring-time** burn-in gate for new/changed specs (a single failure = flaky = blocked). It is NOT a full-suite CI flag: putting `--repeat-each=3` on the whole CI run triples cost for no benefit. CI uses `retries` for flake tolerance (fail-then-pass = reported "flaky").

## GitHub Actions gotchas (e2e CI template)

- **Native `paths:` filter is incompatible with the `labeled` event.** A `pull_request: types: [..., labeled] paths: [...]` config will NOT trigger on a label-only PR (no path change), so a job-level `contains(labels, 'e2e')` force-run never runs. Use `paths:` for change-gating OR drop it and detect changes at the job level with `dorny/paths-filter` — do not combine the two for label override.
- **`gh pr comment` needs `issues: write`** token scope (PR comments are issue comments under the hood); add a workflow `permissions:` block or the failure-path comment silently fails.
- **No official PR-comment CI step exists** in Playwright's docs — the canonical workflow only uploads the HTML report artifact. Result-posting is custom (`gh pr comment` / `actions/github-script`).
- `getByText` is a legitimate user-facing locator (allowed alongside `getByRole`/`getByLabel`); a reviewer demand to force `getByRole('listitem', {name})` can be wrong — a listitem's accessible name is not its text content.

> See-also: [[cr-cli-false-positive-generated-files]] — the same skip-with-proof discipline applies when CR flags a generated manifest as hand-edited.

## Sources

1. playwright.dev — test-agents, trace-viewer, ci-intro, auth, mock, locators, test-cli docs + microsoft/playwright v1.56/v1.59 release notes.
2. Direct execution of `npx playwright@latest init-agents --loop=claude` and `npx playwright trace --help` on Playwright 1.61.0 (2026-06-17). Where execution contradicted secondary sources, execution is authoritative.
