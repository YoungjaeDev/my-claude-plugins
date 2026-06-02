# Wiki Lore Ingest (Step 8, MANDATORY)

This is the former `llm-wiki:post-merge-wiki` skill, absorbed into post-merge as a required step. It reads what just merged and asks "what lore did we learn that the wiki should record?" — then delegates the heavy work (diff-log, multi-page cross-update, insight graduation) to `llm-wiki:ingest-finding`.

It runs **after** config integration (Steps 6-7) on purpose: the wiki step must dedup against what those steps already absorbed (see Routing dedup below).

> Operates on the resolved wiki root, in order: `.llmwiki/wiki/` (preferred) → `.claude/wiki/` (legacy) → `.codex/wiki/` (legacy fork). Examples use `.llmwiki/wiki/`.

## Skip conditions

- **No wiki root resolves** — skip silently. llm-wiki is a soft dependency; post-merge stays fully functional without it.
- **`llm-wiki:ingest-finding` not installed** — skip silently (note it as a manual follow-up).
- **Trivial merge** — skip. Trivial = typo fix, dependency bump, formatting/lint-only, or a PR description that says "no wiki impact".

Unlike the old optional Step 5.8, there is **no `AskUserQuestion` "shall I run the wiki step?" gate** — the step is mandatory whenever a wiki root resolves and the merge is non-trivial. (AskUserQuestion is still used inside Step 4 below, but only for candidates that cross an autonomy boundary.)

## Steps

### 1. Use this PR's merge commit

Use `MERGE_SHA` — **this PR's** merge commit, captured in SKILL.md Step 1 from `gh pr view <N> --json mergeCommit --jq '.mergeCommit.oid'`. Do **not** rederive it with `git log --merges -1` / `git log -1`: after Step 3 pulls the base branch, those grab whatever merge/squash commit last landed on base, which is the wrong PR when post-merge runs late or another PR merged in between — and Step 8 would then build wiki candidates from an unrelated file list.

```bash
# MERGE_SHA was set in SKILL.md Step 1 from gh pr view <N> --json mergeCommit
[ -n "$MERGE_SHA" ] || MERGE_SHA=$(gh pr view <N> --json mergeCommit --jq '.mergeCommit.oid')
```

### 2. Read the diff + PR body + comments

```bash
git show --diff-merges=first-parent --stat "$MERGE_SHA"       # files touched
git show --diff-merges=first-parent --name-only "$MERGE_SHA"  # authoritative file list (first-parent: a non-squash merge commit otherwise shows an empty combined diff)
gh pr view <N> --json title,body,comments,reviews
```

### 3. Derive ingest candidates — file-list-first

**Always start from `git show --diff-merges=first-parent --name-only "$MERGE_SHA"` (actual touched files), never from the PR title/body alone.** Concept-based guessing produces false candidates (e.g. inferring a "cloud-sync.md" page from the phrase "manifest source tag" in a title whose diff touched no cloud-sync code). Walk the file list; for each file ask whether the change introduced lore. If you cannot tie a candidate page to a concrete file in the diff, **drop the candidate**.

For each meaningful change, ask:
- Is the *cause* of this change non-obvious from the diff alone?
- Did the PR review surface a provider quirk, race condition, or design rationale?
- Did a new file/module appear that the wiki's code-map should reference?
- Does the finding meet the `.llmwiki/insight/` graduation bar (recurring + generalizable + costly-to-violate + stabilized)? If so, `ingest-finding`'s graduation step handles it.

List candidates as `(page-to-touch, finding-summary, evidence-file)` tuples — `evidence-file` must come from `git show --diff-merges=first-parent --name-only`. Map each to: an existing wiki page to update (preferred), a new page inside an existing domain (rare), or a new domain dir (needs user approval — surface as a question, never auto-create).

### 4. Triage candidates by autonomy boundary

- **Auto-ingest** high-confidence within-domain candidates — an existing-page update or a new page inside an existing domain, each tied to a concrete file. No prompt; they land autonomously and appear in the final report.
- **Gate via `AskUserQuestion`** only candidates that cross an autonomy boundary:
  - a new domain dir (`ingest-finding` would create a top-level domain)
  - a `> Contradicts:` that needs resolution against an existing page
- Insight graduation (a finding meeting all 4 criteria) is **not** gated — `ingest-finding` graduates it autonomously after the diff log.
- Show 1-line summaries; multi-select OK. If nothing is gated, skip the prompt and ingest directly.

| Action | LLM alone | Needs user confirm |
|---|---|---|
| Read merge diff + PR comments | ✅ | — |
| Derive ingest candidate list | ✅ | — |
| Update existing wiki page (via `ingest-finding`) | ✅ | — |
| Add new wiki page inside existing domain | ✅ | — |
| Graduate a finding to `.llmwiki/insight/` (all 4 criteria) | ✅ | — |
| Add new wiki domain dir | ❌ | ✅ |
| Resolve a `> Contradicts:` against an existing page | ❌ | ✅ |

### 5. Ingest each cleared candidate

For each candidate cleared to ingest (auto-ingested within-domain + any gated candidate the user accepted), invoke `/llm-wiki:ingest-finding` (or run its steps inline if already loaded). The ingest skill handles the diff-log + cross-update discipline and applies v2 frontmatter defaults (`status: active`, inferred `volatility:`, `sources:`) to any new page.

### 6. Final report

- Pages updated (with `last_verified:` bump count)
- New pages added (with their `status` / `volatility` / `sources` defaults)
- Insight graduations, if any (`.llmwiki/insight/` entries, with `promoted_from:`)
- `log.md` entry written, header: `## YYYY-MM-DD — post-merge <PR#> (post-merge)`

```text
## Post-merge ingest — PR #<N> (<MERGE_SHA>)

Candidates (file → finding → evidence):
- <touched-file> → <1-line finding> → <evidence-file>

Auto-ingested: <list> | Gated→accepted: <list> | Skipped: <list>

Result:
- Pages updated: <domain>/<page>.md (last_verified bumped)
- Pages added: <domain>/<page>.md (status: active, volatility: <inferred>, sources: N)
- Insight graduated: <slug>.md (promoted_from <wiki-id>) | none
- log.md: ## YYYY-MM-DD — post-merge #<N> (post-merge)
```

## Routing dedup (vs Steps 6-7)

This step runs after config + Serena integration so it can avoid double-recording (see the knowledge-routing boundary in `core-principle.md`):

- A learning already woven into `CLAUDE.md` / `AGENTS.md` / `.claude/rules/` / Serena as a **mechanical / tool-operation rule** does NOT get re-recorded as wiki lore. Mechanical rule → normative doc; lore → wiki. One home each.
- If a finding is genuinely *both* (a rule with non-obvious rationale), the **rule text** lives in the normative doc and the **rationale/story** is the wiki lore — they are different facts, not duplicates. Cross-link rather than copy.
- A finding that meets the graduation bar graduates to `.llmwiki/insight/` (read by Claude + Codex via the prompt-inject hook), **not** to `.claude/rules/`.

## Verification

- The resolved root's `log.md` has a new `## YYYY-MM-DD — post-merge <PR#> (post-merge)` entry citing the merge SHA + PR #.
- Pages touched have `last_verified: <today>`.
- New pages carry v2 frontmatter defaults.
- No raw `[[wikilink]]` introduced (typed grammar only).
- The user approved any *gated* candidate (new domain / contradiction); within-domain ingests and insight graduations proceed autonomously.
- Every ingested candidate maps to a concrete file in `git show --diff-merges=first-parent --name-only`.

## Anti-patterns

- **Auto-create a new domain / resolve a contradiction without review** — these cross an autonomy boundary.
- **Ingest every trivial fix** — the wiki becomes a churn log instead of a synthesis layer.
- **Skip the diff log** — `ingest-finding` requires the `log.md` entry first; don't shortcut it.
- **Concept-based candidate derivation** — never propose a page from PR title/body phrasing alone; tie every candidate to a file in `git show --diff-merges=first-parent --name-only`.
- **Re-record a config rule as lore** — respect the routing boundary; each fact has one home.
