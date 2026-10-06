# 파일을 쓰는 worker 는 worktree 에 격리하고, 범위는 브랜치 이력으로 검사한다

`/dev:orchestrate` 는 파일을 쓰는 작업 조각을 항상 `isolation: worktree` 로 돌리고, worker 가 범위를 지켰는지는 `git log --no-renames -z --name-only <base>..<branch>` 로 검사한다. 범위를 어긴 브랜치는 고치지 않고 머지하지 않는다. git 은 트리의 상태만 기록하고 누가 바꿨는지는 기록하지 않아서, 공유 체크아웃에서는 어느 worker 가 어떤 파일을 썼는지 알아낼 수 없기 때문이다.

## Considered Options

- 공유 체크아웃에서 dispatch 전후의 `git status --porcelain` 스냅샷을 비교한다: 버렸다. 원래 dirty 였던 파일, staged, untracked, ignored, 이미 커밋된 파일, escape 된 경로에서 새는 곳이 하나씩 계속 나왔고, PR #254 의 Codex 지적 17개 중 16개가 이 전제에서만 성립했다.

## Consequences

- worktree 에는 `.env`, fixture, `node_modules` 같은 입력도 없다. 사용자 승인을 받아 넣어 주거나 저장소의 setup 단계로 다시 만들어야 하고, 커밋 안 된 입력은 dispatch 전에 커밋해야 worker 에게 닿는다.

출처: GitHub PR #254, #261, issue #256, `plugins/dev/skills/orchestrate/SKILL.md`
