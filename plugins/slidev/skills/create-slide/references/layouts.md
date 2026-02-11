# Slidev 레이아웃 참조 가이드

이 문서는 Slidev의 모든 built-in 레이아웃과 apple-basic 테마 전용 레이아웃에 대한 완전한 사용 예제를 포함합니다.

## 목차

- [Built-in 레이아웃](#built-in-레이아웃)
- [Apple-Basic 테마 레이아웃](#apple-basic-테마-레이아웃)
- [Slot Sugar 문법](#slot-sugar-문법)

---

## Built-in 레이아웃

Slidev 코어에 포함된 기본 레이아웃입니다.

### 1. default

기본 콘텐츠 레이아웃. 타이틀과 본문을 표시합니다.

**Frontmatter 옵션:**
- `layout: default` (생략 가능, 기본값)
- 일반적인 슬라이드 옵션 모두 사용 가능

**Slot:**
- `default`: 메인 콘텐츠 영역

**사용 예제:**

```md
---
layout: default
---

# 슬라이드 제목

일반적인 콘텐츠를 여기에 작성합니다.

- 항목 1
- 항목 2
- 항목 3

코드 블록도 사용할 수 있습니다:

\`\`\`js
console.log('Hello Slidev')
\`\`\`
```

---

### 2. center

모든 콘텐츠를 중앙에 배치합니다.

**Frontmatter 옵션:**
- `layout: center`

**Slot:**
- `default`: 중앙 정렬될 콘텐츠

**사용 예제:**

```md
---
layout: center
---

# 중앙 정렬 제목

중앙에 표시될 중요한 메시지

**강조 텍스트**도 중앙 정렬됩니다
```

---

### 3. cover

프레젠테이션의 표지 슬라이드. 첫 번째 슬라이드의 기본 레이아웃입니다.

**Frontmatter 옵션:**
- `layout: cover`
- `background`: 배경 이미지 또는 색상

**Slot:**
- `default`: 제목 및 부제목 영역

**사용 예제:**

```md
---
layout: cover
background: https://source.unsplash.com/collection/94734566/1920x1080
---

# Slidev 프레젠테이션

프레젠테이션 부제목

<div class="pt-12">
  <span @click="$slidev.nav.next" class="px-2 py-1 rounded cursor-pointer" hover="bg-white bg-opacity-10">
    시작하기 <carbon:arrow-right class="inline"/>
  </span>
</div>
```

---

### 4. intro

소개 슬라이드. 발표자 정보와 함께 타이틀을 표시합니다.

**Frontmatter 옵션:**
- `layout: intro`

**Slot:**
- `default`: 소개 내용

**사용 예제:**

```md
---
layout: intro
---

# 프로젝트 소개

## 혁신적인 AI 플랫폼

<div class="absolute bottom-10">
  <span class="font-700">
    발표자: 홍길동
  </span>
</div>

<div class="abs-br m-6 flex gap-2">
  <a href="https://github.com/slidevjs/slidev" target="_blank" alt="GitHub"
    class="text-xl icon-btn opacity-50 !border-none !hover:text-white">
    <carbon-logo-github />
  </a>
</div>
```

---

### 5. section

섹션 구분 슬라이드. 새로운 주제를 시작할 때 사용합니다.

**Frontmatter 옵션:**
- `layout: section`
- `background`: 배경 색상 또는 이미지

**Slot:**
- `default`: 섹션 제목

**사용 예제:**

```md
---
layout: section
background: '#1e293b'
---

# 섹션 1

주요 기능 소개
```

---

### 6. statement

전체 화면에 강조할 문구를 표시합니다.

**Frontmatter 옵션:**
- `layout: statement`

**Slot:**
- `default`: 강조 문구

**사용 예제:**

```md
---
layout: statement
---

# "혁신은 세부 사항에서 시작됩니다"

Steve Jobs
```

---

### 7. fact

중요한 데이터나 통계를 부각시킵니다.

**Frontmatter 옵션:**
- `layout: fact`

**Slot:**
- `default`: 주요 팩트

**사용 예제:**

```md
---
layout: fact
---

# 95%

사용자 만족도
```

---

### 8. quote

인용구를 표시합니다.

**Frontmatter 옵션:**
- `layout: quote`

**Slot:**
- `default`: 인용 내용

**사용 예제:**

```md
---
layout: quote
---

# "프로그래밍은 예술이다"

Donald Knuth, The Art of Computer Programming
```

---

### 9. end

프레젠테이션의 마지막 슬라이드.

**Frontmatter 옵션:**
- `layout: end`

**Slot:**
- `default`: 마무리 메시지

**사용 예제:**

```md
---
layout: end
---

# 감사합니다

질문이 있으시면 언제든지 문의해주세요

contact@example.com
```

---

### 10. full

전체 화면 콘텐츠. 여백 없이 전체 영역을 활용합니다.

**Frontmatter 옵션:**
- `layout: full`

**Slot:**
- `default`: 전체 화면 콘텐츠

**사용 예제:**

```md
---
layout: full
---

<div class="w-full h-full flex items-center justify-center bg-gradient-to-r from-blue-500 to-purple-600">
  <h1 class="text-6xl text-white">전체 화면 콘텐츠</h1>
</div>
```

---

### 11. none

아무런 스타일링도 적용하지 않습니다. 완전한 커스텀 레이아웃이 필요할 때 사용합니다.

**Frontmatter 옵션:**
- `layout: none`

**Slot:**
- `default`: 모든 콘텐츠

**사용 예제:**

```md
---
layout: none
---

<div class="absolute inset-0 flex items-center justify-center">
  <div class="text-center">
    <h1 class="text-8xl font-bold">100%</h1>
    <p class="text-2xl mt-4">커스텀 디자인</p>
  </div>
</div>
```

---

### 12. image

전체 화면 이미지를 표시합니다.

**Frontmatter 옵션:**
- `layout: image`
- `image`: 이미지 URL (필수)
- `backgroundSize`: CSS background-size 속성 (기본값: `cover`)

**Slot:**
- 없음 (이미지만 표시)

**사용 예제:**

```md
---
layout: image
image: https://source.unsplash.com/collection/94734566/1920x1080
backgroundSize: contain
---
```

---

### 13. image-left

왼쪽에 이미지, 오른쪽에 콘텐츠를 배치합니다.

**Frontmatter 옵션:**
- `layout: image-left`
- `image`: 이미지 URL (필수)
- `class`: 콘텐츠 영역에 적용할 CSS 클래스
- `backgroundSize`: 이미지의 background-size (기본값: `cover`)

**Slot:**
- `default`: 오른쪽 콘텐츠 영역

**사용 예제:**

```md
---
layout: image-left
image: https://source.unsplash.com/collection/94734566/800x600
class: my-cool-content
---

# 왼쪽 이미지 레이아웃

오른쪽에는 콘텐츠를 작성합니다.

- 이미지와 텍스트를 함께 표시
- 설명이 필요한 비주얼 자료에 적합
- 반응형으로 동작합니다

<style>
.my-cool-content {
  padding: 2rem;
}
</style>
```

---

### 14. image-right

왼쪽에 콘텐츠, 오른쪽에 이미지를 배치합니다.

**Frontmatter 옵션:**
- `layout: image-right`
- `image`: 이미지 URL (필수)
- `class`: 콘텐츠 영역에 적용할 CSS 클래스
- `backgroundSize`: 이미지의 background-size (기본값: `cover`)

**Slot:**
- `default`: 왼쪽 콘텐츠 영역

**사용 예제:**

```md
---
layout: image-right
image: https://source.unsplash.com/collection/94734566/800x600
---

# 오른쪽 이미지 레이아웃

왼쪽에는 콘텐츠를 작성합니다.

```ts
// 코드 예제도 포함 가능
interface User {
  name: string
  email: string
}
```

이미지가 오른쪽에 자동으로 표시됩니다.
```

---

### 15. iframe

웹 페이지를 임베드합니다.

**Frontmatter 옵션:**
- `layout: iframe`
- `url`: 임베드할 URL (필수)

**Slot:**
- 없음 (iframe만 표시)

**사용 예제:**

```md
---
layout: iframe
url: https://slidev.dev
---
```

---

### 16. iframe-left

왼쪽에 iframe, 오른쪽에 콘텐츠를 배치합니다.

**Frontmatter 옵션:**
- `layout: iframe-left`
- `url`: 임베드할 URL (필수)
- `class`: 콘텐츠 영역에 적용할 CSS 클래스

**Slot:**
- `default`: 오른쪽 콘텐츠 영역

**사용 예제:**

```md
---
layout: iframe-left
url: https://www.youtube.com/embed/dQw4w9WgXcQ
---

# 동영상과 함께 설명

왼쪽에는 YouTube 영상이 표시되고, 오른쪽에는 설명을 작성할 수 있습니다.

- 데모 영상과 함께 설명
- 라이브 사이트 미리보기
- 인터랙티브 콘텐츠
```

---

### 17. iframe-right

왼쪽에 콘텐츠, 오른쪽에 iframe을 배치합니다.

**Frontmatter 옵션:**
- `layout: iframe-right`
- `url`: 임베드할 URL (필수)
- `class`: 콘텐츠 영역에 적용할 CSS 클래스

**Slot:**
- `default`: 왼쪽 콘텐츠 영역

**사용 예제:**

```md
---
layout: iframe-right
url: https://codepen.io/pen/
---

# 코드 데모

왼쪽에 설명을 작성하고, 오른쪽에는 라이브 코드 예제를 표시합니다.

- CodePen 임베드
- StackBlitz 프로젝트
- 인터랙티브 문서
```

---

### 18. two-cols

두 개의 컬럼으로 콘텐츠를 나눕니다.

**Frontmatter 옵션:**
- `layout: two-cols`

**Slot:**
- `default` 또는 `left`: 왼쪽 컬럼
- `right`: 오른쪽 컬럼

**사용 예제:**

```md
---
layout: two-cols
---

# 왼쪽 컬럼

이곳은 왼쪽 컬럼입니다.

- 항목 1
- 항목 2
- 항목 3

::right::

# 오른쪽 컬럼

이곳은 오른쪽 컬럼입니다.

```ts
const greeting = 'Hello'
console.log(greeting)
```

오른쪽에는 코드나 이미지를 배치할 수 있습니다.
```

---

### 19. two-cols-header

헤더와 두 개의 컬럼으로 구성된 레이아웃입니다.

**Frontmatter 옵션:**
- `layout: two-cols-header`

**Slot:**
- `default`: 헤더 영역
- `left`: 왼쪽 컬럼
- `right`: 오른쪽 컬럼

**사용 예제:**

```md
---
layout: two-cols-header
---

# 공통 헤더

이 헤더는 두 컬럼 위에 표시됩니다.

::left::

## 왼쪽 섹션

- Before 상태
- 기존 방식
- 문제점

::right::

## 오른쪽 섹션

- After 상태
- 개선된 방식
- 해결 방안
```

---

## Apple-Basic 테마 레이아웃

`theme: apple-basic`을 사용할 때만 사용 가능한 추가 레이아웃입니다.

### 1. intro (Apple-Basic Override)

Apple Keynote 스타일의 타이틀 슬라이드. 하단에 작성자/날짜 영역이 있습니다.

**Frontmatter 옵션:**
- `layout: intro`
- `theme: apple-basic` (필수)

**Slot:**
- `default`: 제목 및 부제목

**사용 예제:**

```md
---
theme: apple-basic
layout: intro
---

# 혁신적인 제품 발표

차세대 AI 플랫폼

<div class="absolute bottom-10">
  <p class="text-sm opacity-75">
    홍길동 | 2024년 2월 11일
  </p>
</div>
```

---

### 2. intro-image

전체 배경 이미지 위에 타이틀을 오버레이합니다.

**Frontmatter 옵션:**
- `layout: intro-image`
- `theme: apple-basic` (필수)
- `image`: 배경 이미지 URL (필수)

**Slot:**
- `default`: 오버레이될 제목

**사용 예제:**

```md
---
theme: apple-basic
layout: intro-image
image: https://source.unsplash.com/collection/94734566/1920x1080
---

<div class="absolute top-1/3 left-10 right-10">
  <h1 class="text-7xl font-bold text-white drop-shadow-lg">
    미래를 향한 여정
  </h1>
  <p class="text-3xl text-white mt-8 drop-shadow">
    AI가 만드는 새로운 세상
  </p>
</div>
```

---

### 3. intro-image-right

왼쪽에 타이틀, 오른쪽에 이미지를 배치합니다.

**Frontmatter 옵션:**
- `layout: intro-image-right`
- `theme: apple-basic` (필수)
- `image`: 오른쪽 이미지 URL (필수)

**Slot:**
- `default`: 왼쪽 타이틀 영역

**사용 예제:**

```md
---
theme: apple-basic
layout: intro-image-right
image: https://source.unsplash.com/collection/94734566/800x1080
---

<div class="flex flex-col justify-center h-full pl-20">
  <h1 class="text-6xl font-bold mb-8">
    혁신의 시작
  </h1>
  <p class="text-2xl opacity-75">
    새로운 패러다임으로의 전환
  </p>
  <p class="text-lg mt-12 opacity-50">
    2024년 2월 11일
  </p>
</div>
```

---

### 4. image-right (Apple-Basic Override)

콘텐츠와 오른쪽 정렬 이미지, 부제목 지원이 추가된 버전입니다.

**Frontmatter 옵션:**
- `layout: image-right`
- `theme: apple-basic` (필수)
- `image`: 이미지 URL (필수)

**Slot:**
- `default`: 왼쪽 콘텐츠 영역

**사용 예제:**

```md
---
theme: apple-basic
layout: image-right
image: https://source.unsplash.com/collection/94734566/800x600
---

# 주요 기능

## 혁신적인 사용자 경험

- 직관적인 인터페이스
- 빠른 응답 속도
- 강력한 커스터마이징

오른쪽 이미지와 함께 깔끔하게 정리된 콘텐츠를 표시합니다.
```

---

### 5. bullets

최소한의 디자인으로 불릿 포인트만 표시합니다.

**Frontmatter 옵션:**
- `layout: bullets`
- `theme: apple-basic` (필수)

**Slot:**
- `default`: 불릿 리스트

**사용 예제:**

```md
---
theme: apple-basic
layout: bullets
---

# 핵심 요약

- 첫 번째 핵심 포인트
- 두 번째 핵심 포인트
- 세 번째 핵심 포인트
- 네 번째 핵심 포인트

간결하고 명확한 메시지 전달에 최적화된 레이아웃입니다.
```

---

### 6. 3-images

세 개의 이미지를 그리드로 배치합니다. 왼쪽에 큰 이미지 하나, 오른쪽에 두 개의 이미지가 수직으로 쌓입니다.

**Frontmatter 옵션:**
- `layout: 3-images`
- `theme: apple-basic` (필수)
- `imageLeft`: 왼쪽 큰 이미지 URL (필수)
- `imageTopRight`: 오른쪽 상단 이미지 URL (필수)
- `imageBottomRight`: 오른쪽 하단 이미지 URL (필수)

**Slot:**
- `default`: 제목 또는 캡션 (선택)

**사용 예제:**

```md
---
theme: apple-basic
layout: 3-images
imageLeft: https://source.unsplash.com/800x1200?nature
imageTopRight: https://source.unsplash.com/800x600?technology
imageBottomRight: https://source.unsplash.com/800x600?architecture
---

# 다양한 관점

세 가지 측면에서 바라본 프로젝트
```

---

## Slot Sugar 문법

Slidev는 named slot을 간편하게 사용할 수 있는 sugar 문법을 제공합니다.

### 기본 Slot Marker

- `::right::` - 오른쪽 슬롯 시작
- `::left::` - 왼쪽 슬롯 시작
- `::bottom::` - 하단 슬롯 시작
- `::slot-name::` - 커스텀 슬롯 시작

### two-cols 예제

```md
---
layout: two-cols
---

# 왼쪽 컬럼 제목

왼쪽에 표시될 모든 콘텐츠입니다.

- 리스트 항목 1
- 리스트 항목 2

```js
// 코드 블록도 가능
const left = 'content'
```

::right::

# 오른쪽 컬럼 제목

오른쪽에 표시될 모든 콘텐츠입니다.

![이미지](https://source.unsplash.com/400x300?code)

**강조 텍스트**도 사용 가능합니다.
```

### two-cols-header 완전한 예제

```md
---
layout: two-cols-header
---

# 비교 분석

두 가지 접근 방식을 비교합니다.

::left::

## 방법 A

### 장점
- 빠른 구현
- 낮은 복잡도
- 쉬운 유지보수

### 단점
- 제한된 확장성
- 성능 이슈 가능성

```python
# 방법 A 코드 예제
def simple_approach():
    return "quick but limited"
```

::right::

## 방법 B

### 장점
- 높은 확장성
- 우수한 성능
- 유연한 아키텍처

### 단점
- 복잡한 구현
- 긴 개발 시간

```python
# 방법 B 코드 예제
class AdvancedApproach:
    def __init__(self):
        self.scalable = True

    def execute(self):
        return "complex but powerful"
```
```

### 커스텀 슬롯 예제

커스텀 레이아웃을 만들 때 임의의 슬롯 이름을 사용할 수 있습니다.

```md
---
layout: my-custom-layout
---

기본 콘텐츠 영역입니다.

::header::

# 커스텀 헤더

이 부분은 header 슬롯에 들어갑니다.

::footer::

<div class="text-sm opacity-50">
  페이지 하단 정보
</div>

::sidebar::

- 사이드바 항목 1
- 사이드바 항목 2
- 사이드바 항목 3
```

### 여러 슬롯 조합 예제

```md
---
layout: two-cols-header
class: px-8
---

# 제품 비교표

세 가지 제품의 주요 특징을 비교합니다.

::left::

## 제품 A

| 기능 | 지원 여부 |
|------|-----------|
| Feature 1 | ✓ |
| Feature 2 | ✓ |
| Feature 3 | ✗ |
| Feature 4 | ✓ |

**가격:** $99/월

::right::

## 제품 B

| 기능 | 지원 여부 |
|------|-----------|
| Feature 1 | ✓ |
| Feature 2 | ✓ |
| Feature 3 | ✓ |
| Feature 4 | ✓ |

**가격:** $199/월

<div class="mt-8 p-4 bg-green-100 rounded">
  <strong>권장</strong>: 모든 기능이 필요한 경우
</div>
```

---

## 레이아웃 선택 가이드

| 목적 | 권장 레이아웃 |
|------|---------------|
| 표지 | `cover` |
| 섹션 구분 | `section` |
| 일반 콘텐츠 | `default` |
| 중요한 메시지 | `center`, `statement` |
| 통계/데이터 강조 | `fact` |
| 인용 | `quote` |
| 이미지 중심 | `image`, `image-left`, `image-right` |
| 비교 설명 | `two-cols`, `two-cols-header` |
| 웹 임베드 | `iframe`, `iframe-left`, `iframe-right` |
| 마무리 | `end` |
| Apple 스타일 타이틀 | `intro` (apple-basic) |
| 이미지 갤러리 | `3-images` (apple-basic) |

---

## 레이아웃 커스터마이징

모든 레이아웃은 frontmatter의 `class` 속성으로 커스터마이징할 수 있습니다.

```md
---
layout: center
class: text-white bg-gradient-to-r from-blue-500 to-purple-600
---

# 그라데이션 배경

커스텀 스타일이 적용된 중앙 정렬 슬라이드
```

### Scoped 스타일 추가

각 슬라이드마다 고유한 스타일을 적용할 수 있습니다.

```md
---
layout: default
---

# 커스텀 스타일 슬라이드

<div class="my-custom-box">
  특별한 스타일이 적용된 박스
</div>

<style>
.my-custom-box {
  padding: 2rem;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 1rem;
  color: white;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
}
</style>
```

---

## 참고사항

1. **테마 의존성**: `apple-basic` 전용 레이아웃은 해당 테마를 사용할 때만 작동합니다.
2. **Slot 순서**: Slot marker (`::right::` 등)는 반드시 빈 줄 위에 작성해야 합니다.
3. **이미지 경로**: 로컬 이미지는 `public/` 폴더에 저장하고 `/image.png` 형식으로 참조합니다.
4. **반응형**: 모든 built-in 레이아웃은 기본적으로 반응형으로 동작합니다.
5. **PDF 출력**: PDF로 내보낼 때 일부 인터랙티브 기능은 작동하지 않을 수 있습니다.
