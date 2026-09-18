# Detection Logic: State Scan Script

Step 1 of Detection Logic Execution (see `SKILL.md`). Run this to populate
`state` before computing `mode`.

```bash
{ test -f CLAUDE.md && wc -l CLAUDE.md; }
{ test -f .claude/CLAUDE.md && wc -l .claude/CLAUDE.md; }
{ test -d .claude/rules && ls .claude/rules/*.md 2>/dev/null | wc -l; }
test -f AGENTS.md && echo agents-md-present

# Content signals — scan root + rules for canonical tech-stack
# markers that map to a bundled example.
SCAN_FILES=$(ls CLAUDE.md .claude/CLAUDE.md .claude/rules/*.md 2>/dev/null)
[ -n "$SCAN_FILES" ] && {
  grep -liE 'clean architecture|composition root|use ?case|repository pattern' $SCAN_FILES && echo signal:clean-arch
  grep -liE 'next\.js|server component|server action|app router'              $SCAN_FILES && echo signal:nextjs-framework
  grep -liE 'supabase|rls policy|row-level security'                          $SCAN_FILES && echo signal:supabase
  grep -liE 'pricing tier|service spec|prd|target user'                       $SCAN_FILES && echo signal:service-spec
} 2>/dev/null
```

Collect `signal:*` lines into `state.contentSignals`. Empty list
is fine: examples are then skipped.
