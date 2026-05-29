---
name: bootstrap-wiki
description: Use to scaffold the Karpathy 3-layer `.claude/` system (rules + wiki + skills + spec + hooks) in a new repo that doesn't have it yet. Copies templates from the plugin's bundled assets, prompts for project pitch and 1-3 first domains, writes a slim CLAUDE.md.
---

# bootstrap-wiki

Karpathy LLM-Wiki 3-layer = `.claude/rules/` (schema invariants) + `.llmwiki/wiki/` (LLM-maintained lore) + `.llmwiki/raw/` (immutable evidence). This skill drops the empty layout into any repo so the per-PR workflow (spec → resolve-issue → post-merge → ingest) has a place to land. The wiki + raw layers live under the neutral `.llmwiki/` root so `codex-bridge`'s `.claude/`→`.codex/` body transform can never fork them per-agent; the schema layer stays at `.claude/rules/`, the only verified auto-load path.

> Ships with `llm-wiki` plugin; install via marketplace. Templates bundled at `${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-wiki/assets/templates/`.

## When to use

- Brand new repo with no `.claude/` directory
- Existing repo where `.claude/` is just `settings.local.json` (or missing) and you want to start LLM-Wiki discipline
- Asking "how do I add the wiki system here?"

Do NOT use if `.llmwiki/wiki/index.md` (or a legacy `.claude/wiki/index.md`) already exists — the wiki is already initialized; instead use `/llm-wiki:query-wiki` or `/llm-wiki:ingest-finding`. If only a legacy `.claude/wiki/` exists and you want the v2 `.llmwiki/` layout, use `/llm-wiki:migrate-wiki` instead.

## Steps

1. **Confirm context**:
   - Run `pwd` and `git rev-parse --show-toplevel` to confirm the target repo root.
   - If `.llmwiki/wiki/` (or a legacy `.claude/wiki/`) already has content, abort and report to user — overwriting is destructive.

2. **Gather project info via AskUserQuestion**:
   - One-line project pitch (will go into `CLAUDE.md`)
   - 1-3 initial wiki domains (e.g., `frontend`, `backend`, `data-pipeline`) — these become subdirs of `.llmwiki/wiki/`
   - Whether to also create matching `.claude/rules/<domain>.md` stubs

3. **Create layout** (idempotent — use `cp --update=none` / `mkdir -p`):
   ```bash
   mkdir -p .llmwiki/raw .llmwiki/wiki .claude/rules .claude/skills .claude/spec .claude/hooks
   : > .llmwiki/raw/.gitkeep
   cp --update=none ${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-wiki/assets/templates/wiki-skeleton/index.md  .llmwiki/wiki/index.md
   cp --update=none ${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-wiki/assets/templates/wiki-skeleton/log.md    .llmwiki/wiki/log.md
   cp --update=none ${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-wiki/assets/templates/rules-skeleton/_entrypoint.md .claude/rules/_entrypoint.md
   cp --update=none ${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-wiki/assets/templates/rules-skeleton/code-map.md    .claude/rules/code-map.md
   ```

4. **Per-domain stubs**: for each domain name the user gave, create:
   - `.llmwiki/wiki/<domain>/.gitkeep` (so the empty dir is tracked)
   - Optionally `.claude/rules/<domain>.md` from `${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-wiki/assets/templates/rules-skeleton/_domain-template.md`, with `paths:` left as a TODO comment

5. **CLAUDE.md** at repo root:
   - If missing, write a ~30-line slim version: project pitch + a pointer to `.llmwiki/wiki/index.md` (lore) and `.claude/rules/` (schema) + note that the user's global `CLAUDE.md` (under their home `.claude/` directory) takes precedence
   - If existing, do not overwrite — print a diff suggestion for the user to merge manually

6. **First spec template**: copy `${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-wiki/assets/templates/wiki-skeleton/spec-template.md` to `.claude/spec/_template.md` (rename of-the-day). Tell the user the workflow: copy template to `<YYYY-MM-DD>-<short-name>.md` → `/github-dev:decompose-issue` → `/github-dev:resolve-issue` → merge → `/github-dev:post-merge` → `/llm-wiki:post-merge-wiki`.

7. **`.llmwiki/wiki/log.md` initial entry**: append `## YYYY-MM-DD — bootstrap (bootstrap-wiki)` with the domain list created.

## Verification

After bootstrap:
- `.llmwiki/wiki/index.md` exists and has 1+ domain headings (even if empty)
- `.llmwiki/raw/.gitkeep` exists
- `.claude/rules/_entrypoint.md` exists
- `.claude/spec/_template.md` exists
- `.llmwiki/wiki/log.md` has its first entry
- New `CLAUDE.md` (or merge suggestion) points to `.llmwiki/wiki/index.md` (lore) + `.claude/rules/` (schema)
- `git status` shows expected new files (run `git add -n .llmwiki/ .claude/` to preview)

## What NOT to do

- Don't overwrite existing files. Templates are seeds, not authority.
- Don't add a 3rd-depth wiki directory. 2-depth (domain/page) is by design.
- Don't run this in a non-git directory (you'd lose the audit trail of the bootstrap).
- Don't auto-commit. Leave staging + commit message to the user.
