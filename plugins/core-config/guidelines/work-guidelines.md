# Work Guidelines

Common guidelines for Claude Code commands and development workflow.

---

## Core Principles

### Response Rules

- Follow instructions in `@CLAUDE.md`
- Answer in the same language as user's request
- Append sources referenced at the end of your answer
- No emoji in code or documentation
- Never add Claude attribution to commits, PRs, or issues

### Writing Style (Anti-AI)

Write like a human, not a chatbot. Applies to ALL text.

**NEVER use:**
- Filler openers: "Certainly!", "Of course!", "Absolutely!", "I'd be happy to"
- Excessive affirmation: "That's a great idea", "You're absolutely right"
- Redundant summaries: "To summarize...", "In conclusion..."
- Over-explanation of obvious things
- Hedging phrases: "I think maybe...", "It might be possible that..."
- Hollow transitions: "Now, let's...", "Moving on to..."
- Colon headers: "**Item:** description" format

**DO:**
- Get to the point immediately
- Be direct and concise
- Use natural, conversational tone

### Question Policy (MANDATORY)

**ALL questions MUST use `AskUserQuestion` tool** - no exceptions.

Never ask questions as plain text. This includes clarification, option selection, and confirmation requests.

### User Confirmation Required

Always confirm before:
- Irreversible operations (branch deletion, status changes)
- Modifying configuration files (CLAUDE.md, AGENTS.md)
- Making architectural decisions
- Implementing features beyond requested scope

---

## Pre-Implementation Gates

Quality gates before writing any code. Based on Karpathy Principles.

### 1. Assumption Transparency

State all assumptions explicitly before implementing.

- Ambiguous requirements → Present 2-3 interpretations, never auto-select
- Use AskUserQuestion to confirm interpretation
- Never start implementation without clarifying ambiguities

### 2. Senior Engineer Test

Before writing code, ask yourself:

- "Would a senior engineer consider this overcomplicated?"
- No unrequested abstractions, patterns, or configurability
- No unnecessary helpers/utilities for single-use code
- Three similar lines of code beats a premature abstraction

### 3. Surgical Diff Rule

Every changed line must trace directly to user's request.

- NO drive-by improvements
- NO adjacent code style/format changes
- NO refactoring unbroken code
- Flag unrelated issues with comments only, do not fix

---

## Feature Lifecycle

When adding features, consider disable/delete scenarios.

### Design Checklist

- [ ] Can be controlled via feature flag or config option?
- [ ] Uses dependency injection or loose coupling?
- [ ] Removal impact minimized? (no hardcoded dependencies)
- [ ] Rollback-friendly structure?

### Disable Considerations

- Structure allows toggling off via feature flag
- Dependent code gracefully degrades when disabled

### Delete Considerations

- Removal has minimal impact on other modules
- Related tests can be cleanly removed together

---

## Development Workflow

### Parallel Execution

Run independent tasks in parallel via Task tool. See OMC CLAUDE.md "Parallelization Rules" for details.

### Dependency Version Policy

- Prefer widely adopted stable releases over bleeding-edge
- Avoid `alpha`/`beta`/`rc`/canary/nightly releases
- Respect existing project pins
- Propose upgrades with rationale and risks before changing

### Permission-Based Development

- Never overengineer or exceed requested scope
- Always ask permission for new features

---

## Code Exploration

### Tool Priority

1. **Serena MCP** - Semantic analysis (symbols, references) - preferred
2. **Built-in LSP** - Alternative when Serena unavailable
3. **Explorer agent** - Broad exploration (see OMC CLAUDE.md)

### LSP Unavailable Handling

When LSP returns "No LSP server available":
1. STOP current approach
2. Use AskUserQuestion to guide Serena activation or LSP setup

### Serena MCP Tools

| Tool | Use Case |
|------|----------|
| `get_symbols_overview` | Understand file structure (use first) |
| `find_symbol` | Search by name pattern |
| `find_referencing_symbols` | Find all usages of a symbol |
| `replace_symbol_body` | Replace entire function/class/method |
| `insert_after_symbol` / `insert_before_symbol` | Add code at precise locations |
| `search_for_pattern` | Flexible regex search |

**Session Management:**
- Call `activate_project` at conversation start
- Once activated, remains active for session

**Best Practices:**
1. Start with `get_symbols_overview` for new files
2. Use `find_symbol` with `depth=1` to see class methods first
3. Prefer symbolic editing over file-based editing
4. Check `find_referencing_symbols` before renaming/removing
5. Try Serena tools before Grep/Read

---

## Self-Verification (MANDATORY)

Always execute code after writing. See OMC CLAUDE.md "Verification-Before-Completion Protocol".

### Test-First Verification

1. Write failing test first (reproduce problem)
2. Implement fix
3. Verify test passes
4. Check edge cases

### Error-Free Loop

Write → Execute → Error? → Fix → Re-execute → Repeat until success

**NEVER:**
- Report "code written" without executing
- Proceed to next step with errors present
- Ask user to run code you should verify yourself

---

## Code Standards

### MCP Server Usage

Use MCP servers when available:
- `context7` - Library documentation
- `deepwiki` - GitHub repository analysis
- `mcpdocs` - Documentation fetching
- `firecrawl` - Web scraping and search

### Large File Handling

Files exceeding 25000 tokens cannot be read at once.

When encountering "exceeds maximum allowed tokens":
1. Use Grep to locate relevant content first
2. Use Read with `offset` and `limit` parameters
3. Example: `offset=0, limit=1000` → `offset=1000, limit=1000`

### Python Development

- **Virtual Environment (MANDATORY)**: Always use uv
- **NEVER** use system Python directly
- On `ModuleNotFoundError`, stop and report to user
- Validate syntax after edits: `python -m py_compile file.py`

### Pip Issues

Try in order:
1. `pip install --upgrade pip setuptools wheel`
2. `pip cache purge && pip install -r requirements.txt`
3. `pip install --no-cache-dir -r requirements.txt`

### Jupyter Notebook

- Use `edit-notebook` skill for .ipynb guidelines
- NotebookEdit tool only, no text editing
- Verify cell order and outputs after modification

### Output Standards

- **Minimal Output**: Only meaningful debug output when requested
- **No Emojis**: Never use emojis anywhere

### Documentation Language

- **Docstrings**: English (API docs, IDE tooltips)
- **Comments**: Korean (quick understanding)

---

## File Organization

### Avoid Root Clutter

**NEVER** create in project root:
- Analysis notebooks, visualizations, CSV data, logs, temporary files

Only essential config files belong in root.

### Module-Level Organization

```
[module]/
  analysis/    # Analysis files
  outputs/     # Generated outputs
  tests/       # Test files
```

### Temporary Files

- Use dedicated temporary directory
- Never commit to git

---

## Translation Guidelines

When translating to Korean:
- Keep technical terms, code blocks, commands in original form
- Translate surrounding text naturally
- Review after completion

---

## Related

- [ML Guidelines](./ml-guidelines.md) - ML/CV best practices
- OMC CLAUDE.md - Multi-agent orchestration, verification protocols
