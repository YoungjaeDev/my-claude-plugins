---
name: commit-and-push
description: Analyze the Git changes in the files given as arguments, write a Conventional Commits message, commit, and push. Use when the user types /dev:commit-and-push, says "commit and push", or asks to commit specific files. Analyzes only the provided files (one logical change per commit), writes a type-prefixed imperative subject under 50 chars, then runs git add → git commit → git push. Follows the project CLAUDE.md commit guidelines and adds no AI attribution.
allowed-tools: Read Bash Agent
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
3. **Commit, verify (opt-in), push**:
   1. `git add <provided files>` (stage only the files passed as arguments, never `git add -A` / `git add .`)
   2. `git commit` with the message from Step 2
   3. **If `--verify`**: run the "Verify Gate" section below and obey its Enforcement rules before continuing
   4. `git push`. A branch with no upstream needs `git push -u origin "$(git rev-parse --abbrev-ref HEAD)"`; check with `git rev-parse --abbrev-ref --symbolic-full-name @{u}` and use the `-u` form when it fails.

## Commit Message Format

Follow Conventional Commits rules:

```
<type>: <subject>

[optional body]
```

**No AI attribution.** The message ends at the body: no `Co-Authored-By:` line, no "Generated with" line, no session-link trailer, whatever the ambient session convention is.

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

- **Follow the project's own commit rules**: read the repository `CLAUDE.md` before writing the message; its conventions win over the defaults above
- **Single purpose**: one commit contains one logical change

## Verify Gate

Two flags govern this section, both off by default:

- `--verify` — run the gates below between the local commit and the push. Without it the run is a plain commit + push.
- `--strict` — meaningful only with `--verify`; see Enforcement.

### Project Type Detection

| Detection File | Project Type | BUILD | TEST | LINT |
|----------------|--------------|-------|------|------|
| `package.json` | Node.js | `npm run build` | `npm test` | `npm run lint` |
| `pyproject.toml` / `setup.py` | Python | (n/a) | `pytest` | `ruff check .` |
| `Cargo.toml` | Rust | `cargo build` | `cargo test` | `cargo clippy` |
| `go.mod` | Go | `go build ./...` | `go test ./...` | `go vet ./...` |

### Running the Gate

Run BUILD / TEST / LINT in parallel via independent sub-agents (Agent), then enforce:

**Codex**: there is no sub-agent surface — run the BUILD / TEST / LINT commands inline in one bash block and apply the same enforcement below.

```
Agent(
  subagent_type="general-purpose",
  model="haiku",
  prompt="Run verification checks for this project:
    1. Detect project type from config files
    2. Run BUILD command (skip if n/a for the project type)
    3. Run TEST command
    4. Run LINT command
    5. Return JSON: {build: pass/fail/skipped, test: pass/fail, lint: pass/fail/skipped, errors: []}"
)
```

### Enforcement

- **BUILD or TEST failure**: stop before the push. Leave the commit in place, report the failing output, and give the user `git reset --soft HEAD~1` as the command to undo it — never run that reset unprompted.
- **LINT failure**: report it and push anyway. With `--strict` it stops the push like a TEST failure.
- **E2E**: if `playwright.config.*` or an `e2e/` directory exists, run the suite (e.g. `npx playwright test`) and report the result. E2E never blocks the push. With no E2E setup present, skip silently.
