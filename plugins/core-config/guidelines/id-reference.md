# ID Reference Guide

Reference for different ID formats used across GitHub and TaskMaster.

## GitHub IDs

| Type | Format | Example |
|------|--------|---------|
| PR/Issue number | `#N` | `#1`, `#13` |
| Branch | `{type}/{N}-{slug}` | `fix/1-login-bug`, `feat/13-dark-mode` |

> Note: PRs and Issues share the same namespace in GitHub.

## TaskMaster IDs

| Type | Format | Example |
|------|--------|---------|
| Main task | `task N` | `task 1`, `task 2` |
| Subtask | `task N.M` | `task 1.1`, `task 1.2` |

## Linking GitHub and TaskMaster

- PR body: `TaskMaster: task N` or `Task Master ref: task N`
- Issue closing: `Closes #N` (GitHub Issue)

## Example

```
PR #13: "feat: Add authentication"
├── Closes #1 (GitHub Issue)
└── TaskMaster: task 1
    ├── task 1.1 (subtask)
    └── task 1.2 (subtask)
```
