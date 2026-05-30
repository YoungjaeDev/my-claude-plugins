# Model Invocation & Context

Per-model query templates, the council member output schema, context gathering, file access, and timeouts. Used during Round 1 (and re-queries in later rounds).

## Council Member Output Schema

All council members MUST return responses in this structured format:

```yaml
council_member:
  model: "opus" | "sonnet" | "codex" | "gemini"
  response:
    summary: "1-2 sentence core answer"
    detailed_answer: "full response content"
    key_points:
      - point: "key insight"
        evidence: "file:line or reasoning"
    code_references:  # optional
      - file: "/absolute/path/to/file.py"
        lines: "42-58"
        context: "why this is relevant"
    caveats:  # optional
      - "potential limitation or edge case"
    beyond_question:  # optional, evidence-based only
      - insight: "improvement opportunity"
        evidence: "file:line or codebase reference"
        rationale: "why this is relevant to the question context"
  # Round 2+ additional fields
  gaps:
    - "aspect not fully addressed"
  conflicts:
    - "disagrees with [model] on [topic]: [reason]"
```

**Schema enforcement:**
- Sub-agents that fail to follow this schema will have their results flagged
- Missing required fields trigger re-query in next round

**Beyond the Question (evidence-based only):** council members may suggest improvements beyond the direct question, but ONLY with specific file:line references from the codebase, evidence from actual code analysis, and a clear connection to the question context. Generic best practices without codebase evidence are NOT accepted.

## Context Gathering (before Round 1)

**Auto-collect:**
```
- git status / git diff (current changes)
- Directory structure (tree -L 2)

Model-specific guidelines (project root):
- ./CLAUDE.md (Claude Opus/Sonnet)
- ./AGENTS.md (Codex)
- ./gemini.md (Gemini)
- ~/.claude/CLAUDE.md (All models - user-global style/response guidelines)
- .claude/rules/*.md (All models - module-specific rules, if directory exists)
```

Read the project's own `CLAUDE.md` at runtime and follow its conventions.

**Conditional code exploration** — when relevant files are unclear from the question, spawn Explore agents to discover them:

```
Trigger conditions:
- Question mentions code/architecture/structure without specific files
- Question asks about "this", "the code", "current implementation" ambiguously
- UI/UX questions that need component/style file identification

Skip exploration when:
- User provides specific file paths or permalinks
- Question is conceptual (no code context needed)
- Files are obvious from recent git diff
```

```
Task(subagent_type="Explore", run_in_background: true):
  prompt: |
    Find files related to: [USER_QUESTION]

    Return results in this format:
    - /absolute/path/file.ext:LINE-LINE (brief context)

    Focus on:
    - Direct implementation files
    - Related tests
    - Configuration if relevant
```

After exploration, use discovered paths in the File Path Inclusion format below.

**File Path Inclusion (MANDATORY format):**
```
Relevant files for this question:
- /absolute/path/to/file.py:45-78 (authentication logic)
- /absolute/path/to/model.py:12-35 (User model definition)
- /absolute/path/to/screenshot.png (UI reference)

Use your file access tools to READ these files directly.
```

**Model-specific file access:**
| Model | File Access Method |
|-------|-------------------|
| Claude Opus/Sonnet | Read tool (images supported) |
| Codex | sandbox read-only file access |
| Gemini | MCP tools or Bash file read (MCP supported since 2025) |

**Sensitive data filtering (exclude from prompts):**
```
Files: .env*, secrets*, *credentials*, *.pem, *.key
Patterns: sk-[a-zA-Z0-9]+, Bearer tokens, passwords
Directories: node_modules/, __pycache__/, .git/
```

**Prompt size management:**
```
- Large files (>500 lines): include only relevant sections or diff
- Max 5 files per prompt
- Prefer git diff over full file content
- If timeout occurs: reduce context, retry
```

## Round 1 — Per-Model Query Templates

Query all available models **in parallel** using the Task tool with sub-agents and `run_in_background: true`.

### Claude Opus

```
Task(model="opus", subagent_type="general-purpose", run_in_background: true):
  prompt: |
    You are participating in an LLM Council deliberation as Claude Opus.

    ## Guidelines
    Read and follow ~/.claude/CLAUDE.md (user-global) plus ./CLAUDE.md project guidelines.
    You have access to MCP tools. Use them actively to gather accurate information.

    ## Question
    [USER_QUESTION]

    ## Context Files (READ directly using exact paths)
    [FILE_LIST_WITH_LINE_NUMBERS]

    ## Current Changes
    [git diff summary]

    ## Instructions
    Provide your best answer following the Council Member Output Schema.
    Be concise but thorough. Focus on accuracy and actionable insights.

    ## Output (YAML format required)
    [COUNCIL_MEMBER_SCHEMA]
```

### Claude Sonnet

```
Task(model="sonnet", subagent_type="general-purpose", run_in_background: true):
  prompt: [Same structure as Opus, including:
    Read and follow ~/.claude/CLAUDE.md (user-global) plus ./CLAUDE.md for style guidelines.]
```

### Codex

```
Task(subagent_type="general-purpose", run_in_background: true):
  prompt: |
    You are participating in an LLM Council deliberation as Codex.

    ## Tool Usage
    Use mcp__codex-cli__codex tool with:
    - sandbox: "read-only"
    - workingDirectory: "{PROJECT_ROOT}"
    - reasoningEffort: "xhigh"  (or "high" with quick mode)
    (Do NOT specify model - let Codex CLI use its default for forward compatibility)

    ## Guidelines
    Read and follow ~/.claude/CLAUDE.md (user-global) plus ./AGENTS.md project guidelines.
    You have access to MCP tools. Use them actively to gather accurate information.

    ## Question
    [USER_QUESTION]

    ## Context Files
    [FILE_LIST_WITH_LINE_NUMBERS]

    ## Instructions
    Parse Codex's response and return structured YAML following the schema.

    ## Output (YAML format required)
    [COUNCIL_MEMBER_SCHEMA]
```

### Gemini

```
Task(subagent_type="general-purpose", run_in_background: true):
  prompt: |
    You are participating in an LLM Council deliberation as Gemini.

    ## Tool Usage
    Use Bash tool to invoke Gemini CLI:
    ```bash
    cat <<'EOF' | gemini -p -
    [GEMINI_PROMPT_WITH_CONTEXT]
    EOF
    ```
    Note: Gemini CLI supports MCP (since 2025). If MCP is configured,
    Gemini can access project files directly via MCP tools.

    ## Guidelines
    Read and follow ~/.claude/CLAUDE.md (user-global) plus ./gemini.md project guidelines.
    You have access to MCP tools. Use them actively to gather accurate information.

    ## Question
    [USER_QUESTION]

    ## Context Files (READ directly using exact paths)
    [FILE_LIST_WITH_LINE_NUMBERS]

    ## Instructions
    Parse Gemini's response and return structured YAML following the schema.

    ## Output (YAML format required)
    [COUNCIL_MEMBER_SCHEMA]
```

## Parallelism & Timeouts

- Use `run_in_background: true` for true parallelism.
- Timeout per model (use the same value for TaskOutput):

  | Model | Timeout | Reason |
  |-------|---------|--------|
  | Opus/Sonnet | 300000ms (5min) | Direct execution |
  | Codex | 480000ms (8min) | MCP tool + deep reasoning |
  | Gemini | 600000ms (10min) | CLI invocation + long thinking |

- Continue with successful responses if some models fail (min 2/4 required).
- **TaskOutput must use matching timeout**: `TaskOutput(task_id, block=true, timeout=600000)`.
