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

## Hermes Agent

Install this plugin from the monorepo subdirectory:

```bash
hermes plugins install YoungjaeDev/my-claude-plugins/plugins/tcrei-prompt --enable
hermes gateway restart  # if using Hermes through a messaging gateway
```

Load the skill explicitly (Hermes plugin skills are opt-in; start a fresh Hermes session after `--enable`):

```text
skill_view("tcrei-prompt:tcrei-prompt")
```

The skill body carries a Hermes compatibility table mapping Claude/Codex tool terms (`Task`, `Write`, `AskUserQuestion`, `Read`) to Hermes tools (`delegate_task`, `write_file`, `clarify`, `read_file`).
