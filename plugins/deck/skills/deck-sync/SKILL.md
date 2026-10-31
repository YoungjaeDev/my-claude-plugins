---
name: deck-sync
description: "Update an existing house-format deck repo (deck/shell.html + deck/sections/*.html) to the installed deck plugin version: rewrite the stamped rule copies in .claude/rules/ (korean-style, deck-copy, deck-authoring, and the template's deck-design), refresh deck/vendor/, and show the deck/shell.html diff against the deck's own plugin template without overwriting it. Use on '덱 규칙 업데이트', '덱 동기화', '규칙 사본 갱신', 'sync deck rules', 'update the deck plugin files', '/deck:deck-sync', or when deck-check reports stale or missing rule copies. Never touches .claude/rules/deck-local.md. Writes files, so run it only on request. Not for frontend-slides decks."
---

# deck-sync

## Overview

Brings a deck repo's copies up to the plugin version. The deck's template is read from the `<!-- deck shell base ... -->` stamp in `deck/shell.html` (a stamp without a template name, from decks made before templates existed, means `monitor`); its rules, vendor files and shell come from `templates/decks/<template>/`. Rule copies and `deck/vendor/` are overwritten from the plugin; `deck/shell.html` belongs to the deck and is only diffed. Missing `.githooks/` files (`deck` launcher, `pre-commit`, `commit-msg`) are added; existing ones are kept. A rule copy edited by hand at the current version is left alone unless the user agrees to `--force`. `.claude/rules/deck-local.md` holds deck-specific exceptions; sync never reads or writes it, and the copy check reads the deck's own bans from its `### 덱 금지 표기` table (same columns as the `deck-copy.md` table).

Deck-specific commit checks belong in `.githooks/local-checks.sh`, which the plugin's `pre-commit` runs first on every commit and which sync never writes, so they survive. Since sync keeps existing `.githooks/` files, a deck gets a newer `pre-commit` or launcher only by deleting the old one and rerunning sync. Refresh `.githooks/deck` and `.githooks/pre-commit` together (the new hook calls `deck assets`, which an older launcher lacks), and move any lines added to the old `pre-commit` by hand into `local-checks.sh` first.

## When to use

- `deck-check` printed `rules: ... stale`, `missing` or `unstamped`, or `vendor: differs`.
- The user updated the deck plugin and wants the repo to follow.
- Not for a repo without `deck/` (use `deck-new`).

## Procedure

Interaction gate: Claude uses `AskUserQuestion`; Codex uses `request_user_input` when exposed, otherwise asks in plain text and waits. Shell state does not persist between tool calls, so keep the resolver in the same call as each command.

1. Inspect first, from the repo root.

   ```bash
   PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
   [ -z "$PLUGIN_ROOT" ] && [ -f plugins/deck/scripts/kit.py ] && PLUGIN_ROOT=plugins/deck
   if [ -z "$PLUGIN_ROOT" ]; then
     # find, not a glob: zsh aborts on an unmatched glob and does not split an unquoted list.
     found=$(find "$HOME/.claude/plugins/cache" "${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}" \
       -mindepth 3 -maxdepth 3 -type d -path '*/deck/*' 2>/dev/null | awk -F/ '{print $NF "\t" $(0)}')
     if sort -V </dev/null >/dev/null 2>&1; then
       PLUGIN_ROOT=$(printf '%s\n' "$found" | sort -V | tail -1 | cut -f2-)
     else
       PLUGIN_ROOT=$(printf '%s\n' "$found" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1 | cut -f2-)
     fi
   fi
   [ -f "$PLUGIN_ROOT/scripts/kit.py" ] || { echo "deck plugin scripts not found; export PLUGIN_ROOT=<path to plugins/deck>"; exit 1; }
   PY=$(command -v python3 || command -v python)
   "$PY" "$PLUGIN_ROOT/scripts/kit.py" check . --diff
   ```

   Observable result: one `rules:` line per copy with its status, unified diffs for `stale`, `edited` and `unstamped` copies, and `vendor:` / `shell.html:` / `frontend-slides:` lines.

2. Decide on hand edits. For each `edited` or `unstamped` copy, show the diff and ask the user. Lines that are specific to this deck move into `.claude/rules/deck-local.md` (create it if needed; it keeps its own content across syncs). A fix that every deck should get belongs in the plugin original under `templates/rules/`, followed by a plugin version bump. Only after the user agrees, add `--force` in step 3.

3. Sync (same resolver block, then):

   ```bash
   "$PY" "$PLUGIN_ROOT/scripts/kit.py" sync .          # add --force only after step 2 approval
   ```

   Observable result: `rules: <file> written (<old status> -> <version>)` or `ok`, `vendor: <file> updated` when GSAP changed, then `shell.html: same as template` or `differs from template (... not written)` followed by the diff. Exit 1 means an edited copy was left as is.

4. Shell diff. Summarize the `shell.html` diff for the user: which differences are this deck's own design (keep) and which are template fixes worth porting by hand (component CSS, runtime JS). Apply nothing to `shell.html` unless the user asks for a specific change.

   A deck that drew its own phone or app mockup classes before the template had them ports them on request: take the template's `.phone` and `.app-*` CSS into the deck shell, map each old part to the template part that does the same job (top bar, avatar row, card with head, media and actions, profile header, button, image grid, tab bar), rename the classes in `deck/sections/*.html` in the same commit, rebuild and render. The template `.phone` defaults to 320x540, so a phone without inline width and height changes size; check the render for `footer-overlap` and `clip`. A part with no template match stays in the deck shell as `.app-<part>` and is noted in `deck-local.md`; the deck never keeps a second phone frame class beside `.phone`. Shell patches the template now covers (`.warn`, `.shot-row`, the zoom fixes) can be dropped from the deck shell.

## Verification

- `kit.py check .` prints `ok` for every rule copy and `vendor: ok`.
- `git diff --stat` shows changes only under `.claude/rules/`, `deck/vendor/` and new `.githooks/` files; `deck/shell.html` and `.claude/rules/deck-local.md` are unchanged.
- Run `deck-check` afterwards: the copy check now reads the new `deck-copy.md` table, so new bans can surface as violations.
- If `.githooks/local-checks.sh` exists, `sh .githooks/pre-commit` with nothing staged still runs it and exits 0.
