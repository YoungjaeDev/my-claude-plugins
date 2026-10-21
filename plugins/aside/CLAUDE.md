# aside

Website work through the user's own Aside browser, driven by the Aside CLI. The coding
conversation hands the task to a subagent so browser output never floods it. Claude-only: the
entry skill forks into a plugin agent, and Codex ignores `agents/`.

## Shape

| Piece | Where |
|---|---|
| Entry point | `/aside:aside` (`skills/aside`, `context: fork`, `agent: aside:operator`, waits for the result) |
| Worker | `agents/operator.md`, preloads `aside:browser-ops` (not user-invocable) |
| Gate | `$OPS_ROOT/bin/aside_gate.py` (`--root "$OPS_ROOT"` then `status` / `run` / `release`). `scripts/aside_gate.py` only forwards old calls to it |
| Runtime source | `runtime/` mirrors the runtime-owned part of `OPS_ROOT` (`bin/`, `README.md`, `SSH.md`, `templates/`); install with `mkdir -p "$OPS_ROOT" && cp -R runtime/. "$OPS_ROOT/"` |
| Records | `OPS_ROOT` = `ASIDE_OPS_ROOT` or `~/aside-ops`: `README.md`, `SSH.md`, `runs/<request-id>/`, `sites/<domain>/playbook.md`, `artifacts/` |
| Executable | `ASIDE_BIN` or `aside` on PATH |
| Docs | `aside --help`, `aside guide` first; then the caller's `mcpdocs` server with an Aside source (`https://docs.aside.com/llms.txt`) |

Requires a logged-in Aside CLI, Python 3, and the runtime installed under `OPS_ROOT`. Without it
the worker stops with a prerequisite blocker (exit 127 from the forwarder, which prints the install
command). The gate uses POSIX `fcntl`, so it runs on macOS and Linux only.

## Design decisions worth not re-litigating

- **One gate implementation, run from `OPS_ROOT`.** Claude Code, Hermes, and remote SSH callers
  all run `$OPS_ROOT/bin/aside_gate.py`, so removing or upgrading the plugin never splits the lock.
  The plugin's `runtime/` is the distribution copy, not a second gate: never run it in place and
  never add a fallback lock implementation.
- **The worker never installs the runtime itself.** Installing writes to the user's home, so it
  hands the command back and the user approves it.
- **The gate is cooperative, not a sandbox.** A reservation (`.coordination/owner.json`) belongs to
  the pair (owner, request ID), holds across CLI calls, and refuses anything else with exit 75;
  `flock` covers the command in flight. A direct `aside` call bypasses it.
- **Only a proven prelaunch failure clears a reservation**, and only one this call created. Once
  the Aside process starts, any exit code (126/127 included) keeps the reservation.
- **Remote callers do not need this plugin.** A Linux agent can SSH to the Mac and run the gate and
  Aside directly (`$OPS_ROOT/SSH.md`); the plugin is for callers that choose a Claude worker.
- **Reservations never expire.** They are released only after the worker verifies completion or
  cancellation. `running`, `waiting_for_user`, and `unknown` keep theirs; nothing steals a stale
  one automatically. A dead CLI process is not evidence the browser task stopped.
- **Login, 2FA, and approvals end the worker, not the task.** The worker writes
  `waiting_for_user` with the actual Aside session ID and returns; continuation resumes that same
  Aside session. A new Claude worker is fine, a duplicate Aside task is not.
- **Exit 0 is not completion.** Success is the target page or file observed again.
- **Claude IDs and Aside session IDs are different things** and are recorded separately.
- **No bundled MCP server.** Documentation comes from the caller's existing `mcpdocs` (kept on
  `mcp<2`); the plugin never registers or reconfigures MCP servers.
