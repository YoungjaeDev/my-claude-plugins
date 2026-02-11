# Slidev 내장 컴포넌트 레퍼런스

Slidev에서 제공하는 모든 내장 컴포넌트의 상세 가이드입니다.

---

## Navigation & Structure

### 1. Toc - 목차 컴포넌트

슬라이드 목차를 자동으로 생성합니다.

**Props:**
- `columns`: 컬럼 수 (기본값: 1)
- `maxDepth`: 최대 헤딩 깊이 (기본값: Infinity)
- `minDepth`: 최소 헤딩 깊이 (기본값: 1)
- `mode`: 표시 모드 - 'all' | 'onlyCurrentTree' | 'onlySiblings' (기본값: 'all')
- `listClass`: 목록 CSS 클래스

**사용 예시:**
```vue
---
layout: intro
---

# 목차

<Toc columns="2" maxDepth="2" minDepth="1" mode="all" />
```

### 2. Link - 슬라이드 네비게이션 링크

특정 슬라이드로 이동하는 링크를 생성합니다.

**Props:**
- `to`: 대상 슬라이드 번호 또는 경로
- `title`: 링크 텍스트 (선택사항)

**사용 예시:**
```vue
<Link to="5">5번 슬라이드로 이동</Link>
<Link to="intro">Intro 슬라이드로</Link>
```

### 3. SlideCurrentNo - 현재 슬라이드 번호

현재 슬라이드의 번호를 표시합니다.

**사용 예시:**
```vue
<div class="absolute bottom-4 right-4">
  <SlideCurrentNo /> / <SlidesTotal />
</div>
```

### 4. SlidesTotal - 전체 슬라이드 수

프레젠테이션의 총 슬라이드 수를 표시합니다.

**사용 예시:**
```vue
<footer>
  Page <SlideCurrentNo /> of <SlidesTotal />
</footer>
```

### 5. TitleRenderer - 슬라이드 제목 렌더링

특정 슬라이드의 제목을 가져와 표시합니다.

**Props:**
- `no`: 슬라이드 번호

**사용 예시:**
```vue
<div class="toc-entry">
  <Link to="3">
    <TitleRenderer no="3" />
  </Link>
</div>
```

---

## Visual Elements

### 6. Arrow - 화살표 그리기

슬라이드에 화살표를 그립니다.

**Props:**
- `x1`: 시작 x 좌표 (px 또는 %)
- `y1`: 시작 y 좌표
- `x2`: 끝 x 좌표
- `y2`: 끝 y 좌표
- `width`: 선 두께 (기본값: 2)
- `color`: 색상 (기본값: 'currentColor')
- `two-way`: 양방향 화살표 (기본값: false)

**사용 예시:**
```vue
<Arrow x1="400" y1="300" x2="600" y2="400" width="3" color="#ff0000" />
<Arrow x1="10%" y1="50%" x2="90%" y2="50%" two-way />
```

### 7. VDragArrow - 드래그 가능한 화살표

드래그로 위치를 조정할 수 있는 화살표입니다.

**사용 예시:**
```vue
<VDragArrow x1="200" y1="200" x2="400" y2="300" color="#42b883" />
```

### 8. AutoFitText - 자동 크기 조정 텍스트

컨테이너에 맞춰 텍스트 크기를 자동으로 조정합니다.

**Props:**
- `max`: 최대 font-size (기본값: 100px)
- `min`: 최소 font-size (기본값: 10px)

**사용 예시:**
```vue
<AutoFitText :max="200" :min="20" class="w-full h-40">
  이 텍스트는 자동으로 크기가 조정됩니다
</AutoFitText>
```

### 9. Transform - 변형 래퍼

요소를 확대/축소하거나 변형합니다.

**Props:**
- `scale`: 확대/축소 비율 (기본값: 1)
- `origin`: 변형 기준점 (기본값: 'center')

**사용 예시:**
```vue
<Transform :scale="2" origin="top left">
  <img src="/diagram.png" />
</Transform>

<Transform :scale="0.5">
  <div class="code-block">
    긴 코드를 축소해서 표시
  </div>
</Transform>
```

### 10. VDrag - 드래그 가능한 요소

요소를 드래그로 이동할 수 있게 만듭니다.

**사용 예시:**
```vue
<VDrag>
  <div class="bg-blue-500 p-4 rounded">
    이 박스를 드래그하세요
  </div>
</VDrag>

<VDrag x="100" y="200">
  <img src="/logo.png" width="100" />
</VDrag>
```

---

## Media

### 11. SlidevVideo - 비디오 임베드

비디오를 슬라이드에 삽입합니다.

**Props:**
- `controls`: 컨트롤 표시 여부 (기본값: true)
- `autoplay`: 자동 재생 (기본값: false)
- `autoreset`: 슬라이드 나갈 때 리셋 (기본값: true)
- `poster`: 포스터 이미지 URL
- `timestamp`: 시작 시간 (초)

**사용 예시:**
```vue
<SlidevVideo controls autoplay>
  <source src="/demo.mp4" type="video/mp4" />
</SlidevVideo>

<SlidevVideo
  controls
  :autoplay="false"
  poster="/thumbnail.jpg"
  :timestamp="10"
>
  <source src="/presentation.mp4" />
</SlidevVideo>
```

### 12. Youtube - YouTube 임베드

YouTube 비디오를 삽입합니다.

**Props:**
- `id`: YouTube 비디오 ID (필수)
- `width`: 너비 (기본값: 100%)
- `height`: 높이 (기본값: auto)

**사용 예시:**
```vue
<Youtube id="dQw4w9WgXcQ" width="640" height="360" />

<Youtube id="dQw4w9WgXcQ" class="w-full h-80" />
```

### 13. Tweet - Twitter/X 임베드

트윗을 슬라이드에 삽입합니다.

**Props:**
- `id`: 트윗 ID (필수)
- `scale`: 확대/축소 비율 (기본값: 1)
- `conversation`: 대화 스레드 표시 (기본값: 'none')
- `cards`: 카드 표시 여부 (기본값: 'visible')

**사용 예시:**
```vue
<Tweet id="1234567890123456789" />

<Tweet
  id="1234567890123456789"
  :scale="0.8"
  conversation="all"
  cards="hidden"
/>
```

---

## Conditional Rendering

### 14. LightOrDark - 테마 기반 조건부 렌더링

Light/Dark 모드에 따라 다른 콘텐츠를 표시합니다.

**Slots:**
- `#dark`: Dark 모드에서 표시
- `#light`: Light 모드에서 표시

**사용 예시:**
```vue
<LightOrDark>
  <template #dark>
    <img src="/logo-dark.png" />
  </template>
  <template #light>
    <img src="/logo-light.png" />
  </template>
</LightOrDark>

<LightOrDark>
  <template #dark>
    <div class="bg-gray-900 text-white p-4">
      Dark 모드 콘텐츠
    </div>
  </template>
  <template #light>
    <div class="bg-white text-gray-900 p-4">
      Light 모드 콘텐츠
    </div>
  </template>
</LightOrDark>
```

### 15. RenderWhen - 컨텍스트 기반 조건부 렌더링

특정 렌더링 컨텍스트에서만 콘텐츠를 표시합니다.

**Props:**
- `context`: 렌더링 컨텍스트
  - `main`: 메인 슬라이드
  - `visible`: 현재 보이는 슬라이드
  - `print`: 인쇄/PDF 출력
  - `slide`: 슬라이드 뷰
  - `overview`: 개요 모드
  - `presenter`: 발표자 모드
  - `previewNext`: 다음 슬라이드 프리뷰

**사용 예시:**
```vue
<RenderWhen context="presenter">
  <div class="notes">
    발표자만 볼 수 있는 노트
  </div>
</RenderWhen>

<RenderWhen context="print">
  <footer>인쇄용 푸터</footer>
</RenderWhen>

<RenderWhen context="main">
  <div class="animations">
    메인 뷰에서만 실행되는 애니메이션
  </div>
</RenderWhen>
```

---

## Animation Components

### 16. VClick - 클릭 기반 가시성

클릭할 때마다 요소를 표시합니다.

**사용 예시:**
```vue
<div>
  <p>항상 보이는 텍스트</p>
  <VClick>
    <p>첫 번째 클릭에 나타남</p>
  </VClick>
  <VClick>
    <p>두 번째 클릭에 나타남</p>
  </VClick>
</div>
```

### 17. VClicks - 자식 요소 순차 표시

자식 요소들을 클릭할 때마다 하나씩 표시합니다.

**사용 예시:**
```vue
<VClicks>
  <p>첫 번째 클릭</p>
  <p>두 번째 클릭</p>
  <p>세 번째 클릭</p>
</VClicks>

<!-- 리스트 항목 순차 표시 -->
<VClicks>
  <ul>
    <li>항목 1</li>
    <li>항목 2</li>
    <li>항목 3</li>
  </ul>
</VClicks>
```

### 18. VAfter - 이전 클릭 이후 표시

이전 VClick/VClicks 이후에 표시됩니다.

**사용 예시:**
```vue
<VClick>
  <p>첫 번째</p>
</VClick>

<VAfter>
  <p>첫 번째와 함께 표시됨</p>
</VAfter>

<VClick>
  <p>두 번째</p>
</VClick>
```

### 19. VSwitch - 클릭 기반 슬롯 전환

클릭할 때마다 다른 슬롯을 표시합니다.

**Props:**
- `unmount`: 이전 슬롯 언마운트 여부 (기본값: true)
- `tag`: 래퍼 태그 (기본값: 'div')
- `childTag`: 자식 래퍼 태그 (기본값: 'div')
- `transition`: Transition 이름

**사용 예시:**
```vue
<VSwitch>
  <template #0>
    <div>초기 상태</div>
  </template>
  <template #1>
    <div>첫 번째 클릭 후</div>
  </template>
  <template #2>
    <div>두 번째 클릭 후</div>
  </template>
</VSwitch>

<VSwitch transition="fade" :unmount="false">
  <template #0>
    <img src="/step1.png" />
  </template>
  <template #1>
    <img src="/step2.png" />
  </template>
  <template #3-5>
    <img src="/step3-5.png" />
  </template>
</VSwitch>
```

---

## Branding

### 20. PoweredBySlidev - Slidev 브랜딩 링크

Slidev 공식 사이트로 연결되는 브랜딩 링크입니다.

**사용 예시:**
```vue
<div class="absolute bottom-2 right-2 text-xs opacity-50">
  <PoweredBySlidev />
</div>
```

---

## 종합 예시

다양한 컴포넌트를 조합한 실전 예시:

```vue
---
layout: center
---

# 제품 소개

<VClicks>

- 기능 1: 빠른 성능
- 기능 2: 직관적 UI
- 기능 3: 확장 가능

</VClicks>

<VClick>
<Transform :scale="1.5" class="mt-8">
  <AutoFitText :max="60" :min="20" class="text-blue-500">
    지금 시작하세요!
  </AutoFitText>
</Transform>
</VClick>

<Arrow x1="200" y1="400" x2="600" y2="400" color="#42b883" />

---
layout: two-cols
---

# 데모 비디오

<SlidevVideo controls autoplay>
  <source src="/demo.mp4" type="video/mp4" />
</SlidevVideo>

::right::

# 주요 포인트

<VClicks>

1. 간단한 설치
2. 강력한 기능
3. 커뮤니티 지원

</VClicks>

<VAfter>
<div class="mt-4 p-4 bg-blue-100 rounded">
  <Link to="10">자세히 보기 →</Link>
</div>
</VAfter>

---

# 반응형 콘텐츠

<LightOrDark>
  <template #dark>
    <div class="bg-gray-800 p-8 rounded">
      <h2 class="text-white">Dark 모드 최적화</h2>
      <Youtube id="dQw4w9WgXcQ" class="mt-4" />
    </div>
  </template>
  <template #light>
    <div class="bg-white p-8 rounded shadow">
      <h2 class="text-gray-900">Light 모드 최적화</h2>
      <Youtube id="dQw4w9WgXcQ" class="mt-4" />
    </div>
  </template>
</LightOrDark>

<RenderWhen context="presenter">
  <div class="notes mt-4 p-4 bg-yellow-100 rounded">
    발표자 노트: 이 부분에서 데모를 강조할 것
  </div>
</RenderWhen>
```
