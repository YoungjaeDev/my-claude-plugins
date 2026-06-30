# my-claude-plugins System Architecture

## Overview

<!-- workflow-viz: system-overview -->
<!-- last-updated: 2026-05-15 22:07:58 -->

## C4 Container Diagram

```mermaid
%%{init: {'theme':'base', 'themeVariables': {
  'primaryColor':'#3B82F6',
  'primaryTextColor':'#fff',
  'primaryBorderColor':'#2563EB',
  'lineColor':'#6B7280',
  'secondaryColor':'#10B981',
  'tertiaryColor':'#F59E0B'
}}}%%
flowchart TB
    subgraph User["User"]
        U[Claude Code User]
    end

    subgraph System["my-claude-plugins"]
        subgraph Core["Core Layer"]
            CC[core-config<br/>Hooks: guidelines, format, notify]
        end

        subgraph Development["Development Tools"]
            GD[github-dev<br/>Commands: resolve-issue, PR, etc.]
            DF[docs-forge<br/>README/CHANGELOG]
        end

        subgraph Research["Research & Search"]
            CS[code-scout<br/>Resource discovery]
            DW[deepwiki<br/>GitHub repo docs]
            PS[paper-search-tools<br/>Academic papers]
        end

        subgraph AI["AI Models"]
            CO[council<br/>Multi-model deliberation]
        end

        subgraph Content["Content & Docs"]
            SL[slidev<br/>Presentations]
            TR[translator<br/>Translation]
            NO[notion<br/>Notion upload]
        end

        subgraph Tools["Dev Tools"]
            NB[notebook<br/>Jupyter editing]
            ML[ml-toolkit<br/>ML tools]
            IV[interview<br/>Requirements]
        end
    end

    subgraph External["External Services"]
        GH[(GitHub)]
        HF[(HuggingFace)]
        AR[(arXiv/PubMed)]
        NT[(Notion API)]
    end

    U --> System
    GD --> GH
    CS --> GH
    CS --> HF
    DW --> GH
    PS --> AR
    NO --> NT

    classDef coreStyle fill:#3B82F6,stroke:#2563EB,color:#fff
    classDef devStyle fill:#10B981,stroke:#059669,color:#fff
    classDef researchStyle fill:#8B5CF6,stroke:#7C3AED,color:#fff
    classDef aiStyle fill:#F59E0B,stroke:#D97706,color:#fff
    classDef contentStyle fill:#EC4899,stroke:#DB2777,color:#fff
    classDef toolStyle fill:#6366F1,stroke:#4F46E5,color:#fff

    class CC coreStyle
    class GD,DF devStyle
    class CS,DW,PS researchStyle
    class CO aiStyle
    class SL,TR,NO contentStyle
    class NB,ML,IV toolStyle
```

## Plugin Categories

| Category | Plugins | Purpose |
|----------|---------|---------|
| **Core** | core-config | Foundation: hooks, formatting, notifications |
| **Development** | github-dev, docs-forge | Code workflow |
| **Research** | code-scout, deepwiki, paper-search-tools | Information gathering |
| **AI Models** | council | External AI services |
| **Content** | slidev, translator, notion | Document creation |
| **Tools** | notebook, ml-toolkit, interview | Specialized utilities |

## Data Flow

```mermaid
sequenceDiagram
    actor User
    participant CC as core-config
    participant Plugin as Target Plugin
    participant Ext as External Service

    User->>CC: Request (auto-inject guidelines)
    CC->>Plugin: Enhanced request
    Plugin->>Ext: External API call (if needed)
    Ext-->>Plugin: Response
    Plugin-->>User: Final response
    CC->>CC: Stop hook (notify)
```

## See Also

- [Plugin Workflows](./workflows/) - Individual plugin flowcharts
- [Progress State](.claude/state/workflow-progress.json) - Current execution state
