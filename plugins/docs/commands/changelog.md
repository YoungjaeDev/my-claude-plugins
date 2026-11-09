---
name: changelog
description: Generate or update CHANGELOG files using Keep a Changelog format
argument-hint: "[init|add|release] [message]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Skill
---

# CHANGELOG Command

Manage CHANGELOG.md in Keep a Changelog format with 3 modes (`init`, `add`, `release`) and 6 entry categories.

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

First load `Skill("docs:doc-guides")` and follow its `## Human-read documents` and `## CHANGELOG` sections. Entries follow the tone rules of `references/writing-standard.md`; the Keep a Changelog headings stay as the format defines them, since `CHANGELOG.md` is on the standard's exception list for shape. Categories, writing style, automation tools and anti-patterns are in `references/CHANGELOG_PATTERNS.md`.

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

