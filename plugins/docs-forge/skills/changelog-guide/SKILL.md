# CHANGELOG Guide

This skill provides CHANGELOG writing patterns based on Keep a Changelog and Conventional Commits.

## Triggers

- "how to write changelog"
- "changelog format"
- "changelog template"
- "keep a changelog"

## Quick Reference

### Standard Format

```markdown
# Changelog

## [Unreleased]

### Added
- New feature

### Fixed
- Bug fix

## [1.0.0] - 2026-02-05

### Added
- Initial release
```

### Categories

| Category | When to Use |
|----------|-------------|
| Added | New features |
| Changed | Existing functionality changes |
| Deprecated | Features to be removed |
| Removed | Removed features |
| Fixed | Bug fixes |
| Security | Security patches |

### Semantic Versioning

```
MAJOR.MINOR.PATCH

MAJOR: Breaking changes
MINOR: New features (backward compatible)
PATCH: Bug fixes (backward compatible)
```

### Writing Style

Write for users, not developers:

| Bad | Good |
|-----|------|
| "Fixed async race condition" | "Fixed crash on file upload" |
| "Refactored auth module" | "Improved login speed by 50%" |
| "Updated deps" | "Improved security with latest libraries" |

## Automation Tools

| Tool | Best For |
|------|----------|
| semantic-release | Full CI/CD automation |
| release-please | GitHub PR-based review |
| git-cliff | Customizable generation |

## References

For detailed patterns, see:
- `../../references/CHANGELOG_PATTERNS.md` - Full format documentation
