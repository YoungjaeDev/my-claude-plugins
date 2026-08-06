# TCREI Domain Patterns

Domain-specific TCREI application patterns with complete before/after examples.
Based on Google's Prompting Essentials (Coursera) TCREI framework.

## 1. Software Development

### Task Patterns
```
Verbs: write, refactor, test, migrate, debug, optimize
Outputs: 3 unit tests, API endpoint, migration script, PR description
Constraints: Jest conventions, REST spec, backward compatibility, <200ms response
```

### Context Patterns
```
Audience: junior dev / senior reviewer / CI/CD pipeline
Purpose: bug fix / new feature / performance improvement
Source: existing code patterns, error logs, requirements doc
```

### References Patterns
```
Style: follow existing codebase conventions
Sample: reference similar existing implementation
Schema: API response JSON schema
```

### Evaluate Patterns
```
Must-have: type safety, error handling, 80%+ test coverage
Must-not: any types, leftover console.log, hardcoded values
Verify: build passes, lint passes, existing tests unbroken
```

### Iterate Patterns
```
"Switch error handling from try-catch to Result pattern"
"Rename variables from camelCase to snake_case throughout"
"Add 2 edge case test scenarios"
```

### Complete Example

**Original**: "Build a login API"

**TCREI Transformation**:
```
## Task
Write a JWT-based login API endpoint.
- Output: POST /api/auth/login endpoint
- Format: Express.js router + controller separation
- Constraints: <200ms response time, proper HTTP status codes

## Context
- Audience: Called from a frontend SPA
- Purpose: User authentication and session management
- Source: Existing User model schema (users table)

## References
- Response schema:
  { "token": "string", "expiresIn": "number", "user": { "id": "string", "email": "string" } }
- Error response: { "error": "string", "code": "string" }
- Match existing signup API patterns in the codebase

## Evaluate
Must-have: bcrypt password verification, JWT expiry config, input validation
Must-not: plaintext password storage, SQL-injectable queries, stack traces in error responses
Verify: wrong password returns 401, unknown email returns 404, success returns 200 + token

## Iterate
1. "Add rate limiting at 5 requests per minute per IP"
2. "Extract refresh token logic into a separate module"
3. "Log failed login attempts to a dedicated audit table"
```

---

## 2. Marketing / Content

### Task Patterns
```
Verbs: write, compare, plan, draft
Outputs: intro copy, persona comparison table, campaign brief
Constraints: under 200 words, markdown, include 1 CTA
```

### Context Patterns
```
Audience: beginner developers / marketing managers / decision makers
Purpose: course promotion / product intro / brand awareness
Source: course curriculum, product specs, competitor analysis
```

### References Patterns
```
Tone: "Learn the essentials fast and apply them in real projects" (friendly + professional)
Format: bullet-point driven, no hype
Sample: provide 2 successful past examples
```

### Evaluate Patterns
```
Must-have: audience specified, 3 key points, 1 CTA
Must-not: exaggeration, unsourced statistics, hollow buzzwords like "revolutionary"
Verify: understandable by a beginner, CTA points to a specific action
```

### Complete Example

**Original**: "Write a course intro"

**TCREI Transformation**:
```
## Task
Write an introductory blurb for a NestJS file upload course.
- Output: Markdown copy
- Length: 5 sentences max
- Tone: beginner-friendly, warm but professional

## Context
- Audience: Junior backend developers (< 6 months experience)
- Purpose: Udemy course landing page description
- Source: Course covers Multer setup, S3 upload, input validation, security tips

## References
Style: short, fact-driven. No hype.
Tone samples:
> "Learn the core concepts fast and apply them in real projects right away."
> "Every term comes with a plain-language explanation so beginners can follow along."

## Evaluate
Must-have: mention target audience (juniors), list 3 key features, include 1 CTA
Must-not: "revolutionary", "perfect", or other hype adjectives; no pricing/discount mentions
Verify: a non-developer should understand what the course teaches

## Iterate
1. "Cut to 4 sentences or fewer"
2. "Remove filler adjectives; keep only facts"
3. "Make the final CTA explicitly say 'click enroll now'"
```

---

## 3. Documents / Reports

### Task Patterns
```
Verbs: summarize, convert, organize, extract
Outputs: 5-sentence summary, 6-slide outline, action item table
Constraints: markdown, table format, use real names
```

### Context Patterns
```
Audience: executives / team leads / external partners
Purpose: decision support / progress sharing / approval request
Source: full meeting transcript, original report, project docs
```

### Evaluate Patterns
```
Must-have: owner real names, deadlines, status (in-progress/done/delayed)
Must-not: speculative timelines, unassigned owners left blank
Verify: table has 3+ rows, empty values show TBD, dates in YYYY-MM-DD
```

### Complete Example

**Original**: "Summarize the meeting notes"

**TCREI Transformation**:
```
## Task
Summarize the meeting notes below into 5 bullet points and create an action item table.
- Output: Markdown summary + table
- Format: bullets (summary) + table (owner / item / deadline / status)
- Constraints: table must have 3+ rows

## Context
- Audience: Team members who missed the meeting
- Purpose: Share launch timeline review outcomes
- Source: [Attach full meeting transcript below]

## References
Table columns: | Owner | Action Item | Deadline | Status |
Status values: In-progress / Done / Delayed / TBD
Empty value rule: always fill with TBD

## Evaluate
Must-have: real names for owners, YYYY-MM-DD for deadlines, status from the 4 allowed values
Must-not: "someone", "soon", "if possible" or other vague language
Verify: every action item has both an owner and a deadline

## Iterate
1. "Add a Priority column with P0/P1/P2 labels"
2. "Reduce summary to 3 bullet points"
3. "Add a Reason column for delayed items"
```

---

## 4. Education / Learning

### Task Patterns
```
Verbs: explain, create, compare, design
Outputs: 3 learning objectives + 1 example, 5-question quiz, curriculum outline
Constraints: beginner level, include hands-on exercises
```

### Context Patterns
```
Audience: students / self-learners / workshop participants
Purpose: teach a concept / assess understanding / structure a course
Source: textbook chapter, documentation, lecture notes
```

### Evaluate Patterns
```
Must-have: learning objectives stated, runnable examples, difficulty level marked
Must-not: unexplained jargon, non-executable code snippets
Verify: a beginner can follow the examples step-by-step, content matches learning objectives
```

### Complete Example

**Original**: "Teach React hooks"

**TCREI Transformation**:
```
## Task
Create a tutorial explaining React hooks (useState, useEffect, useContext).
- Output: Markdown tutorial with code examples
- Length: 3 sections, each with 1 runnable example
- Constraints: beginner level, no class component comparisons

## Context
- Audience: Frontend beginners who know HTML/CSS/JS basics
- Purpose: Self-paced online tutorial
- Source: React 18 official documentation

## References
Style: step-by-step with numbered instructions
Each section follows: concept explanation -> code example -> expected output
Code format: JSX with comments explaining each line

## Evaluate
Must-have: 3 learning objectives at the top, all code examples are copy-paste runnable
Must-not: unexplained technical terms, deprecated patterns (componentDidMount etc.)
Verify: a beginner with only HTML/JS knowledge can follow without external references

## Iterate
1. "Add a 'Common Mistakes' subsection to each hook section"
2. "Include a mini-project at the end combining all 3 hooks"
3. "Add TypeScript versions of each code example"
```

---

## 5. Translation / Localization

### Task Patterns
```
Verbs: translate, localize, adapt
Outputs: Korean translation, localized landing page copy
Constraints: preserve technical terms in original language, natural target language
```

### References Patterns
```
Glossary: { "repository": "repository (keep original)", "commit": "commit (keep original)", "pull request": "pull request (keep original)" }
Tone: official documentation style / blog-friendly style
```

### Evaluate Patterns
```
Must-have: consistent technical terminology, original meaning preserved
Must-not: meaning-altering paraphrasing, translationese (unnatural literal translations)
Verify: glossary terms are consistent across the entire document
```

### Complete Example

**Original**: "Translate the README to Korean"

**TCREI Transformation**:
```
## Task
Translate the following English README into Korean.
- Output: Korean markdown document
- Format: preserve all code blocks, commands, and file paths in English
- Constraints: natural Korean, not literal translation

## Context
- Audience: Korean-speaking developers
- Purpose: Make the project accessible to Korean open-source community
- Source: [Attach original README below]

## References
Glossary:
- "repository" -> keep as "repository" or use accepted term
- "pull request" -> keep as "pull request"
- "deploy" -> keep as "deploy"
Tone: friendly technical writing, not formal/stiff

## Evaluate
Must-have: all original sections present, code blocks unchanged, links preserved
Must-not: translationese patterns, inconsistent term usage across sections
Verify: every glossary term is used consistently throughout the document

## Iterate
1. "Replace any remaining translationese with natural Korean phrasing"
2. "Ensure all section headers match the original structure"
3. "Add translator notes for culturally ambiguous references"
```

---

## Sources

- [Google Prompting Essentials - Coursera](https://www.coursera.org/specializations/prompting-essentials-google)
- [Google TCREI Framework - AI with Katarina](https://aiwithkatarina.com/googles-tcrei-prompting-framework/)
- [Google 9-Hour Course Takeaways - WokeWaves](https://www.wokewaves.com/posts/google-ai-prompt-engineering-course-takeaways)
- [TCREI Framework Definition - Canadian AI Guy](https://canadianaiguy.ca/definition/tcrei-framework/)
