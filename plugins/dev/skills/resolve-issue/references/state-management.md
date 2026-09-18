# State Management

Session state file, schema, checkpoint save and cleanup blocks for `SKILL.md` ("[NEW] Save checkpoint" lines, Step 12).

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
