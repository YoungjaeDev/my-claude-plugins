---
name: commit-and-push
description: Analyze a specific set of changed files, write a Conventional Commits message for them, then commit and push. Use when the user asks to commit and push a named/selected set of files (e.g. "commit and push these files", "commit src/auth.ts and push"). Scoped to the files the user names — it does not stage or analyze unrelated changes. This pushes to the remote; only the named files are committed.
---

# Commit & Push

Analyze only the files the user identified, write an appropriate commit message,
commit, and push.

## Scope: which files

There is no explicit argument string — take the target files from what the user
named in the request or the immediate conversation. **Do not analyze or stage
files other than those.** If no files are clearly identified, ask which files to
commit rather than guessing or staging everything.

## Before pushing

`git push` updates the remote. Show the proposed commit message and the exact
file list, and proceed once the scope is clear. If the user only asked to
"commit" (not push), stop after the commit.

## Workflow

1. **Analyze changes**: Determine the purpose of changes in the provided files only
   - New feature addition
   - Bug fix
   - Refactoring
   - Documentation update
   - Style/formatting
2. **Write commit message**: Conventional Commits format
3. **Commit & Push**: `git add <named files>` → `git commit` → `git push`

## Commit Message Format

```
<type>: <subject>

[optional body]
```

### Types
- `feat`: New feature addition
- `fix`: Bug fix
- `refactor`: Code refactoring
- `docs`: Documentation changes
- `style`: Code formatting, missing semicolons, etc.
- `test`: Test code addition/modification
- `chore`: Build, configuration file changes

### Subject Guidelines
- Use imperative, present tense
- Start with lowercase
- No period at the end
- Keep it concise (under 50 characters)

## Guidelines

- **Do not analyze or stage files other than those the user named**
- **Clarity**: Clearly communicate what was changed and why
- **Follow CLAUDE.md**: Read the project's CLAUDE.md at runtime and follow its guidelines
- **Single purpose**: One commit should contain only one logical change
