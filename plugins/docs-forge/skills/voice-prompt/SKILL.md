---
name: voice-prompt
description: "Normalize Korean voice-mode STT input before acting on it: strip speech fillers, fix orthography and Korean-to-English code-switching, resolve garbled identifiers (file, function, branch, skill names) against the actual repo instead of guessing, and never rewrite numbers or dates. Echoes one line of what it understood and proceeds, asking once in a single batched round only where two readings imply different actions. Stays active until released. Use ONLY when the user explicitly invokes /docs-forge:voice-prompt or asks to turn on voice-input normalization — do NOT auto-fire from an incidental mention of voice mode or dictation. Triggers — 보이스 모드 정리, 음성 입력 정규화, STT 정규화, 말버릇 제거, 받아쓰기 교정, voice input cleanup, normalize dictation."
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

Plugin skills are explicit opt-in loads in Hermes — the description never surfaces this body on
its own. **Load it as `skill_view("docs-forge:voice-prompt")`.** `docs-forge` is in
`HERMES_ELIGIBLE`, so its generated adapter registers every skill under the qualified
`<plugin>:<skill>` form. The bare name resolves only through the skill-unit install
(`node scripts/install-skills.mjs`, which wraps `npx skills`), which registers the frontmatter
`name` verbatim — a separate path from the plugin adapter.

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

Invoked as **`/docs-forge:voice-prompt`** under Claude Code — a plugin skill is registered under
its plugin namespace, so that qualified form is the identifier to document and to type. (Under
Hermes the skill-unit install registers the bare `voice-prompt` instead; see the compatibility note
above. Different runtimes, not a contradiction.)

Active from explicit invocation until released. Applies to every subsequent input in the session,
typed or spoken — no auto-detection, no sniffing for "does this look like STT".

- **Read the live speech profile once, at activation.** `.claude/voice-prompt/speech-profile.md`
  is an ordinary project file; nothing places it in context automatically, so an entry the user
  confirmed in an earlier session is invisible until you open it. Read it (with the file-reading
  tool, not a shell `cat`) if it exists — an absent file is the normal first-run state, not an
  error. **Skip this and the profile is write-only:** the "an entry in the speech profile" basis in
  the table below can never fire, and the same misrecognition gets re-asked every session.
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

**Transliterate first, then search.** The spoken form is Korean and the repo is English, so
searching for the transcript verbatim finds nothing: "로더" appears in no path, and grepping it
returns zero candidates even when `loader.py` is sitting right there. Write down the English stems
the Korean pronunciation could be, *then* look each one up. This conversion is the step that does
the actual work — skip it and the whole feature silently no-ops.

| Spoken | English stem candidates |
|---|---|
| 로더 | `loader` |
| 씨알픽스 | `cr-fix`, `crfix` |
| 이식성 (a translated word, not a transliteration) | `portability` |
| 커밋 | `commit` |

**Hand the stems to `grep` as data, never as shell source.** Writing them into a quoted heredoc
and reading them with `grep -f` is the only form with a mechanical guarantee: nothing inside
`<<'STEMS'` is parsed by the shell, so a quote, backtick, `$(…)`, or newline that survived into a
stem is inert. Substituting a stem into the command text — or into a `set --` line — does **not**
have that property, because both are parsed as source before `grep` ever runs, and `grep -F` only
sees what the shell already handed it.

```bash
stems=$(mktemp) || { echo "voice-prompt: mktemp failed" >&2; exit 1; }
cat > "$stems" <<'STEMS'
loader
STEMS

# Fetch the list, then filter — separate statuses, so a git failure cannot hide
# behind grep's "no match". `grep -f` unions every stem in one pass, so there is
# also no loop piping into `sort` whose exit status would replace the real one.
files=$(git ls-files -co --exclude-standard) || {
  rm -f "$stems"
  echo "voice-prompt: git ls-files failed — a tool error, not zero candidates" >&2; exit 1; }
candidates=$(printf '%s\n' "$files" | grep -iF -f "$stems"); rc=$?
[ "$rc" -le 1 ] || { rm -f "$stems"; echo "voice-prompt: grep failed (status $rc)" >&2; exit 1; }

# Branches — same stem file.
brs=$(git branch -a --format='%(refname:short)') || {
  rm -f "$stems"; echo "voice-prompt: git branch failed" >&2; exit 1; }
brmatch=$(printf '%s\n' "$brs" | grep -iF -f "$stems"); rc=$?
[ "$rc" -le 1 ] || { rm -f "$stems"; echo "voice-prompt: grep failed (status $rc)" >&2; exit 1; }
rm -f "$stems"
```

`-F` matches each stem literally, so a syllable that happens to be a regex metacharacter cannot
alter the *search* either. Two exit-status rules carry the rest:

- **Only `grep` status 1 means zero candidates**, and that is a question, not an error. Status 2 or
  higher is a grep failure — surface it instead of asking the user about a search that never ran.
- **Never let a pipeline decide whether the lookup failed.** A `git`-into-`grep` pipeline reports a
  `git` failure as grep's exit 1, which reads as "no such file"; a candidate loop piping into
  `sort` has its failure exit replaced by sort's success. `grep -f` avoids both by needing neither.
  (`set -o pipefail` is not the fix: it flips the second case the other way, reporting a plain
  no-match as failure.)

- **Exactly one candidate** → auto-fix, and name it in the echo.
- **Zero** → first suspect your own transliteration, not the user. Try the other spellings the
  pronunciation allows (hyphenated / concatenated, transliteration vs. translation) before asking.
  Only when every stem comes back empty is it a question.
- **Several** → ask. Offer the near-misses you found as options; a list of real paths is easier to
  answer than an open question.
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

```text
→ <normalized request>  (<changed item>, <changed item>)
```

Keep the parenthetical to what actually changed, shortest form: `로더 파일→loader.py`,
`필러 3어 삭제`. Nothing changed means no parenthetical. Never pad it with what you considered
and rejected.

Then proceed immediately. No approval round trip — **with one exception**:

**Irreversible or outward-facing actions get an explicit confirmation, not an echo.** Push, merge,
force-push, reset, branch or file deletion, publishing, sending, anything that leaves the machine.
Name the action and its resolved target together, then wait:

```text
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

**Test each candidate for the template, rather than picking a root and then testing.** Choosing
one root first means a half-extracted cache directory aborts the whole step instead of falling
through to a good older version.

```bash
cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
hermes_root="${HERMES_HOME:-$HOME/.hermes}"
cl=$(mktemp) || { echo "voice-prompt: mktemp failed" >&2; exit 1; }

# Candidate roots, most specific first. A wrong guess costs nothing — each entry
# still has to hold the template to win.
{
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then printf '%s\n' "$CLAUDE_PLUGIN_ROOT"; fi
  printf '%s\n' plugins/docs-forge
  # Codex cache, newest version FIRST. Sort on the version basename, never the
  # full path: lexicographic path order ranks zeta/…/0.1.0 above alpha/…/0.2.0,
  # and 0.9.0 above 0.10.0. sort -V orders X.Y.Z; BSD/macOS sort has no -V, so
  # degrade to a reverse numeric dotted-field sort.
  if sort -V </dev/null >/dev/null 2>&1; then
    ls -1d "$cache_root"/*/docs-forge/* 2>/dev/null \
      | awk -F/ '{print $NF "\t" $0}' | sort -Vr | cut -f2-
  else
    ls -1d "$cache_root"/*/docs-forge/* 2>/dev/null \
      | awk -F/ '{print $NF "\t" $0}' | sort -t. -k1,1nr -k2,2nr -k3,3nr | cut -f2-
  fi
  # Hermes: docs-forge is in HERMES_ELIGIBLE, so a plugin adapter exists; the
  # flat path stays as the separate skill-unit install route.
  printf '%s\n' "$hermes_root/plugins/docs-forge" "$hermes_root/skills/voice-prompt"
  # Project-scope skill-unit install. `npx skills` owns this layout, so these are
  # candidate paths, not a verified contract — harmless, since the -f test decides.
  printf '%s\n' .agents/skills/voice-prompt .claude/skills/voice-prompt
} > "$cl"

TEMPLATE=""
while IFS= read -r root; do
  [ -n "$root" ] || continue
  # Two layouts: bundled plugin tree, and the flat skill-unit install.
  for t in "$root/skills/voice-prompt/templates/speech-profile.md" \
           "$root/templates/speech-profile.md"; do
    if [ -f "$t" ]; then TEMPLATE="$t"; break; fi
  done
  if [ -n "$TEMPLATE" ]; then break; fi
done < "$cl"
rm -f "$cl"
[ -n "$TEMPLATE" ] || { echo "voice-prompt: bundled template not found" >&2; exit 1; }

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
