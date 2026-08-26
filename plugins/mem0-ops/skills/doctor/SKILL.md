---
name: doctor
description: "Check mem0 configuration posture on this machine — MEM0_RERANK env (unset means rerank ON, against mem0's own best practice), ~/.mem0/settings.json auto_save (the file overrides env on every hook run — common trap), project decay flag, upstream hook UserPromptSubmit timeout budget, and user_id/app_id identity fragmentation. Read-only; suggests fixes but never applies them. Use for 'mem0 설정 점검', hook timeout complaints, or after installing mem0 on a new machine."
---

# doctor

## Codex note

Script is plain `python3` on all runtimes. Codex 0.135 does NOT export
`CLAUDE_PLUGIN_ROOT` — always resolve `PLUGIN_ROOT` first (block below).

## Steps

1. Resolve the plugin root (cross-runtime), then run the check:

   ```bash
   PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
   [ -z "$PLUGIN_ROOT" ] && [ -d plugins/mem0-ops/scripts ] && PLUGIN_ROOT=plugins/mem0-ops
   if [ -z "$PLUGIN_ROOT" ]; then
     cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
     PLUGIN_ROOT=$(ls -1d "$cache_root"/*/mem0-ops/* 2>/dev/null | sort | tail -1)
   fi
   [ -d "$PLUGIN_ROOT/scripts" ] || { echo "mem0-ops scripts not found"; exit 1; }
   python3 "$PLUGIN_ROOT/scripts/doctor.py"
   ```
2. For each WARN, explain the fix but do NOT apply automatically:
   - MEM0_RERANK unset -> add `"MEM0_RERANK": "off"` to `~/.claude/settings.json` env.
   - auto_save true -> set `"auto_save": false` in `~/.mem0/settings.json`
     (env MEM0_AUTO_SAVE does NOT work — upstream `_identity.sh` overwrites it
     from this file on every hook run).
   - hook timeout 8s -> raising it means editing the plugin cache copy, which
     resets on update; prefer rerank off first, upstream issue second.
     Multiple cached versions may be listed — only the session-pinned one is live.
   - identity fragmentation -> consolidate `MEM0_USER_ID` across machines.
3. decay INFO line: if the REST read failed, tell the user to check the GUI
   toggle or run `client.project.get(fields=["decay"])` via the mem0 SDK.
