---
name: fleet-scan
description: "Scan ALL mem0 app_ids at once — per-app memory count, noise ratio (session_summary and friends), junk app_id candidates (JUNK? flag), and app/user_id fragmentation pairs. Read-only, deterministic script, zero LLM cost. Use when the user asks for a mem0-wide overview, 'which projects are noisy', 'mem0 전체 점검', or before a cleanup round. Per-project quality (duplicates inside one app) belongs to the upstream mem0 plugin's memory-reviewer instead."
---

# fleet-scan

## Hermes/Codex note

Runs the same on Claude and Codex (script is plain `python3`). On Hermes,
`Bash` maps to `terminal`.

## Steps

1. Run `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/fleet_scan.py`.
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
