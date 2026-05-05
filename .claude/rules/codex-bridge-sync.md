---
paths: plugins/codex-bridge/**
---

# codex-bridge Sync Rules

Behavioral invariants for the my-claude-plugins → Codex skill sync engine (`plugins/codex-bridge/scripts/sync.mjs`).

## Role

Sync plugin skills (`plugins/*/skills/**/SKILL.md`) AND commands (`plugins/*/commands/*.md`) to Codex CLI's native skill directory (`~/.agents/skills/`) idempotently. my-claude-plugins is single source of truth (SSOT); the target is a derived artifact rebuilt every run.

Commands are not a first-class concept in Codex — they're wrapped as synthetic skills with `<plugin>-<command>` naming (e.g. `github-dev-resolve-issue`) and `bridge_source: <plugin>/commands/<command>` markers to distinguish from skill-origin entries.

## Key Components

- `scripts/sync.mjs` — single-file Node 18+ engine (zero runtime deps). Exports `discoverSkills`, `discoverCommands`, `parseFrontmatter`, `applyTransforms`, `transformSkillContent`, `injectBridgeSource`, `syncOne`, `syncCommand`, `syncAll`, `pruneOrphans`, `loadConfig`, `parseArgs`, `isExcluded`.
- `codex-bridge.config.json` — default `exclude` glob list + 3 transform rules + text extension whitelist.
- `skills/codex-sync/SKILL.md` — Claude Code entrypoint (`/codex-bridge:codex-sync`).
- `tests/*.test.mjs` — `node --test` suite, fixtures in `tests/fixtures/`.

## Do's

- **Preserve frontmatter verbatim.** Never let transform rules touch content between the `---` fences. This protects the `bridge_source` provenance marker AND the user-authored `name`/`description` fields.
- **Flatten multi-line YAML block-scalar descriptions (`description: |` / `description: >`) to a single line at sync time.** Codex's skill loader expects single-line descriptions per [official spec](https://developers.openai.com/codex/skills). Block scalars have caused source skills to fail to load into `$skill` selector. Normalization happens in `normalizeFrontmatterDescription`, between body transform and `bridge_source` injection — value preserved, form normalized.
- **Wrap commands as synthetic skills.** `plugins/*/commands/*.md` are converted via `commandToSkillContent` into `<plugin>-<command>/SKILL.md` files. Claude Code-only frontmatter keys (`allowed-tools`, `argument-hint`, `paths`, `version`) are dropped; only `name`, `description` (flattened), and `bridge_source` remain. Body is preserved and goes through standard transform rules.
- **Inject `bridge_source: <plugin>/<skill>` into every synced SKILL.md frontmatter.** The marker is the single source for orphan pruning and collision guarding — without it the sync engine cannot tell bridge-owned files from user/external files.
- **Return `status: 'skipped'` with `reason: 'non-managed-collision'` whenever target SKILL.md exists and lacks `bridge_source`.** Emit a stderr warning naming the file.
- **Sort `discoverSkills` output deterministically** by `(pluginName, skillName)` before returning. Spec P1 `last-wins` semantics require stable ordering so idempotent re-runs produce identical results.
- **Write via staging dir inside target root, then `fs.rename`** for atomicity. On `EXDEV`, fall back to `fs.cp({ recursive: true, force: true })` followed by `fs.rm` on the staging dir.
- **Restrict body transforms to the extension whitelist**: `.md`, `.yml`, `.yaml`, `.json`, `.sh`, `.mjs`, `.js`, `.py`, `.ts`. Other extensions must be copied byte-for-byte.
- **Emit a collision warning once per duplicate `skillName`** detected across distinct plugins, including all plugin names involved and the winner after sort. Store in `report.collisions[]`.
- **Guard `const` declarations against top-level TDZ.** Any module-level `if (isMainModule) main(...)` block must appear after every `const` it transitively depends on (e.g. `KNOWN_FLAGS`). Function declarations hoist; lexical bindings do not.
- **Test Red first.** Fixtures live in `tests/fixtures/`. Write failing test, then the minimal export needed to pass. Re-run the full suite after every cycle.

## Don'ts

- **Never touch `~/.codex/skills/`.** That directory is externally managed. The bridge operates exclusively on `~/.agents/skills/`.
- **Never delete a SKILL.md that lacks `bridge_source`.** Orphan-prune only considers marker-tagged files; untagged files are treated as external ownership.
- **Never override the OpenAI-official target path.** `~/.agents/skills/` is fixed per OpenAI Codex Skills docs. `CODEX_HOME` env is for state/log/config base only — it does NOT control skill discovery. `config.target.agentsHome` exists for testing only.
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

## Out of Scope (V2)

- `agents/openai.yaml` sidecar (eventual migration target for `bridge_source`)
- File-change hook for auto-sync
- `Task(subagent_type=...)` → Codex native subagent mapping
- Project-level `.agents/skills/` scope
- Collision-fallback prefix mode
- npm bin distribution
