# Interactive-Input Gate Best Practices (Claude: AskUserQuestion)

Worked examples for the "Interactive-Input Gate Best Practices"
section of `SKILL.md`.

### Structure Questions with Options
```
Question: "How should the system handle authentication failures?"
Options:
1. Show error and retry (simple)
2. Lock account after 3 attempts (secure)
3. Send email notification (audit trail)
4. Custom handling...
```

### Use multiSelect for Non-Exclusive Choices
```
Question: "Which platforms need to be supported?"
multiSelect: true
Options:
1. Web browser
2. iOS app
3. Android app
4. Desktop app
```

### Provide Context in Descriptions
Each option should explain implications, not just the choice itself.
