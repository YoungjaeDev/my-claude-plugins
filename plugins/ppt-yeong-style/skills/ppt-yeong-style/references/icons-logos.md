# 아이콘·브랜드 로고 — 공식 SVG fetch (§5c)

브랜드/도구 로고는 **직접 그리거나 codex로 생성하지 말 것**(손그림 git 로고가 어색했던 교훈) → **공식 브랜드 SVG 라이브러리에서 받아 인라인**한다.

> **이유:** 손그림·codex 생성 로고는 비율·색이 미묘하게 틀려 "가짜 티"가 난다. 공식 SVG는 권리자가 배포한 정확한 path라 한 번 받아두면 벡터로 선명하고 재현 가능하다.

## 소스 우선순위

**0순위 — ppt-master 번들 확인부터.** 외부 fetch 전에 `templates/icons/simple-icons/<name>.svg`(3,651개, 단색·CC0, 이미 라이선스 검증된 오프라인 자산 — 예: `notion.svg`·`slack.svg` 실제 포함 확인)를 먼저 찾는다. 있으면 `icon_sync.py`로 프로젝트에 동기화해 `data-icon="simple-icons/<name>"`으로 바로 사용 — 네트워크·라이선스 확인이 둘 다 필요 없다. 번들에 없거나 **풀컬러가 필요**할 때만 아래 외부 소스로 내려간다.

## 소스 (무료, 실제 fetch 검증)

- **개발도구 컬러 공식 로고 — devicon**: `https://cdn.jsdelivr.net/gh/devicons/devicon/icons/<name>/<name>-original.svg` (예: `git-original` = 공식 `#F34F29` 단일 path, 가장 컴팩트).
- **SaaS/브랜드 컬러**:
  - gilbarbara/logos(SVGporn) — `https://cdn.jsdelivr.net/gh/gilbarbara/logos/logos/<name>.svg`
  - vectorlogo.zone — `https://www.vectorlogo.zone/logos/<brand>/<brand>-icon.svg`
  - SVGL — `https://svgl.app` (API `https://api.svgl.app`)
- **모노톤 통일 — Simple Icons**: `https://cdn.simpleicons.org/<slug>` 또는 `/<slug>/<hex>` (단색·CC0; 멀티컬러 브랜드색은 사라짐). 대형 카탈로그: thesvg.org · svgrepo.com.
- **폴백 — Wikimedia Commons**: Simple Icons(단색)로 부족하고 위 CDN에도 없을 때만. Commons는 파일마다 라이선스·출처가 다른 저장소라 "퍼블릭 도메인"·"공식 SVG"는 **일반화하지 말 것** — 받으려는 개별 파일의 라이선스 태그(파일 상세 페이지의 `{{PD-textlogo}}` 등)를 그 파일 한정으로 확인한 경우에만 그렇게 표기·사용한다.

## 언제 공식 fetch, 언제 내장 brand-* 아이콘

같은 로고라도 슬라이드에서의 역할에 따라 소스가 갈린다:

- **브랜드 정체성이 슬라이드의 주 메시지**(비교표·"powered by" 로고 벽·파트너 소개)일 때 → 공식 fetch(위 소스), 풀컬러·정확한 브랜드 마크 유지.
- **다른 아이콘들과 나란히 놓이는 장식용 소형 배지**(모노톤 아이콘 그리드의 일부, "이 항목이 대략 이 브랜드 관련"이라는 표식)일 때 → 덱의 단일 아이콘 라이브러리(`ppt-master-craft.md` §4 "아이콘 라이브러리 1종" 원칙, tabler-outline 등의 `brand-*` 글리프)를 그대로 유지. 컬러 공식 로고를 섞으면 그 라이브러리의 모노톤·동일 stroke-width 통일성이 깨진다.

## 워크플로

1. `curl -fsSL <CDN URL> -o assets/logos/<name>.svg` 로 받아 **로컬 보관**(빌드 재현·오프라인).
2. SVG의 path/shape를 슬라이드에 **인라인** + `<g transform="translate(x,y) scale(s)">`로 배치(s = 목표px ÷ 원본 viewBox 변). 원본 fill 색 유지.
3. `<image href>`로 SVG를 거는 대신 **인라인**(finalize 단계 래스터화 회피 → 벡터 선명).
4. 아이콘 56~72px, 관련 텍스트 옆. 공식 도메인(예: `git-scm.com`)은 muted로 신뢰 단서.
5. **근접성(proximity) 필수**: 아이콘은 설명하는 요소(행·문구) **바로 옆**에 붙여 한 묶음으로. 빈 여백(슬라이드 끝)에 멀리 띄우면 고아 요소 → 금지(텍스트 끝~아이콘 간격은 1행 높이 이내).

## 라이선스

아이콘 파일 라이선스(대개 MIT/CC0)와 별개로 **브랜드 상표권**은 권리자 귀속 — 교육·소개 맥락 사용, 변형·왜곡 금지.

**금지:** 손그림 브랜드 로고, 이모지 아이콘, 저해상 래스터.
