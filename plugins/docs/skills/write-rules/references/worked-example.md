## Worked Example: REORGANIZE + Clean Arch signal

A short trace of how the pieces fit together when the audit lands on
a Clean Architecture codebase. The point is to show what
`contentSignals` actually changes: without it the audit is generic
prose; with it the audit can cite a canonical reference.

```
Input state:
  CLAUDE.md         (210 lines)
  .claude/rules/architecture.md  (180 lines, prose-heavy)

Scan:
  state.claudeMdLines = 210
  state.hasRulesDir   = true
  state.contentSignals = ["clean-arch"]      ← grep hit on "Composition Root"
  mode = REORGANIZE

Read (step 1):
  assets/templates/rule-file.md              ← target shape
  assets/templates/rule-categories.md        ← naming/paths vocab
  assets/examples/nextjs-clean-arch.md       ← canonical Clean Arch shape
                                               (only because signal matched)

Read (step 2):
  CLAUDE.md, .claude/rules/architecture.md

Audit findings (step 3):
  - root size 210 > 200 → propose extracting "Build & Test" block
  - architecture.md 180 > 150 → propose splitting by layer
    (domain.md / application.md / infrastructure.md), with paths:
    globs grounded in nextjs-clean-arch.md's layer map
  - architecture.md is prose → propose restructure to
    Role / Do / Don't using rule-file.md Variant A
```

Without `contentSignals`, step 3 still flags the size issues but the
restructure proposal would be generic. The signal-driven Read of
`nextjs-clean-arch.md` is what turns "this rule should be shorter"
into "this rule should split along the layer seams the example uses".
