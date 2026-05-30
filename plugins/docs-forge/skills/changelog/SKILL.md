---
name: changelog
description: Create or update a project's CHANGELOG.md file in Keep a Changelog format — initialize a new changelog, add entries to the Unreleased section, or cut a release by moving Unreleased into a versioned section. Use when the user wants to write, edit, bump, or maintain a CHANGELOG (e.g. "add a changelog entry", "update the changelog", "start a CHANGELOG", "cut a changelog release"). This performs the edit; for format reference only, see the changelog-guide skill.
---

# CHANGELOG

Create and maintain CHANGELOG.md files using the Keep a Changelog format. This
skill writes changes to disk — confirm the intended action when ambiguous.

## Infer the action

There is no explicit argument string — infer which operation the user wants from
their request and the conversation:

| Intent | Operation |
|--------|-----------|
| "start / create a changelog", no file exists | `init` |
| "add / note / record a change", "log this" | `add` (to Unreleased) |
| "cut a release", "move unreleased to vX", "release the changelog" | `release` |

For `add`, infer the category from the change description: Added (new feature),
Changed, Deprecated, Removed, Fixed (bug fix), Security. If the category is
genuinely ambiguous, ask once via `AskUserQuestion`.

## Instructions

### init

1. Create CHANGELOG.md with Keep a Changelog format
2. Include header with format and semver links
3. Add an Unreleased section
4. Add an initial 0.1.0 or 1.0.0 entry based on project state

### add

1. Read existing CHANGELOG.md
2. Parse the Unreleased section
3. Add the entry to the appropriate category (create the category if missing)
4. Write updated CHANGELOG.md

Entry format:
```markdown
- [Description of change] ([#issue](link))
```

### release

1. Read existing CHANGELOG.md
2. Determine version bump:
   - Breaking changes → MAJOR
   - New features → MINOR
   - Bug fixes only → PATCH
3. Move Unreleased content to a new version section
4. Add the date in ISO format
5. Create a fresh empty Unreleased section
6. Update comparison links at the bottom

## Output

Write changes directly to CHANGELOG.md, then report what was done:

```
Added to CHANGELOG.md:
- [Fixed] Description of fix

Current Unreleased:
- 2 Added
- 1 Fixed
```

## Reference

For standard categories, writing-style guide, automation tools, and
anti-patterns, see `../../references/CHANGELOG_PATTERNS.md` (or invoke the
`changelog-guide` skill for the quick reference).
