#!/usr/bin/env bash
# Stage <deck>/index.html and the files it loads into a fresh scratch dir with noindex headers,
# then deploy that folder to Vercel production.
# Usage: bash deploy.sh [DECK_DIR] [VERCEL_PROJECT]
#   DECK_DIR defaults to ./deck. VERCEL_PROJECT defaults to the "- Vercel 프로젝트: `name`" line
#   of <deck>/outline.md. Run build.py first; this script deploys index.html as it is on disk.
#   DECK_STAGE_ONLY=1 stops after staging, so the folder can be inspected without deploying.
#   DECK_CREATE_PROJECT=1 adds --create-if-missing for a first deploy to a project that does not exist.
# The full Vercel log goes to <staging dir>.log, outside the uploaded folder. After the deploy the
# production URL must serve as many slides as the staged index.html, or the script exits 1.
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
for d in fonts vendor motions brand; do if [ -d "$DECK/$d" ]; then cp -R "$DECK/$d" "$OUT/"; fi; done
# Literal asset paths in index.html (sections, footer). Logos are also built at runtime from the
# shell's SECTIONS array, so the whole logos/ and brand/ folders go up as well.
ASSETS="$(cd "$DECK/assets" 2>/dev/null && pwd -P || true)"
# grep exit 1 (no assets/ path) is a valid deck; exit 2 (read error) must stop staging.
# A path ends at a quote, bracket, query, fragment or whitespace, so non-ASCII names stay whole.
REFS="$(grep -o "assets/[^\"'<>()?#[:space:]]*" "$DECK/index.html")" || [ $? -eq 1 ] \
  || { echo "[abort] could not read $DECK/index.html" >&2; exit 1; }
printf '%s\n' "$REFS" | sort -u | while read -r f; do
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
LOG="$OUT.log"
set -- deploy --prod --yes --project "$NAME"
if [ "${DECK_CREATE_PROJECT:-}" = 1 ]; then set -- "$@" --create-if-missing; fi
echo "log: $LOG"
if ! (cd "$OUT" && npx -y vercel@latest "$@") >"$LOG" 2>&1; then
  tail -20 "$LOG" >&2
  if grep -qiE 'project_not_found|project not found' "$LOG"; then
    echo "[abort] Vercel project $NAME does not exist. Check the name, or rerun with DECK_CREATE_PROJECT=1 to create it." >&2
  fi
  echo "[abort] vercel deploy failed; full log: $LOG" >&2
  exit 1
fi
# "Aliased" is the project domain viewers open; "Production" the unique deployment URL. The colon
# after the label depends on the CLI version.
URL="$(sed -n 's/.*Aliased:\{0,1\} *\(https:[^ ]*\).*/\1/p' "$LOG" | tail -1)"
[ -n "$URL" ] || URL="$(sed -n 's/.*Production:\{0,1\} *\(https:[^ ]*\).*/\1/p' "$LOG" | tail -1)"
[ -n "$URL" ] || { echo "[abort] no deployment URL in $LOG" >&2; exit 1; }
echo "url: $URL"
# A stale cache or a deploy to the wrong project serves a different slide count.
# grep exit 1 is a count of 0; under pipefail it would end the script before the comparison.
BUILT="$({ grep -o 'class="slide' "$OUT/index.html" || [ $? -eq 1 ]; } | wc -l | tr -d ' ')"
LIVE="$(curl -fsSL "$URL")" || { echo "[abort] could not fetch $URL" >&2; exit 1; }
SERVED="$(printf '%s' "$LIVE" | { grep -o 'class="slide' || [ $? -eq 1 ]; } | wc -l | tr -d ' ')"
echo "slides: built $BUILT, served $SERVED"
if [ "$BUILT" != "$SERVED" ]; then
  echo "[abort] $URL serves $SERVED slides, the build has $BUILT: stale cache or wrong project" >&2
  exit 1
fi
