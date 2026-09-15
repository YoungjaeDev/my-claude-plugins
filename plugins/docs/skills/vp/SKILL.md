---
name: vp
description: "Voice-prompt gate for a request dictated through speech-to-text: fix misheard terms against the project's .agents/voice-terms.md, restate the intent in one line and proceed when it is clear, or ask 2-3 targeted questions when it is ambiguous, inaccurate, or self-contradictory. Use when /docs:vp appears anywhere in the prompt (start, middle, or end), '음성 전사', '음성 프롬프트', '받아쓰기 프롬프트', 'voice prompt', 'dictated prompt'. For a full requirements interview or a grill-me stress test use docs:interview-methodology."
---

# vp

A dictated prompt arrives as one run-on stream: misheard terms, no structure, and later sentences
that revise earlier ones. Interpret the stream before acting on it. The `/docs:vp` marker can sit
anywhere in the prompt; drop it and treat the rest as the request.

## Procedure

1. **Load the dictionary.** Read `.agents/voice-terms.md` at the repository root when it exists and
   apply every row. The folder is vendor-neutral so Claude Code and Codex share one file.
2. **Normalize.** Fix other misheard terms only where the conversation or the repository (skill
   names, paths, identifiers) makes the intended word certain. When the speaker corrects
   themselves mid-stream, the later statement wins.
3. **Classify.** A point is ambiguous when it changes the work and has two or more reasonable
   readings: an uncertain term, a missing target, or two statements that conflict. A fact the
   repository can answer is not ambiguous; look it up instead of asking.
4. **Act.**
   - Clear: print `이해한 내용: <one-line restatement>` and the corrected terms
     (`메탈로지 → methodology`), then do the work.
   - Ambiguous: ask the 2-3 decisions that most change the work in one interactive-input gate
     (Claude `AskUserQuestion`; Codex `request_user_input` when exposed, otherwise one short
     blocking question). Each question states the current reading and marks a recommended option.
     Proceed once answered.
5. **Propose dictionary rows.** At the end of the response, list the term corrections from steps 2
   and 4 that are likely to recur:

   ```text
   사전 추가 후보 (.agents/voice-terms.md):
   | 인터뷰 메탈로지 | interview-methodology |
   ```

   Write rows only after the user approves. On the first write, create the file with this header:

   ```markdown
   # Voice terms

   | Heard | Meant |
   |---|---|
   ```

## Done when

The response shows either the one-line restatement or answered questions before any work, and ends
with dictionary candidates or none. No row enters `.agents/voice-terms.md` without approval.
