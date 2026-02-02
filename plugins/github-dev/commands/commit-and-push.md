---
description: Analyze Git changes and commit with appropriate message, then push
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
3. **Commit & Push**: `git add` -> `git commit` -> `git push`

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

