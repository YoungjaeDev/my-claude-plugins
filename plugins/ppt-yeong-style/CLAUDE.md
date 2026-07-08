# ppt-yeong-style Plugin

yeong 스타일 강의·제안 덱 작성 규약. **ppt-master**(빌드 엔진) 위에 얹는 작성 레이어 — 엔진은 손대지 않고, 그 위에서 무엇을·어떻게 쓸지를 일관 적용한다. 0.7.0부터 스킬 3종 + 리뷰 에이전트 4종.

## Skills

| Skill | Description |
|-------|-------------|
| `ppt-yeong-style` | 작성 규약(메인): 미감 시그니처(§0)·덱 유형·md 소스 규약·작성 원칙 16종·밀도 리듬(중간 강화 기본)·역할 기반 색·codex-image vs SVG 경계·앱 UI 실물 강제·ppt-master 레버 조합 차별화·윤문·렌더 QA. 진입점 = `SKILL.md`, 세부는 `references/` 6종 + `assets/injection-prompt.md` |
| `lecture-deck` | 강의 덱 전용 운영: 시간→장수 구성·실습 handouts 생성 규약(자료-지시문 정합 검증)·실습 프롬프트 카드·placeholder→실캡처 스크린샷 슬롯·리넘버링 파이프라인(4중 동기화)·표 행 수 재배치·전사 회고 루프·강사 노트 태그. 완성 실례 = `references/cc-common-reference.md`(47장) + 대표 렌더 PNG 5장 |
| `deck-review` | 리뷰 파이프라인 오케스트레이션: 아래 에이전트 4종 병렬 dispatch + `codex:rescue` 교차 리뷰(설치 시) → 장별 수정 티켓 종합. 리뷰어는 관찰+제안만, 수정은 메인 세션 |

## Agents (deck-review가 dispatch)

| Agent | 관점 |
|-------|------|
| `audience-fit` | 청중 페르소나 적합성 — **페르소나는 파라미터 주입**(하드코딩 없음) |
| `story-flow` | through-line·기승전결·개념 순서·리듬 곡선 (§8b 9항목 실행 규격) |
| `fact-check` | 공식 docs 대조 + 공식 vs 실사용 병기 + unverified 표기 + 정정 파급 장 나열 |
| `design-qa` | 렌더 QA(정렬·오버플로·대괄호 누출·표 밴드)·anti-slop·레이아웃 분포 |

## 엔진·의존 관계

- **ppt-master** = 빌드 엔진(spec_lock·finalize_svg·svg_to_pptx·7-step). 구현 owner이며 **bare name으로 참조**(vendor 금지). prerequisite — 미설치 시 빌드 진입 전 중단.
- 그 외 의존 스킬은 **있으면 사용, 없으면 생략 + 설치 제안 문구 출력**: `codex-image`(이미지)·`interview`(인터뷰)·`anti-slop-design`(영문 slop·디자인 감사)·`humanize-korean`(한국어 윤문)·`design-shotgun`(색 후보)·`codex:rescue`(교차 리뷰).

## 구조

```text
ppt-yeong-style/
├── .claude-plugin/plugin.json
├── CLAUDE.md                       # 이 파일
├── agents/                         # 리뷰 서브에이전트 4종 (deck-review가 dispatch)
│   ├── audience-fit.md
│   ├── story-flow.md
│   ├── fact-check.md
│   └── design-qa.md
└── skills/
    ├── ppt-yeong-style/            # 메인: 작성 규약
    │   ├── SKILL.md                # §0 미감 + 파이프라인 + md 규약 + 원칙 16 + 리듬 + §4 레버 + §5 서브스킬 포인터
    │   ├── references/             # design-language / color-typography / images-and-pop / icons-logos / ppt-master-craft / ppt-master-and-qa
    │   └── assets/injection-prompt.md
    ├── lecture-deck/               # 강의 덱 운영
    │   ├── SKILL.md
    │   ├── references/cc-common-reference.md   # 47장 완성 실례(로스터·리듬·검증 이력)
    │   └── assets/cc-common/*.png  # 대표 렌더 5장(저용량 — 실물 PPTX/PDF는 cc-lesson-deck·Drive 참조)
    └── deck-review/
        └── SKILL.md                # 4관점 병렬 리뷰 오케스트레이션
```

## Hermes Agent

monorepo 서브디렉토리에서 플러그인을 설치:

```bash
hermes plugins install YoungjaeDev/my-claude-plugins/plugins/ppt-yeong-style --enable
hermes gateway restart  # 메시징 게이트웨이로 Hermes를 쓰는 경우
```

스킬을 명시적으로 로드 (Hermes plugin skill은 opt-in, `--enable` 후 새 Hermes 세션 시작):

```text
skill_view("ppt-yeong-style:ppt-yeong-style")
```

- 스킬 본문은 Claude/Codex 도구 용어(`Bash`, `Read`, `AskUserQuestion`, 이미지 생성, `Skill`)를 Hermes 도구(`terminal`, `read_file`, `clarify`, `image_generate`, `skill_view`)로 매핑하는 호환 표를 포함한다.
- 전제: 빌드 엔진인 외부 `ppt-master` 플러그인 enable + `uv` 설치가 필요하다. 미설치 시 빌드 진입 전 중단.
- Hermes·Codex(0.135는 `agents` 미노출)에는 Claude식 서브에이전트 dispatch가 없다 — `deck-review`는 4관점 체크리스트를 메인 세션에서 순차 수행하는 것으로 강등된다(`deck-review/SKILL.md` 런타임 폴백 참조).
