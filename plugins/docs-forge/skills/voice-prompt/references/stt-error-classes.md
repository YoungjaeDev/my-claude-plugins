# STT error classes and the correction stance for each

What Korean speech-to-text reliably gets wrong, and what to do about each class when the
transcript is a **live command** rather than a record.

The class list is a property of Korean STT, not of any one product, so it matches the taxonomy the
sibling `plaud-note-taking` skill uses on meeting transcripts. The *stance* column does not match,
and that is the whole reason these are two files. There, the transcript is evidence and an
unfixable span is annotated in place and left for a human. Here, the transcript is about to be
executed, so every span must end in one of three terminal states — fixed, asked about, or passed
through untouched.

## The classes

| Error class | What to expect | Stance here |
|---|---|---|
| **Code-switched identifiers** (KO pronunciation of an EN name) | The dominant failure. A single-language model approximates the embedded English into Korean syllables: `loader` → "로더", `cr-fix` → "씨알픽스", `commit` → "커밋" (already loaned) or "코멋" (not). | **Resolve against the repo or the installed-skill list.** One candidate fixes it; zero or several is a question. Never settle it from plausibility. |
| **English loanwords** | Mangled or half-transliterated, and the correct target is often a real English word rather than the loaned Korean one. | Fix only when it changes **spelling, not which thing is meant** — that is the orthography case below. If the correct target is a *different word*, context alone is not a basis: look it up or ask. Identifiers always belong to the row above. |
| **Orthography (맞춤법)** | Spacing and 받침 errors, worse on fast or noisy speech. Rarely changes meaning. | Fix silently. Low value, low risk. |
| **Homophone substitution** | Korean is dense with homophones; the model picks the frequent one, which is often wrong in a technical sentence. | Fix only when every reading but one is **impossible** — elimination, not a likelihood judgement. If two readings survive, ask; if they imply different actions, ask even when one feels far more likely. |
| **Numbers, dates, versions, amounts** | Reliably mangled, and the mangled form is indistinguishable from a correct one. | **Never rewrite.** Pass through. This is the safety property, not a limitation. |
| **Dropped or merged clauses** | Fragments vanish; two sentences fuse when the speaker does not pause. | Do not reconstruct. A plausible completion is an invented instruction. Ask. |
| **Self-correction mid-utterance** | "아 아니", "그거 말고", "다시" followed by the intended form. Frequent in speech, since the speaker cannot backspace. | Not an error to fix — a **basis**. The form after the marker wins. |
| **Sentence boundaries and punctuation** | Auto-segmentation is imperfect; a command can absorb the next thought. | Re-segment only when every candidate split implies the **same action, target, and ordering**. When they differ behaviorally, ask before executing — the echo reports a reading after the fact and cannot undo a wrong one. |

## Why "never rewrite a number" is absolute

Every other class has a recoverable failure mode: a wrong filler deletion loses a nuance, a wrong
orthography fix is cosmetic, a wrong identifier guess fails loudly when the path does not exist.

A misheard number fails **silently and plausibly**. `PR 189` heard as `PR 180` names a real PR, so
nothing errors — the work simply lands in the wrong place. There is no lookup that distinguishes
"the number I heard" from "the number that was said", which is why context is not admissible here
even when it feels overwhelming.

The same reasoning covers versions (`0.1.0` vs `0.10`), amounts, and dates.

## Evidence hierarchy for a correction

In descending order. A correction needs one of these; "it probably means X" is not one of them.

1. **The repo itself** — a single candidate from `git ls-files`, the branch list, or symbol tooling.
2. **The installed-skill listing** — for skill and command names, resolved from session context.
3. **The speech profile** — `.claude/voice-prompt/speech-profile.md`, entries the user confirmed.
4. **In-utterance self-correction** — the speaker's own restatement.
5. **Unambiguous orthography** — a misspelling with exactly one valid target, where the fix changes
   spelling and not which thing is meant.

Anything else is a question. Context is a signal that flags a candidate for lookup; it is never
standalone authorization to rewrite.
