---
name: deck-deploy
description: "Deploy a house-format deck (deck/shell.html + deck/sections/*.html built into deck/index.html) to Vercel production: stage index.html, fonts, vendor, motions and the assets it loads into a fresh self-contained folder with noindex headers and robots.txt, run vercel deploy, then verify the headers. Use ONLY when the user explicitly asks to deploy after reviewing the deck locally: '덱 배포', '배포해줘', 'Vercel에 올려', 'deploy the deck', '/deck:deck-deploy'. Never deploy on your own after an edit or a passing check. Publishes to the internet. Not for frontend-slides decks."
---

# deck-deploy

## Overview

Publishes the built deck as a static site. The staging folder holds only what the page loads, so the plugin, sections, outline and rules never leave the machine. The Vercel project name comes from the `- Vercel 프로젝트:` line of `deck/outline.md`. Search engines are kept out by an `X-Robots-Tag: noindex, nofollow, noarchive` header and a `Disallow: /` robots.txt.

## When to use

- The user explicitly asks to deploy, and has reviewed the deck locally (dev server or rendered PNGs).
- Not after an edit, a sync, or a passing `deck-check` on your own initiative: deploying is the user's call every time.

## Procedure

Interaction gate: Claude uses `AskUserQuestion`; Codex uses `request_user_input` when exposed, otherwise asks in plain text and waits. Shell state does not persist between tool calls, so keep the resolver in the same call as each command.

1. Gate. Run `deck-check` first. If anything failed, stop and report. Then read the project name from `deck/outline.md` and ask the user to confirm: "Deploy deck/index.html to Vercel project `<name>` (https://<name>.vercel.app)?" Proceed only on a yes. A placeholder `<project-name>` means the outline is unfinished: ask for the name and write it into the outline first.

2. Stage only, then inspect (from the repo root).

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
   [ -f "$PLUGIN_ROOT/scripts/deploy.sh" ] || { echo "deck plugin scripts not found; export PLUGIN_ROOT=<path to plugins/deck>"; exit 1; }
   DECK_STAGE_ONLY=1 bash "$PLUGIN_ROOT/scripts/deploy.sh" deck
   ```

   Observable result: `staged: <dir>`, `project: <name>`, `DECK_STAGE_ONLY=1: staged, not deployed`. List the staged folder and confirm it holds `index.html`, `fonts/`, `vendor/`, `motions/`, `assets/`, `robots.txt`, `vercel.json` and nothing else (no `sections/`, `outline.md`, `.claude/`).

3. Deploy (same resolver block, then):

   ```bash
   bash "$PLUGIN_ROOT/scripts/deploy.sh" deck
   ```

   It stages a fresh folder and runs `npx -y vercel@latest deploy --prod --yes --project <name>`. The last lines carry the deployment URL. A Vercel login prompt or an auth error means the user must run `npx vercel login` themselves; do not work around it.

4. Report the production URL and the header check below.

## Verification

```bash
curl -sI https://<name>.vercel.app | grep -i x-robots-tag     # X-Robots-Tag: noindex, nofollow, noarchive
curl -s https://<name>.vercel.app/robots.txt                  # User-agent: * / Disallow: /
```

Open the URL once and confirm the first slide renders with the deck's fonts.
