# Absorption self-check — PR #200 (issue #199, milestone 3)

**AUDIT-ONLY.** This artifact diagnoses the result of the single-skill plugin absorption merged as
PR #200 (`c56bd25`, plugins 24 → 14). It performs no absorption, no rename, and no restructure. The
prior audit `skill-content-structure-audit.md` is a separate 2026-07 artifact and is untouched.

Method: `docs-forge:skill-audit`, applied to the eleven absorbed skills and to the eleven skills now
in `docs-forge`. Measurements from `plugins/docs-forge/skills/skill-forge/scripts/measure-skills.mjs`
(53 skills, run 2026-08-10). Rules from `plugins/docs-forge/skills/skill-forge/references/`.

## At a glance

- **Live references to a defunct plugin: 0.** One grep hit, judged historical, evidence below.
- **1 P1 finding in skill bodies** — `llm-wiki/plaud-note-taking` states its Hermes eligibility in
  terms of a plugin that no longer exists.
- **1 P1 finding outside skill bodies** — `README.md`'s plugin catalog still carries a `<details>`
  section for each of the 11 absorbed plugins and has none for the new `publish` plugin. No guard
  covers that region. Out of scope for this milestone; recommended as a follow-up issue.
- **Trigger collisions inside `docs-forge` (11 skills): 0**, with two near-misses recorded.
- **Renames: 0 applied, 6 candidates deferred.** Rename execution is excluded from issue #199.
- **`docs-forge:{readme,changelog,moc,deploy-doc}-guide` keep their names** — the suffix avoids a
  collision with the four same-named commands, which is a justified naming exception.

## 1. Live-reference judgement

The scan covers the 14 plugin names that no longer exist: `slidev`, `ppt-yeong-style`,
`anti-slop-design` (deleted in PR #164 / #191) plus the 11 absorbed in PR #200.

```bash
GONE='slidev|ppt-yeong-style|anti-slop-design|brightdata-guide|gws-sync|interview|notebook|plaud-note-taking|rules-forge|spec-state|tally-form|tcrei-prompt|translator|voice-prompt'
rg --hidden -n "\b($GONE):[a-z0-9-]+" \
  --glob '!.git/**' --glob '!docs/**' --glob '!.claude/spec/**' \
  --glob '!.llmwiki/**' --glob '!**/tests/fixtures/**'
```

One hit:

| Hit | Verdict | Evidence |
|---|---|---|
| `plugins/docs-forge/CLAUDE.md:243` — ``- Migration: `/rules-forge:generate` and `/rules-forge:split` removed.`` | **historical** | The line sits inside the `write-rules` "Version History" list, under the `2.0.0 (2026-05-12) — BREAKING` entry. It records that two commands were removed in that release and names their then-current namespace. Rewriting it to `docs-forge:` would assert those commands once existed under `docs-forge`, which is false. |

`.llmwiki/`, `.claude/spec/`, `docs/`, and `**/tests/fixtures/**` are excluded from the scan by
design: they describe the past, and a deleted subject does not make a dated record stale (see
`.llmwiki/wiki/llm-wiki-design/deleted-subject-not-stale.md`). Forcing them to zero would destroy
the record. That is the most plausible malfunction of this check and it was not performed.

**Live `plugin:skill` references to a defunct plugin: 0.**

## 2. Findings in absorbed skill bodies

### P1-1 — `plugins/llm-wiki/skills/plaud-note-taking/SKILL.md:38-40`

```
Load it by name with `skill_view("plaud-note-taking")`; `plaud-note-taking` is outside
`HERMES_ELIGIBLE`, so no generated adapter exists for the qualified `<plugin>:<skill>` form.
```

`HERMES_ELIGIBLE` (`scripts/manifest-eligibility.mjs:17-22`) holds plugin names:
`github-dev`, `docs-forge`, `code-scout`, `ml-toolkit`. `plaud-note-taking` has not been a plugin
since PR #200; the name that has to be checked against that set is now `llm-wiki`.

The conclusion still holds by accident — `llm-wiki` is also outside the allowlist, so there is still
no adapter and the bare load is still correct. The reasoning is what broke: a reader cannot verify
the claim, and the day `llm-wiki` is added to the allowlist the sentence stays literally "true"
while the correct load form silently changes to `skill_view("llm-wiki:plaud-note-taking")`.

Fix: name the plugin, not the skill — "`llm-wiki` is outside `HERMES_ELIGIBLE`".

### P2-1 — `plugins/docs-forge/skills/tcrei-prompt/SKILL.md:292`

"this plugin ships no `agents/` directory, so there is no verifier agent named `claude`". The
referent moved from `tcrei-prompt` to `docs-forge`. Verified still true: `plugins/docs-forge/agents`
does not exist. No action required; recorded so a later reader knows it was checked rather than
missed.

### P2-2 — frontmatter drift carried through the move

| Skill | Key | Effect |
|---|---|---|
| `docs-forge:interview-methodology` | `version` | none — no runtime reads it |
| `docs-forge:voice-prompt` | `version` | none |
| `llm-wiki:plaud-note-taking` | `version` | none |
| `code-scout:brightdata-guide` | `license` | none in Claude Code; valid in the Agent Skills spec |
| `publish:tally-form` | `argument-hint` | autocomplete hint in Claude Code; ignored by Codex and Hermes |

`version` is in neither the Claude Code frontmatter reference nor the Agent Skills six-field set —
no runtime reads it, and it will disagree with `plugin.json` the first time either changes. Removing
it is cleanup, not a correctness fix. `license` and `argument-hint` are valid fields; see
`plugins/docs-forge/skills/skill-forge/references/frontmatter.md` for the evidence, including the
one path on which `argument-hint` is fatal (packaging for claude.ai / the Skills API, which this
repository does not use).

### Structure axis — measured, not absorption fallout

Five absorbed skills exceed the 300-line target used for new skills: `write-rules` 411,
`tcrei-prompt` 363, `code-scout:brightdata-guide` 343, `interview-methodology` 342, `voice-prompt`
314. None exceeds the 500-line non-blocking ceiling enforced by `check-skill-prose.mjs`, and all
five were that length before the move. They belong to the deferred fleet review (a separate issue),
not to this check.

### Axes checked and clean

- **Bundled-path resolvers** — every `PLUGIN_ROOT` resolver in a moved skill scans its new plugin's
  cache path (`publish/tally-form` → `*/publish/*`, `docs-forge/voice-prompt` → `*/docs-forge/*`).
  No resolver still looks for a defunct plugin directory.
- **Hermes install instructions** — the four `hermes plugins install …/plugins/<name>` lines in
  plugin `CLAUDE.md` files all name existing plugins.
- **Namespaced skill invocations** — every `skill_view("<plugin>:<skill>")` example names a plugin
  that exists. The single bare-name form is `plaud-note-taking`, covered by P1-1 above, and it is
  bare for a correct reason.
- **Frontmatter loading hazards** — no absorbed skill has a description over 1024 characters, and
  `tcrei-prompt`'s description, which contains `Triggers: `, is a `|` block scalar and therefore
  parses. Both are enforced from milestone 4 by `scripts/check-skill-contract.mjs`.

## 3. Trigger-collision review — the eleven `docs-forge` skills

Descriptions read side by side. Grouped by the request each would match:

| Branch | Owner | Others that could match | Verdict |
|---|---|---|---|
| README / CHANGELOG / MOC / deploy-doc reference | the four `-guide` skills | — | clean; each names its own document type and says which command loads it |
| write or revise a skill | `skill-forge` | `skill-audit`, `skill-fleet-review` | clean; each of the three names the other two and says which case belongs to them |
| diagnose one skill | `skill-audit` | `skill-fleet-review` | clean; "one existing skill" vs "every skill in a plugin tree" |
| generate or restructure CLAUDE.md and `.claude/rules` | `write-rules` | `skill-forge` | clean; different artifact — rules files, not skills |
| interview the user before implementing | `interview-methodology` | — | see near-miss 1 |
| rewrite a prompt | `tcrei-prompt` | `voice-prompt` | see near-miss 2 |

**Near-miss 1 — three skills interview, one advertises it.** `write-rules` (NEW mode) and
`tcrei-prompt` (gap-filling) both interview the user, and `interview-methodology` claims the
broadest branch in the bundle ("ask me questions", "understand my needs before implementing").
There is no collision *because neither of the other two lists an interview phrase as a trigger* —
they trigger on their own artifact. Recorded so that adding "interview me" to either description
later is understood as creating the collision, not inheriting it.

**Near-miss 2 — two skills rewrite user input.** `tcrei-prompt` restructures a prompt;
`voice-prompt` normalizes dictated input. They stay apart because `voice-prompt` carries an
explicit negative trigger ("Use ONLY when the user explicitly invokes … do NOT auto-fire from an
incidental mention of voice mode"). That guard is load-bearing; removing it collides the two.

No description changes were needed.

## 4. Rename judgement

Rename execution is excluded from issue #199 (the goal statement lists it under what this work never
does). Judgement is recorded here; every candidate is deferred.

Criterion applied — the pointer principle from
`plugins/docs-forge/skills/skill-forge/references/structure.md`: a name must identify its object
without its plugin prefix, and two skills in one plugin must be separable by name alone.

| Skill | Verdict | Reason |
|---|---|---|
| `github-dev:state-tracker` | **rename candidate** (deferred) | "state" does not distinguish `.claude/state/spec.json` from a state-envelope run record; the plugin now owns skills touching both |
| `deepwiki:ask` | **rename candidate** (deferred) | bare common verb; nothing in the name says what is asked |
| `paper-search-tools:setup` | **rename candidate** (deferred) | bare common noun |
| `project-init:new` | **rename candidate** (deferred) | bare common adjective; "new" what |
| `code-scout:resource-finder` vs `code-scout:research-orchestrator` | **rename candidate** (deferred) | the boundary between the two is not derivable from the names |
| `code-scout:brightdata-guide` | **rename candidate, low priority** (deferred) | the `-guide` suffix has no command to avoid in `code-scout`, so it reads as a category label rather than a distinguisher |
| `docs-forge:readme-guide`, `changelog-guide`, `moc-guide`, `deploy-doc-guide` | **do not rename** | `plugins/docs-forge/commands/{readme,changelog,moc,deploy-doc}.md` exist 1:1; the suffix is collision avoidance, which the naming rule lists as a justified exception |
| all eleven absorbed skills | **do not rename** | each already names its object (`write-rules`, `translate-web-article`, `edit-notebook`, `plaud-note-taking`, …); the move did not degrade any of them |

Renaming any of the six candidates changes every cross-reference to it and requires a version bump
on the owning plugin. That is a separate change with its own review.

## 5. Finding outside skill bodies — README plugin catalog

`README.md`'s collapsible plugin catalog was not restructured when the plugins were absorbed. The
`<summary><strong>…</strong></summary>` headings still name all eleven absorbed plugins
(`brightdata-guide`, `gws-sync`, `interview`, `notebook`, `plaud-note-taking`, `rules-forge`,
`spec-state`, `tally-form`, `tcrei-prompt`, `translator`, `voice-prompt`), and the new `publish`
plugin has no section at all.

Reproduce:

```bash
rg -o '<summary><strong>([a-z0-9-]+)</strong>' -r '$1' README.md | sort > /tmp/a
jq -r '.plugins[].name' .claude-plugin/marketplace.json | sort > /tmp/b
comm -23 /tmp/a /tmp/b   # 11 sections for plugins that no longer exist
comm -13 /tmp/a /tmp/b   # publish has no section
```

The section bodies were partially updated — the `rules-forge` block already names
`/docs-forge:write-rules` — so the command namespaces were substituted while the headings were not.
That makes this leftover rather than a deliberate historical record.

`check-doc-consistency.mjs` passes because it reads only the structure tree, the `AGENTS.md`
`## Plugins` table, and the documented count strings. The `<details>` catalog is outside every
guard, which is why the drift survived a merge.

**Not fixed here.** Milestone 3 diagnoses the absorption; rewriting twelve catalog sections is a
separate change. Recommended as a follow-up issue, together with a guard extension so the
`<summary>` name-set is compared against the registry the same way the tree already is.

## 6. Out of scope

- The full fleet review of all 53 skills — `docs-forge:skill-fleet-review` exists as of this
  milestone but is deliberately not run; that is a separate issue.
- Any restructure of the five over-length absorbed skills.
- Removal of the no-op `version` frontmatter keys.
- The README catalog fix in section 5.
- Any rename from section 4.
