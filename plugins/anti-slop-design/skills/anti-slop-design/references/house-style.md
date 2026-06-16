# house-style

기본 제안값(default suggestion)과 OSS 교차점검. 출처 substance: `docs/references/anti-slop-design-oss-synthesis.md` §5.

**원칙: 기본은 범용, house-style은 worked example / 기본 제안값.** 브리프나 브랜드 자료가 있으면 그것이 이긴다. house-style은 "자료가 없을 때의 합리적 출발점"이지 강제 규범이 아니다.

---

## 1. 기본 제안값 (enterprise 톤)

- **enterprise / calm but sharp** — 과장 없는 기술회사 신뢰감, 정보 전달 우선, low-noise/high-signal.
- **monochrome + 단일 accent** — grayscale base + accent 1색.
- **Pretendard** (한글 본문/제목).
- **no emoji** (코드·문서·UI 공통).
- **inline SVG diagram** — 아키텍처/플로우/data-viz.
- **dependency-free static** — HTML + CSS + vanilla JS, 외부 의존 없음.
- **print-CSS** (본문 >=10pt).
- **callout** — Note / Tip / Important / Caution / Warning.

OSS 보강(합의): 단일 restrained accent는 hallmark(accent <=~5% viewport)·huashu(<=3-4색)·frontend-slides("dominant color + sharp accent가 timid 균등 팔레트를 이긴다")·frontend-design("boldness는 한 곳에 spend")가 모두 지지. no emoji·dependency-free도 직접 합의.

---

## 2. 충돌 해소 (house-style이 banned 패턴에 근접하는 지점)

### blue/indigo accent <-> AI 팔레트
사용자 기본 accent(blue/indigo)는 repo들이 지목하는 바로 그 hue 대역이다(frontend-slides는 generic indigo `#6366f1`를 명시 ban, impeccable은 hue 260-310 flag, purple->blue gradient는 1순위 universal tell).

**해소:** slop은 **gradient**와 **무고민 기본값 indigo**이지, *평면 단일 committed* indigo가 아니다.
- house-style은 특정 committed indigo 토큰을 `oklch()`로 핀하고 **절대 gradient화하지 않는다**.
- 이 한 지점이 house-style이 banned 패턴에 가장 근접한 유일 지점 — 사용 시 "flat 단색 committed accent"임을 인라인으로 명시.

### inline SVG diagram <-> 손그림 SVG ban
huashu 최우선 ban은 **figurative/representational SVG**(사람·장면·제품)다. **diagram·icon·data-viz는 명시적 허용 집합.**

**해소:** SVG ban을 **figurative에만 스코프**한다. 아키텍처/플로우 다이어그램은 house-style 핵심 자산이므로 false-positive 내면 안 된다. 즉 "손그림 인물/제품 SVG" != "구조 다이어그램".

### Pretendard / callout
banned font 목록(Inter/Roboto/Geist/Space Grotesk 등 Latin face 대상)에 Pretendard 없음 — 한국어-우선 의도적 선택, 충돌 없음(어떤 repo도 Pretendard를 과용 폰트로 지목하지 않음, clean 처리). callout은 어떤 repo도 안 다룸 — slop corpus와 직교, 충돌 없음.

---

## 3. 적용 규칙

- 브랜드 자료 없을 때만 위 기본값을 출발점으로. 자료 있으면 brand-spec이 이긴다.
- accent는 `oklch()` 단일 committed 토큰, gradient 금지.
- SVG는 diagram/icon/data-viz만 — figurative 손그림 금지.
- 범용 산출이 목표면 house-style을 강제하지 말고 "기본 제안"으로만 제시한다.
