# Corrected-note template

Write `derived/<slug>.corrected.md` in the `derived/` subfolder beside the frozen originals. Drop
any section that has no content. Keep it readable: one fact per line, no tables of raw transcript.

Personal data (phone numbers, emails, credentials) is **masked in place** as `[삭제됨: 유형]`, not
deleted. This file is the full transcript with tagging, so a silent deletion is an untagged edit;
the marker preserves speaker attribution, utterance order, and the positions the `[정정]` citations
point at.

This is the fidelity artifact, not the readable record. The readable record is
`derived/<slug>.digest.md` (`templates/digest.md`), distilled from this file after the user
approves it.

```md
---
derived_from: {slug}.transcript.txt
ingested: {YYYY-MM-DD}
---

# {회의/녹음 제목} (corrected)
자료: {slug}.transcript.txt · PLAUD (Whisper STT)  {요약 .note.txt 가 있을 때만 " (+ {slug}.note.txt) · LLM 요약" 을 덧붙인다}
정정 기준: 전사록 근거, terminology.md · 정정일 {YYYY-MM-DD}

## 요약 (확인된 내용만)
{전사록이 실제로 뒷받침하는 2~3문장. 요약 파일의 미검증 주장은 넣지 않는다.}

## 정정한 전사
{화자 라벨을 보존한 정정 본문. 바뀐 곳은 인라인 태깅:}
{  [정정] "원문" → "정정" (근거)}
{  [확인 필요] STT 의심 구간 또는 모호한 부분}
{  Speaker N 은 추정값으로 유지 — 실명·담당자로 확정하지 않음}

## 정정한 표현
- "{PLAUD 원문}" → "{정정}"   ({근거: terminology.md / 자기수정 / 인용})

## 확인 필요 (grill 후에도 미해결)
[OQ-01] {질문}
왜 확인이 필요한가: {무엇이 모호/충돌/STT 의심인지}
답변 대상: {이름 또는 답변 대상 미정}

## 요약 vs 전사록 불일치
- {요약이 결정으로 적었으나 전사록엔 제안/논의만 있는 항목 → 확정 결정 아님}
```

## Ordering

0. `derived_from:` / `ingested:` frontmatter, with **no `sha256:` field** (that absence is what
   lets `wiki:lint-wiki` leave a hand-edited derivative alone instead of reporting `DRIFT`)
1. 회의 식별 + 정정 기준
2. 확인된 요약
3. 정정한 전사 (인라인 태깅)
4. 정정 표현 목록
5. 확인 필요 (open questions)
6. 요약 vs 전사록 불일치

Put open questions and the summary-vs-transcript flags where they are easy to find — these are
what the reader must act on.
