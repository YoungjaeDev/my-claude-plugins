# github-dev Workflow

<!-- workflow-viz: github-dev -->
<!-- last-updated: 2026-04-28 11:36:46 -->

## Overview

GitHub workflow automation with 9 commands.

## Command Flowchart

```mermaid
%%{init: {'theme':'base', 'themeVariables': {
  'primaryColor':'#10B981',
  'primaryTextColor':'#fff',
  'primaryBorderColor':'#059669',
  'lineColor':'#6B7280'
}}}%%
flowchart TB
    subgraph GithubDev["github-dev Commands"]
        direction TB

        subgraph IssueFlow["Issue Resolution Flow"]
            RI[resolve-issue]
            DI[decompose-issue]
            CIL[create-issue-label]
        end

        subgraph PRFlow["PR Flow"]
            CAP[commit-and-push]
            CR[code-review]
            PM[post-merge]
        end

        subgraph WorktreeFlow["Worktree Flow"]
            MW[merge-worktree]
        end
    end

    Issue[GitHub Issue] --> DI
    DI --> RI
    RI -->|"PR path"| CAP
    CAP --> CR
    CR --> PM
    RI -->|"worktree path"| MW

    classDef issueStyle fill:#10B981,stroke:#059669,color:#fff
    classDef worktreeStyle fill:#3B82F6,stroke:#2563EB,color:#fff
    classDef commitStyle fill:#F59E0B,stroke:#D97706,color:#fff

    class RI,DI,CIL issueStyle
    class MW worktreeStyle
    class CAP,CR,PM commitStyle
```

## resolve-issue Detail (12 Phases)

```mermaid
flowchart TD
    Start([Start]) --> P1[1. Analyze Issue]
    P1 --> P2[2. Verify Plan Alignment]
    P2 --> P3[3. Create Branch]
    P3 --> P4[4. Update GitHub Project]
    P4 --> P5[5. Analyze Codebase]
    P5 --> P6[6. Plan Resolution]
    P6 --> P7[7. Implement]
    P7 --> P8[8. Write Tests]
    P8 --> P9[9. Validate]
    P9 --> P9a{All Pass?}
    P9a -->|No| P7
    P9a -->|Yes| P10[9.5 Verification Gates]
    P10 --> P11[9.6 Two-Stage Review]
    P11 --> P11a{Approved?}
    P11a -->|No| P7
    P11a -->|Yes| P12[10. Create PR]
    P12 --> P13[11. Update Checkboxes]
    P13 --> P14[12. Cleanup/Archive]
    P14 --> End([End])

    classDef analyzeStyle fill:#8B5CF6,stroke:#7C3AED,color:#fff
    classDef planStyle fill:#3B82F6,stroke:#2563EB,color:#fff
    classDef implStyle fill:#10B981,stroke:#059669,color:#fff
    classDef testStyle fill:#F59E0B,stroke:#D97706,color:#fff
    classDef reviewStyle fill:#EC4899,stroke:#DB2777,color:#fff
    classDef prStyle fill:#06B6D4,stroke:#0891B2,color:#fff

    class P1,P2 analyzeStyle
    class P3,P4,P5,P6 planStyle
    class P7 implStyle
    class P8,P9,P9a,P10 testStyle
    class P11,P11a reviewStyle
    class P12,P13,P14 prStyle
```

## commit-and-push Detail (3 Phases)

```mermaid
flowchart LR
    Start([Start]) --> A[1. Analyze Changes]
    A --> B[2. Commit]
    B --> C[3. Push]
    C --> End([End])

    classDef phase fill:#10B981,stroke:#059669,color:#fff
    class A,B,C phase
```

## State File Schema

Location: `.omc/state/github-dev-{issue}.json`

```json
{
  "sessionId": "github-dev-123-2026-02-12T10:00:00Z",
  "command": "resolve-issue",
  "issueNumber": 123,
  "phase": "implement",
  "checkpoints": [
    { "phase": "analyze", "status": "complete" },
    { "phase": "implement", "status": "in_progress" }
  ]
}
```

## Progress Indicators

| Symbol | Status |
|--------|--------|
| ✓ | Phase completed |
| ▶ | Currently executing |
| ○ | Not started |
| ✗ | Failed (needs retry) |
