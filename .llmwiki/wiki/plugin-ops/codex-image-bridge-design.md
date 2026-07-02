---
id: codex-image-bridge-design
aliases: [codex-image, codex-exec-delegation, sub-cli-model-inherit, passthrough-shell-validation, disable-model-invocation, --ref, edit-vs-reference-arg]
last_verified: 2026-07-02
status: active
volatility: stable
sources: 3
---

# Designing a Claude→sub-CLI bridge skill (codex-image)

`codex-image` is a Claude-only skill that generates images by shelling out to
`codex exec` (Codex CLI's own image-gen) instead of calling the OpenAI REST API.
That delegation shape — a Claude skill driving an external model CLI as its
backend — has five design rules that are easy to get wrong, most confirmed on
codex-cli 0.142.

> See-also: shared-source-codex-manifests

## Inherit the sub-CLI's default model — don't pin

Omit `-m`/`--model` in the default path. The bare `codex exec` uses the user's
own Codex default model, which **auto-tracks the latest upstream model with zero
per-release maintenance**. Pinning a model id in the skill would mean chasing
weekly model renames (the "5.5?" problem) for no benefit. Expose `--model` as an
**opt-in** override, not a default. The general rule: when you delegate to a CLI
that already resolves a sensible default, inheriting it is more durable than
re-encoding the choice one layer up.

## Least-privilege sandbox over "yolo"

Default to `-s workspace-write` — the minimal sandbox that can still write the
PNG into the output dir. It is the deliberate opposite of a bypass:

- `-s read-only` can't save the file; `-s danger-full-access` over-grants.
- The true bypass is `--dangerously-bypass-approvals-and-sandbox` (skip approvals
  **and** sandbox). codex 0.142 exposes **no `--yolo` alias** for `codex exec` —
  use the canonical long flag, opt-in only, never default.
- `codex exec` is headless, so it never blocks on approval prompts; the sandbox
  flag (not a bypass) is what actually governs what it can touch.

## Validate passthrough args at the shell trust boundary

A user-supplied `--model` value reaches a shell argument (`-m <id>`). Validate it
before interpolation — the skill is otherwise security-careful (it already routes
the *prompt* through stdin, never a shell arg) and the override path must match:

- `--model`: require `^[A-Za-z0-9._:-]+$`; refuse anything else (a value with
  shell metacharacters could be parsed as a separate command).
- `--reasoning` / `--sandbox`: enum-constrain (`low|medium|high|xhigh`;
  `read-only|workspace-write|danger-full-access`) — they interpolate into the
  command line too.

The regex `^[A-Za-z0-9._:-]+$` already accepts real model ids (`gpt-5.5`,
`gpt-5.4-mini`, `o3`) and rejects injection — a **trailing `-` in a character
class is a literal hyphen, not a range**. A Codex P2 review misread it as
excluding hyphens; empirically refuted (bash ERE + python `re` both accept the
hyphenated ids and reject `evil; rm -rf /`), so it was skipped.

## Visibility is not a cost gate — model-invocable + in-body grounding

`disable-model-invocation: true` (used through 1.1.0 as the "manual only, cost
and side effects" guard) removes the skill from the agent's available-skills
list entirely — slash-invocation only. That fails as a cost gate in exactly the
workflow the skill exists for: a deck-build pipeline whose spec named
codex-image as the image path could not see or load the skill, so it dispatched
a 140k+-token research agent to re-derive raw `codex exec` usage — and then ran
generation autonomously anyway. The flag hid the *recipe* without preventing
the *cost*; it only removed the safest, cheapest path to the action.

Since 1.2.0 the skill is model-invocable and the gate lives in the body:
generation needs explicit grounding (a direct user request, or a task spec that
names codex-image), and the agent asks before generating when grounding or
scope is ambiguous. General rule: a cost/side-effect gate must sit where the
agent can read it at decision time — invisibility is not enforcement.

## Generic attach flag, no built-in edit-vs-reference semantics

`codex exec`'s `-i, --image <FILE>...` (verified via `codex exec --help` on
codex-cli 0.142.3) is a bare "attach image(s) to the initial prompt" transport
— it carries no notion of "edit this file" vs. "use this only as inspiration
for a different image." `--edit` (edit an existing image, output still a new
non-destructive file — never claim it overwrites the input) and `--ref`
(attach as a style/character reference while generating an otherwise-new
image) both resolve to the same `-i <path>` call; the only thing that can
carry the edit-vs-reference *intent* is the prompt text sent alongside it (see
Prompt Handoff). That distinction is therefore **unverified** absent a live
generation test — mark it as such in the skill body and check the actual
first-use output (new image guided by the reference, not a near-copy or a
literal edit of it) rather than asserting the split works.

## Quote/array-exec is the injection defense, not a character denylist

`--edit` / `--ref` paths reach the same shell-command line as `--model` (both
end up in a `codex exec ... -i "<path>" ...` invocation), so they need the
same passthrough-validation discipline as the section above — a dogfooded
cr-fix loop (PR #92, 5 real findings across 5 iterations, one rated P0) is
proof the naive version of that rule is wrong. The first fix denylisted a
literal set of shell metacharacters including `\` and `:`; that broke every
Windows path (the skill's own PowerShell examples use `C:\...`), a self-
inflicted regression caught by CodeRabbit one iteration later. Correct rule:
the actual injection defense is **passing the path as a single quoted/escaped
shell argument or via array-form exec — never string concatenation**; a
character check on top of that should reject only characters that are never
legitimate in a *shell-command* position (`` ` $ " ' ; | & < > ( ) ``), and
must explicitly exclude characters that are legitimate in a *path* on some
platform (`\` separator, `:` drive letter on Windows). Denylisting for
"looks dangerous" without checking what a real path on every supported
platform looks like breaks the feature for an entire platform, not just the
attacker's crafted input.

## Sources

- `plugins/codex-image/skills/codex-image/SKILL.md` (PR #80, merged b681a26) — the
  passthrough-override design + Validation step 7; codex-cli 0.142 `codex exec --help`.
- PR #91 (merged 7be395d) — `disable-model-invocation` retirement + in-body
  grounding gate; deck-build dogfood where the hidden skill cost a 140k+-token
  `codex exec` re-derivation while generation still ran.
- PR #92 (merged e431312) — new `--ref` argument + unverified edit-vs-reference
  caveat; cr-fix dogfood surfaced the P0 shell-injection gap in `--edit`/`--ref`
  and the Windows-path regression in the first fix attempt; `codex exec --help`
  on codex-cli 0.142.3 confirmed `-i, --image` is generic attach, not edit-scoped.
