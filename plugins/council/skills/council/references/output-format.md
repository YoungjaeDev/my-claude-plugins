# Output Format, Progress, Errors & Interaction

Progress-tracking template, the final deliberation report template, the error-handling table, and `AskUserQuestion` guidance.

## Progress Tracking (TodoWrite)

Show progress at each stage.

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
- Model response received → mark that model's todo as "completed"
- All models done → "[Council] Analyze responses" to "in_progress"
- Round 2 needed → add re-query todos for specific models
- Analysis done → "[Council] Synthesize" to "in_progress"

## Final Output Template

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

In quick mode, the report can be reduced (skip the deliberation-process / coordinator-analysis tables) since there is a single round and no Round 1.5 analysis.

## Error Handling

| Error | Response |
|-------|----------|
| Model timeout | Continue with successful responses, note failures |
| All models fail | Report error, suggest retry |
| Parse failure | Use fallback extraction, flag for re-query |
| Empty response | Exclude from synthesis, note in output |
| Schema violation | Flag and request re-query in next round |

## User Interaction (AskUserQuestion)

Use `AskUserQuestion` when clarification is needed.

**Before Round 1:**
- Question is ambiguous or too broad
- Missing critical context (e.g., "review this code" but no file specified)
- Multiple interpretations possible

**During deliberation:**
- Strong disagreement between models that cannot be resolved
- New information discovered that changes the question scope

**After synthesis:**
- Remaining disagreements require user input to decide
- Actionable next steps require user confirmation

**Example questions:**
```
- "Your question mentions 'the API' - which specific endpoint or service?"
- "Models disagree on X vs Y approach. Which aligns better with your constraints?"
- "Should the council prioritize performance or maintainability?"
```

**Important:** Never assume or guess when context is unclear. Ask first, then proceed.

## Intent Examples (natural language, not slash syntax)

- "Ask the council: what's the best way to implement caching in this API?" → full multi-round deliberation.
- "Quick council take — tabs or spaces?" → quick mode (single round, free-form).
- "Get a few models' opinions on the current authentication flow and how to improve it." → full deliberation, likely triggers Explore-agent context gathering.
