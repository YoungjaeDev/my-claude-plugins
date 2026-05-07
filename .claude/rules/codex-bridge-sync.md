---
paths: plugins/codex-bridge/**
---

# codex-bridge Sync Rules

Behavioral invariants for the my-claude-plugins → Codex skill sync engine (`plugins/codex-bridge/scripts/sync.mjs`).

## Role

Sync plugin skills (`plugins/*/skills/**/SKILL.md`), commands (`plugins/*/commands/*.md`), AND subagents (`plugins/*/agents/*.md`) to Codex CLI's native directories (`~/.agents/skills/` for skills+commands, `~/.codex/agents/*.toml` for subagents) idempotently. my-claude-plugins is single source of truth (SSOT); the target is a derived artifact rebuilt every run.

Commands are not a first-class concept in Codex — they're wrapped as synthetic skills with `<plugin>-<command>` naming (e.g. `github-dev-resolve-issue`) and `bridge_source: <plugin>/commands/<command>` markers to distinguish from skill-origin entries.

Subagents have their own native target in Codex (`~/.codex/agents/<plugin>-<agent>.toml`). Markdown frontmatter is converted to TOML; body is wrapped in `developer_instructions = """..."""` triple-quoted multi-line string. The provenance marker is a `# bridge_source = "<plugin>/agents/<agent>"` comment on the first line (TOML has no first-class metadata, so the comment carries the role of the YAML `bridge_source:` field).

## Key Components

- `scripts/sync.mjs` — single-file Node 18+ engine (zero runtime deps). Exports `discoverSkills`, `discoverCommands`, `discoverAgents`, `resolvePluginsDir`, `resolvePluginContentDir`, `isVersionedCacheChild`, `compareSemver`, `parseFrontmatter`, `applyTransforms`, `transformSkillContent`, `injectBridgeSource`, `agentToCodexToml`, `syncOne`, `syncCommand`, `syncAgent`, `syncAll`, `pruneOrphans`, `pruneAgentOrphans`, `tomlHasBridgeSource`, `readTomlBridgeSource`, `loadConfig`, `parseArgs`, `isExcluded`.
- `codex-bridge.config.json` — default `exclude` glob list + 3 transform rules + text extension whitelist.
- `skills/codex-sync/SKILL.md` — Claude Code entrypoint (`/codex-bridge:codex-sync`).
- `tests/*.test.mjs` — `node --test` suite, fixtures in `tests/fixtures/`.

## Do's

- **Preserve frontmatter verbatim.** Never let transform rules touch content between the `---` fences. This protects the `bridge_source` provenance marker AND the user-authored `name`/`description` fields.
- **Flatten multi-line YAML block-scalar descriptions (`description: |` / `description: >`) to a single line at sync time.** Codex's skill loader expects single-line descriptions per [official spec](https://developers.openai.com/codex/skills). Block scalars have caused source skills to fail to load into `$skill` selector. Normalization happens in `normalizeFrontmatterDescription`, between body transform and `bridge_source` injection — value preserved, form normalized.
- **Wrap commands as synthetic skills.** `plugins/*/commands/*.md` are converted via `commandToSkillContent` into `<plugin>-<command>/SKILL.md` files. Claude Code-only frontmatter keys (`allowed-tools`, `argument-hint`, `paths`, `version`) are dropped; only `name`, `description` (flattened), and `bridge_source` remain. Body is preserved and goes through standard transform rules.
- **Convert subagents to Codex TOML.** `plugins/*/agents/*.md` are converted via `agentToCodexToml` into `<plugin>-<agent>.toml` files at `~/.codex/agents/`. Structure: `# bridge_source = "<plugin>/agents/<agent>"` comment on line 1, optional `# original-model`/`# original-skills`/`# original-tools` comments preserving Claude Code-only fields (Codex's model alias namespace differs — drop the value, keep the trail), then real TOML keys `name`, `description`, `developer_instructions = """..."""`. Body transforms run before TOML wrap; backslashes and `"""` sequences are escaped per TOML basic multi-line string rules (`\` → `\\`, `"""` → `\"""`).
- **Inject `bridge_source: <plugin>/<skill>` into every synced SKILL.md frontmatter.** The marker is the single source for orphan pruning and collision guarding — without it the sync engine cannot tell bridge-owned files from user/external files. For agent .toml files, the same role is played by the `# bridge_source = "..."` comment.
- **Return `status: 'skipped'` with `reason: 'non-managed-collision'` whenever target SKILL.md (or agent .toml) exists and lacks the `bridge_source` marker.** Emit a stderr warning naming the file.
- **Sort `discoverSkills` output deterministically** by `(pluginName, skillName)` before returning. Spec P1 `last-wins` semantics require stable ordering so idempotent re-runs produce identical results.
- **Write via staging dir inside target root, then `fs.rename`** for atomicity. On `EXDEV`, fall back to `fs.cp({ recursive: true, force: true })` followed by `fs.rm` on the staging dir.
- **Restrict body transforms to the extension whitelist**: `.md`, `.yml`, `.yaml`, `.json`, `.sh`, `.mjs`, `.js`, `.py`, `.ts`. Other extensions must be copied byte-for-byte.
- **Emit a collision warning once per duplicate `skillName`** detected across distinct plugins, including all plugin names involved and the winner after sort. Store in `report.collisions[]`.
- **Guard `const` declarations against top-level TDZ.** Any module-level `if (isMainModule) main(...)` block must appear after every `const` it transitively depends on (e.g. `KNOWN_FLAGS`). Function declarations hoist; lexical bindings do not.
- **Test Red first.** Fixtures live in `tests/fixtures/`. Write failing test, then the minimal export needed to pass. Re-run the full suite after every cycle.
- **Resolve `pluginsDir` via `resolvePluginsDir(scriptPath, override)`** which detects monorepo vs Claude Code versioned cache layout (heuristic: every direct child of the monorepo candidate is semver-named ⇒ jump one level up). Honor `--plugins-dir <path>` override. Per-plugin layout is resolved by `resolvePluginContentDir(pluginDir)` which descends into `<plugin>/<latest-semver>/` when `.claude-plugin/` is absent and all children are semver. Together they make discovery work both from `<repo>/plugins/codex-bridge/scripts/sync.mjs` and from `~/.claude/plugins/cache/my-claude-plugins/codex-bridge/<version>/scripts/sync.mjs`.
- **Skip `pruneOrphans` when `validSources.size === 0`.** A discovery miss (wrong `pluginsDir`, over-restrictive `--plugin` filter, freshly-init repo) must never trigger destructive prune. Emit a stderr warning and push to `report.warnings` so the failure is visible. Pair with the `discoverSkills returned 0 results` warning emitted at the top of `syncAll` for upstream signal.

## Don'ts

- **Never touch `~/.codex/skills/`.** That directory is externally managed. The bridge operates exclusively on `~/.agents/skills/` (skills+commands) and `~/.codex/agents/` (subagents).
- **Never delete a SKILL.md or agent .toml that lacks the `bridge_source` marker.** Orphan-prune only considers marker-tagged files (frontmatter `bridge_source:` for skills, `# bridge_source = "..."` comment for agent .toml); untagged files are treated as external/user ownership.
- **Never override the OpenAI-official target paths.** `~/.agents/skills/` is fixed per OpenAI Codex Skills docs; `~/.codex/agents/*.toml` is fixed per OpenAI Codex Subagents docs. `CODEX_HOME` env is for state/log/config base only — it does NOT control skill or agent discovery. `config.target.agentsHome` and `config.target.agentsTomlHome` exist for testing only.
- **Never add runtime dependencies.** Node 18+ built-ins only. The spec mandates zero-deps for portability and reproducibility.
- **Never apply transforms to frontmatter.** `bodyOnly: true` is a contract, not a default. Transforms (`CLAUDE.md`→`AGENTS.md`, `.claude/`→`.codex/`, namespace regex) must only touch body.
- **Never use non-atomic writes** that leave target in a partial state if the process dies mid-sync.
- **Never bundle Windows/macOS verification into V1 scope.** Cross-platform testing is best-effort per spec.
- **Never combine `--plugin <list>` with auto-prune.** The filter narrows `validSources` to the selected plugins, so `pruneOrphans` treats every bridge-managed skill from other plugins as an orphan and deletes it. Always pair `--plugin` with `--no-prune`, or run a full sync separately.
- **Never inject content into `~/.codex/AGENTS.md`.** The bridge is no longer responsible for guideline inject (removed in v1.3.0). `plugins/*/guidelines/*.md` source files remain SSOT but are not auto-pushed anywhere.

## Source of Truth

- Feature spec: `.claude/spec/2026-04-14-codex-bridge-skill-sync.md`
- Plugin doc: `plugins/codex-bridge/CLAUDE.md`
- Entry skill: `plugins/codex-bridge/skills/codex-sync/SKILL.md`

## Out of Scope

- `agents/openai.yaml` sidecar (eventual migration target for `bridge_source`)
- File-change hook for auto-sync
- Codex-compatible mapping for agent `model` / `tools` (currently preserved as `# original-*` comments only — user must wire up manually if desired)
- Project-level `.agents/skills/` scope
- Collision-fallback prefix mode
- npm bin distribution
