---
name: release
description: Cut a versioned GitHub release — detect the next semver from conventional commits (or an explicit version), update version manifest files, tag, push, and create a GitHub release with auto-generated notes. Use when the user explicitly wants to publish/cut a GitHub release or version bump (e.g. "create a GitHub release", "cut a v1.2.0 release", "publish a release with changelog"). Always previews the version bump + changelog and waits for confirmation before tagging/pushing; treat an unconfirmed request as a dry-run preview. Do NOT trigger on the bare word "release" in unrelated discussion.
---

# Release

Create a versioned GitHub release with automatic version detection, version file
updates, tagging, and changelog generation via `gh release create --generate-notes`.

## Infer intent and options

There is no explicit argument string — infer from the user's request:

- **Explicit version** (e.g. "release 1.2.0") → use as-is.
- **Bump level** ("major/minor/patch release") → apply that bump.
- **Draft / prerelease** → mark accordingly.
- **Preview only** ("what would the release be", "dry run") → run the preview and stop.
- **First release / no tags yet** → baseline-tag flow (see First Release Flow).

If none specified, auto-detect the bump from conventional commits since the last tag.

## Safety: this publishes

This skill tags, pushes, and creates a public GitHub release — all hard to undo.
**Always run the Preview (Step 5) and get explicit confirmation before Step 6
onward.** If the user has not clearly confirmed they want to publish, stop after
the preview (treat it as a dry-run). Never skip validation unless the user
explicitly asks to.

## Workflow

1. **Check Prerequisites**
   - Verify `gh` CLI is installed and authenticated: `gh auth status`
   - Verify clean working tree: `git status --porcelain`
     - If uncommitted changes exist, prompt user to commit or stash first
   - Verify current branch is pushed to remote: `git rev-parse --abbrev-ref --symbolic-full-name @{u}`

2. **Detect Previous Tag**
   - Run `git describe --tags --abbrev=0 2>/dev/null` to find the latest tag
   - If no tags exist:
     - If a baseline commit was given: create baseline tag at that commit
       ```bash
       git tag v0.0.0 <commit>
       ```
     - Otherwise prompt the user:
       - Tag current HEAD as `v0.0.0` (baseline only, no release)
       - Tag a specific commit as baseline
       - Abort and let user set up tags manually
     - After baseline created, re-run detection

3. **Detect Version Files**

   Scan project root for known version manifest files. Multiple files may coexist
   (e.g., Tauri projects have both `Cargo.toml` and `tauri.conf.json`).

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
   - Store list of all detected files for batch update in Step 7

4. **Determine New Version**

   Priority order:
   1. Explicit version → use as-is (e.g., `1.2.0`)
   2. Bump level (major/minor/patch) → apply to current version
   3. Auto-detection from conventional commits since last tag:

   ```bash
   git log <prev-tag>..HEAD --oneline --no-merges
   ```

   Analyze commit prefixes:
   - `BREAKING CHANGE:` or `feat!:` or `fix!:` (with `!`) → **major**
   - `feat:` → **minor**
   - `fix:`, `docs:`, `chore:`, `refactor:`, `style:`, `test:`, `perf:`, `ci:` → **patch**
   - Mixed types → highest level wins

5. **Preview** (always — this is the gate)

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

   - If the user asked for a preview / dry-run: **stop here, create nothing**
   - Otherwise: prompt the user for explicit confirmation before continuing

6. **Validate** (unless the user explicitly asked to skip)

   Reuse the Verification Gates pattern from the `resolve-issue` skill:

   | Detection File | Project Type | Build Command | Test Command |
   |----------------|--------------|---------------|--------------|
   | `package.json` | Node.js | `npm run build` | `npm test` |
   | `Cargo.toml` | Rust | `cargo build` | `cargo test` |
   | `pyproject.toml` | Python | - | `pytest` |
   | `go.mod` | Go | `go build ./...` | `go test ./...` |

   - BUILD failure: abort release, report errors
   - TEST failure: abort release, report failures

7. **Update Version Files**

   For each detected file, update the version string:

   - `package.json`: `"version"` field via JSON-aware edit
   - `Cargo.toml`: `version = "..."` under `[package]`
   - `pyproject.toml`: `version = "..."` under `[project]` or `[tool.poetry]`
   - `setup.cfg`: `version = ...` under `[metadata]`
   - `tauri.conf.json`: `"version"` field via JSON-aware edit

   Stage all updated files: `git add <list of updated files>`

8. **Commit and Tag**

   ```bash
   git commit -m "chore: release v<NEW_VERSION>"
   git tag v<NEW_VERSION>
   ```

9. **Push and Create Release**

   ```bash
   git push origin <current-branch> --tags

   gh release create v<NEW_VERSION> \
     --generate-notes \
     --notes-start-tag <PREV_TAG> \
     --title "v<NEW_VERSION>"
   ```

   Append `--draft` and/or `--prerelease` to the `gh` command if the user asked for them.

10. **Output**

    Print the release URL returned by `gh release create`:
    ```
    Release created: https://github.com/<owner>/<repo>/releases/tag/v<NEW_VERSION>
    ```

> Read ~/.claude/CLAUDE.md and the project CLAUDE.md at runtime and follow them.

## Version File Detection Details

### Multi-File Projects

Some projects carry version numbers in multiple files (e.g., Tauri:
`tauri.conf.json` + `Cargo.toml` + optionally `package.json`). All detected files
are updated together to keep versions in sync.

### Fallback

If auto-detection finds no version files:
1. Check the project CLAUDE.md for version file hints
2. Prompt user to specify file path(s)
3. Store user response for future runs (in-session only)

## First Release Flow

For repositories with no existing tags, first create a baseline tag at a chosen
commit (e.g. `v0.0.0`) **without** creating a GitHub release, then run the release
again to generate notes from that baseline forward. Example:

```text
1. "Set the release baseline at commit abc1234"   → tags v0.0.0, no release
2. "Cut a minor release"                          → creates v0.1.0 with changelog from v0.0.0..HEAD
```
