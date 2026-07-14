# project-init `new` — procedure

Shared procedure body for `/project-init:new` (command) and the `new` skill. Both surfaces resolve this file via `references/new-procedure.md` relative to the plugin's installed root — Claude Code exposes that root as `${PLUGIN_ROOT}`; Codex 0.135 places it under `~/.codex/plugins/cache/<marketplace>/project-init/<version>/`.

> **Trigger surface**: explicit user invocation only. No automatic trigger (running it in the wrong directory is dangerous). The preflight guard below MUST run before any destructive op — both surfaces re-state the guard at the top of their body so it cannot be skipped.

## Core principles

- **Minimal seeding, explicit follow-ups**: seed only what Day 1 truly needs (the empty `.claude/` structure, a CLAUDE.md stub, AGENTS.md review guidelines, README/CHANGELOG, the gh repo). Tech-stack-based rule generation (`/rules-forge:write-rules`) and the wiki-domain interview (`/llm-wiki:bootstrap-wiki`) are **not invoked — only pointed to in Phase 7**. Generating generic content in an empty project imposes an overwrite cost on the user.
- **Owner gate is mandatory**: since the user has a side-project context (personal + org repos), owner selection must not be automated — always ask in the Phase 1 interview.
- **Codex GitHub reviewer surface**: the `## Review guidelines` section of `AGENTS.md` is what the Codex GitHub cloud reviewer reads automatically. It must be seeded at repo-creation time to take effect from the first PR.

## Prerequisites

- `gh` CLI installed + `gh auth status` OK
- `git` installed
- `jq` installed (Phase 0's `infer-github-context.sh` and some placeholder-substitution helpers depend on it)
- The current directory is the target — show the user the `pwd` output and confirm before proceeding

## Phase 0 — Preflight (automatic, no prompt)

```bash
# --- Plugin root resolution (cross-runtime) ---------------------------------
# Claude Code exports CLAUDE_PLUGIN_ROOT. Codex 0.135 does not export an
# equivalent variable yet, so we fall back to discovering the cached plugin
# directory. If neither path resolves we abort early — running with a wrong
# PLUGIN_ROOT would silently miss scripts/* and assets/* later.
PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$PLUGIN_ROOT" ]; then
  # Best-effort Codex cache lookup. Order: latest version directory under the
  # configured marketplace name; user override via $CODEX_PLUGIN_CACHE.
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  # Prefer `sort -V` (GNU) for proper semver ordering; macOS / BSD sort lacks
  # -V and would fail silently, so fall back to plain lexicographic sort.
  # Picks fine for typical X.Y.Z under 10 — covers the realistic version range
  # the plugin cache will ever hold for a single plugin.
  if sort -V </dev/null >/dev/null 2>&1; then
    candidate=$(ls -1d "$cache_root"/*/project-init/* 2>/dev/null | sort -V | tail -1)
  else
    candidate=$(ls -1d "$cache_root"/*/project-init/* 2>/dev/null | sort | tail -1)
  fi
  [ -n "$candidate" ] && [ -d "$candidate" ] && PLUGIN_ROOT="$candidate"
fi
if [ -z "$PLUGIN_ROOT" ] \
    || [ ! -d "$PLUGIN_ROOT/scripts" ] || [ ! -r "$PLUGIN_ROOT/scripts" ] \
    || [ ! -d "$PLUGIN_ROOT/assets" ]  || [ ! -r "$PLUGIN_ROOT/assets" ]; then
  echo "[abort] project-init could not resolve PLUGIN_ROOT." >&2
  echo "        Ensure PLUGIN_ROOT has readable scripts/ and assets/ directories, then re-run." >&2
  exit 1
fi

# Auth check
gh auth status || { echo "[abort] gh CLI not authenticated. Run: gh auth login"; exit 1; }

# Extract git identity
GIT_USER_NAME=$(git config --global user.name || echo "")
GIT_USER_EMAIL=$(git config --global user.email || echo "")

# Diagnose current directory state
CWD=$(pwd)
DIR_NAME=$(basename "$CWD")
HAS_GIT=$([ -d .git ] && echo "yes" || echo "no")
HAS_CLAUDE=$([ -d .claude ] && echo "yes" || echo "no")
HAS_CODE=$(find . -maxdepth 2 -type f \( -name "*.py" -o -name "*.ts" -o -name "*.js" -o -name "*.go" -o -name "*.rs" -o -name "*.java" \) 2>/dev/null | head -1 | wc -l)

# Collect GitHub owner candidates
bash "$PLUGIN_ROOT/scripts/infer-github-context.sh"
# Output: JSON { "personal": "<login>", "orgs": ["<org1>", "<org2>", ...] }
```

> The hard preflight guard (refusing any cwd content beyond `.git/` and OS metadata) runs **before** this Phase 0 block — see the top of `commands/new.md` and `skills/new/SKILL.md`. The legacy Phase 0 idempotency soft-guard below is retained for backward-compatible behavior on truly-fresh runs (e.g. user removes `.gitkeep` files between attempts) but is now subordinate to the hard guard.

If `HAS_CLAUDE=yes` or a commit already exists in `.git/` — the **idempotency guard** fires:
- Confirm via `AskUserQuestion`: "This directory is already set up. Continuing preserves existing files but skips some steps. Continue?"

## Phase 1 — Project Identity Interview

**Single batched `AskUserQuestion` — 4 questions** (the description is free text, so take it via Other).

Question 1: **Project name**
- header: "Name"
- options: `<DIR_NAME>` (default) / "Custom (Other)"

Question 2: **Owner**
- header: "Owner"
- options: generated dynamically — the personal account + all orgs from Phase 0. Mark each option's description "Personal" / "Organization".

Question 3: **Visibility**
- header: "Visibility"
- options: "Private (Recommended)" / "Public"
- (add "Internal" for an org owner)

Question 4: **License**
- header: "License"
- options: "MIT (Recommended)" / "Apache-2.0" / "GPL-3.0" / "None"

> The description (one-liner) is not a separate plain-text question — ask it briefly in one line right after the Phase 1 answers, or take it via the AskUserQuestion Other input. A plain-text description is more natural, so one extra short question is allowed.

## Phase 2 — `.claude/` Scaffold (structure only)

```bash
bash ${PLUGIN_ROOT}/scripts/idempotent-seed.sh ensure-claude-dirs
# Creates: .claude/{spec,rules}/.gitkeep + .llmwiki/{raw,wiki}/.gitkeep
```

Do not invoke `bootstrap-wiki` / `write-rules` — an empty project has no lore to record and no tech-stack signal.

## Phase 3 — CLAUDE.md Minimal Stub

If an existing `CLAUDE.md` is present, skip with a notice. Otherwise write it in this form (this stub is the seeded output; keep it in the user's language):

```markdown
# <project_name>

<one-line description>

## LLM Wiki (`.llmwiki/wiki/`)

이 프로젝트는 Karpathy LLM-Wiki 3-layer 시스템 위에 동작한다. 도메인 lore (provider quirks, design rationale, debugging stories) 는 wiki 가 보관한다.

- **진입점**: `.llmwiki/wiki/index.md` (Map of Content). 페이지 직접 grep 금지.
- **사용 순서**:
  1. lore 가 필요할 때 → `/llm-wiki:query-wiki` 먼저
  2. 새 발견 → `/llm-wiki:ingest-finding`
  3. PR merge 후 → `/github-dev:post-merge` 가 wiki 적재까지 내장 (별도 skill 불필요)
- **현재 상태**: wiki 비어있음. 적극 채워라. 첫 도메인 lore 가 쌓이기 시작하면 `/llm-wiki:bootstrap-wiki` 호출로 도메인 구조 인터뷰를 받는다.

## Setup Status

이 파일은 `/project-init:new` 가 만든 minimal stub 이다. 코드가 어느 정도 쌓이면 다음을 호출해라:

- `/rules-forge:write-rules` — tech-stack 기반 CLAUDE.md + `.claude/rules/*.md` 재생성
- `/llm-wiki:bootstrap-wiki` — 첫 wiki 도메인 인터뷰 + 템플릿 시드

> 사용자의 global `~/.claude/CLAUDE.md` 가 항상 우선한다. 이 파일은 프로젝트 한정 규칙만 보관한다.
```

Substitute the placeholders (`<project_name>`, `<one-line description>`) with the Phase 1 answers.

## Phase 4 — AGENTS.md Seed (★ this plugin's differentiator)

**Variant selection**: recommend based on Phase 1 description keywords, but confirm with the user.

| Keyword in description | Recommended variant |
|------------------------|---------------------|
| "deep learning", "ML", "model", "training", "dataset", "vision", "NLP" | `ml` |
| "web", "fullstack", "frontend", "backend", "API", "REST", "GraphQL" | `web` |
| otherwise / unclear | `general` (base) |

`AskUserQuestion`:
- header: "Variant"
- options: "<recommended> (Recommended)" / the other 2

> Assign the answer to the `VARIANT` variable (e.g. `general` / `ml` / `web`). If the user leaves it blank or omits the answer, default to `VARIANT=general`.

```bash
# Portable in-place sed — GNU sed uses `sed -i 'cmd' file`, BSD/macOS sed uses
# the `sed -i '' 'cmd' file` signature. Branch on `sed --version`.
if sed --version >/dev/null 2>&1; then
  sed_inplace() { sed -i "$@"; }
else
  sed_inplace() { sed -i '' "$@"; }
fi

# POSIX lowercasing — ${VAR,,} is Bash 4+ only, so it breaks with a bad
# substitution on macOS default /bin/bash (3.2). Replace with tr (reused in the
# Phase 6 visibility normalization too).
to_lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Normalize the AskUserQuestion label ("ml (Recommended)" / "web" / "general")
# to a filename token (general|ml|web). Abort on an unknown value.
variant_lower=$(to_lower "$VARIANT")
case "$variant_lower" in
  *ml*)         VARIANT_FLAG="ml" ;;
  *web*)        VARIANT_FLAG="web" ;;
  *general*|"") VARIANT_FLAG="general" ;;
  *) echo "[abort] Unknown variant: $VARIANT"; exit 1 ;;
esac

SRC="${PLUGIN_ROOT}/assets/AGENTS.review-guidelines.${VARIANT_FLAG}.md"
# For the general variant, use the base file
[ "$VARIANT_FLAG" = "general" ] && SRC="${PLUGIN_ROOT}/assets/AGENTS.review-guidelines.md"

# Escape characters dangerous in a sed replacement context (\, &, |) — if user
# input contains a `&` like "Frontend & Backend", sed re-inserts the whole match.
esc_sed() { printf '%s' "$1" | sed 's/[\\&|]/\\&/g'; }
PROJECT_NAME_ESC=$(esc_sed "$PROJECT_NAME")
ONE_LINER_ESC=$(esc_sed "$ONE_LINER")
OWNER_ESC=$(esc_sed "$OWNER")
LICENSE_ESC=$(esc_sed "$LICENSE")

if [ ! -f AGENTS.md ]; then
  cp "$SRC" AGENTS.md
  # Substitute placeholders (using the escaped values)
  sed_inplace "s|{{PROJECT_NAME}}|${PROJECT_NAME_ESC}|g" AGENTS.md
  sed_inplace "s|{{ONE_LINER}}|${ONE_LINER_ESC}|g" AGENTS.md
  sed_inplace "s|{{OWNER}}|${OWNER_ESC}|g" AGENTS.md
else
  echo "[skip] AGENTS.md already exists — preserving existing content"
fi
```

The `## Review guidelines` section of AGENTS.md is read automatically by the Codex GitHub cloud reviewer ([OpenAI Codex GitHub integration](https://developers.openai.com/codex/integrations/github)) — give the user a one-line note.

## Phase 5 — README + CHANGELOG

```bash
# Track only newly-seeded files — apply substitution only to the cp'd files so
# that deliberate {{PROJECT_NAME}}-style placeholders in existing files are not tampered with.
SEEDED_FILES=()
if [ ! -f README.md ]; then
  cp "${PLUGIN_ROOT}/assets/README.minimal.md" README.md
  SEEDED_FILES+=("README.md")
fi
if [ ! -f CHANGELOG.md ]; then
  cp "${PLUGIN_ROOT}/assets/CHANGELOG.initial.md" CHANGELOG.md
  SEEDED_FILES+=("CHANGELOG.md")
fi

# Reuse sed_inplace / *_ESC defined in Phase 4 — escaped + platform-portable
for f in "${SEEDED_FILES[@]}"; do
  sed_inplace "s|{{PROJECT_NAME}}|${PROJECT_NAME_ESC}|g" "$f"
  sed_inplace "s|{{ONE_LINER}}|${ONE_LINER_ESC}|g" "$f"
  sed_inplace "s|{{OWNER}}|${OWNER_ESC}|g" "$f"
  sed_inplace "s|{{LICENSE}}|${LICENSE_ESC}|g" "$f"
done
```

Gate: preview the first 30 lines of README.md, then allow edits. Fix inline with `Edit` immediately rather than invoking again.

## Phase 6 — GitHub Repo Creation

```bash
# Git init if needed
[ -d .git ] || git init -b main

# Seed .gitignore BEFORE staging so machine-local run records never enter the
# initial commit — state-envelope records live under .claude/state/ and must not
# be committed. `git add .claude/` honors .gitignore for a directory add, so the
# record is skipped once this line is present (a fresh bootstrap has no .gitignore).
if ! grep -qxF '.claude/state/' .gitignore 2>/dev/null; then
  printf '%s\n' '.claude/state/' >> .gitignore
fi

# Stage all seeded files (git add is a no-op for already-existing files)
git add .claude/ .llmwiki/ CLAUDE.md AGENTS.md README.md CHANGELOG.md .gitignore

# Idempotent re-run path: if Phase 4/5 both skipped and there is no staged diff,
# `git commit` fails with `nothing to commit` and aborts the later gh repo create.
# Branch on whether staged changes exist.
if ! git diff --cached --quiet; then
  git commit -m "chore: bootstrap project skeleton via project-init"
else
  echo "[skip] no new changes to commit — idempotent re-run path"
fi
```

`AskUserQuestion`: confirm after a dry-run preview.

```bash
# Normalize the AskUserQuestion label ("Private (Recommended)", "Public", "Internal")
# to a gh CLI token (private|public|internal).
# Reuse the Phase 4 to_lower helper (POSIX tr — Bash 3.2 compatible).
vis_lower=$(to_lower "$VISIBILITY")
case "$vis_lower" in
  *private*)  VIS_FLAG="private" ;;
  *public*)   VIS_FLAG="public" ;;
  *internal*) VIS_FLAG="internal" ;;
  *) echo "[abort] Unknown visibility: $VISIBILITY"; exit 1 ;;
esac

# Idempotent re-run guard: if an origin remote already exists, `gh repo create
# --remote=origin` fails trying to register a duplicate. Surface the URL the
# existing remote points to and give the user a manual push command.
if git remote get-url origin >/dev/null 2>&1; then
  EXISTING=$(git remote get-url origin)
  echo "[skip] origin remote already exists ($EXISTING) — skipping gh repo create."
  echo "       manual sync: git push -u origin $(git branch --show-current)"
else
  # Repo create + push (dry-run preview first, then real run)
  PREVIEW="gh repo create ${OWNER}/${PROJECT_NAME} --${VIS_FLAG} --description \"${ONE_LINER}\" --source=. --remote=origin --push"
  echo "$PREVIEW"

  # User confirms via AskUserQuestion (Recommended: "Run")
  gh repo create "${OWNER}/${PROJECT_NAME}" --"${VIS_FLAG}" --description "${ONE_LINER}" --source=. --remote=origin --push
fi
```

If the license is not None — after gh repo create, create the LICENSE file via `gh api`, or advise the user to do it "later". For simplicity, V1 only advises.

## Phase 7 — Summary + Next Actions

```text
✓ Project '<name>' bootstrapped at <cwd>

Files seeded:
  .claude/spec/.gitkeep
  .claude/rules/.gitkeep
  .llmwiki/raw/.gitkeep
  .llmwiki/wiki/.gitkeep
  CLAUDE.md       (minimal stub — LLM Wiki entrypoint)
  AGENTS.md       (variant: <variant> — includes Codex Review guidelines)
  README.md       (6-section minimal)
  CHANGELOG.md    ([Unreleased] only)

GitHub repo: https://github.com/<owner>/<name>

Next actions (call when ready):
  1. 코드가 쌓이면        → /rules-forge:write-rules
     (tech-stack 기반 CLAUDE.md + .claude/rules/*.md 재생성)

  2. 첫 도메인 lore 쌓이면 → /llm-wiki:bootstrap-wiki
     (도메인 인터뷰 + .llmwiki/wiki/<domain>/ 구조 시드)

  3. 첫 PR merge 후        → /github-dev:post-merge
     (wiki 적재까지 내장 — 별도 skill 불필요)
```

## Failure handling

| Step | Behavior on failure |
|------|--------------|
| Preflight hard guard | abort + notice (use `/rules-forge:write-rules` or `/llm-wiki:bootstrap-wiki` for non-empty dirs) |
| Phase 0 — gh auth | abort + notice (`gh auth login`) |
| Phase 0 — idempotency guard user abort | stop immediately, preserve the partial seed |
| Phase 6 — `gh repo create` | local changes/commits stay intact, only push fails. Advise the user of a manual retry command |
| Phase 6 — repo name collision | surface the gh CLI error message verbatim + suggest retrying Phase 1 |

## Out of Scope

- CI/CD workflow seed (`.github/workflows/`)
- pre-commit hook seed
- external boilerplate auto-download (cookiecutter etc. — if needed, a separate `Skill("code-scout:research-orchestrator")` call)
- multi-language interview branching — a single mixed Korean/English version is maintained
