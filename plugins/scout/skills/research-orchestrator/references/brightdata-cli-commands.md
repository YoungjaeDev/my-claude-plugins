# Bright Data CLI: the commands scout uses

The `@brightdata/cli` commands behind scout's terminal path: `bdata scrape` for fetching, plus the `login`, `zones`, `config` and `budget` checks the `brightdata-guide.md` preflight runs. The package installs `brightdata` and the `bdata` shorthand and needs Node.js >= 20; for `search`, `pipelines` and every other command, run `bdata --help` or read <https://docs.brightdata.com/llms.txt>.

## Setup (operator, one-time, not the agent)

- **Install**: the operator installs `@brightdata/cli` (pinned version) or chooses `npx --yes --package @brightdata/cli@<version> brightdata <command>`. The agent never installs the CLI.
- **Auth**: the operator runs `bdata login` (browser OAuth, or `-d` / `--device` for SSH and headless machines) or exports `BRIGHTDATA_API_KEY`. Login validates the key, saves credentials under the user's config directory and creates the `cli_unlocker` and `cli_browser` zones.
- **Missing or unauthenticated**: surface it to the user and stop; do not install or hardcode keys. Avoid the `-k, --api-key <key>` override in shared or subagent contexts.

## `bdata scrape <url>`: Web Unlocker

Fetch any URL (handles CAPTCHA, JS rendering, anti-bot).

| Flag                  | Description                                        |
| ---------------------- | ---------------------------------------------------|
| `-f, --format <fmt>`  | `markdown` (default), `html`, `screenshot`, `json` |
| `--country <code>`    | Geo-target (e.g. `kr`, `us`, `jp`)                 |
| `--zone <name>`       | Web Unlocker zone                                  |
| `--mobile`            | Mobile user agent                                  |
| `--async`             | Submit async, return snapshot ID                   |
| `-o, --output <path>` | Write to file                                      |

```bash
bdata scrape https://example.com
bdata scrape https://docs.example.com/guide -f markdown -o guide.md
```

## Account and config checks

```bash
bdata zones                             # list proxy zones (preflight gate 3)
bdata config get default_zone_unlocker  # exit 1 means unset (preflight gate 4)
bdata budget                            # account balance; exits 0 even on a 403, so not an auth check
bdata logout                            # clear stored credentials
```
