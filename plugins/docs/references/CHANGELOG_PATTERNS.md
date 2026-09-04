# CHANGELOG Patterns Reference

Based on Keep a Changelog, Conventional Commits, and industry best practices.

---

## Standard Format (Keep a Changelog)

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- New feature description

### Changed
- Change description

### Fixed
- Bug fix description

## [1.0.0] - 2026-02-05

### Added
- Initial release

[Unreleased]: https://github.com/user/repo/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/user/repo/releases/tag/v1.0.0
```

---

## Categories

| Category | When to Use | Example |
|----------|-------------|---------|
| **Added** | New features | "Added dark mode support" |
| **Changed** | Existing functionality changes | "Changed API response format" |
| **Deprecated** | Features to be removed | "Deprecated v1 API endpoints" |
| **Removed** | Removed features | "Removed IE11 support" |
| **Fixed** | Bug fixes | "Fixed memory leak in file upload" |
| **Security** | Security patches | "Fixed SQL injection vulnerability" |

---

## Semantic Versioning

```
MAJOR.MINOR.PATCH

MAJOR: Breaking changes (1.x.x -> 2.0.0)
MINOR: New features, backward compatible (1.0.x -> 1.1.0)
PATCH: Bug fixes, backward compatible (1.0.0 -> 1.0.1)
```

### Version Bump Rules

| Change Type | Version Bump | Example |
|-------------|--------------|---------|
| Breaking API change | MAJOR | Removing endpoint |
| New feature | MINOR | Adding endpoint |
| Bug fix | PATCH | Fixing validation |
| Security fix | PATCH (usually) | Patching vulnerability |
| Deprecation notice | MINOR | Marking for removal |

---

## Writing Style

### User-Focused (Good)

```markdown
### Fixed
- Fixed crash when uploading files larger than 100MB
- Improved dashboard load time by 40%
- Login now works with special characters in password
```

### Developer-Focused (Avoid for public changelog)

```markdown
### Fixed
- Fixed async race condition in FileUploadService
- Optimized SQL query in DashboardRepository
- Updated bcrypt regex validation
```

### Comparison

| Bad | Good |
|-----|------|
| "Fixed bug in auth module" | "Fixed login failure with SSO accounts" |
| "Updated dependencies" | "Improved security with updated crypto libraries" |
| "Refactored code" | "Improved performance of search feature" |
| "Fixed #234" | "Fixed file upload timeout (#234)" |

---

## Entry Format

### Standard Pattern

```markdown
- [Action verb] [what changed] [benefit/context] ([#issue](link))
```

### Examples

```markdown
### Added
- Added bulk export feature for reports, supporting CSV and Excel formats (#123)
- Added keyboard shortcuts for common actions (Ctrl+S to save, Ctrl+Z to undo)

### Changed
- Changed default timeout from 30s to 60s for large file uploads
- Improved error messages to include suggested fixes

### Fixed
- Fixed memory leak when processing large datasets (#456)
- Fixed incorrect date display in non-UTC timezones

### Security
- Fixed XSS vulnerability in comment rendering (CVE-2026-1234)
```

---

## Unreleased Section

Always maintain an `[Unreleased]` section at the top:

```markdown
## [Unreleased]

### Added
- Feature in progress

### Fixed
- Bug fix merged but not released
```

**Benefits**:
- Tracks work between releases
- Makes release notes preparation easier
- Shows project activity

---

## Version Links

Add comparison links at the bottom:

```markdown
[Unreleased]: https://github.com/user/repo/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/user/repo/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/user/repo/releases/tag/v1.0.0
```

---

## Conventional Commits Integration

If using Conventional Commits for auto-generation:

### Commit Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type Mapping

| Commit Type | Changelog Category |
|-------------|-------------------|
| `feat:` | Added |
| `fix:` | Fixed |
| `perf:` | Changed |
| `refactor:` | (Usually excluded) |
| `docs:` | (Usually excluded) |
| `style:` | (Usually excluded) |
| `test:` | (Usually excluded) |
| `chore:` | (Usually excluded) |
| `BREAKING CHANGE:` | Breaking Changes |

### Example Commits

```bash
feat(auth): add SSO login support
fix(upload): handle files larger than 100MB
perf(dashboard): improve load time by 40%
feat!: change API response format  # Breaking change
```

---

## Automation Tools

### Comparison

| Tool | Best For | Automation Level |
|------|----------|------------------|
| **semantic-release** | Full CI/CD automation | High |
| **release-please** | GitHub PR-based review | Medium-High |
| **standard-version** | Local control | Medium |
| **git-cliff** | Customizable generation | Low |

### semantic-release

```yaml
# .github/workflows/release.yml
- uses: cycjimmy/semantic-release-action@v4
```

Auto: version bump + changelog + GitHub release + npm publish

### release-please

```yaml
# .github/workflows/release.yml
- uses: googleapis/release-please-action@v4
```

Creates PR with changelog, merge to release.

### git-cliff

```bash
git cliff --output CHANGELOG.md
```

Generate only, manual version control.

---

## Breaking Changes

### Highlighting

```markdown
## [2.0.0] - 2026-02-05

### Breaking Changes

- **API**: Changed `/users` endpoint response format
  - Migration: Update client to handle new `data` wrapper
- **Config**: Renamed `apiKey` to `api_key` in config file
  - Migration: Update your config file

### Added
- ...
```

### Migration Guide Pattern

```markdown
### Breaking Changes

#### API Response Format

**Before (v1.x)**:
```json
{ "users": [...] }
```

**After (v2.x)**:
```json
{ "data": { "users": [...] }, "meta": {...} }
```

**Migration**: Update your client code to access `response.data.users`
```

---

## Templates

### Minimal

```markdown
# Changelog

## [Unreleased]

## [1.0.0] - YYYY-MM-DD

### Added
- Initial release
```

### Standard

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [1.0.0] - YYYY-MM-DD

### Added
- Initial release with core features

[Unreleased]: https://github.com/user/repo/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/user/repo/releases/tag/v1.0.0
```

### With Breaking Changes Section

```markdown
# Changelog

## [Unreleased]

## [2.0.0] - YYYY-MM-DD

### Breaking Changes
- Description with migration guide

### Added
- New features

### Changed
- Changes

### Fixed
- Fixes

## [1.x.x]
...
```

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| Git log dump | Unreadable, dev-focused | Curate and summarize |
| "Various fixes" | Uninformative | Be specific |
| Missing dates | Can't track timeline | Always include date |
| No version links | Can't see diffs | Add comparison URLs |
| Inconsistent format | Hard to scan | Use standard categories |
| Including internal changes | Noise for users | Filter to user-facing |
| Passive voice | Unclear actor | Use active voice |

---

## Checklist

Before release:

- [ ] Unreleased section moved to new version
- [ ] Version number follows semver
- [ ] Date in ISO format (YYYY-MM-DD)
- [ ] All entries use active voice
- [ ] Breaking changes clearly marked
- [ ] Migration guides for breaking changes
- [ ] Issue/PR links included
- [ ] Version comparison links updated
- [ ] No internal/dev-only changes
- [ ] Entries sorted by importance
