# Bright Data: MCP and CLI usage

How scout reaches Bright Data for its one job, fetching a page that plain fetchers cannot read: the four-gate preflight, the 2 MCP tools scout calls (`scrape_as_markdown`, `scrape_batch`) and the CLI equivalent `bdata scrape`. Everything else (search, `web_data_*`, browser automation, pipelines, plans and quotas) is out of scope here; read the live docs at <https://docs.brightdata.com/ai/mcp-server/overview> (index: <https://docs.brightdata.com/llms.txt>) or `bdata --help` when a task needs it.

Tool names in this guide are generic: `terminal` is Bash on Claude Code and the shell tool on Codex, and the Bright Data MCP tool names are the same on both runtimes.

## Two ways in: MCP or CLI

- **MCP tools present** (`scrape_as_markdown` in your tool registry): call them directly.
- **MCP tools absent**: the common case is a delegated subagent, which inherits the parent's terminal and skills but not its MCP toolsets. Use the Bright Data CLI from the terminal (`bdata` / `brightdata`, reference in `brightdata-cli-commands.md`).
- **Neither**: run the preflight below and stop at the failing gate. Never fall back to the agent's built-in web fetch or search for a call Bright Data was meant to make.

## Preflight: four gates, in order, before the first Bright Data call

An unconfigured setup must stop and surface the setup step instead of quietly falling back to a built-in fetch. Gate 1 is a fork: when the MCP tools are present you are done (call them and skip gates 2-4, which check only the CLI path). Gates 2-4 run only when gate 1 finds no MCP tools, in order, stopping at the first that fails, so an MCP-only session with no CLI is never stopped at gate 2.

| # | Gate | How to check | If it fails |
| --- | --- | --- | --- |
| 1 | MCP tools present | Is `search_engine` or `scrape_as_markdown` in your tool registry? | Not fatal: this is the normal `delegate_task` subagent case. Fall through to gate 2 and use the CLI. |
| 2 | CLI installed | `command -v bdata \|\| command -v brightdata` | STOP. Report that neither the Bright Data MCP tools nor the `bdata` CLI is reachable and surface the install step from `brightdata-mcp-setup.md`. Do not install it yourself and do not run shell-piped installers. |
| 3 | Authenticated | `bdata zones`: a printed zone table means the credentials work | STOP. Ask the operator to run `bdata login` once (add `-d` for an SSH or headless machine) or to export `BRIGHTDATA_API_KEY`. Never pass a key on the command line. |
| 4 | Default zone set | `bdata config get default_zone_serp` and `bdata config get default_zone_unlocker` (exit status 1 means unset) | STOP. Run `bdata zones`, surface the zone names it prints, and ask the operator to run `brightdata config set default_zone_serp <zone>` plus `brightdata config set default_zone_unlocker <zone>` (or to export `BRIGHTDATA_SERP_ZONE` / `BRIGHTDATA_UNLOCKER_ZONE`). Do not edit their config yourself. |

- **Gate 3 reads output, not exit status**: `bdata budget` exits 0 even when the API answers `403 … lacks the required permissions`, so test `bdata zones` and treat an auth or permission message in its output as a failure whatever `$?` says.
- **Gate 4**: `bdata search` and `bdata scrape` fail with `No zone specified` until a default is set. Many accounts have no `serp`-type zone; an `unblocker` zone then serves both keys.
- **After a failed gate**: the task ends with the setup guidance. Skills that route a fetch through Bright Data cite this preflight rather than restating it.

## MCP tools scout uses

- **`scrape_as_markdown`**: one page as Markdown, through Bright Data's unlocker (bot protection, CAPTCHA, JS rendering). This is web-scout's tier-3 fetch and `generate-llmstxt`'s per-URL fetch.
- **`scrape_batch`**: several pages in one request, returned as URL/content pairs. Only `generate-llmstxt` uses it, and only when it is in the registry; otherwise it loops `scrape_as_markdown`.
- **A needed tool is missing**: do not edit the host's settings or MCP config yourself. Tell the operator which tool is missing and that the server's tool groups are set by the `groups` URL parameter (remote) or the `GROUPS` env var (local), per `brightdata-mcp-setup.md`, then continue with `scrape_as_markdown`.

## CLI (terminal)

- **Operator-only setup**: the operator installs `@brightdata/cli` once, out of band, or chooses the version-pinned `npx --yes --package @brightdata/cli@<version> brightdata <command>`. When `bdata` is not found, surface that and stop: never install it, run a shell-piped installer, or modify global packages.
- **Auth**: the operator runs `bdata login` once or exports `BRIGHTDATA_API_KEY`. Never pass an API key inside a command or prompt.
- **Fetch**: `bdata scrape <url> -f markdown` reads a page as Markdown (formats and flags in `brightdata-cli-commands.md`).

## Decision: MCP vs CLI

1. `scrape_as_markdown` in your tools → use the MCP.
2. Only `terminal`, no Bright Data tools → use the CLI.
3. `bdata` not installed, not logged in, or no default zone → the four-gate preflight above names the failing gate and its fix, and the task stops. Do not auto-install, hardcode keys, or fall back to a built-in fetch.
