---
name: readme
description: Generate a new README.md from a CRO-optimized template, or analyze and improve an existing README. Picks a template by project type (cli, library, react-component, mcp-plugin, saas, desktop) and applies conversion-rate-optimization best practices. Use when the user wants to write, create, generate, audit, or improve a README file (e.g. "generate a README", "write a README for this CLI", "review/score my README", "improve the README"). This produces or edits the file; for patterns reference only, see the readme-guide skill.
---

# README

Generate or analyze README files using patterns from awesome-readme. This skill
writes/edits files and may generate visual assets — confirm intent when ambiguous.

## Infer the action

There is no explicit argument string — infer the operation and project type from
the user's request and the project:

| Intent | Operation |
|--------|-----------|
| "write / create / generate a README" | `generate` |
| "analyze / review / score / improve my README" | `analyze` |

For `generate`, determine the project type from the request or by analyzing the
project structure: `cli`, `library`, `react-component`, `mcp-plugin`, `saas`,
`desktop`.

## Instructions

### generate

1. Determine project type from the request or by analyzing project structure
2. Read the appropriate template from `../../references/TEMPLATES.md`
3. Gather project info:
   - Package name from package.json, setup.py, Cargo.toml, etc.
   - Description from package config
   - Existing commands/API
4. **Generate visual assets** via the `midjourney-imagineapi` skill (only if the
   user wants visuals — image generation is a side effect, so confirm first):
   - **Logo**: project logo (square, minimal, tech-style)
   - **Banner**: header banner (wide format, includes project name)
   - Save to `assets/logo.png` and `assets/banner.png`
5. Generate the README customized for the project
6. Apply CRO best practices from `../../references/CRO_CHECKLIST.md`

### analyze

1. Read existing README.md
2. Check against patterns in `../../references/README_PATTERNS.md`
3. Evaluate using `../../references/CRO_CHECKLIST.md`
4. Provide specific improvement suggestions with examples
5. Score each category: Header, Quick Start, Features, Examples, Trust signals

## Output Format

### generate

Write README.md to the project root with the appropriate template structure,
placeholder comments for the user to fill, and all CRO elements included.

### analyze

```markdown
## README Analysis

### Score: X/10

### Strengths
- ...

### Improvements Needed
- [ ] Issue 1 - Suggested fix
- [ ] Issue 2 - Suggested fix

### Quick Wins
1. ...
2. ...
```

## Visual Assets Generation

When generating a README with visuals, create logo and banner via the
`midjourney-imagineapi` skill.

### Logo Guidelines
- **Style**: Minimal, modern, tech-focused
- **Format**: Square (1:1 ratio)
- **Prompt template**: `minimal tech logo for [project-name], [project-domain] tool, clean vector style, single color accent, white background --ar 1:1 --style raw`

### Banner Guidelines
- **Style**: Wide header with project branding
- **Format**: Wide (3:1 or 4:1 ratio)
- **Prompt template**: `tech product banner for [project-name], [tagline], modern gradient background, minimal design, dark theme --ar 3:1 --style raw`

### Asset Placement

```markdown
<p align="center">
  <img src="assets/banner.png" alt="Project Banner" width="100%">
</p>

<p align="center">
  <img src="assets/logo.png" width="120" alt="Project Logo">
</p>
```
