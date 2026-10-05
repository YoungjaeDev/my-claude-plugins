---
id: codex-plugin-surfaces
aliases: [codex-hook-trust, codex-skills-only, codex-plugin-install]
last_verified: 2026-10-05
status: active
volatility: volatile
sources: 5
---

# What Codex actually registers from an installed plugin

`codex plugin add <name>@my-claude-plugins` registers the plugin's `skills/` and nothing else.

- `commands/` and `agents/` in `plugin.json` are ignored. Skill logic moved into an agent definition disappears on Codex without an error.
- Bundled hooks are copied into the cache but never run until the user registers them in `~/.codex/hooks.json` and approves them in `/hooks`. Until then there is no signal at all; `codex exec` (headless) can never grant trust, so plugin hooks never fire in CI.
- `/hooks` approval is recorded in `~/.codex/config.toml`, not in `hooks.json`: an entry `[hooks.state."<source path>:<event>:<i>:<j>"]` carries a `trusted_hash` (sha256). For example:

  ```toml
  [hooks.state."/path/to/hook.sh:UserPromptSubmit:0:0"]
  trusted_hash = "<sha256>"
  ```

  A missing `config.toml` entry skips the hook silently: no error, no warning.
- A `hook: UserPromptSubmit` (or other event) line in `codex exec` output does not identify which hook source ran. The line can come from an already-trusted, unrelated hook (for example a pre-existing `~/.codex/hooks.json` entry), not the plugin's own hook. Confirm by command path, not by event name.
- `trusted_hash` is presumably a content hash, so editing a hook script after approval probably invalidates trust and forces re-approval via `/hooks`. **Unverified.**
- A per-turn convention (for example "read the wiki MOC before answering lore questions") therefore has only two carriers on Codex: the manually registered hook, or the repo's own `AGENTS.md`. A skill cannot carry it because a skill loads only on the turn it is selected.
- Skill `description` over 1024 characters is skipped silently; `: ` inside an unquoted description collapses the YAML on both runtimes. `scripts/check-skill-contract.mjs` guards both.
- A skill's per-project data file that both runtimes read and grow goes under a vendor-neutral dot folder. `docs:vp` keeps its term dictionary at `.agents/voice-terms.md` for this reason. Codex can technically read `.claude/`, but the name marks the file as belonging to one vendor. `wiki:plaud-note-taking` predates this and still keeps its dictionary at `.claude/plaud-note-taking/terminology.md`; the two dictionaries are separate files.
- The `PLUGIN_ROOT` resolver that every bundled-script skill carries (Codex exports no `CLAUDE_PLUGIN_ROOT`) runs under the user's shell, often zsh. zsh's `nomatch` aborts a whole command when any one glob matches nothing, so `ls -1d "$A"/*/deck/* "$B"/*/deck/*` exits 1 with no output when either cache root has no match: a missing Codex cache hides the Claude cache's hit. The `no matches found` line comes from the shell, not `ls`, so `2>/dev/null` does not silence it. The deck skills therefore search both roots with `find ... -path '*/deck/*'` (`plugins/deck/skills/deck-check/SKILL.md`). The resolvers in `dev`, `wiki` and `docs` glob a single root per `ls`, so an unmatched glob there yields an empty result, which is already the correct "not cached" answer; they only leak the stderr line. The trap opens when a second root is added to the same `ls`.
- The 2.30.0 rename moved the cache paths: hook entries pointing at `llm-wiki/<ver>/hooks/...` must be re-pointed at `wiki/<ver>/...` and re-trusted. Entries for `core-config` / `core` are deleted outright: the plugin was removed in 2.31.0 and its per-prompt injection is replaced by the user-global instructions (`CLAUDE.md.global`).

## Sources

- GitHub issue #169 (measured on codex-cli 0.145.0, 2026-07-27)
- PR #213 Codex review thread on `plugins/llm-wiki/CLAUDE.md` (2026-09-04)
- `plugins/wiki/CLAUDE.md` "Codex hooks (descriptor shipped, manual wiring)" (amended 2026-09-11 with the `config.toml` trust schema)
- commit 05dc01c `plugins/docs/skills/vp/SKILL.md` (`.agents/voice-terms.md` shared dictionary, 2026-09-15)
- merge 9a74a07 `plugins/deck/skills/deck-check/SKILL.md` (`find`-based resolver over the Claude and Codex caches; zsh `nomatch` reproduced 2026-10-05)

> Evidence: https://github.com/YoungjaeDev/my-claude-plugins/issues/169
> See-also: [[bundle-rename-is-a-new-entry]]
