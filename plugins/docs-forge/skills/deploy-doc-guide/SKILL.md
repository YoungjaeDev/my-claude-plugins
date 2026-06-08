---
name: deploy-doc-guide
description: Deployment / procedure document skeleton — the binding structure for client-facing .md procedure docs (top summary + prerequisites checklist + numbered steps + number-match + link-don't-redefine). Loaded by the docs-forge deploy-doc workflow.
---

# Deploy Doc Guide

The cross-runtime SSOT for client-facing deployment / procedure documents. The `## Quick Reference` skeleton below is binding — the `deploy-doc` command and any agent must self-verify against it before writing.

## Triggers

- "배포 문서"
- "deployment doc"
- "procedure doc"
- "절차 문서"
- "client procedure doc"

## Quick Reference

The skeleton (Korean default; English labels in parentheses for `--lang en`). Each item is a self-verify checklist entry — confirm all before output:

1. **Top summary** — a 2-3 line **untitled** paragraph at the very top of the file (above the first `##`). No heading. States what is deployed and the step count at a high level.
2. **Prerequisites** — a `## 전제조건` (`## Prerequisites`) section where **every** line is a `- [ ]` checklist item. No bare prose bullets.
3. **Procedure** — a `## 절차` (`## Procedure`) section where **every** step is a `### N.` heading, numbered contiguously from `### 1.` with no gaps and no `### N.`-less prose steps.
4. **Number-match rule** — the step count named or implied in the top summary MUST equal the number of `### N.` headings. Mismatch = FAIL.
5. **Link, don't redefine** — detailed contracts, schemas, and SSOT specifics are linked (to `--links` documents), never inlined. The procedure references the authority; it does not restate it.

Compliance check before writing: summary 2-3 lines? prerequisites all `- [ ]`? procedure all contiguous `### N.`? summary count == `### N.` count? contracts linked not inlined?

## References

- `../../references/DEPLOY_DOC_PATTERNS.md` — empty skeleton, a filled example, and anti-patterns.
