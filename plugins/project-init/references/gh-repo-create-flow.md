# gh repo create — Owner inference + Visibility decision tree

The decision context for the `/project-init:new` Phase 1 interview and Phase 6 repo creation.

## Owner inference (not automatic, interview required)

It is common for a user to hold a personal account plus side-project/employer orgs at once, so **never auto-decide the owner**. Collect candidates with `gh api` and take the choice via `AskUserQuestion`.

### Candidate-collection commands

```bash
# Personal account
PERSONAL=$(gh api user --jq '.login')

# Orgs (paginated)
# gh CLI refuses --slurp and --jq together, so pipe the --slurp output to a
# local jq. --paginate alone + --jq makes jq receive a separate JSON document
# per page, leaving only the first page at the page boundary on multi-page
# results (an actual finding from PR #24).
ORGS=$(gh api --paginate --slurp /user/orgs | jq -c '[.[][].login]')
```

> Used alone, `--paginate` streams results beyond 30 as multiple documents, so
> `--jq` catches only the first page. Bundling them into an array-of-arrays with
> `--slurp` and flattening with `jq '[.[][].login]'` is the portable, correct pattern.

### Decision tree

```
Q: "Where to create the repo?"
├─ {personal_login}                     [Personal]
├─ {org1}                                [Organization]
├─ {org2}                                [Organization]
└─ ...
```

Spell out "Personal" / "Organization" in each option's description — so the user is not confused when two orgs have similar names.

## Visibility decision

```
Q: "Visibility?"
├─ Private (Recommended)
├─ Public
└─ Internal     ← shown only for an org owner (personal accounts cannot use internal)
```

Why the recommended default is Private:
- A new project may contain not-yet-cleaned secrets / debug commits / WIP code. Switching to public later is one line (`gh repo edit --visibility public`), but after a public → private switch you cannot recall forks.
- Even if the intent is public OSS, keeping it private for the first week and switching after cleanup is the safe pattern.

> Command to switch to public: `gh repo edit {{OWNER}}/{{PROJECT_NAME}} --visibility public --accept-visibility-change-consequences`

## License decision

License is independent of visibility (a private repo can carry a license too).

| Option | When |
|--------|------|
| **MIT** (Recommended) | simple permissive, highest compatibility |
| **Apache-2.0** | when an explicit patent grant is needed |
| **GPL-3.0** | copyleft intent (forces derivatives to stay GPL) |
| **None** | when deliberately not setting a license (for a private repo, effectively "all rights reserved") |

The `--license <name>` flag of `gh repo create` can auto-generate a LICENSE file (using a template). Omit it when the license is None.

```bash
# Auto-seed the license
gh repo create "${OWNER}/${PROJECT_NAME}" \
  --${VISIBILITY,,} \
  --description "${ONE_LINER}" \
  --license "${LICENSE}" \
  --source=. --remote=origin --push
```

> Limitation: `gh repo create --license` auto-generates the license file only for an empty repo (no code). Combined with `--source=.` there are already commits, so license auto-generation may not happen — in that case seed it separately with `gh api -X POST /repos/.../contents/LICENSE` or advise the user to do it manually. In V1, just pass `--license` in the command and ignore failure (advise the user).

## Push flow

```bash
# 0. git init (skip if .git already exists)
[ -d .git ] || git init -b main

# 1. Stage all seed files
git add .claude/ CLAUDE.md AGENTS.md README.md CHANGELOG.md

# 2. Initial commit
git commit -m "chore: bootstrap project skeleton via project-init"

# 3. gh repo create + auto push
gh repo create "${OWNER}/${PROJECT_NAME}" \
  --${VISIBILITY,,} \
  --description "${ONE_LINER}" \
  --source=. --remote=origin --push
```

`--source=.` designates the current directory as the git source. `--remote=origin` registers the `origin` remote automatically. `--push` pushes the current branch.

## Recovery on failure

| Failure | Recovery |
|------|------|
| `gh repo create` — repo name collision | retry Phase 1 (pick a different name). The local commit is preserved as-is. |
| `gh repo create` — insufficient permission (not an org member) | suggest re-choosing the owner in Phase 1. |
| Push failure — network / auth | advise the manual `git remote add origin ...` + `git push -u origin main` commands. |
| Initial commit failure — missing gitignore | check whether a temporary `.env`, `node_modules/`, etc. got staged. `.gitignore` seeding is outside V1 scope, so the user handles it explicitly. |

## Idempotency

On a second `/project-init:new` invocation in the same directory:
1. If `.git` already exists, skip `git init`.
2. If any of AGENTS.md / CLAUDE.md / README.md / CHANGELOG.md already exists, skip that file in Phase 4 / 5 and print a notice.
3. If `.claude/` already exists, add only the Phase 2 `.gitkeep` (the directory structure itself is preserved).
4. If the `gh repo` already exists — confirm with `gh repo view ${OWNER}/${PROJECT_NAME}`, then ask the user "wire only the remote?".

This guard is handled by `scripts/idempotent-seed.sh`.
