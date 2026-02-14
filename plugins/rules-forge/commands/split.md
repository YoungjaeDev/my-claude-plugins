---
name: split
description: Extract rules from existing CLAUDE.md to .claude/rules/ without interview workflow
---

# Split CLAUDE.md

Quick command to extract modular rules from an existing monolithic CLAUDE.md file without interactive interview. Ideal for fast restructuring when you want automatic extraction.

## Usage

```bash
/rules-forge split [--dry-run] [--threshold LINES]
```

### Flags

| Flag | Description | Default |
|------|-------------|---------|
| `--dry-run` | Show proposed changes without writing files | false |
| `--threshold N` | Only extract sections with N+ lines | 10 |

## What It Does

1. **Reads** current CLAUDE.md
2. **Analyzes** content structure
3. **Identifies** extractable sections
4. **Creates** .claude/rules/ directory
5. **Extracts** sections to individual rule files
6. **Updates** root CLAUDE.md with @import references
7. **Preserves** all original content

## Automatic Detection

The command automatically detects and extracts:

### Section Types

| Pattern | Extracted To | Detection |
|---------|--------------|-----------|
| Architecture/Design sections | `architecture.md` | Headers with "Architecture", "Design", "Structure" |
| Testing procedures | `testing.md` | Headers with "Test", "QA", "Verification" |
| Data processing rules | `data.md` | Headers with "Data", "Processing", "Pipeline" |
| API/Backend rules | `api.md` | Headers with "API", "Backend", "Routes" |
| Frontend/UI rules | `frontend.md` | Headers with "Frontend", "UI", "Components" |
| Deployment procedures | `deployment.md` | Headers with "Deploy", "Release", "CI/CD" |
| Security guidelines | `security.md` | Headers with "Security", "Auth", "Permissions" |

### Content Classification

**Stays in Root:**
- Project overview (<20 lines)
- Operational commands
- Critical safety rules (marked "Immutable" or "Critical")
- Emergency protocols

**Extracted to Rules:**
- Detailed guidelines (>threshold lines)
- Framework-specific patterns
- Tool configurations
- Testing procedures
- Deployment checklists

## Example Output

### Before Split

```
./CLAUDE.md (950 lines)
  - Project overview (15 lines)
  - Commands (30 lines)
  - Architecture rules (180 lines)
  - Data processing (140 lines)
  - API guidelines (160 lines)
  - Testing procedures (220 lines)
  - Deployment checklist (120 lines)
  - Security rules (85 lines)
```

### After Split

```
./CLAUDE.md (120 lines)
  - Project overview (15 lines)
  - Commands (30 lines)
  - Critical rules (25 lines)
  - @import directives (6 lines)
  - Quick reference (20 lines)

.claude/rules/
  - architecture.md (180 lines)
  - data.md (140 lines)
  - api.md (160 lines)
  - testing.md (220 lines)
  - deployment.md (120 lines)
  - security.md (85 lines)
```

## Workflow Example

### Default Split

```bash
/rules-forge split

# Output:
# Analyzing CLAUDE.md (950 lines)...
#
# Extracting sections:
#   → architecture.md (180 lines)
#   → data.md (140 lines)
#   → api.md (160 lines)
#   → testing.md (220 lines)
#   → deployment.md (120 lines)
#   → security.md (85 lines)
#
# Updating root CLAUDE.md...
#   950 → 120 lines (-87% reduction)
#
# Done! 6 rule files created.
```

### Dry Run

```bash
/rules-forge split --dry-run

# Output:
# [DRY RUN] No files will be written.
#
# Proposed changes:
#
# ./CLAUDE.md
#   Lines 1-45: Keep (project overview + commands)
#   Lines 50-80: Keep (critical safety rules)
#   Lines 85-265: Extract → .claude/rules/architecture.md
#   Lines 270-410: Extract → .claude/rules/data.md
#   ...
#
# New @import section:
#   See @.claude/rules/architecture.md for design patterns
#   See @.claude/rules/data.md for data processing
#   ...
#
# Run without --dry-run to apply changes.
```

### Custom Threshold

```bash
/rules-forge split --threshold 20

# Only extract sections with 20+ lines
# Smaller sections stay in root
```

## Behind the Scenes

This command uses the `rules-guide` skill in non-interactive mode:

```typescript
// Pseudo-code
const content = await readFile('CLAUDE.md');
const sections = parseMarkdownSections(content);

const extractable = sections.filter(s =>
  s.lines >= threshold &&
  !isCritical(s) &&
  !isOperational(s)
);

for (const section of extractable) {
  const filename = classifySection(section);
  await createRuleFile(`.claude/rules/${filename}`, section.content);
}

await updateRootWithImports(extractable);
```

## Path-Specific Rules

Automatically generates `paths:` frontmatter when directory patterns are detected:

```markdown
# Before (in root):
## API Development
- All routes in src/api/
- Use error middleware
- Validate all inputs

# After (.claude/rules/api.md):
---
paths: src/api/**/*.ts
---

# API Development Rules
- Use error middleware
- Validate all inputs
```

## Verification

After split, the command verifies:

| Check | Requirement |
|-------|-------------|
| Root size | <200 lines |
| Rule file size | <500 lines each |
| Content preservation | All original content exists in root or rules |
| Import references | All extracted files have @import in root |

## Best Practices

1. **Run dry-run first** to preview changes
2. **Commit before split** so you can revert if needed
3. **Review extracted files** for accuracy
4. **Adjust threshold** if default extraction is too aggressive

## Comparison: split vs. generate

| Feature | split | generate --restructure |
|---------|-------|------------------------|
| Speed | Fast (automatic) | Slower (interactive) |
| Control | Minimal | Full control |
| Interview | No | Yes |
| Customization | Limited | Extensive |
| Best for | Quick cleanup | Careful reorganization |

## See Also

- `/rules-forge generate --restructure` - Interactive restructuring with interview
- `rules-guide` skill - Underlying implementation
- `claude-md-management` - Update individual rules after split
