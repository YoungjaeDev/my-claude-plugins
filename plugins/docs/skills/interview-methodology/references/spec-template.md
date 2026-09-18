# Spec Output Format

Full template for the "Interview Completion" full-spec path in
`SKILL.md`.

**File path**: `.claude/spec/{YYYY-MM-DD}-{feature-name}.md`

**Examples**:
- `.claude/spec/2026-01-20-dark-mode.md`
- `.claude/spec/2026-01-20-api-rate-limiting.md`

After interview completion, write a spec file with:

```markdown
# Feature Specification: [Feature Name]

## Overview
[1-2 sentence summary]

## User Stories
- As a [user type], I want [goal] so that [benefit]

## Requirements

### Must Have (P0)
- [ ] Requirement 1
- [ ] Requirement 2

### Should Have (P1)
- [ ] Requirement 3

### Nice to Have (P2)
- [ ] Requirement 4

## Technical Constraints
- [List technical requirements and limitations]

## UI/UX Requirements
- [List interface requirements]

## Edge Cases
| Scenario | Expected Behavior |
|----------|------------------|
| Case 1   | Behavior 1       |

## Testing Decisions
- **Seam**: [the public interface/boundary tests assert through]
- **Behavior under test**: [what this seam must do, in observable terms]
- **Excluded**: [what this spec deliberately does not test, and why]

## Out of Scope
- [Explicitly list what this feature does NOT include]

## Open Questions
- [Any unresolved items for future discussion]
```
