# State Management

## Overview
OMC uses file-based state management for persistence across sessions.

## State Locations

### Local State (.omc/)
```
.omc/
├── state/              # Session state files
│   ├── ralph.json
│   ├── ultrawork.json
│   ├── ultrapilot-state.json
│   ├── ultrapilot-ownership.json
│   ├── autopilot.json
│   └── ...
├── logs/               # Audit logs
│   └── delegation-audit.jsonl
├── notepads/           # Plan-scoped wisdom
│   └── {plan-name}/
│       ├── learnings.md
│       ├── decisions.md
│       ├── issues.md
│       └── problems.md
└── plans/              # Plan files (READ ONLY)
    └── {plan-name}.md
```

### Global State (~/.omc/)
```
~/.omc/
├── state/              # Global state
└── config/             # Global configuration
```

## Key State Files

### Boulder State
**File**: src/features/boulder-state.ts

Core state persistence:
- saveBoulderState() - Save session state
- loadBoulderState() - Load session state
- State includes: tasks, context, mode flags

### Mode-Specific State
Each execution mode manages its own state file:
- **Ralph**: .omc/state/ralph.json
- **Ultrawork**: .omc/state/ultrawork.json
- **Autopilot**: .omc/state/autopilot.json
- **Ultrapilot**: .omc/state/ultrapilot-state.json

### Notepad System
Plan-scoped wisdom capture (v3.4+):
- **API**: initPlanNotepad(), addLearning(), addDecision(), addIssue(), addProblem()
- **Location**: .omc/notepads/{plan-name}/
- Auto-creates on first use

## State Management Best Practices
1. Always check for existing state before creating new
2. Clean up state files on successful completion
3. Use cancel skill to clear all states
4. Notepad entries persist across sessions for learning
