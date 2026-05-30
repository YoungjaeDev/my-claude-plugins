# Project-Tracking Diagram Spec (canon)

Canonical diagram formats for the github-dev project-tracking system. This is the
single source of truth — the `update-progress`, `decompose-issue`, and
`post-merge` skills all generate diagrams per this spec instead of duplicating it.

All diagram types are built from the state file's `architecture.mermaidSource`
(the 10-20 node project workflow captured during decompose-issue) plus per-issue
`status`, `dependsOn`, and `architectureNode` data.

## Output format by medium

| Output Medium | Format | Reason |
|---------------|--------|--------|
| GitHub Issue/PR body | Mermaid (Type M-2) | GitHub markdown renderer supports it |
| Milestone description | Markdown Table | GitHub milestones don't render Mermaid |
| Terminal (session output) | ASCII (Type M-1) | Terminal can't render Mermaid |
| State file (storage) | Mermaid source | Raw data for generating Issue/PR diagrams |

## Diagram Generation Algorithm

1. Parse `architecture.mermaidSource` from the state file
2. For each node ID in `architecture.scopeNodes`, append `:::scope` classDef
3. For each issue, determine status class (`done`/`active`/`pending`)
4. Generate task-list nodes grouped by module, connected by `dependsOn` arrows
5. Apply classDef definitions at the end

Status mapping:
- `[v]` / `done` — closed issues
- `[>]` / `active` — issues with a PR or in progress
- `[ ]` / `pending` — open issues

## Type M-1: Milestone Overview (Terminal, ASCII)

Renders the full project workflow with scope highlighting and a task summary as
ASCII art (terminal cannot render Mermaid).

```
=== Project Workflow ===
[Bot Loop] --> [scanChatList] --> <new request?>
                                    |yes --> [Pipeline] *
                                    |no  --> [Push System] *
                                 (* = milestone scope)

=== <milestoneName> Tasks ===
 [v] #12 Push targets
 [>] #13 Time window              (depends: #12)
 [ ] #14 Template engine          (depends: #13)

Progress: 1/3 (33%)
```

**How to build Type M-1:**
1. Parse `architecture.mermaidSource` and convert to an ASCII tree layout
2. For each node ID in `scopeNodes`: append a `*` marker to that node
3. Add a task-list section with all issues, applying the `[v]`/`[>]`/`[ ]` status markers
4. Add `dependsOn` info: if issue #13 has `dependsOn: [12]`, show `(depends: #12)`
5. Show a progress summary line: `Progress: X/Y (ZZ%)`

## Type M-2: Issue Context View (Issue/PR body, Mermaid)

Shows the full workflow with "this issue" highlighted, plus its dependencies.

````markdown
```mermaid
<mermaidSource from state file, with this issue's architectureNode highlighted>

    %% This issue's context
    subgraph context ["#13 Time window filter"]
        T13["#13 Time window filter<br/>-- this issue"]:::here
    end

    subgraph deps ["Dependencies"]
        T12["#12 Push targets"]:::done
    end

    subgraph next ["Blocked by this"]
        T14["#14 Template engine"]:::pending
    end

    T12 --> T13
    T13 --> T14
    F --- context

    classDef scope fill:#ddf4ff,stroke:#54aeff,stroke-width:3px
    classDef here fill:#1f6feb,color:#fff,stroke:#1f6feb,stroke-width:3px
    classDef done fill:#2da44e,color:#fff,stroke:#2da44e
    classDef active fill:#1f6feb,color:#fff,stroke:#1f6feb
    classDef pending fill:#6e7781,color:#fff,stroke:#6e7781
```

**Milestone: <milestoneName> -- ZZ% (X/Y)**
````

**How to build Type M-2:**
1. Copy `architecture.mermaidSource` verbatim
2. Highlight the current issue's `architectureNode` with `:::scope`
3. Create a `context` subgraph with just this issue node using `:::here`
4. Create a `deps` subgraph with issues this one `dependsOn`
5. Create a `next` subgraph with issues that have `dependsOn` pointing to this issue
6. Add dependency arrows between issue nodes
7. Connect the context subgraph to its `architectureNode` with `---`

## Mermaid Rules

- Colors: 4 classDefs (`scope=#ddf4ff`, `done=#2da44e`, `active=#1f6feb`, `pending=#6e7781`) + `here` (thick active)
- Line breaks: `<br/>` only (`\n` forbidden in node text)
- Node text: wrap in `"` double quotes
- Max 20 nodes per diagram (architecture + tasks combined)
- subgraph ID: lowercase English (`subgraph tasks ["Display Name"]`)
- The `mermaidSource` is never modified — classDef and subgraphs are appended after it

## Milestone Format: Markdown Table (Milestone description)

GitHub milestone descriptions do not render Mermaid. Use this Markdown Table
format for all milestone descriptions.

```markdown
## <milestoneName> Progress (auto-updated: YYYY-MM-DD)

| Status | Issue | Title | Depends On |
|--------|-------|-------|------------|
| [v] | #12 | Push targets | - |
| [>] | #13 | Time window | #12 |
| [ ] | #14 | Template engine | #13 |

**Progress: X/Y (ZZ%)**
```

## Body markers

`<!-- project-tracking-start -->` / `<!-- project-tracking-end -->` — only the
section between markers is replaced, preserving existing issue/PR body content.
