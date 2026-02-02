# MCP Server Integration

## Overview
The project integrates with Model Context Protocol (MCP) servers to extend Claude Code capabilities.

## Key Files
- **src/mcp/servers.ts** - getDefaultMcpServers() function
- **src/mcp/** - MCP server configurations

## Supported MCP Servers
Default servers configured:
- Context7 - Code context management
- Exa - Search capabilities
- GitHub - Repository integration
- Filesystem - File operations

## Integration Points
1. MCP servers defined in getDefaultMcpServers()
2. Skills can leverage MCP tools
3. Config loader (src/config/loader.ts) handles MCP setup

## Setup Skill
- **skills/mcp-setup/** - User-facing MCP configuration skill
- Trigger: "setup mcp", "configure mcp"
- Auto-invoked when MCP patterns detected
