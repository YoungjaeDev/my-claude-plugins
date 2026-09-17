---
id: bot-identity-matching
aliases: [bot-login-spoofing, reviewer-login-matcher, bot-stem-matching]
last_verified: 2026-09-17
status: active
volatility: stable
sources: 2
---

# Matching a bot by name has two failure modes, and fixing one opens the other

A review bot's login is reported with two spellings. GitHub's GraphQL surface strips the `[bot]` suffix; REST keeps it. The same account is `coderabbitai` in one response and `coderabbitai[bot]` in the next. An equality filter therefore matches on one surface and returns zero rows on the other.

Zero rows is the dangerous shape. It is indistinguishable from "the bot has not reviewed yet", so the consumer either waits forever or declares the work converged — a *silent* zero, never an error.

The obvious repair is to stop pinning the exact string and match a stem instead: `test("coderabbit"; "i")`. That covers both spellings and opens a second hole. `test()` without anchors is a substring match, and GitHub logins accept alphanumerics and hyphens up to 39 characters, so `coderabbit-evil` and `chatgpt-codex-connector-evil` are both registrable. Anyone can review or comment on a public pull request. A loop that reads reviewer bodies and edits code from them now has an input any outsider can author.

## The shape that holds

Anchor both ends and make the suffix optional: `test("^coderabbitai(\\[bot\\])?$"; "i")`.

- **Both ends, not one.** A prefix anchor alone (`^coderabbitai`) still matches `coderabbitai-evil`. The first proposal a reviewer offers is usually the prefix; it is not the fix.
- **The optional suffix is safe to pin** because `[` and `]` are not legal login characters. No registrable account can produce the `[bot]` form, so admitting it costs nothing and covers the second surface.
- **jq needs the escape doubled.** Inside a jq string, `"\\[bot\\]"` is what reaches the regex engine as `\[bot\]`. One backslash makes `[bot]` a character class, which matches quietly and wrongly.
- **Selecting the newest row makes a spoof a wrong success, not a failure.** A consumer doing `sort_by(.submitted_at) | last` hands back the forged row whenever it is more recent. Nothing errors; the loop proceeds on attacker text.

## Anchoring reintroduces the silent zero

Pinning the full login means the filter returns zero the day the bot renames its account — the exact failure the stem match was introduced to fix. There is no matcher that avoids both. The resolution is not a cleverer regex: it is a regression test per consumer, asserting both spellings match and a lookalike does not. Spoofing is an attacker acting today; a rename is a vendor acting once, loudly, and the test is what makes it loud instead of silent.

## Evidence

Fourteen matchers across one skill. Six had been moved from equality to a stem in the same pull request that this hardening landed in; eight had carried the unanchored stem since long before. The review that caught it flagged only the six the diff touched — the sibling class it did not introduce stayed invisible, because a reviewer reads the diff and the defect lives in the file.

## Sources

- GitHub PR #228 (equality → stem → anchored, 14 matchers)
- CodeRabbit review on PR #228 (2 findings, `🔒 Security & Privacy | 🟠 Major`)

> Evidence: https://github.com/YoungjaeDev/my-claude-plugins/pull/228
> See-also: [[review-loop-churn]]
