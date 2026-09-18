# Failure triage: agy log classification

Detail for the Failure policy section's agy triage step, pulled out of SKILL.md so the body
keeps only the failure table.

Triage an agy failure by matching its most recent log against the three known signatures. Match
and report the classification, not the log body: the log sits in an agent configuration
directory and its lines carry paths, settings, and auth diagnostics that the triage decision does
not need. Grepping for the three patterns answers the question with none of that exposure:

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

Show the raw log only if the user asks for it after seeing the classification.
