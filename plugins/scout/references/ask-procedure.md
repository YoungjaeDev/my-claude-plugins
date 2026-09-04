# DeepWiki ask — procedure

Shared procedure body for `/scout:ask` (command) and the `ask` skill. Both surfaces resolve this file via `references/ask-procedure.md` relative to the plugin's installed root (`${CLAUDE_PLUGIN_ROOT}/...` under Claude Code; the same relative path under the Codex plugin cache) so the workflow stays single-sourced.

## Input shape

The caller passes a repository spec and a question. Two arrival paths:

- **Command (`/scout:ask`)**: `$ARGUMENTS` is the raw user text. Parse:
  - Format: `owner/repo "question"` or `owner/repo question text`.
  - Repository: extract the first `owner/repo` pattern.
  - Question: everything after the repository.
- **Skill (`ask`)**: caller already supplies the repo + question in conversational form. Restate back to the user before querying so the parse is auditable.

Examples:
- `facebook/react` + "How does the reconciliation algorithm work?"
- `vercel/next.js` + "Explain the app router architecture."
- `pytorch/pytorch` + "What are the autograd internals?"

## Workflow

### Phase 1 — Understand repository structure

Get an overview of the documentation:

```
mcp__deepwiki__read_wiki_structure({ repoName: "[owner/repo]" })
```

Use the returned topic list to:
- Understand what documentation exists.
- Identify the sections relevant to the question.
- Plan which areas to explore deeper.

### Phase 2 — Gather context (conditional)

If the question requires deep understanding or spans multiple topics:

```
mcp__deepwiki__read_wiki_contents({ repoName: "[owner/repo]" })
```

Use this when:
- Question is broad (architecture, design philosophy).
- Multiple topics from the structure look relevant.
- A comprehensive answer needs full context.

Skip this when:
- Question is narrow and specific.
- The structure clearly points to one topic.
- A quick answer is sufficient.

### Phase 3 — Ask the question

Query with the gathered context:

```
mcp__deepwiki__ask_question({
  repoName: "[owner/repo]",
  question: "[QUESTION]"
})
```

### Phase 4 — Multi-query expansion (if needed)

If the initial response is insufficient:

1. **Decompose** the question into sub-questions.
2. **Query in parallel** using multiple `ask_question` calls.
3. **Synthesize** the results into a comprehensive answer.

Example decomposition:

```
Original: "How does Next.js handle routing?"

Sub-questions:
- "How does the App Router work?"
- "How does the Pages Router work?"
- "How are dynamic routes handled?"
```

## Smart query strategy

| Question type | Strategy |
|---------------|----------|
| **Specific** ("How does X function work?") | Skip Phase 2, direct `ask_question`. |
| **Broad** ("Explain the architecture") | Full workflow with contents. |
| **Comparative** ("X vs Y in this repo") | Structure → targeted asks. |
| **Exploratory** ("What can this do?") | Structure → contents → summary. |

## Multi-repository queries

DeepWiki supports querying multiple repos at once:

```
mcp__deepwiki__ask_question({
  repoName: ["facebook/react", "vuejs/vue"],
  question: "Compare the reactivity systems"
})
```

Use for:
- Framework comparisons.
- Finding common patterns.
- Cross-project analysis.

## Output format

```markdown
## DeepWiki Query: [repo]

### Question
[Original question]

### Documentation Structure
[Relevant topics from wiki structure]

### Answer
[Comprehensive answer from DeepWiki]

### Key References
- [Topic 1]: [Brief description]
- [Topic 2]: [Brief description]

### Further Exploration
- [Suggested follow-up questions]
```

## Error handling

| Error | Action |
|-------|--------|
| Invalid repo format | Ask the user for `owner/repo` format. |
| Repository not found | Verify the repository exists on GitHub. |
| Empty question | Ask the user for a specific question. |
| DeepWiki MCP unavailable | Fall back to direct GitHub exploration via `gh` CLI; surface the MCP setup link (`https://mcp.deepwiki.com/`). |
| Insufficient answer | Trigger multi-query expansion (Phase 4). |

## Tips

1. **Be specific**: "How does useEffect cleanup work?" beats "Tell me about hooks".
2. **Use structure first**: understand what docs exist before diving deep.
3. **Compare repos**: DeepWiki excels at cross-repository analysis.
4. **Iterate**: if the first answer is shallow, ask follow-up questions.

## Guidelines

- Follow the host project's CLAUDE.md / AGENTS.md guidelines.
- Cite specific documentation sections when possible.
- Provide actionable insights, not just summaries.
