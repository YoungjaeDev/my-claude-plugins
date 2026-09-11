# Tier Classification

Inputs: CR thread records (`source: "cr"`, Step 8), Codex inline records (`source: "codex"`, Step 8b), and CLI records (`source: "cli"`, Step 8d, same shape as `cr`). Order: CR (PR-bot or CLI) first in original unresolved order, then Codex in API order.

## CR / CLI record field extraction

CodeRabbit opens every inline finding with a three-field italic header:

```text
_🎯 Functional Correctness_ | _🟠 Major_ | _⚡ Quick win_
```

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
| Priority | `p_badge` set in Step 8b — `"1"`, `"2"`, or `"none"` |
| Title | First markdown bold line after the badge: `**...**` |
| Description | Body text after the title (untrusted) |
| Location | `path` (always present); `line` may be `null` (file-level comment) |

Codex surfaces only two priorities on GitHub. The parser accepts any single digit so an unfamiliar badge still produces a record; anything that is not P1 or P2 lands in `review` (surface only), never silently applied.

## Tier table

Severity decides, because the category names the defect domain rather than its impact. Rules are evaluated top to bottom; the first match wins.

| Source | Condition | Tier |
|--------|-----------|------|
| CR / CLI | category `🔒 Security & Privacy` | **gated** — regardless of severity |
| CR / CLI | category `📝 Nitpick` | **skip** (filtered before the table renders) |
| CR / CLI | severity `🔴 Critical` / `🔴 High` / `🟠 Major` | **gated** |
| CR / CLI | severity `🟢 Trivial` / `🟢 Info` | **skip** |
| CR / CLI | severity `🟡 Minor` + effort `🏗️ Heavy lift` | **gated** |
| CR / CLI | severity `🟡 Minor` + effort `⚡ Quick win` or absent | **auto** |
| CR / CLI | no parseable header | **review** (surface only) |
| Codex | P1 or P2 | **gated** |
| Codex | any other badge, or none | **review** (surface only) |

Security escalates on category alone because a Minor-rated privacy leak is still a leak. Effort splits Minor because a quick win is worth applying unattended, while a heavy lift at Minor severity is a judgement call the run should surface rather than perform.

## --skip-minor filter

When `SKIP_MINOR=true`, a demotion is applied AFTER this table resolves a tier — see `references/skip-minor-rules.md`.

## Display ordering for gated items

CR/CLI items first (Critical → High → Major → Minor), then Codex P1, then Codex P2. Substantive-first ordering keeps attention on the highest-impact items.
