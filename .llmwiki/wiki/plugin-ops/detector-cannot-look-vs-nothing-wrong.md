---
id: detector-cannot-look-vs-nothing-wrong
aliases: [pipefail-kills-detector, jq-failure-in-command-substitution, argjson-strict-json, read-only-detector-silent-failure]
last_verified: 2026-07-10
status: active
volatility: stable
sources: 2
---

# A detector must never report "nothing wrong" when it means "could not look"

Read-only detectors — the scripts that answer "is this repo wired up?" — have two failure modes that both look like success. One kills the whole run and produces no output; the other produces confident output that is wrong. Both were found in `plugins/project-init/scripts/project_state.sh`, one per release.

## Mode 1: one axis fails, the whole diagnostic disappears

`set -euo pipefail` turns any non-zero exit inside a command substitution into a script abort. Two commands routinely exit non-zero on perfectly normal input:

- `find` signals "no match" with exit 1. `MATCHES=$(find . -name '*.py' | wc -l)` therefore kills the script on a repo that happens to have no Python.
- `jq` exits non-zero on a corrupt input file. `KEYS=$(jq -r '.mcpServers|keys[]' ~/.claude.json)` kills the script when the user's config is malformed.

The user sees no JSON, no partial report, and no obvious cause. The symptom reads as "the tool is broken", not "one of your config files is". Measured: a `~/.claude.json` containing `NOT JSON` made the script exit 5 with zero bytes of output; every other axis was healthy.

The fix is not `|| true` at the top level. It is to **contain the failure inside the axis that owns it** and surface the fact that the axis could not be evaluated:

```bash
mcp_readable() { jq -e 'type=="object" and ((.mcpServers // {})|type)=="object"' "$1" >/dev/null 2>&1; }
# ...
if ! mcp_readable "$f"; then unreadable+=("$f"); fi
```

## Mode 2: `|| true` turns a failure into a false clean

Once the abort is patched with `|| true`, the failure becomes invisible instead of fatal. `jq -r '.mcpServers // {} | keys[]' "$f" 2>/dev/null | sort || true` returns **zero keys** for a corrupt file, a file whose `.mcpServers` is `"x"` (jq errors on `keys` of a string), and a file whose `.mcpServers` is `[]` (jq returns array *indices*). All three then report **"no duplicate MCP servers"**, which is a lie: the truth is "I could not compare them."

Guard on the question you are actually asking. "Is this valid JSON?" is not the question — an empty file is valid input to `jq`, and `{"mcpServers": []}` is valid JSON. The question is "can I enumerate `mcpServers` as an object?", and everything else is `unreadable`, reported as its own state.

## Mode 3: the value crosses into `--argjson`

`jq --argjson name "$v"` demands strict JSON. Values scraped out of foreign config formats are not JSON:

- TOML permits an inline comment after a value, so `project_doc_max_bytes = 65536 # bytes` yields `65536 # bytes`.
- TOML permits `_` digit separators, so `65_536` is a valid integer that `--argjson` rejects.

Both spellings are *correct configuration* and both aborted the script before it printed anything. Normalize (cut at the first space-hash, strip separators), validate (`case "$v" in *[!0-9]*)`), and fall back to the documented default. Never hand a foreign format's raw bytes to a strict parser.

Related trap in the same family: `${f#$HOME/}` is a **pattern** expansion, so a `$HOME` containing glob characters mangles the stripped path. Quote the prefix: `${f#"$HOME/"}`.

## Why this recurs

Each instance arrives disguised as an edge case ("who has a corrupt config?"), and each one is discovered only by running the script against the ugly input rather than reading it. The invariant is cheap to state and hard to remember: **a diagnostic that cannot evaluate an axis says so, keeps going, and never converts ignorance into an all-clear.**

> See-also: [[jq-capture-yields-empty]]
> See-also: [[worktree-squash-merge-gotchas]]
> Evidence: plugins/project-init/scripts/project_state.sh
> Evidence: plugins/project-init/CLAUDE.md

## Sources

1. **PR #104** (`feat(project-init): add wiring skill with shared state detector`) — the `find` / `pipefail` instance. `find ... | wc -l` killed the script on an empty match; `find | head -1 | grep -q .` inverted its own result via SIGPIPE(141). Fixed with `find_or_empty` / `count_files` helpers and `-print -quit`.
2. **PR #106** (`feat(project-init): ASK verdict class + three efficacy axes for wiring`) — the `jq` instances. Reproduced across corrupt / empty / `[]` / `"x"` / top-level-array `~/.claude.json`, and across `65536`, `65536 # bytes`, `65_536`, `"65536"`, `abc`, key-absent, config-absent for `project_doc_max_bytes`. Before the fix: exit 2 or exit 5, zero output. After: exit 0 in every case, with `mcp.unreadable` naming the file it could not read.
