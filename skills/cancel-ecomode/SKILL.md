---
name: cancel-ecomode
description: Cancel active Ecomode mode
---

# Cancel Ecomode

[ECOMODE CANCELLED]

The Ecomode has been cancelled. Clearing state files.

## MANDATORY ACTION

**First**, check if ecomode is linked to an active Ralph loop:

```bash
cat .omc/ecomode-state.json 2>/dev/null | jq -r '.linked_to_ralph // false'
```

**If linked_to_ralph is true**: Use `/oh-my-claudecode:cancel-ralph` instead to cancel both Ralph and its linked Ecomode.

**Otherwise**, execute this command to cancel Ecomode:

```bash
mkdir -p .omc && \
echo '{"active": false, "cancelled_at": "'$(date -Iseconds)'", "reason": "User cancelled via /cancel-ecomode"}' > .omc/ecomode-state.json && \
echo '{"active": false, "cancelled_at": "'$(date -Iseconds)'", "reason": "User cancelled via /cancel-ecomode"}' > ~/.claude/ecomode-state.json
```

After running this command, ecomode will be deactivated and the HUD will update.

## Note on Linked Modes

Since v3.5, Ralph can activate either Ultrawork OR Ecomode based on user preference. If you see `linked_to_ralph: true` in the ecomode state, it means Ecomode was auto-activated by Ralph. In this case:
- Use `/oh-my-claudecode:cancel-ralph` to cancel both modes
- If you only cancel ecomode, Ralph will continue but without parallel execution benefits

## To Start Fresh

- `/oh-my-claudecode:ecomode "task"` - Start ecomode only (standalone)
- `/oh-my-claudecode:ralph "task"` - Start ralph with default execution mode
