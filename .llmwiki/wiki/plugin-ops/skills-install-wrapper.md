---
id: skills-install-wrapper
aliases: [install-skills, npx-skills, skills-installer-tui, hermes-install, agents-skills-dir]
last_verified: 2026-07-27
status: active
volatility: stable
sources: 4
---

# Installing marketplace skills to Hermes / Codex (npx skills wrapper)

`scripts/install-skills.mjs` installs this marketplace's skills into external
agents (Hermes Agent, Codex) by **wrapping `npx skills`** (vercel-labs/skills) —
no custom exporter. It is a dev script (outside `plugins/`, so it does not affect
`sync-codex-manifests --check`) and adds only two things over the raw CLI: a
plugin-grouped selector and Hermes profile targeting.

Since PR #166 this is the **only** Hermes delivery path — the generated
`plugin.yaml` + `__init__.py` adapters were retired (see the Supersedes link below).
Codex keeps its manifest generator alongside this route, because `npx skills`
carries skills *only*: core-config (4 hooks, 0 skills), llm-wiki (6 hooks) and
paper-search-tools (1 MCP server) ship payloads that no skill installer delivers.

> Supersedes: [[hermes-plugin-adapter]]

## The `npx skills add` contract (measured)

- **Source arg = repo root `.`** — `npx skills add .` validates the local path,
  reads `.claude-plugin/marketplace.json`, and discovers all skills grouped by
  plugin (`./plugins/<name>` scopes to that plugin's skills). So one invocation
  can install a cross-plugin selection.
- **Skill selection = *repeated* `-s <name>` flags.** Comma is NOT a separator:
  `-s a,b` → `No matching skills found` (exit 1). The flag matches the skill's
  frontmatter `name`, which is globally unique across this repo's 52 skills (23
  skill-bearing plugins, re-measured 2026-07-27), so `-s <name>` against source `.`
  is unambiguous. Names install **flat** — `cr-fix`, not `github-dev:cr-fix` — so
  uniqueness must hold against *other people's* skills too, not just this repo's;
  `install-skills.mjs --selftest` only guards the intra-repo half.
- **Agents** — `-a hermes-agent` / `-a codex`. Run inside an agent, `npx skills`
  auto-detects it and goes **non-interactive (no picker)** — so a wrapper MUST
  pass `-a` explicitly or it silently targets the detected agent; with `-y` +
  explicit `-s` it is deterministic in any shell. (This is why the wrapper's own
  grouped selector carries the selection value, not just grouping.)
- **Codex global install path = `~/.agents/skills/<name>/`** (copied), the same
  dir the retired `codex-bridge` wrote to — NOT `~/.codex/skills` (which holds
  only `.system`). Symlink/copy, conflicts, remove, update, and the lockfile are
  all owned by `npx skills`, not reimplemented.
- **Layout divergence resolved (#166)**: this route installs flat per-skill dirs
  under `$HERMES_HOME/skills/<skill>/`, while the retired `hermes plugins install`
  route implied `$HERMES_HOME/plugins/<name>/skills/`. With the adapter gone there
  is one layout, so a `SKILL_DIR` fallback chain only has to cover the flat one —
  which is also the only layout ever *measured* here.
- **`-a hermes-agent` COPIES, it does not symlink** (measured 2026-07-27, skills
  v1.5.20): `~/.hermes/skills/cr-fix/` came out a real directory while
  `~/.claude/skills/*` entries are symlinks into `~/.agents/skills/`. Upstream
  documents symlink-with-copy-fallback, so do not assume the link; a source-tree
  edit does **not** reach an existing Hermes install until a reinstall or
  `npx skills update`.

## Hermes indexes `~/.hermes/skills/` passively

Upstream docs call `~/.hermes/skills/` "the primary directory and source of truth"
and state that "every installed skill is automatically available as a slash
command", surfacing at `skills_list()` (Level 0 progressive disclosure). So under
this route a skill's `description` surfaces it the same way it does under Claude
Code and Codex 0.135.

This **retires the opt-in load contract** the adapter route carried, where a skill
was reachable only via an explicit `skill_view("<plugin>:<skill>")` call after
`--enable`. A skill body that says "you were explicitly loaded, not auto-selected"
is describing the retired route and is now wrong for Hermes.

## Hermes profile = HERMES_HOME bridge

`npx skills` has no profile flag — it installs to `$HERMES_HOME/skills`. A Hermes
profile is an isolated `HERMES_HOME`: default = `<base>/skills`, named =
`<base>/profiles/<name>`. The wrapper targets a named profile by injecting
`HERMES_HOME=<base>/profiles/<name>` on the spawn env. Because each agent can
need a distinct env, the wrapper does **one `npx skills add` spawn per (agent,
profile)**, never combining agents. The Hermes base must be computed from an
existing `HERMES_HOME` (fallback `~/.hermes`) for both the availability check and
the profile scan — hardcoding `~/.hermes` for detection hid a relocated install.

## EXCLUDED is manifest-scoped, not install-scoped

The installer filters install candidates by **skill count only** (core-config has
0 skills → naturally dropped). It deliberately does NOT reuse the Codex manifest
`EXCLUDED` set (core-config / codex-image): that set governs Codex
*manifest eligibility*, not *install availability*, so codex-image is
installable to Codex via the TUI. Known counterpoint (a Codex review flagged
it, accepted as a deliberate decision): installing `codex-image` — a Claude→Codex
bridge — into Codex is circular, so a per-target exclusion is a reasonable future
refinement, not a v1 bug.

> See-also: [[shared-source-codex-manifests]]
> Evidence: scripts/install-skills.mjs

## Sources

- `scripts/install-skills.mjs` (P0 install wrapper) + `.claude/spec/2026-06-24-skills-installer-tui.md` — the wrapper, the selector, and the HERMES_HOME / skill-count design decisions.
- vercel-labs/skills `npx skills add` CLI — `-s` (repeated, comma-rejecting) / `-a` / `-g` semantics, agent auto-detect non-interactive mode, `~/.agents/skills` codex target, `$HERMES_HOME/skills` hermes target; measured 2026-06-24.
- PR #166 (2026-07-27) — retires the Hermes adapter layer, making this the sole Hermes path; re-measured `npx skills add . -l` → 52 skills, and an end-to-end `-a hermes-agent -s cr-fix -g` install that landed a copied (not symlinked) `~/.hermes/skills/cr-fix/`.
- Hermes Agent docs, Skills System page (`hermes-agent.nousresearch.com/docs/user-guide/features/skills`, read 2026-07-27) — `~/.hermes/skills/` is "the primary directory and source of truth"; "every installed skill is automatically available as a slash command"; `skills_list()` is Level 0 of progressive disclosure.
