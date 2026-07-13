---
id: codex-review-threads-never-resolve
aliases: [codex-comments-reanchor-to-head, new-vs-old-findings-by-review-id, open-threads-proxy-overcounts, cr-skipped-threads-stand]
last_verified: 2026-07-13
status: active
volatility: volatile
sources: 3
---

# Codex never resolves its review threads; CodeRabbit does

The two reviewers `cr-fix` drives behave differently after a fix lands, and the difference makes "how many findings are left?" unanswerable from thread counts.

## What each bot does on re-review

**CodeRabbit** re-reviews the new push and marks the threads its fix satisfied as `isResolved: true`. Its check-run flips to `success` (or `neutral` when it has nothing to add). Counting unresolved CR threads is a valid convergence signal.

**Codex** posts a new review and leaves every earlier thread open. GitHub then re-anchors a still-applicable comment onto the newest commit, updating its `commit_id` and shifting its `line` to wherever the code moved. So an already-fixed Codex finding reappears at a new line, on the current SHA, in the current diff — indistinguishable from a fresh one at a glance.

**CodeRabbit's resolution has a blind spot of its own**: it auto-resolves only the threads a *code change* satisfies. A suggestion the loop deliberately judged `skip` (spurious, or YAGNI-refused) stays unresolved forever and is re-raised **verbatim** on every re-review, its `line` re-anchoring as the file shifts. On PR #122 the same two skip-judged threads returned across three consecutive re-reviews. Convergence must therefore count only applies/defers per cycle; a stable residue of standing skip-judged threads is the *expected* end state of a converged PR, not leftover work.

Observed on PR #106 across five review rounds: thread count went 3 → 6 → 12 while the genuinely new findings per round were 3 → 3 → 1. Every "extra" thread was a resolved-in-code Codex comment that had followed the diff.

## The only reliable discriminator

`pull_request_review_id`. Fetch the reviews, take the ids whose `commit_id` equals the SHA you just pushed, and keep only the comments belonging to those reviews:

```bash
NEW=$(gh api --paginate "repos/{owner}/{repo}/pulls/$PR/reviews" \
  | jq -s -r --arg s "$SHA" 'add // [] | [.[] | select(.commit_id==$s)] | map(.id) | @csv' | tr -d '"')
gh api --paginate "repos/{owner}/{repo}/pulls/$PR/comments" \
  | jq -s --arg ids "$NEW" 'add // [] | ($ids|split(",")|map(tonumber)) as $I
      | [.[] | select(.in_reply_to_id==null and (.pull_request_review_id as $r | $I | index($r)))]'
```

Neither `commit_id` on the comment nor `isOutdated` on the thread works: the first is rewritten by re-anchoring, and the second stays `false` while the code still matches the comment's context.

## Two consumers currently get this wrong

`post-merge` Step 1.5 counts top-level review comments as an "open threads" proxy and reports it alongside the cr-fix defer list. On a Codex-reviewed PR that number is dominated by comments Codex has never resolved, so it overstates leftover work — 15 open comments on a PR whose real leftover was one deferred finding.

A convergence loop that stops when "unresolved threads == 0" will never stop on a Codex PR.

## Consequence for the iteration cap

Because Codex re-reviews every push and never closes its own threads, the loop's terminating signal has to come from *new findings per round*, not from thread state. `cr-fix`'s default `--max-iter 5` is doing real work here: PR #106 converged 2 → 3 → 6 → 1 → 2 applied fixes across five rounds and would have kept producing small findings indefinitely.

> See-also: [[cr-fix-yagni-over-engineering-axis]]
> See-also: [[state-file-self-describing]]
> Evidence: plugins/github-dev/skills/post-merge/SKILL.md

## Sources

1. **PR #106** (`feat(project-init): ASK verdict class + three efficacy axes`) — five review rounds. Review ids `4667955030` / `4670906496` / `4671038720` / `4671134067` / `4671174743` (Codex, none resolved) against `4667970382` / `4671078375` / `4671130001` / `4671174112` (CodeRabbit, resolving as fixes landed). Codex comments from the first review re-anchored from `project_state.sh:275` → `:290` → `:301` as the file grew.
2. **PR #107** (`feat(core-config): conditional [council] pointer`) — CodeRabbit auto-resolved both threads its fix satisfied on the next push (`isResolved: true`, `isOutdated: true`); Codex was not engaged, so the contrast is clean.
3. **PR #122** (`fix(github-dev): cr-fix correctness repair set`) — the CR skip-residue instance: threads at SKILL.md lines 71/604 (judged `skip` in iter 3) re-raised verbatim in iters 4-6, line-shifting 604 → 607 as edits landed above; the loop converged with both still open by design.
