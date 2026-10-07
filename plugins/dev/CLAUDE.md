# GitHub Dev Plugin

GitHub workflow automation skills for Claude Code. All workflows are skills (no command surface), so `/dev:<name>` slash calls resolve to the skill and run under both Claude Code and Codex.

dev owns the back half only: from a PR ready for review to merge and cleanup. The front half (idea → spec → tickets → implementation → PR) is Matt's skills (`mattpocock-skills`, `/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement-spec` or `/implement`); bug diagnosis is Matt's `/diagnosing-bugs`, and lessons go to `/retro` in the session that built the change. `/dev:flow` routes across both halves.

## Skills

| Skill | Description |
|---------|-------------|
| `/dev:commit-and-push` | Analyze changes, commit with conventional message, push |
| `/dev:post-merge` | Cleanup only after a merge: surface leftover review findings, switch to base, delete the merged branch, close the issues the merge left open, sync the GitHub Project status, check the repo About line, commit. Records no lessons (`/retro` does); README / CHANGELOG edits are one-line pointers to `docs:readme` / `docs:changelog` |
| `/dev:cr-fix` | Unified CodeRabbit + ChatGPT-Codex review loop (multi-file skill at `skills/cr-fix/`): pre-flight detects which reviewers are engaged, then wait + fetch + judge + apply + push per iteration. Each finding is validated against local code and severity-reassessed, then applied, deferred or skipped autonomously (no per-finding confirmation). CodeRabbit headers are read by emoji badge whatever the emphasis (`scripts/cr-header.jq`), and the "Outside diff range comments" in review bodies are collected as findings too. Tiers are severity-first: Security always gated, Critical/High/Major gated, Minor + Heavy lift gated, Minor + Quick win auto, Trivial/Info and Nitpicks skipped; Codex P0-P2 gated on iter 1, and a Codex P2 from iter 2 on is deferred unjudged to the follow-up issue. With a passing build/test baseline, each fix is built and tested before the commit and a failing one is reverted and deferred. No round fetches, judges, pushes, ends or merges before every reviewer that is on has given HEAD a verdict (findings or clean; ADR 0002): a progress mark, a rate-limit notice or a review pause is not one, so a stop reached right after a push is held until its verdicts arrive, a new gated finding earns one more round, and a spent wait budget ends at `timeout` (or the held state) with auto-merge off. Codex reporting Failed on HEAD stops at `codex_failed` without any PR comment. The loop stops on `clean`, a low-severity floor (`minor_floor`), churn (findings only on the previous iteration's lines — code only, since a prose rewrite reproduces its own lines — or outside the PR diff), or the iteration cap, and files one follow-up issue (`tbd` label) when `final_state` is `churn` / `minor_floor` / `iteration_cap` / `user_declined` / `clean` / `timeout` and something was deferred in any cycle or HEAD was left without every verdict. `--auto-merge` (default OFF) merges only `clean`, `minor_floor` or `churn`, only with the follow-up issue filed whenever anything was deferred, and only when every reviewer that is on gave HEAD a verdict. `final_state` enum: `clean`, `user_declined`, `minor_floor`, `churn`, `iteration_cap`, `timeout`, `failure`, `cr_inactive`, `rate_limited`, `cli_failed`, `reviewers_unavailable`, `codex_failed`, `unknown` (triggers: `skills/cr-fix/references/failure-modes.md`). `--cr-source` selects the review source; `auto` falls back to the local `coderabbit` CLI or Codex-only when the PR bot is rate-limited. Same-file generalization (default ON) patches sibling occurrences of a real, high-confidence, grep-able finding within the same file. Before iter 1 it reads the PR comments for a reviewer's "will not review" signal (Codex usage limit, CodeRabbit auto-review disabled): one down drops that reviewer for the run, both down stops at `reviewers_unavailable` with no waiting and no auto-merge. A draft PR stops with a `gh pr ready` hint, since CodeRabbit skips drafts. A `CONFLICTING` PR gets `origin/<base>` merged and resolved hunk by hunk inside the loop. The skill posts no PR comment except the `@coderabbitai rate limit` query and at most one `@coderabbitai review` per head SHA, posted only for a non-default base CodeRabbit will not auto-review (unless the repo set `auto_review.enabled: false`) or when CodeRabbit has paused automatic reviews (`auto_pause_after_reviewed_commits`); a re-run finds the earlier request in the PR comments and skips. It never posts `@codex review`; otherwise re-review is triggered by the push. |
| `/dev:release` | Bump the version manifests, tag, and create a GitHub release with auto-generated release notes (does not touch `CHANGELOG.md` — that is `post-merge` Step 9.5 + `docs:changelog`) |
| `/dev:session-handoff` | End-of-session handoff summary (decisions, shipped changes, key files, running state, verification, deferrals) so a fresh agent continues from chat alone. Chat-only: writes no file, updates no memory |
| `/dev:orchestrate` | Subagent orchestration discipline: one job card per slice (goal, scope, absolute paths, inputs, output shape, done criteria, preset), model x effort worker presets `dev:worker-standard/deep/max` (sonnet medium / opus high / opus xhigh), one writer per path, quality gate with bounded re-query (2x same agent, 1x next preset up, then the user), orchestrator runs the verification itself and reports a per-agent ledger. `Workflow` only on a manual `/dev:orchestrate` call; every writing slice runs under `isolation: worktree`, so the scope check is one `git log --no-renames -z --name-only --pretty=format: <base>..<worker branch>` against that card's owned Paths and a branch that exceeds them is dropped rather than reverted; `git worktree list` baseline cleanup gate |
| `/dev:flow` | Short router over the whole flow: Matt front half (`/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement-spec` or `/implement`, detail via `/ask-matt`) then dev back half (`/dev:cr-fix` → merge → `/dev:post-merge` → `/retro`), plus the branches (bug → `/diagnosing-bugs`, no PR, ad-hoc parallel work → `/dev:orchestrate`, small ambiguous request, wiki ingest / query, worktree, non-default base, E2E) and the one-time product-repo setup (Matt setup + five triage labels). Points, never acts; stays implicitly invocable |

## cr-fix Flags

Full table: `skills/cr-fix/references/arguments.md` (`--auto-merge`, `--max-iterations`, `--codex-grace`, `--no-codex`, `--skip-minor`, `--no-minor-stop`, `--no-generalize`, `--cr-source`, ...).

## Worktree Workflow (PR-based)

Use Claude Code's built-in worktree (`claude --worktree <name>`) for isolated PR work:

```bash
claude --worktree feature-auth
# inside the worktree: build the change (Matt /implement) and open the PR
/dev:cr-fix                 # drive the review loop on that PR
/dev:post-merge <PR>        # after the PR merges on GitHub, still inside the worktree
# post-merge works on the main repo and prints, as its last line:
#   cd "<main repo>" && git worktree remove "<worktree>" && git branch -d "<branch>"
# run that line after leaving the worktree session
```

**Note:** `post-merge` inside a worktree runs every git step against the main repo (`git -C "$MAIN_REPO"`), copies the worktree's cr-fix state into the main repo's `.claude/state/archive/`, and leaves the worktree and branch removal to the printed command. It never removes the worktree itself: on Windows a worktree removed from inside itself is only half deleted.

## Requirements

- `gh` CLI installed and authenticated
- GitHub repository with proper permissions

## gh / jq Invariants

All commands in this plugin shell out to `gh` and `jq`. Six pitfalls that silently break new bash blocks:

- **A bot login has two spellings and the surface decides which one you get.** GraphQL (`gh pr view <N> --json comments,reviews`, `gh api graphql`) strips the `[bot]` suffix; REST (`gh api repos/{owner}/{repo}/issues/<N>/comments`, `.../pulls/<N>/reviews`, `.../pulls/<N>/comments`, `.../issues/<N>/reactions`) keeps it. On one live PR: `gh pr view 116 --json comments --jq '.comments[].author.login'` printed `coderabbitai`, while `gh api repos/OWNER/REPO/issues/116/comments --jq '.[].user.login'` printed `coderabbitai[bot]`. An equality filter therefore matches on one surface and returns zero rows on the other — and zero rows reads exactly like "the bot has not reviewed yet", so the loop waits forever or exits as a false `clean`. Match on an anchored pattern that admits both spellings and nothing else: `select((.user.login // "") | test("^coderabbitai(\\[bot\\])?$"; "i"))`. Anchor both ends — an unanchored stem (`test("coderabbit"; "i")`) is a substring match, and `coderabbit-evil` is a registrable GitHub login that anyone can use to comment on a public PR, which hands an outside account a write path into a loop that applies review text to code. The `(\\[bot\\])?$` tail is safe to pin because `[` and `]` are not legal login characters, so the suffix form cannot be forged. Note the jq double-escape: `"\\[bot\\]"` — one backslash makes `[bot]` a character class that silently matches something else. The trade-off is that pinning the full login brings back the silent zero the stem match fixed: the day a bot renames its account, the filter returns 0 rows, which is indistinguishable from "has not reviewed yet" (infinite wait or a false `clean`). The regression tests in `skills/cr-fix/tests/run-tests.sh` are the contract that keeps both spellings covered. The `// ""` is load-bearing — a ghost or deleted account carries a null `user`, and `null | test(...)` aborts the whole jq program.

- **Host is a field, not a default.** `gh api` talks to `github.com` whatever the local remote says (`--hostname` is what changes it), and `--repo owner/repo` resolves the same way; both accept the host explicitly (`--hostname <host>`, `--repo [HOST/]OWNER/REPO`). Any step that reaches a repository named in text rather than inferred from the checkout must state the host, taken from a URL it already holds. The failure that survives one round of fixing is the asymmetric one: pinning the host on the read call and leaving the matching write call unqualified reads state from one server and writes to another, same number, no error. An issue or PR URL carries its own host, so passing the URL avoids the assembly entirely — `gh issue view` and `gh issue close` both take `{<number> | <url>}`.
- A `gh api` REST path in a skill body must use gh's literal `{owner}/{repo}` placeholder (auto-resolved from the current repo) — never `$OWNER/$REPO` shell vars unless that skill demonstrably sets them. A skill step that interpolates an unset `$OWNER`/`$REPO` calls `repos//pulls/...` and fails silently or returns nothing. Prefer `gh api "repos/{owner}/{repo}/pulls/<N>/files"` (or `gh pr view/diff <N>`, which carry no repo coordinates) over raw-var REST.
- `gh ... --jq <expr>` accepts a single filter string and does NOT forward jq CLI flags (`--arg`, `--argjson`). Variable injection requires the pipe form: `gh ... | jq --arg name "$value" '...'`. Trying `gh ... --jq --arg name "$v" '...'` fails with `accepts 1 arg(s), received 4`.
- REST endpoints (`/pulls/{pr}/reviews`, `/issues/{pr}/comments`, `/commits/{sha}/statuses`) default to `per_page=30` and return paginated results. On long-lived PRs or CI-heavy SHAs the first page can be all-old or all-newest-30 — use `gh api --paginate ... | jq -s 'add // []' | jq ...` to slurp every page into a single array before filtering.
- `/commits/{sha}/statuses` (plural) returns every individual status event; `/commits/{sha}/status` (singular) collapses to one latest entry per context. The singular endpoint hides early `pending` entries, so use plural when the earliest moment a SHA was observed matters.
- Commit `committer.date` is git metadata — cherry-picks, rebases, or stale-commit pushes make it arbitrarily older than the actual push. For "when did GitHub first see this SHA" use the earliest `/statuses` `created_at`; `committer.date` is acceptable only as a last-resort fallback when no statuses exist yet.

## Agent Tool Syntax

This plugin dispatches Claude Code's built-in agents through the Agent tool:

```
Agent(
  subagent_type="Explore",
  prompt="..."
)
```

### Model Selection Guide

| Task Type | Agent | Model |
|-----------|-------|-------|
| Code search | `Explore` | auto |
| Implementation | `claude` | `sonnet` |
| Complex refactoring | `claude` | `opus` |
| Test writing | `claude` | `sonnet` |
| Validation | `claude` | `sonnet` |

## project-init (흡수: project-init)

Orchestrates a project's **agent-harness lifecycle**. The two directions are symmetric.

- `new` — Day-1 setup (`.claude/`, CLAUDE.md, AGENTS.md, README/CHANGELOG, gh repo create + push). **Empty directories only.**
- `wiring` — diagnoses the harness config of an already-existing repo. **The inverse of `new`.** Read-only detection, then edits only behind an `AskUserQuestion` gate.

### Surfaces

| Surface | Entry | Description |
|---------|-------|-------------|
| Skill | `/dev:new` | Explicit invocation and capability discovery on both runtimes (the separate `commands/new.md` was dropped in the 2.30.0 consolidation; a skill is the one surface Codex also reads). The description is scoped narrowly so only phrases like "bootstrap a new project in this empty dir" match. |
| Skill | `wiring` | Diagnoses an existing repo. No command surface — a `/dev:wiring` skill call is enough, and a command would not be emitted to Codex, only duplicating the body. |

`new` puts a **preflight hard guard** in the first block of the body — if `.git/`, `.claude/`, or a source file exists anywhere in cwd, abort. It does not rely on description-based matching alone; it enforces at runtime. `wiring` has no such guard (by definition it is only meaningful in a non-empty repo).

### Detection SSOT

`scripts/project_state.sh` is **solely** responsible for project-state detection. Pure read-only, emitting a single JSON blob.

- `wiring` consumes all 14 axes. Four of them look at not "does the file exist" but **"does the config actually take effect"** — `core.hooksPath` (must be turned on per clone), whether an `@import` has defeated the `paths:` scoping of `.claude/rules`, whether the same MCP server registered in two user-scope files causes one definition to be discarded wholesale, and whether Codex `AGENTS.md` fits within the `project_doc_max_bytes` budget.
- An axis that is a **decision** rather than a defect (`git remote`, `gws-sync`) is emitted as `ASK`. The answer is written to `answers` in `.claude/state/wiring.json` and the script carries it forward as-is — the skill never re-asks an already-answered item. Because values differ per machine (Drive folder ids, etc.), they stay in gitignored state, and `CLAUDE.md` keeps only a **one-line path pointer**. A warning that barks every run trains people to ignore it, and then a real `FAIL` gets buried with it.
- **An `ASK` must have a step that actually asks** (Step 3.5). If it is only stamped `(unanswered)` in the report with nowhere to ask, no answer is recorded and the next run repeats the same line verbatim — the class becomes decoration. A question closed without an answer leaves no key. An unrecorded `ASK` is not a recorded "no".
- Write a suppression condition in **one place only**. The `gws_sync` verdict is not decided by the answer alone — it also reads whether `.gws-sync.json` exists and whether the `gws` CLI is present, so the filesystem moves even after the answer is recorded. Writing the same condition three times across the verdict table, the prose, and the question step means it drifts three ways.
- **Orphan MCP registrations are not handled.** A server left behind by a deleted plugin needs usage history to judge, so it is the built-in `/doctor`'s territory. A **duplicate registration**, by contrast, is the intersection of two files' keys — and **drift** (`duplicates_drifted`) is a value comparison on that intersection — so both are pure computation. Do not pretend to catch what determinism cannot.
- `idempotent-seed.sh diagnose` wraps this script and picks out only the legacy output shape (`cwd`/`dir_name`/`git`/`seeded`/`code_signal`). It does not re-implement the detection logic.
- **The Step 0 hard guard of `new` is not absorbed here.** The guard has zero dependencies (pure `find`) and must run **before** the `PLUGIN_ROOT` resolver. Turning it into a script call would introduce a new failure mode where "the guard silently does not run if PLUGIN_ROOT resolution fails". A safety device is never moved behind a lazy-load.

`find` expresses "not found" as exit 1. Under `set -o pipefail`, `find ... | wc -l` kills the script on a legitimate empty result. Every `find` goes through the `find_or_empty` / `count_files` helpers, and `code_signal` uses `-print -quit` to avoid a `head`-induced SIGPIPE false positive.

`jq` digs the same pit. If `jq` exits non-zero on a single corrupted user config file, that failure rides up through command substitution and `set -e` kills the script — instead of failing to judge one axis, the whole diagnostic vanishes and the user sees no output at all. Confine one axis's failure to that axis (like `mcp.unreadable`) and keep emitting the rest of the diagnostic. And **never report "did not see it" as "no problem".**

When reading an external tool's value to pass to `jq --argjson`, do not trust the source format. TOML allows an inline comment after a value and a `_` separator in integers, so `65536 # bytes` scraped by `sed` is a valid config yet invalid JSON. Normalize numbers and confirm they are all digits; otherwise fall back to the documented default.

The Codex config location is `${CODEX_HOME:-$HOME/.codex}` (`codex --help`). Hardcoding `$HOME/.codex` reports `config: false` on a machine that uses `CODEX_HOME`, wiping out the approval/sandbox posture and doc-budget verdicts wholesale.

### Principles

- **Preflight hard guard is non-negotiable**: the guard is embedded in Step 0 of `skills/new/SKILL.md`. The premise is that a description alone cannot block a wrong trigger — even if the model misreads the description, runtime blocks it. Removing the guard must be an explicit (high-friction, deliberate) user decision.
- **wiring does not diagnose another owner's territory**: wiki-page health (staleness, broken links and Sources, orphans, index drift) is owned by `/wiki:lint`. wiring looks only at filesystem signals — "does a wiki exist / is it under the current `.llmwiki/` root". Overlap means the day comes when two diagnostics give different answers.
- **Name the owning skill for each defect**: a verdict with no next action is noise. wiring directly fixes only mechanical, reversible edits (a `.gitignore` line, creating `.tmp/`, `core.hooksPath`, serena `project_name`); anything needing judgment (legacy wiki migration, CLAUDE.md authoring, spec relocation, Serena onboarding, mem0 changes) is delegated.
- **Minimal seeding, explicit follow-ups**: seed only what Day 1 needs. Tech-stack-based rule generation and wiki ingest are **not invoked, only pointed to**. Generating generic content in an empty project imposes an overwrite cost on the user.
- **Owner gate is mandatory**: since the user has a personal + multiple-org context, never auto-decide the owner. Require an explicit choice via `AskUserQuestion`.
- **Codex GitHub reviewer surface**: the AGENTS.md `## Code Review Rules` section is what the Codex GitHub cloud reviewer reads automatically. It must be **seeded at repo-creation time** to take effect from the first PR.
- **Idempotent re-runs**: on a second invocation in the same directory, preserve existing files + skip steps + print a notice. Never overwrite. (But since the hard guard aborts on the mere presence of `.git`/`.claude`, an idempotent re-run does not occur on the normal path — it only matters on the recovery path for a partial seed that bypassed the guard.)

### File layout

```text
plugins/dev/
├── .claude-plugin/plugin.json
├── skills/
│   ├── new/SKILL.md                    # bootstrap skill (preflight guard + pointer)
│   └── wiring/SKILL.md                # existing-repo diagnostic (read-only detection + gated edits)
├── references/
│   ├── new-procedure.md                # the body (Phase 0–7) — shared by both surfaces
│   ├── codex-review-discovery.md       # AGENTS.md vs /review CLI
│   └── gh-repo-create-flow.md          # owner inference + visibility decision
├── assets/                             # templates that go directly into the output
│   ├── AGENTS.review-guidelines.md     # general variant (base)
│   ├── AGENTS.review-guidelines.ml.md  # ML/data variant
│   ├── AGENTS.review-guidelines.web.md # web/full-stack variant
│   ├── README.minimal.md
│   └── CHANGELOG.initial.md
├── scripts/
│   ├── infer-github-context.sh         # gh api user + orgs
│   ├── idempotent-seed.sh              # conflict guard + .claude/ + .llmwiki/ seed (diagnose = wrapper)
│   └── project_state.sh                # detection SSOT — read-only 14-axis JSON
└── CLAUDE.md                           # this file
```

### Preflight guard contract

This POSIX shell block sits in Step 0 of `skills/new/SKILL.md`:

```bash
FIRST_EXISTING=$(find . -mindepth 1 -maxdepth 5 \
  \( -name '.git' -o -path './.git/*' \
   -o -name '.DS_Store' -o -name 'Thumbs.db' \
   -o -name 'desktop.ini' \) -prune \
  -o -print 2>/dev/null | head -1)

if [ -d .git ] || [ -n "$FIRST_EXISTING" ]; then
  echo "[abort] dev:new refuses to run in a non-empty directory."
  ...
  exit 1
fi
```

- **Rejection rule**: anything in cwd that is not `.git/`, `.DS_Store`, `Thumbs.db`, or `desktop.ini` causes abort. `Dockerfile`, `Makefile`, `.env`, `docs/`, `src/app/main.py` — all of those trigger.
- **Search depth**: 5 levels (`find -maxdepth 5`). Deep-nested source files do not slip past the guard.
- **Abort message**: surfaces cwd + the first offending entry + a redirect to `/docs:write-rules` or `/dev:wiring` for the "scaffold an existing project" case.
- **Non-POSIX hosts**: PowerShell-default environments must invoke via `bash -c '<guard>'` (Git Bash / WSL / Cygwin). The intent of the check, not the literal shell, is what matters — equivalent PowerShell rewrites are acceptable as long as they refuse the same conditions.

When modifying it, update both files at once. Changing only one makes the surfaces diverge in behavior.

### Cross-runtime plugin root resolution

`references/new-procedure.md` Phase 0 opens with a `PLUGIN_ROOT` resolver:

```bash
PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$PLUGIN_ROOT" ]; then
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  if sort -V </dev/null >/dev/null 2>&1; then
    candidate=$(ls -1d "$cache_root"/*/dev/* 2>/dev/null \
      | awk -F/ '{print $NF "\t" $0}' | sort -V | tail -1 | cut -f2-)
  else
    candidate=$(ls -1d "$cache_root"/*/dev/* 2>/dev/null \
      | awk -F/ '{print $NF "\t" $0}' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1 | cut -f2-)
  fi
  [ -n "$candidate" ] && [ -d "$candidate" ] && PLUGIN_ROOT="$candidate"
fi
[ -n "$PLUGIN_ROOT" ] && [ -d "$PLUGIN_ROOT/scripts" ] || { echo "[abort] ..."; exit 1; }
```

- Under **Claude Code**, `${CLAUDE_PLUGIN_ROOT}` is set automatically and the resolver short-circuits on the first branch.
- Under **Codex**, no equivalent env var is exposed, so the resolver falls back to `~/.codex/plugins/cache/<marketplace>/dev/<version>/`. Users can override with `CODEX_PLUGIN_CACHE` or set `PLUGIN_ROOT` directly.
- **The sort key is the version basename, not the full path.** Sorting whole paths compares the marketplace directory name before it ever reaches the version, so `zeta/dev/0.4.0` beats `alpha/dev/0.10.0` — and `sort -V` does not save you, because it too starts at the first differing component. The `awk` prefix puts the version first and `cut -f2-` recovers the path. The `sort -V` probe stays for userlands that predate it (Apple's FreeBSD sort has had `-V` since 10.13, so this is rarer than it looks), and its fallback is a numeric dotted-field sort rather than plain `sort`, which would rank `0.6.1` above `0.10.0`. Same form as `plugins/dev/skills/cr-fix/SKILL.md`, whose `tests/run-tests.sh` case guards it.
- All subsequent bash blocks reference `${PLUGIN_ROOT}/scripts/...` and `${PLUGIN_ROOT}/assets/...`. Adding a new asset / script means updating only the procedure file — no per-surface duplication.

### Placeholder convention

The templates under `assets/` use only these placeholders (sed substitution):

| Placeholder | Meaning |
|-------------|------|
| `{{PROJECT_NAME}}` | project name (Phase 1 answer) |
| `{{ONE_LINER}}` | one-line description |
| `{{OWNER}}` | personal account or org name |
| `{{LICENSE}}` | MIT / Apache-2.0 / GPL-3.0 / None |
| `{{YEAR}}` | current year |

When introducing a new placeholder, update the sed lines in Phase 4/5 of `references/new-procedure.md` as well.

### AGENTS.md variant policy

The three files share the same skeleton:

1. `## Project context` — `{{PROJECT_NAME}}` + `{{ONE_LINER}}` (1-2 lines)
2. `## Build / Test / Lint` — placeholder TODO
3. `## Code Review Rules` — **the section the Codex cloud reviewer reads**
   - `### Do not flag` (linter territory — handled by tooling)
   - `### P0 — Correctness / Security`
   - `### P1 — Performance / Maintainability`
   - `### Domain-specific` (differs per variant; general has only a TODO)

The variant difference is the `### Domain-specific` section plus 1-2 domain-specific items added to `### P0` / `### P1`; nothing else differs across variants.

### Out of Scope

- CI/CD workflow seed (`.github/workflows/`) — too much per-variant variety
- Pre-commit hook seed — same reason
- Boilerplate auto-download (cookiecutter, copier) — a separate `Skill("scout:research-orchestrator")` call
- Multi-language interview branching — a single mixed Korean/English version is maintained

### References

- Plugin versioning rules: `.claude/rules/plugin-versioning.md`
- Codex GitHub integration: <https://learn.chatgpt.com/docs/third-party/github>
- Related follow-ups: `/docs:write-rules`, `/wiki:ingest`
