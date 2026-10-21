---
name: aside
description: Delegate browser tasks to the Aside specialist, or continue a recorded Aside task after login.
argument-hint: "<task, request.json path, or continue request-id>"
context: fork
agent: aside:operator
background: false
---

Execute this user's browser request using the preloaded browser-ops procedure:

$ARGUMENTS

If this is a continuation, locate the exact prior request and saved Aside session; if several waiting tasks match, ask the parent which one. In a forked skill you do not inherit the parent's full conversation: use the explicit task and records, never guessed context. For a new task, record scope and observable success criteria before browser action.

Return verified results or a persistent `waiting_for_user` handoff. Do not delegate again or recursively call this entry skill. Do not register MCPs or change browser defaults.
