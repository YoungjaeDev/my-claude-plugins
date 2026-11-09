# deck

House-format HTML decks, lecture and report: `deck/shell.html` + `deck/sections/*.html` assembled into
`deck/index.html`, 1920x1080 stage, GSAP motions, self-hosted IBM Plex Sans KR, RALPHDEV brand.
This plugin holds the one canonical copy of the deck rules, the tools, and the scaffold template.
Generic presentations and PPTX conversion stay with `frontend-slides`.

## Shape

| Piece | Where | Copied into a deck repo? |
|---|---|---|
| Shared rule originals (korean-style, deck-copy, deck-authoring; deck-report for report decks only) | `templates/rules/*.md` | yes, stamped, by `deck-new` / `deck-sync` into `.claude/rules/` |
| Deck templates (shell, sample cover, outline, motions, fonts, GSAP, brand, logo manifest), one folder each; `monitor` is the default | `templates/decks/<name>/` | once, by `deck-new --template <name>`; the deck owns it afterwards |
| Template rule originals (deck-design: brand, fonts, footer, picture assets) | `templates/decks/<name>/rules/*.md` | yes, stamped, next to the shared rules; never into `deck/` |
| Brand folders (colour tokens, self-hosted fonts, font sources); a template names its brand in `brand.txt` | `templates/brands/<brand>/` | into `deck/brand/` by `deck-new`; `deck-sync` overwrites it like `vendor/` |
| Tool launcher `deck`, `pre-commit`, `commit-msg` | `templates/githooks/` | into `.githooks/` by `deck-new` / `deck-sync` when missing; never overwritten |
| Tools | `scripts/` | never; skills run them from the plugin root |
| Playwright for the render tools | `package.json` + `package-lock.json` | no |

Skills: `deck-ask`, `deck-new`, `deck-author`, `deck-assets`, `deck-check`, `deck-sync`, `deck-deploy`.
`deck-new`, `deck-sync`, `deck-deploy` and `deck-assets` have side effects and carry
`agents/openai.yaml` with `allow_implicit_invocation: false`.

## Tools

All take the deck directory (default `./deck`) and read the rule copies from `<deck>/../.claude/rules/`. In a deck repo every tool is also `sh .githooks/deck <build|copy|outline|assets|check|kit|render|interaction|frames|dev|root> [args]`. The Python scripts list their flags in their docstrings and take `--selftest`; `deck-check` and `deck-deploy` show the Node and shell tools' flags in use.

| Script | Does |
|---|---|
| `build.py` | splices sections and motion script tags into the shell, writes `index.html`, prints `slides: N` |
| `dev.py` | 127.0.0.1 dev server with `E` edit mode; Cmd/Ctrl+S writes the section back with runtime state stripped |
| `check_copy.py` | banned patterns from the `### 금지 표기` table of `deck-copy.md`, the `### 보고 덱 금지 표기` table of `deck-report.md` (report decks) and the optional `### 덱 금지 표기` table of `deck-local.md`, plus the shell-contract wording checks; the deck kind comes from `kit.deck_kind` |
| `check_assets.py` | raw screenshot names and archives, captures without a `captures.md` row or outside a zoomable figure, missing `assets/` paths |
| `check_outline.py` | section text pieces appear verbatim in `outline.md`; flow rows without a mockup or motion |
| `kit.py new\|sync\|check\|prereq` | scaffold, rule copies + vendor and brand refresh, missing `.githooks/` files, drift report, frontend-slides detection |
| `render-deck.cjs [--slides 12,S3-04] [--quick]` | slide PNGs, contact sheets and PDF with overflow, clip, footer and font checks at four viewports; `--slides` skips the PDF, `--quick` runs 1920x1080 only |
| `check-deck-interaction.cjs` | keyboard, hash, panel, capture-zoom, reveal-box and motion checks |
| `motion-frames.cjs --slide N\|ID --at 0,800,end` | PNGs of one slide's motion at seeked times |
| `deploy.sh [DECK] [PROJECT]` | stages a noindex folder, runs `vercel deploy --prod`, compares served and built slide counts (`slides: built N, served N`); `DECK_STAGE_ONLY=1` stops before deploying, `DECK_CREATE_PROJECT=1` adds `--create-if-missing` (only after the user agrees) |

## Design decisions

- **Rules ship as stamped copies, not imports.** A plugin cannot ship `.claude/rules/`, and a symlink or `@import` into the versioned cache loses `paths:` scoping or breaks on every update. Each copy gets `> deck 플러그인 <version> 사본(<hash>). ...` right after its frontmatter, and `kit.py` reports it as `ok`, `missing`, `stale`, `edited`, `unstamped` or `bare`; `sync` overwrites `edited`/`unstamped` copies only with `--force`.
- **A rule template change reaches existing deck repos on their next `deck-sync`.** Until then `kit.py check` reports their copies `stale` and the deck pre-commit fails on commits that touch `deck/` or `.claude/rules/`.
- **`deck-local.md` is the deck's escape hatch.** No tool writes `.claude/rules/deck-local.md`; `check_copy.py` reads only its optional `### 덱 금지 표기` table.
- **Deck-specific commit checks plug in.** The pre-commit hook runs `.githooks/local-checks.sh` when it exists, so a deck's own check survives `sync`.
- **The ban list lives in `deck-copy.md`, not in the checker.** `check_copy.py` parses the `| 쓰지 않는다 | 대신 | 검사식 |` table, so the rule text and the machine check cannot drift. Checks that are shell contract rather than wording stay in code.
- **The shell is the deck's, the template only diffs.** `deck-new` writes `<!-- deck shell base <template> <version> -->` under the doctype; `sync` prints the diff against that template's shell and never writes `shell.html`. A stamp without a template name means `monitor`.
- **Brand tokens belong to the plugin.** `templates/brands/<brand>/` is copied to `deck/brand/` and overwritten by `deck-sync`; a deck's own exceptions go in its `shell.html`. The marker file is `brand.txt`, not `BRAND`, which would collide with `brand/` on case-insensitive file systems.
- **Design rules follow the template, copy rules do not.** `deck-copy.md`, `korean-style.md` and `deck-authoring.md` bind every deck; brand, fonts, footer and picture assets live in the template's `rules/deck-design.md`.
- **Runtime files are copied into the deck.** Fonts, GSAP, motions and assets must open from disk without the plugin.
- **The deck kind is one outline header line.** A report deck has `- deck_kind: report` in the `deck/outline.md` header; no line means a lecture deck. `kit.py` copies `deck-report.md` only into a report deck.
- **Deploy only on an explicit request**, after local review. Never as a follow-up to an edit.
- **Decks call the tools through `.githooks/deck`, not a cache path.** A hard-coded `~/.claude/plugins/cache/.../deck/<version>` breaks on the next update; the launcher re-resolves on every run and exits 3 when no plugin (or a too-old one) is found, and the pre-commit hook skips on 3.
- **frontend-slides is a soft prerequisite.** `kit.py prereq` reports it; it never fails a build.

## Claude Code and Codex

- Skills resolve `PLUGIN_ROOT` with the resolver block each SKILL.md carries (caller value, `CLAUDE_PLUGIN_ROOT`, source tree, then the newest cached version).
- Codex cannot read `.claude/rules/`, so the stamped rule copies bind Claude only. Under Codex the skills still run every tool, and the copy check still applies the `deck-copy.md` table because the script reads the file directly.
- The render tools need `playwright` from `package-lock.json`. When the plugin root has no `node_modules` (a source checkout, Codex), run `npm ci --ignore-scripts` there or set `NODE_PATH`; the tools drive the system Chrome, so no browser download is needed.

## Portability

- Python scripts run with `python3` or `python` (skills pick whichever exists).
- The checkers in `scripts/` are stdlib only; the image helpers in `skills/deck-assets/scripts/` (`slice-sheet.py`, `redact-image.py`) need Pillow.
- `deploy.sh` uses `mktemp -d`, `cp -R`, `grep -o`, `sed -n`, `curl`, `wc`, `tr`, which behave the same on GNU and BSD.
