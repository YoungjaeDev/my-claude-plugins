---
id: mem0-hook-latency-budget
aliases: [mem0-rerank-default, mem0-userpromptsubmit-timeout, mem0-hook-timeout, mem0-auto-save-priority]
last_verified: 2026-07-07
status: active
volatility: volatile
sources: 4
---

# mem0 hook latency budget (UserPromptSubmit 8s vs blocking search)

The mem0 plugin (mem0-plugins marketplace, verified at 0.2.12) runs a **blocking**
memory search on every `UserPromptSubmit` (prompts >= 20 chars) under a `timeout: 8`
declared in the plugin's cached `hooks/hooks.json`. The budget does not survive the
worst-case path:

- each HTTP search call is capped at `SEARCH_TIMEOUT = 5` (`scripts/_search.py:14`);
- the resume/session-state branch of `scripts/on_user_prompt.sh` issues **two
  sequential searches** (session_state + decisions) — worst case ~10s > 8s;
- rerank is **on by default** (`should_rerank()`: unset env = enabled), adding
  ~150-200ms per prompt;
- plus python interpreter cold-start per hook invocation.

Result: intermittent "output discarded" hook-timeout errors on ordinary prompts.

## Rules

1. **Latency levers must live in user-owned files, not the plugin cache.**
   `MEM0_RERANK=off` in `~/.claude/settings.json` `env` disables rerank and survives
   plugin updates. Editing the cached `hooks.json` `timeout` works but resets on every
   version bump — same failure mode as documented in cache version-pinning.
   `MEM0_RERANK` is read case-insensitively; `0`/`false`/`no`/`off` disable, anything
   else (including unset) enables.
2. **The plugin's rerank-on default contradicts upstream guidance.** mem0's own
   advanced-retrieval Best Practice says do NOT enable rerank by default — measure
   the need first. Rerank only re-orders the vector top-k so the best memory lands
   inside the `top_k=5` injection window; off = pure vector-similarity order.
3. **Rerank-off does not fully fix the budget.** The 2-sequential-search resume path
   alone can exceed 8s. Residual options if timeouts persist: raise the cached
   `timeout` 8 -> 12 (re-apply after every update) or file an upstream issue.
4. **The env-lever pattern (rule 1) does not generalize per flag.** `_identity.sh:68`
   unconditionally re-assigns and exports `MEM0_AUTO_SAVE` from `~/.mem0/settings.json`'s
   `auto_save` key on every hook run, so `MEM0_AUTO_SAVE` in `~/.claude/settings.json`
   `env` is silently ineffective — for this flag `~/.mem0/settings.json` is the SOT.
   (`MEM0_RERANK` is untouched by `_identity.sh`, which is why the env lever works
   there.) Check per-flag precedence in `_identity.sh` before choosing the lever's home.
   Also: `auto_save: false` only disables auto-capture *writes*; search/injection,
   SessionStart context load, and the add-memory nudge all remain active.

> See-also: [[cache-version-pinning]]
> See-also: [[mem0-llmwiki-federation]]

## Sources

- `~/.claude/plugins/cache/mem0-plugins/mem0/0.2.12/hooks/hooks.json` (UserPromptSubmit `timeout: 8`) + `scripts/_search.py` (`SEARCH_TIMEOUT = 5`, `should_rerank()`) + `scripts/on_user_prompt.sh` (two-search resume branch) — re-verified 2026-07-07.
- mem0 docs, advanced-retrieval Best Practices ("don't enable rerank by default; measure first"), via mcpdocs `mem0:https://docs.mem0.ai/llms.txt`.
- Session transcript 48e62aa5 (2026-07-06 investigation) — root-cause exploration; staging marker consumed 2026-07-07.
- Session transcript 73e1c10b (mem0-ops build + auto_save off application) — `_identity.sh` precedence trap discovered; re-verified against `~/.claude/plugins/cache/mem0-plugins/mem0/0.2.12/scripts/_identity.sh:68` 2026-07-07; staging marker consumed 2026-07-07.
