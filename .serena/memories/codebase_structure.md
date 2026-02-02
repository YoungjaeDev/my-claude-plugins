# Codebase Structure

## Root Directory
```
oh-my-claudecode/
├── src/                 # TypeScript source code
├── agents/              # Agent definition markdown files (28+)
├── skills/              # Skill definition directories (31+)
├── commands/            # Command expansion definitions
├── hooks/               # Hook implementations
├── scripts/             # Utility scripts
├── bridge/              # Bridge utilities
├── docs/                # Documentation
├── templates/           # Template files
├── examples/            # Example configurations
├── .github/             # GitHub workflows
└── dist/                # Compiled output (generated)
```

## Source Code (src/)
```
src/
├── index.ts             # Main entry, exports createSisyphusSession()
├── agents/              # Agent system
│   ├── definitions.ts   # Agent definitions builder
│   └── index.ts         # Agent exports
├── cli/                 # CLI implementation
│   └── index.js         # CLI entry point
├── commands/            # Command expansion
│   └── index.ts         # expandCommand, getAllCommands
├── config/              # Configuration
│   └── loader.ts        # loadConfig, findContextFiles
├── features/            # Core features
│   ├── magic-keywords.ts    # Magic keyword processing
│   ├── background-tasks.ts  # Background task management
│   ├── continuation-enforcement.ts
│   ├── auto-update.ts
│   ├── boulder-state.ts     # Session state persistence
│   └── context-injector.ts  # Context injection
├── hooks/               # Hook system
├── hud/                 # HUD statusline
├── installer/           # Plugin installer
├── lib/                 # Libraries
├── mcp/                 # MCP server configs
│   └── servers.ts       # getDefaultMcpServers
├── platform/            # Platform-specific
├── shared/              # Shared types
│   └── types.ts         # PluginConfig, SessionState, etc.
├── tools/               # Custom tools
│   └── index.ts         # lspTools, astTools
└── utils/               # Utilities
```

## Agents Directory
Each agent is a markdown file with prompt instructions:
- `architect.md`, `architect-low.md`, `architect-medium.md`
- `researcher.md`, `researcher-low.md`
- `scientist.md`, `scientist-low.md`, `scientist-high.md`
- `designer.md`, `designer-low.md`, `designer-high.md`
- `executor.md`, `executor-low.md`, `executor-high.md`
- `explore.md`, `explore-medium.md`
- And more...

## Skills Directory
Each skill is a directory containing:
- `SKILL.md` - Main skill prompt
- `trigger.txt` (optional) - Trigger patterns
- Additional resources as needed

Key skills:
- `ralph/` - Persistence mode
- `ultrawork/` - Parallel execution
- `planner/` - Planning mode
- `research/` - Research orchestration
- `git-master/` - Git operations
- `autopilot/` - Autonomous execution

## Key Entry Points
1. **CLI**: `dist/cli/index.js` (bin: oh-my-claudecode)
2. **API**: `dist/index.js` (createSisyphusSession)
3. **Plugin**: Installed via Claude Code plugin system
