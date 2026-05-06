# Feature Specification: Codex Review Integration + CR Nitpick Skip

## Overview

Extend `cr-fix` (and downstream `resolve-issue`) to additionally process **ChatGPT-Codex** (`chatgpt-codex-connector[bot]`) review comments alongside CodeRabbit, while explicitly **skipping** all CodeRabbit Nitpick-class items. Wait synchronization is gated on CodeRabbit (the only bot emitting commit-status); Codex is processed opportunistically with a configurable grace period after CodeRabbit completes.

Reference case: PR YoungjaeDev/jaywalk-vlm-risk#116 — CodeRabbit posted only Nitpicks (in review-body `<details>` block), Codex posted P2-class inline comments via `/pulls/{N}/comments` with `line: null`.

## User Stories

- As a PR author, I want cr-fix to wait for both CR and Codex before processing so I get unified feedback in one cycle.
- As a PR author, I want Nitpick-class items skipped entirely so I don't spend time on low-value polish suggestions.
- As a PR author, I want Codex P1/P2 issues surfaced for review-and-apply but P3 silently dropped.
- As a PR author, I want repos without Codex configured to behave identically to today (no regression, no extra wait).

## Requirements

### Must Have (P0)

- [ ] **CodeRabbit Nitpick complete skip**
  - Tier classifier removes the `📝 Nitpick + Minor/Trivial/Info → auto` entry; Nitpicks are filtered out **before** Step 9a table rendering. They do not appear in the table, do not auto-apply, do not increment `applied_this_cycle`/`deferred_this_cycle`.
  - The CodeRabbit review-body-level `<details>🧹 Nitpick comments</details>` block is also ignored (reuse current behavior — Step 8 only reads `reviewThreads`, never review-body).

- [ ] **Codex inline comment fetch**
  - New Step 8b after the current Step 8: call `gh api repos/$OWNER/$REPO/pulls/$PR_NUM/comments`, filter `user.login == "chatgpt-codex-connector[bot]"`, keep entries where `commit_id == $CUR_SHA` (review for the current SHA only — older-SHA entries already addressed).
  - Each Codex inline comment becomes a thread-equivalent record with: `path`, `line` (may be `null`), `body`, `severity` (parsed from P1/P2/P3 badge), `source: "codex"`.
  - Codex review-level body (`/reviews` endpoint) is ignored — actionable content lives only in inline comments.

- [ ] **Codex P-badge severity parsing**
  - Regex on body header: `!\[P([123]) Badge\]\(https://img\.shields\.io/badge/P([123])-([a-z]+)-flat\)`.
  - Color mapping (verified from PR #116): P1=red, P2=yellow, P3=green.
  - Map: P1 → `gated`, P2 → `gated`, P3 → `skip` (filtered before table, same as CR Nitpick).
  - If body has no P badge AND review state == APPROVED: treat as no-finding (silent).
  - If body has no P badge AND review state == COMMENTED: log a warning and tier as `review` (surface, don't auto-fix).

- [ ] **Wait synchronization (CR-gated, Codex grace)**
  - Step 6 unchanged: poll CR commit-status until `success`/`failure`/`timeout`.
  - **New Step 6b**: after CR `success`, if Codex is active (see auto-detect below), spawn a second background poller via `Bash(run_in_background)` that polls `/pulls/$PR_NUM/reviews` every 30s for up to `--codex-grace` seconds (default 90), looking for any review with `commit_id == $CUR_SHA AND user.login == "chatgpt-codex-connector[bot]"`.
  - Use `Monitor` to wait — same pattern as CR polling. Token cost during wait ~0.
  - On grace period expiry without Codex review, proceed with CR-only fetch.
  - On `final_state="failure"` or `"timeout"` for CR: skip Codex grace entirely.

- [ ] **Codex auto-detect (zero-config opt-in)**
  - In Step 2 (state init), set `codex_active=unknown`.
  - At top of Step 6 first iteration only: probe `gh api repos/$OWNER/$REPO/pulls/$PR_NUM/reviews --jq '[.[] | select(.user.login == "chatgpt-codex-connector[bot]")] | length'`.
  - If count > 0: `codex_active=true` for the run. If count == 0: `codex_active=false` for the run (Codex grace skipped, Codex fetch skipped).
  - Cached for the entire `cr-fix` run; not re-probed per iteration.
  - Override flag: `--no-codex` forces `codex_active=false`. (No `--with-codex` flag in V1 — to force Codex on a brand-new PR, the user can comment `@codex review` on GitHub which makes Codex post a review, and the next `cr-fix` run picks it up via auto-detect.)

- [ ] **Codex `line: null` handling**
  - File-level gated tier: when Codex comment has `path` but `line == null`, the gated review flow reads the **whole file** (or up to first 500 lines if huge) instead of `±20` lines around an anchor.
  - LLM derives the affected location from the comment body text by inspecting the file content.
  - AskUserQuestion still presents one issue at a time (Apply/Defer/Modify) — no batching.
  - If file exceeds 1000 lines: log a warning `codex-file-too-large: skipping <path> (use Serena symbol-level navigation)`, increment `deferred_this_cycle`, surface to user post-run.

- [ ] **Source column in Step 9a table**
  - Add `Source` column: `CR` for CodeRabbit thread, `Codex` for Codex inline comment.
  - No deduplication: if both bots flagged the same `path:line`, both rows appear. User decides per row.

- [ ] **Step 9a tier table extension**

  | Issue source | Type / Badge | Severity | Tier |
  |--------------|--------------|----------|------|
  | CR | `🚨 Bug` / `⚠️ Potential issue` | any | `gated` |
  | CR | anything | `🔴 Critical` / `🔴 High` / `🟠 Major` | `gated` |
  | CR | `🔒 Security` (any field) | any | `gated` |
  | CR | `🛠️ Refactor suggestion` | `🟡 Minor` / `🟢 Trivial` / `🟢 Info` | `auto` |
  | CR | `📝 Nitpick` | any | **`skip`** (was `auto` — REMOVED) |
  | CR | `💡 Verification agent` / `🔍 Outside diff range` | any | `review` |
  | Codex | P1 (red) | n/a | `gated` |
  | Codex | P2 (yellow) | n/a | `gated` |
  | Codex | P3 (green) | n/a | **`skip`** |
  | Codex | no badge + COMMENTED | n/a | `review` |
  | Codex | no badge + APPROVED | n/a | (silent — no row) |

- [ ] **`skip` tier semantics**
  - New tier value alongside `auto`/`gated`/`review`.
  - Items classified `skip` are filtered out **before** Step 9a table rendering. They never appear to the user, never increment applied/deferred counters, never trigger AskUserQuestion.
  - Final JSON gains a counter: `skipped_total: <n>` (sum of CR Nitpicks + Codex P3 across all iterations) for telemetry.

- [ ] **resolve-issue passthrough**
  - Add to resolve-issue.md flag table:
    - `--codex-grace <sec>` → forwarded as cr-fix's `--codex-grace`
    - `--no-codex` → forwarded as cr-fix's `--no-codex`
  - Default behavior (no flags): cr-fix runs with `auto-detect ON + 90s grace`.

### Should Have (P1)

- [ ] **Final JSON schema extension**
  ```json
  {
    "iterations": <n>,
    "applied_total": <n>,
    "deferred_total": <n>,
    "skipped_total": <n>,
    "codex_state": "active|inactive|disabled",
    "final_state": "clean|user_declined|iteration_cap|timeout|failure|cr_inactive|unknown",
    "merged": <bool>,
    "pr": <num>,
    "last_sha": "<sha>"
  }
  ```
  - `codex_state`:
    - `active` — Codex reviewed at least one SHA during the run (auto-detect ON)
    - `inactive` — auto-detect found no Codex history on the PR
    - `disabled` — explicit `--no-codex`

- [ ] **Engagement gate parity**
  - Today's CR-engagement gate (Step 8 zero-actionable handling) blocks "PR just opened, CR hasn't started" cases. Mirror this for Codex: if `codex_active=true` AND zero Codex inline + zero CR threads after first iteration, do NOT declare convergence — re-poll once.

### Nice to Have (P2)

- [ ] Telemetry summary line at end-of-run: `cr-fix: applied=N deferred=N skipped=N codex=active iterations=N final=clean`
- [ ] Step 9a table footer: `(N CR Nitpicks + M Codex P3 hidden — pass --show-skipped to inspect)` if `skipped_total > 0`. (Skip flag implementation deferred to V2.)

## Technical Constraints

- Node 18+ / standard `gh` CLI / `jq`. No new external deps.
- All Codex bodies are Korean prose in PR #116 — sanitization rules already redact paths/URLs/secrets and are language-agnostic. No additional i18n work needed.
- `commit_id` field on review/comment objects is the canonical SHA tie. Use it instead of body parsing of `Reviewed commit:` text.
- Fetch path: comment-level `gh api repos/.../pulls/$N/comments` returns inline review comments only (NOT issue comments — those are at `/issues/$N/comments`). Verified against PR #116.
- Codex comments **do not** appear in GraphQL `reviewThreads` — must use REST `/pulls/$N/comments` endpoint.

## UI/UX Requirements

- **Step 9a table format** (when both bots have output):
  ```
  Source   Type/Badge          Severity   Path:Line                   Tier
  CR       🚨 Bug              Critical   src/auth/middleware.py:42   gated
  Codex    P1                  -          src/auth/handler.py:null    gated
  Codex    P2                  -          src/api/routes.py:null      gated
  CR       🛠️ Refactor         Minor      src/util/format.py:88       auto
  ```
- **Hidden item disclosure**: If `skipped_total > 0`, append a one-line note below the table:
  ```
  (3 items hidden: 2 CR Nitpicks, 1 Codex P3 — see full PR for details)
  ```
- **AskUserQuestion description for gated tier**: include `Source: CR | Codex` in the per-issue prompt so user knows which bot's verdict they're acting on.

## Edge Cases

| Scenario | Expected Behavior |
|----------|------------------|
| PR has no CR engagement AND `codex_active=true` | Apply CR-engagement gate as today (re-poll); Codex grace still runs. |
| CR `final_state=failure`, Codex active | Skip Codex fetch entirely. Surface CR failure as today. |
| CR `final_state=clean` (zero threads), Codex P1 found | Treat as **not clean**. Process Codex as gated. `final_state` becomes whatever the Codex flow ends as. |
| Codex review for HEAD SHA exists at CR-completion moment | Skip 6b grace entirely (already done — fast path). |
| Codex review SHA != HEAD SHA (user pushed mid-grace) | Treat as `grace_expired`; do not block. Next iteration's probe may pick up newer Codex review. |
| Both CR Nitpick AND Codex P3 on same path:line | Both filtered to `skip`, silently dropped. No user prompt. |
| Codex comment body has malformed P badge | Treat as `review` (no badge case), log warning. |
| Codex returns review with state=CHANGES_REQUESTED | Same as COMMENTED — process inline comments. (Codex spec doesn't currently emit this state but be defensive.) |
| Codex file >1000 lines | Skip with warning, increment `deferred_this_cycle`, do not block run. |
| Repo has Codex but specific PR has no Codex review yet (brand-new PR) AND no `--with-codex` | `codex_active=false` for the run (auto-detect counts existence, not freshness). User can re-run cr-fix later or pass `--with-codex` to force grace wait. |

## Affected Files

| File | Change |
|------|--------|
| `plugins/github-dev/commands/cr-fix.md` | Step 1 (new flags), Step 2 (state init), Step 6b (Codex grace polling), Step 8 (existing CR fetch unchanged), new Step 8b (Codex fetch), Step 9a (tier table extension + Source column + skip tier), Step 9c (Codex line:null gated handling), Step 16 (final JSON schema extension) |
| `plugins/github-dev/commands/resolve-issue.md` | Flag table: add `--codex-grace`, `--no-codex` passthrough rows. Step 10.5 banner mention codex auto-detect. |
| `plugins/github-dev/CLAUDE.md` | Update cr-fix description row + resolve-issue Flags table |
| `plugins/github-dev/.claude-plugin/plugin.json` | Bump `version` to `1.15.0` (MINOR — backward-compatible feature) |
| `.claude-plugin/marketplace.json` | Sync github-dev `version` to `1.15.0`; bump `metadata.version` |
| Root `CLAUDE.md` | github-dev row: append note about Codex integration |
| Root `README.md` | Optional: brief mention in github-dev section |

## Out of Scope (V2 — defer)

- `--show-skipped` flag (post-V1 telemetry feature)
- Other review bots (Greptile, Renovate, etc.)
- Fuzzy-match dedup between CR and Codex on overlapping issues
- Codex `@codex address that feedback` comment posting (one-way fetch only for V1)
- Symbol-level navigation for Codex `line:null` cases via Serena (V1 reads file directly, falls back to skip on >1000 lines)
- Resume-from-interruption for cr-fix runs interrupted during Codex grace polling
- CodeRabbit review-body-level `<details>` block parsing (intentionally skipped per Q5 decision)

## Open Questions

None at spec time — all decisions resolved via interview. If implementation surfaces new ambiguities, escalate via AskUserQuestion before writing code.

## Implementation Order

1. **Phase 1** — cr-fix.md edits (the bulk of the work):
   1. Step 1 + Step 2 (flags + state)
   2. Step 6b + auto-detect probe
   3. Step 8b (Codex fetch)
   4. Step 9a tier table + Source column + `skip` tier filter
   5. Step 9c Codex `line:null` handling
   6. Step 16 final JSON schema
2. **Phase 2** — resolve-issue.md flag passthrough
3. **Phase 3** — CLAUDE.md / marketplace.json / version bumps
4. **Phase 4** — Local validation: re-test against PR #116 expectation (CR Nitpick hidden, Codex P2 surfaced as gated, no false convergence).

## Validation

Before merging this change:

1. Dry-run `cr-fix` against PR #116 (no actual fix applied — `--max-iterations 0` or read-only mode) and verify:
   - Step 9a table shows 0 CR rows (only Nitpick existed) and 2 Codex P2 rows.
   - `codex_state == "active"`, `skipped_total == 1` (the CR Nitpick block — though we don't parse it, so actually `skipped_total == 0` from that block; verify Codex P3 cases on a different PR).
2. Run against a PR with **no Codex history** (any other repo): verify `codex_state == "inactive"`, no grace wait, behavior identical to today.
3. Run against a PR with **only CR Nitpicks** (no substantive items, no Codex): verify `final_state == "clean"`, table is empty, `skipped_total == <n>` if Nitpick threads were inline (not body-only).

## References

- PR YoungjaeDev/jaywalk-vlm-risk#116 — driving case
- Current cr-fix tier classifier: `plugins/github-dev/commands/cr-fix.md:228-249`
- Current Step 6 wait phase: `plugins/github-dev/commands/cr-fix.md:105-137`
- Current Step 8 GraphQL fetch: `plugins/github-dev/commands/cr-fix.md:160-198`
- Codex inline comment format (sample):
  ```
  POST /pulls/116/comments — fetched fields:
  user.login: "chatgpt-codex-connector[bot]"
  commit_id: "3c4585311e..."
  path: "src/gt_review/__main__.py"
  line: null
  body: "**<sub><sub>![P2 Badge](https://img.shields.io/badge/P2-yellow-flat)</sub></sub>  <title>**\n\n<korean prose>"
  ```
