# ppt-master 파이프라인 · 윤문 · 완료 QA · 실사용 주의 (§6~§8 + 주의)

ppt-master는 **빌드 엔진**이다(이 스킬은 그 위 작성 규약). 아래는 엔진을 돌릴 때 yeong이 지키는 부분 + 윤문·완료 기준 + 실사용 판단.

## §6. ppt-master 7-step (직접 확인 — 위에서 돌릴 때 지킬 것)

엄격한 **직렬 7-step**. 핵심만:

- **Step 4 Strategist = Eight Confirmations (⛔ BLOCKING)** — canvas/장수/청중/스타일/색/아이콘/타이포/이미지 8개를 묶음 추천 후 **명시 승인까지 정지**. 승인 후 design_spec.md(서술) + spec_lock.md(실행 계약) 생성, 이후 단계는 자동 진행.
- **Step 6 Executor (HARD rules):**
  - SVG는 **메인 에이전트가 페이지 단위 순차 수기 생성.** 서브에이전트 위임 금지. 5장씩 배치 금지. **스크립트 일괄 생성 금지.**
  - 페이지마다 `spec_lock.md` 재읽기 — 색/폰트/아이콘은 거기 값만(기억·즉흥 금지). per-page `page_rhythm`(anchor/dense/breathing) 조회.
  - `svg_quality_checker.py` 통과(error 0) 후 진행. notes/total.md 생성.
- **Step 7:** `finalize_svg.py` → `svg_to_pptx.py`(애니메이션 기본 포함). `cp`로 finalize 대체 금지.
- design_spec.md는 영문 템플릿 구조(I~XI 섹션) 유지, 내용 값만 한국어.

> 명시하지 않은 세부(canvas init·source 변환·template·executor 스타일 등)는 **ppt-master SKILL.md 그대로** 따른다. python 스크립트는 **`uv run`으로 실행.**

## §7. 윤문

- **humanize-korean** — 본문/노트 **fast 자동** + 납품본 **strict**. (anti-slop = 영문 slop·디자인 감사 / humanize-korean = 한국어 재작성 — 분업.)
- 차단: 수사의문문·역설 hook·TED 슬로건·번역투(~에 대해/~를 통해)·이중피동·접속사 남발·콜론 헤더·"not X but Y"·진부표현(AI 시대/디지털 전환/매우/당연히)·**오그라드는 친근/위로/응원조**(함께 시작·함께 봐요·걱정 말고·쉽게·금방·같이 ~해요·딱 ~만 알면). 강의 교안은 담백·사실 우선(§3 원칙 13).
- humanize-korean 미설치 시: 위 차단 목록을 체크리스트로 직접 적용.

## §8. 완료 기준 / Visual QA

- **렌더 기반 QA가 완료 기준.** PPT→PNG export 후 페이지별로 정렬·오버플로·아이콘(fill만, stroke 금지)·코드박스·풀블리드 안전영역 체크. yeong 실제 패턴: 페이지별 subtask 병렬 + ultrathink 검토(상사 보고용은 엄격도 ↑).
- 진실 기준 = **PowerPoint/cairosvg.** LibreOffice는 overflow를 숨겨 부적합. PPTX 텍스트/수치 검증은 group shape **재귀.**
- 표지는 finalize 후 `svg_final`로 별도 확인(cairosvg는 외부 상대경로 이미지 미로드).
- **고화질 PDF 납품**: cairo 부재 환경은 브라우저 렌더 `device_scale_factor=2`(2560×1440 PNG) → img2pdf 경로. 화면 검토는 1280px 축소본으로(읽기 도구 한도).

## §8b. 스토리 흐름 review (빌드 후 — 페이지별 QA와 별개)

페이지별 Visual QA가 "각 장이 깨끗한가"라면, 스토리 review는 **"덱 전체가 한 줄기로 이어지는가"**를 본다. export 전(또는 직후) PDF/렌더를 **처음부터 끝까지 통독**하며 점검:

- **through-line**: 표지의 한 문장 약속이 끝까지 일관되게 증명되는가. 끊기거나 갑자기 튀는 장 없는가.
- **surface 일관성**(원칙 14): 명령·스크린샷이 한 주 surface(CLI/Desktop/웹)로 일관되는가. "데스크톱으로 시작"인데 CLI 명령이 섞이지 않는가.
- **용어 일관성**: 같은 개념을 다른 말로 부르지 않는가(예: 채팅 AI vs 에이전틱 AI 표현 통일).
- **개념 등장 순서·의존**: 뒤에서 쓰는 개념을 앞에서 정의했는가. 선후 역전 없는가.
- **고아·탈선 슬라이드**(원칙 15): 본 흐름과 무관한 곁가지·경쟁 도구가 본류에 끼지 않았는가.
- **사실 정확성**(원칙 4): 명령·UI·기능 주장이 claude-code-guide·공식 docs와 맞는가. 미확인은 `unverified` 표기·재확인.

발견 시 → deck.md 소스 수정 후 해당 장만 재빌드. 이 review는 **렌더 QA 통과만으로 완료로 보지 않는다**(정렬은 맞아도 스토리가 끊기면 미완).

## 주의 / 미해결 (실사용 시 판단)

- **SVG 생성 경로(결정)**: 기본 = **ppt-master 순차 수기**(레이아웃 다양성·페이지 간 일관성·anti-slop에 유리 — 생성기는 균일 레이아웃을 양산해 "일관성 과다" 불만과 충돌). 생성기 `_gen_*.py`는 **반복 구조(터미널 블록·단계 카드)가 명백하고 장수 많은 실습덱에만** 키트로 한정. ppt-master와 혼용 금지(덱 내 택1). 생성기 쓸 땐 레이아웃 균일화 위험을 별도로 의식.
- **이미지 경로(결정)**: 기본 = codex-image(무드컷·배경·hero). 정확한 라벨·표·도식은 SVG. ppt-master `image_gen.py`는 기본 미사용. (상세 → `images-and-pop.md`.)
- **용어·도구명 정확성(출처 근거)**: 도구·브랜드명은 전사·출처에서 **실제 언급된 것만**, 추측 금지(예: 전사 미언급 용어는 본문 신중·부록 제외). **강사 자작 스킬 vs 일반 개념을 구분**해 표기.
- **OS 병기 터미널 블록 = 좌우 대칭 높이 기계 적용 금지**: 병기(Win/Mac) 시 명령 줄수가 다르면 블록 높이를 내용에 맞춰 가변 처리(또는 양쪽 줄수 의도적 맞춤). "병기 = 좌우 동일 높이"를 기계적으로 강제하면 짧은 쪽 하단 여백이 뜬다.
- **brand 팔레트** 프로젝트 전용 색은 repo 한정 격리, 전역화 금지(→ `color-typography.md`).
