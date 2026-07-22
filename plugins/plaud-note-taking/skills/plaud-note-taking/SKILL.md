---
name: plaud-note-taking
description: "Use to review and correct a PLAUD voice-recorder note that was dropped into .llmwiki/raw/transcripts/. PLAUD emits two separate artifacts per recording — a raw Whisper STT transcript and a separate LLM summary — and this skill corrects the transcript (never the summary) for STT misrecognition and project terminology, relentlessly interviews the user (grill-me) to resolve anything ambiguous, and writes a *.corrected.md next to the originals without modifying them. Triggers: PLAUD transcript, 플라우드 노트, 전사록 정정, STT 수정, 회의록 교정, plaud note review, correct meeting transcript."
version: 0.1.0
---

# PLAUD Note Review & Correction

## When to use

- A PLAUD note (transcript, or transcript + summary) has been placed in
  `.llmwiki/raw/transcripts/` and needs cleaning before it is usable.
- "이 회의록 정정해줘", "plaud 전사 STT 고쳐줘", "전사록 오탈자·용어 맞춰줘", "correct this PLAUD transcript".

## What a PLAUD note is (read first)

Read `references/plaud-note-format.md` before touching content. Two facts drive everything:

1. **A PLAUD note is two separate artifacts.** The **transcript** is raw single-language
   Whisper STT output (speaker-labeled). The **summary/note** is a *separate* LLM pass over
   that transcript. They are generated and stored independently.
2. **The transcript is ground truth; the summary is not.** The summary reads fluently even
   when it silently invents a decision that was never made. **Correct against the transcript
   and audio, never against the summary.** Where the summary asserts something the transcript
   does not support, that is a flag, not a fact.

## Role and scope

This skill corrects a transcript conservatively and writes a **new** corrected file. It never
edits the uploaded originals. It sorts every span into four states (see
`references/correction-policy.md`), tagged inline in the corrected file:

- `[확인됨]` — present in the transcript and not in conflict with a trusted source.
- `[정정]` — a misrecognition fixable with certain evidence: a `terminology.md` entry, an
  in-transcript self-correction, or a cited trusted source. Keep original → corrected → basis.
- `[해석]` — useful context inferred from flow, not stated verbatim. Never promote to a
  decision, action item, or commitment.
- `[확인 필요]` — ambiguous / conflicting / STT-suspect. Becomes an open question.

## Process

Two ways to ask: for a **single direct question** (which recording to process, confirming
scope) use `AskUserQuestion`. For **resolving a list of open questions**, borrow
`interview:interview-methodology` in grill-me posture (step 4).

1. **Locate input.** Find `<YYYY-MM-DD-slug>.transcript.txt` (and optional `.note.txt`) in
   `.llmwiki/raw/transcripts/`. If more than one recording is present, or the files are
   loosely / oddly named, ask via `AskUserQuestion` which recording to process and confirm the
   `<YYYY-MM-DD-slug>`, then normalize **copies** — never destructively rename or edit an
   original. If only a summary/note exists and there is no transcript, **stop**: you cannot
   correct against a summary. Report the missing transcript.

2. **Understand the note.** Read transcript and summary as separate inputs. Keep PLAUD's
   `Speaker 1 / Speaker 2` labels as **estimates** — PLAUD over-splits one person or merges
   two on cross-talk. Never convert a speaker label into a real name, an attendee count, or
   attribution of a decision without independent evidence.

3. **Correct** (conservative — `references/correction-policy.md` + `references/terminology.md`):
   - STT fixes target the known error zone: Korean+English **code-switched tech terms**,
     **proper nouns** (company / product / person), garbled **English loanwords**, and
     orthography (맞춤법). **Dropped or merged sentences are not reconstructed** — leave them
     `[확인 필요]` unless the boundary re-segments unambiguously (never invent missing content).
   - A correction needs a defensible basis: a `terminology.md` entry, an in-transcript
     self-correction, or a cited trusted source. Context is a signal that *flags* a candidate —
     it is not standalone authorization to rewrite a proper noun or a number. When the only
     basis is "it probably means X", flag `[확인 필요]` instead of correcting.
   - Terminology fixes use **only** verified entries in the **project's** term dictionary at
     `.llmwiki/raw/transcripts/terminology.md`. On first run, seed it by copying the bundled
     `references/terminology.md` template (the bundled file is an empty template, never the live
     dictionary — a plugin-cache copy cannot hold a project's terms). A term not in the
     dictionary is not corrected from memory — it becomes an open question or a proposed
     dictionary addition.
   - **Numbers, dates, prices, contract terms**: never "clean up" by guessing. If STT-suspect
     or unbased, flag `[확인 필요]`.
   - Never change meaning. A correction restores what was said; it does not improve it.

4. **Resolve open questions — grill me.** Collect every `[확인 필요]`: ambiguous owner /
   deadline / number, uncertain speaker attribution that affects a decision, and any place the
   **summary asserts a decision the transcript does not support**. If one or more open
   questions remain, load `interview:interview-methodology` and run it in a **relentless,
   grill-me posture** ("집요하게 캐물어") over the open-question list — one fact per question, do
   not accept a vague answer, keep pressing until each is resolved or the user explicitly
   defers it. Ask it to run a focused close (resolve this list; do not spin up a separate
   spec). If the interview plugin is unavailable, question each open item directly, in the
   same relentless posture. Fold confirmed answers back in as `[확인됨]` / `[정정]`; leave
   anything the user defers as `[확인 필요]`.

5. **Write the corrected file.** Produce `<slug>.corrected.md` in the same folder using
   `templates/corrected-note.md`. **Never silently overwrite an existing corrected file** — the
   user may have hand-edited it; if `<slug>.corrected.md` already exists, write the next free
   `<slug>.corrected-vN.md` (or ask before overwriting). Do not edit the project dictionary
   yourself — if recurring unknown terms look worth adding, list them as candidates at the
   bottom of the corrected file for the user to confirm later. Do not dump raw personal data
   (phone numbers, emails, credentials) into the corrected file.

## Prohibitions

- Never modify, rename, or delete the uploaded `.transcript.txt` / `.note.txt` originals.
- Never treat the summary as a source of confirmed decisions, owners, or deadlines.
- Never correct a name / company / product / number from memory — only from `terminology.md`
  or a cited trusted source.
- Never promote a `[해석]` or a mere request/proposal into a confirmed decision or action item.

## Verification before writing

- [ ] Corrected against the transcript, not the summary?
- [ ] Every `[정정]` has a basis (dictionary entry / in-transcript self-correction / cited source)?
- [ ] No owner / deadline / number invented to fill a gap?
- [ ] Speaker labels left as estimates unless independently confirmed?
- [ ] Open questions grilled to resolution or explicitly deferred?
- [ ] Summary claims the transcript does not support are flagged, not adopted?
- [ ] Originals untouched; output is a new `*.corrected.md`?

## Example (Korean domain)

```md
# 랜딩페이지 논의 (corrected)
자료: 2026-07-22-landing.transcript.txt (+ .note.txt) · PLAUD (Whisper STT + LLM 요약)
정정 기준: 전사록 근거, terminology.md

## 정정한 표현
- "투디제로" → "2dzero"        (terminology.md)
- "리액트" → "React"          (terminology.md — 코드스위칭 기술용어)

## 확인 필요
- [OQ-01] 가격표 수정 담당자는 누구인가요?
  전사록에는 "저희 쪽에서 수정"만 있어 담당자가 특정되지 않음.

## 요약 vs 전사록 불일치
- note.txt는 "금요일 출시 확정"이라 적었으나, 전사록에는 제안 발화만 있고 합의 확인이 없음.
```

## Reference files

- `references/plaud-note-format.md` — what a PLAUD note is; STT error classes; transcript-over-summary rule.
- `references/correction-policy.md` — the four states and when each applies; open-question rules.
- `references/terminology.md` — empty template for the project term dictionary (seeded into `.llmwiki/raw/transcripts/terminology.md`; the only basis for a terminology `[정정]`).
- `templates/corrected-note.md` — the `*.corrected.md` output format.
