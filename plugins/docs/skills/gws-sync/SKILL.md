---
name: gws-sync
description: 로컬 폴더 → Google Drive 단방향 제안형 동기화 — gws CLI 기반(MCP 아님, 인증 전제). 매핑 설정 파일(.gws-sync.json)로 로컬↔Drive 폴더 대응을 기억하고, 실행 시 Drive 트리를 탐색해 신규·변경 diff 리포트를 만든 뒤, 업로드 위치를 AskUserQuestion으로 승인받아 업로드한다. 삭제는 제안만(자동 삭제 금지). gws 미설치면 공식 docs 설치 안내를 출력하고 중단. 트리거 — "Drive에 올려줘/동기화해줘", "이 폴더 Drive랑 맞춰줘", "산출물 Drive 갱신", "gws sync", "드라이브 업로드". 단발 파일 1개 업로드는 gws-drive-upload 스킬이 가볍다(설치돼 있으면 그쪽 제안).
---

# gws-sync: local → Drive one-way proposal-based sync

Sync local folders to Google Drive one way through the `gws` CLI: a `.gws-sync.json` mapping, a diff report in 4 classes (New, Changed, Identical, Drive orphan), and a write only after the user approves it.

Ask with `AskUserQuestion` on Claude Code or `request_user_input` on Codex; when neither is available, stop and report the diff without writing anything.

- **One-way**: local → Drive only; never pull Drive-side changes back to local.
- **Proposal-based**: every write happens only after a diff report plus user approval.
- **No automatic deletion**: Drive orphans are a proposal only.
- **Content update**: updating a Drive file updates the existing file's content, not a new file, so the file ID, share links and version history survive.

## 0. Prerequisite check (every run)

1. `gws --version`: **if missing, stop** and print install guidance: "gws CLI가 필요합니다. 설치: `npm install -g @googleworkspace/cli` 또는 공식 문서 github.com/googleworkspace/cli 참조. 설치 후 첫 사용이면 `gws auth setup`(1회) → `gws auth login`으로 인증하세요(`gcloud` 미설치 환경은 공식 README의 수동 OAuth 설정 참조)." (Do not install automatically, propose only.)
2. Confirm auth and scope: if a light read call (`gws drive files list --params '{"pageSize": 1}'`) fails, print auth guidance and stop: `gws auth setup` on first use, `gws auth login` thereafter. **A successful read does not guarantee write scope**: if the upload/update step hits a permission error, guide the user to re-authenticate with the drive write scope (e.g. `gws auth login --scopes drive`; confirm the exact flag with `gws auth --help`). Never assume write access from a read check alone.
3. Suggest useful skills (optional): if the task matches another gws skill/recipe in the catalog (e.g. share with the team after upload → recipe-share-folder-with-team), find it in the live catalog (`gh api repos/googleworkspace/cli/contents/skills --jq '.[].name'`, descriptions in the repo's `docs/skills.md`) and print an **install-suggestion line** alongside. Confirm the exact install command form with the current `skills` CLI before presenting it, or if unconfirmed just say "설치 방법은 skills CLI로 확인하세요". Suggest only, never force.

## 1. Mapping config file: `.gws-sync.json`

Remember the mapping at the local repo root (or a user-specified location):

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

- `files` is a local-filename → Drive-file-ID cache. **A cached ID is only a hint, not a basis for trust**: before updating, always re-confirm in §3-4 that the ID sits inside the approved folder, is not trashed, and matches that local filename uniquely (a stale cache can overwrite the wrong Drive file). It is recorded automatically after the first upload.
- If the config file is absent, create it through the location-approval flow in §2 and store the approved mapping (also confirming whether to "skip the prompt and use this folder from now on").

## 2. Upload-location approval (MANDATORY: user approval)

When there is no mapping, or the user names a new target folder:

1. **Walk the Drive tree**: search for candidate folders. Drive query syntax requires the exact folder MIME value `'application/vnd.google-apps.folder'` (`mimeType = folder` does not match), and must exclude trashed items explicitly:
   ```bash
   gws drive files list --params '{"q": "name contains '\''<name>'\'' and mimeType = '\''application/vnd.google-apps.folder'\'' and trashed = false", "fields": "files(id,name,parents)", "supportsAllDrives": true, "includeItemsFromAllDrives": true}'
   ```
   Inspect each candidate folder's children to establish context.
2. **Propose and approve the location with the question tool**: present 2-3 candidates (plus a "create new folder" option) and write only to the location the user chooses. **No upload without approval.** If a mapping already exists, skip this step (the config is itself the approval record).

## 3. diff report → approval → upload

Read `references/procedure.md` before this section: it holds every step's commands and the timestamp, hash and Shared Drive details. The steps and their gates:

1. **Local scan** of the mapping's `include` patterns under `local`.
2. **Drive scan** narrowed to the target folder (parent filter, trashed exclusion, shared-drive flags, pagination).
3. **diff report** as a table: New (`+upload`), Changed (content update, timestamps compared as UTC epoch seconds), Identical (skip), Drive orphan (**proposal only**, never deleted). Capture each New/Changed file's `{sha256, size, mtime}` snapshot at this moment.
4. **Re-confirm update-target IDs (MANDATORY)**: one Drive item inside the approved folder, not trashed, matching the filename exactly once; otherwise stop and let the user pick the ID.
5. **Approval** of the report; with 0 new or changed files, report "already in sync" and exit.
5b. **Freeze the approval manifest (MANDATORY)** from the §3 snapshot; if a file changed since the diff, abort and return to §3.
6. **Execute from the manifest only**: re-check each item's hash and target ID right before it runs, and on any mismatch abort the entire run and return to §3, never skipping just that item. Updates keep the existing file ID.
7. **Verify**: re-query the target folder and report counts and names as a table.

## Hard rules

- Never run a write (upload/update) without a diff report plus approval.
- **Upload only items present in the §5b approval manifest**: never upload a file absent from the manifest; if a manifest value and reality (local file, target ID) disagree, do not force part of it through, abort and re-approve. Never grow the list by re-scanning after approval.
- Deletion, moving, and permission changes are out of scope for this skill: proposal text only.
- Drive → local download (two-way) is out of scope.
- Even for large or many-file runs, upload one file at a time sequentially (on partial failure, report how far it got).
- Confirm with the user whether `.gws-sync.json` should be committed (file IDs may be internal information; propose `.gitignore` for a shared repo).

## Dependencies / references

- `references/procedure.md`: the full §3 steps, read before running §3.
- `gws` CLI (required; if missing, print install guidance and stop): global flags, auth, and output format live in the gws-shared skill (if installed) or `gws --help`.
- Official gws skills and recipes: the `skills/` directory and `docs/skills.md` of github.com/googleworkspace/cli, read live for situational suggestions.
