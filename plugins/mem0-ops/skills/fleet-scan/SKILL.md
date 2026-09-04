---
name: fleet-scan
description: "Scan ALL mem0 app_ids at once — per-app memory count, noise ratio (session_summary and friends), junk app_id candidates (JUNK? flag), and app/user_id fragmentation pairs — plus local config-posture checks (MEM0_RERANK env, ~/.mem0/settings.json auto_save precedence trap, decay flag, hook timeout budget; absorbed from doctor). Read-only, deterministic scripts, zero LLM cost. Use for a mem0-wide overview, 'which projects are noisy', 'mem0 전체 점검', 'mem0 설정 점검', hook timeout complaints, or before a cleanup round. Per-project quality (duplicates inside one app) belongs to the upstream mem0 plugin's memory-reviewer instead."
---

# fleet-scan

## Codex note

Script is plain `python3` on all runtimes. Codex 0.135 does NOT export
`CLAUDE_PLUGIN_ROOT` — always resolve `PLUGIN_ROOT` first (block below).

## Steps

1. Resolve the plugin root (cross-runtime), then run the scan:

   ```bash
   PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
   [ -z "$PLUGIN_ROOT" ] && [ -d plugins/mem0-ops/scripts ] && PLUGIN_ROOT=plugins/mem0-ops
   if [ -z "$PLUGIN_ROOT" ]; then
     cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
     PLUGIN_ROOT=$(ls -1d "$cache_root"/*/mem0-ops/* 2>/dev/null | sort | tail -1)
   fi
   [ -d "$PLUGIN_ROOT/scripts" ] || { echo "mem0-ops scripts not found"; exit 1; }
   # Interpreter detection — python3 alone breaks python.org Windows installs; validate
   # the candidate really is Python 3 (a python->python2 alias would die on f-strings)
   PY=""; for c in python3 python "py -3"; do
     if $c -c 'import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then PY=$c; break; fi
   done
   [ -n "$PY" ] || { echo "no Python 3 interpreter found (tried python3, python, py -3)"; exit 1; }
   $PY "$PLUGIN_ROOT/scripts/fleet_scan.py"
   ```

   - Requires `MEM0_API_KEY`; the script exits with guidance if unset.
   - Full-fleet scan pages every app — expect ~1-2 minutes on large stores.
2. Interpret the report for the user:
   - `JUNK?` flag = basename-style name + noise >= 90% + zero manual types.
     These are cwd-fallback artifacts; suggest `cleanup --app <name> --all`.
   - `FRAG` pairs = same project split across two app_ids (recall is split).
     Merge is out of scope v1 — report only.
   - High noise% on a real project = suggest
     `cleanup --app <name> --type session_summary`.
3. Do NOT delete anything from this skill. Route to the cleanup skill.

## Config posture (absorbed from doctor)

When the user asks about local mem0 configuration ('mem0 설정 점검', hook timeouts, rerank) rather than fleet contents, run the posture check. Shell state does not persist across tool calls, so this block re-resolves `PLUGIN_ROOT` and the interpreter itself:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && [ -d plugins/mem0-ops/scripts ] && PLUGIN_ROOT=plugins/mem0-ops
if [ -z "$PLUGIN_ROOT" ]; then
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  PLUGIN_ROOT=$(ls -1d "$cache_root"/*/mem0-ops/* 2>/dev/null | sort | tail -1)
fi
[ -d "$PLUGIN_ROOT/scripts" ] || { echo "mem0-ops scripts not found"; exit 1; }
PY=""; for c in python3 python "py -3"; do
  if $c -c 'import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then PY=$c; break; fi
done
[ -n "$PY" ] || { echo "no Python 3 interpreter found (tried python3, python, py -3)"; exit 1; }
$PY "$PLUGIN_ROOT/scripts/doctor.py"
```

For each WARN, explain the fix but do NOT apply automatically:

- MEM0_RERANK unset -> add `"MEM0_RERANK": "off"` to `~/.claude/settings.json` env.
- auto_save true -> set `"auto_save": false` in `~/.mem0/settings.json` (env `MEM0_AUTO_SAVE` does NOT work — upstream `_identity.sh` overwrites it from this file on every hook run).
- hook timeout 8s -> raising it means editing the plugin cache copy, which resets on update; prefer rerank off first, upstream issue second. Multiple cached versions may be listed — only the session-pinned one is live.
- identity fragmentation -> consolidate `MEM0_USER_ID` across machines.
- decay INFO line: if the REST read failed, tell the user to check the GUI toggle or run `client.project.get(fields=["decay"])` via the mem0 SDK.
