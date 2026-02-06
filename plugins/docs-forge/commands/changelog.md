---
name: changelog
description: Generate or update CHANGELOG files using Keep a Changelog format
argument-hint: "[init|add|release] [message]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
---

# CHANGELOG Command

Manage CHANGELOG files using Keep a Changelog format.

## Arguments

- `init` - Create new CHANGELOG.md
- `add` - Add entry to Unreleased section
- `release` - Move Unreleased to new version

## Options for `add`

- `--added` - New feature
- `--changed` - Changed existing functionality
- `--deprecated` - Soon-to-be removed feature
- `--removed` - Removed feature
- `--fixed` - Bug fix
- `--security` - Security fix

## Instructions

### For `init`

1. Create CHANGELOG.md with Keep a Changelog format
2. Include header with format and semver links
3. Add Unreleased section
4. Add initial 0.1.0 or 1.0.0 entry based on project state

### For `add`

1. Read existing CHANGELOG.md
2. Parse the Unreleased section
3. Add entry to appropriate category
4. If category doesn't exist, create it
5. Write updated CHANGELOG.md

Entry format:
```markdown
- [Description of change] ([#issue](link))
```

### For `release`

1. Read existing CHANGELOG.md
2. Determine version bump:
   - Check for breaking changes -> MAJOR
   - Check for new features -> MINOR
   - Bug fixes only -> PATCH
3. Move Unreleased content to new version section
4. Add date in ISO format
5. Create empty Unreleased section
6. Update comparison links at bottom

## Output

Write changes directly to CHANGELOG.md.

Report what was done:
```
Added to CHANGELOG.md:
- [Fixed] Description of fix

Current Unreleased:
- 2 Added
- 1 Fixed
```

## Reference

See `references/CHANGELOG_PATTERNS.md` for:
- Standard categories
- Writing style guide
- Automation tools
- Anti-patterns to avoid
