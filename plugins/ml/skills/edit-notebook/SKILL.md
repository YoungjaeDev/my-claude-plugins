---
name: edit-notebook
description: Safely edit an existing Jupyter Notebook (.ipynb) file. Use when (1) adding/modifying/deleting cells in an .ipynb file, (2) working with notebook structure. Triggered by notebook editing requests. Not for generating a new CV notebook (ml:cv-notebook).
---

# Notebook Editing

Edit `.ipynb` files through a structure-aware path, never as raw text. Three edit modes, and the user runs the cells.

## Tool selection

- **Claude Code**: `NotebookEdit` for every `.ipynb` change.
- **Codex** (no `NotebookEdit`): a short `nbformat` Python snippet that reads, mutates the cells and writes. Detect the interpreter first (`python3` → `python` → `py -3`), since pinning one name breaks either macOS or Windows.
- **nbformat install**: check with `<py> -c "import nbformat"` and install on a miss with the same interpreter, `<py> -m pip install nbformat`. nbformat is not in the stdlib, and a bare `pip` can target a different environment than the one checked.
- **Never** use `Edit`, `Write`, or `Bash(sed/cat)` on `.ipynb`.

## Cell insertion: track cell_id

`NotebookEdit` returns the inserted cell's id. Pass it to the next insert so cells land in order:

```
NotebookEdit(edit_mode="insert", cell_type="code", new_source="...")
-> Returns cell_id='abc123'

NotebookEdit(edit_mode="insert", cell_id="abc123", cell_type="code", new_source="...")
-> Returns cell_id='def456'

NotebookEdit(edit_mode="insert", cell_id="def456", ...)
```

An insert without `cell_id` lands at the beginning, so a sequence of them comes out in reverse order.

| Mode | Purpose | cell_id |
|------|---------|---------|
| replace | Update existing cell | Required |
| insert | Add new cell | Recommended (omit = top insertion) |
| delete | Remove cell | Required |

## Execution and verification

- `NotebookEdit` edits only and never executes. After adding cells, tell the user: "Please run the cells in Jupyter".
- Do NOT use `mcp__ide__executeCode`: it corrupts notebook state.
- After editing, read the first 30 lines of the notebook to confirm the cell order, and confirm that existing outputs are preserved.
