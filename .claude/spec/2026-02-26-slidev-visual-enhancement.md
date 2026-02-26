# Feature Specification: Slidev Plugin Visual Enhancement

## Overview

plugins/slidev의 생성 품질을 개선한다. 현재 구조적으로는 잘 잡혀있지만 시각적으로 밋밋한 슬라이드가 생성되는 문제를 해결하기 위해, 실제 KubeCon/JSConf 수준 발표자료의 시각 패턴을 SKILL.md 생성 로직과 references에 반영한다.

### Evidence Sources

분석된 7개 레포의 패턴을 기반으로 한다:
- **slidevjs/themes** (공식 5개 테마): 레이아웃 구조, CSS 변수, layoutHelper 패턴
- **nekomeowww/talks KubeCon HK 2024**: glassmorphism 카드, glow background, $clicks 애니메이션, attributify 모드
- **BaizeAI/talks KubeCon HK 2025**: 동일 저자의 진화된 패턴, 색상 시맨틱 카드 시스템
- **slidev-theme-geist**: Vercel 디자인 시스템, 8단계 accent scale, 디자인 토큰
- **2022-jsconf-presentation**: 코드 중심 발표, line highlighting step-through, maxHeight
- **dev-environment-as-code**: academic 테마, figure 레이아웃, footnote 컴포넌트
- **git-most-wanted**: 최소 스타일 교육용 발표, 일관된 슬라이드 템플릿

상세 분석: `.omc/research/analysis-*.md` (7개 파일, 총 3,600줄+)

## Requirements

### Must Have (P0)

#### SKILL.md 생성 로직 개선

- [ ] **Headmatter 기본값 보강**
  - `mdc: true` (MDC 문법 활성화)
  - `transition: fade-out` (기본 전환 효과 -- blur 포함 cross-fade. slide-left 대신)
  - `drawings.persist: false`
  - `css: unocss` (Rich 레벨에서)
  - `colorSchema: dark` (Rich 레벨 기본. Minimal은 테마 기본값)
  - `preload: false` (15+ 슬라이드 발표에서)
  - 커버 슬라이드 `class: text-center`
  - 일반 슬라이드 `class: py-10` (가장 흔한 패턴)

- [ ] **아이콘 시스템 도입**
  - 기술 발표: `<div i-logos:xxx />` (기술 로고) + `<div i-carbon:xxx />` (UI 아이콘)
  - 비즈니스/일반: `<div i-carbon:xxx />` / `<mdi-xxx />` (불릿 아이콘만)
  - 인터뷰에서 코드/프레임워크 정보를 기반으로 자동 판단
  - 아이콘 패키지 설치 안내:
    ```bash
    npm add -D @iconify-json/carbon @iconify-json/logos @iconify-json/mdi
    ```
  - 아이콘 사이즈 패턴 (실제 KubeCon 발표 기준):
    - 인라인 텍스트: `text-sm mr-1` (header bar 내)
    - 중간 로고: `text-3xl mr-3`
    - 대형 카드 아이콘: `h-20 w-20`
    - 히어로 아이콘: `text-[96px]` 또는 `class="text-8xl"`
  - 인라인 아이콘 정렬: `inline-block mr-1 translate-y-0.8`

- [ ] **UnoCSS 활용 강화**
  - **Minimal**: 표준 `class=""` 문법 + 기본 유틸리티
  - **Rich**: attributify 모드 (`<div flex items-center gap-4>` -- class 없이)
    - `css: unocss` headmatter 필수
    - UnoCSS config에서 `presetAttributify()` 필요
  - 슬라이드별 `class` frontmatter 활용:
    - `class: py-10` (가장 흔함, 18/28 슬라이드에서 사용)
    - `class: py-4` (코드 많은 슬라이드)
    - `class: px-24` / `class: px-35` (intro 레이아웃)
    - `class: text-center` (센터 레이아웃 보조)

- [ ] **Glassmorphism 카드 패턴 (Core)**
  카드 패턴은 Rich 프레젠테이션의 핵심 시각 요소. 모든 콘텐츠 슬라이드에서 사용.

  **기본 카드 공식** (BaizeAI/nekomeowww 패턴):
  ```html
  <div border="2 solid {color}-800" bg="{color}-800/20" rounded-lg overflow-hidden>
    <div bg="{color}-800/40" px-4 py-2 flex items-center>
      <div i-carbon:xxx text-{color}-300 text-xl mr-2 />
      <span font-bold>Card Title</span>
    </div>
    <div px-4 py-3>
      <!-- Content -->
    </div>
  </div>
  ```

  **색상 시맨틱 시스템**:
  | 색상 | 의미 | 사용 맥락 |
  |------|------|-----------|
  | `white` | 중립/정보 | 일반 정보 카드 |
  | `red` | 문제/경고/기존 방식 | Before, 단점, 리스크 |
  | `green` | 해결/이점 | After, 장점, 솔루션 |
  | `blue` | 기술/아키텍처 | 시스템 구조, 기술 상세 |
  | `purple` | 코드/컴파일러 | 코드 관련 토픽 |
  | `yellow` | 주의/"현실" | 주의사항, 트레이드오프 |
  | `cyan` | 컨테이너/인프라 | Docker, 클라우드 |
  | `sky` | 클라우드/쿠버네티스 | Kubernetes, 클라우드 서비스 |
  | `indigo` | 고급 기능 | Advanced features |

  **Glassmorphism 효과** (dark mode에서):
  ```html
  <div border="2 solid white/5" rounded-lg overflow-hidden bg="white/5" backdrop-blur-sm>
  ```

- [ ] **Scoped CSS 패턴 도입**
  - 커버 슬라이드 h1 gradient text (테마 컬러 기반, AI 클리셰 색상 금지)
  - footnote 스타일링:
    ```css
    .footnotes-sep { display: none; }
    .footnotes > .footnotes-list {
      margin-top: 12px;
      opacity: 0.9;
      font-size: 12px;
    }
    ```
  - v-click hidden 요소 blur 효과:
    ```css
    .slidev-vclick-target {
      transition: opacity 500ms ease, filter 200ms ease, color 300ms ease;
    }
    .slidev-vclick-hidden {
      opacity: 0;
      pointer-events: none;
      filter: blur(3px);
    }
    ```
  - 코드 블록 glassmorphism:
    ```css
    :root {
      --slidev-code-padding: 8px 10px;
      --slidev-code-background: #16161690 !important;
    }
    .slidev-code {
      backdrop-filter: blur(10px);
      border: 1px solid #eee1;
    }
    ```
  - Dark mode 배경 강제 (glow 배경 필수):
    ```css
    .dark #slide-content {
      background-color: black !important;
    }
    ```
  - v-mark 스케일 보정:
    ```css
    .rough-annotation > path[stroke-width='2'] {
      stroke-width: calc(2px * var(--slidev-slide-scale));
    }
    ```

- [ ] **슬라이드별 전환 효과 다양화**
  - 기본: `transition: fade-out` (blur 포함 cross-fade, KubeCon 표준)
  - fade-out 커스텀 CSS (Rich 레벨):
    ```css
    .fade-out-leave-active {
      transition: opacity calc(var(--slidev-transition-duration) * 0.6) ease-out, filter 200ms ease;
    }
    .fade-out-enter-active {
      transition: opacity calc(var(--slidev-transition-duration) * 0.8) ease-in, filter 200ms ease;
      transition-delay: calc(var(--slidev-transition-duration) * 0.6);
    }
    .fade-out-enter-from, .fade-out-leave-to {
      opacity: 0;
      filter: blur(5px);
    }
    ```
  - 슬라이드별 오버라이드: `transition: 'none'` (복잡한 애니메이션 슬라이드에서)

- [ ] **v-click/v-mark 적극 활용**
  - **Minimal**:
    - 불릿 리스트에 `<v-clicks>` 기본 적용
    - `v-click` directive로 단순 순차 공개
    - click markers `[click]`를 presenter notes에 기본 포함
  - **Rich**:
    - 위 모든 항목 +
    - `$clicks` 조건부 클래스 바인딩 (카드/요소 입장 애니메이션):
      ```html
      <div
        v-click flex flex-col gap-2 items-center transition duration-500 ease-in-out
        :class="$clicks < 1 ? 'translate-x--20 opacity-0' : 'translate-x-0 opacity-100'"
      >
      ```
    - 방향별 트랜스폼:
      - 좌 → 우: `translate-x--20` → `translate-x-0`
      - 우 → 좌: `translate-x-20` → `translate-x-0`
      - 위 → 아래: `translate-y--20` → `translate-y-0`
      - 아래 → 위: `translate-y-20` → `translate-y-0`
      - 스케일: `scale-80 opacity-0` → `scale-100 opacity-100`
    - `v-clicks depth="2"` -- 중첩 리스트 애니메이션
    - `v-after` -- 이전 v-click과 동시에 등장
    - `v-mark` 하이라이트:
      ```html
      <span v-mark="{ at: 2, color: 'rgb(144, 200, 255)', type: 'underline' }">keyword</span>
      ```
    - v-motion 입장 효과:
      ```html
      <div v-motion :initial="{ opacity: 0, y: 50 }" :enter="{ opacity: 1, y: 0, transition: { delay: 200 } }">
      ```
    - 순차 딜레이 (`v-for` + computed v-click):
      ```html
      <div v-for="(item, idx) in items" v-click="2 + idx"
        :class="$clicks < (2 + idx) ? 'opacity-0 translate-x--10' : 'opacity-100 translate-x-0'"
        transition duration-300 ease-in-out>
      ```

- [ ] **Global Layer 생성**
  - **Minimal**: `global-bottom.vue` -- 페이지 번호 + 작성자명 + 날짜
    - 커버/엔드 슬라이드에서 숨기기 (`$nav.currentPage > 1`)
  - **Rich**: 위 + Glow Polygon 배경 시스템
    - seeded random gradient polygons (3겹: blue, magenta, pastel)
    - 슬라이드별 시드 제어: `glowSeed: 228` frontmatter
    - 분포 제어: `glow: bottom` / `glow: right` frontmatter
    - blur 70px + hue-rotate per slide
    - 2.5s ease 전환 (슬라이드 간 부드러운 변화)
    - 참조: `.omc/research/analysis-nekomeowww-kubecon.md` Section 8

- [ ] **인터뷰 Phase 3 확장**
  - "시각적 수준" 선택 추가: Minimal / Rich

  **Minimal 포함 항목:**
  - 아이콘 (carbon/mdi)
  - `transition: fade-out`
  - `<v-clicks>` 불릿 래핑
  - 기본 v-click 순차 공개
  - `class: py-10` per-slide 패딩
  - global-bottom.vue (페이지 번호)

  **Rich 포함 항목 (Minimal 전부 +):**
  - UnoCSS attributify 모드 (`css: unocss`)
  - Glassmorphism 카드 패턴 + 색상 시맨틱
  - `$clicks` 조건부 입장 애니메이션
  - v-mark 텍스트 하이라이트
  - v-motion 입장 효과
  - Glow polygon 배경 (global-bottom.vue)
  - Scoped CSS (fade-out blur, code glassmorphism, v-mark 스케일링)
  - `colorSchema: dark` 강제
  - `preload: false`
  - icons: carbon + logos + devicon + mdi
  - Staggered delay 애니메이션 (safelist 포함)

- [ ] **UnoCSS Config 가이드 (Rich 레벨)**
  - Rich 레벨에서 `uno.config.ts` 생성 가이드:
    ```ts
    import config from '@slidev/client/uno.config'
    import { mergeConfigs, presetAttributify, presetIcons, presetWebFonts, presetWind3 } from 'unocss'

    export default mergeConfigs([config, {
      safelist: [
        ...Array.from({ length: 30 }, (_, i) => `delay-${(i + 1) * 100}`),
        'animate-pulse',
      ],
      presets: [
        presetWind3({ dark: 'class' }),
        presetAttributify(),
        presetIcons({
          prefix: 'i-',
          extraProperties: { display: 'inline-block', 'vertical-align': 'middle' },
        }),
        presetWebFonts({
          fonts: { sans: 'DM Sans' },
        }),
      ],
    }])
    ```
  - Note: Out of Scope "uno.config.ts 커스텀 설정"을 Rich 레벨 한정으로 예외 처리

#### References 보강

- [ ] **새 파일: `references/visual-patterns.md`**
  - Glassmorphism 카드 공식 (기본, 헤더 바, 비교)
  - 색상 시맨틱 카드 시스템 (red/green/blue/purple/yellow)
  - Before/After 비교 패턴 (red vs green 2-col grid)
  - 3-column 그리드 카드 (challenges, features)
  - 스피커 카드 패턴 (circular avatar + bio)
  - 스켈레톤 와이어프레임 패턴 (empty div wireframe)
  - 인라인 SVG 아키텍처 다이어그램 패턴
  - Code + 설명 분할 패턴
  - 절대 위치 데코 요소 (로고, QR코드, 결과 이미지)
  - Scoped CSS 예제 (fade-out blur, code glassmorphism, footnote, v-mark scaling)

- [ ] **새 파일: `references/icons.md`**
  - 아이콘 설치 및 사용법 (UnoCSS presetIcons)
  - 주요 아이콘 세트: carbon (UI), logos (브랜드), devicon (기술), mdi (일반), ri (GitHub 등)
  - Attributify 아이콘 문법: `<div i-carbon:warning-alt text-red-300 text-xl mr-2 />`
  - 콘텍스트별 추천 아이콘 매핑
  - 인라인 아이콘 정렬 패턴: `inline-block mr-1 translate-y-0.8`
  - 브랜드 색상 매핑 (arbitrary values):
    ```html
    <span text="[#5791f7]">Kubernetes</span>
    <span text="[#f6432f]">PyTorch</span>
    ```

- [ ] **기존 파일 업데이트: `references/layouts.md`**
  - 각 레이아웃에 `class` frontmatter 예제 추가 (`class: py-10`)
  - `layoutClass` frontmatter 활용 예제
  - 공식 테마 레이아웃 구조 패턴:
    - `.slidev-layout` root class + layout-specific class
    - `my-auto` 수직 중앙 정렬
    - Named slots (`::right::`, `::items::`) 패턴
  - apple-basic 전용 레이아웃 (intro-image, 3-images, bullets)
  - figure 레이아웃 (academic 테마: figureCaption, figureUrl, figureFootnoteNumber)
  - grid 기반 split 레이아웃: `grid grid-cols-2 gap-8`

- [ ] **기존 파일 업데이트: `references/animations.md`**
  - v-mark 색상/타입별 실전 예제 (nekomeowww 패턴):
    ```html
    <span v-mark="{ at: 2, color: 'rgb(144, 200, 255)', type: 'underline' }">text</span>
    ```
  - click markers `[click]` 패턴
  - `$clicks` 조건부 클래스 바인딩 패턴 (방향별 4가지)
  - v-motion 입장 효과 예제
  - `v-clicks depth="2"` 중첩 리스트 예제
  - `v-after` 동기화 예제
  - Staggered delay 패턴 (`v-for` + computed v-click)
  - Custom keyframe 애니메이션 예제 (pulse, shake)
  - `<Arrow>` 컴포넌트 활용 예제

- [ ] **기존 파일 업데이트: `references/components.md`**
  - `<Arrow>` 활용 패턴 (코드 블록 가리키기 등)
  - `<Transform>` 실전 활용
  - `<Footnotes>` / `<Footnote>` 컴포넌트 (academic 테마)
  - Counter 인터랙티브 컴포넌트 패턴

- [ ] **새 파일: `references/glow-background.md`** (Rich 전용)
  - global-bottom.vue glow polygon 배경 전체 코드
  - Per-slide frontmatter 제어 (glowSeed, glow, glowOpacity, glowHue)
  - CSS (bg, clip 클래스, 2.5s transition)
  - seedrandom 의존성 설치
  - 커스텀 색상 조합 가이드 (테마 컬러 기반)

### Should Have (P1)

- [ ] **Example 슬라이드 업데이트**: SKILL.md의 "Complete slides.md Structure" 예제를 KubeCon 수준으로 업그레이드
  - Minimal 예제: v-clicks + fade-out + icons + py-10
  - Rich 예제: glassmorphism cards + $clicks animation + attributify + glow seed
- [ ] **`<script setup>` 가이드**: 복잡한 v-motion 애니메이션을 위한 script setup 패턴
- [ ] **코드 블록 고급 패턴**:
  - Line highlighting step-through: `{all|1-2|4-21|23-28}`
  - `maxHeight` 스크롤: `{maxHeight: '450px'}`
  - Shiki 테마 설정 (github-dark, material-darker)

### Nice to Have (P2)

- [ ] **MDC 문법 활용 가이드**: 인라인 스타일링 `[텍스트]{style="color:red"}` 예제
- [ ] **`<VSwitch>` 활용 패턴**: 클릭별 콘텐츠 교체로 동적 슬라이드
- [ ] **Magic Link 스타일링**: GitHub 링크 자동 아이콘/이름 표시 커스텀 CSS

## Anti-AI Design Rules

생성 시 반드시 지켜야 할 디자인 금지 사항:

| 금지 항목 | 설명 |
|-----------|------|
| 보라-초록 그라데이션 | AI가 즐겨 쓰는 `from-purple-500 to-green-400` 류 |
| 네온 색상 조합 | `#ff00ff`, `#00ffff` 같은 과도하게 채도 높은 조합 |
| Accent bar | 슬라이드 상단/하단의 장식적 색상 바 |
| 과도한 그라데이션 | 배경 전체 그라데이션. 텍스트 강조용으로만 제한적 허용 |
| 직접적 네온 글로우 | 요소에 직접 적용하는 네온/글로우 효과 |
| 무지개 색상 나열 | 한 슬라이드에 5+ 색상 무작위 사용 |

허용되는 시각적 처리:
- 테마 컬러 기반 gradient text (h1 등 제한적)
- 단색 배경 (`background: '#1e293b'` 등)
- `cover.sli.dev` 큐레이션 이미지 (커버 슬라이드)
- Glassmorphism 카드: `backdrop-blur` + 반투명 bg + 테두리 (핵심 패턴)
- `v-mark`의 Rough Notation 스타일 (손그림 느낌으로 자연스러움)
- Glow polygon 배경: `blur(70px)` 처리된 은은한 gradient polygon (Rich 전용, 네온과 구분됨)
- 색상 시맨틱 카드: 일관된 색상 의미 체계 내에서 `{color}-800/20` 반투명 활용

### 색상 사용 가이드라인

**카드/UI 요소**:
- `bg="{color}-800/20"` + `border="2 solid {color}-800"` (카드 공식)
- `bg="{color}-800/40"` (카드 헤더 바)
- `text-{color}-300` (아이콘/강조 텍스트, dark mode 기준)

**텍스트**:
- `opacity-70` / `opacity-50` (보조 텍스트)
- `text-zinc-300` ~ `text-zinc-500` (중립 텍스트)
- `text-neutral-200` ~ `text-neutral-700` (계층 표현)

**브랜드 색상**:
- 기술 로고는 공식 hex 값 사용: `text="[#5791f7]"` (Kubernetes), `text="[#f6432f]"` (PyTorch)

## Technical Constraints

- slides.md 생성에 집중
- Vue 컴포넌트 파일: global-bottom.vue (Minimal: 페이지번호, Rich: glow + 페이지번호)
- Rich 레벨에서 uno.config.ts 생성 허용 (attributify + icons + safelist)
- 기존 인터뷰 워크플로우 유지 (Phase 1~3 구조 변경 없이 Phase 3 확장만)
- Anti-AI writing rules 기존 규칙 유지
- 테마별 호환성 고려 (apple-basic 전용 레이아웃 구분)

## Out of Scope

- 커스텀 테마 생성
- 커스텀 Vue 컴포넌트 생성 (global-bottom.vue 제외)
- Slidev 프로젝트 빌드/배포 자동화
- 새로운 테마 추가
- Glow polygon 배경의 색상 커스터마이징 UI (코드 직접 수정으로 대응)
