# deck

House-format HTML lecture decks: `deck/shell.html` + `deck/sections/*.html` assembled into
`deck/index.html`, 1920x1080 stage, GSAP motions, self-hosted IBM Plex Sans KR, RALPHDEV brand.
This plugin holds the one canonical copy of the deck rules, the tools, and the scaffold template.
Generic presentations and PPTX conversion stay with `frontend-slides`.

## Shape

| Piece | Where | Copied into a deck repo? |
|---|---|---|
| Shared rule originals (korean-style, deck-copy, deck-authoring) | `templates/rules/*.md` | yes, stamped, by `deck-new` / `deck-sync` into `.claude/rules/` |
| Deck templates (shell, sample cover, outline, motions, fonts, GSAP, brand, logo manifest), one folder each; `monitor` is the default | `templates/decks/<name>/` | once, by `deck-new --template <name>`; the deck owns it afterwards |
| Template rule originals (deck-design: brand, fonts, footer, picture assets) | `templates/decks/<name>/rules/*.md` | yes, stamped, next to the shared rules; never into `deck/` |
| Tool launcher `deck`, `pre-commit`, `commit-msg` | `templates/githooks/` | into `.githooks/` by `deck-new` / `deck-sync` when missing; never overwritten |
| Tools | `scripts/` | never; skills run them from the plugin root |
| Playwright for the render tools | `package.json` + `package-lock.json` | no |

Skills: `deck-ask`, `deck-new`, `deck-author`, `deck-assets`, `deck-check`, `deck-sync`, `deck-deploy`.
`deck-new`, `deck-sync`, `deck-deploy` and `deck-assets` have side effects and carry
`agents/openai.yaml` with `allow_implicit_invocation: false`.

## Tools

All take the deck directory (default `./deck`); the rule copies are read from `<deck>/../.claude/rules/`.
In a deck repo every tool is also `sh .githooks/deck <build|copy|outline|assets|check|kit|render|interaction|frames|dev|root> [args]`.

| Script | Does |
|---|---|
| `build.py [DECK]` | splice sections and motion script tags into the shell, write `index.html`, print `slides: N` |
| `dev.py [DECK] [--port N]` | 127.0.0.1 dev server, rebuild per request, `E` edit mode, Cmd/Ctrl+S writes the section back |
| `check_copy.py [DECK] [--rules F] [--selftest]` | banned patterns from the `### 금지 표기` table of `deck-copy.md` and the optional `### 덱 금지 표기` table of `deck-local.md`, plus comma-after-connective, native counting words, `p.source`/tag chips, slide labels; `alt` and `aria-label` text is checked against the banned patterns only |
| `check_assets.py [DECK] [--staged] [--selftest]` | refuses raw OS screenshot names and archives anywhere in the commit, an image in a folder with a `captures.md` but no row for it, and a missing `assets/` path referenced by sections, shell or motions; warns on images nothing references. `--staged` reads the git index |
| `check_outline.py [DECK] [--outline F] [--selftest]` | every h2, `p.lead`, `li` and `.fbox` text piece of the sections appears verbatim in `outline.md`; exit 2 on an unreadable deck or outline |
| `kit.py new\|sync\|check\|prereq [REPO] [--template NAME]` | scaffold (`--template`, default `monitor`), rule copies + vendor refresh, missing `.githooks/` files, drift report, frontend-slides detection; `sync` and `check` take the template from the shell stamp |
| `render-deck.cjs [--slides 12,S3-04] [--quick]` | `previews/slide-<NN>-<ID>.png` + `sheet-<N>.png` contact sheets + PDF; overflow / clip / bounds / footer / font-fallback checks at four viewports, one grouped line per problem; `--slides` (numbers or ids) skips the PDF, `--quick` runs 1920x1080 only |
| `check-deck-interaction.cjs` | keyboard, hash, history, input focus, panel, resize, motion checks; `motion-early` for an element visible before its turn |
| `motion-frames.cjs --slide N\|ID --at 0,800,end` | PNGs of one slide's motion at seeked times |
| `deploy.sh [DECK] [PROJECT]` | stage a self-contained folder with noindex, `vercel deploy --prod`, keep the full log and print `log:` and `url:`, then compare the served slide count with the built one (`slides: built N, served N`, mismatch exits 1); `DECK_STAGE_ONLY=1` stops before deploying, `DECK_CREATE_PROJECT=1` adds `--create-if-missing` (only after the user agrees) |

## Design decisions worth not re-litigating

- **Rules ship as stamped copies, not imports.** A plugin cannot ship `.claude/rules/`, and a
  symlink or `@import` into the versioned cache loses `paths:` scoping or breaks on every update.
  The copy gets `> deck 플러그인 <version> 사본. ...` right after its frontmatter. `kit.py check`
  re-stamps the template with the copy's version and compares whole files, so `edited` (hand
  change at the current version), `stale` (older stamp) and `missing` are exact, not heuristics.
  `sync` refuses to overwrite `edited`/`unstamped` copies without `--force`.
- **`deck-local.md` is the deck's escape hatch.** Deck-specific exceptions go in
  `.claude/rules/deck-local.md`. No tool writes it; `check_copy.py` reads only its optional
  `### 덱 금지 표기` table, so a deck adds its own banned wording without editing the stamped copy.
- **Deck-specific commit checks plug in, they do not patch the hook.** The pre-commit hook runs
  `.githooks/local-checks.sh` when it exists, so a deck's own check survives `sync`.
- **The ban list lives in `deck-copy.md`, not in the checker.** `check_copy.py` parses the
  `| 쓰지 않는다 | 대신 | 검사식 |` table, so the rule text and the machine check cannot drift.
  Checks that are shell contract rather than wording (comma, counting words, labels) stay in code.
- **The shell is the deck's, the template only diffs.** `deck-new` writes
  `<!-- deck shell base <template> <version> -->` under the doctype; `sync` prints the diff against
  the current shell of that template and never writes `shell.html`. A stamp without a template
  name comes from a deck made before templates existed and means `monitor`.
- **Design rules follow the template, copy rules do not.** `deck-copy.md`, `korean-style.md` and
  `deck-authoring.md` bind every deck. Brand, fonts, footer and picture assets differ per template,
  so they live in the template's `rules/deck-design.md`, stamped and synced like the shared rules.
- **Runtime files are copied into the deck.** Fonts, GSAP, motions and assets must be in the
  deployed folder and must open from disk without the plugin, so the deck carries them.
- **Deploy only on an explicit request**, after local review. Never as a follow-up to an edit.
- **Decks call the tools through `.githooks/deck`, not a cache path.** Shell state does not survive
  between agent tool calls, so a multi-line resolver gets replaced by a hard-coded
  `~/.claude/plugins/cache/.../deck/<version>` that breaks on the next update. The launcher re-resolves
  on every run and exits 3 when no plugin (or a too-old one) is found; the pre-commit hook skips on 3.
- **frontend-slides is a soft prerequisite.** `kit.py prereq` reports it from
  `~/.claude/plugins/installed_plugins.json` or the plugin caches; it never fails a build.

## Claude Code and Codex

- Skills resolve `PLUGIN_ROOT` (caller value, `CLAUDE_PLUGIN_ROOT`, source tree `plugins/deck`,
  then the newest `*/deck/<version>` under the Claude and Codex caches). The lookup uses `find`,
  not a glob: zsh aborts a command on an unmatched glob and does not word-split an unquoted list.
- Codex cannot read `.claude/rules/`, so the stamped rule copies bind Claude only. Under Codex the
  skills still run every tool; the copy check still applies the `deck-copy.md` table because the
  script reads the file directly.
- Claude Code installs `playwright` from `package-lock.json` when it copies the plugin into its
  cache. A local source checkout and Codex do not: run `npm ci --ignore-scripts` in the plugin root
  or set `NODE_PATH`. No browser download is needed; the tools drive the system Chrome.

## Portability

Python scripts run with `python3` or `python` (skills pick whichever exists). The checkers in
`scripts/` are stdlib only; the image helpers in `skills/deck-assets/scripts/` (`slice-sheet.py`,
`redact-image.py`) need Pillow.
`deploy.sh` uses `mktemp -d`, `cp -R`, `grep -o`, `sed -n`, `curl`, `wc`, `tr`, which behave the same on GNU and BSD.
