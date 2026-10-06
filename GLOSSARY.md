# my-claude-plugins

Claude Code 와 Codex 가 함께 읽는 플러그인 marketplace 다. 이 용어집은 플러그인이 다루는 개발 흐름과 지식 보관에 쓰는 말을 정한다.

## Language

### 개발 흐름

**앞단 (front half)**:
아이디어에서 인계 PR 이 열리기까지의 작업 구간.
_Avoid_: 기획 단계, planning, upstream

**뒷단 (back half)**:
인계 PR 부터 머지, 그리고 머지 뒤 정리까지의 작업 구간.
_Avoid_: post-PR, downstream

**spec**:
여러 세션에 걸친 작업 하나의 목표, 결정, 범위를 적어 이슈 트래커에 올린 것. `.claude/spec/` 의 파일은 spec 이 아니라 과거 기록이다.
_Avoid_: 기획서

**인계 PR (handoff PR)**:
앞단이 끝날 때 열리는 PR. 뒷단은 이 PR 에서 시작한다.
_Avoid_: draft PR (draft 는 PR 의 상태일 뿐이다), spec PR

**리뷰 루프 (review loop)**:
리뷰 봇의 지적을 판단해 반영하고, push 해서 다시 리뷰받기를 되풀이하는 뒷단의 일.
_Avoid_: cr-fix (옛 스킬 이름), 자동 수정

**HEAD 판정 (HEAD verdict)**:
리뷰어가 PR 의 현재 HEAD 커밋에 대해 낸 결과로, 지적·통과·실패 중 하나다. 진행 중 표시나 rate limit 안내는 판정이 아니다.
_Avoid_: 리뷰 완료, success status

### 지식

**바깥 지식 (outside knowledge)**:
저장소가 통제하지 못하는 것(플랫폼, 벤더, 고객, 도메인)에 대한 지식. 문서로 들어왔든 작업 중에 알게 됐든 같다.
_Avoid_: lore

**raw**:
밖에서 들어온 문서를 손대지 않고 그대로 보관한 원본.
_Avoid_: 자료, transcript (원본의 한 종류일 뿐이다)

**개념 페이지 (concept page)**:
한 개념에 대한 raw 나 작업 중 증거(PR, 커밋, 측정 결과)를 묶어 정리하고 그 출처를 인용하는 wiki 페이지.
_Avoid_: insight, lore 페이지
