# 지식은 종류마다 둘 곳이 하나다

결정은 `docs/adr`, 용어는 `GLOSSARY.md`, 같은 실수를 막는 일은 `/retro` 가 만드는 자동 검사와 포인터, 바깥 지식은 `.llmwiki` 에 둔다. 예전에는 `.llmwiki` 가 이 넷을 모두 "lore" 로 받았는데, 이 repo 의 페이지는 대부분 AGENTS.md 나 스킬 문서와 중복이었고, 제품 repo 에서 질문하려고 실제로 읽힌 것은 바깥 지식(회의록, 리서치, 고객 문서, 플랫폼 사실)이었다. 이 결정으로 2026-09-18 pocock-borrow 의 Non-goal("GLOSSARY·ADR 은 `.llmwiki` 와 겹친다")을 뒤집는다.

## Consequences

- wiki 는 훅 없이 ingest·query·lint 로만 쓴다. 세션 끝 자동 수집은 약 200건이 처리되지 않은 채 쌓이기만 해서 지운다.
- 이 repo 의 바깥 지식은 플랫폼 사실뿐이고 그 출처는 `docs/llm-doc-sources.md` 가 가리키므로, 이 repo 에는 `.llmwiki` 를 두지 않는다. 플랫폼 사실에 기대는 코드 자리에는 벤더 문서 링크를 단다.

출처: `.claude/spec/2026-10-06-matt-front-dev-back.md` 결정 7·19·21·22
