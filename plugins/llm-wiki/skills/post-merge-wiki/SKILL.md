---
name: post-merge-wiki
description: Use after `github-dev:post-merge` (or any PR merge to main) to scan the merged diff + PR comments for wiki-worthy lore and chain `ingest-finding` for each candidate. Closes the spec → dev → review → wiki loop without manual trigger.
---

# post-merge-wiki

The default `github-dev:post-merge` skill handles branch cleanup + milestone updates but stops short of the wiki. This skill is the missing link — it reads what just merged and asks "what lore did we just learn that the wiki should record?".

> Operates on the repo's wiki root, resolved in order: `.llmwiki/wiki/` (preferred) →
> `.claude/wiki/` (legacy) → `.codex/wiki/` (legacy Codex fork). Examples below use
> `.llmwiki/wiki/`; substitute the legacy path if that is what the repo has.

> Ships with `llm-wiki` plugin; install via marketplace.

## When to use

- Immediately after `github-dev:post-merge` completes
- After any merge to `main` where the PR fixed a non-obvious bug, added a new provider, changed an invariant, or surfaced a debugging story
- When the soft-hint `PostToolUse` hook flags a recent `git commit` worth ingesting

Do NOT use:
- For trivial merges (typo fix, dep bump, formatting)
- When the PR description already says "no wiki impact"
- When no wiki root resolves (suggest `/llm-wiki:bootstrap-wiki` instead)

## Steps

1. **Identify the merge commit**:
   ```bash
   git log --merges -1 --pretty=format:'%H %s'
   # or, if merge was squash:
   git log -1 --pretty=format:'%H %s'
   ```
   Capture the SHA + PR number from the squash message (e.g. `(#132)`).

2. **Read the diff + PR body + comments**:
   ```bash
   git show --stat <SHA>          # files touched
   git show --name-only <SHA>     # authoritative file list
   gh pr view <N> --json title,body,comments,reviews
   ```

3. **Derive ingest candidates**.

   **Always start from `git show --name-only <SHA>` (actual touched files), never from the PR title/body alone.** Concept-based guessing produced false candidates in the v2 0-week verification (e.g. a "cloud-sync.md" candidate was inferred from the phrase "manifest source tag" in the PR title, but the actual diff touched no cloud-sync code). Walk the file list, then for each file ask whether the change introduced lore. If you cannot tie a candidate page to a concrete file in the diff, drop the candidate.

   For each meaningful change, ask:
   - Is the *cause* of this change non-obvious from the diff alone?
   - Did the PR review surface a provider quirk, race condition, or design rationale?
   - Did a new file/module appear that the wiki's code-map should reference?
   - Did an invariant in `rules/*.md` change (alert user separately)?

   List candidates as `(page-to-touch, finding-summary, evidence-file)` tuples — `evidence-file` must come from `git show --name-only`. Map to:
   - Existing wiki pages to update (preferred — see `ingest-finding`'s append-only-rot warning)
   - New pages inside existing domains (rare)
   - New domain dir (needs user approval — surface as a question, do not auto-create)

4. **Present the candidates to the user via AskUserQuestion**:
   - Show the list with 1-line summaries
   - Let user pick which to ingest, which to skip
   - Multi-select OK

5. **For each accepted candidate**: invoke `/llm-wiki:ingest-finding` (or call its steps inline if already loaded). The ingest skill handles the diff-log + cross-update discipline, and applies v2 frontmatter defaults (`status: active`, inferred `volatility:`, `sources:`) to any new page it creates.

6. **Final report**:
   - Pages updated (with `last_verified:` bump count)
   - New pages added (with their `status` / `volatility` / `sources` defaults from `ingest-finding`)
   - Resolved root's `log.md` entry written (header: `## YYYY-MM-DD — post-merge <PR#> (post-merge-wiki)`)
   - Any `rules/*.md` invariant flag for the user to resolve manually

## LLM autonomy boundaries

| Action | LLM alone | Needs user confirm |
|---|---|---|
| Read merge diff + PR comments | ✅ | — |
| Derive ingest candidate list | ✅ | — |
| Update existing wiki page (via `ingest-finding`) | ✅ | — |
| Add new wiki page inside existing domain | ✅ | — |
| Add new wiki domain dir | ❌ | ✅ |
| Modify `rules/*.md` invariant | ❌ (alert only) | ✅ |
| Skip a candidate the user didn't review | ❌ | ✅ |

## Output format

```
## Post-merge ingest — PR #<N> (<SHA>)

Candidates (file → finding → evidence):
- <touched-file> → <1-line finding> → <evidence-file>
- ...

Accepted: <list> | Skipped: <list>

Result:
- Pages updated: <domain>/<page>.md (last_verified bumped)
- Pages added: <domain>/<page>.md (status: active, volatility: <inferred>, sources: N)
- log.md: ## YYYY-MM-DD — post-merge #<N> (post-merge-wiki)
- rules/*.md flags: <none | list>
```

### Worked example

```
## Post-merge ingest — PR #132 (a1b2c3d)

Candidates (file → finding → evidence):
- src/providers/x.py → provider X returns null on >8KB inputs → src/providers/x.py
- src/cache.py → no lore (mechanical refactor) → (dropped)

Accepted: backend/provider-x.md | Skipped: cache refactor

Result:
- Pages updated: (none)
- Pages added: backend/provider-x.md (status: active, volatility: volatile, sources: 1)
- log.md: ## 2026-05-29 — post-merge #132 (post-merge-wiki)
- rules/*.md flags: none
```

## Verification

- The resolved root's `log.md` has a new `## YYYY-MM-DD — post-merge <PR#> (post-merge-wiki)` entry citing the merge SHA + PR #
- Pages touched have `last_verified: <today>`
- New pages carry v2 frontmatter defaults (`status: active`, inferred `volatility:`, `sources:`)
- No raw `[[wikilink]]` introduced (typed grammar only)
- User explicitly approved the candidate list before any wiki edit
- Every ingested candidate maps to a concrete file in `git show --name-only`

## Anti-patterns

- **Auto-ingest without user review** — surprise edits to lore erode trust.
- **Ingest every trivial fix** — wiki becomes a churn log instead of a synthesis layer.
- **Skip the diff log** — `ingest-finding` requires the resolved root's `log.md` entry first; don't shortcut it here either.
- **Run before `github-dev:post-merge`** — branch cleanup + milestone state must settle first.
- **Concept-based candidate derivation** — never propose a page from PR title/body phrasing alone. Tie every candidate to a file in `git show --name-only`.

## See also

> All wiki events (lint reports, ingest summaries, post-merge ingests) accumulate in the resolved wiki root's `log.md` (e.g. `.llmwiki/wiki/log.md`) with schema header `## YYYY-MM-DD — <event-type> (<source-skill>)`.
