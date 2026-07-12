---
id: skills-install-wrapper
aliases: [install-skills, npx-skills, skills-installer-tui, hermes-install, agents-skills-dir]
last_verified: 2026-06-24
status: active
volatility: stable
sources: 2
---

# Installing marketplace skills to Hermes / Codex (npx skills wrapper)

`scripts/install-skills.mjs` installs this marketplace's skills into external
agents (Hermes Agent, Codex) by **wrapping `npx skills`** (vercel-labs/skills) —
no custom exporter. It is a dev script (outside `plugins/`, so it does not affect
`sync-codex-manifests --check`) and adds only two things over the raw CLI: a
plugin-grouped selector and Hermes profile targeting.

## The `npx skills add` contract (measured)

- **Source arg = repo root `.`** — `npx skills add .` validates the local path,
  reads `.claude-plugin/marketplace.json`, and discovers all skills grouped by
  plugin (`./plugins/<name>` scopes to that plugin's skills). So one invocation
  can install a cross-plugin selection.
- **Skill selection = *repeated* `-s <name>` flags.** Comma is NOT a separator:
  `-s a,b` → `No matching skills found` (exit 1). The flag matches the skill's
  frontmatter `name`, which is globally unique across this repo's 47 skills, so
  `-s <name>` against source `.` is unambiguous.
- **Agents** — `-a hermes-agent` / `-a codex`. Run inside an agent, `npx skills`
  auto-detects it and goes **non-interactive (no picker)** — so a wrapper MUST
  pass `-a` explicitly or it silently targets the detected agent; with `-y` +
  explicit `-s` it is deterministic in any shell. (This is why the wrapper's own
  grouped selector carries the selection value, not just grouping.)
- **Codex global install path = `~/.agents/skills/<name>/`** (copied), the same
  dir the retired `codex-bridge` wrote to — NOT `~/.codex/skills` (which holds
  only `.system`). Symlink/copy, conflicts, remove, update, and the lockfile are
  all owned by `npx skills`, not reimplemented.
- **Layout divergence vs the plugin-adapter route**: this route installs flat
  per-skill dirs under `$HERMES_HOME/skills/<skill>/`, while
  `hermes plugins install` implies `$HERMES_HOME/plugins/<name>/skills/`. Skill
  bodies whose `SKILL_DIR` fallback only covers one route miss the other — see
  the layout-divergence caveat in [[hermes-plugin-adapter]].

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
