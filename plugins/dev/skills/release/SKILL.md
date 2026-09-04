---
name: release
description: Create a versioned GitHub release — detect the current version, bump by semver, update version manifest files, commit, tag, push, and run gh release create with auto-generated notes. Use ONLY when the user explicitly types /dev:release or asks to cut, publish, or tag a release. Do NOT auto-fire from incidental mentions of releases or version numbers — this creates a git tag and a public GitHub release. Supports --dry-run, --patch/--minor/--major, --draft, --prerelease, and --init for the first baseline tag, and validates build/test before releasing.
allowed-tools: Read Edit Bash AskUserQuestion
---

# Release

Create a versioned GitHub release with automatic version detection, version file updates, tagging, and changelog generation via `gh release create --generate-notes`.

## Arguments

- Version (optional): Explicit version string, e.g., `1.2.0`
- `--patch` / `--minor` / `--major`: Semver bump shorthand (overrides auto-detection)
- `--dry-run`: Preview version bump and changelog without creating anything
- `--draft`: Create as draft release on GitHub
- `--prerelease`: Mark as pre-release on GitHub
- `--skip-validation`: Skip build/test verification before releasing
- `--init <commit>`: Create initial baseline tag (for first-ever release)

## Workflow

1. **Check Prerequisites**
   - Verify `gh` CLI is installed and authenticated: `gh auth status`
   - Verify clean working tree: `git status --porcelain`
     - If uncommitted changes exist, prompt user to commit or stash first
   - Verify current branch is pushed to remote: `git rev-parse --abbrev-ref --symbolic-full-name @{u}`

2. **Detect Previous Tag**
   - Run `git describe --tags --abbrev=0 2>/dev/null` to find the latest tag
   - If no tags exist:
     - If `--init <commit>` provided: create baseline tag at specified commit
       ```bash
       git tag v0.0.0 <commit>
       ```
     - If `--init` not provided: prompt user with options:
       - Tag current HEAD as `v0.0.0` (baseline only, no release)
       - Tag a specific commit as baseline
       - Abort and let user set up tags manually
     - After baseline created, re-run detection

3. **Detect Version Files**

   Scan project root for known version manifest files. Multiple files may coexist (e.g., Tauri projects have both `Cargo.toml` and `tauri.conf.json`).

   | Detection File | Version Location | Project Type |
   |----------------|------------------|--------------|
   | `package.json` | `"version": "X.Y.Z"` | Node.js |
   | `Cargo.toml` | `version = "X.Y.Z"` | Rust |
   | `pyproject.toml` | `version = "X.Y.Z"` | Python |
   | `setup.cfg` | `version = X.Y.Z` | Python (legacy) |
   | `tauri.conf.json` | `"version": "X.Y.Z"` | Tauri |

   - Read current version from the first detected file
   - Cross-check with latest git tag version
   - If no version files found, prompt user for the file path
   - Store list of all detected files for batch update in Step 6

4. **Determine New Version**

   Priority order:
   1. Explicit version argument: use as-is (e.g., `1.2.0`)
   2. Bump flag (`--patch`, `--minor`, `--major`): apply to current version
   3. Auto-detection from conventional commits since last tag:

   ```bash
   git log <prev-tag>..HEAD --oneline --no-merges
   ```

   Analyze commit prefixes:
   - `BREAKING CHANGE:` or `feat!:` or `fix!:` (with `!`) -> **major**
   - `feat:` -> **minor**
   - `fix:`, `docs:`, `chore:`, `refactor:`, `style:`, `test:`, `perf:`, `ci:` -> **patch**
   - Mixed types -> highest level wins

5. **Preview**

   Always display before proceeding:

   ```
   Release Preview
   ---------------
   Previous tag:    v1.1.0
   New version:     v1.2.0
   Bump type:       minor (auto-detected from 3 feat commits)
   Commits:         12 commits since v1.1.0
   Version files:   package.json, Cargo.toml

   Recent changes:
     feat: add HWP/HWPX document parsing
     feat: upgrade llama.cpp to b8149
     fix: context length hardcoding issue
   ```

   - If `--dry-run`: stop here, do not proceed
   - Otherwise: prompt user for confirmation before continuing

6. **Validate (unless --skip-validation)**

   Reuse the Verification Gates pattern from `resolve-issue`:

   | Detection File | Project Type | Build Command | Test Command |
   |----------------|--------------|---------------|--------------|
   | `package.json` | Node.js | `npm run build` | `npm test` |
   | `Cargo.toml` | Rust | `cargo build` | `cargo test` |
   | `pyproject.toml` | Python | - | `pytest` |
   | `go.mod` | Go | `go build ./...` | `go test ./...` |

   - BUILD failure: abort release, report errors
   - TEST failure: abort release, report failures
   - If validation passes or `--skip-validation` used: continue

7. **Update Version Files**

   For each file detected in Step 3, update the version string:

   - `package.json`: Update `"version"` field via JSON-aware edit
   - `Cargo.toml`: Update `version = "..."` under `[package]`
   - `pyproject.toml`: Update `version = "..."` under `[project]` or `[tool.poetry]`
   - `setup.cfg`: Update `version = ...` under `[metadata]`
   - `tauri.conf.json`: Update `"version"` field via JSON-aware edit

   Stage all updated files:
   ```bash
   git add <list of updated files>
   ```

8. **Commit and Tag**

   ```bash
   git commit -m "chore: release v<NEW_VERSION>"
   git tag v<NEW_VERSION>
   ```

9. **Push and Create Release**

   ```bash
   git push origin <current-branch> --tags
   ```

   Build the `gh release create` command:
   ```bash
   gh release create v<NEW_VERSION> \
     --generate-notes \
     --notes-start-tag <PREV_TAG> \
     --title "v<NEW_VERSION>"
   ```

   Append flags if specified:
   - `--draft` -> add `--draft` to gh command
   - `--prerelease` -> add `--prerelease` to gh command

10. **Output**

    Print the release URL returned by `gh release create`:
    ```
    Release created: https://github.com/<owner>/<repo>/releases/tag/v<NEW_VERSION>
    ```

> Follow ~/.claude/CLAUDE.md and project CLAUDE.md.

## Version File Detection Details

### Multi-File Projects

All files detected in Step 3 are updated together, so a project with multiple version manifests (e.g., Tauri's `tauri.conf.json` + `Cargo.toml` + optionally `package.json`) stays in sync.

### Fallback

If auto-detection finds no version files:
1. Check `@CLAUDE.md` for version file hints
2. Prompt user to specify file path(s)
3. Store user response for future runs (in-session only)

## First Release Flow

For repositories with no existing tags:

```
/dev:release --init <commit>
```

This creates a baseline tag (`v0.0.0` by default) at the specified commit without creating a GitHub release. The next invocation of `/dev:release` will then generate notes from that baseline forward.

Example first-time setup:
```bash
# 1. Set baseline (no release created)
/dev:release --init abc1234

# 2. Create first real release
/dev:release --minor
# -> Creates v0.1.0 with changelog from v0.0.0..HEAD
```
