# Korean speech fillers — classes, and the test that decides

A stopword list cannot do this job. Half of these words carry meaning in some positions and none
in others, so the decision has to be made per occurrence. This file gives the **classes** to
recognize and the **test** that resolves each occurrence.

## The function-residue test

> Remove the word. If what you would do changes, it was not a filler.

That is the whole rule. Run it before every deletion, and **keep the word when the answer is
unclear** — a preserved filler costs a slightly longer sentence, while a deleted operator changes
the command.

Worked cases:

| Utterance | Verdict |
|---|---|
| "어쨌든 뭐 그냥 이 파일 고쳐" | All three are fillers. Removing them changes nothing. |
| "**그냥** 지워" | Keep. Means "delete it and nothing else" — removing it drops a scope constraint. |
| "**일단** 커밋해" | Keep. Orders a sequence: commit first, then the rest. |
| "이거 **좀** 고쳐" | Filler (softener). |
| "**좀만** 고쳐" | Keep. Bounds the size of the change. |
| "고쳐야 **될 것 같은데**" | Keep. Carries confidence, and confidence can decide whether to act or confirm. |

## The classes

| Class | Examples | Default |
|---|---|---|
| **담화 표지** (discourse marker) | 어쨌든, 어찌됐든, 하여튼, 아무튼, 그래서 뭐, 그건 그렇고 | Delete |
| **간투사** (hesitation) | 어, 음, 그, 저, 뭐, 이제, 그니까 | Delete |
| **완화 표현** (hedge) | ~것 같은데, ~려나, ~인데, 좀 | **Keep** — carries confidence |
| **즉시 반복 / 재시작** | Same phrase twice; a sentence abandoned and restarted | Keep the final form only |
| **자기수정 표지** (self-correction) | 아 아니, 아니 그거 말고, 다시, 아니아니 | **Never delete** — it is a correction basis |
| **호칭 / 확인 요청** | 클로드, 야, 알겠지, 됐지 | Delete unless it selects a target |

Two rows are not deletions at all:

- **Hedges stay.** "고쳐야 될 것 같은데" is a weaker instruction than "고쳐". Flattening it into an
  imperative manufactures certainty the speaker did not express — the same failure as widening a
  request.
- **Self-correction markers are load-bearing.** They mean the following form wins:
  `foo.py 고쳐, 아 아니 bar.py` → `bar.py 고쳐`. Deleting the marker and keeping both filenames
  produces two targets where the speaker named one.

## Why these are bundled rather than per-user

Everything above is general Korean speech, not one speaker's idiosyncrasy. "어쨌든", "하여튼",
"그냥", "뭐" are in every Korean speaker's mouth, so putting them here — instead of in a personal
profile — is what makes the skill work on first run for anyone.

The per-project `.claude/voice-prompt/speech-profile.md` is for what genuinely does **not**
generalize: one speaker's recurring mispronunciation of a specific term, a personal shorthand, a
project's domain vocabulary that no repo lookup can resolve. If a candidate entry would be true of
Korean speakers in general, it belongs in this file instead, as a change to the plugin.

## What deletion must never do

- Never delete across a clause boundary to make a sentence shorter.
- Never delete a word that names or scopes a target.
- Never delete the second half of a self-correction.
- Never treat a dropped or garbled clause as a filler run and drop it silently — that is a
  question (see `stt-error-classes.md`).
