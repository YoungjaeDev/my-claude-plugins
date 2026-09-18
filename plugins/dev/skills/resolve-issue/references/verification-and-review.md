# Verification Gates and 2-Stage Review

Detail for `SKILL.md` Steps 9.5 and 9.6.

## Verification Gates

Quality gates that must pass before commit.

### Check Types
| Check | Purpose | Required |
|-------|---------|----------|
| BUILD | Compilation success | Yes |
| TEST | All tests pass | Yes |
| LINT | No linting errors | No (warning only) |
| TYPE_CHECK | Type errors resolved | No (warning only) |

### Project Type Detection
| Detection File | Project Type | Commands |
|----------------|--------------|----------|
| `package.json` | Node.js | `npm run build`, `npm test`, `npm run lint` |
| `pyproject.toml` or `setup.py` | Python | `pytest`, `ruff check .` |
| `Cargo.toml` | Rust | `cargo build`, `cargo test`, `cargo clippy` |
| `go.mod` | Go | `go build ./...`, `go test ./...` |

### Running Verification
```
Agent(
  subagent_type="claude",
  model="sonnet",
  prompt="Run verification checks for this project:
    1. Detect project type from config files
    2. Run BUILD command - must pass
    3. Run TEST command - must pass
    4. Run LINT command - report warnings
    5. Return JSON: {build: pass/fail, test: pass/fail, lint: pass/fail/skipped, errors: []}"
)
```

### Gate Enforcement
- BUILD failure: Block commit, report errors
- TEST failure: Block commit, report failures
- LINT failure: Warn but allow commit (unless `--strict`)


## 2-Stage Review Protocol

### Overview
Before PR creation, implementation passes two review stages:
1. **Spec Compliance** - Does it meet requirements?
2. **Code Quality** - Is it well implemented?

### Stage 1: Spec Compliance Review

```
Agent(
  subagent_type="claude",
  model="sonnet",
  prompt="Spec compliance review for issue #${ISSUE_NUMBER}
    ## Issue Requirements
    ${ISSUE_BODY}
    ## Changed Files
    ${GIT_DIFF_STAT}
    ## Review Checklist
    1. Does implementation meet all issue requirements?
    2. Are all checkbox items in the issue addressed?
    3. Any missing functionality?
    ## Output: {verdict: PASS|FAIL, gaps: [], recommendation: string}"
)
```

### Stage 2: Code Quality Review

```
Agent(
  subagent_type="claude",
  model="opus",
  prompt="Code quality review for issue #${ISSUE_NUMBER}
    ## Changed Files
    ${GIT_DIFF}
    ## Review Checklist
    1. Does code follow project conventions?
    2. Is error handling comprehensive?
    3. Are tests sufficient?
    4. Any security concerns?
    ## Output: {verdict: PASS|FAIL, issues: [], recommendation: string}"
)
```

### Review Loop
- Maximum 3 retries per stage
- On failure, fix based on specific feedback
- After 3 failures, escalate to user

### Skip Review Flag
`--skip-review`: Use for trusted changes (e.g., docs only)
