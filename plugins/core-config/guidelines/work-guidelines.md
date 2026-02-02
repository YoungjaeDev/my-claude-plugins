# Work Guidelines

Common guidelines for all Claude Code commands and development workflow.

---

## Core Principles

### Response Rules
- Follow the instructions in `@CLAUDE.md`
- Answer in the same language as user's request
- Append sources that you've referenced at the very end of your answer
- Do not use emoji in code or documentation
- Never add Claude attribution (e.g., "Generated with Claude", "Co-Authored-By: Claude") to commits, PRs, or issues

### Writing Style (Anti-AI)
Write like a human, not a chatbot. Applies to ALL text: responses, documentation, comments, commit messages.

**NEVER use these AI-ish patterns:**
- Filler openers: "Certainly!", "Of course!", "Absolutely!", "I'd be happy to", "Great question!"
- Excessive affirmation: "That's a great idea", "You're absolutely right", "Excellent point"
- Redundant summaries: "To summarize...", "In conclusion...", "To recap..."
- Over-explanation: Explaining obvious things, restating the question
- Hedging phrases: "I think maybe...", "It might be possible that..."
- Hollow transitions: "Now, let's...", "Moving on to...", "Next, we'll..."
- Colon headers: "**Item:** description", "**Topic:** content" - just write naturally without label-colon-content structure

**DO:**
- Get to the point immediately
- Be direct and concise
- Use natural, conversational tone
- Skip pleasantries unless genuinely warranted

### Uncertainty Handling
- If you are uncertain, confused, or lack clarity about the requirements or approach, **STOP immediately** and ask the user for clarification
- Do not proceed with assumptions or guesses that could lead to incorrect implementations
- **NEVER** ask questions inline in response text - always use `AskUserQuestion` tool

### Question Policy (MANDATORY)
- **ALL questions MUST use `AskUserQuestion` tool** - no exceptions
- Never ask questions as plain text in responses
- This includes:
  - Clarification questions
  - Option/choice selection
  - Confirmation requests
  - Any user input needed

**Why:**
- Plain text questions get buried in long responses
- Tool-based questions provide clear UI separation
- Ensures user doesn't miss important decisions

### User Confirmation Required
Always confirm with the user before:
- Irreversible operations (branch deletion, status changes)
- Modifying configuration files (CLAUDE.md, AGENTS.md, GEMINI.md)
- Making architectural decisions
- Implementing features beyond requested scope

---

## Development Workflow

### Parallel Execution
Use Task tool for independent tasks. For large projects, split into sub-tasks that:
- Avoid consuming entire context window (maximizes token efficiency)
- Produce separate files or distinct code sections (mergeable outputs)
- Have no cross-dependencies (can run without coordination)
- Example: Separate handlers, independent tests, different modules

### Dependency Version Policy (Stable First)
- Prefer widely adopted stable releases over the newest/bleeding-edge versions
- Avoid `alpha`/`beta`/`rc`/canary/nightly releases
- Respect existing project pins
- If a newer version is required (security fix, critical bugfix, or mandatory feature), propose the upgrade with rationale and risks before changing

### Performance/Optimization Gate
- If you identify a clearly faster or more reliable library/framework/approach with meaningful benefit, **PAUSE** implementation and recommend it with trade-offs
- Proceed only after user approval

### Permission-Based Development
- Never overengineer or go beyond the requested scope
- Always ask user for permission when implementing new features

---

## Code Standards

### MCP Server Usage
Utilize MCP servers whenever possible:
- `context7` - Library documentation queries
- `deepwiki` - GitHub repository analysis
- `mcpdocs` - Documentation fetching
- `firecrawl` - Web scraping and search

### Agent & Skill Usage
- Use appropriate agent or skill when available
- If intent is clear, use directly; if unclear, propose and get approval

### Code Exploration Strategy

#### Pre-Implementation Exploration (MANDATORY)
Before writing or modifying code, spawn multiple Explorer agents in parallel:

| Agent Focus | Purpose |
|-------------|---------|
| **Structure** | Overall architecture and file relationships |
| **Pattern** | Similar implementations in codebase |
| **Dependency** | Affected modules and consumers |

**Benefits:**
- Preserves main context window for actual implementation
- Each agent explores independently without blocking
- Aggregated insights before touching code

**Execution:**
```
Task tool with subagent_type=Explore (launch 2-3 agents simultaneously in single message)
```

#### Parallel Exploration with Multiple Tools
Combine the following tools in parallel for efficient code exploration:

| Tool | Use Case | How to Use |
|------|----------|------------|
| **Explorer agent** | Broad codebase exploration, structure understanding | Task tool with `subagent_type=Explore` |
| **Serena MCP** | Semantic code analysis (symbols, references) | See tools below |
| **Built-in LSP** | goToDefinition, findReferences, hover | Direct LSP calls |

#### Tool Selection Priority
1. **Serena MCP** - Preferred when available
2. **Built-in LSP** - Alternative when Serena is unavailable
3. **Explorer agent** - For broad exploration and structure understanding

#### LSP Unavailable Handling
When Built-in LSP returns "No LSP server available" error:
1. **STOP** - Halt the current approach
2. **AskUserQuestion** - Inform user with options:
   - Check if Serena MCP can be activated
   - Or guide LSP server setup for the target language

#### Serena MCP Tools

| Tool | Use Case |
|------|----------|
| `get_symbols_overview` | First step: understand file structure |
| `find_symbol` | Search by name pattern (supports substring matching) |
| `find_referencing_symbols` | Find all usages of a symbol |
| `replace_symbol_body` | Replace entire function/class/method |
| `insert_after_symbol` / `insert_before_symbol` | Add new code at precise locations |
| `search_for_pattern` | Flexible regex search across codebase |

**Session Management:**
- Call `activate_project` at the start of each new conversation session
- Once activated, remains active for the entire session
- Prompt: "activate serena" or "serena activate project"

**Onboarding & Memory:**
- Onboarding: Run once per project initial setup (`onboarding` tool)
- Indexing: LSP-based real-time analysis, no periodic refresh needed
- Memory updates (`edit_memory`): Only when structure changes
  - New modules/adapters added
  - Architecture patterns changed
  - Build/test commands modified

**Best Practices:**
1. Start with `get_symbols_overview` for new files
2. Use `find_symbol` with `depth=1` to see class methods before diving deeper
3. Prefer symbolic editing over file-based editing when modifying functions/classes
4. Always check `find_referencing_symbols` before renaming/removing symbols
5. Never use Grep/Read before trying Serena tools first

### Self-Verification (MANDATORY)

#### Execution Requirement
- **MUST** execute code after writing, not just write and report
- For Python scripts: run with appropriate interpreter
- For tests: run pytest or equivalent
- For notebooks: add/edit cells with NotebookEdit, user executes in Jupyter

#### Error-Free Loop
1. Write code
2. Execute
3. Error? → Analyze → Fix → Re-execute
4. Repeat until success
5. Only then proceed or report

**NEVER:**
- Report "code written" without executing it
- Move to next step while errors exist
- Ask user to run code that you should verify yourself

#### Result Sanity Check
After successful execution, verify output makes sense:
- Data types/shapes as expected
- No unexpected NaN/None/empty values
- Numeric ranges reasonable
- Visualizations render correctly

If results look wrong → investigate and fix, don't just report the anomaly.

### Large File Handling
- Files exceeding 25000 tokens cannot be read at once (Claude Code internal limit)
- When encountering "exceeds maximum allowed tokens" error:
  1. Use Grep to locate relevant content first
  2. Use Read tool with `offset` and `limit` parameters to read in chunks
  3. Example: `offset=0, limit=1000` → `offset=1000, limit=1000` sequentially
- Never attempt to read entire large files without chunking

### Python Development
- **Virtual Environment (MANDATORY)**: Always use virtual environment (uv) when running Python
- **NEVER** use system Python (`python`, `python3`) directly
- If `ModuleNotFoundError` occurs when attempting to run without virtual environment, immediately stop and report to user
- **Syntax Validation**: After modifying Python (.py) files, always validate syntax using `py_compile`:
  ```bash
  python -m py_compile file.py
  ```

### Pip Installation Issues
If pip install errors occur, try in order:
1. `pip install --upgrade pip setuptools wheel`
2. `pip cache purge && pip install -r requirements.txt`
3. `pip install --no-cache-dir -r requirements.txt` (install packages one by one)

### Jupyter Notebook Editing
- Use `edit-notebook` skill for .ipynb editing guidelines
- NotebookEdit tool only, no text editing tools
- After modification: verify cell order and outputs preserved

### Output Standards
- **Minimal Output**: Avoid unnecessary print statements in code - only include meaningful debug output when explicitly requested
- **No Emojis**: Never use emojis anywhere, whether in documentation or code

### Code Documentation Language
- **Docstrings**: English (for API docs, IDE tooltips, type checker integration)
- **Inline/block comments**: Korean (for quick understanding and clarity)

---

## File Organization

### Avoid Root Clutter
- **NEVER** create output files in project root:
  - Analysis notebooks
  - Visualizations
  - CSV data
  - Logs
  - Temporary files
- Only essential project configuration files belong in root (e.g., `README.md`, `requirements.txt`, config files)

### Module-Level Organization
Each module should maintain its own organized structure:
```
[module]/
  analysis/    # Analysis files
  outputs/     # Generated outputs
  tests/       # Test files
  ...
```

### Temporary Files
- Create and use a dedicated temporary directory
- Never commit temporary files to git

---

## Translation Guidelines

When translating into Korean:
- Keep technical terms, code blocks, and commands in their original form
- Translate the surrounding text into natural, context-appropriate Korean
- After completing the translation, review it to ensure it meets these criteria

---

## Related Guidelines

- [ID Reference](./id-reference.md) - GitHub/TaskMaster ID conventions
- [ML Guidelines](./ml-guidelines.md) - ML/CV batch inference, color formats, Ultralytics
- [PRD Guide](./prd-guide.md) - PRD template for TaskMaster
