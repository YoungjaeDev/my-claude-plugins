# Slidev Plugin

Slidev markdown presentation generator plugin.

## Skill

| Skill | Description |
|-------|-------------|
| `create-slide` | Generate Slidev presentations through interview workflow |

## Triggers

- "create a slide"
- "make a presentation"
- "build a deck"
- "presentation"
- "slidev"

## Workflow

1. **Auto-detect**: Check if Slidev project exists
2. **Setup** (if needed): `npm init slidev@latest` + theme installation
3. **Interview**: Gather topic, audience, duration, structure, code/diagrams needs, theme, tone
4. **Generate**: Create slides.md based on interview results
5. **Review**: Show slide structure summary + execution commands

## Themes

| Theme | Style |
|-------|-------|
| `apple-basic` (default) | Apple Keynote, minimal |
| `seriph` | Serif fonts, classic |
| `vercel` | Dark, modern |
| `purplin` | Purple gradient, vibrant |
| `academic` | Academic paper style |
| `bricks` | Block-based, structural |

## Standard Slide Flow

Cover -> Agenda -> Section 1 -> ... -> Section N -> Summary -> Q&A

## Key Principles

- Default to user's language, keep technical terms in original form
- Anti-AI writing: Remove exaggerated/promotional/AI vocabulary, use concrete and direct expressions
- Real-time Slidev documentation lookup via mcpdocs/deepwiki

## Requirements

- Register Slidev docs source in mcpdocs (`slidev:https://sli.dev/llms.txt`)
- deepwiki MCP server (optional)
