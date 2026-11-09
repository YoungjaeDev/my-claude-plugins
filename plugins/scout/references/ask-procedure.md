# DeepWiki ask — procedure

The workflow behind the `ask` skill (`/scout:ask`): up to 4 DeepWiki MCP phases, then one answer in the output format below. The skill resolves this file at `references/ask-procedure.md` under the plugin's installed root.

## Input shape

The caller supplies a repository spec and a question, in conversational form or as `owner/repo "question"` / `owner/repo question text` (the repository is the first `owner/repo` pattern, the question everything after it). Restate both before querying so the parse is auditable.

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

- **Use it when** the question is broad (architecture, design philosophy), several topics from the structure look relevant, or a comprehensive answer needs full context.
- **Skip it when** the question is narrow, the structure points to one topic, or a quick answer is enough.

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
| Specific ("How does X function work?") | Skip Phase 2, direct `ask_question`. |
| Broad ("Explain the architecture") | Full workflow with contents. |
| Comparative ("X vs Y in this repo") | Structure → targeted asks. |
| Exploratory ("What can this do?") | Structure → contents → summary. |

## Multi-repository queries

DeepWiki supports querying multiple repos at once:

```
mcp__deepwiki__ask_question({
  repoName: ["facebook/react", "vuejs/vue"],
  question: "Compare the reactivity systems"
})
```

Use it for framework comparisons, common patterns and cross-project analysis.

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
