# omc (oh-my-claudecode) Workflow

<!-- workflow-viz: omc -->
<!-- last-updated: 2026-04-28 11:36:46 -->

## Overview

Multi-agent orchestration system with various execution modes.

## Mode Selection Flow

```mermaid
%%{init: {'theme':'base', 'themeVariables': {
  'primaryColor':'#F59E0B',
  'primaryTextColor':'#fff',
  'primaryBorderColor':'#D97706',
  'lineColor':'#6B7280'
}}}%%
flowchart TB
    User[User Request] --> Detect{Keyword Detection}

    Detect -->|"autopilot, build me"| AP[autopilot]
    Detect -->|"ralph, don't stop"| RL[ralph]
    Detect -->|"ulw, ultrawork"| UW[ultrawork]
    Detect -->|"ultrapilot"| UP[ultrapilot]
    Detect -->|"plan this"| PL[plan]
    Detect -->|"swarm N"| SW[swarm]
    Detect -->|"pipeline"| PP[pipeline]
    Detect -->|"eco, budget"| EC[ecomode]
    Detect -->|default| ST[Standard execution]

    AP --> Execute
    RL --> Execute
    UW --> Execute
    UP --> Execute
    PL --> Execute
    SW --> Execute
    PP --> Execute
    EC --> Execute
    ST --> Execute

    Execute[Execute with mode] --> Verify{Architect Verify}
    Verify -->|Pass| Done([Complete])
    Verify -->|Fail| Fix[Fix issues]
    Fix --> Execute

    classDef modeStyle fill:#F59E0B,stroke:#D97706,color:#fff
    classDef verifyStyle fill:#10B981,stroke:#059669,color:#fff

    class AP,RL,UW,UP,PL,SW,PP,EC,ST modeStyle
    class Verify,Done verifyStyle
```

## autopilot Flow

```mermaid
flowchart TD
    Start([Start]) --> Analyze[Analyze Requirements]
    Analyze --> Plan[Generate Plan]
    Plan --> Parallel[Parallel Agent Execution]
    Parallel --> Verify[Continuous Verification]
    Verify --> Check{All Pass?}
    Check -->|No| Fix[Self-Correction]
    Fix --> Parallel
    Check -->|Yes| Complete([Complete])

    classDef phase fill:#3B82F6,stroke:#2563EB,color:#fff
    class Analyze,Plan,Parallel,Verify,Fix phase
```

## ralph Flow (Persistence Mode)

```mermaid
flowchart TD
    Start([Start]) --> Work[Execute Task]
    Work --> Check{TODO Complete?}
    Check -->|No| Continue[Continue Working]
    Continue --> Work
    Check -->|Yes| Architect[Architect Verify]
    Architect --> Approved{Approved?}
    Approved -->|No| Work
    Approved -->|Yes| Done([Exit])

    classDef persist fill:#EC4899,stroke:#DB2777,color:#fff
    class Work,Continue,Architect persist
```

## ultrawork Flow (Parallel Execution)

```mermaid
flowchart TD
    Start([Start]) --> Decompose[Decompose into tasks]
    Decompose --> Spawn[Spawn parallel agents]

    subgraph Parallel["Parallel Execution"]
        A1[Agent 1: executor]
        A2[Agent 2: executor]
        A3[Agent 3: executor]
        AN[Agent N: ...]
    end

    Spawn --> Parallel
    Parallel --> Collect[Collect results]
    Collect --> Merge[Merge changes]
    Merge --> Done([Complete])

    classDef parallel fill:#8B5CF6,stroke:#7C3AED,color:#fff
    class A1,A2,A3,AN parallel
```

## Agent Tiers

```mermaid
flowchart LR
    subgraph LOW["LOW (Haiku)"]
        EL[explore]
        AL[architect-low]
        XL[executor-low]
        WR[writer]
    end

    subgraph MEDIUM["MEDIUM (Sonnet)"]
        EX[executor]
        RS[researcher]
        DS[designer]
        QA[qa-tester]
        BF[build-fixer]
    end

    subgraph HIGH["HIGH (Opus)"]
        AR[architect]
        XH[executor-high]
        PL[planner]
        CR[critic]
        SC[security-reviewer]
    end

    classDef low fill:#10B981,stroke:#059669,color:#fff
    classDef medium fill:#3B82F6,stroke:#2563EB,color:#fff
    classDef high fill:#F59E0B,stroke:#D97706,color:#fff

    class EL,AL,XL,WR low
    class EX,RS,DS,QA,BF medium
    class AR,XH,PL,CR,SC high
```

## State Files

| Mode | State Location |
|------|----------------|
| ralph | `.omc/state/ralph-state.json` |
| ultrapilot | `.omc/state/ultrapilot-state.json` |
| swarm | `.omc/state/swarm-tasks.db` (SQLite) |
| pipeline | `.omc/state/pipeline-{name}.json` |
