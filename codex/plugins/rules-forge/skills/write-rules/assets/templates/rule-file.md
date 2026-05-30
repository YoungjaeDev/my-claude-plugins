<!--
Template: Single .codex/rules/*.md skeleton.

Use: write-rules skill Read s this when generating any new rule file
across NEW / SPLIT / REORGANIZE modes. Skill picks Variant A or B
based on whether the rule has a clear path boundary.

Both variants follow the Role / Do / Don't / Source of Truth shape —
the style proven in this repo's own .codex/rules/codex-bridge-sync.md
and plugin-versioning.md.
-->

## Variant A — Path-scoped rule (default for domain-specific guidance)

```markdown
---
paths:
  - "{{glob 1}}"
  - "{{glob 2}}"
---

# {{Topic}}

## Role

{{One sentence: what this rule's responsibility is in the project.
   Example: "Defines the dependency direction and layering invariants
   for the API service layer."}}

## Do

- {{Imperative statement, verifiable. Example: "Inject repository
   interfaces via constructor; never call new Repository() inside
   use cases."}}
- {{...}}
- {{...}}

## Don't

- {{Imperative anti-statement. Example: "Don't import Next.js types
   from src/core/domain/. The domain layer must remain
   framework-agnostic."}}
- {{...}}
- {{...}}

## Examples

{{Optional code blocks. Only include if the Do/Don't items benefit
   from a concrete shape. Skip otherwise.}}

```{{language}}
{{code example}}
```

## Source of Truth

- {{Link to canonical spec, file, or doc. Example: "docs/architecture/api-layering.md"}}
```

## Variant B — Always-load rule (universal guidance)

```markdown
# {{Topic}}

## Role

{{One sentence. Example: "Tech-stack rules for tooling that applies
   repo-wide regardless of file path."}}

## Do

- {{...}}
- {{...}}

## Don't

- {{...}}
- {{...}}

## Source of Truth

- {{...}}
```

Variant B omits the frontmatter block entirely — `.codex/rules/*.md`
files with no `paths:` field always load at session start.

## When to choose which variant

| Choose Variant A (path-scoped) when | Choose Variant B (always-load) when |
|---|---|
| Rule applies to a specific subdirectory or file pattern | Rule applies repo-wide regardless of file |
| Following the rule requires reading project-specific code structure | Rule is a top-level convention (e.g., commit format, language choice) |
| Loading cost matters (rule body is long) | Rule is short (≤30 lines) and broadly applicable |

## Size guidance

- Target ≤150 lines per rule file. Longer files reduce LLM compliance.
- If a topic naturally exceeds 200 lines, split into sub-rules with
  more specific `paths:` globs rather than one mega-file.
- Code examples count toward line budget — prefer 1-2 minimal
  examples over exhaustive coverage.

## Frontmatter glob reference

`paths:` accepts a YAML list or comma-separated string. Common patterns:

| Pattern | Matches |
|---|---|
| `"src/api/**/*.ts"` | All TS files anywhere under src/api/ |
| `"src/**/*.{ts,tsx}"` | Both TS and TSX under src/ |
| `"tests/**/*.test.ts"` | Test files only |
| `"scripts/run_*.py"` | Specific script naming pattern |

Multi-pattern arrays match the union — a file matching any glob loads
the rule.
