# Skill System Architecture

## Overview
Skills are specialized behaviors activated by keywords or patterns. Each skill is a directory containing prompt files.

## Skill Structure
Location: **skills/** directory (31+ skills)

Each skill directory contains:
- **SKILL.md** - Main prompt/instructions
- **trigger.txt** (optional) - Auto-trigger patterns
- Additional resources as needed

## Key Skills

### Execution Modes
| Skill | Trigger | Purpose |
|-------|---------|---------|
| autopilot | "autopilot", "build me" | Full autonomous execution |
| ralph | "don't stop", "ralph" | Persistence until complete |
| ultrawork | "ulw", "ultrawork" | Maximum parallelism |
| ecomode | "eco", "efficient" | Token-efficient parallel |
| ultrapilot | "ultrapilot", "parallel build" | Parallel autopilot |

### Planning & Analysis
| Skill | Trigger | Purpose |
|-------|---------|---------|
| planner | "plan this", broad requests | Planning with interview |
| plan | "plan" keyword | Quick planning |
| ralplan | "ralplan" | Iterative planning consensus |
| analyze | "analyze", "debug" | Deep investigation |
| deepsearch | "search", "find" | Thorough codebase search |

### Specialized Skills
| Skill | Trigger | Purpose |
|-------|---------|---------|
| frontend-ui-ux | UI context (silent) | Design sensibility |
| git-master | Git context (silent) | Git expertise |
| ultraqa | "test", "QA" | QA cycling |
| tdd | "tdd", "test first" | TDD enforcement |
| research | "research", "analyze data" | Parallel scientist orchestration |

### Orchestration
| Skill | Trigger | Purpose |
|-------|---------|---------|
| swarm | "swarm N agents" | Coordinated task claiming |
| pipeline | "pipeline", "chain" | Sequential agent chaining |
| cancel | "stop", "cancel" | Unified cancellation |

## Skill Loading
Skills are automatically discovered and loaded from the skills/ directory at runtime.

## Auto-Invocation
Skills with trigger.txt are automatically invoked when patterns match user input.
