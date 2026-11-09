# deck-check output guide

What each line from the `deck-check` tools means and what to do about it, keyed by the line's first word. Step numbers are the SKILL.md steps.

## Step 1: build, copy, outline, assets, rule copies

- **`hooks: off ...`**: the deck's commit hooks are not enabled. Put it at the top of the report on every run and ask the user whether to run `git config core.hooksPath .githooks` (it changes the repo's git config, so only on a yes). No line means the hooks are on.
- **`slides: N`**: keep N for step 2.
- **`warn: slide i (...): '(N쪽)' names slide N, ...`**: a page reference in slide text points past the deck or at the cover, agenda or a section cover. Warning only (exit 0): fix the number, or name the slide title instead.
- **`violations: 0`**: otherwise each line names file, slide id, rule and text. Fix the section (and `deck/outline.md`, the copy source) rather than the checker.
- **`cannot read banned patterns`**: `.claude/rules/deck-copy.md` is missing or lost its `### 금지 표기` table; run `deck-sync`.
- **Deck bans**: the deck's own bans go in a `### 덱 금지 표기` table of `.claude/rules/deck-local.md`, same columns (`| 쓰지 않는다 | 대신 | 검사식 |`). `cannot read deck bans` means that table is malformed.
- **Report deck bans**: in a report deck `.claude/rules/deck-report.md` adds its `### 보고 덱 금지 표기` table. The outline's `deck_kind` line alone decides, so a leftover copy in a lecture deck is not read.
- **`patterns: N from ... and deck-report.md and deck-local.md`**: shows which tables were read. The line ends in `deck_kind: lecture|report`, read from the `- deck_kind: report` header line of `deck/outline.md` (absent means lecture).
- **`alt="..."` / `aria-label="..."`**: a line ending in one of these is screen-reader text. Only the banned patterns apply there, not the comma or counting checks.
- **`캡션 N자(최대 50자, 한 줄)`**: a capture caption is one line; the capture's conditions go in its `captures.md` row.
- **`형광펜 N개(장당 최대 6개)`**: `.mark` goes on up to six spots per slide, with or without a list.
- **`1인칭(보고 덱):<word>`**: report decks only, for 내 / 나 / 저 (and 내가, 저는, 제가, 저희 and the like). A bare 내 counts only at the start of a phrase, so 기간 내 and 1년 내 pass. Drop the subject in narration, and use a role name (개발자, 회사 담당자) in owner and role cells.
- **`assets: 0 failed`**: a failure line names the file. A raw screenshot or `.zip` name: keep the original outside the repo and commit a renamed, blurred copy. An image with no row in the nearest `captures.md` of its folder: a folder under `deck/assets/` that holds a `captures.md` records every capture (file name, screen, date, what was blurred).
- **Missing asset**: an `assets/...` path that a section, the shell or a motion loads but that does not exist.
- **`<src> is a capture outside figure.shot or .shot-row figure (it cannot zoom)`**: every capture opens full-slide on click, so wrap it in `figure.shot` or a `.shot-row` figure. A capture is an image under a folder with a `captures.md`; logos, icons and cuts have none and are exempt.
- **`unused (...)`**: images nothing names. Warning only: delete them or leave them.
- **`outline: 0 missing of T`**: every h2, `p.lead`, `li` and `.fbox` text piece (its `strong`, its own text, its `span`) must appear verbatim somewhere in `deck/outline.md`. A miss line names file, slide id, kind and text: bring the outline and the section back to the same words (the outline is the source; a dev-server edit belongs in it too).
- **`none of the T texts is in`**: a wrong path, or an outline that paraphrases instead of quoting.
- **Line breaks**: a line break reads as ` / ` on both sides (a section `<br>`; ` / ` or `<br>` in the outline), so a literal ` / ` in slide text is written as is in the outline, with no `&#47;` escape. Mockups (`.term`, `.tr-win`, `.browser-win`), `svg`, `pre`, panels and `[data-outline-skip]` are not checked.
- **`outline: warning <ID> <유형>: no mockup and no motion`**: warning only. A 흐름, 순서, 구성 or 화면 row has both its 캡처·목업 and 모션 cells empty; give it a motion or a mockup (deck-authoring "흐름은 움직임으로").
- **`rules: <file> <status>`**: one line per rule copy. `stale` or `missing` means run `deck-sync`; `edited` means someone changed a copy by hand, and the deck-specific lines belong in `.claude/rules/deck-local.md`. Add `--diff` to see the change.
- **`vendor:` / `shell.html:`**: a shell that differs from the template is normal (the deck owns it) and is info only.
- **`frontend-slides: installed|missing`**: warning only, never a failure. Relay the printed install commands when missing.

## Step 2: render and interaction

Each tool prints one JSON line (`"status":"verified"` or `"failed"`), then one line per problem, and writes `render-report.json` / `interaction-report.json`. Render problem lines read `slide 12 S3-04 <kind>: <detail> [<passes>]`, the same problem from several viewports listed once.

- **`overflow`**: an element's own text is larger than its box. The mockup pointer `.cursor` is ignored.
- **`clip`**: text cut off inside an `overflow: hidden|clip` box such as a mockup page. Shorten the content or enlarge the box, or mark a deliberate crop with `data-intentional-clip`. The mockup pointer `.cursor` is ignored.
- **Other render kinds**: `out-of-bounds`, `footer-overlap`, `font-fallback`, `single-slide`, `pdf-pages`.
- **`capture-zoom: slide N ID: <src> covers P% of the slide after a click on file://`**: the interaction tool opens the built file from disk (`file://...?static=1`), clicks the first capture of every slide that has one, expects its figure to cover at least 80% of the slide, then closes it with a second click. A failure means the shell's zoom handler does not reach that figure (the shell must toggle `.zoomed` on `figure.shot` and on `.shot-row` figures) or a script error on file:// (`file:// pageerror`).
- **`reveal-<arrival|open|copy|refold|static|print>: slide N ID: ...`**: only when a slide has a `.reveal-box`. The first reveal box must arrive folded, open on a click of its button (`open` class, `aria-expanded="true"`), carry one copy button per `pre.code`, fold again after the slide is left and revisited, and render open under `?static=1` and in print. A failure means the deck's `shell.html` lacks a piece of the 2.2.0 reveal-box runtime: compare it with the template diff that `deck-sync` prints.
- **`motion-early: slide N ID: <element> visible at 0s ...`**: an element shows before its turn because a later `fromTo` rendered its start values at creation. Add `immediateRender: false` to that `fromTo` (the authored end state then keeps it hidden until its turn), and look at the step 3 frames.

## Tool failures

- **`deck: plugin scripts not found`** (exit 3 from the launcher): no deck plugin in the Claude or Codex cache; export `PLUGIN_ROOT`.
- **`deck: <tool> is not in <root>`**: the installed plugin is older than the launcher; update it.
- **`MissingPlaywright`**: a local source checkout or Codex has no `node_modules` in the plugin. Run `npm ci --ignore-scripts` in the plugin root (`sh .githooks/deck root` prints it), or point `NODE_PATH` at another `node_modules` that has `playwright`. Browsers are not needed; the tools drive the system Chrome.
- **Codex copy picked**: the launcher prefers, at the same version, the cached copy that has `node_modules`. An older `.githooks/deck` may pick the Codex copy; delete it and run `deck-sync` to refresh.
- **`pdf-pages:` / `pdfinfo:`** failures with no other problem: `pdfinfo` (poppler) is missing. Pass `--pdfinfo PATH` or install poppler.
