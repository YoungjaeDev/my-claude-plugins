# Task Completion Checklist

When completing a task in oh-my-claudecode, ensure the following steps are performed:

## Before Committing

### 1. Build Check
```bash
npm run build
```
Ensure TypeScript compilation succeeds without errors.

### 2. Lint Check
```bash
npm run lint
```
Fix any linting errors or warnings.

### 3. Format Code
```bash
npm run format
```
Ensure consistent code formatting.

### 4. Run Tests
```bash
npm run test:run
```
Ensure all tests pass.

## Code Quality Guidelines

### For New Features
- Add appropriate TypeScript types
- Export from relevant index.ts files
- Add JSDoc comments for public APIs
- Consider backward compatibility

### For Bug Fixes
- Identify root cause
- Write regression test if applicable
- Test edge cases

### For Agents/Skills
- Place agent definitions in `agents/` directory
- Place skill definitions in `skills/` directory with proper `SKILL.md` and optional `trigger.txt`
- Update README.md if adding significant features

## Commit Message Format
Use conventional commit format:
- `feat:` for new features
- `fix:` for bug fixes
- `docs:` for documentation
- `chore:` for maintenance
- `refactor:` for refactoring
- `test:` for tests

Example: `feat: add new scientist agent tier`
