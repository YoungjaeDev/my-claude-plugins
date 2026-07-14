---
name: gws-sync
description: 로컬 폴더 → Google Drive 단방향 제안형 동기화 — gws CLI 기반(MCP 아님, 인증 전제). 매핑 설정 파일(.gws-sync.json)로 로컬↔Drive 폴더 대응을 기억하고, 실행 시 Drive 트리를 탐색해 신규·변경 diff 리포트를 만든 뒤, 업로드 위치를 AskUserQuestion으로 승인받아 업로드한다. 삭제는 제안만(자동 삭제 금지). gws 미설치면 공식 docs 설치 안내를 출력하고 중단. 트리거 — "Drive에 올려줘/동기화해줘", "이 폴더 Drive랑 맞춰줘", "산출물 Drive 갱신", "gws sync", "드라이브 업로드". 단발 파일 1개 업로드는 gws-drive-upload 스킬이 가볍다(설치돼 있으면 그쪽 제안).
---

# gws-sync — local → Drive one-way proposal-based sync

**Design principles**: (1) One-way (local → Drive) only — never pull Drive-side changes back to local. (2) Proposal-based — every write happens only after a diff report plus user approval. (3) Never delete automatically (proposal only). (4) Updating a Drive file is a **content update of the existing file**, not a new-file creation (the file ID is kept, so share links and version history survive).

## 0. Prerequisite check (every run)

1. `gws --version` — **if missing, stop** and print install guidance: "gws CLI가 필요합니다. 설치: `npm install -g @googleworkspace/cli` 또는 공식 문서 github.com/googleworkspace/cli 참조. 설치 후 첫 사용이면 `gws auth setup`(1회) → `gws auth login`으로 인증하세요(`gcloud` 미설치 환경은 공식 README의 수동 OAuth 설정 참조)." (Do not install automatically — propose only.)
2. Confirm auth and scope: if a light read call (`gws drive files list --params '{"pageSize": 1}'`) fails, print auth guidance and stop — `gws auth setup` on first use, `gws auth login` thereafter. **A successful read does not guarantee write scope** — if the upload/update step hits a permission error, guide the user to re-authenticate with the drive write scope (e.g. `gws auth login --scopes drive`; confirm the exact flag with `gws auth --help`). Never assume write access from a read check alone.
3. Suggest useful skills (optional): if the task matches another gws skill/recipe in the catalog (e.g. share with the team after upload → recipe-share-folder-with-team), find it in `references/gws-skills-llms.txt` and print an **install-suggestion line** alongside. Confirm the exact install command form with the current `skills` CLI before presenting it (use the form in `references/gws-skills-llms.txt` verbatim, or if unconfirmed just say "설치 방법은 skills CLI로 확인하세요"). Suggest only — never force.

## 1. Mapping config file — `.gws-sync.json`

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

- `files` is a local-filename → Drive-file-ID cache. **A cached ID is only a hint, not a basis for trust** — before updating, always re-confirm in §3-4 that the ID sits inside the approved folder, is not trashed, and matches that local filename uniquely (a stale cache can overwrite the wrong Drive file). It is recorded automatically after the first upload.
- If the config file is absent, create it through the location-approval flow in §2 and store the approved mapping (also confirming whether to "skip the prompt and use this folder from now on").

## 2. Upload-location approval (MANDATORY — AskUserQuestion)

When there is no mapping, or the user names a new target folder:

1. **Walk the Drive tree** — search for candidate folders. Drive query syntax requires the exact folder MIME value `'application/vnd.google-apps.folder'` (`mimeType = folder` does not match), and must exclude trashed items explicitly:
   ```bash
   gws drive files list --params '{"q": "name contains '\''<name>'\'' and mimeType = '\''application/vnd.google-apps.folder'\'' and trashed = false", "fields": "files(id,name,parents)", "supportsAllDrives": true, "includeItemsFromAllDrives": true}'
   ```
   Inspect each candidate folder's children to establish context.
2. **Propose and approve the location via AskUserQuestion** — present 2-3 candidates (plus a "create new folder" option) and write only to the location the user chooses. **No upload without approval.** If a mapping already exists, skip this step (the config is itself the approval record).

## 3. diff report → approval → upload

1. **Local scan**: collect files matching the `include` patterns under the mapping's `local` folder.
2. **Drive scan**: **narrow the scope** to the target folder and list it — a parent filter, trashed exclusion, the shared-drive flags, and pagination are all required (an unconstrained `files list` pulls in unrelated files and pollutes the diff):
   ```bash
   gws drive files list --params '{"q": "'\''<folderId>'\'' in parents and trashed = false", "fields": "nextPageToken, files(id,name,size,modifiedTime,mimeType,parents)", "supportsAllDrives": true, "includeItemsFromAllDrives": true}' --page-all
   ```
3. **diff report** (print as a table):
   - **New**: local-only → an `+upload` target
   - **Changed**: present on both sides and locally different (size differs, or local mtime > Drive modifiedTime) → a content-update target
   - **Identical**: skip
   - **Drive orphan**: Drive-only → **proposal only** ("N files not present locally — please delete them yourself" + the list). Never delete automatically.
4. **Re-confirm update-target IDs (MANDATORY)**: for each "changed" file, from the §3-2 scan results pin down the single Drive item that is **inside the approved folder, trashed=false, and matches that local filename exactly once**. If the cached ID disagrees with that result (outside the folder, trashed, name mismatch) or several same-named files exist, **stop the automatic flow and use AskUserQuestion to let the user pick the target ID**. Update the cache only with the confirmed ID.
5. **Approval**: show the report and confirm whether to proceed (if the new/changed count is 0, report "already in sync" and exit).
5b. **Freeze the approval manifest (MANDATORY)**: immediately after the §5 approval, write only the actually-approved items into a **frozen manifest**. Each item is `{local, action(new|update), target, size, mtime}` — `target` is the destination folderId for `new`, or the fileId confirmed in §4 for `update`. Every subsequent upload reads **only this manifest**. Do not re-scan local between approval and execution to slip in newly-appeared files — the approval is valid only for this list.

   ```json
   {"approved": [
     {"local": "exports/deck.pptx", "action": "update", "target": "1eon6SX...", "size": 91234, "mtime": 1720000000},
     {"local": "exports/notes.pdf", "action": "new", "target": "1aQthLJ...", "size": 20481, "mtime": 1720000100}
   ]}
   ```
6. **Execute — approval manifest only (binding)**: process each manifest item in order. **Immediately before** executing each item, re-read the local file and target ID and compare them against the manifest values — if the file has disappeared, its size/mtime differs from approval time, or an `update` target ID disagrees with the §4-confirmed value, **do not skip just that item; abort the entire run** and return to §3 for a re-diff and re-approval (no silent workaround, no partial force-through). **Never upload a file absent from the manifest, under any circumstances.**
   - New (My Drive folder): `gws drive +upload <file> --parent <folderId>` → record the returned ID in the `files` cache.
   - New (Shared Drive folder): the `+upload` helper does not pass `supportsAllDrives`, so team-Drive uploads fail (upstream googleworkspace/cli #722). If the target folder is a Shared Drive, route around it with the raw create path — `gws drive files create --params '{"supportsAllDrives": true}' --params-name-parents ...` (confirm the exact create arguments and parent-specification syntax with `gws drive files create --help`). Determine whether the mapping's `driveFolderId` belongs to a Shared Drive via the `parents`/drive lookup in the §3-2 scan.
   - Changed: use only the ID confirmed in §4: `gws drive files update --params '{"fileId": "<id>", "supportsAllDrives": true}' --upload <file>` — update the existing ID without creating a new file (update handles both My Drive and Shared Drive via `supportsAllDrives`).
7. **Verify**: after upload, re-query the target folder to confirm counts and names, and report the result as a table.

## Hard rules

- Never run a write (upload/update) without a diff report plus approval.
- **Upload only items present in the §5b approval manifest** — never upload a file absent from the manifest; if a manifest value and reality (local file, target ID) disagree, do not force part of it through — abort and re-approve. Never grow the list by re-scanning after approval.
- Deletion, moving, and permission changes are out of scope for this skill — proposal text only.
- Drive → local download (two-way) is out of scope.
- Even for large or many-file runs, upload one file at a time sequentially (on partial failure, report how far it got).
- Confirm with the user whether `.gws-sync.json` should be committed (file IDs may be internal information — propose `.gitignore` for a shared repo).

## Dependencies / references

- `gws` CLI (required; if missing, print install guidance and stop) — global flags, auth, and output format live in the gws-shared skill (if installed) or `gws --help`.
- `references/gws-skills-llms.txt` — a catalog of the 95 official skills/recipes (54 services + 41 recipes). An index for situational suggestions.
