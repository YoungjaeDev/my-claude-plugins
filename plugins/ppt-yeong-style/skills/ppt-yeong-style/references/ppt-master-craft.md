# ppt-master 깊이 활용 — 조합으로 차별화 (§4 상세)

ppt-master는 "md → PPTX 변환기"가 아니라 **레이어드 디자인 엔진**이다. 대부분은 기본 경로만 써서 "그냥 잘 만든 PPT"에서 멈춘다. **"아무나 못 만드는" 덱은 엔진 안의 레버를 인터뷰·사양 단계에서 의도적으로 골라 조합할 때** 나온다. 이 문서는 그 레버 목록·조합 레시피·함정이다.

> 전제: 모든 레버는 ppt-master `spec_lock.md`(페이지마다 재읽기되는 실행 계약)에 박아야 executor가 일관 적용한다. 기억·즉흥 금지. 레버를 머리로만 정하고 spec_lock에 안 박으면 긴 덱에서 드리프트한다.

## 레버 6종 (무엇을·언제·yeong 적용)

| 레버 | 메커니즘 (ppt-master) | 언제 | yeong 적용 |
|------|----------------------|------|-----------|
| **레이아웃 3축** | `spec_lock` 의 `page_rhythm`(anchor/dense/breathing) + `page_layouts`(per-page 템플릿 basename) + `page_charts`(차트 템플릿) | 모든 덱 | 페이지별로 셋을 **다르게** 조합해 "전 장 카드 그리드" 균일함 탈피. anchor=표지/전환, breathing=실습/개념 1개, dense=표/비교 |
| **이미지 rendering×palette** | Strategist 8번째 확인 — 20 렌더링 × 14 팔레트 매트릭스, design_spec §III.h + spec_lock `image_rendering`/`image_palette` | codex/AI 무드 이미지 쓰는 덱 | **deck-wide 1조합 락** 후 per-image type만 조절 → 아트디렉션 일관. 강의=editorial·sketch-notes·warm-scene + warm-earth·mono-ink 류 |
| **3종 템플릿 fusion** | Step 3 Template_Dispatcher — `templates/brands/` + `templates/layouts/` + `templates/decks/` 경로 명시(fusion 규칙) | 검증된 구조/브랜드 재사용 | brand=yeong 색·로고·아이덴티티, layout=검증 구조, deck=중간 페이지. 같은 종 2개 충돌은 해소 프롬프트 |
| **아이콘 라이브러리** | Strategist 6번째 — `chunk-filled`/`tabler-filled`/`tabler-outline`/`phosphor-duotone` 중 **택1** + `simple-icons`(브랜드 로고 전용) | 모든 덱 | 스타일 1종 deck-wide 고정(fill만, stroke 금지는 §icons-logos). 톤: chunk=tech·각짐, phosphor=부드러움 |
| **검증 차트 + verify-charts** | `templates/charts/charts_index.json`(bar/line/pyramid/funnel/timeline/matrix/kpi 등) + `verify-charts` 워크플로(좌표 10~50px 보정) | 데이터·도식 정확도 필요 | 표·도식을 codex 무드가 아니라 **편집가능 SVG 차트 템플릿**으로. 숫자·라벨 정확. 빌드 후 verify-charts로 좌표 보정 |
| **애니메이션 + live preview** | `animation_config.py scaffold`(animations.json) + svg_editor `server.py --live`(localhost:5050) | 발표용·핵심 장 강조 | 자동 매핑 위에 **핵심 장만** 등장 애니메이션 수동 튜닝. live preview로 생성 중 실시간 확인·주석 |

## 차별화 조합 레시피 (구체)

ppt-master 기본값만 쓰면 안 나오는 결과를 만드는 조합. 모두 anti-slop·역할 기반 색을 깬다는 게 아니라, **그 안에서 의도된 리듬·아트디렉션·정확도**를 더한다.

- **리듬 변주 덱** — 전 장 같은 레이아웃(슬롭 신호)을 피한다: `page_rhythm`을 anchor→breathing→dense→breathing로 의도적으로 출렁이게 + `page_layouts`로 개념장/실습장/표장에 다른 템플릿. 한 덱 안에서 "장마다 호흡이 다른" 인상.
- **일관 아트디렉션 덱** — 표지·전환의 codex 무드를 deck-wide `image_rendering`+`image_palette` **1조합**으로 락(예: sketch-notes + warm-earth). 모든 무드컷이 한 손에서 나온 듯. 본문은 흰 배경 유지(fade는 표지·전환만).
- **검증 구조 + yeong 톤** — `templates/layouts/<검증된 구조>` + `templates/brands/<yeong 색>` fusion. 남이 만든 탄탄한 골격에 우리 색·로고·voice만 덮어 빠르고 일관되게.
- **정확한 데이터 덱** — KPI·추세·비교를 codex가 아니라 `charts_index.json` 템플릿(kpi_cards·line_chart·comparison_table)으로 + verify-charts. 숫자가 픽셀 단위로 맞는 "컨설팅급" 정확도.

## 정확도·충실도 레버 (ppt-master만 되는 것)

기본 경로에 이미 들어있지만 의식하면 품질이 갈리는 것:

- **finalize_svg → DrawingML 충실도**: 아이콘 `<use>` 플레이스홀더·둥근사각 `rx`·마커 화살표·이미지 clipPath를 **래스터화 없이** PPTX 네이티브로 보존 → 벡터 선명. `cp`로 finalize 대체 금지(원칙 깨짐).
- **EMF/WMF 벡터 보존**: DOCX/PPTX 소스의 벡터 자산을 PPTX 네이티브 미디어로 임베드(0 래스터 손실). 소스가 오피스 문서면 이 경로가 살아있는지 확인.
- **spec_lock 페이지별 재읽기**: 긴 덱에서 컨텍스트 압축으로 색·폰트가 드리프트하는 걸 막는 핵심. 레버를 정했으면 **반드시 spec_lock에 박아** executor가 매 장 재읽게 한다.
- **paragraph merge**: dy-스택 텍스트가 PowerPoint에서 편집가능한 단일 프레임으로 합쳐짐 → 납품 후 고객이 직접 고치기 쉬움.

## 함정

- **레버 ≠ 화려함.** 다축 조합은 "효과를 더 넣자"가 아니다. honesty test(빼도 손실 없으면 슬롭)·anti-slop·역할 색 락은 그대로. 레버는 *의도된* 다양성·정확도에만.
- **균일화 위험**: 생성기 `_gen_*.py`는 균일 레이아웃을 양산한다 — 반복 구조 대량 실습덱에만, ppt-master 순차 수기와 혼용 금지(§ppt-master-and-qa 주의). 레이아웃 다양성은 `page_layouts` 변주로, 생성기로가 아니다.
- **매트릭스 과조합**: rendering×palette는 deck-wide 1조합 락이 원칙. 장마다 다른 조합 = 아트디렉션 붕괴(슬롭).
- **fusion 충돌**: 같은 종 템플릿 2개(brand 2개 등)는 자동 병합 말고 해소 프롬프트로 택1.
- **레버는 spec_lock에.** 인터뷰·머리로만 정하면 executor가 모른다. 모든 선택은 design_spec(서술) + spec_lock(실행 계약)에 기록.
