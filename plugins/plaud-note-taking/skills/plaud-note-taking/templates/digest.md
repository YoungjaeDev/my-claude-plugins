# Digest template

Write `derived/<slug>.digest.md` beside the corrected file. This is the readable meeting record:
the file a person (or a later agent) opens instead of the transcript. Drop any section with no
content. One fact per line.

The digest **compresses the corrected file and adds nothing**. If a line cannot be traced back to
a span already in `derived/<slug>.corrected.md`, it does not belong here.

```md
---
derived_from: <slug>.corrected.md
ingested: YYYY-MM-DD
---

# {회의 제목}
{YYYY-MM-DD} · 근거: derived/{slug}.corrected.md

## 한 줄
{이 회의가 무엇이었나 - 1문장}

## 결정된 것
- {확정 사항}

## 액션
- {할 일} / {담당자 또는 미정} / {기한 또는 미정}

## 논의만 됨 (미확정)
- {제안·검토 단계에서 멈춘 것}

## 미해결
- {아직 답이 없는 것}
```

## Where each line comes from

| Digest section | Source in the corrected file |
|---|---|
| 결정된 것 | `[확인됨]` only |
| 액션 | `[확인됨]` owner/deadline; unresolved ones stay `미정`, never guessed |
| 논의만 됨 (미확정) | `[해석]`, and any proposal that never reached agreement |
| 미해결 | `[확인 필요]` left open after the grill-me pass |

## Writing rules

- **No upward promotion.** A `[해석]` or `[확인 필요]` span may never appear under "결정된 것".
  That is the one rule the whole pipeline rests on: the corrected file earned its confidence
  levels through cited evidence, and compression must not launder them.
- **No new facts.** Nothing enters the digest that the corrected file does not already carry.
  If a gap is obvious while writing, do not close it here; go back to the corrected file.
- **`미정` is a real answer.** An owner or deadline nobody confirmed stays `미정`. Filling it in
  from context is the same failure the correction policy forbids for numbers and names.
- **No frontmatter `sha256:`.** `llm-wiki:lint-wiki` hashes only files that declare it, so a
  derived file without it can be hand-edited without reporting as `DRIFT`.
- **No sensitive data.** Phone numbers, emails, credentials, and personal details stay out,
  same as the corrected file.
- **Speaker labels stay estimates.** Do not turn `Speaker N` into a name or an owner here; the
  digest inherits, it does not resolve.
