# 앞단은 Matt 스킬 원본이, 뒷단은 dev 가 맡는다

아이디어에서 인계 PR 까지는 `mattpocock-skills` 를 fork 나 수정 없이 auto-update 로 쓰고, dev 는 인계 PR 부터 머지와 정리까지만 맡는다. Matt 흐름은 스킬 하나가 일 하나만 하고 단계마다 다음 스킬이 읽을 산출물(spec, 티켓, integration branch)을 남기지만, dev 앞단의 `decompose-issue`·`resolve-issue` 는 스킬마다 책임이 17-18개였고 2026-09-21 이후로는 쓰이지 않았다. Matt 흐름은 "PR ready for review" 에서 끝나고 dev 사용량은 그 뒤(리뷰, 머지, 정리)에 몰려 있어서, 두 흐름은 겹치지 않고 이어진다.

## Consequences

- dev 에서 `decompose-issue`, `resolve-issue`, `diagnose`, `state-tracker` 를 지운다. 버그 진단은 Matt `diagnosing-bugs` 가, 'grill me' 는 Matt `grilling` 이 맡는다.
- Matt 원본을 고치지 않으므로 Matt 쪽 버그(blocked-by 링크가 안 걸리는 문제 등)는 우회만 하고 고치지 않는다.

출처: `.claude/spec/2026-10-06-matt-front-dev-back.md` 결정 1·3·5·9·10
