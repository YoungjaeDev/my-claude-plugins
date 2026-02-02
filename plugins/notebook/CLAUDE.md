# Notebook Plugin

Safe Jupyter Notebook (.ipynb) editing.

## Skill

| Skill | Description |
|-------|-------------|
| `edit-notebook` | Guidelines for .ipynb file manipulation |

## Key Rules

1. **NotebookEdit tool only** - Never use text editing tools on .ipynb
2. **Preserve outputs** - Don't accidentally clear cell outputs
3. **Cell order matters** - Verify order after modifications
4. **User executes** - Add/edit cells, user runs in Jupyter

## Usage

The skill auto-activates when working with .ipynb files.

## Common Operations

| Operation | Approach |
|-----------|----------|
| Add cell | `NotebookEdit` with `edit_mode=insert` |
| Modify cell | `NotebookEdit` with `edit_mode=replace` |
| Delete cell | `NotebookEdit` with `edit_mode=delete` |
| Read notebook | `Read` tool (renders all cells) |

## Best Practices

- Read notebook first to understand structure
- Use `cell_id` for precise targeting
- Specify `cell_type` (code/markdown) when inserting
- Verify cell order after complex edits
