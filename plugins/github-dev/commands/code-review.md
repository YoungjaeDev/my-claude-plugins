---
description: Pre-commit code review analysis and auto-fix
---

# Code Review Analysis

## Purpose

Review and process code review feedback from external tools like CodeRabbit.

**Core workflow:** Receive external tool review results -> Analyze -> Auto-fix safe changes immediately -> Request user confirmation for items requiring judgment

## Processing Workflow

1. **Analyze review content**: Evaluate validity and impact scope of suggested changes
2. **Apply auto-fixes**: Immediately apply clear and safe fixes
3. **Provide checklist**: Request user confirmation for items requiring judgment

## Auto-fix vs Checklist Criteria

### Auto-fix Targets
- Obvious bug fixes (null checks, conditional errors, etc.)
- Coding convention violations (formatting, naming, etc.)
- Simple typos and unnecessary code removal
- Clear defects like race conditions, memory leaks

### Checklist Targets
- Architecture or design changes
- Business logic modifications (functional behavior changes)
- Performance optimizations (with trade-offs)
- Unclear or controversial review suggestions

## Input Format

Provide CodeRabbit review results as arguments:

```
Warning: Potential issue | Major

[Problem description]
[Details]
[Suggested changes: diff format]

Committable suggestion
Prompt for AI Agents
[Filename, line number, fix summary]
```

### Examples

```
Warning: Style | Minor

Variable name does not follow camelCase.

- const user_name = "John";
+ const userName = "John";
```

```
Warning: Logic | Critical

State is missing from useEffect dependency array.

- useEffect(() => { fetch(url); }, []);
+ useEffect(() => { fetch(url); }, [url]);
```

## Guidelines

- **Critical review**: Validate review suggestions rather than accepting blindly
- **Project guidelines first**: Follow `@CLAUDE.md` conventions and architecture principles
- **Safety first**: Use `AskUserQuestion` tool to confirm with user when uncertain
- **Interactive confirmation**: Use `AskUserQuestion` tool to provide options for items requiring judgment
- **Commit after completion**: Commit with appropriate message and push after all fixes are complete

