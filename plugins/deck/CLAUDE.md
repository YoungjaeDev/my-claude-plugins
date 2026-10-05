# deck

House-format HTML lecture decks: `deck/shell.html` + `deck/sections/*.html` assembled into
`deck/index.html`, 1920x1080 stage, GSAP motions, self-hosted IBM Plex Sans KR, RALPHDEV brand.
This plugin holds the one canonical copy of the deck rules, the tools, and the scaffold template.
Generic presentations and PPTX conversion stay with `frontend-slides`.

## Shape

| Piece | Where | Copied into a deck repo? |
|---|---|---|
| Rule originals (korean-style, deck-copy, deck-authoring) | `templates/rules/*.md` | yes, stamped, by `deck-new` / `deck-sync` into `.claude/rules/` |
| Deck template (shell, sample cover, outline, motions, fonts, GSAP, brand, logo manifest) | `templates/deck/` | once, by `deck-new`; the deck owns it afterwards |
| Tools | `scripts/` | never; skills run them from the plugin root |
| Playwright for the render tools | `package.json` + `package-lock.json` | no |

Skills: `deck-ask`, `deck-new`, `deck-author`, `deck-assets`, `deck-check`, `deck-sync`, `deck-deploy`.
`deck-new`, `deck-sync`, `deck-deploy` and `deck-assets` have side effects and carry
`agents/openai.yaml` with `allow_implicit_invocation: false`.

## Tools

All take the deck directory (default `./deck`); the rule copies are read from `<deck>/../.claude/rules/`.

| Script | Does |
|---|---|
| `build.py [DECK]` | splice sections and motion script tags into the shell, write `index.html`, print `slides: N` |
| `dev.py [DECK] [--port N]` | 127.0.0.1 dev server, rebuild per request, `E` edit mode, Cmd/Ctrl+S writes the section back |
| `check_copy.py [DECK] [--rules F] [--selftest]` | banned patterns from the `### 금지 표기` table of `deck-copy.md`, plus comma-after-connective, native counting words, `p.source`/tag chips, slide labels |
| `kit.py new\|sync\|check\|prereq [REPO]` | scaffold, rule copies + vendor refresh, drift report, frontend-slides detection |
| `render-deck.cjs` | PNG per slide + PDF, overflow / bounds / footer / font-fallback checks at four viewports |
| `check-deck-interaction.cjs` | keyboard, hash, history, input focus, panel, resize, motion checks |
| `deploy.sh [DECK] [PROJECT]` | stage a self-contained folder with noindex, `vercel deploy --prod`; `DECK_STAGE_ONLY=1` stops before deploying |

## Design decisions worth not re-litigating

- **Rules ship as stamped copies, not imports.** A plugin cannot ship `.claude/rules/`, and a
  symlink or `@import` into the versioned cache loses `paths:` scoping or breaks on every update.
  The copy gets `> deck 플러그인 <version> 사본. ...` right after its frontmatter. `kit.py check`
  re-stamps the template with the copy's version and compares whole files, so `edited` (hand
  change at the current version), `stale` (older stamp) and `missing` are exact, not heuristics.
  `sync` refuses to overwrite `edited`/`unstamped` copies without `--force`.
- **`deck-local.md` is the deck's escape hatch.** Deck-specific exceptions go in
  `.claude/rules/deck-local.md`; no tool reads or writes it.
- **The ban list lives in `deck-copy.md`, not in the checker.** `check_copy.py` parses the
  `| 쓰지 않는다 | 대신 | 검사식 |` table, so the rule text and the machine check cannot drift.
  Checks that are shell contract rather than wording (comma, counting words, labels) stay in code.
- **The shell is the deck's, the template only diffs.** `deck-new` writes
  `<!-- deck shell base <version> -->` under the doctype; `sync` prints the diff against the
  current template and never writes `shell.html`.
- **Runtime files are copied into the deck.** Fonts, GSAP, motions and assets must be in the
  deployed folder and must open from disk without the plugin, so the deck carries them.
- **Deploy only on an explicit request**, after local review. Never as a follow-up to an edit.
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

Python scripts are stdlib only and run with `python3` or `python` (skills pick whichever exists).
`deploy.sh` uses `mktemp -d`, `cp -R`, `grep -o`, `sed -n`, which behave the same on GNU and BSD.
