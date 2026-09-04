# Correction policy — states, open questions, discrepancies

Conservative discipline for turning a PLAUD transcript into a corrected note. The transcript
is the primary source; the summary and any project docs are secondary. Never let a plausible
guess pass as a confirmed fact.

## Source roles

| Source | Role | Standalone rule |
|---|---|---|
| PLAUD transcript | Primary record of what was said | Can carry misrecognition + speaker split/merge errors. Do not infer owner / deadline / attendee count from it alone. |
| PLAUD summary / note | Fast-navigation aid only | Never a source of confirmed decisions, owners, or deadlines. Can fabricate — see "Summary vs transcript". |
| Verified project docs / calendar / email | External verification | Must be cited when used. |
| `terminology.md` | Terminology-correction basis | A name not in the list is not corrected from memory. |

## The four states

Tag every non-trivial span inline in the corrected file.

### `[확인됨]` (confirmed)
All of: appears directly in the transcript (or a verified external source); no material
conflict across transcript / summary / external basis; owner / deadline / decision not filled
by inference.

### `[정정]` (corrected)
One of these bases only: a standard term from `terminology.md`; a trusted external source for a
date / number / proper noun; a speaker's own immediate self-correction inside the transcript.
Record `original → corrected → basis`. A correction restores meaning; it never changes it.

### `[해석]` (interpretation)
Context useful for reading the meeting but not stated verbatim. Always tag it. Never promote it
to a decision, action item, or commitment.

### `[확인 필요]` (needs confirmation → open question)
Make an open question when any of: transcript and summary disagree; speaker / owner / project
name is unclear; a baseline-less phrase ("next week", "our side", "곧") appears; an action is
mentioned with no owner or deadline; a number / date / price / term is ambiguous or
STT-suspect; a source conflicts with a project doc and recency is unknown.

## Speaker attribution

PLAUD `Speaker N` labels are voice-segment estimates (over-split / merge on cross-talk). Do not
use speaker count as attendee count, and do not bind a label to a real name without independent
evidence. If attribution affects who owns a decision or task, keep the attribution
`[확인 필요]` even when the sentence is clear.

## Summary vs transcript

The summary can assert a decision the transcript never supports (and can also silently fix a
transcript error). For every summary claim of a decision / owner / deadline, verify it against
the transcript. If the transcript shows only a proposal, request, or discussion, it is **not** a
confirmed decision — record it as a proposal and, if it matters, raise an open question. Collect
these mismatches in the corrected file's "summary vs transcript" section.

## Open-question format

A good question is directly answerable — one fact each.

```text
[OQ-01] <the precise question>
왜 확인이 필요한가: <what is ambiguous / conflicting / STT-suspect in the source>
답변 대상: <name if known, else 답변 대상 미정>
```

Resolve open questions by interviewing the user relentlessly (grill-me). Fold confirmed answers
back in as `[확인됨]` / `[정정]`; leave anything the user defers as `[확인 필요]`.

## Sensitive information

Keep only what the corrected note needs. Do not copy phone numbers, email addresses,
credentials, or unnecessary personal circumstances into the corrected file.
