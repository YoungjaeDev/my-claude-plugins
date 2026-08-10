/goal docs/prd/skill-forge/01_PRD.md의 모든 acceptance criterion 이 만족되고 VALIDATION.md의 필수 검증이 통과될 때까지 멈추지 말고 PLAN.md의 skill-forge 스킬과 가드를 구현한다.

작업 디렉토리는 docs/prd/skill-forge/ 이고 산출 코드는 plugins/docs-forge/skills/ 와 scripts/ 에 들어간다.

먼저 PRD.md, VALIDATION.md, RECOVERY.md, PLAN.md를 읽는다. 전체 결정 근거가 필요하면 .claude/spec/2026-08-05-skill-forge-and-singleton-absorption.md를 읽는다.

마일스톤 4개를 순서대로 진행한다 (선행 확인 → skill-forge → 자기검수 → 가드). 각 마일스톤의 범위·완료 조건·검증은 PLAN.md를 단일 진실 원천으로 삼는다.

PRD.md와 PLAN.md를 벗어나는 scope 확장은 금지한다. Non-goals 항목이나 선택 기능은 구현하지 않는다.

이 골이 절대 하지 않는 것: 단일스킬 플러그인 흡수, rename 실행. 이 둘은 #198 에서 사람이 처리해 PR #200 으로 머지됐고 되돌리기 어렵다. 마일스톤 3 은 그 결과를 검수만 한다. docs/audit/ 의 기존 파일도 수정하지 않는다. .llmwiki/ 와 tests/fixtures/ 의 과거 기록은 소멸한 플러그인을 언급해도 보존한다. 참조 0건 기준은 live 참조에만 걸린다. 스킬 50개 전수 검토는 별도 이슈이므로 도구만 만들고 돌리지 않는다.

자립 제약을 지킨다. skill-forge 본문·references·scripts 어디에서도 외부 마켓플레이스 스킬(skill-creator, superpowers, hermes-agent-skill-authoring)을 읽으라고 지시하지 않는다. 필요한 내용은 references 안에 자체 보유한다. 측정 스크립트는 docs/audit/measure-skills.mjs 를 참조하지 않고 번들 scripts/ 에 자체 구현한다. 저장소 내부 스킬 위임도 필수 경로에 두지 않는다. bare ${CLAUDE_PLUGIN_ROOT} 대신 cross-runtime resolver 블록을 쓴다.

마일스톤 1 에서 확인 못 한 항목은 unverified 로 표기하고 금지 규칙으로 단정하지 않는다. 근거 없는 금지를 만드는 것이 규칙이 없는 것보다 나쁘다.

엄격도는 엄격이다. 각 마일스톤이 끝나면 VALIDATION.md의 필수 검증 7종을 전부 재실행하고, 하나라도 실패하면 다음 마일스톤에 진입하지 않는다. 플러그인 파일을 건드렸으면 plugin.json PATCH 이상 + marketplace.json 엔트리 + metadata.version 을 같은 변경에 포함하고 매니페스트를 재생성한다.

각 마일스톤이 끝나면 PROGRESS.md를 업데이트한다. 실패한 시도는 배운 점까지 기록한다.

모든 실패 처리·되돌리기·방향 재확인 규칙은 RECOVERY.md를 따른다. 요구사항이 충돌하거나 같은 검증이 3회(3 attempts) 실패하면 자체 수정을 멈추고 사람의 결정을 기다린다 (Claude Code 는 /goal pause 를 지원하지 않음).
