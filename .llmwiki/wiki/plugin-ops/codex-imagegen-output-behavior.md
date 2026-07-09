---
id: codex-imagegen-output-behavior
aliases: [codex-image-behavior, codex-korean-lettering, codex-palette-crush, codex-role-color, gpt-image-output]
last_verified: 2026-07-09
status: active
volatility: volatile
sources: 1
---

# codex-image(gpt-image) 출력 behavior quirk

`codex-image`가 `codex exec`로 뽑는 gpt-image 출력의 **prompt-craft 실측** 3종. 브리지 *호출* 계약(모델·샌드박스·`-i` 플래그·injection 방어)은 별개 페이지 소관이고, 이건 같은 플러그인의 *출력* 축이다.

> See-also: [[codex-image-bridge-design]]

## 짧은 한글 레터링은 신뢰 가능 — 폴백 근거는 "오타"가 아니다

짧은 라벨·말풍선 수준의 한글은 **자소분리·오타 0으로 정상 렌더**된다(직접 재생성으로 확인 — "codex 한글 불안정" 가정이 실측에서 뒤집힘). 따라서 SVG 레터링 폴백의 진짜 근거는 "오타 위험"이 아니라 **수정 가능성·폰트 통일·키메시지 규약**이다. 폴백 트리거는 장문/자주 바뀌는 문구/정확 수치/명령어/대괄호 키메시지/덱 전체 폰트 통일이 필요할 때로 좁힌다 — 이 조건이 아니면 codex 레터링을 그대로 쓴다.

## "flat, no gradient" 과잉 강조는 팔레트를 뭉갠다

프롬프트에서 "flat, no gradient"를 강하게 밀면 codex가 팔레트를 과처리해 **엣지가 깨지고 색이 뭉개진 저품질 출력**이 나온다(실측 시 23KB 깨진 이미지). 완화 표현은 **"flat vector with soft subtle shading"** — 미니멀/그라데이션-텍스트 금지(출력 규약)와는 다른 레이어의 *프롬프트 문구* 교훈이다. 출력물의 그라데이션을 금지하되, 프롬프트로 그걸 지나치게 못박지는 않는다.

## 역할색은 명시하지 않으면 의미색으로 폴백한다

역할색(subject의 브랜드/의미 색)을 프롬프트에 안 박으면 codex가 **대상의 통념적 의미색으로 폴백**한다(예: 배터리 → 초록/빨강 신호등색). 덱의 역할·면적 팔레트를 지키려면 프롬프트에 역할색을 **명시**해야 한다.

## Sources

- PR #103 (merged `6d7750d`) — ppt-yeong-style 0.9.0 스토리 개념 일러스트 규약. 실측 근거는 스킬 본문 `plugins/ppt-yeong-style/skills/ppt-yeong-style/references/images-and-pop.md`(§5 실측 9a/9b·레터링 경계) + `references/color-typography.md`(codex tone·레터링 폰트 축). 실험 이미지는 별 repo `cc-lesson-deck/assets/generated/codex-image/story-battery-*`(3패널/코믹/단일씬 + 레터링 2종).
