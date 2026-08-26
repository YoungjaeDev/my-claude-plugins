---
name: bootstrap-wiki
description: Use to scaffold the LLM-Wiki knowledge system (`.llmwiki/` insight + wiki + raw, plus spec) in a new repo that doesn't have it yet. Copies templates from the plugin's bundled assets, prompts for project pitch and 1-3 first domains, writes a slim CLAUDE.md.
---

# bootstrap-wiki

LLM-Wiki 3-layer = `.llmwiki/insight/` (promoted cross-agent rules) + `.llmwiki/wiki/` (LLM-maintained lore) + `.llmwiki/raw/` (immutable evidence). This skill drops the empty layout into any repo so the per-PR workflow (spec → resolve-issue → post-merge → ingest) has a place to land. All three layers live under the neutral `.llmwiki/` root so `codex-bridge`'s `.claude/`→`.codex/` body transform can never fork them per-agent — one copy, both agents (Claude Code + Codex). This skill does **not** scaffold a `.claude/rules/` schema layer: Codex can't read it, so cross-agent rules graduate to `.llmwiki/insight/` and reach both runtimes via the `core-config` prompt-injection hook instead. `.claude/rules/` stays reserved for mechanical tool-operation rules (not wiki lore), which this skill leaves to the project.

> Ships with `llm-wiki` plugin; install via marketplace. Templates bundled at `<plugin-root>/skills/bootstrap-wiki/assets/templates/` — Step 3 resolves `<plugin-root>` across runtimes (Claude `CLAUDE_PLUGIN_ROOT`, Codex plugin cache), since Codex 0.135 does not export `CLAUDE_PLUGIN_ROOT`.

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

3. **Create layout** (idempotent — `mkdir -p` + existence guards; avoid GNU-only `cp --update=none` so it works on macOS/BSD too):
   ```bash
   # --- Plugin root resolution (cross-runtime) -------------------------------
   # Claude exports CLAUDE_PLUGIN_ROOT; Codex 0.135 does not. Every branch verifies
   # its target (CHK) exists before committing, so a stale env or an incomplete
   # cache version falls through instead of winning. The cache branch walks
   # versions high-to-low and takes the first COMPLETE one.
   CHK="skills/bootstrap-wiki/assets/templates"
   PLUGIN_ROOT=""
   [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -e "$CLAUDE_PLUGIN_ROOT/$CHK" ] && PLUGIN_ROOT="$CLAUDE_PLUGIN_ROOT"
   [ -z "$PLUGIN_ROOT" ] && [ -e "plugins/llm-wiki/$CHK" ] && PLUGIN_ROOT="plugins/llm-wiki"
   if [ -z "$PLUGIN_ROOT" ]; then
     cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
     while IFS= read -r d; do
       [ -e "$d/$CHK" ] && { PLUGIN_ROOT="$d"; break; }
     done < <(ls -1d "$cache_root"/*/llm-wiki/*/ 2>/dev/null | awk -F/ '{print $(NF-1)"\t"$0}' | sort -t. -k1,1rn -k2,2rn -k3,3rn | cut -f2- | sed 's#/$##')
   fi
   { [ -n "$PLUGIN_ROOT" ] && [ -e "$PLUGIN_ROOT/$CHK" ]; } || { echo "bootstrap-wiki: plugin root not resolved (need $CHK)" >&2; exit 1; }

   # raw/ is bucketed by source-type (external / research / transcripts / audits);
   # see ${PLUGIN_ROOT}/references/wiki-conventions.md § raw/ layout. wiki/ uses domain subdirs, insight/ stays flat.
   mkdir -p .llmwiki/raw/external .llmwiki/raw/research .llmwiki/raw/transcripts .llmwiki/raw/audits \
            .llmwiki/wiki .llmwiki/insight .claude/skills .claude/spec
   for b in external research transcripts audits; do : > ".llmwiki/raw/$b/.gitkeep"; done
   T="${PLUGIN_ROOT}/${CHK}"
   [ -f .llmwiki/wiki/index.md ]        || cp "$T/wiki-skeleton/index.md"                 .llmwiki/wiki/index.md
   [ -f .llmwiki/wiki/log.md ]          || cp "$T/wiki-skeleton/log.md"                   .llmwiki/wiki/log.md
   [ -f .llmwiki/insight/index.md ]     || cp "$T/insight-skeleton/index.md"              .llmwiki/insight/index.md
   [ -f .llmwiki/insight/_insight-template.md ] || cp "$T/insight-skeleton/_insight-template.md"  .llmwiki/insight/_insight-template.md
   ```
   Replace `TODO-INITIAL-DATE` in `.llmwiki/insight/index.md` with today's date. (`.claude/rules/` is intentionally NOT created here — see the intro.)

4. **Per-domain stubs**: for each domain name the user gave, create:
   - `.llmwiki/wiki/<domain>/.gitkeep` (so the empty dir is tracked)

5. **CLAUDE.md** at repo root:
   - If missing, write a ~30-line slim version: project pitch + a pointer to `.llmwiki/insight/index.md` (promoted cross-agent rules, read first) and `.llmwiki/wiki/index.md` (lore) + note that the user's global `CLAUDE.md` (under their home `.claude/` directory) takes precedence
   - If existing, do not overwrite — print a diff suggestion for the user to merge manually

6. **First spec template**: copy `${PLUGIN_ROOT}/skills/bootstrap-wiki/assets/templates/wiki-skeleton/spec-template.md` to `.claude/spec/_template.md` (rename of-the-day). Reuse `PLUGIN_ROOT` from Step 3, or re-run the resolver block if this runs in a fresh shell. Tell the user the workflow: copy template to `<YYYY-MM-DD>-<short-name>.md` → `/github-dev:decompose-issue` → `/github-dev:resolve-issue` → merge → `/github-dev:post-merge` (requires the `github-dev` plugin; its mandatory wiki step ingests merged lore — no separate skill needed). If `github-dev` is not installed, run `/llm-wiki:ingest-finding` manually after merging instead.

7. **`.llmwiki/wiki/log.md` initial entry**: append `## YYYY-MM-DD — bootstrap (bootstrap-wiki)` with the domain list created.

## Verification

After bootstrap:
- `.llmwiki/wiki/index.md` exists and has 1+ domain headings (even if empty)
- `.llmwiki/raw/{external,research,transcripts,audits}/.gitkeep` exist (source-type buckets)
- `.llmwiki/insight/index.md` exists (with `TODO-INITIAL-DATE` replaced by today's date)
- `.claude/spec/_template.md` exists
- `.llmwiki/wiki/log.md` has its first entry
- New `CLAUDE.md` (or merge suggestion) points to `.llmwiki/insight/index.md` (promoted rules) + `.llmwiki/wiki/index.md` (lore)
- No `.claude/rules/` schema layer was created by this skill
- `git status` shows expected new files (run `git add -n .llmwiki/ .claude/` to preview)

## What NOT to do

- Don't overwrite existing files. Templates are seeds, not authority.
- Don't add a 3rd-depth wiki directory. 2-depth (domain/page) is by design.
- Don't run this in a non-git directory (you'd lose the audit trail of the bootstrap).
- Don't auto-commit. Leave staging + commit message to the user.
