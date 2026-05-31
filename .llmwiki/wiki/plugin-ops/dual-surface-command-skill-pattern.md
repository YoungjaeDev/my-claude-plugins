---
id: dual-surface-command-skill-pattern
aliases: [dual-surface-plugin, command-skill-shared-references, codex-claude-portability]
last_verified: 2026-05-31
status: active
volatility: stable
sources: 4
---

# Dual-surface command + skill pattern

A plugin in this marketplace can expose the same workflow through two surfaces:

- **Command** (`commands/*.md`) — explicit user invocation via slash command
  (`/plugin:command-name`). Claude Code only.
- **Skill** (`skills/<name>/SKILL.md`) — capability discovery; the model
  reaches for it when a conversational trigger matches the skill description.
  Claude Code AND Codex 0.135.

When a workflow benefits from both — explicit invocation by users who already
know the command exists, plus capability discovery for users who don't — ship
both, but never duplicate the body. Both surfaces resolve a shared procedure
file in `references/<name>-procedure.md`.

## Why this pattern exists

Before this pattern, command-only plugins had nothing to expose on the Codex
side ([[shared-source-codex-manifests]] — Codex 0.135's manifest does not
recognize `commands`). They ended up in the generator's `EXCLUDED` set and
were unreachable from Codex sessions. Conversely, skill-only plugins lost
the explicit-typing surface that users had built muscle memory for.

The pattern lets a plugin be Codex-eligible without rewriting the existing
command surface or duplicating its body.

## Required directory layout

```
plugins/<name>/
├── commands/
│   └── <name>.md                # Thin pointer — frontmatter + arg parsing +
│                                # "See references/<name>-procedure.md".
├── skills/
│   └── <name>/
│       └── SKILL.md             # Thin pointer + (when destructive) runtime
│                                # safety guard at Step 0. Body delegates to
│                                # references/<name>-procedure.md.
├── references/
│   └── <name>-procedure.md      # The actual workflow body. Single source.
└── .claude-plugin/plugin.json   # commands: [...] AND skills: [...]
```

The procedure file is plain Markdown describing the workflow; it does NOT
have skill frontmatter. Skill frontmatter belongs only on `SKILL.md`.

## The skill description must be narrow

Description-based skill matching means the model decides when to invoke based
on phrasing. For destructive plugins (e.g. `project-init` runs `gh repo create`
and seeds files into `$PWD`), a broad description like "Use when bootstrapping
a project" misfires on phrases like "set up X" or "initialize Y" in a directory
that already has code.

Counter-measures, in order of strength:

1. **Narrow trigger phrasing** in the description (`description:` frontmatter).
   List explicit trigger phrases. Document what the skill must NOT fire on.
2. **Runtime hard guard** at the top of `SKILL.md`. Even if the description
   matches incorrectly, a `find` block that aborts on non-empty cwd refuses
   damage. The guard duplicates at the command surface for symmetry. See
   `plugins/project-init/skills/new/SKILL.md` Step 0 for the canonical form.
3. Document the duplication contract — `plugins/<plugin>/CLAUDE.md` must call
   out that both surfaces carry the same guard so a future edit doesn't drift
   them apart.

The runtime guard is what actually prevents damage; the description is the
soft-fence. Do not skip the hard guard on the assumption "the model will read
the description correctly".

## Cross-runtime path resolution

`${CLAUDE_PLUGIN_ROOT}` is a Claude Code env var. Codex 0.135 does NOT export
an equivalent. Skills that need to invoke scripts or copy assets from the
plugin's installed root must resolve the path portably.

For SKILL.md / command files that only point to a procedure document, prefer
the relative-path phrasing — "See `references/<name>-procedure.md` in this
plugin's installed root" — so the model resolves the path against its own
location. Optionally annotate "(`${CLAUDE_PLUGIN_ROOT}/references/...` under
Claude; same relative path under the Codex plugin cache)" for clarity, but
do not let the env var be the only resolution hint.

For procedure files whose bash blocks actually read scripts or copy assets,
prepend a `PLUGIN_ROOT` resolver to Phase 0:

```bash
PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$PLUGIN_ROOT" ]; then
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  if sort -V </dev/null >/dev/null 2>&1; then
    candidate=$(ls -1d "$cache_root"/*/<plugin>/* 2>/dev/null | sort -V | tail -1)
  else
    candidate=$(ls -1d "$cache_root"/*/<plugin>/* 2>/dev/null | sort | tail -1)
  fi
  [ -n "$candidate" ] && [ -d "$candidate" ] && PLUGIN_ROOT="$candidate"
fi
if [ -z "$PLUGIN_ROOT" ] \
    || [ ! -d "$PLUGIN_ROOT/scripts" ] || [ ! -r "$PLUGIN_ROOT/scripts" ] \
    || [ ! -d "$PLUGIN_ROOT/assets" ]  || [ ! -r "$PLUGIN_ROOT/assets" ]; then
  echo "[abort] could not resolve PLUGIN_ROOT" >&2; exit 1
fi
```

Subsequent bash blocks use `${PLUGIN_ROOT}/scripts/...` rather than
`${CLAUDE_PLUGIN_ROOT}/scripts/...`. Resolution order:

1. caller-supplied `PLUGIN_ROOT` (escape hatch for unusual install layouts)
2. `${CLAUDE_PLUGIN_ROOT}` (Claude Code path)
3. `~/.codex/plugins/cache/<marketplace>/<plugin>/<version>/` (Codex 0.135 path,
   overridable via `CODEX_PLUGIN_CACHE`)
4. abort with explicit message asking the user to export `PLUGIN_ROOT`

The validator MUST check `scripts/` AND `assets/` (whichever are referenced
later). Checking only one delays failure to mid-procedure when a copy or
script invocation breaks instead of failing fast at Phase 0.

### macOS / BSD shell portability

`sort -V` is GNU-only. macOS / BSD `sort` silently lacks `-V`, which would
break the cache-version selection above. Probe the flag first
(`sort -V </dev/null >/dev/null 2>&1`) and fall back to plain `sort` —
lexicographic ordering picks the right version for typical X.Y.Z patterns
under 10.

The same probe-and-fallback shape applies to other GNU-only flags the
procedure may use (`sed -i` signature, `${VAR,,}` Bash 4+, etc.).

## Versioning

A dual-surface conversion is a MINOR bump for the plugin (new skill surface
is backward-compatible — the command stays). The marketplace `metadata.version`
also bumps MINOR because newly-Codex-eligible plugins is a backward-compatible
addition to the marketplace catalog.

## Sources

- `plugins/deepwiki/skills/{ask,generate-llmstxt}/SKILL.md` — minimal
  dual-surface case (no scripts, no assets — pure MCP wrapper). Documents the
  description tuning for fuzzy capability discovery.
- `plugins/project-init/skills/new/SKILL.md` + `references/new-procedure.md` —
  destructive plugin case. Demonstrates the hard runtime guard and the
  `PLUGIN_ROOT` resolver pattern.
- `plugins/project-init/CLAUDE.md` — documents the dual-surface contract: both
  surfaces must carry the same preflight guard, and the resolver in the
  procedure file is the single point that turns `${PLUGIN_ROOT}` into a real
  filesystem path under both runtimes.
- PR #41 review iters 1-4 — the cr-fix loop surfaced both portability defects
  (`${CLAUDE_PLUGIN_ROOT}` non-expansion under Codex, `sort -V` BSD breakage)
  and validated the guard scope (the original guard's depth-2 source-file list
  let `Dockerfile`, `Makefile`, `.env`, `docs/*`, and deeper sources slip
  through).

> Refines: [[shared-source-codex-manifests]]
> See-also: [[neutral-llmwiki-root]]
> Evidence: plugins/project-init/references/new-procedure.md
> Evidence: plugins/deepwiki/skills/ask/SKILL.md
