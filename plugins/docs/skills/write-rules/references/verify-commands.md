# Verify Commands (per mode)

Deterministic verify commands for each Mode Execution's Verify step
(see `SKILL.md`).

## NEW / SPLIT / REORGANIZE

```bash
wc -l CLAUDE.md                                     # expect ≤200
find .claude/rules -name '*.md' -exec wc -l {} +    # each ≤150
grep -c '^@\.claude/rules' CLAUDE.md                # expect 0
```

SPLIT additionally:

Cross-check: sum of extracted sections + reduced root ≈ original
root (no content silently dropped).

## TIGHTEN

```bash
wc -l CLAUDE.md                           # expect lower than before
git diff --stat CLAUDE.md                 # confirm scope is surgical
grep -c '^@\.claude/rules' CLAUDE.md      # expect 0
```

Cross-check: no new sections added that don't trace to user input.
