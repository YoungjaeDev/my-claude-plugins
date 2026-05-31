---
description: First-day project bootstrap — interview, .claude/ scaffold, CLAUDE.md + AGENTS.md (Codex reviewer guidelines) + README + CHANGELOG seed, gh repo create + initial push
---

# /project-init:new

새 디렉토리에서 한 번 호출해 "Day 1 ready" 프로젝트를 만든다 — 인터뷰 → 로컬 시드 → gh 레포 생성 → 초기 커밋/푸시.

> **Trigger surface**: 명시적 user invocation 만. 자동 트리거 없음 (잘못된 디렉토리에서 실행되면 위험).

## Step 0 — Preflight hard guard (NON-NEGOTIABLE, runs before any other body content)

이 가드는 `references/new-procedure.md` 의 Phase 0 보다 먼저 실행된다. 비어있지 않은 디렉토리에서는 abort 한다.

```bash
# Hard guard — refuses to run if cwd contains ANYTHING beyond ignorable OS junk.
# Walks up to 5 levels deep so deeper sources (e.g. src/app/main.py) and any
# top-level file (Dockerfile, Makefile, .env, docs/*) trigger the abort. Only
# .git/ and OS metadata (.DS_Store, Thumbs.db, desktop.ini) are pruned — a
# pre-existing top-level .claude/ deliberately makes the guard fire (it means
# the directory has already been initialized and re-running would clash).
FIRST_EXISTING=$(find . -mindepth 1 -maxdepth 5 \
  \( -name '.git' -o -path './.git/*' \
   -o -name '.DS_Store' -o -name 'Thumbs.db' \
   -o -name 'desktop.ini' \) -prune \
  -o -print 2>/dev/null | head -1)

if [ -d .git ] || [ -n "$FIRST_EXISTING" ]; then
  echo "[abort] project-init refuses to run in a non-empty directory."
  echo "        cwd: $(pwd)"
  echo "        Existing entry detected: ${FIRST_EXISTING:-.git/}"
  echo "        If you really want to add Claude/Codex scaffolding to an existing"
  echo "        project, use /rules-forge:write-rules or /llm-wiki:bootstrap-wiki"
  echo "        instead."
  exit 1
fi
```

The legacy Phase 0 idempotency guard (in the procedure file) is now redundant for fresh-dir runs but remains as a defense-in-depth check for the partial-seed re-run path (user removed `.gitkeep` files between attempts).

## Step 1 — Procedure

가드를 통과하면 전체 Phase 0–7 를 따른다. 본문은 이 플러그인의 `references/new-procedure.md` 에 있다 — `new` skill 도 동일 파일을 가리킨다. Claude Code 에서는 `${CLAUDE_PLUGIN_ROOT}/references/new-procedure.md` 로 해석되고, Codex 에서는 plugin cache 디렉토리 기준 동일 상대 경로 (`references/new-procedure.md`) 로 해석된다.

Reference에 포함된 내용:
- Phase 0 — Preflight (gh auth, identity, owner candidates 추출).
- Phase 1 — Project identity interview (name / owner / visibility / license, batched AskUserQuestion).
- Phase 2 — `.claude/` + `.llmwiki/` scaffold.
- Phase 3 — CLAUDE.md minimal stub.
- Phase 4 — AGENTS.md seed (variant: `general` / `ml` / `web`).
- Phase 5 — README + CHANGELOG seed.
- Phase 6 — `git init` + `gh repo create`.
- Phase 7 — Summary + next actions (`/rules-forge:write-rules`, `/llm-wiki:bootstrap-wiki`, `/github-dev:post-merge`).
