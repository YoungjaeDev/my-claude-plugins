---
name: commit-and-push
description: Analyze the Git changes in the files given as arguments, write a Conventional Commits message, commit, and push. Use when the user types /github-dev:commit-and-push, says "commit and push", or asks to commit specific files. Analyzes only the provided files (one logical change per commit), writes a type-prefixed imperative subject under 50 chars, then runs git add → git commit → git push. Follows the project CLAUDE.md commit guidelines and adds no AI attribution.
allowed-tools: Read Bash
---

# Commit & Push

Analyze only the files provided as arguments, create an appropriate commit message, commit, and push.

## Workflow

1. **Analyze changes**: Determine the purpose of changes in the provided files only
   - New feature addition
   - Bug fix
   - Refactoring
   - Documentation update
   - Style/formatting
2. **Write commit message**: Write clearly in Conventional Commits format
3. **Commit & Push**: `git add <provided files>` -> `git commit` -> `git push` (stage only the files passed as arguments, never `git add -A` / `git add .`)

## Commit Message Format

Follow Conventional Commits rules:

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

- **Do not analyze files other than those provided as arguments**
- **Clarity**: Clearly communicate what was changed and why
- **Follow CLAUDE.md**: Check project guidelines in `@CLAUDE.md`
- **Single purpose**: One commit should contain only one logical change
