# QA and pass criteria

A section change is done only when every item below holds. The commands (build, copy check, render,
interaction check) belong to the `deck-check` skill; this file owns what counts as a pass.

## Pass criteria

- The build succeeds and prints the expected slide count.
- The copy check reports 0 violations: the 금지 표기 table in `.claude/rules/deck-copy.md`, the comma
  after a connective ending, native numerals in counts, and slide labels.
- Render at 1920×1080 in the motion end state (`?static=1` or `window.presentation.finishMotion()`).
  The render report shows 0 overflow, 0 font fallback, 0 failures.
- The body of every slide ends above the footer: its bottom edge is at y ≤ 900 on the stage. If not, split
  the slide (deck-copy "한 줄").
- Every `src` exists, and every logo has its record (deck-authoring "근거는 링크로").
- `data-section` is placed as deck-authoring "디자인은 셸에" decides.
- Each slide makes sense with its panels closed (deck-authoring "원문은 패널로") and panel commands
  match their source (deck-copy "본문은 말, 명령은 패널").
- Panel buttons in a `div.reveal-group` do not overlap the title or each other.

## Look at every PNG

Open each rendered PNG yourself. A report that says "0 overflow" does not catch these:

- body pushed to the top of a text-only slide,
- overlapping boxes, buttons or SVG lines,
- unreadable fragments of a capture,
- the same element rendered twice,
- SVG text crossing its box border,
- a `.boxflow` line that no longer meets its box after a box moved.

This visual pass is not delegated to a subagent. A QA agent that reports shell-injected elements
(agenda section rows, the "N / 5" footer text, the footer itself) as missing is wrong: the shell adds
them at runtime.

## Delegating section work

When a subagent writes a section, its brief names the target slide IDs, the files it may change (one
`sections/*.html` per agent), the files it must not touch (`shell.html`, `index.html`, other sections),
the rules to read (`deck-copy.md`, `korean-style.md`, `deck-authoring.md`, this skill), and the done
criteria above. The main session checks `git diff` and the PNGs itself before accepting the result.
