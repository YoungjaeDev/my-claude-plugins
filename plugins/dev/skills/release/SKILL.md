---
name: release
description: Create a versioned GitHub release — detect the current version, bump by semver, update version manifest files, commit, tag, push, and run gh release create with auto-generated notes. Use ONLY when the user explicitly types /dev:release or asks to cut, publish, or tag a release. Do NOT auto-fire from incidental mentions of releases or version numbers — this creates a git tag and a public GitHub release. Supports --dry-run, --patch/--minor/--major, --draft, --prerelease, and --init for the first baseline tag, and validates build/test before releasing.
allowed-tools: Read Edit Bash AskUserQuestion
---

# Release

Create a versioned GitHub release: detect the current version, update the version manifests, commit, tag, push, and let `gh release create --generate-notes` write the release-page notes. The repository's `CHANGELOG.md` is not this skill's file — `dev:post-merge` Step 9.5 and `docs:changelog` own it.

## Guidelines

- **Ask before the irreversible action**: every prompt below is a gate. Ask with `AskUserQuestion` on Claude Code or `request_user_input` on Codex; when neither is available, ask one short blocking question before the tag, the push or `gh release create`.
- **The tag and the release are public and irreversible**: never run Steps 8-9 without the Step 5 confirmation, and never publish a tag this run did not create.
- **Idempotent re-runs**: Step 8 commits only what Step 7 staged and accepts an existing tag only when it already points at `HEAD`.

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
   - Verify current branch is pushed to remote: `git rev-parse --abbrev-ref --symbolic-full-name @{u}`. No upstream means the tag would point at a commit GitHub cannot see — stop and have the user push the branch first.

2. **Detect Previous Tag**
   - Run `git fetch --tags` and then `git tag --list 'v[0-9]*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -t. -k1.2,1n -k2,2n -k3,3n | tail -1` to find the highest existing release tag; the strict `vX.Y.Z` filter keeps `v2`, pre-release and nightly tags out of the pick. Do not use `git describe --tags --abbrev=0`: it returns the nearest tag reachable from HEAD, which is not the latest version whenever a higher tag lives on another branch — and that single value feeds both the bump base and `--notes-start-tag`.
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
   - Read the CI the previous tag's push started: `scripts/ci-run-check.sh <PREV_TAG>` (resolver and reading rules in `references/ci-check.md`). Show its lines in the Step 5 preview; a job that never started is a warning, not a stop.

3. **Detect Version Files**

   Scan project root for known version manifest files. Multiple files may coexist (e.g., Tauri projects have both `Cargo.toml` and `tauri.conf.json`).

   | Detection File | Version Location | Project Type | Step 7 update |
   |----------------|------------------|--------------|---------------|
   | `package.json` | `"version": "X.Y.Z"` | Node.js | `"version"` field, JSON-aware edit |
   | `Cargo.toml` | `version = "X.Y.Z"` | Rust | `version = "..."` under `[package]` |
   | `pyproject.toml` | `version = "X.Y.Z"` | Python | `version = "..."` under `[project]` or `[tool.poetry]` |
   | `setup.cfg` | `version = X.Y.Z` | Python (legacy) | `version = ...` under `[metadata]` |
   | `tauri.conf.json` | `"version": "X.Y.Z"` | Tauri | `"version"` field, JSON-aware edit |

   - Read current version from the first detected file
   - Cross-check with latest git tag version
   - If no version files found, check the project's `CLAUDE.md` for version file hints, then prompt the user for the file path(s)
   - Store list of all detected files for batch update in Step 7

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
     feat: <subject>
     feat: <subject>
     fix: <subject>
   ```

   - If `--dry-run`: stop here, do not proceed
   - Otherwise: prompt user for confirmation before continuing

6. **Validate (unless --skip-validation)**

   Detect the project type and run its build and test:

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

   For each file detected in Step 3, update the version string as the table's last column says, then stage the updated files:
   ```bash
   git add <list of updated files>
   ```

8. **Commit and Tag**

   Commit only when Step 7 actually staged something. A re-run, or a version the manifests already
   carry, stages nothing, and a bare `git commit` then aborts on `nothing to commit` and takes the
   tag down with it:

   ```bash
   if git diff --cached --quiet; then
     echo "release: version files already at v<NEW_VERSION> — tagging the existing commit"
   else
     git commit -m "chore: release v<NEW_VERSION>"
   fi
   # Idempotent after a partial release: an existing tag is accepted only when it already
   # points at this commit; a tag on a different commit is a mismatch, not something to move.
   if git rev-parse --verify --quiet "refs/tags/v<NEW_VERSION>" >/dev/null; then
     [ "$(git rev-list -n1 "v<NEW_VERSION>")" = "$(git rev-parse HEAD)" ] \
       || { echo "release: tag v<NEW_VERSION> points at a different commit" >&2; exit 1; }
   else
     git tag v<NEW_VERSION>
   fi
   ```

9. **Push and Create Release**

   Push the branch and **only the tag this run created**. `--tags` would publish every local tag, including an `--init` baseline or an unrelated experiment:

   ```bash
   git push origin <current-branch>
   git push origin "v<NEW_VERSION>"
   ```

   GitHub resolves `--notes-start-tag`, so the baseline must be on the remote, and an `--init`
   baseline is local-only until now. Publish only the baseline this run created; any other
   local-only tag was never agreed to, so empty `PREV_TAG` instead.

   ```bash
   if ! git ls-remote --exit-code --tags origin "refs/tags/<PREV_TAG>" >/dev/null 2>&1; then
     if [ "<PREV_TAG>" = "<the tag --init created this run>" ]; then
       git push origin "<PREV_TAG>" || PREV_TAG=""
     else
       PREV_TAG=""   # local-only tag from elsewhere: never published on the user's behalf
     fi
   fi
   ```

   Build the `gh release create` command:
   ```bash
   gh release create v<NEW_VERSION> \
     --generate-notes \
     --notes-start-tag <PREV_TAG> \
     --title "v<NEW_VERSION>"
   ```

   Drop `--notes-start-tag` entirely when `PREV_TAG` is empty: `--generate-notes` then falls back
   to the previous release GitHub knows about.

   Append flags if specified:
   - `--draft` -> add `--draft` to gh command
   - `--prerelease` -> add `--prerelease` to gh command

10. **Output**

    Print the release URL returned by `gh release create`:
    ```
    Release created: https://github.com/<owner>/<repo>/releases/tag/v<NEW_VERSION>
    ```

    Then run `scripts/ci-run-check.sh v<NEW_VERSION>` once and add its lines: whether the tag's run was created and started. Do not wait for it to finish.

## First release

In a repository with no tags, `/dev:release --init <commit>` creates the `v0.0.0` baseline tag without a GitHub release (Step 2).
The next `/dev:release` (for example `--minor`, giving `v0.1.0`) generates notes from that baseline forward.
Until then the baseline is local-only; Step 9 pushes it only because this run created it.
