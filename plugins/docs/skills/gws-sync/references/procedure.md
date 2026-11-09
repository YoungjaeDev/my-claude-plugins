# gws-sync procedure

The full §3 steps (diff report, approval, frozen manifest, upload, verify), read before running §3 of `SKILL.md`. Step numbers match the ones `SKILL.md` and this file cite (§3-2, §3-4, §5, §5b, §6).

## 3. diff report → approval → upload

1. **Local scan**: collect files matching the `include` patterns under the mapping's `local` folder.
2. **Drive scan**: **narrow the scope** to the target folder and list it (a parent filter, trashed exclusion, the shared-drive flags, and pagination are all required): an unconstrained `files list` pulls in unrelated files and pollutes the diff:
   ```bash
   gws drive files list --params '{"q": "'\''<folderId>'\'' in parents and trashed = false", "fields": "nextPageToken, files(id,name,size,modifiedTime,mimeType,parents)", "supportsAllDrives": true, "includeItemsFromAllDrives": true}' --page-all
   ```
3. **diff report** (print as a table):
   - **New**: local-only → an `+upload` target
   - **Changed**: present on both sides and locally different (size differs, or local mtime > Drive modifiedTime) → a content-update target. Normalize both timestamps to UTC epoch-seconds before comparing: local mtime is already epoch, Drive `modifiedTime` is RFC3339, so convert it first (`date -d "$modifiedTime" +%s`).
     - On BSD/macOS strip the trailing `Z` **and** any fractional seconds before parsing: `t="${modifiedTime%Z}"; date -u -jf %Y-%m-%dT%H:%M:%S "${t%.*}" +%s`. A zero-fraction `...:56Z` has no dot for `%.*` to cut, so the `Z` must be removed separately or the parse fails.
     - Comparing the epoch integer against the raw RFC3339 string is meaningless and misclassifies changed files.
   - **Identical**: skip
   - **Drive orphan**: Drive-only → **proposal only** ("N files not present locally, please delete them yourself" + the list). Never delete automatically.
   - **Snapshot for approval binding**: while building this report, capture each New/Changed file's `{sha256, size, mtime}` **at this diff moment** (`sha256sum "$f" 2>/dev/null || shasum -a 256 "$f"`; record `null` if neither tool exists). This diff-time snapshot is the exact bytes the user sees in the report, so it, not a later re-read, is what §5b freezes and §6 re-verifies against.
4. **Re-confirm update-target IDs (MANDATORY)**: for each "changed" file, from the §3-2 scan results pin down the single Drive item that is **inside the approved folder, trashed=false, and matches that local filename exactly once**. If the cached ID disagrees with that result (outside the folder, trashed, name mismatch) or several same-named files exist, **stop the automatic flow and use AskUserQuestion to let the user pick the target ID**. Update the cache only with the confirmed ID.
5. **Approval**: show the report and confirm whether to proceed (if the new/changed count is 0, report "already in sync" and exit).
5b. **Freeze the approval manifest (MANDATORY)**: immediately after the §5 approval, write only the actually-approved items into a **frozen manifest**.
   - Each item is `{local, action(new|update), target, size, mtime, sha256}`; `target` is the destination folderId for `new`, or the fileId confirmed in §4 for `update`; `size`/`mtime`/`sha256` are the **§3 diff-time snapshot** (the exact bytes the user saw), not a fresh read.
   - Before freezing, re-read each approved file **once** and compare it to its §3 snapshot: if any file changed between the diff and the approval (`sha256` differs, or size/mtime differs when the snapshot hash is `null`), **do not freeze; abort and return to §3** for a re-diff and re-approval, so the manifest can never bind to bytes the user did not approve.
   - When no hash tool exists the §3 snapshot degrades to size+mtime, and this re-check degrades with it.
   - Every subsequent upload reads **only this frozen manifest**. Do not re-scan local between approval and execution to slip in newly-appeared files: the approval is valid only for this list.

   ```json
   {"approved": [
     {"local": "exports/deck.pptx", "action": "update", "target": "1eon6SX...", "size": 91234, "mtime": 1720000000, "sha256": "9f86d081884c7d65..."},
     {"local": "exports/notes.pdf", "action": "new", "target": "1aQthLJ...", "size": 20481, "mtime": 1720000100, "sha256": "2c26b46b68ffc68f..."}
   ]}
   ```
6. **Execute: approval manifest only (binding)**: process each manifest item in order.
   - **Immediately before** executing each item, re-read the local file and target ID and compare them against the manifest values. If the file has disappeared, its **recomputed `sha256` differs** from the manifest value, or an `update` target ID disagrees with the §4-confirmed value, **do not skip just that item; abort the entire run** and return to §3 for a re-diff and re-approval (no silent workaround, no partial force-through).
   - When the manifest recorded `"sha256": null`, compare size/mtime against the frozen §3 snapshot instead; metadata gates only in that degraded case. A matching hash with a drifted mtime (e.g. a build tool touching the file) is not a mismatch.
   - The hash re-check is the real gate: size and mtime can coincide across different content, so bytes that changed after approval slip through a metadata-only compare but not a content compare. **Never upload a file absent from the manifest, under any circumstances.**
   - New (My Drive folder): `gws drive +upload <file> --parent <folderId>` → record the returned ID in the `files` cache.
   - New (Shared Drive folder): the `+upload` helper does not pass `supportsAllDrives`, so team-Drive uploads fail[^722]. If the target folder is a Shared Drive, route around it with the raw create path: `gws drive files create --params '{"supportsAllDrives": true}' --params-name-parents ...` (confirm the exact create arguments and parent-specification syntax with `gws drive files create --help`). Determine whether the mapping's `driveFolderId` belongs to a Shared Drive via the `parents`/drive lookup in the §3-2 scan.
   - Changed: use only the ID confirmed in §4: `gws drive files update --params '{"fileId": "<id>", "supportsAllDrives": true}' --upload <file>` (update the existing ID without creating a new file; update handles both My Drive and Shared Drive via `supportsAllDrives`).
7. **Verify**: after upload, re-query the target folder to confirm counts and names, and report the result as a table.

[^722]: Upstream issue googleworkspace/cli #722.
