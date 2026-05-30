---
name: create-issue-labels
description: Analyze a project's tech stack and create a sensible set of GitHub issue labels (type / area / complexity) for it. Use whenever the user wants to set up, create, bootstrap, or standardize GitHub issue labels for a repository — especially on a fresh repo or when establishing a label taxonomy. Triggers on "create issue labels", "set up GitHub labels", "label scheme for this repo".
---

# Create Issue Labels

Analyze project structure and create appropriate GitHub issue labels. If the
project has a CLAUDE.md, read it at runtime and follow its guidelines.

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
