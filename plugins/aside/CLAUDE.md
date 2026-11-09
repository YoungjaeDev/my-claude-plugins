# aside

Website work through the user's own Aside browser, driven by the Aside CLI, with 2 skills and 1 agent. The coding conversation hands the task to a subagent so browser output never floods it. Claude-only: the entry skill forks into a plugin agent, and Codex ignores `agents/`.

## Shape

| Piece | Where |
|---|---|
| Entry point | `/aside:aside` (`skills/aside`, `context: fork`, `agent: aside:operator`, waits for the result) |
| Worker | `agents/operator.md`, preloads `aside:browser-ops` (not user-invocable); the worker rules live in that skill body |
| Gate | `$OPS_ROOT/bin/aside_gate.py` (`--root "$OPS_ROOT"` then `status` / `run` / `release`). `scripts/aside_gate.py` only forwards old calls to it |
| Runtime source | `runtime/` mirrors the runtime-owned part of `OPS_ROOT` (`bin/`, `README.md`, `SSH.md`, `templates/`); install with `mkdir -p "$OPS_ROOT" && cp -R runtime/. "$OPS_ROOT/"` |
| Records | `OPS_ROOT` = `ASIDE_OPS_ROOT` or `~/aside-ops`: `README.md`, `SSH.md`, `runs/<request-id>/`, `sites/<domain>/playbook.md`, `artifacts/` |
| Executable | `ASIDE_BIN` or `aside` on PATH |
| Docs | `aside --help`, `aside guide` first; then the caller's `mcpdocs` server with an Aside source (`https://docs.aside.com/llms.txt`) |

Requires a logged-in Aside CLI, Python 3, and the runtime installed under `OPS_ROOT`; without it the worker stops with a prerequisite blocker (exit 127 from the forwarder, which prints the install command). The gate uses POSIX `fcntl`, so it runs on macOS and Linux only.

## Decisions

- **One gate, run from `OPS_ROOT`**: Claude Code, Hermes and remote SSH callers all run `$OPS_ROOT/bin/aside_gate.py`, so removing or upgrading the plugin never splits the lock. `runtime/` is the distribution copy: never run it in place and never add a fallback lock.
- **Cooperative, not a sandbox**: a reservation (`.coordination/owner.json`) belongs to the pair (owner, request ID), holds across CLI calls, and refuses anything else with exit 75; `flock` covers the command in flight. A direct `aside` call bypasses it.
- **Reservations never expire**: they are released only after verified completion or cancellation, and nothing steals a stale one. A dead CLI process is not evidence the browser task stopped.
- **Runtime docs are stamped copies**: edits under `runtime/` reach a user's `OPS_ROOT` only when they re-run the install command.
- **No bundled MCP server**: documentation comes from the caller's existing `mcpdocs` (kept on `mcp<2`); the plugin never registers or reconfigures MCP servers.
