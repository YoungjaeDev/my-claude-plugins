---
description: Request Codex review with Claude cross-check
---

# Codex Review

Request code review from Codex MCP, cross-checked by Claude for consensus.

**Core Principle:** Codex has limited context/tools, so Claude validates all feedback. Disagreements trigger re-queries (max 3 rounds) until consensus.

---

## Arguments

`$ARGUMENTS` parsing:

| Input | Mode | Action |
|-------|------|--------|
| (none) | General | AskUserQuestion for review type |
| `'text in quotes'` | Directed | Review in specified direction |
| `path/to/file` | File-focused | Review that file + dependencies |

**Detection:** If argument is an existing file/directory path, use File-focused mode. Otherwise, treat as Directed review text.

---

## Context Gathering

### Auto-collect

| Item | Source | Priority |
|------|--------|----------|
| Files from conversation | Read/Edit/Write history | Required |
| Git changes | `git diff`, `git status` | Required |
| CLAUDE.md | Project root | Required |
| Directory structure | `tree -L 2 -I 'node_modules\|__pycache__\|.git'` | Recommended |
| Recent commits | `git log --oneline -10` | Optional |

### Exclude (sensitive data)

**Files:** `.env*`, `secrets*`, `*credentials*`, `*token*`, `*.pem`, `*.key`
**Patterns:** `sk-[a-zA-Z0-9]+`, `AKIA[A-Z0-9]+`, `Bearer [...]`, `password[:=]...`
**Dirs:** `node_modules/`, `__pycache__/`, `.git/`, binaries, media files

### Size Management

- Prefer `git diff` over full file content
- Large files (>500 lines): include only relevant sections (50 lines around changes)
- Max 5 files per prompt
- On timeout: reduce CLAUDE.md to key sections, use `tree -L 1`

---

## Execution

### 1. Invoke Codex

```
mcp__codex__codex({
  prompt: [REVIEW_PROMPT],
  sandbox: "read-only",
  workingDirectory: [PROJECT_ROOT]
})
```

**Prompt template:**
```
## Role
You are a code review expert reviewing work in progress.

## Review Type
[Implementation direction / Code quality / Architecture]

## Project Context
### CLAUDE.md
[Project guidelines]

### Work Guidelines
Read and follow: .claude/guidelines/work-guidelines.md
If .claude/rules/ exists, also read relevant rule files for module-specific guidance.
(Use your file access to read these files directly)

### Directory Structure
[tree output]

## Review Target
### Current Work Summary
[Description of ongoing work]

### Changes
[git diff or file list]

### File Contents
[Key files with line numbers]

## Output Format (required)

### Strengths
- [item]: [description] (file:line)

### Suggestions
| Item | Location | Issue | Solution |
|------|----------|-------|----------|

### Risks
- [severity]: [description] (file:line)

### Questions
- [question]

### Summary
[1-2 sentence conclusion]

### Beyond the Question (Evidence-Based)
If you identify improvements beyond the direct question:
- Alternative approaches FOUND IN this codebase (with file:line)
- Architectural patterns ALREADY USED that could apply
- Potential optimizations BASED ON actual code analysis

DO NOT suggest generic best practices without codebase evidence.
```

### 2. Parse Response

Extract sections: Strengths, Suggestions, Risks, Questions, Summary

### 3. Claude Cross-check

Validate Codex feedback against:
- Project context (did Codex understand the codebase?)
- CLAUDE.md compliance
- Technical accuracy (is the suggestion implementable?)
- Existing patterns (does it match current codebase style?)
- Already-resolved issues (is Codex pointing out something already fixed?)

Identify any incorrect claims with evidence.

### 4. Resolve Disagreements

If discrepancies found, invoke Codex again with context:

```
## Previous Review Summary
[Codex 1st response key points]

## Claude Cross-check Results
[Discrepancies with evidence]

## Re-review Request
Reconsider only these items:
1. [item 1]
2. [item 2]

Provide corrections in the same output format.
```

**Exit conditions:**
- Consensus reached
- 3 rounds completed
- Codex accepts Claude's evidence

### 5. Final Output

```markdown
## Codex Review Result (Codex + Claude Consensus)

### Process
- Review type: [type]
- Rounds: [N]
- Status: [Full consensus / Partial / Claude judgment]

### Valid Feedback
| Item | Description | Location | Source |
|------|-------------|----------|--------|

### Suggestions
| Item | Issue | Solution | Source |
|------|-------|----------|--------|

### Risks
| Severity | Description | Location |
|----------|-------------|----------|

### Corrections (Codex errors)
| Codex Claim | Actual | Evidence |
|-------------|--------|----------|

### Action Items
[Recommended next steps - use AskUserQuestion if choices needed]

### Summary
[Final conclusion]
```

---

## Error Handling

| Error | Response |
|-------|----------|
| No context | "No reviewable content found. Specify review direction." |
| Codex MCP failure | "Codex MCP invocation failed. Check MCP server status." |
| Timeout | "Response timeout. Reducing prompt size and retrying." |

---

## Guidelines

- Respond in user's language
- No emojis in code or documentation
- **Never assume unclear context - use AskUserQuestion**
- Code modifications require user confirmation
- Follow `@CLAUDE.md` project conventions

---

## Example

```bash
# General review
/ask-codex

# Directed review
/ask-codex 'Review error handling approach'

# File-focused review
/ask-codex src/components/auth/login.tsx
```
