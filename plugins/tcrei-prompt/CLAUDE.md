# TCREI Prompt Plugin

Rewrite prompts using Google's TCREI structure for next-session reuse.

## Skill

| Skill | Description |
|-------|-------------|
| `tcrei-prompt` | Diagnose missing TCREI elements, interview to fill gaps, generate copy-paste-ready prompt |

## TCREI Framework

Google's Prompting Essentials (Coursera) 5-step structure:

| Step | Purpose | Sub-elements |
|------|---------|-------------|
| Task | Define the action | verb + output + constraints |
| Context | Provide background | audience + purpose + source material |
| References | Show desired form | samples, schemas, tone examples |
| Evaluate | Set quality gates | must-have + must-not + verification |
| Iterate | Plan refinements | specific numbers, rules, actions |

## Workflow

1. Diagnose which T/C/R/E/I elements exist in the original prompt
2. Interview for missing elements using AskUserQuestion
3. Generate structured TCREI prompt
4. Self-verify with OMC verifier agent
5. Save to `.claude/prompts/{YYYY-MM-DD}-{name}.md`

## Triggers

- "TCREI"
- "structure this prompt"
- "prompt enhance"
- "make a prompt for next session"
