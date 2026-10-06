# post-merge 는 머지 뒤 정리만 한다

post-merge 는 브랜치, 트래커, 상태 파일 정리만 하고, 교훈을 CLAUDE.md·AGENTS.md·rules·Serena·wiki 에 옮겨 적던 단계(옛 Step 6-8)는 두지 않는다. 교훈은 빌드한 세션에서 `/retro` 가 맡는다. retro 는 기계적인 실수를 자동 검사로 바꾸고 항상 로드되는 문서를 최소로 두는 반면, 옛 Step 6 은 교훈을 문장으로 쌓아 AGENTS.md 를 약 20KB, dev CLAUDE.md 를 약 30KB 로 키웠다.

출처: `.claude/spec/2026-10-06-matt-front-dev-back.md` 결정 18
