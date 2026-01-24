---
name: swarm
description: N coordinated agents on shared task list with atomic claiming
---

# Swarm Skill

Spawn N coordinated agents working on a shared task list with atomic claiming. Like a dev team tackling multiple files in parallel.

## Usage

```
/swarm N:agent-type "task description"
```

### Parameters

- **N** - Number of agents (1-5, enforced by Claude Code limit)
- **agent-type** - Agent to spawn (e.g., executor, build-fixer, architect)
- **task** - High-level task to decompose and distribute

### Examples

```bash
/swarm 5:executor "fix all TypeScript errors"
/swarm 3:build-fixer "fix build errors in src/"
/swarm 4:designer "implement responsive layouts for all components"
/swarm 2:architect "analyze and document all API endpoints"
```

## Architecture

```
User: "/swarm 5:executor fix all TypeScript errors"
              |
              v
      [SWARM ORCHESTRATOR]
              |
   +--+--+--+--+--+
   |  |  |  |  |
   v  v  v  v  v
  E1 E2 E3 E4 E5
   |  |  |  |  |
   +--+--+--+--+
          |
          v
   [SHARED TASK LIST]
   - Fix a.ts (claimed E1)
   - Fix b.ts (done E2)
   - Fix c.ts (claimed E3)
   - Fix d.ts (pending)
   ...
```

## Workflow

### 1. Parse Input
- Extract N (agent count)
- Extract agent-type
- Extract task description
- Validate N <= 5

### 2. Create Task List
- Analyze codebase based on task
- Break into file-specific subtasks
- Initialize shared task list with all subtasks
- Each task gets: id, file, description, status, owner, timestamp

### 3. Spawn Agents
- Launch N agents via Task tool
- Set `run_in_background: true` for all
- Each agent gets:
  - Reference to shared task list
  - Claiming protocol instructions
  - Completion criteria

### 4. Task Claiming Protocol
Each agent follows this loop:

```
LOOP:
  1. Read swarm-tasks.json
  2. Find first pending task
  3. Atomically claim task (check status, set to claimed, add owner)
  4. Execute task
  5. Mark task as done
  6. GOTO LOOP (until no pending tasks)
```

**Atomic Claiming:**
- Read current task status
- If still "pending", claim it
- If someone else claimed, try next task
- Timeout: 5 minutes per task
- If timeout exceeded, task auto-releases to pending

### 5. Progress Tracking
- Orchestrator monitors via TaskOutput
- Shows live progress: claimed/done/pending counts
- Reports which agent is working on which file
- Detects idle agents (all tasks claimed by others)

### 6. Completion
Exit when ANY of:
- All tasks marked "done"
- All agents idle (no pending tasks)
- User cancels via `/cancel-swarm`

## State Files

### `.omc/swarm-state.json`
Session-level state:

```json
{
  "session_id": "swarm-20260123-143022",
  "agent_count": 5,
  "agent_type": "executor",
  "task_description": "fix all TypeScript errors",
  "status": "active",
  "started_at": "2026-01-23T14:30:22Z",
  "agents": [
    {"id": "agent-1", "background_task_id": "task_abc123", "status": "working"},
    {"id": "agent-2", "background_task_id": "task_def456", "status": "working"},
    ...
  ]
}
```

### `.omc/state/swarm-tasks.json`
Shared task list with atomic claiming:

```json
{
  "tasks": [
    {
      "id": "task-001",
      "file": "src/utils/validation.ts",
      "description": "Fix type errors in validation helpers",
      "status": "claimed",
      "owner": "agent-1",
      "claimed_at": "2026-01-23T14:30:25Z",
      "timeout_at": "2026-01-23T14:35:25Z"
    },
    {
      "id": "task-002",
      "file": "src/components/Header.tsx",
      "description": "Fix missing prop types",
      "status": "done",
      "owner": "agent-2",
      "claimed_at": "2026-01-23T14:30:26Z",
      "completed_at": "2026-01-23T14:32:15Z"
    },
    {
      "id": "task-003",
      "file": "src/api/client.ts",
      "description": "Add return type annotations",
      "status": "pending",
      "owner": null,
      "claimed_at": null,
      "timeout_at": null
    }
  ],
  "stats": {
    "total": 15,
    "pending": 8,
    "claimed": 5,
    "done": 2
  }
}
```

### `.omc/state/swarm-claims.json`
Ownership tracking and timeout enforcement:

```json
{
  "claims": [
    {
      "task_id": "task-001",
      "agent_id": "agent-1",
      "claimed_at": "2026-01-23T14:30:25Z",
      "timeout_at": "2026-01-23T14:35:25Z",
      "heartbeat_at": "2026-01-23T14:33:10Z"
    }
  ],
  "timeouts": {
    "claim_timeout_seconds": 300,
    "heartbeat_interval_seconds": 60
  }
}
```

## Task Claiming Protocol (Detailed)

### Atomic Claim Operation

```javascript
// Pseudo-code for agent claiming
function claimTask() {
  const tasks = readJSON('.omc/state/swarm-tasks.json');

  for (const task of tasks.tasks) {
    if (task.status === 'pending') {
      // Attempt atomic claim
      const now = new Date().toISOString();
      const timeout = addMinutes(now, 5).toISOString();

      task.status = 'claimed';
      task.owner = agentId;
      task.claimed_at = now;
      task.timeout_at = timeout;

      writeJSON('.omc/state/swarm-tasks.json', tasks);
      return task;
    }
  }

  return null; // No pending tasks
}
```

### Timeout Auto-Release

Orchestrator periodically checks for timed-out claims:

```javascript
function releaseTimedOutTasks() {
  const tasks = readJSON('.omc/state/swarm-tasks.json');
  const now = new Date();

  for (const task of tasks.tasks) {
    if (task.status === 'claimed' && new Date(task.timeout_at) < now) {
      task.status = 'pending';
      task.owner = null;
      task.claimed_at = null;
      task.timeout_at = null;
      // Log timeout event
    }
  }

  writeJSON('.omc/state/swarm-tasks.json', tasks);
}
```

## Agent Instructions Template

Each spawned agent receives these instructions:

```markdown
You are agent {id} in a swarm of {N} {agent-type} agents.

**Your Task:** {task_description}

**Shared Task List:** .omc/state/swarm-tasks.json

**Your Loop:**
1. Read swarm-tasks.json
2. Find first task with status="pending"
3. Claim it atomically (set status="claimed", owner="{id}", timestamp)
4. Execute the task
5. Mark status="done", set completed_at
6. Repeat until no pending tasks

**Claiming Protocol:**
- Read file, check status="pending"
- Update status="claimed", add your ID
- Set timeout_at = now + 5 minutes
- Write file back
- If file changed between read/write, retry

**Completion:**
When no pending tasks remain, exit cleanly.

**Reporting:**
Update your progress in swarm-state.json under agents[{id}].status
```

## Constraints

- **Max Agents:** 5 (enforced by Claude Code background task limit)
- **Claim Timeout:** 5 minutes per task
- **Heartbeat:** Agents should update heartbeat every 60 seconds
- **Auto-Release:** Timed-out claims automatically released by orchestrator

## Error Handling

- **Agent Crash:** Task auto-releases after timeout
- **State Corruption:** Orchestrator validates and repairs on each cycle
- **No Pending Tasks:** Agent exits cleanly
- **All Agents Idle:** Orchestrator detects and concludes session

## Cancel Swarm

User can cancel via `/cancel-swarm`:
- Stops orchestrator monitoring
- Signals all background agents to exit
- Preserves partial progress in swarm-tasks.json
- Marks session as "cancelled" in swarm-state.json

## Use Cases

### 1. Fix All Type Errors
```
/swarm 5:executor "fix all TypeScript type errors"
```
Spawns 5 executors, each claiming and fixing individual files.

### 2. Implement UI Components
```
/swarm 3:designer "implement Material-UI styling for all components in src/components/"
```
Spawns 3 designers, each styling different component files.

### 3. Security Audit
```
/swarm 4:security-reviewer "review all API endpoints for vulnerabilities"
```
Spawns 4 security reviewers, each auditing different endpoints.

### 4. Documentation Sprint
```
/swarm 2:writer "add JSDoc comments to all exported functions"
```
Spawns 2 writers, each documenting different modules.

## Benefits

- **Parallel Execution:** N agents work simultaneously
- **Auto-Balancing:** Fast agents claim more tasks
- **Fault Tolerance:** Timeouts and auto-release prevent deadlocks
- **Progress Visibility:** Live stats on claimed/done/pending
- **Scalable:** Works for 10s to 100s of subtasks

## Implementation Notes

The orchestrator (main skill handler) is responsible for:
1. Initial task decomposition (via explore/architect)
2. Creating state files
3. Spawning N background agents
4. Monitoring progress via TaskOutput
5. Enforcing timeouts and auto-release
6. Detecting completion conditions
7. Reporting final summary

Each agent is a standard Task invocation with:
- `run_in_background: true`
- Agent-specific prompt with claiming instructions
- Reference to shared state files
