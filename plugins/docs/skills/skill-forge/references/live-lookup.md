# Look it up live

A platform fact copied into a skill is a cache entry with no invalidation: it is right on the day it
was written and goes stale silently when the tool ships. Point at the source instead, and let the
agent read it on the run that needs it.

## What counts as a platform fact

Anything the vendor's docs or the tool's own output already carry: frontmatter fields and their
limits, hook and settings schemas, CLI flags and accepted values, subcommand lists, model names and
reasoning levels, output paths and formats, version floors. If an agent can learn it by running a
command or opening a page, it is a platform fact.

## Notes on the lookup order

The order itself is in SKILL.md's "Look it up live". What each step needs to get right:

- **Installed tool**: `<tool> --help`, `<tool> <sub> --help`, `<tool> --version`, a listing command,
  or a file the tool ships with (a bundled skill, a schema). Check what the command printed, not
  only its exit status: some CLIs answer an unknown subcommand's `--help` with the top-level help
  and exit 0.
- **Docs MCP**: an `llms.txt` source whose domain is the vendor's own. A third-party catalog
  registered under a similar name is not the spec. `deepwiki` and `context7` are third-party
  summaries: use them as a lead when the vendor has no docs, and confirm any value they give
  against the installed tool or the vendor's docs before a skill relies on it.
- **Direct fetch**: the vendor's `llms.txt` index first, then the page it lists.

## How a skill says it

Name the command or the page and what to read from it, at the step that uses it:

| Instead of | Write |
|---|---|
| "`--loop` accepts `vscode \| claude \| codex`" | "read the accepted values from `npx playwright init-agents --help`" |
| "Verified against X 1.61" | the installed version read at run time (`npx playwright --version`) and compared with the minimum the vendor docs state (or the skill's own stated floor, marked as policy), plus the `--help` to read |
| a hard-coded enum of model names or effort levels | the listing command (`codex debug models`) and the field to read |
| a copied table of frontmatter fields | the doc URL and section (`https://code.claude.com/docs/en/skills.md`, frontmatter reference) |

Starting points that resolve today:

| Topic | Source |
|---|---|
| Claude Code (skills, hooks, settings, plugins, subagents, worktrees) | `https://code.claude.com/docs/llms.txt`; every page has a `.md` twin |
| Codex CLI | `https://developers.openai.com/codex/llms.txt`; locally `codex --help`, `codex debug models` |
| Agent Skills standard (portable frontmatter) | `https://agentskills.io/specification.md` |
| GitHub CLI | `gh <cmd> --help`; `https://cli.github.com/manual/` |

## What stays encoded

Only what no lookup can return:

- **Owner policy** — a choice this repository made (a version-bump rule, a safety gate, an allowed
  alias set narrower than the tool accepts).
- **Undocumented behavior** — something observed but stated nowhere (a CLI that hangs without
  `< /dev/null`, a cache layout, an error signature).
- **Silent failures** — a violation that produces no error on some runtime.

Put these in a script or a check that fails loudly when they stop holding (a guard, a test fixture
that encodes the observed format), not in prose alone. Mark an encoded fact whose evidence is gone
as `unverified` with the command that would re-check it, rather than deleting the rule.
