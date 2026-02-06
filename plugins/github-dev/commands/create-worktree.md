---
description: Create git worktree with proper branch naming
---

# Create Worktree

Create a git worktree for an issue with automatic branch naming. Follow project guidelines in `@CLAUDE.md`.

## Usage

```bash
/github-dev:create-worktree #123
/github-dev:create-worktree #123 --path ../my-worktree
```

## Workflow

1. **Fetch Issue Details**
   ```bash
   gh issue view $ISSUE_NUMBER --json title,labels
   ```

2. **Determine Branch Type**
   | Label | Type |
   |-------|------|
   | `bug` | `fix` |
   | `enhancement`, `feature` | `feat` |
   | `refactor` | `refactor` |
   | `docs`, `documentation` | `docs` |
   | (default) | `feat` |

3. **Generate Branch Name**
   - Pattern: `{type}/{issue-number}-{slug}`
   - Slug: lowercase, spaces to hyphens, max 50 chars, remove special chars
   - Example: `fix/42-login-validation-error`

4. **Detect Default Branch**
   ```bash
   git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
   ```

5. **Create Worktree**
   ```bash
   BRANCH_NAME="{type}/{issue-number}-{slug}"
   WORKTREE_PATH="../{type}-{issue-number}-{slug}"

   git fetch origin
   git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" origin/$DEFAULT_BRANCH
   ```

6. **Update .gitignore (if needed)**
   ```bash
   grep -q "worktrees/" .gitignore 2>/dev/null || echo "worktrees/" >> .gitignore
   ```

7. **Output Instructions**
   ```
   Worktree created successfully!

   Branch: fix/42-login-validation-error
   Path:   ../fix-42-login-validation-error

   To start working:
     cd ../fix-42-login-validation-error && claude

   To resolve the issue:
     /github-dev:resolve-issue #42
   ```

## Flags

| Flag | Description |
|------|-------------|
| `--path` | Custom worktree path (default: `../{type}-{issue}-{slug}`) |

## Notes

- Worktree is created from the latest default branch (usually `main`)
- Branch naming follows conventional commit style
- After work is done, clean up with: `git worktree remove <path>`
