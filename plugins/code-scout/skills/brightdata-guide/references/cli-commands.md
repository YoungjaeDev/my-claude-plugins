# Bright Data CLI — Command Reference (security-patched)

**Package:** `@brightdata/cli` · **Commands:** `brightdata` / `bdata` (shorthand) · **Requires:** Node.js >= 20

> Patched by Dante Labs: the official reference shipped shell-piped and global-install commands. Those are removed here. **The agent must not install the CLI.** Installation and login are one-time operator tasks done out of band.

## Setup (operator, one-time — not the agent)

- The operator installs the `@brightdata/cli` package (pin a specific version) on the machine, or the operator chooses the no-install path: `npx --yes --package @brightdata/cli@<version> brightdata <command>`.
- The operator authenticates once with `bdata login` (browser or `--device` for headless), or exports `BRIGHTDATA_API_KEY` in the environment. Credentials are saved under the user's config directory.
- The agent assumes `bdata` is on PATH and already authenticated. If it is not, surface that to the user and stop — do not install or hardcode keys.

## Global options

| Flag                  | Description                                                                                     |
| --------------------- | ----------------------------------------------------------------------------------------------- |
| `-k, --api-key <key>` | Override API key for one request (avoid in shared/subagent contexts; prefer saved login or env) |
| `--timing`            | Show request timing                                                                             |
| `-v, --version`       | Show CLI version                                                                                |

## `bdata login` / `bdata logout`

Authenticate (one-time, operator). Browser OAuth by default.

| Flag                     | Description                               |
| ------------------------ | ----------------------------------------- |
| `-d, --device`           | Device flow for SSH/headless environments |
| `-c, --customer-id <id>` | Account ID (optional)                     |

```bash
bdata login            # browser OAuth (operator)
bdata login --device   # headless/SSH (operator)
bdata logout           # clear stored credentials
```

On login the CLI validates the key, saves credentials, and auto-creates required zones (`cli_unlocker`, `cli_browser`).

## `bdata scrape <url>` — Web Unlocker

Fetch any URL (handles CAPTCHA, JS rendering, anti-bot).

| Flag                  | Description                                        |
| --------------------- | -------------------------------------------------- |
| `-f, --format <fmt>`  | `markdown` (default), `html`, `screenshot`, `json` |
| `--country <code>`    | Geo-target (e.g. `kr`, `us`, `jp`)                 |
| `--zone <name>`       | Web Unlocker zone                                  |
| `--mobile`            | Mobile user agent                                  |
| `--async`             | Submit async, return snapshot ID                   |
| `-o, --output <path>` | Write to file                                      |

```bash
bdata scrape https://example.com
bdata scrape https://www.musinsa.com/products/123 -f markdown
bdata scrape https://shop.example.com -f json --country kr -o out.json
```

## `bdata search <query>` — SERP

Search Google/Bing/Yandex. Google returns structured JSON (organic, ads, People Also Ask, related).

| Flag                  | Description                                   |
| --------------------- | --------------------------------------------- |
| `--engine <name>`     | `google` (default), `bing`, `yandex`          |
| `--country <code>`    | Localized results (e.g. `kr`)                 |
| `--language <code>`   | Language (e.g. `ko`, `en`)                    |
| `--type <type>`       | `web` (default), `news`, `images`, `shopping` |
| `--page <n>`          | Page, 0-indexed                               |
| `--json` / `--pretty` | JSON output                                   |
| `-o, --output <path>` | Write to file                                 |

```bash
bdata search "유니클로 남성 자켓 가격" --type shopping --country kr --json
bdata search "men jacket price" --type shopping --country kr --json --pretty
bdata search "open source scraping" --json | jq -r '.organic[].link'
```

## `bdata pipelines <type> [params...]` — structured extraction (40+ platforms)

Triggers an async collection job, polls, returns structured results.

| Flag                  | Description                                |
| --------------------- | ------------------------------------------ |
| `--format <fmt>`      | `json` (default), `csv`, `ndjson`, `jsonl` |
| `--timeout <seconds>` | Poll timeout (default 600)                 |
| `--json` / `--pretty` | JSON output                                |
| `-o, --output <path>` | Write to file                              |

```bash
bdata pipelines list                                   # all types
bdata pipelines google_shopping "https://www.google.com/search?tbm=shop&q=men+jacket"
bdata pipelines amazon_product "https://www.amazon.com/dp/B09V3KXJPB" --format csv -o p.csv
bdata pipelines amazon_product_search "laptop" "https://www.amazon.com"
```

### Common pipeline types

| Group        | Types                                                                                                                                                                                                                                                        |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| E-commerce   | `google_shopping`, `amazon_product`, `amazon_product_reviews`, `amazon_product_search` (`<keyword> <domain>`), `walmart_product`, `ebay_product`, `bestbuy_products`, `etsy_products`, `homedepot_products`, `zara_products`                                 |
| Professional | `linkedin_person_profile`, `linkedin_company_profile`, `linkedin_job_listings`, `linkedin_posts`, `linkedin_people_search` (`<url> <first> <last>`), `crunchbase_company`, `zoominfo_company_profile`                                                        |
| Social       | `instagram_profiles`/`_posts`/`_reels`/`_comments`, `facebook_posts`/`_marketplace_listings`/`_company_reviews`/`_events`, `tiktok_profiles`/`_posts`/`_shop`/`_comments`, `x_posts`, `youtube_profiles`/`_videos`/`_comments` (`<url> [n]`), `reddit_posts` |

Most types take just `<url>`; the exceptions are noted in parentheses. Run `bdata pipelines list` for the live, complete set.

## `bdata status <job-id>` / `zones` / `budget` / `config`

```bash
bdata status s_abc123 --wait --pretty   # poll an async job
bdata zones                             # list proxy zones
bdata budget                            # account balance (free tier: 5,000 req/month)
bdata config get default_zone_unlocker  # view/set CLI config
```

> Free tier: ~5,000 credits/month shared across Unlocker/SERP/Web Scraper, reset on the 1st, no rollover. A near-zero balance on a free account is expected, not an error.

## Output parsing (for price collection)

`search --type shopping --json` and `pipelines google_shopping` return JSON with product titles and prices. `scrape -f markdown` returns readable text. Extract: brand, item, price (number), currency, source URL, observation date — one row per item, drop rows with no verifiable price.
