# What a PLAUD note is

PLAUD (PLAUD.AI) makes small AI voice recorders (Plaud Note / Note Pro / NotePin). The device
only records; all processing happens in the PLAUD app/web ("PLAUD Intelligence"). Every
recording becomes a **note** made of two independently generated artifacts plus extras
(mind map, etc.). For correction, only the first two matter.

## The two-stage pipeline (the fact that drives everything)

1. **Transcript — raw STT.** Produced by **OpenAI Whisper (v3-large) + Azure ASR** (PLAUD also
   runs its own trained ASR on newer paths). Speaker-labeled, paragraph-broken, timestamps
   optional (off by default). This is the verbatim "what was said."
2. **Summary / note — a separate LLM pass.** A user-chosen model (GPT / Claude / Gemini)
   re-writes the transcript into a template (meeting recap, action items, etc.). Generated and
   stored **separately** from the transcript; can be regenerated without re-transcribing.

**Correct the transcript, never the summary.** The summary reads perfectly fluently even when
it fabricates — e.g. "the team agreed to launch Friday" when the transcript only shows a
proposal. It can also silently *fix* a transcript error, so the two diverge in both directions.
The transcript (and, ideally, the audio) is the ground truth. Treat any summary claim the
transcript does not support as a flag, not a fact.

## Speaker labels are estimates

Auto speaker labeling assigns `Speaker 1 / Speaker 2 …` and is renamable in-app, but it
**over-splits one person into two and merges two people into one on overlapping/cross-talk
audio**. So:

- Speaker **count is not the attendee count.**
- Never bind a `Speaker N` to a real name from voice pattern or tone alone.
- Real names come only from independent evidence (calendar invite, email, an explicit
  self-introduction in the transcript).
- If speaker attribution affects who owns a decision or task, and it is not independently
  confirmed, it is an open question — even when the sentence itself is clear.

## STT error classes to expect (esp. Korean business audio)

PLAUD transcribes **one language per recording** — no bilingual mode, no translation — and is
tuned to standard pronunciation (**dialects / 사투리 are officially unsupported**). Accuracy is
condition-dependent (~90% clean Korean, down to ~60% in a noisy real meeting), not a fixed
number. When audio is unclear the model **fills gaps with plausible guesses**, so small errors
stack until meaning shifts. Prioritize these correction targets:

| Error class | What to expect | Correction stance |
|---|---|---|
| **Code-switched tech terms** (KO + EN) | The #1 error zone — embedded English is approximated by the single-language model. | Fix from `terminology.md` / context; the biggest win. |
| **Proper nouns** (company / product / person) | Pronunciation-dependent misrecognition. | Fix only from the dictionary or a cited source; else open question. |
| **English loanwords** | Mangled or half-transliterated. | Fix from context + dictionary. |
| **Dropped / merged sentences** | Fragments omitted; sentences fused on overlap. | Mark `[확인 필요]`; do not invent the missing content. |
| **Orthography (맞춤법)** | Severe on noisy audio. | Fix spelling without changing meaning. |
| **Numbers / dates / prices / terms** | STT reliably mangles these; no safe auto-fix. | **Never guess** — flag `[확인 필요]`. |
| **Sentence boundaries / punctuation** | Auto-segmentation imperfect, worse on overlap. | Re-segment only where meaning is unambiguous. |

PLAUD's own mitigation is a **Custom Vocabulary + industry glossary** — this skill mirrors that
as `terminology.md`, the single basis for a terminology correction.

## Export shape (why a `.txt` post-processor fits)

Transcript exports as plain **TXT / SRT / DOCX / PDF** (summary as TXT / Markdown / DOCX / PDF).
So the input to this skill is naturally the exported `.transcript.txt` (+ optional summary
`.note.txt`) placed in `.llmwiki/raw/transcripts/`.

---

Sources (verified 2026-07-22; vendor numbers marked where relevant): PLAUD device/AI-model FAQ
`plaud.ai/pages/plaud-devices`, User Guide PDF, support articles on languages / bilingual /
translation / export, accuracy trade-off blog (WER 23.4%), and KO reviews (IT조선, monopick.kr,
plaud.kr 사용후기). Numbers/dates and homophone cases are a general-STT expectation, not a
PLAUD-documented example — hence the "always flag, never guess" stance.
