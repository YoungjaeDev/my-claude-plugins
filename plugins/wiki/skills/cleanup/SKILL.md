---
name: cleanup
description: "Backup-then-delete mem0 noise for one app (default: current project's app_id resolved from cwd like the upstream plugin does) or any app via --app. Dry-run is the default; deletion requires --execute and per-app user confirmation. Full-app teardown (--all) for junk app_ids. Always writes a JSON backup to ~/.mem0/backups/ first; restore = re-add with infer=False. Use for 'mem0 정리', 'session_summary 삭제', junk app teardown after fleet-scan."
---

# cleanup

## Codex note

Script is plain `python3` on all runtimes. The confirmation gate uses
`AskUserQuestion` on Claude; on Codex ask in plain text and wait.
Codex 0.135 does NOT export `CLAUDE_PLUGIN_ROOT`:
always resolve `PLUGIN_ROOT` first (block below).

## Steps

1. Resolve the plugin root (cross-runtime):

   ```bash
   PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
   [ -z "$PLUGIN_ROOT" ] && [ -d plugins/wiki/scripts ] && PLUGIN_ROOT=plugins/wiki
   if [ -z "$PLUGIN_ROOT" ]; then
     cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
     PLUGIN_ROOT=$(ls -1d "$cache_root"/*/wiki/* 2>/dev/null | sort | tail -1)
   fi
   [ -d "$PLUGIN_ROOT/scripts" ] || { echo "wiki scripts not found"; exit 1; }
   ```

   Scope: no args = current project (script mirrors upstream chain:
   `MEM0_PROJECT_ID` env -> `~/.mem0/project_map.json` -> git slug -> basename).
   The script REFUSES basename-fallback scope; pass `--app` explicitly then.
   `--type` additionally requires a user scope (`--user` or `MEM0_USER_ID`);
   only `--all` targets every entity scope (user/agent/run) in the app.
2. Dry-run first, always:
   `python3 "$PLUGIN_ROOT/scripts/cleanup.py" [--app X] --type session_summary`
   (or `--all` for a junk app teardown flagged by fleet-scan).
3. Show the dry-run count + samples to the user, then gate with
   AskUserQuestion (one question per app: delete N of M? yes/no).
4. Only after explicit yes: re-run with `--execute`. Report ok/failed counts
   and the backup path.
5. Verify: run `python3 "$PLUGIN_ROOT/scripts/audit.py" --app X` and
   confirm the deleted type count is now 0.
6. Restore procedure (if the user regrets): read the backup JSON at
   `~/.mem0/backups/<app>-<timestamp>.json`: it holds `{app, target_ids,
   rows}` where `rows` is the WHOLE app at backup time and `target_ids`
   lists what was actually deleted. Re-add ONLY the rows whose id is in
   `target_ids` via mem0 `add_memory` with `infer=False`, same
   app_id/user_id/metadata; re-adding all rows would duplicate the
   untouched ones.
