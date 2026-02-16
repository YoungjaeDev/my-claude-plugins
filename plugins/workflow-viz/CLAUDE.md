# Workflow Visualization Plugin

System-wide workflow visualization with Mermaid diagrams and ASCII progress tracking.

## Features

| Feature | Description |
|---------|-------------|
| System Architecture | C4 Container diagram of all plugins |
| Plugin Workflows | Flowchart for each plugin's workflow |
| Progress Tracking | Auto-update on task completion via hook |
| ASCII Visualization | On-demand ASCII progress display |

## Usage

### View Progress (ASCII)
```
/workflow-viz:show-progress
```

### Diagrams Location
- `docs/architecture/system-overview.md` - C4 Container diagram
- `docs/architecture/workflows/` - Per-plugin flowcharts

## State File
`.omc/state/workflow-progress.json` - Current progress state
