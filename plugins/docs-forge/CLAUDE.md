# docs-forge Plugin

Generate and analyze README/CHANGELOG files using CRO best practices from awesome-readme.

## Skills

| Skill | Description |
|-------|-------------|
| `readme-guide` | README patterns and templates reference |
| `changelog-guide` | CHANGELOG format and automation guide |
| `deploy-doc-guide` | Deployment / procedure doc skeleton (summary + prerequisites + numbered steps) |
| `moc-guide` | MOC index generation spec (hook precedence, lightweight vs strict) |

## Commands

| Command | Description |
|---------|-------------|
| `/docs-forge:readme` | Generate or analyze README |
| `/docs-forge:changelog` | Generate or analyze CHANGELOG |
| `/docs-forge:deploy-doc` | Generate or restructure a deployment / procedure doc |
| `/docs-forge:moc` | Generate a Map of Content index for a docs folder |

## References

Comprehensive reference documents in `references/`:

| File | Content |
|------|---------|
| `README_PATTERNS.md` | Structure patterns from 9 awesome-readme examples |
| `CHANGELOG_PATTERNS.md` | Keep a Changelog format and automation |
| `TEMPLATES.md` | Copy-paste templates for 6 project types |
| `CRO_CHECKLIST.md` | Conversion optimization checklist |
| `EXAMPLES_ANALYSIS.md` | Detailed analysis of each example project |
| `DEPLOY_DOC_PATTERNS.md` | Deployment-doc skeleton, filled example, anti-patterns (Korean) |
| `MOC_PATTERNS.md` | MOC hook-sourcing ladder, lightweight + strict examples (Korean) |

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

```
/docs-forge:readme generate --type cli
/docs-forge:readme generate --type library
/docs-forge:readme generate --type react-component
/docs-forge:readme generate --type mcp-plugin
/docs-forge:readme generate --type saas
/docs-forge:readme generate --type desktop
```

### Analyze Existing README

```
/docs-forge:readme analyze
```

### Generate CHANGELOG

```
/docs-forge:changelog init
/docs-forge:changelog add "Added new feature"
```

### Generate Deployment Doc

```
/docs-forge:deploy-doc generate docs/deploy/inference.md --title "추론 서비스 배포"
/docs-forge:deploy-doc generate docs/deploy/inference.md --links deploy/spec.md
/docs-forge:deploy-doc rewrite docs/legacy-procedure.md
```

### Generate MOC

```
/docs-forge:moc docs/
/docs-forge:moc docs/ --strict
/docs-forge:moc docs/ --out docs/INDEX.md
```
