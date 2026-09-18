# Question Framework by Category

Supporting detail for the Core Principle (Non-Obvious Questions) and
Phase 2 (Deep Dive) of the interview flow in `SKILL.md`.

### Bad Questions (Obvious)
- "What feature do you want?" (they already told you)
- "Do you want it to work well?" (obviously yes)
- "Should it be fast?" (obviously yes)

### Good Questions (Non-Obvious)
- "What happens when X fails? Should it retry, fail silently, or notify?"
- "Who else might use this besides you? Do they have different needs?"
- "What's the worst thing that could happen if this feature misbehaves?"

## Question Framework by Category

### 1. Technical Implementation
- What existing systems does this need to integrate with?
- Are there performance constraints (response time, memory, etc.)?
- What's the expected scale? 10 users or 10,000?
- Are there security or compliance requirements?
- Should this work offline? On mobile?
- What happens during network failures or timeouts?

### 2. User Interface & Experience
- Who are the different user personas interacting with this?
- What's the primary device/platform? Secondary?
- Are there accessibility requirements?
- What's the user's technical proficiency level?
- What should happen on errors - technical message or friendly guidance?
- Are there existing UI patterns in the app this should follow?

### 3. Edge Cases & Error Handling
- What inputs are considered invalid? How should they be handled?
- What if the user does X when they should do Y?
- What's the behavior when data is missing or malformed?
- How should concurrent/conflicting operations be handled?
- What are the failure modes and recovery strategies?

### 4. Constraints & Tradeoffs
- What's more important: speed of delivery or completeness?
- Are there budget/resource limitations?
- What can we cut if we run out of time?
- What's the minimum viable version vs. ideal version?
- Are there dependencies on other teams or systems?

### 5. Business Context
- Why is this feature needed now?
- What problem does this solve for the business?
- How will success be measured?
- What's the cost of NOT doing this?
- Are there regulatory or legal considerations?
