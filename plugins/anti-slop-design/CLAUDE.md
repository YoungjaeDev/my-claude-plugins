# Anti-Slop Design Plugin

Anti-AI-slop design guard for web/SaaS landing, decks (PPT), dashboards, and copy. Runs a clarify->context->plan->run->audit->revise flow with a two-phase audit gate; hands Korean copy rewriting to humanize-korean.

## Skills

| Skill | Description |
|-------|-------------|
| `/anti-slop-design:anti-slop-design` | Anti-AI-slop design guard for websites/SaaS landing, presentation decks (PPT), dashboards/admin UI, and marketing/UI copy — clarify->context->plan->run->audit->revise flow with two-phase audit gate and Korean copy handoff to humanize-korean |

## Hermes Agent

Install the skill (`npx skills`, wrapped by the repo's installer):

```bash
node scripts/install-skills.mjs                                              # interactive picker
npx skills add YoungjaeDev/my-claude-plugins -a hermes-agent -s anti-slop-design -g
```

It lands in `~/.hermes/skills/anti-slop-design/`, which Hermes indexes automatically — it shows up in `skills_list()` and as a slash command under its **flat** name `anti-slop-design`, not `anti-slop-design:anti-slop-design`.

The skill body carries a Hermes compatibility table mapping Claude/Codex tool terms (`AskUserQuestion`, `Read`, `Skill`) to Hermes tools (`clarify`, `read_file`, `skill_view`). The Korean-copy handoff runs against the separately-installed `humanize-korean` skill.
