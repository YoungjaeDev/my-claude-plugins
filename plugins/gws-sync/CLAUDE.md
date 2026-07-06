# gws-sync Plugin

로컬 폴더 → Google Drive **단방향 제안형 동기화**. gws CLI(공식 googleworkspace/cli) 기반 — MCP가 아니라 CLI를 부른다. 인증(`gws auth login`)은 전제.

## Skill

| Skill | Description |
|-------|-------------|
| `gws-sync` | 매핑 설정(`.gws-sync.json`) 기억 → Drive 트리 탐색 → 신규·변경 diff 리포트 → **업로드 위치 AskUserQuestion 승인(필수)** → 업로드(기존 파일은 content update — 파일 ID·공유 링크·버전 히스토리 보존). 삭제는 제안만. |

## 설계 원칙 (하드 룰)

1. **단방향** — 로컬 → Drive만. Drive 변경을 로컬로 내리지 않는다.
2. **제안형** — 모든 쓰기는 diff 리포트 + 사용자 승인 뒤에만.
3. **삭제 자동 실행 금지** — Drive 고아 파일은 목록으로 제안만.
4. **update ≠ 재업로드** — 기존 파일 갱신은 `files update --upload`(ID 유지). 새 파일을 만들어 링크를 깨지 않는다.

## 의존

- `gws` CLI **필수** — 미설치 시 설치 안내(`npm install -g @googleworkspace/cli` + github.com/googleworkspace/cli) 출력 후 중단. 자동 설치하지 않는다.
- `references/gws-skills-llms.txt` — 공식 스킬 54종 + 레시피 41종 카탈로그. 사용자 상황에 맞는 미설치 스킬/레시피를 `npx skills add` 문구로 제안하는 인덱스.

## 구조

```text
gws-sync/
├── .claude-plugin/plugin.json
├── CLAUDE.md                    # 이 파일
└── skills/gws-sync/
    ├── SKILL.md                 # 0.전제 확인 → 1.매핑 설정 → 2.위치 승인 → 3.diff→승인→업로드
    └── references/gws-skills-llms.txt
```
