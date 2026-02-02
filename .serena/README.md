# Serena MCP Server Configuration

This directory contains Serena MCP server configuration for the oh-my-claudecode project.

## Structure

```
.serena/
├── project.yml          # Main configuration
├── memories/            # Project-specific knowledge base
│   ├── project_overview.md
│   ├── codebase_structure.md
│   ├── code_style.md
│   ├── typescript_config.md
│   ├── agent_system.md
│   ├── skill_system.md
│   ├── state_management.md
│   ├── mcp_integration.md
│   ├── task_completion.md
│   ├── suggested_commands.md
│   └── serena_integration_guide.md
├── cache/               # Language server cache
│   └── typescript/
└── README.md           # This file
```

## Configuration Highlights

- **Language**: TypeScript with tsserver
- **Ignored paths**: dist/, node_modules/, .omc/state/, .omc/logs/
- **Memory files**: 11 comprehensive documentation files
- **Initial prompt**: Architecture overview automatically loaded

## Usage

Serena provides:
- Symbol-level code navigation
- TypeScript language server integration
- Project-specific memory system
- Pattern-based code search
- File and directory operations

See `memories/serena_integration_guide.md` for detailed usage.

## Initialization

Serena was initialized for this TypeScript project with:
1. TypeScript language server configuration
2. Project-specific ignore patterns
3. Comprehensive memory documentation
4. Initial prompt with key architecture info

No additional setup needed - Serena is ready to use!
