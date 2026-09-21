# Wiki Log

Append-only event log for the resolved wiki root (`.llmwiki/wiki/`, or a legacy `.claude/wiki/` if that is what the repo has). Each entry under a `## YYYY-MM-DD — <one-line summary>` header. Newest first.

Every `/ingest-finding` run and every `/dev:post-merge` run that executes the wiki ingest step writes a block here **before** touching the page, so `git revert` of the resulting commit cleanly reverses both. (Post-merge skips the ingest — and this log — for trivial merges or when no wiki root resolves.) See `ingest-finding` skill for the diff-log discipline.

---

<!-- New entries go directly under this line -->

## 2026-09-21 — the churn test reads position as authorship, which prose breaks (post-merge #260)

- guards/review-loop-churn.md: added the position-as-authorship rule to `## Stopping it` (a prose iteration rewrites whole paragraphs and reproduces their lines, so a new defect class is charged as churn; judge prose by the outside-the-diff axis and let `iteration_cap` be the backstop), added the PR #254 measurement to `## Evidence` (stopped at iter 3 on four findings, three real, one of them the premise the change rested on), `last_verified` 2026-09-11 -> 2026-09-21, `sources` 4 -> 6
- index.md: broadened the guards hook

## 2026-09-21 — CodeRabbit obeys the PR head's config, not the base's (post-merge #259)

- guards/coderabbit-config-branch.md: new page — measured across two PRs while `main` kept `reviews.auto_review.enabled: false`: #254's head carried the key and CodeRabbit skipped, #259's head removed it and CodeRabbit auto-reviewed; a re-enable (and a disable) is therefore live inside its own PR, `cr-review-request.sh` reading the working tree agrees with that, and disabling auto-review drops cr-fix to a single reviewer with nothing in its final JSON recording the absence; sources: PR #254, PR #259
- index.md: added the guards hook

## 2026-09-21 — worker scope is an isolation problem, not a git-forensics one (post-merge #254)

- guards/worker-scope-attribution.md: new page — `git status --porcelain` records tree state and not the actor, so a shared checkout leaks worker attribution six ways (dirty / staged / untracked / ignored / committed / quoted paths); `isolation: worktree` makes the branch the per-worker record and the check one `git log --no-renames -z --name-only` against the recorded base (two dots, never `git diff ...`, merge commits rejected first); isolation costs the ignored inputs it protects; the git-level gate cannot see a write through a symlink created and removed within the run; sources: PR #254, its Codex review (16 of 17 findings held only under the shared-checkout premise), `orchestrate/SKILL.md` steps 4-5
- index.md: added the guards hook

## 2026-09-17 — bot login matching: stem fixes the two spellings and opens spoofing (post-merge #228)

- guards/bot-identity-matching.md: new page — two spellings per surface (GraphQL strips `[bot]`, REST keeps it), equality → silent zero, unanchored stem → registrable lookalike (`coderabbit-evil`) reaching a loop that edits code, `^<login>(\[bot\])?$` as the only closing form (`[`/`]` are illegal login characters), jq double-escape, `sort_by | last` turning a spoof into a wrong success, anchoring's silent-zero cost paid by regression tests; sources: PR #228, its CodeRabbit review
- index.md: added the guards hook

## 2026-09-15 — agent-definition `effort:` field and per-tier worker presets (post-merge #227)

- runtimes/agent-definition-effort.md: new page — undocumented `effort:` frontmatter (`low`/`medium`/`high`/`xhigh`/`max`, silent downgrade on unsupporting models), `Agent` tool overrides `model` only, hence the four `dev:worker-*` preset files; sources: official `claude-security` agents, CLI 2.1.272 binary enum, commit 98f36f5
- index.md: added the runtimes hook

## 2026-09-15 — vendor-neutral data folder for cross-runtime skill files (post-merge)

- runtimes/codex-plugin-surfaces.md: added the `.agents/` placement rule from `docs:vp`, noted that plaud-note-taking still keeps its dictionary under `.claude/`, `last_verified` 2026-09-11 -> 2026-09-15, `sources` 3 -> 4

## 2026-09-11 — review-loop churn: the stop rule shipped and still did not stop (ingest-finding)

- guards/review-loop-churn.md: rewrote the body as the distilled stop rule (whole-loop churn measurement, defer-floor dependency, enforced cap), compressed both occurrences into `## Evidence`, added PR #223 + issue #225 sources, `last_verified` 2026-09-04 -> 2026-09-11, `sources` 2 -> 4
- index.md: updated the guards hook to the broadened rule
- insight/review-loop-churn.md: graduated (4 promotion criteria met across PR #213 and PR #223)
- insight/index.md: added the entry hook

## 2026-09-04 — bootstrap (bootstrap-wiki)

Re-bootstrapped after the 2026-08 restructure removed the previous tree. Domains: plugins, guards, runtimes. Seeded three pages from the 2.30.0 consolidation work (#213, #214, #216).
