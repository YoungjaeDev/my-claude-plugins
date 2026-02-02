---
description: Consult multiple AI models and synthesize collective wisdom (LLM Council)
---

# LLM Council

Inspired by Andrej Karpathy's LLM Council: query multiple AI models with the same question, anonymize their responses, and synthesize collective wisdom through multi-round deliberation.

**Core Philosophy:**
- Collective intelligence > single expert opinion
- Anonymization prevents model favoritism
- Multi-round deliberation resolves conflicts and fills gaps
- Diverse perspectives lead to better answers

---

## Arguments

`$ARGUMENTS` parsing:

1. **No arguments**: `/council` - Prompt user for question
2. **Question only**: `/council How should I structure this API?`
3. **Quick mode**: `/council --quick What's the best approach?`

**Flags:**
- `--quick`: Quick mode (see below)

**Default behavior (no flags):**
- Maximum reasoning depth (Codex: reasoningEffort=xhigh, model=gpt-5.1-codex-max)
- Full multi-round deliberation (up to 3 rounds)
- YAML schema enforced

**Quick mode (`--quick`):**
- All 4 models queried (Opus, Sonnet, Codex, Gemini)
- Single round only (Round 1 -> direct Synthesis, no Round 1.5 analysis)
- YAML schema not enforced (free-form responses accepted)
- Codex: reasoningEffort=high (instead of xhigh)

---

## Pre-flight Check

Before querying models, detect available council members:

**1. Detect Available Models:**
```bash
# Built-in (always available)
AVAILABLE_MODELS="opus,sonnet"
MODEL_COUNT=2

# Check optional CLIs
if command -v codex > /dev/null 2>&1; then
  AVAILABLE_MODELS="$AVAILABLE_MODELS,codex"
  MODEL_COUNT=$((MODEL_COUNT + 1))
fi

if command -v gemini > /dev/null 2>&1; then
  AVAILABLE_MODELS="$AVAILABLE_MODELS,gemini"
  MODEL_COUNT=$((MODEL_COUNT + 1))
fi

echo "Available models ($MODEL_COUNT): $AVAILABLE_MODELS"
```

**2. Model Availability Decision:**

| Models Available | Action |
|------------------|--------|
| 4 (all) | Proceed with full council |
| 3 | Proceed, note missing model |
| 2 (Opus + Sonnet only) | Proceed with reduced council |
| < 2 | Error - cannot proceed |

**3. Setup Recommendation:**

If Codex or Gemini is missing, inform the user:

```
Council will run with [N] models: [list]

For richer deliberation with more perspectives, install additional models:
  /council-setup

Proceed with current setup? [Y/n]
```

Use `AskUserQuestion` tool with options:
- "Proceed with [N] models" (recommended if >= 2)
- "Run /council-setup first"

**4. Guidelines Files (Optional but recommended):**
```bash
[ -f ./CLAUDE.md ] && echo "CLAUDE.md: ✅" || echo "CLAUDE.md: ❌ (Claude context limited)"
[ -f ./AGENTS.md ] && echo "AGENTS.md: ✅" || echo "AGENTS.md: ❌ (Codex context limited)"
[ -f ./GEMINI.md ] && echo "GEMINI.md: ✅" || echo "GEMINI.md: ❌ (Gemini context limited)"
```

**5. Dynamic Model Selection:**

Only query models that are available. Skip unavailable models gracefully:

```python
models_to_query = []
if True:  # Always available
    models_to_query.extend(["opus", "sonnet"])
if codex_available:
    models_to_query.append("codex")
if gemini_available:
    models_to_query.append("gemini")
```

---

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

**Beyond the Question (Evidence-Based Only):**
Council members may suggest improvements beyond the direct question, but ONLY with:
- Specific file:line references from the codebase
- Evidence from actual code analysis
- Clear connection to the question context

Generic best practices without codebase evidence are NOT accepted.

---

## Context Gathering (Before Round 1)

Before querying models, collect relevant context:

**Auto-collect:**
```
- git status / git diff (current changes)
- Directory structure (tree -L 2)

Model-specific guidelines (project root):
- ./CLAUDE.md (Claude Opus/Sonnet)
- ./AGENTS.md (Codex)
- ./gemini.md (Gemini)
- .claude/guidelines/work-guidelines.md (All models - style and response guidelines)
- .claude/rules/*.md (All models - module-specific rules, if directory exists)
```

**Conditional Code Exploration:**

When relevant files are unclear from the question, spawn Explore agents to discover them:

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

**Sensitive Data Filtering (exclude from prompts):**
```
Files: .env*, secrets*, *credentials*, *.pem, *.key
Patterns: sk-[a-zA-Z0-9]+, Bearer tokens, passwords
Directories: node_modules/, __pycache__/, .git/
```

**Prompt Size Management:**
```
- Large files (>500 lines): include only relevant sections or diff
- Max 5 files per prompt
- Prefer git diff over full file content
- If timeout occurs: reduce context, retry
```

---

## Progress Tracking

Use TodoWrite to show progress at each stage:

**Round 1 start:**
```yaml
todos:
  - content: "[Council] Query Opus"
    status: "in_progress"
    activeForm: "Querying Opus"
  - content: "[Council] Query Sonnet"
    status: "in_progress"
    activeForm: "Querying Sonnet"
  - content: "[Council] Query Codex"
    status: "in_progress"
    activeForm: "Querying Codex"
  - content: "[Council] Query Gemini"
    status: "in_progress"
    activeForm: "Querying Gemini"
  - content: "[Council] Analyze responses"
    status: "pending"
    activeForm: "Analyzing responses"
  - content: "[Council] Synthesize"
    status: "pending"
    activeForm: "Synthesizing"
```

**Update rules:**
- Model response received -> mark that model's todo as "completed"
- All models done -> "[Council] Analyze responses" to "in_progress"
- Round 2 needed -> add re-query todos for specific models
- Analysis done -> "[Council] Synthesize" to "in_progress"

---

## Execution

### Round 1: Collect Initial Responses

Query all 4 models **in parallel** using Task tool with sub-agents:

**Claude Opus:**
```
Task(model="opus", subagent_type="general-purpose", run_in_background: true):
  prompt: |
    You are participating in an LLM Council deliberation as Claude Opus.

    ## Guidelines
    Read and follow ./CLAUDE.md project guidelines.
    Read and follow: .claude/guidelines/work-guidelines.md for style guidelines.
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

**Claude Sonnet:**
```
Task(model="sonnet", subagent_type="general-purpose", run_in_background: true):
  prompt: [Same structure as Opus, including:
    Read and follow: .claude/guidelines/work-guidelines.md for style guidelines.]
```

**Codex:**
```
Task(subagent_type="general-purpose", run_in_background: true):
  prompt: |
    You are participating in an LLM Council deliberation as Codex.

    ## Tool Usage
    Use mcp__codex-cli__codex tool with:
    - sandbox: "read-only"
    - workingDirectory: "{PROJECT_ROOT}"
    - reasoningEffort: "xhigh"  (or "high" with --quick)
    - model: "gpt-5.1-codex-max"

    ## Guidelines
    Read and follow ./AGENTS.md project guidelines.
    Read and follow: .claude/guidelines/work-guidelines.md for style guidelines.
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

**Gemini:**
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
    Read and follow ./gemini.md project guidelines.
    Read and follow: .claude/guidelines/work-guidelines.md for style guidelines.
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

**Important:**
- Use `run_in_background: true` for true parallelism
- Timeout per model (use same value for TaskOutput):
  | Model | Timeout | Reason |
  |-------|---------|--------|
  | Opus/Sonnet | 300000ms (5min) | Direct execution |
  | Codex | 480000ms (8min) | MCP tool + deep reasoning |
  | Gemini | 600000ms (10min) | CLI invocation + long thinking |
- Continue with successful responses if some models fail (min 2/4 required)
- **TaskOutput must use matching timeout**: `TaskOutput(task_id, block=true, timeout=600000)`

### Round 1.5: Coordinator Analysis (MANDATORY)

**⚠️ DO NOT SKIP**: After collecting responses, the coordinator **MUST** perform this analysis before synthesis.
Skipping Round 1.5 defeats the purpose of multi-round deliberation.

**1. Anonymize Responses:**
```
1. Assign labels in response arrival order: Response A, B, C, D
2. Create internal mapping:
   label_to_model = {
     "Response A": "[first arrived]",
     "Response B": "[second arrived]",
     "Response C": "[third arrived]",
     "Response D": "[fourth arrived]"
   }
3. Present responses by label only (hide model names until synthesis)
```

**2. Gap Analysis:**
```yaml
gaps_detected:
  - model: "opus"
    gap: "performance benchmarks not addressed"
    severity: "medium"
  - model: "gemini"
    gap: "security implications missing"
    severity: "high"
```

**3. Conflict Detection:**
```yaml
conflicts_detected:
  - topic: "recommended approach"
    positions:
      - model: "opus"
        position: "use library A"
        evidence: "official docs recommend"
      - model: "codex"
        position: "use library B"
        evidence: "better performance"
    resolution_needed: true
```

**4. Convergence Check (REQUIRED before synthesis):**
```yaml
convergence_status:
  agreement_count: 3  # models with same core conclusion
  gaps_remaining: 2
  conflicts_remaining: 1
  decision: "proceed_to_round_2" | "terminate_and_synthesize"
```

**Decision logic:**
- If `agreement_count >= 3` → `terminate_and_synthesize` (strong consensus)
- If `gaps_remaining == 0` AND `conflicts_remaining == 0` → `terminate_and_synthesize`
- If `conflicts_remaining > 0` AND round < 3 → `proceed_to_round_2`
- If `gaps_remaining > 0` AND round < 3 → `proceed_to_round_2`
- Otherwise → `terminate_and_synthesize`

### Round 2: Targeted Re-queries (Conditional)

If convergence criteria not met, re-query only models with gaps/conflicts:

**Re-query prompt template:**
```
## Previous Round Summary
Round 1 produced the following positions:

### Response A
- Position: [summary]
- Key points: [list]

### Response B
- Position: [summary]
- Key points: [list]

[... other responses ...]

## Gaps Identified
- [gap 1]
- [gap 2]

## Conflicts Detected
- Topic: [topic]
  - Position A: [description]
  - Position B: [description]

## Re-query Focus
Please address specifically:
1. [specific gap or conflict to resolve]
2. [specific gap or conflict to resolve]

Provide evidence and reasoning for your position.

## Output (YAML format required)
[COUNCIL_MEMBER_SCHEMA with gaps/conflicts fields]
```

### Round 2.5: Coordinator Analysis

Same as Round 1.5. Check convergence again.

### Round 3: Final Cross-Validation (Conditional)

If still not converged after Round 2:
- Focused on resolving remaining conflicts
- Models see other models' positions (still anonymized)
- Final opportunity for consensus

### Synthesis

After convergence or max rounds:

1. **Reveal** the label-to-model mapping
2. **Analyze** all responses:
   - Consensus points (where models agree)
   - Resolved conflicts (with reasoning)
   - Remaining disagreements (with analysis)
   - Unique insights (valuable points from individual models)
3. **Produce** final verdict combining best elements

---

## Termination Criteria

### Hard Limits (Mandatory Termination)
| Condition | Value |
|-----------|-------|
| Max rounds | 3 |
| Max total time | 20 min |
| Max per-model timeout | 10 min (Gemini) |
| Min successful models | 2/4 (proceed with partial results) |
| All models failed | immediate termination |

### Soft Limits (Convergence - any triggers termination)
| Condition | Threshold |
|-----------|-----------|
| Strong consensus | 3+ models agree on core conclusion |
| All gaps resolved | 0 remaining |
| All conflicts resolved | 0 remaining |
| Conflicts irreconcilable | Cannot be resolved with more queries |

---

## Output Format

```markdown
## LLM Council Deliberation

### Question
[Original user question]

### Deliberation Process
| Round | Models Queried | Convergence | Status |
|-------|---------------|-------------|--------|
| 1 | All (4) | 65% | Gaps detected |
| 2 | Codex, Gemini | 85% | Conflict on approach |
| 3 | Codex | 95% | Converged |

### Individual Responses (Anonymized)

#### Response A
[Content]

**Key Points:**
- [point 1] (evidence: file:line)
- [point 2] (evidence: file:line)

#### Response B
[Content]

#### Response C
[Content]

#### Response D
[Content]

### Model Reveal
| Label | Model |
|-------|-------|
| Response A | codex |
| Response B | opus |
| Response C | sonnet |
| Response D | gemini |

### Coordinator Analysis

#### Gaps Addressed
| Gap | Resolved By | Round |
|-----|-------------|-------|
| Performance benchmarks | Codex | 2 |
| Security considerations | Opus | 1 |

#### Conflicts Resolved
| Topic | Final Position | Reasoning |
|-------|---------------|-----------|
| Library choice | Library A | Official docs + 3 model consensus |

#### Remaining Disagreements
| Topic | Positions | Analysis |
|-------|-----------|----------|
| [topic] | A: [pos], B: [pos] | [why unresolved] |

### Council Synthesis

#### Consensus
[Points where all/most models agree - with evidence]

#### Key Insights by Model
| Model | Unique Contribution |
|-------|-------------------|
| Codex | [insight] |
| Opus | [insight] |

### Final Verdict
[Synthesized answer combining collective wisdom with confidence level and caveats]

### Code References
| File | Lines | Context |
|------|-------|---------|
| /path/to/file.py | 45-78 | Authentication logic |
```

---

## Error Handling

| Error | Response |
|-------|----------|
| Model timeout | Continue with successful responses, note failures |
| All models fail | Report error, suggest retry |
| Parse failure | Use fallback extraction, flag for re-query |
| Empty response | Exclude from synthesis, note in output |
| Schema violation | Flag and request re-query in next round |

---

## User Interaction

Use `AskUserQuestion` tool when clarification is needed:

**Before Round 1:**
- Question is ambiguous or too broad
- Missing critical context (e.g., "review this code" but no file specified)
- Multiple interpretations possible

**During Deliberation:**
- Strong disagreement between models that cannot be resolved
- New information discovered that changes the question scope

**After Synthesis:**
- Remaining disagreements require user input to decide
- Actionable next steps require user confirmation

**Example questions:**
```
- "Your question mentions 'the API' - which specific endpoint or service?"
- "Models disagree on X vs Y approach. Which aligns better with your constraints?"
- "Should the council prioritize performance or maintainability?"
```

**Important:** Never assume or guess when context is unclear. Ask first, then proceed.

---

## Examples

```bash
# Standard council consultation (full multi-round, max reasoning)
/council What's the best way to implement caching in this API?

# Quick mode for simpler questions
/council --quick Should we use tabs or spaces for indentation?

# Architecture review
/council Review the current authentication flow and suggest improvements
```

---

## Guidelines

- Respond in the same language as the user's question
- No emojis in code or documentation
- If context is needed, gather it before querying models
- For code-related questions, include relevant file snippets with line numbers
- Respect `@CLAUDE.md` project conventions
- **Never assume unclear context - use AskUserQuestion to clarify**
