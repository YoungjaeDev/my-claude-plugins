# Feature Specification: Adopt from davidondrej/skills (2026-07-22)

## Overview
Investigation-phase decision record. NOTHING is implemented yet — this file is the
durable output of a `/interview:interview-methodology` session backed by a 3-seat
council (main Claude session + `codex:codex-rescue` + `antigravity:agy-rescue`),
each of which read `github.com/davidondrej/skills` independently and were then
cross-compared. Implementation is a later session (`decompose-issue` →
`resolve-issue`).

Source repo: **`github.com/davidondrej/skills`** — 37 skills across 5 categories +
a top-level `hooks/` guard triplet. **MIT, Copyright (c) 2026 David Ondrej.** The
repo is explicitly "David Ondrej's *personal* agent skills" (a squashed
auto-published sanitized mirror of a private repo). That personal framing is why
most of it is out of scope for this marketplace — see "Why the rest is skipped".

Method provenance: the adopt-triage vocabulary (gap-filler / insight-reflection /
skip; "diff posture not rules") is this repo's own established methodology, from
`.llmwiki/wiki/plugin-ops/skill-authoring-source-grounded-then-audit.md` §4. That
page also records a prior `mattpocock/skills` adoption batch (PRs #154/#156/#158) —
relevant because David's `teach` skill is itself Matt Pocock's work, already
evaluated and out of scope.

## Interview parameters (user, 2026-07-22)
- **Goal:** both net-new capabilities AND patterns to improve existing plugins.
- **Landing form:** plugins + good guidance into CLAUDE.md/AGENTS.md (and `.llmwiki`).
- **Runtime bar:** Claude-only acceptable per-item (3-runtime portability not mandatory).
- **Session scope:** decision / shortlist ONLY. No implementation this session.

## Council convergence = confidence
All three seats read the repo independently. Where they converged, confidence is
high. The council's real value was catching what the main seat missed by not
reading every axis: `handoff` (both council seats independently ranked it #2) and
the `fable-safe-prompt` do-not-adopt flag (both flagged it on ethics/mission
grounds). Unanimous #1 (`global-agent-guardrails`) was corroboration, not discovery.

## Confirmed Decisions (user, 2026-07-22)

### ADOPT — new capability, lands as a plugin
| # | Skill | Verdict | Notes |
|---|-------|---------|-------|
| A1 | `ops-and-setup/global-agent-guardrails` + `hooks/{deny-dangerous.sh,dangerous-patterns.txt,test-guard.sh}` | **ADOPT (3-seat unanimous #1)** | PreToolUse denylist hook blocking catastrophic shell commands before any agent runs them. Zero equivalent in our 25 plugins. Same "one script, format-arg per runtime" shape as core-config `prompt_inject.sh`. **Seatbelt, not sandbox** (regex bypassable by obfuscation — documented). Conservative allow-set (`rm -rf node_modules`, `git push --force-with-lease` stay allowed). |
| A2 | `agent-orchestration/handoff` | **ADOPT (codex+agy independent #2)** | Manual `/handoff` (`disable-model-invocation: true`). Compacts a session into one copy-paste block; core principle "State, not instructions". Fills the ephemeral session-to-session baton gap (distinct from spec-state cross-run aggregate and llm-wiki durable lore); especially useful for cross-tool Claude→Codex handoff. Pure prompt, portable. |
| A3 | `ops-and-setup/create-readonly-db-role` | **ADOPT — conditional confirmed IN** | User confirmed agents-query-prod-DB is a real recurring use case. Hardened SELECT-only Postgres/Supabase role (grant wall + denylist-not-allowlist + read-only/timeout + RLS `bypassrls` trap + verify-writes-blocked-twice loop). Opens a new "agent DB ops" scope (no existing plugin to extend). |

### MINE — mechanism only into AGENTS.md / `.llmwiki` (NOT adopted as a skill)
| # | Source | What to mine | Target |
|---|--------|--------------|--------|
| M1 | `skill-authoring/effective-agent-skills` | skill-authoring canon (progressive disclosure, description-as-routing-contract, degrees-of-freedom→strictness, ship/security checklist). Independently corroborates our `: ` colon-space YAML trap. | 2-3 lines → `.llmwiki/insight/`; cross-check AGENTS.md authoring rules. Overlaps `plugin-dev:skill-development` — do NOT ship as a plugin. |
| M2 | `research-and-web/research-prompt` | "completion bar + gap-round self-critique + per-finding output format (link+claim+why)" brief-writing rubric. Drop its DeepAPI "executing" tail. | fold into `code-scout:research-orchestrator` synthesis rubric / `tcrei-prompt`. |
| M3 | `agent-orchestration/goal-loop` | two ideas only: the explicit "forbid reward-hacking (do not delete/skip/weaken tests to pass)" clause + the meta-prompting trick (second session drafts the goal contract). Skill itself redundant (`ralph-loop` exists); its `/goal` native-feature claim is UNVERIFIED for our runtimes. | inject into `github-dev:resolve-issue` / `ralph-loop` guidance. |
| M4 | repo-wide pattern | `disable-model-invocation: true` — now a standard Agent Skills spec field for manual-only utilities. | apply to our manual-only skills that shouldn't auto-fire. |
| M5 | `research-and-web/youtube-transcript` (skill itself skipped — DeepAPI-locked) | the portable `yt-dlp --sub-format json3` flatten recipe (avoids the auto-VTT double-line bug). | one insight line, usable IF we ever build a transcript capability. Low priority. |

### CONDITIONAL — deferred
| # | Skill | Status |
|---|-------|--------|
| C1 | `ops-and-setup/google-safe-browsing` | **DEFER** ("다음에 판단"). Prevents/fixes a deployed public web app getting Google's "Dangerous site" flag (neutral landing, no brand-in-domain, Search Console day-one, transparency-API status check). Orthogonal to `insane-search` (that fetches *others'* WAF/anti-bot pages; this protects *our* deployed apps). Revisit if public-webapp deploys + Safe-Browsing flags become a real recurring issue. |

### DO NOT ADOPT — flagged on ethics/mission (not quality)
| # | Skill | Reason |
|---|-------|--------|
| F1 | `agent-orchestration/fable-safe-prompt` | Rewrites cyber/bio/dual-use prompts to slip past Claude Fable 5 safety classifiers (abstract the sensitive domain, delete reasoning-extraction triggers). Both council seats independently flagged: adopting a safety-classifier-evasion tool into a shared marketplace is off-mission regardless of a "false-positive reduction" framing. Do not propagate. |

## Landing shapes (recommended; finalize at decompose)
- **A1 guardrails** → recommended **new standalone plugin** (`command-guard`): a safety
  guard is a separate concern with clean independent enable/disable (feature-lifecycle),
  keeping core-config single-concern. Lower-effort alternative = extend core-config
  (reuse its `hooks/codex-hooks.json` + sync wiring). User deferred the final call to
  decompose. **Required adaptation: the patterns are macOS-flavored (`/Users`,
  `diskutil`) — this operator is on Linux, so tune to `/home` + Linux disk paths.**
  Keep the fail-open-without-`jq` behavior and the `test-guard.sh` harness. Prune the
  Cursor/OpenCode/Pi/Droid/Devin wiring down to Claude Code + Codex + Hermes.
- **A2 handoff** → small standalone plugin OR fold into `spec-state`. Decide at decompose.
- **A3 readonly-db-role** → new plugin (opens "agent DB ops" scope). Decide at decompose.

## Why the rest (~27 skills) is skipped — structural, not quality
David's repo is explicitly personal, so the skip pile splits cleanly:
- **Vendor-locked to David's paid DeepAPI:** `deepapi` (1432 lines), `online-shopping`,
  `fireflies-transcript`, `youtube-transcript` (primary path), `deep-research`,
  `browser-harness` (primary path). Unusable without his account.
- **Personal / machine-hardcoded:** `save-idea` (`~/code/content`), `level-up` (his
  knowledge log), `vps-server-management`, `setup-help`, `cmux`/`herdr` (macOS
  terminal-app control), `anti-sleep`, `pi-custom-model`, `pi-web-search`.
- **Redundant — we already do it equal/better:** `codex-subagent` (codex plugin),
  `distribute-skill-to-all-agents`/`push-skill-to-github` (our `sync-codex/hermes`
  manifests), `folder-specific-claude-and-agents-md` (our deliberate `@import` over its
  symlink — see dual-integration.md), `agent-self-scheduling` (`loop`/`schedule`/cron),
  `brain-to-docs` (`interview`+`docs-forge`), `launch-subagent` (AGENTS.md Part 4;
  also hardcodes model names).
- **Their own anti-pattern (effective-agent-skills warns style-only variants aren't
  skills):** `short`, `remind`, `decisions` (as a plugin — its one-line "list choices
  you're not confident of" folds into our `unverified`/verification discipline, not a
  plugin). **Incomplete:** `prompt-me` (DRAFT). **Stub/profane:** `read-all-adrs`.
- **Out of scope:** `teach` (Matt Pocock's learning-design tool, already-evaluated source).

## License / attribution
MIT © 2026 David Ondrej — permissive. For anything adopted near-verbatim (the
guard script + regex file is the main case) keep an attribution line
(`Adapted from davidondrej/skills (MIT)`). Mined patterns (M1-M5) carry no
obligation.

## Next-session plan (decompose-issue candidates)
1. `command-guard` plugin (A1) — Linux-tuned, 3-runtime hook wiring, test harness. **Highest value.**
2. `handoff` plugin or spec-state fold (A2).
3. `readonly-db-role` plugin (A3).
4. Insight/guidance PR mining M1-M4 (+ M5 optional) into `.llmwiki/insight` + code-scout + resolve-issue.
   Bundling: A1 alone is one PR; A2/A3 may bundle; M1-M4 bundle into one guidance PR.

## Open Questions
- A1 final landing (new `command-guard` plugin vs core-config extend) — confirm at decompose.
- A2 landing (standalone vs spec-state fold).
- C1 `google-safe-browsing` — revisit if public-webapp Safe-Browsing flags become real.

## Sources
- `github.com/davidondrej/skills` @ `main` (pushed 2026-07-21), read via `gh api` + council clones.
- 3-seat council reports (this session): main Claude seat (8+3 SKILL.md read firsthand), `codex:codex-rescue`, `antigravity:agy-rescue`.
- `.llmwiki/wiki/plugin-ops/skill-authoring-source-grounded-then-audit.md` §4 — this repo's own adopt-triage methodology + prior mattpocock batch record.
