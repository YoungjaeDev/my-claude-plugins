# Failure triage: agy log classification

The Failure policy step of `SKILL.md`: match agy's most recent log against 3 known signatures and
report only the classification. The log lines carry paths, settings and auth diagnostics the
decision does not need, so the block prints none of them.

```bash
LOG=$(ls -t "$HOME/.gemini/antigravity-cli/log/"cli-*.log 2>/dev/null | head -1)
if [ -z "$LOG" ]; then
  echo "agy-triage: no log found"
elif grep -qE 'auth timed out|silent auth failed|keyringAuth: timed out' "$LOG"; then
  echo "agy-triage: auth-timeout"      # the model never ran — do not retry
elif grep -qE 'rename .*Access is denied' "$LOG"; then
  echo "agy-triage: file-lock"         # transient — the one retry is worth it
elif grep -qE 'text_drip.*length=' "$LOG"; then
  echo "agy-triage: output-dropped"    # generated but not delivered — retry
else
  echo "agy-triage: unclassified"
fi
```
