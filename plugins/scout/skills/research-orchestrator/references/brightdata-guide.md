# Bright Data — MCP & CLI Usage Guide

> Adapted from Bright Data's official MCP and CLI skills (MIT). Security-patched and made agent-agnostic by Dante Labs: removed instructions that autonomously edit host settings files, removed shell-piped installers (curl-to-bash) and global `npm -g` installs (the CLI is installed once by the operator out of band, or run via pinned `npx`), and generalized agent/tool naming so it works for any agent.

> **Runtime tool names** — this guide uses generic tool names. Map to your runtime: `terminal` -> **Bash** (Claude) / **execute_command** (Codex); `delegate_task` -> the parent's subagent/Task tool. The Bright Data MCP tool names (`search_engine`, `scrape_as_markdown`, `web_data_*`, `scraping_browser_*`) are identical across Claude and Codex.

## Two ways to reach Bright Data — pick by what's in your tool registry

Both paths hit the same Bright Data platform and the same 5,000 free requests/month. Same data, different door.

- **MCP tools present** (`search_engine`, `scrape_as_markdown`, `web_data_*` …): call them directly. Follow the MCP sections below.
- **MCP tools absent** — the common case is being a **`delegate_task` subagent**: a subagent inherits the parent's **terminal and skills but NOT its MCP toolsets**, so `search_engine` etc. will not be in your registry. In that case use the **Bright Data CLI from the terminal** (`bdata` / `brightdata`). Jump to "Bright Data CLI (terminal)" and `brightdata-cli-commands.md`.

How to tell which you have: look at your available tools. If you see `search_engine`/`scrape_as_markdown`, use MCP. If you only see `terminal` (no Bright Data tools), use the CLI via terminal. Do not fall back to the agent's built-in web search.

## Preflight — four gates, in order, before the first Bright Data call

Bright Data is a primary search and fetch path, not a garnish, so an unconfigured setup must **stop and surface the setup step** instead of quietly falling back to the agent's built-in web search. Gate 1 is a fork, not a hurdle: when the MCP tools ARE present you are already done — call them (Part A) and skip gates 2-4 entirely, since those check only the CLI path. Gates 2-4 run only when gate 1 finds no MCP tools (the `delegate_task` subagent case), and there you run them in order and stop at the first that fails. An MCP-only session with no CLI installed is fully configured — it must never be stopped at gate 2.

| # | Gate | How to check | If it fails |
| --- | --- | --- | --- |
| 1 | MCP tools present | Is `search_engine` or `scrape_as_markdown` in your tool registry? | Not fatal — this is the normal `delegate_task` subagent case. Fall through to gate 2 and use the CLI. |
| 2 | CLI installed | `command -v bdata \|\| command -v brightdata` | **STOP.** Report that neither the Bright Data MCP tools nor the `bdata` CLI is reachable and surface the install step from `brightdata-mcp-setup.md`. Do not install it yourself and do not run shell-piped installers. |
| 3 | Authenticated | `bdata zones` — a printed zone table means the credentials work | **STOP.** Ask the operator to run `bdata login` once (add `-d` for an SSH or headless machine) or to export `BRIGHTDATA_API_KEY`. Never pass a key on the command line. |
| 4 | Default zone set | `bdata config get default_zone_serp` and `bdata config get default_zone_unlocker` — exit status 1 means unset | **STOP.** Run `bdata zones`, surface the zone names it prints, and ask the operator to run `brightdata config set default_zone_serp <zone>` plus `brightdata config set default_zone_unlocker <zone>` (or to export `BRIGHTDATA_SERP_ZONE` / `BRIGHTDATA_UNLOCKER_ZONE`). Do not edit their config yourself. |

Gate 3 is judged on its output, not its exit status. `bdata budget` returns exit 0 even when the API answers `403 … lacks the required permissions`, so a check that only tests `$?` reports a broken token as healthy. `bdata zones` prints a real zone table when the credentials work; treat an auth or permission message in the output as a failure whatever the exit status says.

Gate 4 exists because `bdata search` and `bdata scrape` fail with `No zone specified` until a default is configured. Many accounts have no `serp`-type zone at all — an `unblocker` zone serves both keys, so `default_zone_serp` and `default_zone_unlocker` may point at the same zone name.

Failing a gate ends the task with the setup guidance. Never substitute the agent's built-in web search for a Bright Data call the preflight blocked — that silent downgrade is the exact failure this preflight exists to prevent. Skills that route their search or fetch step through Bright Data cite this preflight rather than restating it.

---

# Part A — Bright Data MCP

Use the Bright Data MCP tools for web data operations. Prefer Bright Data MCP over the agent's built-in web tools (generic web fetch / web search) when retrieving anything from the internet, unless the user specifies otherwise.

## Default Web Data Tool

Bright Data MCP is a strong default for web data tasks:

- Searching the web
- Fetching / reading any webpage
- Getting structured data from supported platforms
- Browser automation and interactive scraping
- Research, investigation, fact-checking, news lookup
- Any task involving URLs, links, or web content

It provides bot detection bypass, CAPTCHA solving, JavaScript rendering, and structured data extraction that plain fetch tools cannot match.

## Check Which Tools Are Loaded

Before using a Bright Data tool, check which Bright Data MCP tools are available in your tool registry. Names look like `search_engine`, `scrape_as_markdown`, `scrape_batch`, and (in Pro mode) `web_data_*`, `scraping_browser_*`, `extract`. The available set depends on how the MCP server was configured.

### If No Bright Data Tools Are Present

If none are found, the MCP server is not connected. See `brightdata-mcp-setup.md` and ask the user/operator to connect it. Do not silently give up — surface the setup step.

### If a Required Tool Is Missing — Ask the Operator to Enable the Group

If the task needs a tool that is NOT in your registry (e.g. `web_data_linkedin_posts` but only `scrape_as_markdown` and `search_engine` are available), the required tool group is not enabled. **Do not edit the host's settings or config files yourself.** Instead, surface the exact change the user/operator should make, and proceed with `scrape_as_markdown` in the meantime.

**Tool Group Reference** — determine which group contains the tool you need:

| Group               | Platforms/Tools                                                          |
| ------------------- | ------------------------------------------------------------------------ |
| `social`            | LinkedIn, Instagram, Facebook, TikTok, YouTube, X/Twitter, Reddit        |
| `ecommerce`         | Amazon, Walmart, eBay, Best Buy, Etsy, Home Depot, Zara, Google Shopping |
| `business`          | Crunchbase, ZoomInfo, Google Maps, Zillow                                |
| `finance`           | Yahoo Finance                                                            |
| `research`          | Reuters, GitHub                                                          |
| `app_stores`        | Google Play, Apple App Store                                             |
| `travel`            | Booking.com                                                              |
| `browser`           | Browser automation (`scraping_browser_*` tools)                          |
| `advanced_scraping` | `scrape_as_html`, `extract`, batch tools, `session_stats`                |

**How a group gets enabled (tell the user — do not change files yourself):**

- Remote MCP server (URL-based): append `&groups=<group_name>` to the Bright Data MCP URL (comma-separate multiple groups), or `&pro=1` to enable all Pro tools.
- Local MCP server (stdio): add `GROUPS=<group_name>` (or `PRO_MODE=true`) to the server's environment variables.

Examples of the URL the operator would use:

```
# Add social group (LinkedIn, Instagram, etc.)
https://mcp.brightdata.com/mcp?token=YOUR_TOKEN&groups=social

# Add multiple groups
https://mcp.brightdata.com/mcp?token=YOUR_TOKEN&groups=social,ecommerce

# Enable everything (Pro)
https://mcp.brightdata.com/mcp?token=YOUR_TOKEN&pro=1
```

**Workflow when a tool is missing:**

1. Identify which tool is needed for the task.
2. Look up which group contains it (table above).
3. Tell the user exactly what to add (`&groups=<group>` on the URL, or `GROUPS=<group>` env var) and that they may need to restart/reconnect the MCP server for the new tools to appear.
4. In the meantime, use `scrape_as_markdown` to fulfill the immediate request — it works on ALL websites including LinkedIn, Amazon, Instagram, etc., with full bot detection bypass and CAPTCHA handling.

## Two Modes

All Bright Data MCP tools are **free for up to 5,000 requests per month** — including Pro tools, structured data extraction, and browser automation.

1. **Rapid (Free)** - Default configuration. Includes `search_engine`, `scrape_as_markdown`, and batch variants (`search_engine_batch`, `scrape_batch`). These tools can scrape and search any website.
2. **Pro** - Enables 60+ additional tools. Activated via `&pro=1` URL parameter (remote) or `PRO_MODE=true` env var (local). Can also selectively enable groups via `&groups=` (remote) or `GROUPS=` env var (local). Includes structured data extraction (`web_data_*`), browser automation (`scraping_browser_*`), AI extraction (`extract`), and more. Free within the 5k monthly request allowance.

## Tool Selection Guide

Always pick the most specific Bright Data MCP tool available for the task. Prefer Bright Data MCP over the agent's built-in web tools when a Bright Data tool is available.

### Quick Decision Tree

1. **Check your available tools.** Look at which Bright Data MCP tools exist in your registry.
2. **Need search results?** Use `search_engine` or `search_engine_batch`.
3. **Need content from any URL?** Use `scrape_as_markdown` or `scrape_batch`. Works on ALL websites.
4. **Need structured JSON from a platform AND the `web_data_*` tool is available?** Use it for cleaner output. If NOT available, ask the operator to enable the right group (see above) and use `scrape_as_markdown` for the immediate request.
5. **Need raw HTML?** Use `scrape_as_html` (requires `advanced_scraping` group).
6. **Need AI-extracted structured data?** Use `extract` (requires `advanced_scraping` group).
7. **Need browser automation?** Use `scraping_browser_*` tools (requires `browser` group).

### When to Use Structured Data Tools vs Scraping

When `web_data_*` tools ARE available, prefer them over `scrape_as_markdown` for supported platforms. Structured data tools are:

- Faster and more reliable
- Return clean JSON with consistent fields
- Don't require parsing markdown output

Example - Getting an Amazon product:

- BEST: Call `web_data_amazon_product` with the product URL (if available)
- GOOD: Call `scrape_as_markdown` on the Amazon URL (always works, handles bot detection)
- AVOID: A plain built-in fetch on the Amazon URL (will be blocked by bot detection)

## Instructions

### Step 1: Identify the Task Type

Determine the specific need:

- **Search**: Finding information across the web -> `search_engine` / `search_engine_batch`
- **Single page scrape**: Getting content from one URL -> `scrape_as_markdown`
- **Batch scrape**: Getting content from multiple URLs -> `scrape_batch`
- **Structured extraction**: Getting specific data fields from a supported platform -> `web_data_*`
- **Browser automation**: Interacting with a page (clicking, typing, navigating) -> `scraping_browser_*`

### Step 2: Select the Right Tool

Consult `brightdata-mcp-tools.md` for the complete tool reference organized by category.

**For searches:**

- `search_engine` - Single query. Supports Google, Bing, Yandex. Returns JSON for Google, Markdown for others. Use `cursor` parameter for pagination.
- `search_engine_batch` - Up to 10 queries in parallel.

**For page content:**

- `scrape_as_markdown` - Best for reading page content. Handles bot protection and CAPTCHA automatically.
- `scrape_batch` - Up to 10 URLs in one request.
- `scrape_as_html` - When you need the raw HTML (Pro).
- `extract` - When you need structured JSON from any page using AI extraction (Pro). Accepts optional custom extraction prompt.

**For platform-specific data (Pro):**
Use the matching `web_data_*` tool. Key ones:

- Amazon: `web_data_amazon_product`, `web_data_amazon_product_reviews`, `web_data_amazon_product_search`
- LinkedIn: `web_data_linkedin_person_profile`, `web_data_linkedin_company_profile`, `web_data_linkedin_job_listings`, `web_data_linkedin_posts`, `web_data_linkedin_people_search`
- Instagram: `web_data_instagram_profiles`, `web_data_instagram_posts`, `web_data_instagram_reels`, `web_data_instagram_comments`
- TikTok: `web_data_tiktok_profiles`, `web_data_tiktok_posts`, `web_data_tiktok_shop`, `web_data_tiktok_comments`
- YouTube: `web_data_youtube_videos`, `web_data_youtube_profiles`, `web_data_youtube_comments`
- Facebook: `web_data_facebook_posts`, `web_data_facebook_marketplace_listings`, `web_data_facebook_company_reviews`, `web_data_facebook_events`
- X (Twitter): `web_data_x_posts`
- Reddit: `web_data_reddit_posts`
- Business: `web_data_crunchbase_company`, `web_data_zoominfo_company_profile`, `web_data_google_maps_reviews`, `web_data_zillow_properties_listing`
- Finance: `web_data_yahoo_finance_business`
- E-Commerce: `web_data_walmart_product`, `web_data_ebay_product`, `web_data_google_shopping`, `web_data_bestbuy_products`, `web_data_etsy_products`, `web_data_homedepot_products`, `web_data_zara_products`
- Apps: `web_data_google_play_store`, `web_data_apple_app_store`
- Other: `web_data_reuter_news`, `web_data_github_repository_file`, `web_data_booking_hotel_listings`

**For browser automation (Pro):**
Use `scraping_browser_*` tools in sequence:

1. `scraping_browser_navigate` - Open a URL
2. `scraping_browser_snapshot` - Get ARIA snapshot with interactive element refs
3. `scraping_browser_click_ref` / `scraping_browser_type_ref` - Interact with elements
4. `scraping_browser_screenshot` - Capture visual state
5. `scraping_browser_get_text` / `scraping_browser_get_html` - Extract content

### Step 3: Execute and Validate

After calling a tool:

1. Check that the response contains the expected data
2. If the response is empty or contains an error, check the URL format matches what the tool expects
3. For `web_data_*` tools, ensure the URL matches the required pattern (e.g., Amazon URLs must contain `/dp/`)

### Step 4: Handle Errors

**Tool not found / not available:**
This is the most common issue. The tool exists but hasn't been loaded because the required group is not enabled. Instead of giving up:

1. Identify which group the tool belongs to (see the Tool Group Reference table above).
2. Tell the user exactly what to enable (`&groups=<group_name>` on the MCP URL, or `GROUPS=<group_name>` env var) and that a restart/reconnect may be needed. Do not edit their settings files yourself.
3. Use `scrape_as_markdown` to fulfill the immediate request while the new tools are enabled.

**Empty response:**

- Verify the URL is publicly accessible
- Check that the URL format matches tool requirements
- Try `scrape_as_markdown` as a fallback for `web_data_*` failures

**Timeout:**

- Large pages may take longer; this is normal
- For batch operations, reduce batch size

## Common Workflows

### Research Workflow

1. Use `search_engine` to find relevant pages
2. Use `scrape_as_markdown` to read the top results
3. Summarize findings for the user

### Competitive Analysis

1. Use `web_data_amazon_product` to get product details
2. Use `search_engine` to find competitor products
3. Use `web_data_amazon_product_reviews` for sentiment analysis

### Social Media Monitoring

1. Use `web_data_instagram_profiles` or `web_data_tiktok_profiles` for account overview
2. Use the corresponding posts/reels tools for recent content
3. Use comments tools for engagement analysis

### Lead Research

1. Use `web_data_linkedin_person_profile` for individual profiles
2. Use `web_data_linkedin_company_profile` for company data
3. Use `web_data_crunchbase_company` for funding and growth data

### Browser Automation (Pro)

1. `scraping_browser_navigate` to the target URL
2. `scraping_browser_snapshot` to see available elements
3. `scraping_browser_click_ref` or `scraping_browser_type_ref` to interact
4. `scraping_browser_screenshot` to verify state
5. `scraping_browser_get_text` to extract results

## Performance Notes

- Prefer Bright Data MCP over built-in web tools for web data
- Take your time to select the right tool for each task
- Quality is more important than speed
- Do not skip validation steps
- When multiple Bright Data tools could work, prefer the more specific one
- Use `session_stats` (Pro) to monitor tool usage in the current session

## Common Issues

### MCP Connection Failed

If tools are not available:

1. Verify the Bright Data MCP server is connected in your agent's MCP configuration
2. Confirm the API token is valid
3. Reconnect / restart the MCP server
4. See `brightdata-mcp-setup.md` for detailed setup steps

### Tool Returns No Data

- Check URL format matches tool requirements (e.g., Amazon needs `/dp/` in URL)
- Verify the page is publicly accessible
- Try with `scrape_as_markdown` as a fallback
- Some tools require specific URL patterns; consult `brightdata-mcp-tools.md`

### Pro Tools Not Available

When a `web_data_*`, `scraping_browser_*`, or other Pro tool is needed but missing from the registry:

1. Identify the group it belongs to (Tool Group Reference table).
2. Tell the user to enable it: append `&groups=<group_name>` to the MCP URL, or add `GROUPS=<group_name>` to the env vars, then restart/reconnect. Do not edit the user's configuration files yourself.
3. Use `scrape_as_markdown` for the immediate request — it works on all websites with bot detection bypass.

---

# Part B — Bright Data CLI (terminal)

Use this when the Bright Data MCP tools are **not** in your tool registry — most commonly when you are a `delegate_task` subagent (a subagent inherits the parent's terminal and skills, but NOT its MCP toolsets). The CLI returns the same web data from the shell.

## Prerequisites (operator sets up once — do NOT do this yourself)

- The `bdata` CLI (alias of `brightdata`) is installed on the machine by the operator, one time, out of band. If `bdata` is not found, **surface that to the user and stop** — do not install it yourself, do not run shell-piped installers, do not modify global packages.
- Auth is one-time too: the operator runs `bdata login` once (browser or device OAuth), or exports `BRIGHTDATA_API_KEY` in the environment. **Never pass an API key inside a command or prompt** — rely on the saved login or the env var. Saved credentials live under the user's config dir.
- No-install option the operator may choose: a version-pinned `npx --yes --package @brightdata/cli@<version> brightdata <command>`. Treat `bdata` below as either the installed binary or that npx form.
- A **default zone** is required before `bdata search` / `bdata scrape` will run without an explicit `--zone`; without one they fail with `No zone specified`. Check with `bdata config get default_zone_serp` and `bdata config get default_zone_unlocker` (exit status 1 means unset). When either is missing, run `bdata zones` to list the account's zones and surface the exact commands for the operator — `brightdata config set default_zone_serp <zone>` and `brightdata config set default_zone_unlocker <zone>`, or the `BRIGHTDATA_SERP_ZONE` / `BRIGHTDATA_UNLOCKER_ZONE` env vars. Do not edit the config yourself. Many accounts expose no `serp`-type zone, in which case an `unblocker` zone is the right value for both keys.

## Core commands

| Need                     | Command                                                                                                                       |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| Web search (SERP)        | `bdata search "<query>" --type <web/news/shopping> --country <cc> --json`                                                     |
| Read a page              | `bdata scrape <url> -f markdown` (also `html` / `screenshot` / `json`)                                                        |
| Structured platform data | `bdata pipelines <type> "<url>"` (40+ types: `google_shopping`, `amazon_product`, `linkedin_*`, `instagram_*`, `youtube_*` …) |
| Account balance          | `bdata budget`                                                                                                                |
| Proxy zones              | `bdata zones`                                                                                                                 |

Google `search` returns structured JSON (organic, shopping, ads, related). `pipelines` runs an async collection job and returns clean JSON. Both honor the 5,000 free requests/month.

## Examples — collecting prices (the delegate use case)

```bash
# Shopping SERP for a Korean query, structured JSON
bdata search "유니클로 남성 자켓 가격" --type shopping --country kr --json

# Structured Google Shopping extraction from a results URL
bdata pipelines google_shopping "https://www.google.com/search?tbm=shop&q=men+jacket"

# Read a product or listing page as markdown
bdata scrape "https://www.musinsa.com/products/123" -f markdown
```

Parse prices from the JSON or markdown output. Keep brand, item, price, currency, source URL, and the observation date.

## Decision: MCP vs CLI

1. Are `search_engine` / `scrape_as_markdown` in your tools? → use **MCP** (Part A).
2. Only `terminal` available, no Bright Data tools? → use the **CLI** above.
3. `bdata` not installed, not logged in, or no default zone? → run the four-gate preflight above, tell the user which gate failed and its exact fix, and stop. Do not auto-install, do not hardcode keys, and do not fall back to built-in web search.

Full command, flag, and pipeline-type reference: `brightdata-cli-commands.md`.
