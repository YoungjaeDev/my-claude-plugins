---
name: deck-new
description: "Scaffold a new lecture deck in the house format (deck/shell.html + deck/sections/*.html, GSAP motions, self-hosted fonts, RALPHDEV brand) into the current repo, and copy the stamped deck rules into .claude/rules/. Use when the user asks to start a new deck in this repo: '새 덱 만들어줘', '덱 스캐폴드', '강의 덱 시작', 'new deck', 'scaffold a deck', '/deck:deck-new'. Refuses when deck/ already exists (use deck-sync to refresh rules). Writes files, so run it only on an explicit request. For a one-off presentation without the house shell, or converting a PPTX, use frontend-slides instead."
---

# deck-new

## Overview

Creates `deck/` from the plugin template (neutral `shell.html`, a sample `sections/00-cover.html`, `outline.md`, `motions/basic.js`, fonts, `vendor/gsap.min.js`, brand assets, an empty `assets/logos/sources.json`, `deck/.gitignore`) and writes the three rule copies into `.claude/rules/`, each stamped with the plugin version. The deck owns every copied file afterwards. Build, check, render and deploy tools stay in the plugin and are never copied.

## When to use

- The user explicitly asks for a new house-format deck in the current repository.
- Not when `deck/` exists: the scaffold refuses. Use `deck-sync` for rule updates and `deck-author` for writing slides.
- Not for a generic talk or a PPTX conversion: that is `frontend-slides`.

## Procedure

Interaction gate: Claude uses `AskUserQuestion`; Codex uses `request_user_input` when exposed, otherwise asks in plain text and waits.

1. Confirm the target. Show `pwd` and ask the user to confirm it is the repository root that should hold `deck/`.

2. Resolve the plugin root and scaffold. Shell state does not persist between tool calls, so keep the resolver and the command in one call.

   ```bash
   PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
   [ -z "$PLUGIN_ROOT" ] && [ -f plugins/deck/scripts/kit.py ] && PLUGIN_ROOT=plugins/deck
   if [ -z "$PLUGIN_ROOT" ]; then
     # find, not a glob: zsh aborts on an unmatched glob and does not split an unquoted list.
     found=$(find "$HOME/.claude/plugins/cache" "${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}" \
       -mindepth 3 -maxdepth 3 -type d -path '*/deck/*' 2>/dev/null | awk -F/ '{print $NF "\t" $0}')
     if sort -V </dev/null >/dev/null 2>&1; then
       PLUGIN_ROOT=$(printf '%s\n' "$found" | sort -V | tail -1 | cut -f2-)
     else
       PLUGIN_ROOT=$(printf '%s\n' "$found" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1 | cut -f2-)
     fi
   fi
   [ -f "$PLUGIN_ROOT/scripts/kit.py" ] || { echo "deck plugin scripts not found; export PLUGIN_ROOT=<path to plugins/deck>"; exit 1; }
   PY=$(command -v python3 || command -v python)
   "$PY" "$PLUGIN_ROOT/scripts/kit.py" new .
   ```

   Observable result: `deck: scaffolded <repo>/deck`, one `rules: <name> written (missing -> <version>)` line per rule, and a `frontend-slides:` line. On `[abort] ... already exists` stop and point the user to `deck-sync`.

3. Prerequisite check. The `frontend-slides:` line reports whether the frontend-slides plugin is installed. It is a warning only: the house deck builds without it. When it says `missing`, relay the printed install commands to the user and continue.

4. Fill the deck identity. Ask for the deck title, the thesis sentence, the section list (id, name, goal) and the Vercel project name, then edit:
   - `deck/outline.md` header lines (`덱의 주장`, `섹션`, `Vercel 프로젝트`, `배포 주소`),
   - `deck/shell.html`: `<title>`, the stage `aria-label`, and the `SECTIONS` array (keep `id`, `name`, `goal`, `logos`),
   - `deck/sections/00-cover.html`: the cover `h1` and subtitle.

   Leave the sample S1-01 slide until real content replaces it.

5. Hand off. Tell the user the next steps: `deck-assets` for logos and icon cells, `deck-author` for slides, `deck-check` before showing anyone the deck. Deck-specific rule exceptions go in `.claude/rules/deck-local.md`, which sync never touches.

## Verification

- `deck/shell.html`, `deck/sections/00-cover.html`, `deck/outline.md` and `deck/vendor/gsap.min.js` exist, and the second line of `deck/shell.html` is `<!-- deck shell base <version> -->`.
- Every file in `.claude/rules/` written here contains `> deck 플러그인 <version> 사본.` right after its frontmatter.
- Running `deck-check` on the fresh scaffold passes build, copy check and render.
