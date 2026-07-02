# 이미지 — codex-image vs SVG, fade·pop, 스크린샷 (§5 + §5b)

경계가 핵심이다: **무드는 codex-image, 정확한 라벨·표·숫자는 SVG.** pop/마스코트는 표지·전환에만.

## §5. codex-image vs ppt-master SVG

- **codex-image**(기본 이미지 경로, ppt-master 밖 별도 도구): 사진·무드컷·배경(흐림/바램)·전략적 hero·표보다 이미지가 나은 도식. 한/영 레터링 품질 양호 — **생성 성능을 매번 반문하지 말 것**(saturation). 톤 통일을 명시(디자인 토큰 hex + 캐릭터 참조 이미지 첨부)하고, 생성 후 라벨 오타를 검증. ppt-master의 AI 이미지 생성 경로(Step 5 ai)는 **기본 사용 안 함** — 이미지는 codex-image로 채운다.
- **ppt-master SVG**: 정확한 한국어 라벨·구조·표·숫자·타임라인. 텍스트 정확·수정 가능.
- **하이브리드**: 무드 배경(codex) + 라벨 오버레이(SVG). 도식 2안(풀 codex vs 하이브리드)을 렌더 후 사용자 선택.
- **기본값(codex-image) 이탈 시 사유 명시**: 이미지 없음(SVG 전용)이나 기존 자산 재사용으로 갈 경우, `design_spec.md` 8대 확인 항목 h에 **왜 기본 codex-image 경로를 타지 않는지 한 줄 사유**를 남긴다(예: "이 장은 표·숫자 정확도가 핵심이라 이미지 불필요", "이전 세션에서 이미 승인된 텍스처 재사용"). 사유 없이 그냥 생략하는 것은 금지.

> codex-image 미설치 시: 무드 배경은 생략하거나 단색/그라데이션 SVG 배경으로 degrade. 라벨·표는 그대로 SVG.

## codex 배경 fade 범위

- **표지·섹션 전환 divider·마무리 한정.** 텍스트 가독성 위해 **opacity 0.12~0.16**으로 옅게 바램(저채도·흰 오버레이).
- **본문 슬라이드 배경은 흰색 유지**(배경 미적용, 부득이하면 ≤0.16 극히 옅게).
- 참조 풀: **브랜드/캐릭터 참조 이미지 폴더**(예: `assets/<brand>/`)를 codex-image 프롬프트에 캐릭터·톤 참조로 첨부, 디자인 토큰(예: 주황 `#D97757`·오프화이트) 준수.

## 마스코트·pop·instagram 감성

- **표지·목차·세션 전환 divider에 적극.** codex 생성 마스코트(브랜드 픽셀 캐릭터 참조) + 밝은 pop 무드(주황 포인트).
- 목차 = 섹션 리스트 + 마스코트. 부 전환 divider = 큰 부 제목 + 마스코트 + pop 배경.
- codex-image 호출 시 항상 `-i <실제 참조 이미지>` 첨부(자리표시자 경로 금지). **"-i 첨부는 동작 unverified"라는 판단으로 텍스트 전용 프롬프트로 대체하지 말 것** — 이 저장소·프로젝트의 과거 codex exec 로그·산출물(`assets/generated/codex-image/`)에 `-i` 성공 선례가 있는지 먼저 확인하고, 확인 없이 unverified로 단정해 규칙을 우회하지 않는다(실측: 재확인 없이 우회했다가 캐릭터 없는 추상 이미지만 나와 재생성한 사례).

## anti-slop ↔ pop 경계 (명문화)

- pop/마스코트/instagram 감성은 **표지·목차·전환 divider에서만.**
- 본문은 **anti-slop 기본** — 그라데이션 텍스트·다색 텍스트·icon-tile 균일그리드·이모지 금지, chrome 효과 남용 금지. "pop"은 사진 fade의 무드로만 표현.
- **장르 주의**: 기업·포멀 덱은 pop/마스코트 생략 가능, 강의·캐주얼 덱에서 권장.
- **pop = 감정신호 (honesty test, 톤 버전)**: pop/마스코트/액센트 블록·버스트는 **위계 정점(표지·전환 divider·큰 숫자 1개)에만 격리**하고, 그 자리에서 **감정·내러티브 신호를 실어야** 한다(시그니처의 "one committed loud moment per page"). **톤 정보가 없으면 — 즉 빼도 의미·감정 손실이 없으면 — slop이므로 삭제.** 장식으로서의 pop은 금지. 한 장에 pop 하나(요소마다 금지). 같은 이미지 반복 금지(title/closing 로고 제외).
- **사진 처리(시그니처)**: 사진은 장식이 아니라 에디토리얼 소재 — **B&W/저채도 = 권위, 통제된 컬러 = 즉시성.** 단일 액센트 오버레이·옅은 그레인, 과감한 의도적 크롭, 타입이 사진 위로 침범. glossy 스톡 톤 금지. (상위 계약 → `design-language.md` 6축.)
- 강의 PDF 등 외부 이미지는 **참고만(구조·아이디어)** → 우리 스타일로 재제작. 원문 복붙 금지.

## §5b. 사용자 제공 스크린샷/이미지 배치

직접 넣는 스크린샷·캡처(예: 데스크탑 앱 화면)는 **두 방식으로 약속**한다. ppt-master의 `Acquire Via: user` / `Status: Placeholder` 메커니즘에 얹는다.

1. **슬라이드 단위 지정** — 해당 장 md에 슬롯 표시:
   ```markdown
   <!-- visual: user-image -->
   <!-- image-slot: images/03_app_screen.png | 앱 설정 화면 -->
   ```
   ppt-master Strategist가 이 행을 design_spec §VIII Image Resource List에 `Acquire Via: user` / `Status: Placeholder`로 등록.
2. **폴더 약속** — 파일은 ppt-master 프로젝트 폴더 **`projects/<프로젝트명>/images/`**에 약속 파일명(`<슬라이드번호>_<설명>.png`)으로. 프로젝트 생성 전이면 작업 폴더에 두고 `import-sources`로 흡수.

> 정리: **md의 `image-slot`이 "이 장에 사용자 이미지가 있다"는 인지 신호**(→ design_spec §VIII 등록), 실제 파일은 `projects/<name>/images/`에서 가져온다. 파일명은 슬롯 표기와 일치시킬 것.

**규칙:**
- 파일 있으면 → 해당 장에 배치(safe-zone overlay·풀블리드 규칙 적용, 캡션은 SVG 텍스트로).
- 파일 없으면 → **점선 placeholder 박스 + 캡션으로 자리 유지**(슬롭 아님, 의도적 placeholder). Step 7 image readiness gate가 누락 파일명을 안내, 채운 뒤 재빌드.
- **앱 UI(로그인·diff·권한·설정·세션 등)는 실물 캡처 또는 점선 placeholder만 — codex/AI 생성 절대 금지.** 실제 화면이 진실이고 버전 종속이라, 지어낸 UI는 **틀린 UX를 사실처럼 가르쳐 placeholder보다 나쁘다**(실측: codex가 존재하지 않는 로그인·diff 화면을 진짜처럼 그려낸 사례 — 버튼 배치·라벨이 실제와 다름). "재현 예시" 칩으로도 정당화 금지 — 청중은 칩을 안 읽고 화면을 진짜로 받아들인다.
- **취득 순서**: ① 사용자 제공(`projects/<name>/images/`) → ② playwright로 실제 앱·공식 docs **실물 캡처** → ③ 공식 docs 스크린샷 인용 → ④ 그래도 없으면 **점선 placeholder + 캡션**으로 자리 유지(재빌드 시 채움). 이미지 검색 전용 MCP는 없음 — 실물은 playwright·공식 docs가 정답.
- 실물 캡처는 캡션 없이 임베드(진실). **STOP 신호**: "스크린샷이 없으니 codex로 비슷하게 만들자"는 생각이 들면 멈추고 ②~④로.
