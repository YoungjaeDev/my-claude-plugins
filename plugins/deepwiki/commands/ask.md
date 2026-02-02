---
description: Deep query on GitHub repositories using DeepWiki
---

# DeepWiki Repository Query

Query GitHub repositories in-depth using DeepWiki's AI-powered documentation system.

## Arguments

`$ARGUMENTS` parsing:
- Format: `owner/repo "question"` or `owner/repo question text`
- Repository: Extract `owner/repo` pattern
- Question: Remaining text after repository

Examples:
- `/deepwiki:ask facebook/react "How does the reconciliation algorithm work?"`
- `/deepwiki:ask vercel/next.js explain the app router architecture`
- `/deepwiki:ask pytorch/pytorch what are the autograd internals`

## Workflow

### Phase 1: Understand Repository Structure

First, get an overview of the documentation:

```
mcp__deepwiki__read_wiki_structure({
  repoName: "[owner/repo]"
})
```

This returns available documentation topics. Use this to:
- Understand what documentation exists
- Identify relevant sections for the question
- Plan which areas to explore deeper

### Phase 2: Gather Context (Conditional)

If the question requires deep understanding or spans multiple topics:

```
mcp__deepwiki__read_wiki_contents({
  repoName: "[owner/repo]"
})
```

Use this when:
- Question is broad (architecture, design philosophy)
- Multiple topics seem relevant from structure
- Need comprehensive context for accurate answer

Skip this when:
- Question is narrow and specific
- Structure clearly points to one topic
- Quick answer is sufficient

### Phase 3: Ask the Question

Query with full context:

```
mcp__deepwiki__ask_question({
  repoName: "[owner/repo]",
  question: "[QUESTION]"
})
```

### Phase 4: Multi-Query Expansion (if needed)

If initial response is insufficient:

1. **Decompose** the question into sub-questions
2. **Query in parallel** using multiple `ask_question` calls
3. **Synthesize** results into comprehensive answer

Example decomposition:
```
Original: "How does Next.js handle routing?"

Sub-questions:
- "How does the App Router work?"
- "How does the Pages Router work?"
- "How are dynamic routes handled?"
```

## Smart Query Strategy

| Question Type | Strategy |
|---------------|----------|
| **Specific** ("How does X function work?") | Skip Phase 2, direct ask_question |
| **Broad** ("Explain the architecture") | Full workflow with contents |
| **Comparative** ("X vs Y in this repo") | Structure → targeted asks |
| **Exploratory** ("What can this do?") | Structure → contents → summary |

## Multi-Repository Queries

DeepWiki supports querying multiple repos simultaneously:

```
mcp__deepwiki__ask_question({
  repoName: ["facebook/react", "vuejs/vue"],
  question: "Compare the reactivity systems"
})
```

Use for:
- Framework comparisons
- Finding common patterns
- Cross-project analysis

## Output Format

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

## Error Handling

| Error | Action |
|-------|--------|
| Invalid repo format | Request correct `owner/repo` format |
| Repository not found | Verify repository exists on GitHub |
| Empty question | Request specific question |
| DeepWiki unavailable | Fallback to direct GitHub exploration via `gh` CLI |
| Insufficient answer | Trigger multi-query expansion |

## Tips

1. **Be specific**: "How does useEffect cleanup work?" > "Tell me about hooks"
2. **Use structure first**: Understand what docs exist before diving deep
3. **Compare repos**: DeepWiki excels at cross-repository analysis
4. **Iterate**: If first answer is shallow, ask follow-up questions

## Guidelines

- Follow CLAUDE.md project guidelines
- Cite specific documentation sections when possible
- Provide actionable insights, not just summaries
