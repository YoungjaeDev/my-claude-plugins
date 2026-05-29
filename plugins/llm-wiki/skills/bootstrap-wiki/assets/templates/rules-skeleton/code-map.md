# Code Map

Universal rule — 1-depth tree. Module-level detail moves to `wiki/code-map/`; deeper than that, read the file.

```
src/
  <module-1>/         # 1-line purpose. See wiki/code-map/<module-1>-modules.md
  <module-2>/         # 1-line purpose.
  ...

tests/
  <mirror of src/>

scripts/              # ad-hoc ops scripts. See wiki/code-map/scripts-and-outputs.md

.claude/
  rules/              # schema invariants (always or path-scoped)
  skills/             # workflow runbooks (Skill tool)
  spec/               # per-PR specs (date-prefixed)

.llmwiki/             # neutral root (codex-bridge .claude/->.codex/ never touches it)
  raw/                # immutable evidence (Evidence: cites)
  wiki/               # LLM-maintained lore (on-demand). MOC: .llmwiki/wiki/index.md
```

Replace the placeholders above with the actual top-level directories. Keep this file 1-depth only; any deeper detail goes to `wiki/code-map/`.
