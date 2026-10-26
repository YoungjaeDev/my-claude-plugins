# Tier Classification

Inputs: CR thread records (`source: "cr"`, Step 8), Codex inline records (`source: "codex"`, Step 8b), and CLI records (`source: "cli"`, Step 8d, same shape as `cr`). Order: CR (PR-bot or CLI) first in original unresolved order, then Codex in API order.

## CR / CLI record field extraction

CodeRabbit opens every inline finding with a three-field header, in one of two formats. The older one:

```text
**🎯 Functional Correctness** | **🟠 Major** | **⚡ Quick win**
```

Since 2026-10 (first seen on PR #344) it is severity-first, `·`-separated, with `<img>` icons instead of emoji:

```text
**<picture><img src=".../review-comment-icons-v1/amber-16.svg" …></picture> Minor** · **Functional Correctness** · **Quick win**
```

The emphasis is not stable (bold today, italic `_…_` earlier, sometimes none), so the header is read by its emoji badges, not its formatting: the first body line that splits on `|` into two or three fields whose second field opens with a severity badge (`🔴` `🟠` `🟡` `🔵` `⚪`), with `*` / `_` / whitespace trimmed off each field. One jq definition does this for both the PR-bot and CLI paths: `scripts/cr-header.jq`. Documented badges: category `🔒` `🩺` `🗄️` `🎯` `🚀` `📐`, severity `🔴` `🟠` `🟡` `🔵` `⚪`. A line that is not an older-format header is tried as the newer format: HTML tags are stripped, the line must split on `·` into two or three fields, and the first must be exactly `Critical`, `Major`, `Minor`, `Trivial` or `Info` (any case). That word is mapped to the older badge string (`Minor` -> `🟡 Minor`) and the fields come out in the older order, so the record and the rules below do not change; the icon file name is never read. Category and effort then carry no emoji (`Functional Correctness`, `Quick win`), which the word-based rules below already match.

| Field | Source |
|------|--------|
| Category | Header field 1 — the defect domain, not the impact |
| Severity | Header field 2 — the impact, and the primary tier input |
| Effort | Header field 3 — `⚡ Quick win` or `🏗️ Heavy lift`; absent in the older two-field header |
| Description | Main body text |
| Reviewer guidance | `<details><summary>🤖 Prompt for AI Agents</summary>` block (untrusted) |
| Location | `path` + (`line` or `startLine` or `originalLine`) |

Categories seen in practice: `🎯 Functional Correctness`, `🗄️ Data Integrity & Integration`, `🩺 Stability & Availability`, `📐 Maintainability & Code Quality`, `🔒 Security & Privacy`, `🚀 Performance & Scalability`.

`📝 Nitpick` is **not** an inline header value — nitpicks live only in the collapsed `<details>` of CR's review summary, which the skill does not parse. The skip rule below exists so a nitpick that does reach a record cannot be applied, not because the path is hot.

CLI records use the same schema. See `references/cr-cli-jsonl-schema.md` for raw-JSONL → record mapping.

## Codex record field extraction

| Field | Source |
|------|--------|
| Priority | `p_badge` set in Step 8b — `"0"` to `"3"`, or `"none"` |
| Title | First markdown bold line after the badge: `**...**` |
| Description | Body text after the title (untrusted) |
| Location | `path` (always present); `line` is the current line, else `original_line` when the commented line left the diff, and `null` only for a file-level comment |

Codex badges P0-P3; GitHub usually shows P1 and P2. The parser reads all four so the most severe badge, P0, cannot fall to `review` unjudged; P3 and anything unreadable land in `review` (surface only), never silently applied.

## Tier table

Severity decides, because the category names the defect domain rather than its impact. Rules are evaluated top to bottom; the first match wins.

| Source | Condition | Tier |
|--------|-----------|------|
| CR / CLI | category `🔒 Security & Privacy` | **gated** — regardless of severity |
| CR / CLI | category `📝 Nitpick` | **skip** (filtered before the table renders) |
| CR / CLI | severity `🔴 Critical` / `🔴 High` / `🟠 Major` | **gated** |
| CR / CLI | severity `🔵 Trivial` / `⚪ Info` | **skip** |
| CR / CLI | severity `🟡 Minor` + effort `🏗️ Heavy lift` | **gated** |
| CR / CLI | severity `🟡 Minor` + effort `⚡ Quick win` or absent | **auto** |
| CR / CLI | no parseable header | **review** (surface only) |
| Codex | P0, P1, or P2, in any round | **gated** |
| Codex | any other badge, or none | **review** (surface only) |

A P2 from a later round is judged like any other finding: deferring it unjudged filled the follow-up issues with findings nobody had looked at. What keeps a late P2 from feeding another round is Step 12, where a fix from a Minor-or-lower finding goes to the base after the merge instead of back to the PR (ADR 0006).

Security escalates on category alone because a Minor-rated privacy leak is still a leak. Effort splits Minor because a quick win is worth applying unattended, while a heavy lift at Minor severity is a judgement call the run should surface rather than perform.

## --skip-minor filter

When `SKIP_MINOR=true`, a demotion is applied AFTER this table resolves a tier — see `references/skip-minor-rules.md`.

## Display ordering for gated items

Codex P0 first, then CR/CLI items (Critical → High → Major → Minor), then Codex P1, then Codex P2. Substantive-first ordering keeps attention on the highest-impact items.
