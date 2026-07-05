---
name: gws-sync
description: 로컬 폴더 → Google Drive 단방향 제안형 동기화 — gws CLI 기반(MCP 아님, 인증 전제). 매핑 설정 파일(.gws-sync.json)로 로컬↔Drive 폴더 대응을 기억하고, 실행 시 Drive 트리를 탐색해 신규·변경 diff 리포트를 만든 뒤, 업로드 위치를 AskUserQuestion으로 승인받아 업로드한다. 삭제는 제안만(자동 삭제 금지). gws 미설치면 공식 docs 설치 안내를 출력하고 중단. 트리거 — "Drive에 올려줘/동기화해줘", "이 폴더 Drive랑 맞춰줘", "산출물 Drive 갱신", "gws sync", "드라이브 업로드". 단발 파일 1개 업로드는 gws-drive-upload 스킬이 가볍다(설치돼 있으면 그쪽 제안).
---

# gws-sync — 로컬 → Drive 단방향 제안형 동기화

**설계 원칙**: ① 단방향(로컬 → Drive)만 — Drive 쪽 변경을 로컬로 내리지 않는다 ② 제안형 — 모든 쓰기는 diff 리포트 + 사용자 승인 뒤에만 ③ 삭제는 절대 자동 실행하지 않는다(제안만) ④ Drive 파일 갱신은 새 파일 생성이 아니라 **기존 파일 content update**(파일 ID 유지 — 공유 링크·버전 히스토리 보존).

## 0. 전제 확인 (매 실행)

1. `gws --version` — **미설치면 중단**하고 설치 안내 출력: "gws CLI가 필요합니다. 설치: `npm install -g @googleworkspace/cli` 또는 공식 문서 github.com/googleworkspace/cli 참조. 설치 후 첫 사용이면 `gws auth setup`(1회) → `gws auth login`으로 인증하세요(`gcloud` 미설치 환경은 공식 README의 수동 OAuth 설정 참조)." (자동 설치하지 않는다 — 제안만.)
2. 인증·스코프 확인: 가벼운 읽기 호출(`gws drive files list --params '{"pageSize": 1}'`)이 실패하면 인증 안내 후 중단 — 첫 사용이면 `gws auth setup`, 이후는 `gws auth login`. **읽기 성공이 쓰기 스코프를 보장하지 않는다** — 업로드/업데이트 단계에서 권한 오류가 나면 drive 쓰기 스코프로 재인증하도록 안내(예: `gws auth login --scopes drive`, 정확한 플래그는 `gws auth --help` 확인). 읽기 검증만으로 쓰기 가능하다고 단정하지 않는다.
3. 유용 스킬 제안(선택): 작업 상황이 카탈로그의 다른 gws 스킬/레시피와 맞으면(예: 업로드 후 팀 공유 → recipe-share-folder-with-team) `references/gws-skills-llms.txt`에서 찾아 **설치 제안 문구**를 함께 출력한다. 설치 명령은 현재 `skills` CLI에서 정확한 형태를 확인한 뒤 제시한다(`references/gws-skills-llms.txt`의 형태를 그대로 쓰되, 미확인이면 "설치 방법은 skills CLI로 확인하세요"라고만). 제안만 하고 강제하지 않는다.

## 1. 매핑 설정 파일 — `.gws-sync.json`

로컬 repo 루트(또는 사용자 지정 위치)에 매핑을 기억한다:

```json
{
  "mappings": [
    {
      "local": "projects/deck-a/exports",
      "driveFolderId": "1aQthLJ...",
      "driveFolderPath": "강의교안/exports",
      "include": ["*.pptx", "*.pdf"],
      "files": { "deck.pptx": "1eon6SX..." }
    }
  ]
}
```

- `files`는 로컬 파일명 → Drive 파일 ID 캐시. **캐시 ID는 힌트일 뿐 신뢰의 근거가 아니다** — 업데이트 전 반드시 §3-4에서 그 ID가 승인된 폴더 안에 있고·trashed 아니고·해당 로컬 파일명과 유일 매칭되는지 재확인한다(캐시가 stale하면 엉뚱한 Drive 파일을 덮어쓸 수 있다). 첫 업로드 후 자동 기록.
- 설정 파일이 없으면 §2의 위치 승인 플로우로 만들고, 승인된 매핑을 저장한다("다음부터는 안 묻고 이 폴더로" 여부도 함께 확인).

## 2. 업로드 위치 승인 (MANDATORY — AskUserQuestion)

매핑이 없거나 사용자가 새 대상 폴더를 말한 경우:

1. **Drive 트리 탐색** — 폴더 후보를 검색한다. Drive 쿼리 문법상 폴더 MIME는 정확한 값 `'application/vnd.google-apps.folder'`로 써야 하고(`mimeType = folder`는 매칭 안 됨), trashed 제외도 명시한다:
   ```bash
   gws drive files list --params '{"q": "name contains '\''<이름>'\'' and mimeType = '\''application/vnd.google-apps.folder'\'' and trashed = false", "fields": "files(id,name,parents)", "supportsAllDrives": true, "includeItemsFromAllDrives": true}'
   ```
   후보 폴더의 하위 목록을 확인해 맥락을 잡는다.
2. **AskUserQuestion으로 위치 제안·승인** — 후보 2~3개(+ "새 폴더 생성" 옵션)를 제시하고 사용자가 고른 위치만 쓴다. **승인 없이 업로드 금지.** 매핑이 이미 있으면 이 단계는 생략(설정이 곧 승인 기록).

## 3. diff 리포트 → 승인 → 업로드

1. **로컬 스캔**: 매핑의 `local` 폴더에서 `include` 패턴 파일 수집.
2. **Drive 스캔**: 대상 폴더로 **범위를 좁혀** 목록을 받는다 — parent 필터·trashed 제외·shared-drive 플래그·페이지네이션 필수(제약 없는 `files list`는 무관한 파일까지 끌어와 diff를 오염시킨다):
   ```bash
   gws drive files list --params '{"q": "'\''<folderId>'\'' in parents and trashed = false", "fields": "nextPageToken, files(id,name,size,modifiedTime,mimeType,parents)", "supportsAllDrives": true, "includeItemsFromAllDrives": true}' --page-all
   ```
3. **diff 리포트** (표로 출력):
   - **신규**: 로컬에만 있음 → `+upload` 대상
   - **변경**: 양쪽에 있고 로컬이 다름(크기 또는 로컬 mtime > Drive modifiedTime) → content update 대상
   - **동일**: 스킵
   - **Drive 고아**: Drive에만 있음 → **삭제 제안만** ("로컬에 없는 파일 N건 — 삭제는 직접 해주세요" + 목록). 자동 삭제 절대 금지.
4. **업데이트 대상 ID 재확인(MANDATORY)**: 각 '변경' 파일에 대해 2단계 스캔 결과에서 **승인된 폴더 안·trashed=false·해당 로컬 파일명과 정확히 1건 매칭**되는 Drive item 하나를 확정한다. 캐시 ID가 이 결과와 어긋나거나(폴더 밖·trashed·이름 불일치) 동명 파일이 여러 개면 **자동 진행을 멈추고 AskUserQuestion으로 대상 ID를 사용자에게 고르게 한다**. 확정된 ID로만 캐시를 갱신.
5. **승인**: 리포트를 보여주고 진행 여부 확인(신규/변경 건수가 0이면 "동기화 최신" 보고 후 종료).
6. **실행**:
   - 신규: `gws drive +upload <file> --parent <folderId>` → 반환 ID를 `files` 캐시에 기록.
   - 변경: 4에서 확정한 ID로만 `gws drive files update --params '{"fileId": "<id>", "supportsAllDrives": true}' --upload <file>` — 새 파일을 만들지 않고 기존 ID를 갱신.
7. **검증**: 업로드 후 대상 폴더를 재조회해 건수·이름 확인, 결과 표 보고.

## 하드 룰

- 쓰기(upload/update)는 diff 리포트 + 승인 없이 실행하지 않는다.
- 삭제·이동·권한 변경은 이 스킬 범위 밖 — 제안 문구만.
- Drive → 로컬 다운로드(양방향)는 범위 밖.
- 대용량/다건이어도 한 파일씩 순차 업로드(부분 실패 시 어디까지 갔는지 보고).
- `.gws-sync.json`은 커밋 대상 여부를 사용자에게 확인(파일 ID가 내부 정보일 수 있음 — 공유 repo면 .gitignore 제안).

## 의존·참조

- `gws` CLI(필수, 미설치 시 설치 안내 후 중단) — 전역 플래그·인증·출력 형식은 gws-shared 스킬(설치 시) 또는 `gws --help`.
- `references/gws-skills-llms.txt` — 공식 스킬/레시피 95종 카탈로그(서비스 54 + 레시피 41). 상황 제안용 인덱스.
