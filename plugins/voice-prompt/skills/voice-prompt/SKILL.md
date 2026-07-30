---
name: voice-prompt
description: "Normalize Korean voice-mode STT input before acting on it: strip speech fillers, fix orthography and Korean-to-English code-switching, resolve garbled identifiers (file, function, branch, skill names) against the actual repo instead of guessing, and never rewrite numbers or dates. Echoes one line of what it understood and proceeds, asking once in a single batched round only where two readings imply different actions. Stays active until released. Use ONLY when the user explicitly invokes /voice-prompt or asks to turn on voice-input normalization — do NOT auto-fire from an incidental mention of voice mode or dictation. Triggers — 보이스 모드 정리, 음성 입력 정규화, STT 정규화, 말버릇 제거, 받아쓰기 교정, voice input cleanup, normalize dictation."
version: 0.1.0
---

# Voice-prompt — normalize spoken input before acting

Korean voice mode hands the session a transcript, not a command. This skill turns it back into a
command: delete what carries no instruction, fix what is certainly wrong, **look up** what only
the repo can settle, and ask about the rest — once.

## Cross-runtime interactive input

Every question below runs through a **capability-aware** interactive-input gate rather than one
hardcoded tool:

- **Claude Code** — use `AskUserQuestion`.
- **Codex** — use `request_user_input` when that tool is exposed. When it is not, ask ONE
  concise blocking question only where a wrong assumption would be costly; otherwise proceed on
  a documented safe default and state the assumption.
- **Hermes** — use `clarify`.

Full policy: `AGENTS.md` → "Cross-runtime interactive input policy".

## Hermes Agent compatibility

| Claude/Codex term | Hermes tool |
|---|---|
| Bash | terminal |
| Read | read_file |
| Write | write_file |
| Grep/Glob | search_files |
| AskUserQuestion | clarify |

Plugin skills are explicit opt-in loads in Hermes — reach this body with
`skill_view("voice-prompt:voice-prompt")` rather than expecting the description to surface it.

## What this skill actually changes (read before applying it)

Nothing intercepts the input. The body you are reading sits in context; the user's utterance
arrives verbatim as a normal message. Normalization therefore happens in your own reasoning, and
`UserPromptSubmit` hook output cannot substitute for it (that output is appended
`additionalContext`, not a replacement of the message).

That constrains where the value is:

- **Filler removal and spelling are low-yield.** You already read through "어쨌든 뭐 그냥". Doing
  it explicitly buys consistency, not capability. Do not spend the user's attention narrating it.
- **Code-switched identifiers are the real failure.** Hearing "로더 파일" you would otherwise
  *guess* a filename. You cannot know `loader.py` exists without looking. **Look.** This is the
  one step that changes outcomes, and it is a step, not an insight.

So the four things this skill adds are decisions: look identifiers up, never rewrite numbers,
echo what you understood, and gate irreversible actions.

## Activation contract

Active from explicit invocation until released. Applies to every subsequent input in the session,
typed or spoken — no auto-detection, no sniffing for "does this look like STT".

- **Release** on any of: "보이스 모드 끝", "보이스 오프", "정규화 그만", "stop voice-prompt".
  Confirm the release in one line and stop applying the rules.
- **The echo line is the liveness signal.** It is mandatory on every turn precisely so the user
  can see the skill is still in force. If you notice you have skipped it, resume — a missing echo
  reads to the user as "the skill drifted out" and prompts a needless re-invocation.

## Three states

Sort every questionable span into exactly one. There is no inline tagging here — an executed
command has no surface to annotate — so the four states used for archival transcripts collapse to
three: fix it, ask about it, or leave it alone.

| State | Condition | Action |
|---|---|---|
| **Auto-fix** | A basis exists: a filler class from `references/korean-filler.md`, plain orthography, a single repo candidate, a single installed-skill candidate, an entry in the speech profile, or the speaker's own self-correction inside the utterance | Fix silently; surface it as one item in the echo |
| **Ask** | Zero candidates or several; two readings imply different actions; the span names the target of an irreversible action | One batched question round |
| **Leave alone** | Numbers, dates, versions, PR/issue numbers, amounts, literal paths, quoted strings | Pass through unchanged |

**"Leave alone" is the safety property, not a gap.** `PR 189` misheard as `PR 180` sends work at
the wrong PR, and no amount of surrounding context licenses a guess about a number. Context
*flags* a candidate; it never authorizes rewriting one.

A correction restores what was said. It does not improve it — do not tighten the user's phrasing,
add qualifiers they did not speak, or widen a request because a bigger version seems more useful.

## Process

### Step 1 — strip what carries no instruction

Apply `references/korean-filler.md`. Two rules dominate:

- **Function-residue test before deleting anything.** If removing the word changes what you would
  do, it is not a filler. "그냥 지워" means "delete it and nothing else"; "일단 커밋해" orders a
  sequence. When unsure, keep it.
- **A self-correction marker is a basis, not a filler.** "아 아니", "그거 말고", "다시" mean the
  utterance after them wins: `foo.py 고쳐, 아 아니 bar.py` normalizes to `bar.py 고쳐`.

Fix orthography and obvious code-switching in the same pass (`references/stt-error-classes.md`).
Preserve sentence structure, word order, and the user's own way of expressing intent — including
hedges, which carry confidence information ("~것 같은데" is not noise).

### Step 2 — resolve identifiers against the repo, do not guess

For every span that looks like a file, directory, function, branch, or skill name, get a
candidate list before using it.

**Bind the spoken stem to a variable. Never paste it into the command text.** A transcript can
contain a quote, a backtick, `$(…)`, or a newline, and interpolating it inline lets that escape
into shell syntax — `grep -F` only ever sees what the shell has already parsed, so it is no
defense against injection.

```bash
STEM='<the spoken stem, single-quoted>'

# Get the list first, so a git failure cannot hide behind grep's "no match".
files=$(git ls-files -co --exclude-standard) || {
  echo "voice-prompt: git ls-files failed — a tool error, not zero candidates" >&2; exit 1; }
candidates=$(printf '%s\n' "$files" | grep -iF -- "$STEM"); rc=$?
[ "$rc" -le 1 ] || { echo "voice-prompt: grep failed (status $rc)" >&2; exit 1; }

# Branches — same split.
brs=$(git branch -a --format='%(refname:short)') || {
  echo "voice-prompt: git branch failed" >&2; exit 1; }
brmatch=$(printf '%s\n' "$brs" | grep -iF -- "$STEM"); rc=$?
[ "$rc" -le 1 ] || { echo "voice-prompt: grep failed (status $rc)" >&2; exit 1; }
```

`grep -iF` matches the stem as a literal string, so a syllable that happens to be a regex
metacharacter cannot alter the *search*. Two exit-status rules matter as much:

- **Only `grep` status 1 means zero candidates.** Status 2 or higher is a grep error, and an
  error is not an empty result — surface it instead of asking the user about a search that never
  ran.
- **Never read the list and the filter through one pipeline status.** If `git` fails, `grep` sees
  empty input and exits 1, which looks exactly like "no such file" — so a broken index would send
  the user a question about a filename instead of reporting the failure.

- **Exactly one candidate** → auto-fix, and name it in the echo.
- **Zero or several** → ask. Offer the near-misses you found as options; a list of real paths is
  easier to answer than an open question.
- **Function and symbol names** → prefer the session's symbol tooling (LSP or Serena) over a text
  search, then fall back to `grep`.
- **Skill and command names** → resolve against the installed-skill listing already in your
  context, not the filesystem. Long English plugin names spoken in Korean are the single most
  frequent break: "슬래시 씨알픽스" is `/github-dev:cr-fix`. Same rule — one candidate resolves,
  several ask.

### Step 3 — ask once, batched

Collect everything still unresolved and ask in **one** round through the interactive-input gate.
Latency is the whole reason voice mode exists; a chain of single questions defeats it.

Each option should be a concrete candidate ("`src/loader.py`" / "`tests/loader_test.py`"), not a
restatement of the ambiguity. If a question is not worth a round trip, it belongs in "leave
alone" — pass the span through untouched and say so in the echo.

### Step 4 — echo one line, then act

```
→ <normalized request>  (<changed item>, <changed item>)
```

Keep the parenthetical to what actually changed, shortest form: `로더 파일→loader.py`,
`필러 3어 삭제`. Nothing changed means no parenthetical. Never pad it with what you considered
and rejected.

Then proceed immediately. No approval round trip — **with one exception**:

**Irreversible or outward-facing actions get an explicit confirmation, not an echo.** Push, merge,
force-push, reset, branch or file deletion, publishing, sending, anything that leaves the machine.
Name the action and its resolved target together, then wait:

```
push → origin/feat/192-voice-prompt-plugin, 맞습니까?
```

This is the only place the immediate-execution rule yields. Misrecognition risk and
irreversibility overlap here, which is exactly the intersection worth one round trip.

### Step 5 — propose profile additions, never write them unasked

When the same misrecognition recurs, reuse the resolution for the rest of the session from memory.
Persist it only after the user confirms.

**Order matters: confirmation comes first, then any write.** Seeding is not a separate permission —
it happens only as the first step of a persist the user has already approved, so nothing is ever
created just because the skill ran. Never seed eagerly at activation.

The bundled template path must be resolved, not assumed: Codex 0.135 does not export
`CLAUDE_PLUGIN_ROOT`, so a literal `<skill dir>` or a bare `${CLAUDE_PLUGIN_ROOT}` fails at step
one outside the source tree.

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && [ -d plugins/voice-prompt/skills ] && PLUGIN_ROOT=plugins/voice-prompt
if [ -z "$PLUGIN_ROOT" ]; then
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  PLUGIN_ROOT=$(ls -1d "$cache_root"/*/voice-prompt/* 2>/dev/null | sort | tail -1)
fi
TEMPLATE="$PLUGIN_ROOT/skills/voice-prompt/templates/speech-profile.md"
[ -f "$TEMPLATE" ] || { echo "voice-prompt: bundled template not found" >&2; exit 1; }

# Runs only after the user confirmed the entry being persisted.
PROFILE=.claude/voice-prompt/speech-profile.md
[ -f "$PROFILE" ] || { mkdir -p .claude/voice-prompt && cp "$TEMPLATE" "$PROFILE"; }
```

The profile lives under `.claude/` — a stable per-project config path — because a plugin-cache
copy is wiped on cache refresh and cannot hold a project's terms. Never add a person's name, a
client or company name, or an amount without separate verification; those default to a question.

## Prohibitions

- Never rewrite a number, date, version, PR/issue number, or amount from context.
- Never invent an identifier. If the repo has no candidate, ask.
- Never widen, tighten, or "improve" the request. Restore the utterance; do not edit the intent.
- Never skip the echo. It is the user's only view into what you changed.
- Never execute an irreversible action off a spoken instruction without the Step 4 confirmation.
- Never write to the speech profile without explicit confirmation.
- Never reconstruct a dropped or garbled clause by guessing what would fit. Ask.

## Verification before acting

- [ ] Every deleted word passed the function-residue test?
- [ ] Every identifier either resolved to a single real candidate or asked about?
- [ ] Numbers, dates, and PR/issue numbers passed through untouched?
- [ ] Open questions batched into one round, with concrete candidates as options?
- [ ] Echo line present, listing only what actually changed?
- [ ] Irreversible action confirmed with its resolved target named?

## Reference files

- `references/stt-error-classes.md` — which error classes to expect and the correction stance for each.
- `references/korean-filler.md` — filler classes, the function-residue test, and what never to delete.
- `templates/speech-profile.md` — empty template for the per-project profile.
