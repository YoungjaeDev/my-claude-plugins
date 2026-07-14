# mem0-ops

Fleet-level mem0 diagnostics and cleanup. Roles are split from the upstream
`mem0@mem0-plugins` (which owns in-project memory quality:
health/memory-reviewer/stats/dream) — this plugin handles only cross-`app_id`
operations. Do not duplicate upstream functionality.

| Skill | Role |
|---|---|
| `fleet-scan` | Fleet-wide noise-rate, junk-candidate, and fragmentation report (read-only) |
| `doctor` | Configuration-posture checks — rerank env, the auto_save file-precedence trap, decay, hook timeout, identity fragmentation (suggestions only) |
| `cleanup` | Backup, then delete by type or app. Dry-run by default; `--execute` plus a skill-layer user confirmation gates it (running the script standalone is gated by `--execute` alone) |

The scripts are stdlib-only and talk to the REST API directly
(`scripts/_api.py`), with no dependency on the upstream scripts or venv.
`MEM0_API_KEY` is required. Design spec:
`docs/superpowers/specs/2026-07-07-mem0-ops-plugin-design.md`.
