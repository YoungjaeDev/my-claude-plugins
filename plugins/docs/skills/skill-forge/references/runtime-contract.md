# Runtime contract

What a skill in this repository owes the two runtimes that load it: Claude Code and Codex 0.135.
Both read the same `plugins/<name>/` tree — there is no per-runtime mirror — so a body that assumes
one runtime's behavior is wrong on the other without saying so.

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
| `disable-model-invocation: true` | the Codex plugin validator rejects the plugin | reviewed by hand; see `frontmatter.md` |

## Calling a bundled script

Use a resolver, never `${CLAUDE_PLUGIN_ROOT}` on its own. The block below tries the Claude
variable, then the source tree, then the Codex plugin cache, and fails loudly rather than running
against an empty path:

```bash
# Honor a caller-supplied PLUGIN_ROOT first — the abort message below tells the user to
# export it, and starting from CLAUDE_PLUGIN_ROOT would overwrite that escape hatch.
PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
[ -z "$PLUGIN_ROOT" ] && [ -d plugins/docs/skills ] && PLUGIN_ROOT=plugins/docs
if [ -z "$PLUGIN_ROOT" ]; then
  # Rank Codex cache candidates on the version basename, not the whole path: a plain
  # sort puts 0.9.0 above 0.10.0 and lets the marketplace directory outrank the version.
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  if sort -V </dev/null >/dev/null 2>&1; then vsort="sort -V"; else vsort="sort -t. -k1,1n -k2,2n -k3,3n"; fi
  PLUGIN_ROOT=$(ls -1d "$cache_root"/*/docs/* 2>/dev/null | awk -F/ '{print $NF "\t" $0}' | $vsort | tail -1 | cut -f2-)
fi
[ -d "$PLUGIN_ROOT/skills" ] || { echo "docs plugin root not found; export PLUGIN_ROOT" >&2; exit 1; }
```

Every later shell block in the body then uses `$PLUGIN_ROOT`.

## Interactive input

There is no shared interaction tool. A body that needs an answer routes through a capability-aware
gate:

- **Claude Code** — `AskUserQuestion`.
- **Codex** — `request_user_input` when it is exposed. When it is not, ask one blocking question
  only where a wrong assumption would be expensive, and otherwise proceed on a documented default
  and say which default you took.

The cheapest correct option is usually a skill with no interactive gate at all: measure, report, and
let the caller decide.

## Surfaces that do not exist everywhere

- **Commands and subagents are Claude-only.** Codex 0.135 manifests support `skills`, `hooks`,
  `mcpServers`, and `apps`. Logic moved into an agent definition silently disappears for Codex. A
  subagent fan-out may accelerate a phase whose inline sequential path stays primary and complete.
- **`.claude/rules/` is Claude-only.** Codex cannot read the directory. Guidance that must bind both
  runtimes lives in `AGENTS.md`; shared lore lives in `.llmwiki/`.

## Packaging obligations

Changing **any file** under `plugins/<name>/` — a skill body, a bundled reference, an asset —
requires all of the following in the same change, because users on a cached plugin copy receive
nothing without a version bump:

1. `plugins/<name>/.claude-plugin/plugin.json` → bump `version` (PATCH for a fix, MINOR for a new
   skill or capability).
2. `.claude-plugin/marketplace.json` → the matching entry's `version`.
3. `.claude-plugin/marketplace.json` → `metadata.version`, the release counter. It is not semver:
   bump it MINOR even for a change that breaks consumers.

Codex reads the same `.claude-plugin` manifests natively — there is no generated layer to
regenerate.

Root documents (`AGENTS.md`, `README.md`, `code_review.md`, `.claude/rules/*`) are not plugin
content and bump nothing.

## Prose language

Skill bodies, bundled references, and plugin `CLAUDE.md` prose are written in English so both
runtimes and the Codex cloud reviewer read one language. Domain content stays in its source
language: user-facing copy, example outputs, and the trigger phrases inside a `description`.
