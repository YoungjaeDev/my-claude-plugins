# Detection Logic: State Scan Script

Step 1 of `## Execution` in `SKILL.md`. Run this to populate
`state` before computing `mode`.

```bash
{ test -f CLAUDE.md && wc -l CLAUDE.md; }
{ test -f .claude/CLAUDE.md && wc -l .claude/CLAUDE.md; }
{ test -d .claude/rules && find .claude/rules -maxdepth 1 -name '*.md' | wc -l; }
test -f AGENTS.md && echo agents-md-present

# Content signals — scan root + rules for canonical tech-stack
# markers that map to a bundled example. The files go into "$@" and the rules
# come from find: zsh aborts on an unmatched glob and passes an unquoted list as one word.
set --
for f in CLAUDE.md .claude/CLAUDE.md; do [ -f "$f" ] && set -- "$@" "$f"; done
if [ -d .claude/rules ]; then
  while IFS= read -r f; do [ -n "$f" ] && set -- "$@" "$f"; done <<EOF
$(find .claude/rules -maxdepth 1 -name '*.md' | sort)
EOF
fi
[ $# -gt 0 ] && {
  grep -liE 'clean architecture|composition root|use ?case|repository pattern' "$@" && echo signal:clean-arch
  grep -liE 'next\.js|server component|server action|app router'              "$@" && echo signal:nextjs-framework
  grep -liE 'supabase|rls policy|row-level security'                          "$@" && echo signal:supabase
  grep -liE 'pricing tier|service spec|prd|target user'                       "$@" && echo signal:service-spec
} 2>/dev/null
```

Collect `signal:*` lines into `state.contentSignals`. Empty list
is fine: examples are then skipped.
