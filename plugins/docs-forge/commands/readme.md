---
name: readme
description: Generate or analyze README files with CRO best practices
argument-hint: "[generate|analyze] [--type TYPE]"
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Task
  - Skill
---

# README Command

Generate or analyze README files using patterns from awesome-readme.

## Arguments

- `generate` - Create new README from template
- `analyze` - Analyze existing README and suggest improvements

## Options

- `--type TYPE` - Project type for generation:
  - `cli` - Command-line tool
  - `library` - npm/pip package
  - `react-component` - React UI component
  - `mcp-plugin` - Claude Code plugin
  - `saas` - Web application
  - `desktop` - Desktop application

## Instructions

### For `generate`

1. Determine project type from argument or by analyzing project structure
2. Read the appropriate template from `references/TEMPLATES.md`
3. Gather project info:
   - Package name from package.json, setup.py, Cargo.toml, etc.
   - Description from package config
   - Existing commands/API
4. **Generate visual assets** using `/midjourney-imagineapi` skill:
   - **Logo**: Create project logo (square, minimal, tech-style)
   - **Banner**: Create header banner (wide format, includes project name)
   - Save to `assets/logo.png` and `assets/banner.png`
   - Use project name and description for prompt context
5. Generate README customized for the project
6. Apply CRO best practices from `references/CRO_CHECKLIST.md`

### For `analyze`

1. Read existing README.md
2. Check against patterns in `references/README_PATTERNS.md`
3. Evaluate using `references/CRO_CHECKLIST.md`
4. Provide specific improvement suggestions with examples
5. Score each category:
   - Header (logo, badges, tagline)
   - Quick Start (time to first success)
   - Features (benefit-oriented)
   - Examples (progressive complexity)
   - Trust signals (social proof, transparency)

## Output Format

### For generate

Write README.md to project root with:
- Appropriate template structure
- Placeholder comments for user to fill
- All CRO elements included

### For analyze

Provide markdown report:
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

When generating README, create logo and banner using `/midjourney-imagineapi` skill.

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
