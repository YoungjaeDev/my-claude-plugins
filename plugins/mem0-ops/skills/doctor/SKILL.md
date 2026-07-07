---
name: doctor
description: "Check mem0 configuration posture on this machine — MEM0_RERANK env (unset means rerank ON, against mem0's own best practice), ~/.mem0/settings.json auto_save (the file overrides env on every hook run — common trap), project decay flag, upstream hook UserPromptSubmit timeout budget, and user_id/app_id identity fragmentation. Read-only; suggests fixes but never applies them. Use for 'mem0 설정 점검', hook timeout complaints, or after installing mem0 on a new machine."
---

# doctor

## Hermes/Codex note

Runs the same on Claude and Codex (script is plain `python3`). On Hermes,
`Bash` maps to `terminal`.

## Steps

1. Run `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/doctor.py`.
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
