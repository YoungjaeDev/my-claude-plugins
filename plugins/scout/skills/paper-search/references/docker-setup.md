# Paper Search Tools Setup

Install, configure, and verify the Paper Search MCP server (Docker image `mcp/paper-search`)
for academic paper discovery. This skill is the single source of truth for the setup and
recovery procedure across Claude Code, Codex, and skill-level installs — do not send the
caller to a separate command.

The server speaks JSON-RPC over stdio; Claude Code launches it via the plugin's `.mcp.json`.
Work through the steps in order and stop at the first one that fails.

## 1. Docker installation state

Missing Docker and installed-but-stopped Docker are different failures — check installation first.

```bash
docker --version
```

- **Command not found / non-zero exit** — Docker is not installed. Install it, then re-run:
  - macOS: `brew install --cask docker`
  - Linux: `curl -fsSL https://get.docker.com | sh`
  - Windows: `winget install Docker.DockerDesktop`
- **Prints a version** — Docker is installed; continue to the daemon check.

## 2. Docker daemon running

`docker --version` succeeds even when the daemon is down, so verify the daemon separately.

```bash
docker info
```

- **`Cannot connect to the Docker daemon` / connection error** — Docker is installed but not
  running. Start Docker Desktop (macOS/Windows) or `sudo systemctl start docker` (Linux) and
  wait for it to fully initialize before continuing.
- **Prints server info** — the daemon is up; continue.

## 3. Image state

```bash
docker image inspect mcp/paper-search >/dev/null 2>&1 && echo present || docker pull mcp/paper-search
```

- **`present`** — the image is already local. To refresh a stale image, run `docker pull mcp/paper-search`.
- **Pull succeeds** — image is now local; continue.
- **Pull fails** — distinguish the cause: a registry/DNS/proxy error is a network failure (retry
  once connectivity is restored), whereas `manifest unknown` / `not found` means the image name
  is wrong. This is a pull failure, not an empty search result.

## 4. Configure the MCP server (platform-specific mount)

The plugin ships `.mcp.json` with a Linux/macOS default mount:

```json
{
  "mcpServers": {
    "paper-search": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "-v", "/tmp/paper-search-downloads:/downloads", "-e", "SEMANTIC_SCHOLAR_API_KEY", "mcp/paper-search"]
    }
  }
}
```

Create the host downloads directory:

- **macOS / Linux:** `mkdir -p /tmp/paper-search-downloads`
- **Windows (PowerShell):** `mkdir -Force $HOME\paper-search-downloads`

**Windows users must edit the `.mcp.json` volume mount** — the host path format depends on the
Docker Desktop backend. Replace `<username>` with the actual Windows username:

- **WSL2 backend (default):** `"-v", "/mnt/c/Users/<username>/paper-search-downloads:/downloads"`
- **Hyper-V backend:** `"-v", "C:/Users/<username>/paper-search-downloads:/downloads"`

If a user's `.mcp.json` already defines other MCP servers, add the `paper-search` key alongside
them — do not overwrite the existing `mcpServers` object.

### Semantic Scholar API key (optional, secret-safe)

The mount passes the key **by name** (`-e SEMANTIC_SCHOLAR_API_KEY`), so Docker reads the value
from the environment at runtime and the secret never lands in `.mcp.json` or the repo. Keep it
that way — never inline the key value into a config file or a commit.

Read it at a silent prompt so the value never lands in your shell history (avoid `export KEY="literal"`, which does):

```bash
read -rsp "Semantic Scholar API key: " SEMANTIC_SCHOLAR_API_KEY; echo
export SEMANTIC_SCHOLAR_API_KEY
```

Get a free key at <https://www.semanticscholar.org/product/api>. When confirming the key is set,
check presence only and never echo the value:

```bash
[ -n "$SEMANTIC_SCHOLAR_API_KEY" ] && echo "SEMANTIC_SCHOLAR_API_KEY is set" || echo "not set"
```

## 5. Verify the JSON-RPC initialize handshake and tool discovery

Confirm the server initializes and exposes its tools before relying on it in Claude Code. Pipe a
minimal `initialize` -> `initialized` -> `tools/list` sequence into the container:

```bash
printf '%s\n%s\n%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"setup-check","version":"1.0.0"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | docker run -i --rm -v /tmp/paper-search-downloads:/downloads mcp/paper-search
```

The `-v` mount mirrors the real `.mcp.json` run (use your platform's mount path from step 4), so a
broken mount surfaces here instead of silently passing `tools/list` with the wrong host directory.

- **Expected** — an `initialize` result for `id:1` (with `serverInfo` and `capabilities`) followed
  by a `tools/list` result for `id:2` listing the search/download/read tools. That confirms both
  the initialize handshake and at least one tool-discovery call.
- **Hangs or prints a JSON-RPC `error`** — the server failed to initialize. Re-check the image
  (step 3) and the daemon (step 2); this is a server failure, not an empty search.

## 6. Connect the MCP server (per runtime)

The Docker image + the step 5 JSON-RPC verification contract are runtime-neutral. Only step 4's
registration and the connect/disable surface differ per runtime:

- **Claude Code** — the plugin's `.mcp.json` is the registration (step 4). Restart (`exit`, then
  `claude`) so it reloads `.mcp.json`, run `/mcp`, and confirm the `paper-search` server shows as
  connected. Tool names then carry the plugin prefix
  `mcp__plugin_paper-search-tools_paper-search__<tool>` (see the `paper-search` usage skill for the
  full tool catalog and the standalone-registration prefix variant).
- **Codex** — installed as a plugin, Codex reads the plugin's `.claude-plugin/plugin.json` natively,
  which already points `mcpServers` at the same `.mcp.json`, so the server is registered automatically —
  do **not** add a second manual entry. Just run the step 5 handshake to verify. Only a standalone
  (non-plugin) Codex needs a manual MCP entry with the step-4 `docker run` args.

## Troubleshooting — distinguish failure classes

A valid but empty result is not an error. Read the response before concluding setup is broken.

- **Empty search result** — a successful JSON-RPC response whose result list is empty means no
  papers matched the query. Broaden the terms or try another platform; do not re-run setup.
- **Rate limited** — Semantic Scholar returns HTTP 429 or a "rate limit" message under heavy use.
  Set `SEMANTIC_SCHOLAR_API_KEY` (step 4) to raise the quota.
- **API error** — a JSON-RPC `error` object or an upstream `4xx/5xx` in the tool result signals a
  backend problem (bad parameters, upstream outage), not a Docker problem.
- **Network failure** — pull/connection timeouts or DNS/proxy errors mean the host cannot reach
  the registry or the paper backend. Fix connectivity, then retry.
- **Docker not found** — install Docker (step 1).
- **Docker not running** — start the daemon (step 2).
- **Connection failed in `/mcp`** — restart Claude Code after Docker is running (step 6).

## Don't need Paper Search?

Disable the server to stop connection errors without uninstalling: on Claude Code via the `/mcp`
command; on Codex via that runtime's plugin or MCP-server management.
