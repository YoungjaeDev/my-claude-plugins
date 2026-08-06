# Bright Data MCP Server Setup

> Agent-agnostic setup. Works for Hermes, Codex, and any MCP-capable client. Configure the MCP server through your agent's own MCP configuration UI/CLI — this guide describes the values to use, it does not edit your settings files for you.

## Prerequisites

1. A Bright Data account - sign up at [brightdata.com](https://brightdata.com)
2. An API token from the [Bright Data Dashboard](https://brightdata.com/cp)

## Remote MCP Server (Recommended)

The remote MCP server requires no local installation. Connect directly via URL.

### Base URL

```
https://mcp.brightdata.com/mcp?token=<YOUR_BRIGHTDATA_API_TOKEN>
```

### Optional Parameters

| Parameter | Values        | Description                                                          |
| --------- | ------------- | -------------------------------------------------------------------- |
| `pro`     | `1`           | Enable all 60+ Pro tools (browser automation, structured extraction) |
| `groups`  | Group name(s) | Enable specific tool groups without full Pro mode                    |
| `tools`   | Tool name(s)  | Enable only specific individual tools                                |

### URL Examples

**Rapid (Free) mode** - search and scrape only:

```
https://mcp.brightdata.com/mcp?token=YOUR_TOKEN
```

**Full Pro mode** - all 60+ tools:

```
https://mcp.brightdata.com/mcp?token=YOUR_TOKEN&pro=1
```

**Specific groups** - e.g., social media + e-commerce:

```
https://mcp.brightdata.com/mcp?token=YOUR_TOKEN&groups=social,ecommerce
```

**Specific tools** - e.g., only Amazon product and search:

```
https://mcp.brightdata.com/mcp?token=YOUR_TOKEN&tools=web_data_amazon_product,search_engine
```

### Connecting (any MCP client)

Add the URL above as a remote (HTTP) MCP server in your agent's MCP configuration. Each agent has its own way to register an MCP server:

- **Hermes**: `hermes mcp add brightdata --url "https://mcp.brightdata.com/mcp?token=YOUR_TOKEN"` (or add it through the Hermes dashboard MCP tab). The connection is stored in the active profile's `config.yaml` under `mcp_servers`.
- **Generic MCP client**: register a server entry with the `url` field pointing at the URL above.

Verify the connection reports a healthy/connected status and that the Bright Data tools appear in the tool list.

## Local MCP Server (stdio)

For users who prefer running the MCP server locally via `npx` (no global install needed).

### Run via npx

```bash
API_TOKEN=your_token PRO_MODE=true npx @brightdata/mcp
```

> Uses `npx` so the package is fetched on demand — no global (`-g`) install required.

### Environment Variables

| Variable    | Required | Description                       |
| ----------- | -------- | --------------------------------- |
| `API_TOKEN` | Yes      | Your Bright Data API token        |
| `PRO_MODE`  | No       | Set to `true` to enable Pro tools |
| `GROUPS`    | No       | Comma-separated group names       |

### Connecting (any MCP client)

Register a stdio MCP server whose command is `npx` with args `@brightdata/mcp`, passing the variables above as environment variables. Example for Hermes:

```bash
hermes mcp add brightdata --command npx --args @brightdata/mcp \
  --env API_TOKEN=your_token WEB_UNLOCKER_ZONE=your_zone npm_config_yes=true
```

(The credential variable is named `API_TOKEN`. `npm_config_yes=true` auto-approves the npx package fetch.)

## Choosing Your Mode

All modes are **free for up to 5,000 requests per month** — including Pro tools.

### Rapid (Free) - Default

- `search_engine` and `scrape_as_markdown` available (plus batch variants)
- Best for: everyday browsing, reading web pages, search queries

### Pro Mode (`pro=1` / `PRO_MODE=true`)

- All 60+ tools enabled
- Structured data from Amazon, LinkedIn, Instagram, TikTok, YouTube, etc.
- Browser automation tools
- Best for: data extraction, social media analysis, e-commerce monitoring, automation

### Groups (Selective Pro)

Enable only the tool groups you need:

- `ecommerce` - Amazon, Walmart, eBay, Best Buy, etc.
- `social` - LinkedIn, Instagram, Facebook, TikTok, YouTube, X, Reddit
- `business` - Crunchbase, ZoomInfo, Google Maps, Zillow
- `finance` - Yahoo Finance
- `research` - Reuters, GitHub
- `app_stores` - Google Play, Apple App Store
- `travel` - Booking.com
- `browser` - Full browser automation
- `advanced_scraping` - HTML scraping, AI extraction, batch operations

## Verifying Your Setup

After connecting, test with a simple tool call:

1. Ask your agent: "Use the Bright Data MCP to search for 'test query'"
2. This should call `search_engine` and return results
3. If it works, your MCP connection is active

If it fails:

- Check your API token is valid and not expired
- Verify the MCP URL is correctly formatted
- Check network connectivity to mcp.brightdata.com
- Reconnect the MCP server in your agent's configuration

## Documentation

Full documentation index: https://docs.brightdata.com/llms.txt
