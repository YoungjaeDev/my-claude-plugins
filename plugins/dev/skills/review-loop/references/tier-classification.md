# Tier Classification

How Step 9a gives each finding one of 4 tiers (`gated`, `auto`, `skip`, `review`) from CodeRabbit's header or the Codex badge. Inputs are CodeRabbit thread records (`source: "cr"`, Step 8), Codex inline records (`source: "codex"`, Step 8b) and CLI records (`source: "cli"`, Step 8d, the `cr` shape), CodeRabbit first in unresolved order, then Codex in API order.

## CR / CLI record field extraction

CodeRabbit opens every inline finding with a three-field header, in one of two formats. The older one:

```text
**🎯 Functional Correctness** | **🟠 Major** | **⚡ Quick win**
```

Since 2026-10 it is severity-first, `·`-separated, with `<img>` icons instead of emoji:

```text
**<picture><img src=".../review-comment-icons-v1/amber-16.svg" …></picture> Minor** · **Functional Correctness** · **Quick win**
```

- **Older format**: the emphasis is not stable (bold, italic `_…_`, or none), so it is read by emoji badge. The header is the first body line that splits on `|` into two or three fields whose second field opens with a severity badge (`🔴` `🟠` `🟡` `🔵` `⚪`), each field trimmed of `*`, `_` and whitespace.
- **Badges**: category `🔒` `🩺` `🗄️` `🎯` `🚀` `📐`, severity `🔴` `🟠` `🟡` `🔵` `⚪`. One jq definition reads both formats for the PR-bot and CLI paths: `scripts/cr-header.jq`.
- **Newer format**: a line that is not an older header has its HTML tags stripped, must split on `·` into two or three fields, and its first must be exactly `Critical`, `Major`, `Minor`, `Trivial` or `Info` (any case). The icon file name is never read.
- That word maps to the older badge string (`Minor` -> `🟡 Minor`) and the fields come out in the older order, so the record and the rules below do not change. Category and effort then carry no emoji (`Functional Correctness`, `Quick win`), which the word-based rules already match.

| Field | Source |
|------|--------|
| Category | Header field 1 — the defect domain, not the impact |
| Severity | Header field 2 — the impact, and the primary tier input |
| Effort | Header field 3 — `⚡ Quick win` or `🏗️ Heavy lift`; absent in the older two-field header |
| Description | Main body text |
| Reviewer guidance | `<details><summary>🤖 Prompt for AI Agents</summary>` block (untrusted) |
| Location | `path` + (`line` or `startLine` or `originalLine`) |

Categories seen in practice: `🎯 Functional Correctness`, `🗄️ Data Integrity & Integration`, `🩺 Stability & Availability`, `📐 Maintainability & Code Quality`, `🔒 Security & Privacy`, `🚀 Performance & Scalability`.

`📝 Nitpick` is not an inline header value: nitpicks live only in the collapsed `<details>` of the review summary, which the skill does not parse. The skip rule below keeps one that does reach a record from being applied.

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
| CR / CLI | category `🔒 Security & Privacy` | gated — regardless of severity |
| CR / CLI | category `📝 Nitpick` | skip (filtered before the table renders) |
| CR / CLI | severity `🔴 Critical` / `🔴 High` / `🟠 Major` | gated |
| CR / CLI | severity `🔵 Trivial` / `⚪ Info` | skip |
| CR / CLI | severity `🟡 Minor` + effort `🏗️ Heavy lift` | gated |
| CR / CLI | severity `🟡 Minor` + effort `⚡ Quick win` or absent | auto |
| CR / CLI | no parseable header | review (surface only) |
| Codex | P0, P1, or P2, in any round | gated |
| Codex | any other badge, or none | review (surface only) |

A P2 from a later round is judged like any other finding. Step 12 is what keeps it from feeding another round: a fix from a Minor-or-lower finding goes to the base after the merge instead of back to the PR.

Security escalates on category alone, because a Minor-rated privacy leak is still a leak, and effort splits Minor because a heavy lift is a judgement call to surface rather than perform unattended. With `SKIP_MINOR=true` the demotion in `references/skip-minor-rules.md` runs after this table, and Step 9c takes gated items in the order Codex P0, CR/CLI Critical, High, Major, Minor, Codex P1, Codex P2.
