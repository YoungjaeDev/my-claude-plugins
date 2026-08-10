# Runtime contract

What a skill in this repository owes the three runtimes that load it: Claude Code, Codex 0.135, and
Hermes Agent. All three read the same `plugins/<name>/` tree — there is no per-runtime mirror — so a
body that assumes one runtime's behavior is wrong on the other two without saying so.

Every failure below is **silent**. Nothing errors; the skill simply is not there, or stops at its
first step.

## Silent failures

| Violation | What happens | Caught by |
|---|---|---|
| `description` over 1024 characters | Codex 0.135 skips the skill. Claude Code loads it normally, so the loss is invisible from the authoring side | `scripts/check-skill-contract.mjs` |
| unquoted `: ` inside `description` | YAML parses the value as a nested mapping; the frontmatter fails and the skill loads with no description on both runtimes | `scripts/check-skill-contract.mjs` |
| bare `${CLAUDE_PLUGIN_ROOT}` | Codex 0.135 does not export it, so a bundled-script call resolves to `/scripts/...` and dies at step one | `scripts/check-skill-contract.mjs` |
| `name` non-kebab or over 64 characters | the command name stops being predictable from the tree, and the Codex validator rejects an empty name | `scripts/check-skill-contract.mjs` |
| frontmatter not starting at byte 0 | no runtime finds the frontmatter; the skill has no description and never triggers | `scripts/check-skill-contract.mjs` |
| hardcoded `AskUserQuestion` | Hermes has no such tool, so the interaction gate stalls | `scripts/check-skill-tool-portability.mjs` |
| `disable-model-invocation: true` | the Codex plugin validator rejects the plugin | reviewed by hand; see `frontmatter.md` |

## Calling a bundled script

Use a resolver, never `${CLAUDE_PLUGIN_ROOT}` on its own. The block below tries the Claude
variable, then the source tree, then the Codex plugin cache, and fails loudly rather than running
against an empty path:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && [ -d plugins/docs-forge/skills ] && PLUGIN_ROOT=plugins/docs-forge
if [ -z "$PLUGIN_ROOT" ]; then
  # Rank Codex cache candidates on the version basename, not the whole path: a plain
  # sort puts 0.9.0 above 0.10.0 and lets the marketplace directory outrank the version.
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  if sort -V </dev/null >/dev/null 2>&1; then vsort="sort -V"; else vsort="sort -t. -k1,1n -k2,2n -k3,3n"; fi
  PLUGIN_ROOT=$(ls -1d "$cache_root"/*/docs-forge/* 2>/dev/null | awk -F/ '{print $NF "\t" $0}' | $vsort | tail -1 | cut -f2-)
fi
for h in "${HERMES_HOME:-$HOME/.hermes}/plugins/docs-forge" .hermes/plugins/docs-forge; do
  [ -n "$PLUGIN_ROOT" ] && break
  [ -d "$h/skills" ] && PLUGIN_ROOT="$h"
done
[ -d "$PLUGIN_ROOT/skills" ] || { echo "docs-forge plugin root not found; export PLUGIN_ROOT" >&2; exit 1; }
```

Every later shell block in the body then uses `$PLUGIN_ROOT`.

## Interactive input

There is no shared interaction tool. A body that needs an answer routes through a capability-aware
gate:

- **Claude Code** — `AskUserQuestion`.
- **Codex** — `request_user_input` when it is exposed. When it is not, ask one blocking question
  only where a wrong assumption would be expensive, and otherwise proceed on a documented default
  and say which default you took.
- **Hermes** — `clarify`.

A skill that carries this block is registered as a pilot in
`scripts/check-skill-tool-portability.mjs`; a skill that hardcodes `AskUserQuestion` without the
block has to be recorded there as reviewed debt. Adding a new skill that does neither fails the
guard. The cheapest correct option is usually a skill with no interactive gate at all: measure,
report, and let the caller decide.

## Surfaces that do not exist everywhere

- **Commands and subagents are Claude-only.** Codex 0.135 manifests support `skills`, `hooks`,
  `mcpServers`, and `apps`; Hermes supports skills. Logic moved into an agent definition silently
  disappears for two runtimes. A subagent fan-out may accelerate a phase whose inline sequential
  path stays primary and complete.
- **Hermes loads plugin skills explicitly.** Claude Code and Codex index a skill by its
  `description`; Hermes reaches one only through `skill_view("<plugin>:<skill>")` in a session
  started after `--enable`. Trigger phrasing still belongs in the description, but a body that says
  "you were selected because your description matched" is wrong under Hermes.
- **`.claude/rules/` is Claude-only.** Codex and Hermes cannot read the directory. Guidance that
  must bind all three lives in `AGENTS.md`; shared lore lives in `.llmwiki/`.

## Packaging obligations

Changing **any file** under `plugins/<name>/` — a skill body, a bundled reference, an asset —
requires all of the following in the same change, because users on a cached plugin copy receive
nothing without a version bump:

1. `plugins/<name>/.claude-plugin/plugin.json` → bump `version` (PATCH for a fix, MINOR for a new
   skill or capability).
2. `.claude-plugin/marketplace.json` → the matching entry's `version`.
3. `.claude-plugin/marketplace.json` → `metadata.version`, the release counter. It is not semver:
   bump it MINOR even for a change that breaks consumers.
4. `node scripts/sync-codex-manifests.mjs` when the plugin is Codex-eligible.
5. `node scripts/sync-hermes-manifests.mjs` when the plugin is in `HERMES_ELIGIBLE`.

Generated files — `.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`, `plugin.yaml`,
`__init__.py` — are never hand-edited. Edit the source and regenerate.

Root documents (`AGENTS.md`, `README.md`, `code_review.md`, `.claude/rules/*`) are not plugin
content and bump nothing.

## Prose language

Skill bodies, bundled references, and plugin `CLAUDE.md` prose are written in English so all three
runtimes and the Codex cloud reviewer read one language. Domain content stays in its source
language: user-facing copy, example outputs, and the trigger phrases inside a `description`.
