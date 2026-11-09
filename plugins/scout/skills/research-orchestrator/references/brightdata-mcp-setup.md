# Bright Data MCP server setup

The values an operator needs to connect the Bright Data MCP server, remote or local, so that gate 1 of the `brightdata-guide.md` preflight passes. The agent surfaces these steps and never edits the host's settings files; current plans, tool groups and parameters are in the live docs at <https://docs.brightdata.com/ai/mcp-server/overview>.

## Prerequisites and remote server

- **Account and token**: a Bright Data account (<https://brightdata.com>) and an API token from the dashboard (<https://brightdata.com/cp>).
- **Remote server** (no local install): register `https://mcp.brightdata.com/mcp?token=<YOUR_BRIGHTDATA_API_TOKEN>` as a remote (HTTP) MCP server in the agent's own MCP configuration.
- **Optional URL parameters**: `groups=<name,...>` limits or extends the tool groups and `tools=<name,...>` picks single tools; the live docs list the current group names.
- **Check**: the client reports the server as connected and `scrape_as_markdown` appears in the tool list.

## Local server (stdio)

Run it on demand through `npx`, with no global install:

```bash
API_TOKEN=your_token npx @brightdata/mcp
```

| Variable    | Required | Description                       |
| ----------- | -------- | ---------------------------------- |
| `API_TOKEN` | Yes      | Your Bright Data API token        |
| `GROUPS`    | No       | Comma-separated group names       |

Register a stdio MCP server whose command is `npx` with args `@brightdata/mcp`, passing these as environment variables (`npm_config_yes=true` auto-approves the package fetch).

## When the connection fails

- Check that the API token is valid and not expired.
- Check the MCP URL format and network access to `mcp.brightdata.com`.
- Reconnect the server in the agent's configuration, then rerun the preflight.
