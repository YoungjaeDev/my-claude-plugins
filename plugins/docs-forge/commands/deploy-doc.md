---
name: deploy-doc
description: Generate or restructure a client-facing deployment / procedure document with a consistent skeleton (summary + prerequisites checklist + numbered steps)
argument-hint: "[generate|rewrite] [path]"
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Skill
---

# Deploy Doc Command

Produce a consistent client-facing deployment / procedure document (`.md`): a top-of-file summary, a prerequisites checklist, and numbered procedure steps. The enforceable skeleton lives in the `deploy-doc-guide` skill (the cross-runtime SSOT); this command orchestrates Read/Write around it.

## Arguments

- `generate` - Author a new procedure doc from collected input.
- `rewrite` - Restructure an existing `.md` into the skeleton, preserving its content.

## Options

- `--title TITLE` - Document title (the `# H1`). If omitted, ask or infer from input.
- `--lang ko|en` - Output language. Default `ko`.
- `--links <doc1,doc2>` - SSOT documents the procedure links to instead of redefining (detailed contracts / specs that must NOT be inlined).

## Instructions

### For `generate`

1. Load the `deploy-doc-guide` Skill — its `## Quick Reference` is the binding skeleton + self-verify checklist.
2. Collect: title, a 2-3 line core summary, prerequisite items, and the ordered procedure steps.
3. Emit the skeleton in this order:
   - Top-of-file **untitled** summary paragraph (2-3 lines, no heading).
   - `## 전제조건` (or `## Prerequisites` for `--lang en`) — every item as a `- [ ]` checklist line.
   - `## 절차` (or `## Procedure`) — each step as `### 1.` / `### 2.` / `### N.`, contiguous numbering from 1.
4. **Number-match rule**: the count of steps named/implied in the summary MUST equal the number of `### N.` headings.
5. **Link, don't redefine**: detailed contracts and SSOT details go to the `--links` documents as links; never inline them.

### For `rewrite`

1. Read the target file.
2. Map existing content onto the skeleton:
   - Move redefined contracts/specs to links (demote inline contracts to `--links` references).
   - Renumber procedure prose into contiguous `### N.` headings.
   - Lift or synthesize the 2-3 line summary to the top as an untitled paragraph.
3. Preserve original prose **verbatim where possible** — this is a surgical restructure, not a rewrite of wording.

## Output Format

Write the document to the given `path`. Then print a compliance summary:

```
deploy-doc <generate|rewrite> -> <path>

Summary lines: N (expect 2-3)
Checklist items: N
### N. steps: N
Summary/body number match: PASS | FAIL
```

Report FAIL explicitly when the summary's step count and the `### N.` heading count differ — do not silently reconcile.
