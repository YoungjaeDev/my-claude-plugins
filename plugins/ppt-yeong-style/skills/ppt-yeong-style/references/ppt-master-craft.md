# ppt-master 깊이 활용 — 조합으로 차별화 (§4 상세)

ppt-master는 "md → PPTX 변환기"가 아니라 **레이어드 디자인 엔진**이다. 대부분은 기본 경로만 써서 "그냥 잘 만든 PPT"에서 멈춘다. **"아무나 못 만드는" 덱은 엔진 안의 레버를 인터뷰·사양 단계에서 의도적으로 골라 조합할 때** 나온다. 이 문서는 그 레버 목록·조합 레시피·함정이다.

> 전제: 모든 레버는 ppt-master `spec_lock.md`(페이지마다 재읽기되는 실행 계약)에 박아야 executor가 일관 적용한다. 기억·즉흥 금지. 레버를 머리로만 정하고 spec_lock에 안 박으면 긴 덱에서 드리프트한다.
>
> **레버는 시그니처를 구현하는 수단이다.** 무엇을 어떤 값으로 락할지는 `design-language.md` §0의 "ppt-master lever lock"(rendering×palette 1조합·page_rhythm 불균등·type-scale ≥1.5·icon 1종·photo B&W+오버레이·pop honesty)을 따른다 — 레버 선택 자체가 시그니처 의도의 번역이다.
>
> **SOT 주의:** 정확한 필드·스크립트·워크플로명·옵션은 **ppt-master SKILL.md/references가 진실**(버전에 따라 달라질 수 있음). 이 문서는 "무엇을 골라 조합할지"(판단 레이어)만 담고 엔진 내부를 복제하지 않는다 — 이름은 hook으로만 쓰고, 동작 세부는 ppt-master에서 확인.

## 레버 8종 (무엇을·언제·yeong 적용)

> **덱 구조(mode)·비주얼 무드(visual_style)는 ppt-master의 "Eight Confirmations" 확인 항목 d 안의 두 레이어**(Layer 1 = mode, Layer 2 = visual_style)다 — 새 확인 단계가 아니라 기존 항목의 명세다. 둘 다 ppt-master 자체에 "이런 내용/청중이면 이 프리셋" 추천표가 내장돼 있어 매번 새로 설계할 필요는 없지만, yeong 시그니처는 그 표 어디에도 없어 명시 지정이 필요하다.
>
> **색 절차 관계:** yeong의 design-shotgun 색 후보 단계는 ppt-master 자체 색 확정 단계(confirmation e, 3후보+실시간 미리보기)를 대체하는 게 아니라 그 앞에 들어가는 **사전 브리핑**이다 — "이런 느낌(웜뉴트럴+액센트1개)으로 후보를 짜달라"는 입력으로 넘기고, 최종 확정은 confirmation e가 한다. 별도 중복 확정 라운드를 만들지 않는다.

| 레버 | 메커니즘 (ppt-master) | 언제 | yeong 적용 |
|------|----------------------|------|-----------|
| **mode(구조)** | Strategist 확인 d.Layer 1 — `pyramid`/`narrative`/`instructional`/`showcase`/`briefing` 중 자체 추천표로 선택, `spec_lock`에 `mode:` 기입 | 모든 덱 | 강의/실습 덱 → `instructional` 고정(ppt-master 자체 추천표와 일치, 판단 불필요). 제안 덱 → `narrative`/`pyramid` 중 인터뷰에서 판단(색 락과 동일 원칙 — 프로젝트마다 판단, 강제 고정 안 함). **콘텐츠가 여러 옵션을 비교해 1개로 확정하는 구조면 `pyramid` 우선**(SCQA 오프닝[Situation→Complication→Question→Answer]과 MECE 비교가 내장돼 있어 페이지 순서·비교 논리가 저절로 안정된다. ppt-master 자체 auto-selection표의 "Strategic decision/analysis/board/investor → pyramid"와 일치. 스토리가 서사 아치[기승전결]로 가는 제안이면 여전히 `narrative`) |
| **visual_style(무드)** | Strategist 확인 d.Layer 2 — 18개 기성 프리셋 또는 `custom`, `spec_lock`에 `visual_style:` + (`custom`이면) `visual_style_behavior:` 기입 | 모든 덱 | yeong 덱 전부 → `custom` 고정 + `design-language.md` §0 시그니처 요약 문단(고정 문구, 프로젝트마다 재작성 안 함 — 색 hex와 달리 "철학"이라 고정) |
| **레이아웃 3축** | `spec_lock`의 `page_rhythm`(anchor/dense/breathing) + `page_layouts`(per-page 템플릿 basename) + `page_charts`(차트 템플릿) | 모든 덱 | 페이지별로 의도적 변주 → "전 장 카드 그리드" 균일함 탈피. anchor=표지/전환, breathing=실습/개념 1개, dense=표/비교. **단, `page_layouts`+`page_charts`는 레이아웃이 그 차트의 호환 셸일 때만 같이 건다(ppt-master hard rule)** — 안 맞으면 그 장은 `page_layouts`에서 생략. 칸 채우려 충돌 레이아웃 강제 금지 |
| **이미지 rendering×palette** | 20 렌더링 × 14 팔레트 매트릭스(ppt-master Strategist 확인 항목) — `spec_lock`의 `image_rendering`/`image_palette`는 **ppt-master 자체 AI 이미지 생성 경로(`image_usage: ai`)를 쓸 때만** 락된다 | codex/AI 무드 이미지 쓰는 덱 | yeong은 이미지를 codex-image(외부, `image_usage: provided`)로 채우므로 이 spec_lock 필드가 안 걸릴 수 있다 — **"ppt-master가 자동으로 지키는 락"이 아니라 "codex-image 프롬프트에 넣을 어휘집"**으로 취급(화풍·색조합 이름을 프롬프트 문구로 번역). **deck-wide 1조합**은 여전히 유지 — 강의=editorial·sketch-notes·warm-scene + warm-earth·mono-ink 류 |
| **3종 템플릿 fusion** | brand + layout + deck 템플릿 fusion (경로·규칙은 ppt-master SKILL.md) | 검증된 구조/브랜드 재사용 | brand=yeong 색·로고·아이덴티티, layout=검증 구조, deck=중간 페이지. 같은 종 2개 충돌은 해소 프롬프트 |
| **아이콘 라이브러리** | `chunk-filled`/`tabler-filled`/`tabler-outline`/`phosphor-duotone` 중 **택1** + `simple-icons`(브랜드 로고 전용) — ppt-master 아이콘 확인 항목 | 모든 덱 | 스타일 1종 deck-wide 고정(fill만, stroke 금지는 §icons-logos). 톤: chunk=tech·각짐, phosphor=부드러움 |
| **검증 차트 + verify-charts** | `templates/charts/charts_index.json`(bar/line/pyramid/funnel/timeline/matrix/kpi 등) + `verify-charts` 워크플로(좌표 10~50px 보정) | 데이터·도식 정확도 필요 | 표·도식을 codex 무드가 아니라 **편집가능 SVG 차트 템플릿**으로. 숫자·라벨 정확. 빌드 후 verify-charts로 좌표 보정 |
| **애니메이션 + live preview** | 애니메이션 config(animations.json) + live preview 서버 — 정확한 명령·포트는 ppt-master SKILL.md | 발표용·핵심 장 강조 | 자동 매핑 위에 **핵심 장만** 등장 애니메이션 수동 튜닝. live preview로 생성 중 실시간 확인·주석 |

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
- **도메인 특화 레이아웃 템플릿(`templates/layouts/` 7종)은 기본 미사용.** academic_defense/ai_ops/government_blue·red/medical_university/pixel_retro/psychology_attachment는 중국 관공서·의료·학술 시장 특화라 yeong 장르(한국어 비즈니스·기술 강의/제안)와 안 맞는다. 사용자가 명시 요청할 때만 검토.
- **개별 장 이미지+텍스트 배치가 막히면** ppt-master의 `references/image-layout-patterns.md`(50+ 배치 패턴 어휘집)에서 고른다 — 매번 좌/우·상/하·풀블리드 3가지로 회귀하지 않기 위한 재료 창고.
- **엔진 내부 파일명·문서 체계는 설치본(버전)에 따라 다르다.** 실측: 한 설치본은 executor 문서가 `executor-general.md`(확장 레이아웃 표 포함), 다른 설치본은 `executor-base.md`(`page_layouts` 템플릿 상속 체계)였다. 레버를 조합하기 전에 **설치된 ppt-master의 SKILL.md/references 현재 트리를 직접 확인**하고, 이 스킬 문서에는 엔진 파일명·표 이름을 계약처럼 박지 않는다(위 SOT 주의와 같은 원리).
- **회사 템플릿을 반복 재사용**하려면 ppt-master의 `create-template`/`create-brand` 워크플로로 한 번 등록해두면 이후 "3종 fusion"의 재료로 계속 쓸 수 있다(매번 처음부터 다시 만들지 않아도 됨).
