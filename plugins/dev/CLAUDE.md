# GitHub Dev Plugin

GitHub workflow automation for Claude Code and Codex: 12 skills, 3 worker agents, no command surface, so every `/dev:<name>` call resolves to a skill on both runtimes. The skills need an authenticated `gh` CLI and a GitHub repository the user can push to.

dev owns the back half only: from a PR ready for review to merge and cleanup. The front half (idea → spec → tickets → implementation → PR) is Matt's skills (`mattpocock-skills`, `/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement-spec` or `/implement`); bug diagnosis is Matt's `/diagnosing-bugs`, and lessons go to `/retro` in the session that built the change. `/dev:flow` routes across both halves.

## Skills

| Skill | Description |
|---------|-------------|
| `/dev:commit-and-push` | Analyze the given files, commit with a Conventional Commits message, push |
| `/dev:post-merge` | Cleanup after a merge: leftover review findings, safe worktree and branch removal through `skills/post-merge/scripts/collect-cleanup.sh`, issue close, Project status, About line, commit. Records no lessons (`/retro` does) |
| `/dev:review-loop` | CodeRabbit + ChatGPT-Codex review loop on an open PR; see `## review-loop` below |
| `/dev:release` | Bump the version manifests, tag, and create a GitHub release with generated notes (`CHANGELOG.md` is `post-merge` Step 9.5 + `docs:changelog`) |
| `/dev:session-handoff` | End-of-session handoff summary in chat; writes no file, updates no memory |
| `/dev:orchestrate` | Subagent discipline: job cards, `dev:worker-standard/deep/max` presets, one writer per path, worktree isolation with a `git log --no-renames -z --name-only --pretty=format: <base>..<worker branch>` scope check, a verified per-agent ledger |
| `/dev:flow` | Router over the whole flow (Matt front half, dev back half, branches, one-time repo setup). Points, never acts; stays implicitly invocable |
| `/dev:new` | Day-1 bootstrap of an empty directory (`references/new-procedure.md`) |
| `/dev:wiring` | Read-only harness diagnosis of an existing repo, edits behind a confirmation gate |
| `/dev:e2e-setup` | Playwright E2E harness setup (agents, MCP entry, config, CI workflow) |
| `/dev:e2e-author` | Plan, generate and burn in E2E specs through the planner and generator roles |
| `/dev:e2e-debug` | Trace-first healing of a failing E2E test, bounded to 3 attempts |

## review-loop

The loop and its bright lines live in `skills/review-loop/SKILL.md`; the CodeRabbit / Codex coordination (tiers, HEAD verdicts, stop states, merge gate, PR-comment budget) is in `skills/review-loop/references/coordination.md`, and the flags in `skills/review-loop/references/arguments.md`.

`final_state` enum: `clean`, `user_declined`, `minor_floor`, `churn`, `iteration_cap`, `timeout`, `failure`, `cr_inactive`, `rate_limited`, `cli_failed`, `reviewers_unavailable`, `codex_failed`, `ci_failing`, `merged_externally`, `unknown` (triggers: `skills/review-loop/references/failure-modes.md`).

The recommended `.coderabbit.yaml` keys and the CodeRabbit CLI install are in `docs/coderabbit-config.md`.

## Worktree Workflow (PR-based)

Use Claude Code's built-in worktree (`claude --worktree <name>`) for isolated PR work:

```bash
claude --worktree feature-auth
# inside the worktree: build the change (Matt /implement) and open the PR
/dev:review-loop            # drive the review loop on that PR
/dev:post-merge <PR>        # after the PR merges on GitHub, still inside the worktree
# post-merge works on the main repo and prints, as its last line:
#   cd "<main repo>" && git worktree remove "<worktree>" && git branch -d "<branch>"
# run that line after leaving the worktree session
```

Inside a worktree, `post-merge` runs every git step against the main repo (`git -C "$MAIN_REPO"`) and copies the worktree's review-loop state into the main repo's `.claude/state/archive/`. It never removes the worktree itself, because on Windows a worktree removed from inside itself is only half deleted.

## gh / jq Invariants

Every bash block in this plugin shells out to `gh` and `jq`. These pitfalls break a new block without an error.

- **Windows `jq.exe` ends output lines in `\r\n`**: `$(...)` drops one trailing `\r`, but a pipe (`sort`, `tr`, `while read`, a second `jq`) keeps it and string compares fail. A script that calls `jq` sources `scripts/jq-lf.sh` from its own directory when present; the helper strips `\r` from output only and keeps jq's exit status. Inline bash blocks in skill bodies are not covered yet.
- **A bot login has two spellings**: GraphQL (`gh pr view --json comments,reviews`, `gh api graphql`) returns `coderabbitai`, REST (`gh api repos/{owner}/{repo}/issues/<N>/comments`, `.../pulls/<N>/reviews`, `.../reactions`) returns `coderabbitai[bot]`. An equality filter returns zero rows on one surface, which reads as "not reviewed yet": an endless wait or a false `clean`.
- **Match the login anchored at both ends**: `select((.user.login // "") | test("^coderabbitai(\\[bot\\])?$"; "i"))`. An unanchored stem (`test("coderabbit"; "i")`) also matches `coderabbit-evil`, a registrable login that could then feed review text into the loop; `[` and `]` are not login characters, so the suffix cannot be forged.
- **Keep the jq escapes and the null guard**: `"\\[bot\\]"` needs the double backslash, or `[bot]` becomes a character class. `// ""` keeps a deleted account's null `user` from aborting the program. A renamed bot account returns zero rows again, so `skills/review-loop/tests/run-tests.sh` covers both spellings.
- **Host is a field, not a default**: `gh api` targets `github.com` whatever the remote says, unless `--hostname <host>` or `--repo [HOST/]OWNER/REPO` names it. A step that reaches a repository named in text states the host from a URL it holds, on the read and on the matching write. `gh issue view` and `gh issue close` take a URL, which carries its host.
- A `gh api` REST path uses gh's literal `{owner}/{repo}` placeholder, never `$OWNER/$REPO` unless the skill sets them; an unset pair calls `repos//pulls/...` and returns nothing. `gh pr view/diff <N>` carry no repo coordinates at all.
- `gh ... --jq <expr>` takes one filter and does not forward `--arg` or `--argjson`. Inject variables with the pipe form `gh ... | jq --arg name "$value" '...'`; the other form fails with `accepts 1 arg(s), received 4`.
- REST lists (`/pulls/{pr}/reviews`, `/issues/{pr}/comments`, `/commits/{sha}/statuses`) page at 30. Slurp every page before filtering: `gh api --paginate ... | jq -s 'add // []' | jq ...`.
- `/commits/{sha}/statuses` (plural) returns every status event; `/status` (singular) keeps one per context and hides early `pending` entries. Use the plural form when the first moment a SHA was seen matters.
- `committer.date` is git metadata that cherry-picks and rebases make arbitrarily old. "When GitHub first saw this SHA" is the earliest `/statuses` `created_at`; `committer.date` is the fallback only when no status exists.

## new and wiring

`new` seeds an empty directory on Day 1 (`.claude/`, `CLAUDE.md`, `AGENTS.md`, README/CHANGELOG, `gh repo create` + push). `wiring` is its inverse: it diagnoses an existing repo read-only and edits only behind a confirmation gate. Both are skills only; Codex reads no command surface.

- **Preflight hard guard**: `skills/new/SKILL.md` Step 0 aborts when cwd holds anything besides `.git/`, `.DS_Store`, `Thumbs.db` or `desktop.ini`, searched 5 levels deep. It is pure `find` and runs before the `PLUGIN_ROOT` resolver, so a failed resolve cannot skip it. Removing it is an explicit user decision.
- **Detection SSOT**: `scripts/project_state.sh` alone detects project state (read-only, one JSON blob, 14 axes). `idempotent-seed.sh diagnose` wraps it for the legacy fields and re-implements nothing.
- **Decisions are `ASK`, not defects**: `git remote` and `gws-sync` answers go to `answers` in gitignored `.claude/state/wiring.json`, and wiring never re-asks an answered key. Every `ASK` has a step that asks (wiring Step 3.5); an unrecorded `ASK` is not a "no".
- **One place per suppression condition**: the `gws_sync` verdict also reads `.gws-sync.json` and the `gws` CLI, so its condition lives in the verdict table only.
- **Out of reach on purpose**: orphan MCP registrations need usage history and belong to `/doctor`. Duplicate registrations and their drift (`duplicates_drifted`) are key and value comparisons, so wiring reports them.
- **Owner per defect**: wiring fixes only mechanical, reversible edits (a `.gitignore` line, `.tmp/`, `core.hooksPath`, serena `project_name`) and names the owning skill for the rest. Wiki-page health belongs to `/wiki:lint`.
- **Owner gate**: `new` never infers the GitHub owner; the user picks it explicitly.
- **Idempotent re-runs**: existing files are kept, steps skip with a notice, nothing is overwritten. The hard guard makes this matter only on the recovery path of a partial seed.

`project_state.sh` rules for contributors:

- `find` exits 1 on "not found", so under `pipefail` every `find` goes through `find_or_empty` / `count_files`, and `code_signal` uses `-print -quit` to avoid a `head` SIGPIPE.
- A `jq` failure on one corrupt user config must fail that axis only (like `mcp.unreadable`), never the whole report. "Did not see it" is never reported as "no problem".
- A value scraped for `jq --argjson` is normalized first: TOML allows `65536 # bytes` and `_` separators. Non-digits fall back to the documented default.
- The Codex config lives at `${CODEX_HOME:-$HOME/.codex}`; a hardcoded `$HOME/.codex` reports `config: false` wherever `CODEX_HOME` is set.

## Cross-runtime plugin root

`references/new-procedure.md` Phase 0 opens with the `PLUGIN_ROOT` resolver: `${CLAUDE_PLUGIN_ROOT}` on Claude Code, otherwise the newest `~/.codex/plugins/cache/<marketplace>/dev/<version>/` (override with `CODEX_PLUGIN_CACHE` or `PLUGIN_ROOT`).

Later blocks use `${PLUGIN_ROOT}/scripts/...` and `${PLUGIN_ROOT}/assets/...`, so a new asset or script changes only the procedure file.

The sort key is the version basename, not the whole path: a whole-path sort ranks `zeta/dev/0.4.0` above `alpha/dev/0.10.0`, with or without `-V`. The `sort -V` probe falls back to a numeric dotted-field sort, never plain `sort`, which ranks `0.6.1` above `0.10.0`.

## Seed templates

The templates under `assets/` use only these placeholders (sed substitution in `references/new-procedure.md` Phase 4/5):

| Placeholder | Meaning |
|-------------|------|
| `{{PROJECT_NAME}}` | project name (Phase 1 answer) |
| `{{ONE_LINER}}` | one-line description |
| `{{OWNER}}` | personal account or org name |
| `{{LICENSE}}` | MIT / Apache-2.0 / GPL-3.0 / None |
| `{{YEAR}}` | current year |

A new placeholder needs a matching sed line in Phase 4/5.

The three `AGENTS.review-guidelines*.md` variants share one skeleton: `## Project context`, `## Build / Test / Lint`, `## Code Review Rules` (`### Do not flag`, `### P0`, `### P1`, `### Domain-specific`), `## CodeRabbit / Codex 조율`, `## 완료 보고`, `## Anti-patterns`. They differ only in `### Domain-specific` and 1-2 items in `### P0` / `### P1`. `## Code Review Rules` is what the Codex GitHub cloud reviewer reads, so it is seeded at repo creation to apply from the first PR.

Not seeded: CI workflows, pre-commit hooks, boilerplate downloads (`scout:research-orchestrator` is separate), per-language interview branches.

## File layout

```text
plugins/dev/
├── .claude-plugin/plugin.json
├── agents/worker-{standard,deep,max}.md   # orchestrate presets (model + effort in frontmatter)
├── assets/                                # seed templates + e2e scaffolds
├── docs/coderabbit-config.md              # recommended .coderabbit.yaml + CLI install
├── references/
│   ├── new-procedure.md                   # new: Phase 0-7
│   └── role-contracts.md                  # e2e planner / generator / healer contracts
├── scripts/                               # project_state.sh, idempotent-seed.sh, infer-github-context.sh, jq-lf.sh
├── skills/<name>/SKILL.md                 # 12 skills; post-merge and review-loop carry references/, scripts/, tests/
├── tests/resolver_smoke.sh                # e2e-setup Step 0 resolver
└── CLAUDE.md                              # this file
```
