# docs Plugin

Documents people and agents read, plus publishing them elsewhere: 8 skills, 4 commands and 9 plugin-level references. Every markdown file here, and every document the commands generate, follows `references/writing-standard.md`.

## Skills

| Skill | Description |
|-------|-------------|
| `doc-guides` | README/CHANGELOG/deploy-doc/MOC reference cards, one per `/docs:*` document command, plus the common human-read document rule they all follow |
| `write-rules` | CLAUDE.md + `.claude/rules/` generation with auto mode detection (NEW, TIGHTEN, SPLIT, REORGANIZE) |
| `interview-methodology` | Confirm the open points of a small, ambiguous request, close with an inline summary or a TCREI reusable prompt. Pressing an existing plan is Matt `grilling`; large work goes to `/grill-with-docs` |
| `vp` | Voice-dictated prompt gate: normalize misheard terms against `.agents/voice-terms.md`, restate and proceed, or ask 2-3 questions |
| `skill-forge` | Write or revise a skill: frontmatter schema, writing levers, skill shape, two-runtime packaging contract |
| `md-audit` | User-invoked: measure markdown shape with the bundled script, judge, report in chat, rewrite only the files the user picks |
| `translate-web-article` | Web page to Korean markdown with image captions. Needs Bright Data MCP or the `bdata` CLI (see the `brightdata-guide` preflight) |
| `gws-sync` | One-way, approval-gated sync from a local folder to Google Drive through the `gws` CLI |

## Commands

| Command | Description |
|---------|-------------|
| `/docs:readme` | Generate or analyze README (`--type` cli, library, react-component, mcp-plugin, saas, desktop, internal) |
| `/docs:changelog` | Generate or analyze CHANGELOG |
| `/docs:deploy-doc` | Generate or restructure a deployment / procedure doc |
| `/docs:moc` | Generate a Map of Content index for a docs folder |

## References

| File | Content |
|------|---------|
| `writing-standard.md` | Shape, tone, skill shape, editing rules and the exception list for every markdown file; read by `md-audit`'s script |
| `README_PATTERNS.md` | Structure patterns from 9 awesome-readme examples, internal repo structure, banner rules, demo placement |
| `README_SECTIONS.md` | readme.so section menu mapped to when to include and the internal repo order |
| `CHANGELOG_PATTERNS.md` | Keep a Changelog format and automation |
| `TEMPLATES.md` | Copy-paste templates for 7 project types |
| `CRO_CHECKLIST.md` | Conversion optimization checklist |
| `EXAMPLES_ANALYSIS.md` | Detailed analysis of each example project |
| `DEPLOY_DOC_PATTERNS.md` | Deployment-doc skeleton, filled example, anti-patterns (Korean-default output examples) |
| `MOC_PATTERNS.md` | MOC hook-sourcing ladder, lightweight + strict examples (Korean-default output examples) |

## Skill authoring and audit

- **Split**: `skill-forge` writes one skill and `md-audit` measures and judges existing markdown, skills included. They run at different moments, so they stay two skills.
- **Rules**: skill rules live in `skills/skill-forge/references/`, the seven review axes in `skills/md-audit/references/axes.md`, and the shape rules in `references/writing-standard.md`.
- **Script**: `skills/md-audit/scripts/measure-skills.mjs` prints the skill table (lines, tokens, description length, sections, references depth, frontmatter keys) and, with `--md`, the shape findings. `--selftest` checks its parsers.
- **Self-contained**: no body, reference or script here tells the reader to open an external marketplace skill. A pointer to one fails silently for any user who does not have it installed.
