# Result recovery

Step 2 of Result Handling in `SKILL.md`: copy a generated image the Codex session left in its own folder into the output directory, 1 source file per missing destination.

Each `codex exec` call is one session. Read its id from the `session id: <UUID>` line of that call's stderr banner. The banner is undocumented (the documented id is the `thread_id` of the `thread.started` event, which only `codex exec --json` emits), so when the line is missing, report the gap rather than guess a folder.

## Copy one file per missing destination

- **Per destination**: with `-n` or `--variants` there is one expected destination per image. Recover each from the session that produced it, and never copy one file into several destinations.
- **Newest first**: list the folder's `*.png` files by mtime and give each missing destination a different entry. Do not pin a filename pattern; it varies by Codex version.
- **No overwrite**: copy under the requested filename base and refuse an existing destination.

```bash
src=$(ls -t "${CODEX_HOME:-$HOME/.codex}/generated_images/<session-id>"/*.png 2>/dev/null | sed -n "<k>p")   # k = 1 for the first missing destination, 2 for the next, ...
[ -n "$src" ] || { echo "no image in session folder" >&2; exit 1; }
dest="<output-dir>/<filename-base>.png"
[ -e "$dest" ] && { echo "refusing to overwrite $dest" >&2; exit 1; }
cp "$src" "$dest"
```

Never re-run generation because a copy failed. The image already exists, and a second run bills a second generation.
