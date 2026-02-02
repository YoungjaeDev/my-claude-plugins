# Agent System Architecture

## Agent Definitions
Location: **agents/** directory (28+ agents)

### Tier System
Agents organized by complexity tier:
- **LOW** (Haiku): Quick tasks, simple lookups
- **MEDIUM** (Sonnet): Standard work, feature implementation
- **HIGH** (Opus): Complex reasoning, architecture

### Key Agents
| Agent | Tier | Purpose |
|-------|------|---------|
| architect | LOW/MED/HIGH | Analysis, debugging, architecture |
| executor | LOW/MED/HIGH | Code changes, implementation |
| explore | LOW/MED/HIGH | Codebase search, file finding |
| designer | LOW/MED/HIGH | UI/UX, frontend components |
| researcher | LOW/MED | Research, documentation |
| scientist | LOW/MED/HIGH | Data analysis, statistics |
| writer | LOW | Documentation, comments |
| planner | HIGH | Strategic planning |
| critic | HIGH | Review, critique |
| qa-tester | MED/HIGH | Testing, QA |

## Agent File Format
Each agent is a markdown file with prompt instructions:
- **agents/architect.md** - Main prompt
- **agents/architect-low.md** - Haiku variant
- **agents/architect-medium.md** - Sonnet variant

## Agent Loading
- **src/agents/definitions.ts** - buildAgentDefinitions()
- Agents loaded dynamically from markdown files
- Prefix: `oh-my-claudecode:` when invoking via Task tool

## Usage Pattern
```typescript
Task(subagent_type="oh-my-claudecode:executor",
     model="sonnet",
     prompt="Implement feature X...")
```
