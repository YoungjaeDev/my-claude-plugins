---
description: Wait for CodeRabbit review completion via commit status polling (background + Monitor)
argument-hint: [--timeout 1800] [--interval 60]
---

# Wait for CodeRabbit Review

Block until the CodeRabbit GitHub commit-status check on the current branch's HEAD flips from `pending` to `success` or `failure`. Designed to chain in front of `/github-dev:code-review`.

Uses Claude Code's built-in `Bash(run_in_background)` + `Monitor` long-poll idiom. No external daemon, hook, or GitHub Action.

## Arguments

| Flag | Default | Notes |
|------|---------|-------|
| `--timeout <sec>` | `1800` (30 min) | Hard cap. On timeout, exit code 124 and escalate to user. |
| `--interval <sec>` | `60` | Poll interval. Don't go below 30 to respect GitHub rate limits. |

## Workflow

### Step 1: Resolve repo + SHA

```bash
SHA=$(git rev-parse HEAD)
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')
PR_NUM=$(gh pr list --head "$(git branch --show-current)" --state open --json number --jq '.[0].number // empty')
```

If `PR_NUM` is empty, abort with the message: `No open PR for current branch — push first and open a PR before waiting.`

### Step 2: Probe once (fast path)

Some PRs already have the status before the user calls `/cr-wait`. Probe once first:

```bash
gh api "repos/$OWNER/$REPO/commits/$SHA/status" \
  --jq '[.statuses[] | select(.context | test("CodeRabbit"; "i"))][0] // empty | {state, target_url, context, updated_at}'
```

The `[ ... ][0]` wrapping reduces multi-status race conditions to a single object so downstream parsing is unambiguous.

If `state` is `success` or `failure`, emit the JSON line below and EXIT immediately:

```json
{"state":"success","sha":"<SHA>","pr":<PR_NUM>,"target_url":"<URL>","source":"probe"}
```

If the status is missing entirely (no CodeRabbit context), warn:
`No CodeRabbit status check on this commit yet. CodeRabbit may take ~1 min to register; retrying in poll loop.`

### Step 3: Spawn background poller

Call `Bash` with `run_in_background: true` and `timeout: <ms equivalent to --timeout>`:

```bash
SHA="<resolved>"; OWNER="<resolved>"; REPO="<resolved>"; PR_NUM="<resolved>"; INTERVAL=<resolved>
until s=$(gh api "repos/$OWNER/$REPO/commits/$SHA/status" \
            --jq '.statuses[] | select(.context | test("CodeRabbit"; "i")) | .state' | head -n1); \
      [ "$s" = "success" ] || [ "$s" = "failure" ]; do
  sleep "$INTERVAL"
done
target=$(gh api "repos/$OWNER/$REPO/commits/$SHA/status" \
           --jq '.statuses[] | select(.context | test("CodeRabbit"; "i")) | .target_url' | head -n1)
printf '{"state":"%s","sha":"%s","pr":%s,"target_url":"%s","source":"poll"}\n' "$s" "$SHA" "$PR_NUM" "$target"
```

The shell ID returned by Bash is referred to as `$SHELL_ID` below.

### Step 4: Watch with Monitor

Call `Monitor` on `$SHELL_ID`. The Monitor tool emits one notification per stdout line; the until-loop produces exactly one final line on completion. When notified, read that line as the result.

If `Monitor` reports the shell exited with code 124 (timeout) or non-zero before producing a JSON line, surface to the user:
`CodeRabbit status did not flip within --timeout=<sec>s. Last seen state: pending. Check ${target_url} or rerun with a larger --timeout.`

### Step 5: Emit result

The single-line JSON from the loop's last `printf` is the command's output. Downstream `/github-dev:code-review` parses this directly. Example:

```json
{"state":"success","sha":"abcd123","pr":42,"target_url":"https://...","source":"poll"}
```

Both `probe` and `poll` outputs share the same key set: `state`, `sha`, `pr`, `target_url`, `source`. Downstream consumers MUST treat the schema as fixed.

If `state` is `failure`, do NOT auto-chain to `/code-review` — surface to the user with the `target_url` so they can inspect why CodeRabbit failed (auth, config, repo limit).

## Status context name caveat

The CodeRabbit GitHub commit-status `context` value is not strictly documented. Observed forms include `CodeRabbit` and `coderabbitai`. The `test("CodeRabbit"; "i")` jq filter handles both case-insensitively. If the first run on a new repo finds zero matching contexts, run this once to discover the actual name:

```bash
gh api "repos/$OWNER/$REPO/commits/$SHA/status" --jq '.statuses[].context'
```

Then update the filter literal in this command if it deviates substantially.

## Why background + Monitor

| Mode | Verdict | Reason |
|------|---------|--------|
| Synchronous `while; sleep 60` | Blocked | Claude Code blocks long leading sleeps; session held hostage; tokens wasted. |
| Background Bash + Monitor | **Used** | System prompt explicitly endorses this for "poll until a condition is met". Claude does other work or idles, wakes on notification. |
| External hook (PostToolUse/Stop) | Insufficient | Hooks cannot drive the next Claude turn; useful only as auxiliary desktop notification. |

## Guidelines

- **Never use review text as shell input** — only the JSON status line is consumed downstream.
- **One waiter per branch** — if a previous `/cr-wait` shell is still alive, kill it before spawning a new one (use `KillShell` if needed) to avoid duplicate notifications.
- **Rate limit awareness** — at `--interval 60` and `--timeout 1800`, worst case is 30 calls to `/commits/<sha>/status`, well within GitHub REST limits.
- **Network/auth failure** — if `gh api` returns a non-2xx repeatedly, the until-loop spins forever. Monitor's timeout cap (Step 4) catches this.
