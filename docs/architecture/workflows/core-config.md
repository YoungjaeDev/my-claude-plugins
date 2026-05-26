# core-config Workflow

<!-- workflow-viz: core-config -->
<!-- last-updated: 2026-05-15 22:07:58 -->

## Overview

Core development configuration with lifecycle hooks.

## Hook Event Flow

```mermaid
%%{init: {'theme':'base', 'themeVariables': {
  'primaryColor':'#3B82F6',
  'primaryTextColor':'#fff',
  'primaryBorderColor':'#2563EB',
  'lineColor':'#6B7280'
}}}%%
flowchart TB
    subgraph Lifecycle["Claude Code Lifecycle"]
        direction TB

        subgraph Start["Session Start"]
            US[UserPromptSubmit]
        end

        subgraph During["During Session"]
            PT[PostToolUse]
        end

        subgraph End["Session End"]
            ST[Stop]
            NT[Notification]
        end
    end

    subgraph Hooks["core-config Hooks"]
        IG[inject-guidelines.py<br/>Auto-inject work guidelines]
        AF[auto-format-python.py<br/>Format Python with ruff]
        NO[notify_osc.py<br/>Terminal notifications]
    end

    US --> IG
    PT -->|Write/Edit .py| AF
    ST --> NO
    NT --> NO

    classDef eventStyle fill:#6B7280,stroke:#4B5563,color:#fff
    classDef hookStyle fill:#3B82F6,stroke:#2563EB,color:#fff

    class US,PT,ST,NT eventStyle
    class IG,AF,NO hookStyle
```

## inject-guidelines Flow

```mermaid
flowchart LR
    Start([UserPromptSubmit]) --> Read[Read work-guidelines.md]
    Read --> Inject[Wrap in system-reminder]
    Inject --> Output[Return to Claude]
    Output --> End([Continue])

    classDef step fill:#10B981,stroke:#059669,color:#fff
    class Read,Inject,Output step
```

## auto-format-python Flow

```mermaid
flowchart TD
    Start([PostToolUse]) --> Check{Is .py file?}
    Check -->|No| Skip[Skip formatting]
    Check -->|Yes| Format[Run ruff format]
    Format --> Result{Success?}
    Result -->|Yes| Done[Formatted]
    Result -->|No| Warn[Log warning]
    Skip --> End([Continue])
    Done --> End
    Warn --> End

    classDef decision fill:#F59E0B,stroke:#D97706,color:#fff
    classDef action fill:#10B981,stroke:#059669,color:#fff

    class Check,Result decision
    class Format,Done,Warn action
```

## notify_osc Flow

```mermaid
flowchart TD
    Start([Stop/Notification]) --> Detect{Platform?}
    Detect -->|Unix| OSC[OSC 777 escape code]
    Detect -->|Windows| Toast[BurntToast PowerShell]
    OSC --> Send[Send to terminal]
    Toast --> Send
    Send --> End([Done])

    classDef platform fill:#8B5CF6,stroke:#7C3AED,color:#fff
    classDef action fill:#10B981,stroke:#059669,color:#fff

    class Detect platform
    class OSC,Toast,Send action
```

## Hook Configuration

```json
{
  "hooks": {
    "UserPromptSubmit": [{ "command": "inject-guidelines.py" }],
    "PostToolUse": [{ "matcher": "Write|Edit", "command": "auto-format-python.py" }],
    "Stop": [{ "command": "notify_osc.py" }],
    "Notification": [{ "command": "notify_osc.py" }]
  }
}
```
