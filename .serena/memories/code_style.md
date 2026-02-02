# Code Style and Conventions

## TypeScript Configuration
- **Target**: ES2022
- **Module**: NodeNext (ESM)
- **Strict Mode**: Enabled
- **Declaration Files**: Generated (.d.ts, .d.ts.map)
- **Source Maps**: Enabled

## Naming Conventions
- **Files**: kebab-case (e.g., `magic-keywords.ts`, `background-tasks.ts`)
- **Classes/Interfaces**: PascalCase (e.g., `BackgroundTaskManager`, `PluginConfig`)
- **Functions**: camelCase (e.g., `createSisyphusSession`, `detectMagicKeywords`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `BOULDER_DIR`, `DEFAULT_MAX_BACKGROUND_TASKS`)
- **Type Parameters**: PascalCase with descriptive names

## ESLint Rules
- `@typescript-eslint/no-unused-vars`: warn (prefix with `_` to ignore)
- `@typescript-eslint/no-explicit-any`: off (flexibility for agent system)
- `@typescript-eslint/no-require-imports`: off (dynamic loading)
- `no-useless-escape`: off (template strings)
- `prefer-const`: warn
- `no-control-regex`: off (ANSI escape codes in terminal output)

## Code Patterns
- **Exports**: Use named exports, re-export from index.ts files
- **Types**: Define types in shared/types.ts or adjacent to implementation
- **Async/Await**: Prefer async/await over Promises
- **Error Handling**: Use try-catch with meaningful error messages
- **Comments**: JSDoc for public APIs, inline comments for complex logic

## File Structure
```
src/
├── index.ts           # Main entry point with re-exports
├── agents/            # Agent definitions and configurations
├── cli/               # CLI implementation
├── commands/          # Command expansion utilities
├── config/            # Configuration loading
├── features/          # Feature implementations (magic-keywords, etc.)
├── hooks/             # Hook implementations
├── hud/               # HUD statusline
├── installer/         # Plugin installer
├── lib/               # Library utilities
├── mcp/               # MCP server configurations
├── platform/          # Platform-specific code
├── shared/            # Shared types and utilities
├── tools/             # Custom tools (LSP, AST)
├── utils/             # Utility functions
└── __tests__/         # Test files
```

## Import Order (recommended)
1. Node.js built-ins
2. External packages
3. Internal modules (relative imports)
4. Types (type-only imports)
