# TCREI Prompt Template

Google's Prompting Essentials (Coursera) 5-step structure for turning a rough request into a
reusable, copy-paste-ready prompt: Task, Context, References, Evaluate, Iterate.

## Diagnosis Criteria

Use this to check which elements a prompt already has before adding more:

| Element | Present if... | Missing if... |
|---------|--------------|---------------|
| **Task** | Has 2+ of: action verb, output format, constraints | Only a vague verb ("do this", "write something") |
| **Context** | Specifies 1+ of: audience, purpose, source material | No background information at all |
| **References** | Includes samples, format specs, schemas, or tone examples | No hint about desired output shape |
| **Evaluate** | Has 1+ of: must-have, must-not, verification criteria | No quality standards defined |
| **Iterate** | Mentions improvement direction or version requests | One-shot request only |

## Output Template

````markdown
# TCREI Prompt: [Title]

> Structured with Google's TCREI framework. Copy and paste directly to any AI.

---

## Task

[Verb] to produce [output].

**Constraints:**
- [Format / length / tone constraint 1]
- [Constraint 2]
- [Constraint 3]

## Context

- **Audience**: [Who will read this]
- **Purpose**: [Why this is needed]
- **Source material**: [What to base it on - attach below or mark "to be attached"]

[Additional background if any]

## References

**Style guide:**
- [Tone / voice rule 1]
- [Tone / voice rule 2]

**Output samples (for tone reference):**
> "[Sample sentence 1]"
> "[Sample sentence 2]"

[If JSON schema is needed:]
```json
{
  "key1": "description",
  "key2": "description"
}
```

## Evaluate

After completing the task, self-check against these criteria:

**Must-have:**
- [ ] [Required element 1]
- [ ] [Required element 2]

**Must-not:**
- [ ] [Prohibited element 1]
- [ ] [Prohibited element 2]

**Verify:**
- [ ] [Verification check 1]
- [ ] [Verification check 2]

## Iterate

Use these refinement prompts if the output needs improvement:

1. "[Specific refinement 1 - includes numbers/metrics]"
2. "[Specific refinement 2 - includes action directive]"
3. "[Specific refinement 3 - includes format/structure change]"
````

Generation rules: each section must be self-contained (understandable without reading other
sections); use specific numbers ("5 sentences" not "short"; "1 page" not "moderate"); iterate
prompts must be context-aware, not generic "make it better"; the body must be copy-paste ready —
no meta-commentary or instructional text inside it.

## Domain-Specific Gap Patterns

Common gaps by domain with default remediation:

| Domain | Commonly missing | Default remediation |
|--------|-----------------|-------------------|
| **Development** | References (code style), Evaluate (test criteria) | Match existing codebase patterns, include test cases |
| **Marketing** | Context (target persona), Evaluate (conversion criteria) | Define persona, add CTA verification |
| **Education** | References (difficulty samples), Iterate (learning progression) | Separate beginner/intermediate, add step-by-step deepening |
| **Documents** | Context (reader level), References (existing templates) | Distinguish exec/practitioner, reference company templates |
| **Translation** | References (glossary), Evaluate (consistency) | Unify technical terms, verify tone consistency |
