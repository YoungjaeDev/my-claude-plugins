# ppt-yeong-style × ppt-master 레버 정렬 보완 설계

- 작성일: 2026-07-01
- 상태: draft (구현 보류 — 별도 브랜치 작업 완료 후 착수 예정)
- 관련 스킬: `plugins/ppt-yeong-style/skills/ppt-yeong-style/`
- 근거: 설치된 `ppt-master` 플러그인(`~/.claude/plugins/marketplaces/ppt-master/skills/ppt-master/`) 파일트리 전수 확인

## 1. 배경과 목적

`ppt-yeong-style`은 ppt-master(빌드 엔진) 위에 얹는 "무엇을·어떻게 쓸지" 작성 규약 레이어다. ppt-master 플러그인의 실제 파일트리를 전수 확인한 결과, `references/ppt-master-craft.md`가 "레버 6종"으로 정리해둔 것보다 엔진의 실제 표면(모드 5종·비주얼스타일 18종·차트 71종·도메인 레이아웃 7종·이미지 3경로·라우팅 5+종)이 훨씬 넓고, 그중 일부는 yeong의 시그니처(design-language.md §0)와 제대로 연결돼 있지 않다는 게 드러났다.

가장 중요한 갭: yeong의 미감 시그니처("따뜻한 중립 + 단일 커밋 액센트")가 ppt-master의 18개 기성 `visual_style` 어디에도 매핑돼 있지 않아, 덱을 만들 때마다 ppt-master의 Strategist가 임의의 기성 스타일을 추천할 위험이 있다. 그 외에도 색 락 절차 중복, 이미지 rendering×palette 락 방식에 대한 부정확한 서술, 도메인 특화 템플릿과의 장르 불일치, PPTX 템플릿을 가져오는 시나리오에 대한 경계 미비를 확인했다.

목표는 **새 파일을 만들지 않고**, 기존 `SKILL.md`/`references/` 몇 곳에 짧게 추가·정정해서 ppt-master가 매번 정확한 값을 추천하도록 "신호"를 정확히 주는 것이다.

## 2. 검토한 대안과 선택 (Approach A)

| 접근 | 내용 | 기각/채택 사유 |
|---|---|---|
| **A. 신호만 정확히 주기 (채택)** | 새 파일 없이 기존 SKILL.md/references 몇 곳에 짧게 추가·정정 | 기존 "정확한 값은 ppt-master가 원본, 우린 판단만" SOT-포인터 원칙 유지, 유지보수 부담 최소 |
| B. 종합 매핑표 새 파일 | 모든 축(구조·무드·차트·이미지)을 한 파일에 총망라 | ppt-master 카탈로그 변경 시 유지보수 부담 크고, 스킬이 일부러 피해온 "엔진 내용 복제" 위험 |
| C. 인터뷰 질문만 추가 | 가장 작은 변경 | 가장 중요한 발견(무드 custom 락 안 걸린 문제)을 해결하지 못함 |

카드뉴스/소셜미디어(정사각·세로) 포맷 지원은 배치 원리 자체가 16:9와 근본적으로 달라 이번 라운드에서 명시적으로 제외한다(§4 참고).

## 3. 변경 파일 및 내용

### 3.1 `references/design-language.md` (§0)

시그니처 서술 뒤에 짧은 문단 추가: 이 시그니처는 ppt-master의 `visual_style: custom` + `visual_style_behavior:` 서술 문단 메커니즘으로 매 덱 명시 락한다는 연결고리를 문서화한다(ppt-master 자체에 "기성 프리셋이 없으면 `custom`으로 문단을 적어 락하라"는 탈출구가 이미 있음 — `visual-styles/_index.md` §3).

### 3.2 `references/ppt-master-craft.md` (§4 레버 표 + 함정 섹션)

- **표 행 추가/구체화**: ppt-master의 "Eight Confirmations" 중 확인 항목 d(스타일)는 이미 mode(Layer 1)·visual_style(Layer 2) 두 레이어로 구성돼 있음(새 확인 단계 추가 아님, 기존 항목 명세):
  - mode: 강의/실습 덱 → `instructional` 고정(ppt-master 자체 추천표와 일치, 판단 불필요). 제안 덱 → `narrative`/`pyramid` 중 인터뷰에서 판단(색 락과 동일 원칙 — 프로젝트마다 판단, 강제 고정 안 함).
  - visual_style: yeong 덱 전부 → `custom` 고정 + design-language.md §0 요약 문단(고정 문구, 프로젝트마다 재작성 안 함 — 색 hex와 달리 "철학"이라 고정).
- **정정**: "이미지 rendering×palette 매트릭스" 레버가 "spec_lock에 락"된다는 현재 서술은, 그 락이 ppt-master 자체 AI 이미지 생성 경로(`image_usage: ai`) 전용이라는 걸 확인 후 부정확함이 드러남 — yeong은 codex-image(외부)로 이미지를 만들어 `image_usage: provided`로 들어가므로 이 spec_lock 필드가 안 걸릴 가능성이 높음. "ppt-master가 자동으로 지키는 락"이 아니라 "codex-image 프롬프트에 넣을 어휘집(화풍·색조합 이름을 프롬프트 문구로 번역해 사용)"으로 서술 정정.
- **색 절차 관계 명시**: yeong의 design-shotgun 색 후보 단계는 ppt-master 자체 색 확정 단계(confirmation e, 3후보+실시간 미리보기)에 들어가는 **사전 브리핑**이지 별도 중복 확정 라운드가 아니라고 명시.
- **함정 섹션에 추가**:
  - 도메인 특화 레이아웃 템플릿 7종(academic_defense/ai_ops/government_blue·red/medical_university/pixel_retro/psychology_attachment)은 중국 관공서·의료·학술 시장 특화라 yeong 장르(한국어 비즈니스·기술 강의/제안)와 안 맞음 — 기본 미사용, 사용자 명시 요청 시만 검토.
  - 개별 장의 이미지+텍스트 배치가 막히면 ppt-master의 `references/image-layout-patterns.md`(50+ 배치 패턴 어휘집)에서 고른다는 포인터.
  - 회사 템플릿을 반복 재사용하려면 ppt-master의 템플릿 등록 절차(`create-template`/`create-brand` 워크플로)로 한 번 만들어두면 이후 "3종 fusion" 재료로 계속 쓸 수 있다는 포인터.

### 3.3 `references/ppt-master-and-qa.md` ("주의/미해결" 섹션)

라우팅 경계 노트 2개 추가:
- 사용자가 실제 .pptx 파일을 그대로 쓰고 싶다고 하면(템플릿 채우기, ppt-master의 `template-fill-pptx` 경로) 시각 규칙(색·구조·무드 락)은 적용 안 되지만 **글 관련 규칙(§3 원칙 15종·§7 윤문·§8b 스토리 흐름 review)은 형식과 무관하게 그대로 적용**한다는 것 명시.
- "이미 만든 PPT를 다듬어달라"(`beautify-pptx` 경로, 페이지 수/순서 유지)도 마찬가지로 md 소스 작성 규약(§2) 자체는 적용 안 됨을 명시.

## 4. 이번 라운드에서 제외 (다음 라운드 후보로 기록)

- 카드뉴스/소셜미디어 포맷(정사각·세로) 지원 — 예정된 후속 작업이 아니라, **yeong 스킬은 PPT 16:9를 계속 기본값으로 유지**하고 이 포맷은 규칙화하지 않는다. 사용자가 실제로 카드뉴스/소셜 포맷을 요청하면 그 시점에 ppt-master의 `canvas-formats.md`(포맷별 배치 원리 포함)를 검토해 온디맨드로 대응한다.
- 오디오 내레이션 등 부가 워크플로(`generate-audio`/`native-narration-pptx`) — 현재 요구 없음.
- 도메인 특화 레이아웃 7종 활용 — 장르 불일치로 보류.
- ppt-master `strategist.md` §4 "Layout Pattern Library"(11종 페이지 구도) — Strategist가 non-blocking으로 자동 적용하는 부분이라 yeong 쪽 조치 불필요, 참고 기록만.

## 5. 검증 방법

문서(스킬 md) 변경이라 자동 테스트는 없다. 대신:
1. 각 파일 수정 후 `python3 -c "import yaml; yaml.safe_load(...)"` 류로 SKILL.md frontmatter 파싱 이상 없는지 확인(과거 콜론-스페이스 이슈 재발 방지).
2. 새로 추가하는 크로스레퍼런스(`image-layout-patterns.md` 등 ppt-master 쪽 경로)가 실제 존재하는지 `find`/`grep`으로 확인.
3. `node scripts/sync-codex-manifests.mjs --check` / `sync-hermes-manifests.mjs --check` 통과 확인(설명 변경이 없으므로 영향 없을 것으로 예상되나 회귀 확인 차원).
4. 실사용 검증은 다음에 실제 yeong 스타일 덱을 만들 때 ppt-master의 Strategist Eight Confirmations에서 mode/visual_style 추천값이 의도대로(강의→instructional, 무드→yeong custom) 뜨는지로 확인 — 문서 변경 자체에 대한 자동 검증은 아니고 사용 시점 검증.

## 6. 다음 단계

현재 별도 브랜치(`chore/prune-plugins-roster`)에서 무관한 작업이 진행 중이라 구현은 보류한다. 이 브랜치 작업이 끝나면 별도 브랜치를 새로 파서 `superpowers:writing-plans` → 구현 순서로 이어간다.
