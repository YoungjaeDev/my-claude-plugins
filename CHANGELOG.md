# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.11.1] - 2026-01-13

### Fixed
- **Agent Frontmatter** - Added missing `name` and `description` fields to all agent YAML frontmatter
  - All 10 agents (oracle, librarian, explore, frontend-engineer, document-writer, multimodal-looker, momus, metis, sisyphus-junior, prometheus) now have required frontmatter per Claude Code sub-agent spec
  - Fixes issue #33: Agents failed to load due to missing required fields

- **Windows Support** - Fixed hook scripts and cross-platform compatibility (closes #30)
  - `hooks.json` now uses Node.js scripts (.mjs) instead of Bash for cross-platform support
  - Created Node.js versions of all hook scripts: `keyword-detector.mjs`, `pre-tool-enforcer.mjs`, `post-tool-verifier.mjs`, `persistent-mode.mjs`
  - Fixed `which` command usage to use `where` on Windows in `plugin-patterns/index.ts` and `lsp/servers.ts`
  - Windows paths are now properly handled with quoted paths in hook commands

### Changed
- **Hook Configuration** - All plugin hooks now use `node` command instead of `bash` for universal compatibility
- Default hook scripts changed from `.sh` to `.mjs` in `hooks/hooks.json`

### Technical Details
- Added `isWindows()` and `whichCommand()` helpers for cross-platform binary detection
- Node.js hook scripts maintain feature parity with Bash versions
- Plugin installation now works correctly on Windows without WSL

## [1.11.0] - 2026-01-13

### Added
- **Enhanced Hook Enforcement System** - Stronger Sisyphus behavior enforcement beyond CLAUDE.md
  - `pre-tool-enforcer.sh`: PreToolUse hook that injects contextual Sisyphus reminders before every tool execution
  - `post-tool-verifier.sh`: PostToolUse hook for verification after tools, with failure detection
  - Enhanced `persistent-mode.sh`: Stop hook now includes build/test/git/background task verification
  - `claude-sisyphus.sh`: CLI wrapper that uses `--append-system-prompt` for direct system prompt injection
  - `sisyphus-aliases.sh`: Shell aliases (`claude-s`, `claudew`) for easy activation

### Changed
- **Stop Hook** now enforces additional verification requirements:
  - Build verification (if build scripts exist)
  - Test verification (if tests exist)
  - Git status check (warns on uncommitted changes)
  - Background task completion check
  - All previous checks (Ralph Loop, Ultrawork, Todo completion)

- **Hook Configuration** - Added PreToolUse and PostToolUse to `hooks.json`

### Technical Details
- PreToolUse hook provides tool-specific reminders (Bash, Task, Edit, Write, Read, Grep/Glob)
- PostToolUse hook tracks session statistics in `~/.claude/.session-stats.json`
- Stop hook returns `continue: false` until ALL verification requirements are met
- CLI wrapper appends core Sisyphus rules directly to Claude's system prompt

### Enforcement Hierarchy
1. **Stop Hook** with `continue: false` - Blocks ALL stopping until verified
2. **PreToolUse** - Injects reminders BEFORE every tool
3. **PostToolUse** - Verifies AFTER every tool
4. **CLI Wrapper** - Appends rules to system prompt

## [1.10.0] - 2026-01-11

### Added
- **Persistent Mode System** - Enhanced hook system for auto-continuation
  - `ultrawork-state` module: Manages persistent ultrawork mode state across sessions
  - `persistent-mode` hook: Unified Stop handler for ultrawork, ralph-loop, and todo continuation
  - `session-start` hook: Restores persistent mode states when a new session starts
  - Three-layer priority enforcement: Ralph Loop > Ultrawork > Todo Continuation

- **Claude Code Native Hooks Integration**
  - SessionStart hook for mode restoration on session resume
  - Enhanced Stop hook with persistent mode detection
  - Cross-platform support (Bash for Unix, Node.js for Windows)

- **Popular Plugin Patterns Module** (`plugin-patterns`)
  - Auto-format support for multiple languages (TypeScript, Python, Go, Rust)
  - Lint validation with language-specific linters
  - Conventional commit message validation
  - TypeScript type checking integration
  - Test runner detection and execution
  - Pre-commit validation workflow

### Changed
- **Bridge Module** - Added persistent-mode and session-start hook handlers
- **Keyword Detector** - Now activates ultrawork state when ultrawork keyword is detected
- **Settings Configuration** - Added SessionStart hook configuration for both Bash and Node.js

### Technical Details
- New hooks: `persistent-mode.sh/.mjs`, `session-start.sh/.mjs`
- State files: `.sisyphus/ultrawork-state.json`, `~/.claude/ultrawork-state.json`
- Ultrawork mode now persists across stop attempts when todos remain incomplete
- Ralph-loop continues with iteration tracking and reinforcement messages

## [1.9.0] - 2026-01-10

### Changed
- **Synced all builtin skills with oh-my-opencode source implementation**
  - Updated `orchestrator` skill (1302 lines) with complete orchestrator-sisyphus.ts template
  - Updated `sisyphus` skill (362 lines) with complete sisyphus.ts template
  - Updated `ultrawork` skill (97 lines) - cleaned and adapted from keyword-detector
  - Updated `ralph-loop` skill (11 lines) from ralph-loop hook
  - Updated `git-master` skill with 1131-line comprehensive template
  - Updated `frontend-ui-ux` skill with enhanced Work Principles section

### Fixed
- **Installer improvements**
  - Fixed skill path format from `'skill-name.md'` to `'skill-name/skill.md'`
  - Fixed agent path for prometheus from `'prometheus/skill.md'` to `'prometheus.md'`
  - Added directory creation for both commands and skills to prevent ENOENT errors
  - Fixed ultrawork skill to remove JavaScript wrapper code (clean prompt only)

- **Template escaping**
  - Properly escaped backticks, template literals (`${}`), and backslashes in all skill templates
  - Fixed TypeScript compilation errors due to improper template string escaping

- **SDK adaptation**
  - Converted all oh-my-opencode SDK patterns to Claude Code SDK:
    - `sisyphus_task()` → `Task(subagent_type=...)`
    - `background_output()` → `TaskOutput()`
    - References to OhMyOpenCode → Oh-My-ClaudeCode-Sisyphus

### Verified
- All 6 builtin skills install correctly to `~/.claude/skills/`
- Orchestrator skill properly delegates with `Task(subagent_type=...)`
- Ultrawork skill contains clean verification guarantees and zero-tolerance failures
- Build completes without TypeScript errors
- Installation completes successfully

## [1.8.0] - 2026-01-10

### Added
- Intelligent Skill Composition with task-type routing
- Architecture comparison documentation (OpenCode vs Claude Code)
- Intelligent Skill Activation section to README

### Changed
- Merged feature/auto-skill-routing branch

## [1.7.0] - Previous Release

### Added
- Windows support with Node.js hooks
- ESM import for tmpdir

---

[1.11.0]: https://github.com/Yeachan-Heo/oh-my-claude-sisyphus/compare/v1.10.0...v1.11.0
[1.10.0]: https://github.com/Yeachan-Heo/oh-my-claude-sisyphus/compare/v1.9.0...v1.10.0
[1.9.0]: https://github.com/Yeachan-Heo/oh-my-claude-sisyphus/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/Yeachan-Heo/oh-my-claude-sisyphus/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/Yeachan-Heo/oh-my-claude-sisyphus/releases/tag/v1.7.0
