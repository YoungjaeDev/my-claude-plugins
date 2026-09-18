# Issue body template

The `### Description` section of the SKILL.md Issue Template. Content depth rules (behaviour-level, no code snippets) stay in SKILL.md "Issue Content Depth".

### Description
<!-- TDD: enabled --> (Add this marker if TDD was selected in Step 3)

**Purpose**: [Why this is needed]

**Implementation Steps** (in order):
1. [ ] Step 1 - description with specific details
2. [ ] Step 2 - description with specific details
3. [ ] Step 3 - description with specific details

**결정 사항** (settled during decomposition, Decision 13; resolve-issue must not have to ask):
- [Test seam, design decision, or scope boundary already decided, and what was decided]

**테스트 seam** (only when TDD is enabled): the public interface / boundary the tests for this
issue assert through. This is what `resolve-issue`'s TDD branch reads as the agreed seam.

**Open questions**: anything genuinely still undecided that implementation must surface, not
silently resolve on its own.

**시작점 힌트** (starting-point hints, not a file-by-file change list):
- `path/filename` - what area of the code this touches

**Completion criteria** (user-facing acceptance criteria):
- [ ] Acceptance criterion 1, stated as observable behaviour from the user's perspective
- [ ] Acceptance criterion 2

**Dependencies**:
- [ ] None or prerequisite issue #number

**References** (optional):
- Add related PRs if available (e.g., PR #36 - brief description)
- Omit this section if none
