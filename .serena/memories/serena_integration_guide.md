# Serena Integration Guide

## Overview
Serena MCP server is configured for the oh-my-claudecode TypeScript project.

## Configuration Status
- **Language Server**: TypeScript (tsserver)
- **Encoding**: UTF-8
- **Ignored Paths**: dist/, node_modules/, .omc/state/, .omc/logs/, .claude/
- **Read-only Mode**: Disabled

## Available Memories
Comprehensive project documentation available:

1. **project_overview.md** - Purpose, features, tech stack, version info
2. **codebase_structure.md** - Directory layout, key files, entry points
3. **code_style.md** - Coding conventions and patterns
4. **typescript_config.md** - TS compiler settings, build commands, import conventions
5. **agent_system.md** - Agent tier system, 28+ agents, usage patterns
6. **skill_system.md** - 31+ skills, triggers, execution modes
7. **state_management.md** - Boulder state, mode states, notepad system
8. **mcp_integration.md** - MCP servers, integration points
9. **task_completion.md** - Completion criteria and best practices
10. **suggested_commands.md** - Common development commands

## Serena Capabilities

### Code Navigation
- `find_symbol` - Search for symbols globally or locally
- `find_referencing_symbols` - Find references to a symbol
- `get_symbols_overview` - Get file-level symbol overview

### Code Editing
- `create_text_file` - Create/overwrite files
- `insert_at_line` - Insert at specific line
- `replace_lines` - Replace line ranges
- `delete_lines` - Delete line ranges
- `insert_before_symbol` / `insert_after_symbol` - Symbol-aware insertion
- `replace_symbol_body` - Replace symbol definition

### Project Operations
- `search_for_pattern` - Pattern search across project
- `list_dir` - Directory listing with recursion
- `read_file` - Read project files
- `execute_shell_command` - Run shell commands

### Memory System
- `write_memory` - Save project-specific memories
- `read_memory` - Read saved memories
- `list_memories` - List all memories
- `delete_memory` - Remove memories

### Language Server
- TypeScript language server automatically started
- Restart with `restart_language_server` if needed
- Symbol navigation, type information, references

## Integration with OMC

Serena can enhance OMC workflows:

1. **Symbol-level editing** - Edit TypeScript symbols precisely
2. **Cross-reference navigation** - Find all usages of functions/types
3. **Memory persistence** - Store project-specific knowledge
4. **Pattern search** - Find code patterns across codebase
5. **Language Server support** - Type-aware refactoring

## Quick Start

```bash
# Search for a symbol
find_symbol: "createSisyphusSession"

# Get file structure
get_symbols_overview: "src/index.ts"

# Search patterns
search_for_pattern: "Task\\(subagent_type"

# Read memories
read_memory: "codebase_structure"

# Execute commands
execute_shell_command: "npm run build"
```

## Best Practices

1. **Use memories** - Read existing memories before asking questions
2. **Symbol-aware editing** - Prefer symbol-based edits over line-based
3. **Language Server** - Leverage TS language server for type safety
4. **Pattern search** - Use regex patterns for complex searches
5. **Memory updates** - Update memories when learning new patterns
