# Question Option Examples

Two worked examples for the question tool in `SKILL.md` (`AskUserQuestion` on Claude Code, `request_user_input` on Codex). Each option explains its implication, not just the choice.

## Structure questions with options

```
Question: "How should the system handle authentication failures?"
Options:
1. Show error and retry (simple)
2. Lock account after 3 attempts (secure)
3. Send email notification (audit trail)
4. Custom handling...
```

## Use multiSelect for non-exclusive choices

```
Question: "Which platforms need to be supported?"
multiSelect: true
Options:
1. Web browser
2. iOS app
3. Android app
4. Desktop app
```
