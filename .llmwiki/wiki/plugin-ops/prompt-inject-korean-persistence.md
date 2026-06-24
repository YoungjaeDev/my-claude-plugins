---
id: prompt-inject-korean-persistence
aliases: [korean-default-regression, prompt-inject-block, english-regression-workflow]
last_verified: 2026-06-24
status: active
volatility: stable
sources: 2
---

# prompt-inject Korean-default: internal workflow/subagent/English-skill is NOT a "별도 지시"

## The failure

The `core-config` per-prompt block (`prompt_inject.sh`) sets a Korean-default for the
final user response. Despite that, after a turn passes through an **English-bodied
workflow** (ultracode / the `Workflow` tool), a **subagent**, or an English skill
(deep-research, most document-skills), the final user-facing answer regresses to
English.

## Why a 1-line directive was not enough

The Korean directive is phrased "별도 지시가 없으면 한국어" (Korean unless told
otherwise). The regression is not that the directive is *absent* — it is a salience
problem:

- The directive sat as 1 of ~6 equal-weight lines in the block.
- An English skill body loaded downstream reads as exactly the "별도 지시"
  (separate instruction) the directive defers to. The skill never says "answer in
  English" — its English prose *is* the implicit override.
- The main session writes the final answer (it synthesizes subagent results) and
  receives the injection on the turn the workflow was invoked — so strengthening the
  injected block alone is sufficient; the subagent specs do not need editing.

## The fix

The block now states, in one lifted line: the final user answer is **always**
Korean, and internal workflow / subagent / English-skill paths (ultracode,
deep-research) are **NOT** a "별도 지시" — passing through them does not authorize an
English answer. Naming the override paths explicitly closes the loophole the bare
directive left open.

Encoder constraint: the block is JSON-encoded by bash parameter expansion (no
jq/python), so it must contain no literal `"` or `\` — use `·`, `()`, `—` instead.

## The block is English, the answer is Korean

The block *text* was later rewritten from Korean to English, but its first line still
mandates a Korean final reply. Writing the rules in English keeps the model from
quietly adopting an English register for the whole turn while the output-language pin
(Korean) stays explicit and unmissable. The Korean phrasing quoted above is the
original directive; the current block expresses the same rule in English.

## Scope boundary

This is lore (the *why*). The directive text itself lives in the hook; the
"regenerate Codex's manual `~/.codex/hooks/` copy after a block change" mechanic
lives in `plugins/core-config/CLAUDE.md`. Do not duplicate either here.

## Sources

1. `plugins/core-config/hooks/prompt_inject.sh` — the strengthened fixed block (PR #50).
2. `plugins/core-config/CLAUDE.md` — the hook's documented purpose ("Claude reverts to English over long sessions") and the Codex manual-copy parity note.

> Evidence: plugins/core-config/hooks/prompt_inject.sh
> See-also: [[insight-layer-via-hook]]
