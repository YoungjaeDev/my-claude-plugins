# Anti-Slop Design Plugin

Anti-AI-slop design guard for web/SaaS landing, decks (PPT), dashboards, and copy. Runs a clarify->context->plan->run->audit->revise flow with a two-phase audit gate; hands Korean copy rewriting to humanize-korean.

## Skills

| Skill | Description |
|-------|-------------|
| `/anti-slop-design:anti-slop-design` | Anti-AI-slop design guard for websites/SaaS landing, presentation decks (PPT), dashboards/admin UI, and marketing/UI copy — clarify->context->plan->run->audit->revise flow with two-phase audit gate and Korean copy handoff to humanize-korean |

## Hermes Agent

Install this plugin from the monorepo subdirectory:

```bash
hermes plugins install YoungjaeDev/my-claude-plugins/plugins/anti-slop-design --enable
hermes gateway restart  # if using Hermes through a messaging gateway
```

Load the skill explicitly (Hermes plugin skills are opt-in; start a fresh Hermes session after `--enable`):

```text
skill_view("anti-slop-design:anti-slop-design")
```

The skill body carries a Hermes compatibility table mapping Claude/Codex tool terms (`AskUserQuestion`, `Read`, `Skill`) to Hermes tools (`clarify`, `read_file`, `skill_view`). The Korean-copy handoff to `humanize-korean` runs via `skill_view("humanize-korean:humanize-korean")` under Hermes.
