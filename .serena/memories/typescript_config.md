# TypeScript Configuration

## Compiler Settings
- **Target**: ES2022
- **Module System**: NodeNext (ESM with .js extensions in imports)
- **Module Resolution**: NodeNext
- **Output**: dist/ directory
- **Source**: src/ directory
- **Strict Mode**: Enabled

## Key Settings
- Declaration files (.d.ts) generated
- Source maps enabled
- JSON module resolution enabled
- Force consistent casing in file names
- ESM interop enabled

## Build Commands
```bash
npm run build          # Compile TypeScript
npm run dev            # Watch mode
npm run prepare        # Pre-publish build
```

## Import Conventions
Since module is "NodeNext", all local imports must include .js extension:
```typescript
import { foo } from './bar.js'  // ✅ Correct
import { foo } from './bar'     // ❌ Will fail
```

## Type Checking
- LSP tools available in src/tools/lsp-tools.ts
- TypeScript diagnostics via src/tools/diagnostics/
- Directory-level type checking supported
