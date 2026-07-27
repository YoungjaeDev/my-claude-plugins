---
name: tcrei-prompt
description: |
  TCREI prompt structuring tool. Rewrites rough prompts into Google's TCREI
  (Task, Context, References, Evaluate, Iterate) format so they produce
  consistent results when reused in the next session.
  Triggers: "TCREI", "structure this prompt", "prompt enhance", "make a prompt for next session",
  "rewrite as TCREI", "improve this prompt".
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
---

# TCREI Prompt Transformer

## Hermes Agent Compatibility

When this skill is loaded through Hermes as `tcrei-prompt:tcrei-prompt`, map Claude/Codex tool names to Hermes tools:

| Claude/Codex term | Hermes tool |
|---|---|
| Read | read_file |
| Write | write_file |
| AskUserQuestion | clarify |

Treat `$ARGUMENTS` as the natural-language arguments supplied when the user asks Hermes to load the skill. Installed into `~/.hermes/skills/` by `npx skills`, this skill is indexed automatically — it appears in `skills_list()` and as a slash command under its **flat** name `tcrei-prompt`.

Rewrites rough prompts into Google's TCREI 5-step structure and outputs
copy-paste-ready prompts for the next session. Based on Google's Prompting
Essentials (Coursera): Task, Context, References, Evaluate, Iterate.

## Trigger Examples

<example>
Context: User has a rough prompt and wants it structured
user: "Turn this into a TCREI prompt: write a blog post"
assistant: Loads TCREI skill, diagnoses missing elements, and starts interview.
<commentary>
Explicit TCREI keyword with a target prompt provided - direct trigger.
</commentary>
</example>

<example>
Context: User wants a reusable prompt for a future session
user: "Make a prompt I can use next time for this task"
assistant: Loads TCREI skill to produce a structured, session-transferable prompt.
<commentary>
"next time" + "prompt" signals session-transfer intent.
</commentary>
</example>

<example>
Context: User wants to improve an existing prompt
user: "This prompt gives inconsistent results, make it better"
assistant: Loads TCREI skill, diagnoses gaps, and interviews for missing elements.
<commentary>
Prompt quality improvement request - systematic TCREI restructuring.
</commentary>
</example>

## Critical Rules

1. **Use AskUserQuestion for all questions** - never ask in plain text
2. **Skip elements already present** - if Task is clear in the original, do not ask about Task
3. **Interview only missing elements** - do not ask about all 5; collect only what is missing
4. **Output must be a copy-paste-ready prompt** - not an explanation or tutorial
5. **Self-verify with OMC verifier** - auto-check quality after generation
6. **Save to file** - store the final prompt at `.claude/prompts/{YYYY-MM-DD}-{name}.md`

## Phase 0: Diagnose the Original Prompt

Analyze the user's prompt and determine which TCREI elements are present vs missing.

### Diagnosis Criteria

| Element | Present if... | Missing if... |
|---------|--------------|---------------|
| **Task** | Has 2+ of: action verb, output format, constraints | Only a vague verb ("do this", "write something") |
| **Context** | Specifies 1+ of: audience, purpose, source material | No background information at all |
| **References** | Includes samples, format specs, schemas, or tone examples | No hint about desired output shape |
| **Evaluate** | Has 1+ of: must-have, must-not, verification criteria | No quality standards defined |
| **Iterate** | Mentions improvement direction or version requests | One-shot request only |

### Diagnosis Output

Show the diagnosis to the user, then proceed to interview:

```
## TCREI Diagnosis

| Element | Status | Found |
|---------|--------|-------|
| Task | Partial | "write a blog post" - verb only, no output format or constraints |
| Context | Missing | - |
| References | Missing | - |
| Evaluate | Missing | - |
| Iterate | Missing | - |

Starting interview to fill in missing elements.
```

## Phase 1: TCREI Interview (Interview Methodology)

Interview the user for missing elements only, using AskUserQuestion.
Follow interview-methodology principles:
- No obvious questions
- Follow-up on each answer
- Provide options for easy answering

### Interview Questions by Element

#### When Task is missing

```
Question: "What output format do you need?"
Options:
1. "Markdown document" - Structured text with headers
2. "JSON / structured data" - Machine-readable, tool-friendly
3. "Free-form text" - Essay, letter, narrative
4. "Table / comparison" - Side-by-side data
```

```
Question: "Any length or format constraints?"
Options:
1. "Short (5 sentences or less)" - Key points only
2. "Medium (1 page)" - Moderate detail
3. "Long (comprehensive)" - Full coverage
4. "Specific format" - Custom input
```

#### When Context is missing

```
Question: "Who is the audience for this output?"
Options:
1. "Myself only" - Personal reference
2. "Team / colleagues" - Internal sharing
3. "Clients / customers" - External delivery
4. "General public" - Published content
```

```
Question: "What is the purpose of this task?"
Options:
1. "Inform / educate" - Help understand something
2. "Persuade / market" - Drive action
3. "Document / archive" - Record keeping
4. "Support decisions" - Aid judgment
```

#### When References are missing

```
Question: "Do you have a preferred tone or style?"
Options:
1. "Professional / formal" - Reports, official docs
2. "Friendly / conversational" - Blog, social media
3. "Concise / bullet-point" - Summaries, briefs
4. "Provide a sample" - I'll give an example
```

```
Question: "Do you want a fixed output structure? (e.g., JSON schema)"
Options:
1. "Free form" - Let AI decide the structure
2. "Fixed key structure" - JSON/YAML schema
3. "Match existing template" - Provide a file path
```

#### When Evaluate is missing

```
Question: "What must the output include?"
multiSelect: true
Options:
1. "N key points" - Specify a number
2. "Call-to-action (CTA)" - Reader should do something
3. "Data / evidence" - Sourced information
4. "Custom requirement" - Specify directly
```

```
Question: "What must the output avoid?"
multiSelect: true
Options:
1. "Exaggeration / hype" - Facts only
2. "Jargon overload" - Keep it simple
3. "Unsourced claims" - Everything needs evidence
4. "Custom restriction" - Specify directly
```

#### When Iterate is missing

Iterate instructions are auto-generated (no interview needed).
Generate 3 context-specific refinement prompts based on the assembled TCREI content.

### Interview Guidelines

1. **Max 2 questions per round** - batch into AskUserQuestion's questions array
2. **1-2 missing elements = 1 round; 3-4 missing = 2 rounds** - keep it short
3. **Cross-pollinate answers** - a Context answer may fill in Task details
4. **Follow up on "Custom" selections** - probe open-ended answers into specifics

## Phase 2: Generate TCREI Prompt

Assemble the structured prompt from collected information.

### Output Template

```markdown
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
```

### Generation Rules

1. **Each section must be self-contained** - understandable without reading other sections
2. **Use specific numbers** - "5 sentences" not "short"; "1 page" not "moderate"
3. **Iterate prompts must be context-aware** - not generic "make it better" but task-specific
4. **Must be copy-paste ready** - no meta-commentary or instructional text inside the prompt body

## Phase 3: Self-Verification (OMC Iterate)

Verify the generated prompt **inline** — the same model runs the OMC checklist directly, in this session. Do NOT dispatch this to a subagent. Three reasons the previous `Task(subagent_type="claude", model="haiku")` form was invalid and is removed:

1. **No dispatch target** — this plugin ships no `agents/` directory, so there is no verifier agent named `claude` (or otherwise) to receive the Task.
2. **Not portable** — of the three runtimes this skill runs on, only Claude Code has a subagent surface; Codex 0.135 and Hermes have none (`.claude/rules/dual-integration.md` surface map: "not supported by Codex 0.135 — Claude-only / not supported by Hermes — skills only"). A Task dispatch there **silently no-ops**, so Phase 3 would never run on 2 of 3 runtimes.
3. **Not a valid Task form** — the standard `Task` tool takes no per-call `model=` argument (a subagent's model comes from its agent-definition frontmatter) and has no built-in `claude` subagent_type (the catch-all is `general-purpose`).

The check is a 6-item pass/fail on a short prompt — there is no context-isolation win from a subagent anyway. Keeping it inline makes Phase 3 run identically on all three runtimes.

### OMC Verification Checklist

Score the generated prompt against these 6 criteria (pass threshold: **5 of 6**):

1. **Task**: has an action verb + output format + constraints?
2. **Context**: has 2+ of audience / purpose / source material?
3. **References**: has 1+ of tone / format / sample?
4. **Evaluate**: has 2+ of must-have / must-not / verify?
5. **Iterate**: has 2+ refinement prompts with specific numbers / rules / actions?
6. **Copy-paste ready**: the entire prompt body has no meta-commentary or instructional text?

For each failing criterion, name the deficient item and a specific improvement.

### On Verification Failure

1. Auto-fix the deficient items identified above.
2. Re-verify (max 2 retry rounds).
3. If still below threshold after 2 rounds, output the current state and notify the user of the remaining gaps.

## Phase 4: Final Output and Save

### Output

1. Display the completed TCREI prompt in the conversation
2. Save to `.claude/prompts/{YYYY-MM-DD}-{name}.md`
   - Create `.claude/prompts/` directory if it does not exist
   - Filename in kebab-case
3. Show verification summary:

```
## Verification Results

| Criterion | Status |
|-----------|--------|
| Task (verb + output + constraints) | Pass |
| Context (audience + purpose + source) | Pass |
| References (tone + format + sample) | Pass |
| Evaluate (must-have + must-not + verify) | Pass |
| Iterate (numbers + rules + actions) | Pass |
| Copy-paste ready | Pass |

Saved to: `.claude/prompts/2026-02-16-blog-post.md`
```

## Domain-Specific TCREI Gap Patterns

Common gaps by domain with default remediation:

| Domain | Commonly missing | Default remediation |
|--------|-----------------|-------------------|
| **Development** | References (code style), Evaluate (test criteria) | Match existing codebase patterns, include test cases |
| **Marketing** | Context (target persona), Evaluate (conversion criteria) | Define persona, add CTA verification |
| **Education** | References (difficulty samples), Iterate (learning progression) | Separate beginner/intermediate, add step-by-step deepening |
| **Documents** | Context (reader level), References (existing templates) | Distinguish exec/practitioner, reference company templates |
| **Translation** | References (glossary), Evaluate (consistency) | Unify technical terms, verify tone consistency |

Full before/after worked examples for each of these five domains — Development, Marketing, Documents, Education, Translation — with complete Task/Context/References/Evaluate/Iterate transformations, live in `references/tcrei-patterns.md`. Load it when you need a concrete pattern to model the generated prompt on.

## Interview Anti-Patterns

1. **Asking about all 5 elements** - skip what is already present; it wastes time
2. **Abstract questions** - offer concrete options instead of "what vibe do you want?"
3. **5 questions at once** - batch max 2 per AskUserQuestion call
4. **Ignoring cross-signals** - a Context answer may reveal Task or Reference details
5. **Interviewing for Iterate** - auto-generate is more effective (context-aware specifics beat generic user input)
