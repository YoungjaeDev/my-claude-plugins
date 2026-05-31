---
description: First-day project bootstrap — interview, .claude/ scaffold, CLAUDE.md + AGENTS.md (Codex reviewer guidelines) + README + CHANGELOG seed, gh repo create + initial push
---

# /project-init:new

새 디렉토리에서 한 번 호출해 "Day 1 ready" 프로젝트를 만든다 — 인터뷰 → 로컬 시드 → gh 레포 생성 → 초기 커밋/푸시.

> **Trigger surface**: 명시적 user invocation 만. 자동 트리거 없음 (잘못된 디렉토리에서 실행되면 위험).

## Step 0 — Preflight hard guard (NON-NEGOTIABLE, runs before any other body content)

이 가드는 `references/new-procedure.md` 의 Phase 0 보다 먼저 실행된다. 비어있지 않은 디렉토리에서는 abort 한다.

```bash
# Hard guard — refuses to run if directory is not fresh
if [ -d .git ] || [ -d .claude ] || [ -n "$(find . -maxdepth 2 -type f \
    \( -name '*.py' -o -name '*.ts' -o -name '*.js' -o -name '*.go' \
    -o -name '*.rs' -o -name '*.java' -o -name 'package.json' \
    -o -name 'pyproject.toml' -o -name 'Cargo.toml' -o -name 'go.mod' \) \
    2>/dev/null)" ]; then
  echo "[abort] project-init refuses to run in a non-empty directory."
  echo "        cwd: $(pwd)"
  echo "        Found existing .git/, .claude/, or source files."
  echo "        If you really want to add Claude/Codex scaffolding to an existing"
  echo "        project, use /rules-forge:write-rules or /llm-wiki:bootstrap-wiki"
  echo "        instead."
  exit 1
fi
```

The legacy Phase 0 idempotency guard (in the procedure file) is now redundant for fresh-dir runs but remains as a defense-in-depth check for the partial-seed re-run path (user removed `.gitkeep` files between attempts).

## Step 1 — Procedure

가드를 통과하면 전체 Phase 0–7 를 따른다. 본문은 `${CLAUDE_PLUGIN_ROOT}/references/new-procedure.md` 에 있다 — 같은 파일을 `new` skill 도 참조하므로 한쪽 업데이트가 양쪽에 전파된다.

Reference에 포함된 내용:
- Phase 0 — Preflight (gh auth, identity, owner candidates 추출).
- Phase 1 — Project identity interview (name / owner / visibility / license, batched AskUserQuestion).
- Phase 2 — `.claude/` + `.llmwiki/` scaffold.
- Phase 3 — CLAUDE.md minimal stub.
- Phase 4 — AGENTS.md seed (variant: `general` / `ml` / `web`).
- Phase 5 — README + CHANGELOG seed.
- Phase 6 — `git init` + `gh repo create`.
- Phase 7 — Summary + next actions (`/rules-forge:write-rules`, `/llm-wiki:bootstrap-wiki`, `/github-dev:post-merge`).
