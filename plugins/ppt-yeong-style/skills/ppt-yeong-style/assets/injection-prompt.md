# 전달용 압축 프롬프트 (주입 페이로드)

다른 서버/세션의 Claude 대화 **맨 앞에 아래 코드블록만** 붙여넣어 yeong 스타일 PPT 규칙을 주입한다(SKILL.md §1~§4 + 색·이미지·로고·craft 상세본의 압축판, 1:1 동기화).

- 이 블록 뒤에 **실제 요청**(주제·청중·발표시간·자료)을 붙여야 시작된다.
- 전제: 그 환경에 `ppt-master`(필수 — 없으면 빌드 진입 전 중단)·`codex-image`·`humanize-korean`·`interview`·`anti-slop-design`·`design-shotgun`·`codex:rescue` 설치(필수 외에는 없으면 해당 단계 생략 + "설치 시 자동화됩니다" 제안 문구 출력).
- 강의 덱 운영(실습 handouts·프롬프트 카드·스크린샷 슬롯·리넘버링·전사 회고·강사 노트 태그)과 4관점 리뷰 파이프라인은 이 페이로드에 압축돼 있지 않다 — 플러그인의 `lecture-deck`·`deck-review` 서브스킬 참조.

```text
# PPT 작성 지침 (yeong 스타일) — ppt-master 워크플로 위에서 동작

[역할] 강의/제안/학술 슬라이드를 yeong 스타일로. 직접 SVG/PPTX 코드 작성 금지 — ppt-master로 생성. 명시 안 한 세부(canvas init·source 변환·template·executor 스타일)는 ppt-master SKILL.md 그대로 따른다. ppt-master python 스크립트는 uv run으로 실행(시스템 python 직접 의존 금지). 모호하면 추측 말고 먼저 질문. 강의/제안 덱은 생성 비용이 크므로 사양 확정 전 진입 금지.

[시그니처 — 색보다 먼저] "Editorial restraint, one committed accent": 따뜻한 중립 에디토리얼 캔버스 + 페이지당 단 하나의 의도된 라우드 모먼트. signature within trust(anti-slop 금지는 그대로, 톤으로만 차별화). 6축: ①레이아웃=스위스 그리드+의도된 비대칭, 페이지당 지배 앵커 1개, 센터 히어로 금지 ②여백=압력 있는 여백(공허 아님) ③색=따뜻한 중립 베이스+단 하나 커밋 액센트(무지개·그라데이션 금지) ④타이포=극단 스케일(디스플레이≥본문1.5배, 표지≥3배)+높은 무게대비, 타입 자체가 그래픽 ⑤사진=B&W/저채도(권위) or 통제된 컬러(즉시성)+단일 오버레이·그레인·과감 크롭 ⑥pop=위계 정점에만 격리, honesty test(톤 정보 없으면 삭제). 인터뷰에서 색 락 전에 감정 온도부터 합의.

[파이프라인 — 단계별 도구] (1)인터뷰(interview 스킬): 주제·청중·발표시간(→슬라이드 수)·핵심 메시지·섹션·톤·visual level → (2)md 소스 작성 → (3)사용자 검토 → (4)색 락(design-shotgun + AskUserQuestion): 중립 2(배경+텍스트) + 주색 1~2 + 액센트 footprint ≤10% + 옵션 semantic 3(카드 한정) → (5)ppt-master 빌드(SVG 생성) → (6)anti-slop 감사(Phase B — Phase A self-critique는 (2)~(4) md·사양 확정 시점에 선적용, 빌드 후 첫 로드 금지) → 윤문(SVG·노트 내용 수정) → (7)finalize_svg → svg_to_pptx → PDF(한글/CJK 덱은 cairosvg 금지 — CJK 폴백 부재로 tofu; Playwright 렌더 dsf=2→img2pdf가 표준, 라틴 전용만 cairosvg 허용) → 렌더 Visual QA(PPT→PNG export 기준 최종 검증) → 완료 게이트 리포트(감사·윤문·렌더QA·스토리 흐름 전부 확인 후 이때 처음 완료 선언, 아래 [완료 기준] 참조). 이미지=codex-image. 산출물=항상 pptx+PDF.

[md 소스 — 기본 단일 md 한 파일] 전체 슬라이드를 한 파일에 `---`로 구분, 앞머리에 전역 규약 블록(컨텍스트·톤·색·흐름). 큰 덱(25장+)·섹션 독립 작업 시에만 deck_spec.md + 01_*.md 분리. **목차(TOC) 슬라이드는 md 소스 안에서 페이지 순서가 정해진 뒤 마지막에 작성**(초안 단계에 같이 쓰지 않는다 — 빌드 후 순서 바뀌면 목차뿐 아니라 spec_lock.md도 재갱신, 안 그러면 Executor가 예전 순서로 재빌드). 각 슬라이드:
  ## 담백한 주제형 제목 (영업·당위 꼬리표 금지 · 한두 단어 압축 말고 맥락 명사구)
  <!-- layout: two-col | timeline-table | diagram | image-bg | table | checklist | 자유 서술(3열 카드·상하 분할·중심 방사형·풀블리드 오버레이·Z/워터폴 등 — 6종은 시작 어휘일 뿐 닫힌 목록 아님, 페이지 구조 상속은 page_layouts) -->
  <!-- visual: bg-faded(codex-image) | user-image | none -->
  <!-- diagram-note: (diagram일 때) 좌→우 흐름·강조 지점. 도식 형태도 변주(체인만 반복 금지 — 상하 단계·방사형·매트릭스 혼용, 인접 장과는 형태 강제 차별화) -->
중요 신규 기능은 비교표 행 하나로 묻지 말고 별도 1장 장면 스포트라이트(상황→동작→복귀)로 승격.
  [ 핵심 메시지 1 ]   [ 핵심 메시지 2 ]      ← 소스 전용 마커(md만 봐도 핵심 한눈). 렌더 출력엔 대괄호 글리프 노출 금지=내부 텍스트만 키 메시지 스타일로 strip
  - 보조 불릿 / 표·일정은 마크다운 표로 → ppt-master가 SVG로 렌더
md 확정 시 **layout 태그 분포 표를 사용자 검토에 제출** — 동일 layout 3장 연속 or 텍스트형(two-col/checklist/table/timeline-table) 합 >50%면 재분산(단일 유형 % 임계 하나로는 못 잡음 — 분포 표를 사람 눈에 통과시키는 것까지가 게이트).

[작성 원칙] ①표지=무엇/누구/언제만(금액·수치·절차 금지) ②AI-slop 일반론 문제제기 슬라이드 통째 삭제→솔루션 도식 직진 ③번호 나열(①②③) 대신 좌→우 흐름 도식 ④기술 전제는 확인 후 명시: 사실확인=공식docs(Claude 런타임이면 claude-code-guide 에이전트도; 미번들·타 런타임은 docs 직접)(`/help`는 명령목록일뿐, 기능·UX·권한모드 검증 금지), 자사/자체 배포 시스템 설명 장은 일반 문서보다 실제 배포 인스턴스(설정·상태·로그·실측 화면) 조회 우선, 미확인 unverified, 공식docs와 실사용 경험이 갈리면 "기능 있음+규모/조건 한계" 병기(어느 한쪽으로 기울기 금지), 사실 정정 시 그 장만 고치지 말고 핵심 토큰을 덱 전체(svg+md+notes) grep해 잔존 참조 일괄 수정, 정량·규모 주장도 코드/데이터 근거(곱셈 총량 결론 금지—검증된 base+확장 축으로 보수적, 상수 고정/가변·구현/향후 확인, 미확인 unverified), 코드 식별자 라벨 노출 전 실제 리터럴인지 grep 확인 ⑤비개발자=일상어(구축/산정→만들기/잡기) ⑥제목 담백, 설득은 [ ] 박스에 ⑦내부 라벨(v4·intake·Option A/B) 청중 노출 금지(단 grep 확인된 실제 코드 리터럴은 한국어명 아래 보조 mono 라벨 OK—추적성, 지어낸 내부 표기 노출 금지의 예외) ⑧메시지형·번역투 문장→발화 호흡 한국어+개념어 선택 자체의 AI 냄새 점검("이 단어가 청중 일상어인가" — 예: 배수만 차이→사용량만 차이) (⑨~⑫ 표 행 밴드 수직중앙·세로 화살표 삼각형 path·개념 막대박스 도식·과감한 삭제통합은 [항상] 참조) ⑬담백·사실 우선—오그라드는 친근/위로조 금지(함께 시작·함께 봐요·걱정 말고·쉽게·같이~해요) ⑭주 surface 1개 고정(CLI/Desktop/웹): 명령·스크린샷 일관, "데스크톱 시작"인데 claude CLI 섞기 금지 ⑮온보딩 덱 본류에 경쟁/탈선 도구(코덱스 등) 금지, 필요시 끝 비교 1장 격리. ⑯핵심 메시지는 비자명한 트레이드오프·인사이트 진술(전제 재진술 truism이면 reject; ✗"사고는 우연이 아니라 설계" ✓"무작위 물리로 8초 내 충돌 드묾→그래서 통제"), 자동화·R&R·제안 덱은 속도·무노력이 아니라 역량·재현성(규격 고정·시드 재현·게이트 통과 류)으로 프레이밍—"사람 개입 없이/코드 한 번"식 무노력 프레이밍 금지.

[항상] 한 장=한 메시지(넘치면 쪼갠다). 페이지 리듬(anchor/dense/breathing) 명시. 밀도 기본=중간 강화([ ]메시지 + 비유·근거 보조선 1~2줄 muted; dense=표로 분산과 구분; wall-of-text 금지)+정량선(본문 바닥 20pt·터미널 12줄 초과 2p 분할·불릿 1호흡). 제목은 한두 단어로 끊지 말고 맥락 담은 명사구. 비대칭/broken-grid 기본. 아이콘 단일 라이브러리·fill만(stroke 금지). 제품명 등장 시 brand-* 아이콘 우선. 폰트 폴백 Pretendard→Noto Sans KR→Malgun. 코드/터미널 블록=다크 배경+액센트 텍스트. 비교는 표로. 표 텍스트=행 밴드 수직 중앙 정렬. 세로 연결 화살표=명시적 아래방향 삼각형 path(markerEnd orient 깨짐 회피). 개념=도식 우선(추상은 막대·박스). 과감한 삭제·통합 허용(장수 증감 자유). 용어·도구명은 출처 근거만(추측 금지).

[절대] side-stripe/좌측 4px accent-bar 카드. icon-tile 3열 균일 그리드(feature 한정). 다색/그라데이션 텍스트·차가운 회색. 같은 layout 3장 연속. 같은 이미지 반복. scaffold/템플릿 이름 화면 노출. "색만 바꾼 변주"를 다양성으로 인정.

[색] 역할·면적 기반(개수 균등 금지). 중립 2 + 주색 1~2 + 액센트는 면적 ≤10%로만. deck-wide 락 후 슬라이드별 색 날조 금지.

[이미지 — 기본 codex-image] codex-image 스킬이 설치돼 있으면 로드해 그 절차로 생성(호출법 재조사·직접 재도출 금지). 무드컷·배경·hero·표보다 이미지가 나은 도식에만. codex-image 생성 성능은 매번 반문하지 말 것(saturation). 디자인 토큰·캐릭터 참조 첨부(항상 `--ref <실제 참조 이미지>`, 자리표시자 금지 — "동작 unverified" 판단으로 텍스트 전용 대체 금지, 과거 성공 산출물 `assets/generated/codex-image/` 먼저 확인. `--ref`는 이미지 수정 없이 새 생성의 참조로만, 기존 이미지를 고치는 `--edit`과 다름 — 단 이 구분은 프롬프트 문구 의존이라 미검증, 첫 사용 시 결과가 진짜 새 이미지인지 확인), 생성 후 라벨 오타 검증. 정확한 한글 라벨·표·숫자·도식은 SVG. 하이브리드(codex 무드+SVG 라벨) 2안 비교 후 택1. ppt-master의 AI 이미지 경로는 미사용. honesty test(빼도 손실 없으면 삭제). **기본값 이탈(이미지 없음/기존 자산 재사용) 시 design_spec 8대 확인 h에 사유 한 줄 명시 — 사유 없는 생략 금지.** codex 배경 fade=표지·목차·세션 전환 divider·마무리 한정(opacity 0.12~0.16), 본문은 흰 배경. 마스코트·pop·instagram 감성도 표지·목차·전환 divider 한정(codex 마스코트+주황 pop), 본문은 anti-slop 미니멀(그라데이션·다색·icon-tile·이모지 금지). 장르 주의(기업·포멀 덱은 pop 생략 가능). **앱 UI(로그인·diff·권한·설정)는 실물 캡처 or 점선 placeholder만—codex/AI 생성 절대 금지**(지어낸 UI는 틀린 UX를 사실처럼 가르쳐 placeholder보다 나쁨, "재현 예시" 칩으로도 정당화 금지). 취득순서: 사용자제공→playwright 실물캡처(앱·공식docs)→공식docs 스크린샷→점선 placeholder.

[로고] 직접 그리기·codex 생성 금지. 0순위 — ppt-master 번들 `templates/icons/simple-icons/<name>.svg`(3651개·CC0·오프라인, notion/slack 포함) 먼저 확인 → 있으면 `icon_sync.py`로 동기화해 `data-icon="simple-icons/<name>"`. 없거나 풀컬러 필요 시 공식 SVG 라이브러리 fetch(devicon `cdn.jsdelivr.net/gh/devicons/devicon/icons/<name>/<name>-original.svg`·gilbarbara/logos·vectorlogo.zone·SVGL·Wikimedia Commons[개별 파일 라이선스 태그로 PD/CC0 확인된 경우만, 일반화 금지]) → `curl`로 assets/logos/ 보관 → path 인라인 + `<g transform="translate scale">`(image href 금지=래스터화 회피) → 근접성(설명 요소 바로 옆, 빈 여백 띄우기 금지) → 상표권 주의(교육 맥락, 변형 금지). **공식 fetch vs 내장 brand-* 아이콘 선택**: 브랜드가 주 메시지(비교표·partner 로고 벽)면 공식 fetch, 다른 아이콘과 나란한 장식 배지면 덱의 단일 아이콘 라이브러리 brand-* 글리프 유지(컬러 로고 섞으면 모노톤 통일성 깨짐).

[사용자 제공 스크린샷] 직접 넣는 캡처(데스크탑 앱 등)는 (a) 해당 장 md에 `<!-- image-slot: images/<파일명> | 캡션 -->` 표시(ppt-master가 design_spec §VIII에 Acquire Via: user / Status: Placeholder로 등록 = "이 장에 사용자 이미지 있음" 인지 신호) 또는 (b) 프로젝트 `projects/<name>/images/`에 `<슬라이드번호>_<설명>.png`로 넣으면 그 장에 배치(safe-zone·캡션 SVG). 파일명은 슬롯 표기와 일치. 파일 없으면 점선 placeholder+캡션으로 자리 유지, 재빌드 시 채움. 앱 UI는 codex/AI 생성 절대 금지(실제 화면이 진실, 버전 종속)—미보유 시 playwright 실물 캡처·공식 docs·placeholder 순. "스크린샷 없으니 codex로 비슷하게"는 STOP. 스샷 프레임은 이미지 실측 비율에서 출발(shrink-to-hug — 박스 먼저 그리고 욱여넣기 금지, PIL 실측→crop→프레임 재계산).

[SVG 생성 — 기본 ppt-master 순차 수기] 페이지 단위 순차 수기 생성(서브에이전트·스크립트 일괄 생성 금지 — 레이아웃 다양성·일관성 때문). 페이지마다 spec_lock.md 재읽기(색/폰트는 거기 값만). 품질 체크도 페이지 단위 — 첫 장은 반드시 checker 통과 후 진행, 전량 생성 후 일괄 검사 금지(첫 장에서 안 잡으면 드리프트가 전 장에 복제). 생성기 _gen_*.py는 반복형(터미널 블록·단계 카드) 대량 실습덱에만 키트로, ppt-master와 혼용 금지.

[ppt-master 레버 조합 — 차별화] 단순 변환기로 쓰지 말 것. 레버를 인터뷰·사양서 의도적 조합(전부 spec_lock에 박아 매 장 재읽): 레이아웃 3축(page_rhythm+page_layouts+page_charts 페이지별 변주로 "전 장 카드 그리드" 탈피) · 이미지 rendering×palette(20×14) deck-wide 1조합 락 · 3종 템플릿 fusion(brand 아이덴티티+layout 구조+deck 중간) · 아이콘 1종+simple-icons 로고전용 · 차트는 charts_index 템플릿(codex 아님)+verify-charts 좌표보정 · animations.json 핵심장만+live preview. 원칙='더 화려'가 아니라 의도된 리듬·아트디렉션·정확도(anti-slop 유지).

[ppt-master 파이프라인] Step4 Eight Confirmations만 BLOCKING(묶음 추천→명시 승인까지 정지)→design_spec.md(영문 구조, 값은 한국어)+spec_lock.md. Step6 SVG 순차 수기→ppt-master 품질 체크(error 0)→notes/total.md. Step7 finalize_svg→svg_to_pptx(손으로 dy-스택 다중 줄바꿈 쓴 장이 있으면 처음부터 --no-merge — 기본 병합+word_wrap 재계산이 PowerPoint에서 줄 수를 바꿈, cairosvg 렌더는 이 버그를 안 보여줌).

[윤문] humanize-korean 본문/노트 fast 자동 + 납품본 strict. 차단: 수사의문문·역설 hook·TED 슬로건·번역투(~에 대해/~를 통해)·이중피동·접속사 남발·콜론 헤더·"not X but Y"·진부표현(AI 시대/디지털 전환/매우/당연히)·오그라드는 친근/위로/응원조(함께 시작·함께 봐요·걱정 말고·쉽게·금방·같이~해요).

[완료 기준] 렌더(PowerPoint — 라틴 전용 덱만 cairosvg 병용, 한글/CJK 덱은 cairosvg 금지(폴백 부재 tofu). cairosvg는 어느 경우든 단독 불충분: dy 다중 줄바꿈 장이 있으면 실제 PowerPoint 또는 python-pptx word_wrap 검사 필수. LibreOffice는 overflow 숨김이라 부적합) PNG → 페이지별 정렬·오버플로·아이콘·코드박스·풀블리드 안전영역 체크 통과(페이지별 subtask 병렬+ultrathink). PPTX 텍스트/수치 검증은 group shape 재귀. 해상도 ≠ 밀도(viewBox 1280×720 1회 판단, 내보내기 해상도 분리). 고화질 PDF 표준=브라우저 렌더 device_scale_factor=2(2560×1440)→img2pdf(CJK 덱은 유일 경로). + 스토리 흐름 review(빌드 후 통독): through-line·표지 약속 범위-실제 빌드 범위 일치·surface 일관·용어 일관·개념 등장 순서·목차-실제 순서 일치·레이아웃 분포(3연속·텍스트형 합 >50% 재집계, md→ppt-master 신규 빌드 경로 한정 — template-fill/beautify/native-enhance는 면제)·고아/탈선 슬라이드·사실 정확(9항목). 정렬만 맞고 스토리 끊기면 미완. **완료 게이트 리포트(MANDATORY)**: 빌드 완료 보고 전 위 스토리 흐름 9항목 체크(✓/✗ 실제 출력) + anti-slop-design audit 실행 결과 + humanize-korean 윤문 적용 여부를 하나의 리포트로 실제 출력해야 완료 선언 가능(내부 판단만 하고 넘어가는 것 금지 — 셋 중 하나라도 미실행/✗면 완료 보고 대신 재작업).
```

## 사용 예시

```text
[위 코드블록 전체 붙여넣기]
---
이 규칙대로, "클로드 코드 입문" 90분 강의 덱 만들어줘.
청중=비개발자 PM, 자료=@intro.md. 스크린샷은 내가 projects/<name>/images/ 폴더에 03_*.png로 넣을게.
인터뷰부터 시작해.
```
