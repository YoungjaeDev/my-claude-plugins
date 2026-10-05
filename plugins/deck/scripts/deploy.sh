#!/usr/bin/env bash
# Stage <deck>/index.html and the files it loads into a fresh scratch dir with noindex headers,
# then deploy that folder to Vercel production.
# Usage: bash deploy.sh [DECK_DIR] [VERCEL_PROJECT]
#   DECK_DIR defaults to ./deck. VERCEL_PROJECT defaults to the "- Vercel 프로젝트: `name`" line
#   of <deck>/outline.md. Run build.py first; this script deploys index.html as it is on disk.
#   DECK_STAGE_ONLY=1 stops after staging, so the folder can be inspected without deploying.
set -euo pipefail
DECK="$(cd "${1:-deck}" && pwd)"
NAME="${2:-}"
if [ -z "$NAME" ] && [ -f "$DECK/outline.md" ]; then
  NAME="$(sed -n 's/^- Vercel 프로젝트: `\([^`]*\)`.*/\1/p' "$DECK/outline.md" | head -1)"
fi
case "$NAME" in
  ""|*"<"*|*" "*) echo "[abort] no Vercel project name: pass it as the 2nd argument or fill '- Vercel 프로젝트: \`name\`' in $DECK/outline.md" >&2; exit 1 ;;
esac
[ -f "$DECK/index.html" ] || { echo "[abort] $DECK/index.html missing: run build.py first" >&2; exit 1; }

OUT="$(mktemp -d)"
cp "$DECK/index.html" "$OUT/"
for d in fonts vendor motions; do if [ -d "$DECK/$d" ]; then cp -R "$DECK/$d" "$OUT/"; fi; done
# Literal asset paths in index.html (sections, footer). Logos are also built at runtime from the
# shell's SECTIONS array, so the whole logos/ and brand/ folders go up as well.
ASSETS="$(cd "$DECK/assets" 2>/dev/null && pwd -P || true)"
# || true: a deck that references no assets/ path is valid; grep's exit 1 must not end the script.
{ grep -o 'assets/[A-Za-z0-9_./-]*' "$DECK/index.html" || true; } | sort -u | while read -r f; do
  case "$f" in *..*) continue ;; esac  # never stage a path that climbs out of assets/
  if [ ! -f "$DECK/$f" ] || [ -L "$DECK/$f" ]; then continue; fi
  # nor one that leaves it through a symlinked directory
  case "$(cd "$(dirname "$DECK/$f")" && pwd -P)/" in "$ASSETS"/*) ;; *) continue ;; esac
  mkdir -p "$OUT/$(dirname "$f")"
  cp "$DECK/$f" "$OUT/$f"
done
mkdir -p "$OUT/assets"
for d in logos brand; do if [ -d "$DECK/assets/$d" ]; then cp -R "$DECK/assets/$d" "$OUT/assets/"; fi; done
printf 'User-agent: *\nDisallow: /\n' > "$OUT/robots.txt"
cat > "$OUT/vercel.json" <<'J'
{ "headers": [ { "source": "/(.*)", "headers": [ { "key": "X-Robots-Tag", "value": "noindex, nofollow, noarchive" } ] } ] }
J
echo "staged: $OUT"
echo "project: $NAME"
if [ "${DECK_STAGE_ONLY:-}" = 1 ]; then echo "DECK_STAGE_ONLY=1: staged, not deployed"; exit 0; fi
cd "$OUT" && npx -y vercel@latest deploy --prod --yes --project "$NAME" 2>&1 | tail -5
