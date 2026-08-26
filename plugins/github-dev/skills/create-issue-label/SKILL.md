---
name: create-issue-label
description: Analyze the project's tech stack and structure, then create a standardized set of GitHub issue labels via gh label create. Use when the user types /github-dev:create-issue-label, says "create issue labels", or sets up a label taxonomy for a repo. Examines package.json, README, and code layout to classify labels by type, area, and complexity, then creates them with gh. Follows the project CLAUDE.md.
allowed-tools: Read Bash Glob Grep
---

## Create Issue Labels

Analyze project structure and create appropriate GitHub issue labels. Follow project guidelines in `@CLAUDE.md`.

## Workflow

1. Analyze project: Examine `package.json`, `README.md`, and code structure
2. Identify tech stack: Detect frameworks, libraries, and tools in use
3. Classify project areas: Frontend, backend, API, infrastructure, etc.
4. Create labels: Generate essential labels based on type, area, and complexity

## Label Guidelines

**The following are examples; adjust based on your project needs.**

### Type
- `type: feature`, `type: bug`, `type: enhancement`, `type: documentation`, `type: refactor`

### Area
- `frontend` `backend` `api` `devops`, `crawling` `ai` `database` `infrastructure`

### Complexity
- `complexity: easy` `complexity: medium` `complexity: hard`

## Example Commands

```bash
gh label create "type: feature" --color "0e8a16" --description "New feature addition"
gh label create "frontend" --color "1d76db" --description "Frontend-related work"
gh label create "complexity: easy" --color "7057ff" --description "Simple task"
```
