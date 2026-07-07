---
name: cleanup
description: "Backup-then-delete mem0 noise for one app (default: current project's app_id resolved from cwd like the upstream plugin does) or any app via --app. Dry-run is the default; deletion requires --execute and per-app user confirmation. Full-app teardown (--all) for junk app_ids. Always writes a JSON backup to ~/.mem0/backups/ first; restore = re-add with infer=False. Use for 'mem0 정리', 'session_summary 삭제', junk app teardown after fleet-scan."
---

# cleanup

## Hermes/Codex note

Script is plain `python3` on all runtimes. The confirmation gate uses
`AskUserQuestion` on Claude; on Codex/Hermes ask in plain text and wait
(Hermes: `clarify`).

## Steps

1. Resolve scope: no args = current project (script mirrors upstream chain:
   `MEM0_PROJECT_ID` env -> `~/.mem0/project_map.json` -> git slug -> basename).
   The script REFUSES basename-fallback scope; pass `--app` explicitly then.
2. Dry-run first, always:
   `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/cleanup.py [--app X] --type session_summary`
   (or `--all` for a junk app teardown flagged by fleet-scan).
3. Show the dry-run count + samples to the user, then gate with
   AskUserQuestion (one question per app: delete N of M? yes/no).
4. Only after explicit yes: re-run with `--execute`. Report ok/failed counts
   and the backup path.
5. Verify: run `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/audit.py --app X` and
   confirm the deleted type count is now 0.
6. Restore procedure (if the user regrets): read the backup JSON at
   `~/.mem0/backups/<app>-<date>.json` and re-add each row via mem0
   `add_memory` with `infer=False`, same app_id/user_id/metadata.
