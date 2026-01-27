---
name: edit-notebook
description: Safely edit Jupyter Notebook (.ipynb) files. Use when (1) adding/modifying/deleting cells in .ipynb files, (2) working with notebook structure, (3) any .ipynb file modification. Triggered by notebook editing requests.
---

# Notebook Editing

Edit Jupyter Notebook files using NotebookEdit tool only.

## Rules

### Tool Selection
- .ipynb = NotebookEdit only
- Edit, Write, search_replace 사용 금지

### Cell Insertion: cell_id Tracking (Required)

NotebookEdit returns inserted cell's id. Track it for sequential insertion:

```
NotebookEdit(edit_mode="insert", cell_type="code", new_source="...")
-> Returns cell_id='abc123'

NotebookEdit(edit_mode="insert", cell_id="abc123", cell_type="code", new_source="...")
-> Returns cell_id='def456'

NotebookEdit(edit_mode="insert", cell_id="def456", ...)
```

**cell_id omitted**: Cell inserted at BEGINNING -> reverse order bug

### Execution Policy
- NotebookEdit = edit only, no execution
- After adding cells: "Please run the cells in Jupyter"
- Do NOT use mcp__ide__executeCode (causes notebook state corruption)

### Post-Edit Verification
- Read first 30 lines to verify cell order
- Confirm existing outputs preserved

## edit_mode Options

| Mode | Purpose | cell_id |
|------|---------|---------|
| replace | Update existing cell | Required |
| insert | Add new cell | Recommended (omit = top insertion) |
| delete | Remove cell | Required |
