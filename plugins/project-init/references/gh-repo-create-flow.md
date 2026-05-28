# gh repo create — Owner 추론 + Visibility 결정 트리

`/project-init:new` Phase 1 인터뷰와 Phase 6 레포 생성의 의사결정 컨텍스트.

## Owner 추론 (자동 X, 인터뷰 필수)

사용자가 personal account + 부업/소속 org 들을 동시에 가지는 경우가 일반적이라 **owner 자동 결정 금지**. `gh api` 로 후보만 수집하고 `AskUserQuestion` 으로 선택받는다.

### 후보 수집 명령

```bash
# Personal account
PERSONAL=$(gh api user --jq '.login')

# Orgs 사용자가 멤버인 것 전체
ORGS=$(gh api /user/orgs --jq '.[].login')
# 또는 페이지네이션 안전:
ORGS=$(gh api --paginate /user/orgs --jq '.[].login')
```

> `--paginate` 안전 사용: orgs 가 30 개 넘는 경우 첫 페이지 30 개만 잡힘.

### 결정 트리

```
Q: "Where to create the repo?"
├─ {personal_login}                     [Personal]
├─ {org1}                                [Organization]
├─ {org2}                                [Organization]
└─ ...
```

옵션 description 에 "Personal" / "Organization" 명시 — 사용자가 두 org 가 비슷한 이름일 때 헷갈리지 않게.

## Visibility 결정

```
Q: "Visibility?"
├─ Private (Recommended)
├─ Public
└─ Internal     ← org owner 일 때만 노출 (personal 은 internal 불가)
```

Recommended default 가 Private 인 이유:
- 신규 프로젝트는 아직 정리되지 않은 secret / debug commit / WIP 코드를 포함할 가능성. 나중에 public 으로 전환은 한 줄이지만 (`gh repo edit --visibility public`), public → private 전환 후 fork 회수는 불가능.
- 의도가 public OSS 라도 첫 1 주는 private 으로 두고 정리 후 전환하는 패턴이 안전.

> Public 으로 전환 명령: `gh repo edit {{OWNER}}/{{PROJECT_NAME}} --visibility public --accept-visibility-change-consequences`

## License 결정

License 는 visibility 와 독립이다 (private 레포에도 license 둘 수 있음).

| Option | 언제 |
|--------|------|
| **MIT** (Recommended) | 단순 permissive, 가장 호환성 높음 |
| **Apache-2.0** | 특허 grant 명시 필요할 때 |
| **GPL-3.0** | copyleft 의도 (derivative 도 GPL 유지 강제) |
| **None** | 명시적으로 license 안 둘 때 (private 레포라면 "사실상 all rights reserved") |

`gh repo create` 의 `--license <name>` 플래그로 자동 LICENSE 파일 생성 가능 (template 사용). 단 license 가 None 이면 생략.

```bash
# License 자동 시드
gh repo create "${OWNER}/${PROJECT_NAME}" \
  --${VISIBILITY,,} \
  --description "${ONE_LINER}" \
  --license "${LICENSE}" \
  --source=. --remote=origin --push
```

> 한계: `gh repo create --license` 는 빈 레포 (코드 없음) 일 때만 license 파일을 자동 생성한다. `--source=.` 와 함께 쓰면 이미 commit 가 있어서 license 자동 생성이 안 될 수 있음 — 그 경우 별도로 `gh api -X POST /repos/.../contents/LICENSE` 로 시드하거나 사용자에게 manual 안내. V1 에서는 명령에 `--license` 만 넣고 실패해도 무시 (사용자 안내).

## Push 흐름

```bash
# 0. git init (이미 .git 있으면 skip)
[ -d .git ] || git init -b main

# 1. 모든 시드 파일 stage
git add .claude/ CLAUDE.md AGENTS.md README.md CHANGELOG.md

# 2. Initial commit
git commit -m "chore: bootstrap project skeleton via project-init"

# 3. gh repo create + 자동 push
gh repo create "${OWNER}/${PROJECT_NAME}" \
  --${VISIBILITY,,} \
  --description "${ONE_LINER}" \
  --source=. --remote=origin --push
```

`--source=.` 는 현재 디렉토리를 git source 로 지정. `--remote=origin` 은 자동으로 `origin` remote 등록. `--push` 는 현재 branch 를 push.

## 실패 시 복구

| 실패 | 복구 |
|------|------|
| `gh repo create` — repo 이름 충돌 | Phase 1 재시도 (다른 이름 선택). local commit 은 그대로 보존. |
| `gh repo create` — 권한 부족 (org 멤버 X) | Phase 1 owner 재선택 권유. |
| Push 실패 — 네트워크 / auth | `git remote add origin ...` + `git push -u origin main` 수동 명령 안내. |
| Initial commit 실패 — gitignore 빠짐 | 임시 `.env`, `node_modules/` 등이 stage 됐는지 확인. `.gitignore` 시드는 V1 scope 밖이라 사용자가 명시적으로 처리. |

## Idempotency

같은 디렉토리에서 `/project-init:new` 두 번째 호출 시:
1. `.git` 이 이미 존재하면 `git init` skip.
2. AGENTS.md / CLAUDE.md / README.md / CHANGELOG.md 중 어느 하나라도 이미 존재하면 Phase 4 / 5 에서 해당 파일은 skip + 안내.
3. `.claude/` 가 이미 있으면 Phase 2 의 `.gitkeep` 만 추가 (디렉토리 구조 자체는 보존).
4. `gh repo` 가 이미 존재하면 — `gh repo view ${OWNER}/${PROJECT_NAME}` 으로 확인 후 사용자에게 "remote 만 wire 할까요?" 결정.

이 가드는 `scripts/idempotent-seed.sh` 가 담당한다.
