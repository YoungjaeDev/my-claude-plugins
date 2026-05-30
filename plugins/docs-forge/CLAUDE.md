# docs-forge Plugin

Generate and analyze README/CHANGELOG files using CRO best practices from awesome-readme.

## Skills

| Skill | Description |
|-------|-------------|
| `readme` | **Generate or analyze** a README file (writes/edits) |
| `changelog` | **Generate or update** a CHANGELOG file (writes/edits) |
| `readme-guide` | README patterns and templates — reference only |
| `changelog-guide` | CHANGELOG format and automation — reference only |

These are auto-triggering skills (not slash commands) — describe your intent in
natural language and Claude invokes them. The action skills (`readme`,
`changelog`) perform edits; the `-guide` skills are read-only references. They
are also exported to Codex as native `$readme` / `$changelog` etc.

## References

Comprehensive reference documents in `references/`:

| File | Content |
|------|---------|
| `README_PATTERNS.md` | Structure patterns from 9 awesome-readme examples |
| `CHANGELOG_PATTERNS.md` | Keep a Changelog format and automation |
| `TEMPLATES.md` | Copy-paste templates for 6 project types |
| `CRO_CHECKLIST.md` | Conversion optimization checklist |
| `EXAMPLES_ANALYSIS.md` | Detailed analysis of each example project |

## Analyzed Examples

Based on awesome-readme curated list:

- ai/size-limit - User segmentation, "Who Uses"
- gofiber/fiber - Benchmarks, Limitations transparency
- httpie/cli - GIF demo, progressive examples
- release-it/release-it - Multi-path install, schema config
- dbt-labs/dbt-core - Visual architecture, analogy-driven
- PostHog/posthog - Cloud-first, feature density
- ryanoasis/nerd-fonts - Decision tree, platform matrix
- electron-markdownify - Hero GIF, dual install paths
- react-parallax-tilt - Props table, external demos

## Usage

### Generate README

```text
Generate a README for this CLI tool
Generate a README for this library / React component / MCP plugin / SaaS / desktop app
```

### Analyze Existing README

```text
Analyze and score my README, suggest improvements
```

### Generate / update CHANGELOG

```text
Start a CHANGELOG for this project
Add a changelog entry: "Added new feature"
Cut a changelog release
```
