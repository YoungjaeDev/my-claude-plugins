---
paths:
  - "deck/**"
---

# 덱 디자인 규칙 (monitor)

> 원본은 `deck` 플러그인의 `templates/decks/monitor/rules/deck-design.md`다. 이 사본을 직접 고치지 말고 원본을 고친 뒤 `deck-sync`로 다시 받는다.

이 덱의 템플릿(`monitor`)이 정하는 브랜드·글꼴·푸터·그림 에셋이다. 템플릿과 상관없는 제작 규칙은 `deck-authoring.md`에 있다.

- RALPHDEV 브랜드를 쓴다. 글꼴은 직접 호스팅한 IBM Plex Sans KR Regular 400·SemiBold 600만 쓰고 합성 굵기를 만들지 않는다.
- 제목 굵기는 셸 `:root`의 `--title-weight`(기본 600)다. 더 가벼운 제목이 필요한 덱은 `shell.html`에서 400으로 바꾼다.
- 표지 바탕이 비어 보이면 `section.slide.cover.backdrop`(은은한 그라디언트 + 옅어지는 격자)을 쓴다. 네온·글로우·보라 그라디언트처럼 장식이 앞서는 효과는 쓰지 않는다.
- 셸 푸터가 RALPHDEV 워드마크와 Ralph 캐릭터를 넣는다. Ralph 캐릭터를 다른 마스코트로 바꾸지 않는다.
- 마스코트와 픽셀 컷은 아껴 쓴다. 놓을 자리와 개수는 `deck-assets` 스킬이 정한다.
