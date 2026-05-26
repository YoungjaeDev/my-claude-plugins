---
name: bootstrap-wiki
description: Use to scaffold the Karpathy 3-layer `.claude/` system (rules + wiki + skills + spec + hooks) in a new repo that doesn't have it yet. Copies templates from the plugin's bundled assets, prompts for project pitch and 1-3 first domains, writes a slim CLAUDE.md.
---

# bootstrap-wiki

Karpathy LLM-Wiki 3-layer = `rules/` (schema invariants) + `wiki/` (LLM-maintained lore) + `raw/` (audit trail elsewhere). This skill drops the empty layout into any repo so the per-PR workflow (spec → resolve-issue → post-merge → ingest) has a place to land.

> Ships with `llm-wiki` plugin; install via marketplace. Templates bundled at `${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-wiki/assets/templates/`.

## When to use

- Brand new repo with no `.claude/` directory
- Existing repo where `.claude/` is just `settings.local.json` (or missing) and you want to start LLM-Wiki discipline
- Asking "how do I add the wiki system here?"

Do NOT use if `.claude/wiki/index.md` already exists — the wiki is already initialized; instead use `/llm-wiki:query-wiki` or `/llm-wiki:ingest-finding`.

## Steps

1. **Confirm context**:
   - Run `pwd` and `git rev-parse --show-toplevel` to confirm the target repo root.
   - If `.claude/wiki/` already has content, abort and report to user — overwriting is destructive.

2. **Gather project info via AskUserQuestion**:
   - One-line project pitch (will go into `CLAUDE.md`)
   - 1-3 initial wiki domains (e.g., `frontend`, `backend`, `data-pipeline`) — these become subdirs of `.claude/wiki/`
   - Whether to also create matching `rules/<domain>.md` stubs

3. **Create layout** (idempotent — use `cp --update=none` / `mkdir -p`):
   ```bash
   mkdir -p .claude/{rules,wiki,skills,spec,hooks}
   cp --update=none ${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-wiki/assets/templates/wiki-skeleton/index.md .claude/wiki/index.md
   cp --update=none ${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-wiki/assets/templates/wiki-skeleton/log.md .claude/wiki/log.md
   cp --update=none ${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-wiki/assets/templates/rules-skeleton/_entrypoint.md .claude/rules/_entrypoint.md
   cp --update=none ${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-wiki/assets/templates/rules-skeleton/code-map.md .claude/rules/code-map.md
   ```

4. **Per-domain stubs**: for each domain name the user gave, create:
   - `.claude/wiki/<domain>/.gitkeep` (so the empty dir is tracked)
   - Optionally `.claude/rules/<domain>.md` from `${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-wiki/assets/templates/rules-skeleton/_domain-template.md`, with `paths:` left as a TODO comment

5. **CLAUDE.md** at repo root:
   - If missing, write a ~30-line slim version: project pitch + `.claude/` 3-layer entrypoint + note that the user's global `CLAUDE.md` (under their home `.claude/` directory) takes precedence
   - If existing, do not overwrite — print a diff suggestion for the user to merge manually

6. **First spec template**: copy `${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-wiki/assets/templates/wiki-skeleton/spec-template.md` to `.claude/spec/_template.md` (rename of-the-day). Tell the user the workflow: copy template to `<YYYY-MM-DD>-<short-name>.md` → `/github-dev:decompose-issue` → `/github-dev:resolve-issue` → merge → `/github-dev:post-merge` → `/llm-wiki:post-merge-wiki`.

7. **`wiki/log.md` initial entry**: append `## YYYY-MM-DD — bootstrap (bootstrap-wiki)` with the domain list created.

## Verification

After bootstrap:
- `.claude/wiki/index.md` exists and has 1+ domain headings (even if empty)
- `.claude/rules/_entrypoint.md` exists
- `.claude/spec/_template.md` exists
- `.claude/wiki/log.md` has its first entry
- New `CLAUDE.md` (or merge suggestion) points to the 3-layer entrypoint
- `git status` shows expected new files (run `git add -n .claude/` to preview)

## What NOT to do

- Don't overwrite existing files. Templates are seeds, not authority.
- Don't add a 3rd-depth wiki directory. 2-depth (domain/page) is by design.
- Don't run this in a non-git directory (you'd lose the audit trail of the bootstrap).
- Don't auto-commit. Leave staging + commit message to the user.
