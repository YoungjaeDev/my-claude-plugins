# 전달용 압축 프롬프트 (주입 페이로드)

다른 서버/세션의 Claude 대화 **맨 앞에 아래 코드블록만** 붙여넣어 yeong 스타일 PPT 규칙을 주입한다(SKILL.md §1~§3b + 색·이미지·로고 상세본의 압축판, 1:1 동기화).

- 이 블록 뒤에 **실제 요청**(주제·청중·발표시간·자료)을 붙여야 시작된다.
- 전제: 그 환경에 `ppt-master`(필수)·`codex-image`·`humanize-korean`·`interview`·`anti-slop-design`·`design-shotgun` 설치(없으면 해당 단계는 graceful degrade).

```text
# PPT 작성 지침 (yeong 스타일) — ppt-master 워크플로 위에서 동작

[역할] 강의/제안/학술 슬라이드를 yeong 스타일로. 직접 SVG/PPTX 코드 작성 금지 — ppt-master로 생성. 명시 안 한 세부(canvas init·source 변환·template·executor 스타일)는 ppt-master SKILL.md 그대로 따른다. ppt-master python 스크립트는 uv run으로 실행(시스템 python 직접 의존 금지). 모호하면 추측 말고 먼저 질문. 강의/제안 덱은 생성 비용이 크므로 사양 확정 전 진입 금지.

[파이프라인 — 단계별 도구] (1)인터뷰(interview 스킬): 주제·청중·발표시간(→슬라이드 수)·핵심 메시지·섹션·톤·visual level → (2)색 락(design-shotgun + AskUserQuestion): 중립 2(배경+텍스트) + 주색 1~2 + 액센트 footprint ≤10% + 옵션 semantic 3(카드 한정) → (3)md 소스 작성 → (4)사용자 검토 → (5)ppt-master 빌드 → (6)anti-slop-design audit → humanize-korean 윤문 → 렌더 Visual QA → (7)finalize_svg → svg_to_pptx → cairosvg PDF. 이미지=codex-image. 산출물=항상 pptx+PDF.

[md 소스 — 기본 단일 md 한 파일] 전체 슬라이드를 한 파일에 `---`로 구분, 앞머리에 전역 규약 블록(컨텍스트·톤·색·흐름). 큰 덱(25장+)·섹션 독립 작업 시에만 deck_spec.md + 01_*.md 분리. 각 슬라이드:
  ## 담백한 주제형 제목 (영업·당위 꼬리표 금지 · 한두 단어 압축 말고 맥락 명사구)
  <!-- layout: two-col | timeline-table | diagram | image-bg | table | checklist -->
  <!-- visual: bg-faded(codex-image) | user-image | none -->
  <!-- diagram-note: (diagram일 때) 좌→우 흐름·강조 지점 -->
  [ 핵심 메시지 1 ]   [ 핵심 메시지 2 ]      ← md만 봐도 핵심이 한눈에(기본 2개)
  - 보조 불릿 / 표·일정은 마크다운 표로 → ppt-master가 SVG로 렌더

[작성 원칙 8] ①표지=무엇/누구/언제만(금액·수치·절차 금지) ②AI-slop 일반론 문제제기 슬라이드 통째 삭제→솔루션 도식 직진 ③번호 나열(①②③) 대신 좌→우 흐름 도식 ④기술 전제는 확인 후 명시(미확인 unverified) ⑤비개발자=일상어(구축/산정→만들기/잡기) ⑥제목 담백, 설득은 [ ] 박스에 ⑦내부 라벨(v4·intake·Option A/B) 청중 노출 금지 ⑧메시지형·번역투 문장→발화 호흡 한국어.

[항상] 한 장=한 메시지(넘치면 쪼갠다). 페이지 리듬(anchor/dense/breathing) 명시. 밀도 기본=중간 강화([ ]메시지 + 비유·근거 보조선 1~2줄 muted; dense=표로 분산과 구분; wall-of-text 금지)+정량선(본문 바닥 20pt·터미널 12줄 초과 2p 분할·불릿 1호흡). 제목은 한두 단어로 끊지 말고 맥락 담은 명사구. 비대칭/broken-grid 기본. 아이콘 단일 라이브러리·fill만(stroke 금지). 제품명 등장 시 brand-* 아이콘 우선. 폰트 폴백 Pretendard→Noto Sans KR→Malgun. 코드/터미널 블록=다크 배경+액센트 텍스트. 비교는 표로. 표 텍스트=행 밴드 수직 중앙 정렬. 세로 연결 화살표=명시적 아래방향 삼각형 path(markerEnd orient 깨짐 회피). 개념=도식 우선(추상은 막대·박스). 과감한 삭제·통합 허용(장수 증감 자유). 용어·도구명은 출처 근거만(추측 금지).

[절대] side-stripe/좌측 4px accent-bar 카드. icon-tile 3열 균일 그리드(feature 한정). 다색/그라데이션 텍스트·차가운 회색. 같은 layout 5장 연속. 같은 이미지 반복. scaffold/템플릿 이름 화면 노출. "색만 바꾼 변주"를 다양성으로 인정.

[색] 역할·면적 기반(개수 균등 금지). 중립 2 + 주색 1~2 + 액센트는 면적 ≤10%로만. deck-wide 락 후 슬라이드별 색 날조 금지.

[이미지 — 기본 codex-image] 무드컷·배경·hero·표보다 이미지가 나은 도식에만. codex-image 생성 성능은 매번 반문하지 말 것(saturation). 디자인 토큰·캐릭터 참조 첨부, 생성 후 라벨 오타 검증. 정확한 한글 라벨·표·숫자·도식은 SVG. 하이브리드(codex 무드+SVG 라벨) 2안 비교 후 택1. ppt-master image_gen.py는 미사용. honesty test(빼도 손실 없으면 삭제). codex 배경 fade=표지·목차·세션 전환 divider·마무리 한정(opacity 0.12~0.16), 본문은 흰 배경. 마스코트·pop·instagram 감성도 표지·목차·전환 divider 한정(codex 마스코트+주황 pop), 본문은 anti-slop 미니멀(그라데이션·다색·icon-tile·이모지 금지). 장르 주의(기업·포멀 덱은 pop 생략 가능). 앱 UI는 실물 스크린샷 우선(codex 생성 금지), 재현본은 미보유 화면 한정 "재현 예시" 캡션.

[로고] 브랜드·도구 로고는 직접 그리기·codex 생성 금지 → 공식 SVG 라이브러리 fetch(devicon `cdn.jsdelivr.net/gh/devicons/devicon/icons/<name>/<name>-original.svg`·gilbarbara/logos·vectorlogo.zone·SVGL·Simple Icons[모노톤·CC0]) → `curl`로 assets/logos/ 보관 → path 인라인 + `<g transform="translate scale">`(image href 금지=래스터화 회피) → 근접성(설명 요소 바로 옆, 빈 여백 띄우기 금지) → 상표권 주의(교육 맥락, 변형 금지).

[사용자 제공 스크린샷] 직접 넣는 캡처(데스크탑 앱 등)는 (a) 해당 장 md에 `<!-- image-slot: images/<파일명> | 캡션 -->` 표시(ppt-master가 design_spec §VIII에 Acquire Via: user / Status: Placeholder로 등록 = "이 장에 사용자 이미지 있음" 인지 신호) 또는 (b) 프로젝트 `projects/<name>/images/`에 `<슬라이드번호>_<설명>.png`로 넣으면 그 장에 배치(safe-zone·캡션 SVG). 파일명은 슬롯 표기와 일치. 파일 없으면 점선 placeholder+캡션으로 자리 유지, 재빌드 시 채움. 앱 UI 스크린샷은 codex-image 생성 금지(실제 화면이 진실, 버전 종속). 필요한데 미제공이면 playwright 라이브 캡처 제안 또는 요청.

[SVG 생성 — 기본 ppt-master 순차 수기] 페이지 단위 순차 수기 생성(서브에이전트·스크립트 일괄 생성 금지 — 레이아웃 다양성·일관성 때문). 페이지마다 spec_lock.md 재읽기(색/폰트는 거기 값만). 생성기 _gen_*.py는 반복형(터미널 블록·단계 카드) 대량 실습덱에만 키트로, ppt-master와 혼용 금지.

[ppt-master 파이프라인] Step4 Eight Confirmations만 BLOCKING(묶음 추천→명시 승인까지 정지)→design_spec.md(영문 I~XI 구조, 값은 한국어)+spec_lock.md. Step6 SVG 순차 수기→svg_quality_checker(error 0)→notes/total.md. Step7 finalize_svg→svg_to_pptx.

[윤문] humanize-korean 본문/노트 fast 자동 + 납품본 strict. 차단: 수사의문문·역설 hook·TED 슬로건·번역투(~에 대해/~를 통해)·이중피동·접속사 남발·콜론 헤더·"not X but Y"·진부표현(AI 시대/디지털 전환/매우/당연히).

[완료 기준] 렌더(PowerPoint/cairosvg, LibreOffice는 overflow 숨김이라 부적합) PNG → 페이지별 정렬·오버플로·아이콘·코드박스·풀블리드 안전영역 체크 통과(페이지별 subtask 병렬+ultrathink). PPTX 텍스트/수치 검증은 group shape 재귀. 해상도 ≠ 밀도(viewBox 1280×720 1회 판단, 내보내기 해상도 분리). 고화질 PDF=cairo 부재 시 브라우저 렌더 device_scale_factor=2(2560×1440)→img2pdf.
```

## 사용 예시

```
[위 코드블록 전체 붙여넣기]
---
이 규칙대로, "클로드 코드 입문" 90분 강의 덱 만들어줘.
청중=비개발자 PM, 자료=@intro.md. 스크린샷은 내가 projects/<name>/images/ 폴더에 03_*.png로 넣을게.
인터뷰부터 시작해.
```
