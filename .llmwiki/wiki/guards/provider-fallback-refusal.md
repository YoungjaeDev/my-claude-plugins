---
id: provider-fallback-refusal
aliases: [fallback-chain-refusal, provider-shopping, quota-only-fallback]
last_verified: 2026-10-05
status: active
volatility: stable
sources: 2
---

# A fallback chain falls through on capacity, never on a refusal

A skill that can reach several generators (image, text, search) usually orders them as a chain: default provider first, the next one when the default cannot serve the request. The chain is safe only if "cannot serve" means **cannot**, not **will not**.

- **Capacity failures fall through.** Quota exhausted, rate limit, provider down, not connected. The request itself was acceptable; another provider serving it changes nothing about what gets made.
- **A safety refusal stops the chain.** The provider looked at the request and declined it. Re-sending the same prompt to the next provider is shopping for one that says yes: the chain becomes a mechanism for bypassing the first provider's policy, and the agent runs it without the user ever seeing the refusal. Stop, report the refusal, and ask the user whether to revise the prompt.

The failure is easy to write because "it failed, try the next one" reads as resilience. The deck plugin's asset skill first listed "quota or a safety refusal" as the trigger for `codex-image` → `agy` → Higgsfield; CodeRabbit flagged it under Security & Privacy, and the trigger is now quota only (`plugins/deck/skills/deck-assets/SKILL.md`, § Icon sheets).

Recording which provider produced each file (the deck asset sidecar's `Fallback used:` line) is what keeps a fallback auditable after the fact. It does not make a refusal fallback acceptable: the record shows the bypass, it does not prevent it.

The same split applies to review and research fallbacks that switch source on a rate limit (`cr-fix --cr-source auto`): rate limits are capacity, so those are fine as written.

## Sources

- CodeRabbit review on PR #269, `plugins/deck/skills/deck-assets/SKILL.md` (Security & Privacy, Major): https://github.com/YoungjaeDev/my-claude-plugins/pull/269#discussion_r4183208716
- `plugins/deck/skills/deck-assets/SKILL.md` § 3 Icon sheets (fallback on quota only, refusal stops and asks), merge 9a74a07

> Evidence: https://github.com/YoungjaeDev/my-claude-plugins/pull/269#discussion_r4183208716