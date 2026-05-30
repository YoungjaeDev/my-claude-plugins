# resolve-issue protocols

Detailed protocols referenced by the `resolve-issue` skill: session state
management, verification gates, and the 2-stage review.

## Verification and Completion Criteria

**Important**: Always verify actual behavior before marking checkboxes as complete.

### Verification Principles
1. **Execution required**: Directly run code/configuration to confirm it actually works
2. **Provide evidence**: Show actual output or results that prove completion
3. **No guessing**: Explicitly mark unverified items as "unverified" or "assumed"
4. **Distinguish partial completion**: Clearly separate code written but not tested

### Prohibited Actions
- Reporting "expected to work" without execution
- Stating "will appear in logs" without checking logs
- Presenting assumptions as facts

## State Management

Session state enables workflow recovery after interruption.

### State File Location
Sessions are saved to: `.claude/state/github-dev-{issue-number}.json`

### State Schema
```json
{
  "sessionId": "github-dev-{issue-number}-{timestamp}",
  "command": "resolve-issue",
  "issueNumber": 123,
  "phase": "analyze|branch|implement|test|review|commit|pr",
  "branchName": "feat/123-add-dark-mode",
  "branchType": "feat|fix|refactor|docs|chore",
  "startedAt": "ISO timestamp",
  "lastCheckpoint": "ISO timestamp",
  "checkpoints": [
    { "phase": "analyze", "status": "complete", "timestamp": "ISO" },
    { "phase": "implement", "status": "in_progress", "timestamp": "ISO" }
  ]
}
```

### Checkpoint Save (after each phase)
```bash
mkdir -p .claude/state
cat > .claude/state/github-dev-${ISSUE_NUMBER}.json << 'EOF'
{... state JSON ...}
EOF
```

### Cleanup (on successful completion)
```bash
mkdir -p .claude/state/archive
mv .claude/state/github-dev-${ISSUE_NUMBER}.json \
   .claude/state/archive/github-dev-${ISSUE_NUMBER}-$(date +%Y%m%d).json
```

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
Task(
  subagent_type="claude",
  model="haiku",
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
- LINT failure: Warn but allow commit (unless the user asked for strict mode)

## 2-Stage Review Protocol

### Overview
Before PR creation, implementation passes two review stages:
1. **Spec Compliance** - Does it meet requirements?
2. **Code Quality** - Is it well implemented?

### Stage 1: Spec Compliance Review

```
Task(
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
Task(
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

### Skip Review
Skip review only for trusted changes (e.g., docs only) when the user explicitly asks.
