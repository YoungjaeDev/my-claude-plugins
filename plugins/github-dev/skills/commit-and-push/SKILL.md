---
name: commit-and-push
description: Analyze the Git changes in the files given as arguments, write a Conventional Commits message, commit, and push. Use when the user types /github-dev:commit-and-push, says "commit and push", or asks to commit specific files. Analyzes only the provided files (one logical change per commit), writes a type-prefixed imperative subject under 50 chars, then runs git add → git commit → git push. Follows the project CLAUDE.md commit guidelines and adds no AI attribution.
allowed-tools: Read Bash Task
---

# Commit & Push

## Hermes Agent Compatibility

When this skill is loaded through Hermes as `github-dev:<skill>`, map Claude/Codex tool names to Hermes tools:

| Claude/Codex term | Hermes tool |
|---|---|
| Bash | terminal |
| Read | read_file |
| Write | write_file |
| Edit | patch |
| Glob/Grep | search_files |
| AskUserQuestion | clarify |
| Task | delegate_task |
| Monitor | process |

Treat `$ARGUMENTS` as the natural-language arguments supplied when the user asks Hermes to run the skill. Installed into `~/.hermes/skills/` by `npx skills`, this skill is indexed automatically — it appears in `skills_list()` and as a slash command under its **flat** name (`<skill>`, not `github-dev:<skill>`).

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
   3. **If `--verify`** (default OFF): run the gates in the "Verify Gate" section below. A BUILD or TEST failure **aborts here** — the commit stays local and nothing is pushed. A LINT failure warns only (blocks only with `--strict`).
   4. `git push`

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
- **`--verify`** (default OFF): run BUILD / TEST / LINT (+ opt-in E2E) gates between commit and push. Without the flag, behavior is unchanged — plain commit + push.
- **`--strict`**: only meaningful together with `--verify`; promotes a LINT failure from warn to a push-blocking error.

## Verify Gate

Quality gates that run **only when `--verify` is passed** (Step 3.3). They run after the local commit and decide whether the push proceeds — keeping the default path (no flag) a plain commit + push.

### Project Type Detection

| Detection File | Project Type | BUILD | TEST | LINT |
|----------------|--------------|-------|------|------|
| `package.json` | Node.js | `npm run build` | `npm test` | `npm run lint` |
| `pyproject.toml` / `setup.py` | Python | (n/a) | `pytest` | `ruff check .` |
| `Cargo.toml` | Rust | `cargo build` | `cargo test` | `cargo clippy` |
| `go.mod` | Go | `go build ./...` | `go test ./...` | `go vet ./...` |

### Running the Gate

Run BUILD / TEST / LINT in parallel via independent sub-agents (Task), then enforce:

```
Task(
  subagent_type="claude",
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

- **BUILD failure**: abort before push; the commit stays local. Report errors.
- **TEST failure**: abort before push; the commit stays local. Report failures.
- **LINT failure**: warn but push anyway — unless `--strict`, which makes it blocking.
- **E2E (opt-in within `--verify`)**: if `playwright.config.*` or an `e2e/` directory is detected, run the suite (e.g. `npx playwright test`) and report. E2E failures are **warn-only — never block the push** (mirrors `resolve-issue` Step 9.4). If no E2E setup is detected, silently skip.
