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

Install the skill (`npx skills`, wrapped by the repo's installer):

```bash
node scripts/install-skills.mjs                                             # interactive picker
npx skills add YoungjaeDev/my-claude-plugins -a hermes-agent -s tcrei-prompt -g
```

It lands in `~/.hermes/skills/tcrei-prompt/`, which Hermes indexes automatically — it shows up in `skills_list()` and as a slash command under its **flat** name `tcrei-prompt`, not `tcrei-prompt:tcrei-prompt`.

The skill body carries a Hermes compatibility table mapping Claude/Codex tool terms (`Write`, `AskUserQuestion`, `Read`) to Hermes tools (`write_file`, `clarify`, `read_file`). Phase 3 self-verification runs inline (no `Task`/subagent) so it is portable across all three runtimes.
