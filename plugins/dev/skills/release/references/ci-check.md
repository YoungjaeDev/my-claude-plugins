# Release-tag CI check

`/dev:release` never waits for the CI a tag push starts. A run that could not start still has to reach the user: on 2026-11-01 the `v2.78.0` jobs never got a runner because the account was billing-locked, and no report showed it for 8 days.

`scripts/ci-run-check.sh <tag>` reads the tag's runs once. It prints one line per run (`status/conclusion` and URL), and one `WARNING` line per job that completed with 0 steps and no runner, quoting the job's failure annotation. A queued job (no runner yet) and a skipped job are not flagged. It runs twice per release:

- **Before the release** (Step 2, on `PREV_TAG`): put its lines in the Step 5 preview. A warning does not block the release, but say plainly that the previous release's CI never ran.
- **After the release** (Step 10, on the new tag): run it once, right after `gh release create`, and add its lines to the output. Do not poll or wait. `no workflow run found` at this point can mean the run is not created yet, so report it as such, with the repository's Actions tab as the place to look.

## Reading the result

- Exit 0: relay the lines as printed.
- A billing-lock annotation adds the line `unlock it in GitHub Settings -> Billing and plans`. Pass it on: only the account owner can lift the lock, and no CI run on any tag starts until then.
- Exit 1: `gh` or `jq` failed, so the CI state is unknown. Report it as unknown, never as "no run" or "passed", and continue the release.

## Calling it

Codex exports no `CLAUDE_PLUGIN_ROOT`, so resolve the script the way `post-merge` does:

```bash
# Ranked on the version basename, so the marketplace dir cannot outrank the version.
# `|| true`: an empty cache is normal on Claude-only hosts.
CACHE_ROOT="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
if sort -V </dev/null >/dev/null 2>&1; then
  CODEX_CAND=$(ls -1d "$CACHE_ROOT"/*/dev/* 2>/dev/null \
    | awk -F/ '{print $NF "\t" $(0)}' | sort -V | tail -1 | cut -f2- || true)
else
  CODEX_CAND=$(ls -1d "$CACHE_ROOT"/*/dev/* 2>/dev/null \
    | awk -F/ '{print $NF "\t" $(0)}' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1 | cut -f2- || true)
fi
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$CLAUDE_PLUGIN_ROOT/skills/release/scripts/ci-run-check.sh" ]; then
  SKILL_DIR="$CLAUDE_PLUGIN_ROOT/skills/release"
elif [ -f "plugins/dev/skills/release/scripts/ci-run-check.sh" ]; then
  SKILL_DIR="plugins/dev/skills/release"
elif [ -n "$CODEX_CAND" ] && [ -f "$CODEX_CAND/skills/release/scripts/ci-run-check.sh" ]; then
  SKILL_DIR="$CODEX_CAND/skills/release"
else
  echo "release: ci-run-check.sh not found; CI state unknown" >&2
  SKILL_DIR=""
fi
[ -n "$SKILL_DIR" ] && bash "$SKILL_DIR/scripts/ci-run-check.sh" "<TAG>"
```
