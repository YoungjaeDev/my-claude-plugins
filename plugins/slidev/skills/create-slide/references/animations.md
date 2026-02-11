# Slidev 애니메이션 레퍼런스

Slidev는 강력한 애니메이션 시스템을 제공하여 클릭 기반 전환, 텍스트 마킹, 복잡한 모션, 코드 변화 애니메이션 등을 지원합니다.

## 1. v-click - 기본 클릭 애니메이션

요소를 클릭할 때마다 순차적으로 나타나게 만듭니다.

### 태그 방식

```md
<v-click>

첫 번째 클릭에 나타남

</v-click>

<v-click>

두 번째 클릭에 나타남

</v-click>

<v-click>

세 번째 클릭에 나타남

</v-click>
```

### 디렉티브 방식 (인라인)

```md
<div v-click>클릭 1</div>
<div v-click>클릭 2</div>
<p v-click>클릭 3</p>
```

### 번호 지정

특정 클릭 순서를 지정할 수 있습니다:

```md
<div v-click="3">세 번째로 나타남</div>
<div v-click="1">첫 번째로 나타남</div>
<div v-click="2">두 번째로 나타남</div>
```

### 클릭 후 숨기기

```md
<div v-click.hide>클릭하면 나타났다가 다음 클릭에 사라짐</div>
<div v-click>이제 이게 나타남</div>
```

### 커스텀 클릭 카운트

Frontmatter에서 슬라이드의 총 클릭 수를 지정:

```md
---
clicks: 5
---

# 슬라이드 제목

<div v-click="1">첫 번째</div>
<div v-click="2">두 번째</div>
<div v-click="3">세 번째</div>
<div v-click="4">네 번째</div>
<div v-click="5">다섯 번째</div>
```

### 실용 예제

```md
# 제품 특징

<v-click>

## 빠른 성능
10배 빠른 로딩 속도

</v-click>

<v-click>

## 안정성
99.9% 가동 시간 보장

</v-click>

<v-click>

## 확장성
무제한 사용자 지원

</v-click>
```

---

## 2. v-clicks - 자동 순차 애니메이션

여러 자식 요소를 자동으로 순차적으로 나타나게 합니다.

### 기본 사용

```md
<v-clicks>

- 첫 번째 항목
- 두 번째 항목
- 세 번째 항목
- 네 번째 항목

</v-clicks>
```

### Depth 지정

중첩된 요소의 깊이를 제어:

```md
<v-clicks depth="2">

- Level 1 항목
  - Level 2 항목 (같이 나타남)
  - Level 2 항목 (같이 나타남)
- Level 1 항목
  - Level 2 항목 (같이 나타남)

</v-clicks>
```

### Every 속성

N개씩 묶어서 나타나게:

```md
<v-clicks every="2">

- 항목 1 (첫 클릭)
- 항목 2 (첫 클릭)
- 항목 3 (두 번째 클릭)
- 항목 4 (두 번째 클릭)

</v-clicks>
```

### 복합 예제

```md
# 로드맵

<v-clicks>

## Q1 2024
- 기능 A 출시
- 베타 테스트 시작

## Q2 2024
- 공식 출시
- 마케팅 캠페인

## Q3 2024
- 글로벌 확장
- 파트너십 체결

</v-clicks>
```

---

## 3. v-after - 이전 클릭과 함께 표시

이전 클릭 요소와 동시에 나타나게 합니다.

### 기본 사용

```md
<div v-click>첫 번째 클릭에 나타남</div>
<div v-after>첫 번째 클릭에 같이 나타남</div>
```

### v-click과 결합

```md
<div v-click="1">첫 번째</div>
<div v-after>첫 번째와 함께</div>
<div v-click="2">두 번째</div>
<div v-after>두 번째와 함께</div>
```

### 실용 예제

```md
# 아키텍처

<div v-click>

## Frontend
React + TypeScript

</div>

<div v-after>

→ API Gateway

</div>

<div v-click>

## Backend
Node.js + Express

</div>

<div v-after>

→ Database

</div>
```

---

## 4. v-mark - 인라인 텍스트 마킹

텍스트를 강조하거나 표시할 수 있습니다.

### 기본 마킹 타입

```md
# 텍스트 강조

이것은 <span v-mark>기본 마크</span>입니다.

이것은 <span v-mark.underline>밑줄</span>입니다.

이것은 <span v-mark.circle>원형 강조</span>입니다.

이것은 <span v-mark.highlight>하이라이트</span>입니다.

이것은 <span v-mark.box>박스</span>입니다.

이것은 <span v-mark.strike-through>취소선</span>입니다.
```

### 색상 지정

```md
이것은 <span v-mark.underline.red>빨간 밑줄</span>입니다.

이것은 <span v-mark.highlight.yellow>노란 하이라이트</span>입니다.

이것은 <span v-mark.circle.green>초록 원</span>입니다.
```

### 클릭과 결합

```md
# 중요 포인트

<div v-click>

성능이 <span v-mark.highlight.yellow v-click>10배</span> 향상되었습니다.

</div>

<div v-click>

비용은 <span v-mark.strike-through.red v-click>$100</span> <span v-mark.highlight.green v-click>$50</span>으로 절감.

</div>
```

### 실용 예제

```md
# 마이그레이션 계획

<v-clicks>

- <span v-mark.box>Phase 1</span>: 데이터 백업
- <span v-mark.box>Phase 2</span>: 시스템 전환
- <span v-mark.box>Phase 3</span>: 검증 및 모니터링

</v-clicks>

<div v-click>

⚠️ <span v-mark.highlight.red>주의</span>: 다운타임 예상 시간 2시간

</div>
```

---

## 5. v-motion - 복잡한 모션 애니메이션

CSS 속성을 애니메이션화하여 복잡한 전환 효과를 만듭니다.

### 기본 사용

```md
<div
  v-motion
  :initial="{ x: -80 }"
  :enter="{ x: 0 }">
  왼쪽에서 슬라이드
</div>
```

### 복합 애니메이션

```md
<div
  v-motion
  :initial="{ x: -80, opacity: 0 }"
  :enter="{ x: 0, opacity: 1, transition: { duration: 1000 } }"
  :leave="{ x: 80, opacity: 0 }">
  페이드 + 슬라이드
</div>
```

### 클릭 기반 모션

```md
<div
  v-motion
  :initial="{ scale: 0 }"
  :enter="{ scale: 1 }"
  :click-1="{ scale: 1.5, rotate: 45 }"
  :click-2="{ scale: 1, rotate: 0 }">
  클릭하면 확대 및 회전
</div>
```

### 딜레이 및 타이밍

```md
<div
  v-motion
  :initial="{ y: -100, opacity: 0 }"
  :enter="{
    y: 0,
    opacity: 1,
    transition: {
      duration: 800,
      delay: 200,
      ease: 'easeOut'
    }
  }">
  딜레이와 이징 적용
</div>
```

### 실용 예제: 카드 애니메이션

```md
# 제품 소개

<div class="grid grid-cols-3 gap-4">

<div
  v-motion
  :initial="{ y: 100, opacity: 0 }"
  :enter="{ y: 0, opacity: 1, transition: { delay: 0 } }">

## 기능 1
빠른 성능

</div>

<div
  v-motion
  :initial="{ y: 100, opacity: 0 }"
  :enter="{ y: 0, opacity: 1, transition: { delay: 200 } }">

## 기능 2
안정성

</div>

<div
  v-motion
  :initial="{ y: 100, opacity: 0 }"
  :enter="{ y: 0, opacity: 1, transition: { delay: 400 } }">

## 기능 3
확장성

</div>

</div>
```

---

## 6. Slide Transitions - 슬라이드 전환 효과

슬라이드 간 전환 애니메이션을 제어합니다.

### Frontmatter 전환 설정

```md
---
transition: slide-left
---

# 슬라이드 1

---
transition: slide-right
---

# 슬라이드 2

---
transition: fade
---

# 슬라이드 3
```

### 사용 가능한 전환 효과

```md
---
# 왼쪽으로 슬라이드
transition: slide-left
---

---
# 오른쪽으로 슬라이드
transition: slide-right
---

---
# 위로 슬라이드
transition: slide-up
---

---
# 아래로 슬라이드
transition: slide-down
---

---
# 페이드
transition: fade
---

---
# View Transition API 사용 (Chrome 111+)
transition: view-transition
---

---
# 전환 효과 없음
transition: none
---
```

### 전역 전환 설정

모든 슬라이드에 기본 전환 효과 적용:

```md
---
# 첫 슬라이드 (전역 설정)
theme: apple-basic
transition: slide-left
---

# 슬라이드 1

---

# 슬라이드 2 (전역 설정 상속)

---
transition: fade
---

# 슬라이드 3 (개별 설정 우선)
```

### 커스텀 전환

Vue transition 컴포넌트 사용:

```md
---
transition: my-custom-transition
---

<style>
.my-custom-transition-enter-active,
.my-custom-transition-leave-active {
  transition: all 0.5s ease;
}

.my-custom-transition-enter-from {
  opacity: 0;
  transform: scale(0.9) rotate(-5deg);
}

.my-custom-transition-leave-to {
  opacity: 0;
  transform: scale(1.1) rotate(5deg);
}
</style>
```

---

## 7. Shiki Magic Move - 코드 변화 애니메이션

코드 블록 간 변화를 부드럽게 애니메이션으로 보여줍니다.

### 기본 사용

````md
# Code Evolution

````md magic-move
```js
// Step 1: 기본 함수
function greet(name) {
  console.log('Hello ' + name);
}
```

```js
// Step 2: ES6 템플릿 리터럴
function greet(name) {
  console.log(`Hello ${name}`);
}
```

```js
// Step 3: 화살표 함수
const greet = (name) => {
  console.log(`Hello ${name}`);
};
```

```js
// Step 4: 최종 버전
const greet = (name) => console.log(`Hello ${name}!`);
```
````
````

### 다중 파일 변화

````md
# Refactoring

````md magic-move
```js
// Before: 모놀리식
function processUser(user) {
  // 검증
  if (!user.email) throw new Error('No email');

  // 처리
  const normalized = user.email.toLowerCase();

  // 저장
  db.save({ email: normalized });
}
```

```js
// After: 모듈화
function validateUser(user) {
  if (!user.email) throw new Error('No email');
}

function normalizeEmail(email) {
  return email.toLowerCase();
}

function saveUser(user) {
  db.save(user);
}

function processUser(user) {
  validateUser(user);
  user.email = normalizeEmail(user.email);
  saveUser(user);
}
```
````
````

### 하이라이트와 결합

````md
````md magic-move {lines: true}
```js {1}
// 함수 선언 강조
function calculate(a, b) {
  return a + b;
}
```

```js {3}
// 리턴 구문 강조
function calculate(a, b) {
  const result = a + b;
  return result;
}
```

```js {2-3}
// 본문 강조
function calculate(a, b) {
  const result = a + b;
  console.log(`Result: ${result}`);
  return result;
}
```
````
````

### 실용 예제: API 진화

````md
# API 개선 과정

````md magic-move
```js
// v1: 기본 REST API
app.get('/users', (req, res) => {
  res.json(users);
});
```

```js
// v2: 페이지네이션 추가
app.get('/users', (req, res) => {
  const { page = 1, limit = 10 } = req.query;
  const start = (page - 1) * limit;
  res.json(users.slice(start, start + limit));
});
```

```js
// v3: 필터링 추가
app.get('/users', (req, res) => {
  const { page = 1, limit = 10, role } = req.query;
  let filtered = role ? users.filter(u => u.role === role) : users;
  const start = (page - 1) * limit;
  res.json(filtered.slice(start, start + limit));
});
```

```js
// v4: 에러 처리 및 타입 안정성
app.get('/users', async (req, res) => {
  try {
    const { page = 1, limit = 10, role } = req.query;
    const query = { ...(role && { role }) };
    const users = await User.find(query)
      .skip((page - 1) * limit)
      .limit(limit);
    res.json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```
````
````

---

## 8. Click Markers in Notes - 발표자 노트 자동 스크롤

발표자 노트에 `[click]` 마커를 추가하여 클릭마다 자동으로 스크롤됩니다.

### 기본 사용

```md
# 제품 특징

<v-clicks>

- 빠른 성능
- 높은 안정성
- 쉬운 확장

</v-clicks>

<!--
[click] 첫 번째 특징: 성능이 10배 향상되었습니다.
[click] 두 번째 특징: 99.9% 가동 시간을 보장합니다.
[click] 세 번째 특징: 수평 확장이 가능합니다.
-->
```

### 복잡한 예제

```md
# 시스템 아키텍처

<div v-click>

## Frontend Layer
React + TypeScript

</div>

<div v-click>

## API Gateway
Kong + Redis

</div>

<div v-click>

## Backend Services
- Auth Service
- User Service
- Payment Service

</div>

<div v-click>

## Database Layer
PostgreSQL + Redis

</div>

<!--
[click] Frontend: React 18 사용, TypeScript로 타입 안정성 확보

[click] API Gateway: Kong으로 rate limiting, Redis로 세션 관리

[click] Backend: 마이크로서비스 아키텍처, 각 서비스는 독립적으로 배포

[click] Database: PostgreSQL은 관계형 데이터, Redis는 캐싱 및 세션
-->
```

### 타이밍 힌트

```md
# 데모

<v-clicks>

1. 로그인
2. 대시보드 확인
3. 데이터 업로드
4. 리포트 생성

</v-clicks>

<!--
[click] 로그인: OAuth 2.0 사용 (예상 시간: 30초)

[click] 대시보드: 실시간 메트릭 확인 (예상 시간: 1분)

[click] 데이터 업로드: CSV 파일 드래그 앤 드롭 (예상 시간: 1분)

[click] 리포트: 자동 생성 및 PDF 다운로드 (예상 시간: 30초)

총 데모 시간: 3분
-->
```

---

## 애니메이션 조합 패턴

### 패턴 1: 순차적 리스트

```md
# 구현 단계

<v-clicks>

- <span v-mark.box>Phase 1</span>: 요구사항 분석
- <span v-mark.box>Phase 2</span>: 설계 및 프로토타입
- <span v-mark.box>Phase 3</span>: 개발 및 테스트
- <span v-mark.box>Phase 4</span>: 배포 및 모니터링

</v-clicks>
```

### 패턴 2: 강조 포인트

```md
# 핵심 메트릭

<div v-click>

응답 시간: <span v-mark.highlight.green>50ms</span>

</div>

<div v-click>

처리량: <span v-mark.highlight.blue>10,000 req/s</span>

</div>

<div v-click>

에러율: <span v-mark.highlight.red>0.01%</span>

</div>
```

### 패턴 3: 비교 강조

```md
# Before vs After

<div class="grid grid-cols-2 gap-8">

<div v-click>

## Before
- <span v-mark.strike-through.red>느린 로딩</span>
- <span v-mark.strike-through.red>높은 메모리 사용</span>
- <span v-mark.strike-through.red>복잡한 코드</span>

</div>

<div v-click>

## After
- <span v-mark.highlight.green>빠른 로딩</span>
- <span v-mark.highlight.green>낮은 메모리 사용</span>
- <span v-mark.highlight.green>간결한 코드</span>

</div>

</div>
```

### 패턴 4: 카드 애니메이션

```md
# 팀 소개

<div class="grid grid-cols-3 gap-4">

<div
  v-motion
  :initial="{ scale: 0, rotate: -10 }"
  :enter="{ scale: 1, rotate: 0, transition: { delay: 0 } }">

## Frontend
3명

</div>

<div
  v-motion
  :initial="{ scale: 0, rotate: -10 }"
  :enter="{ scale: 1, rotate: 0, transition: { delay: 200 } }">

## Backend
4명

</div>

<div
  v-motion
  :initial="{ scale: 0, rotate: -10 }"
  :enter="{ scale: 1, rotate: 0, transition: { delay: 400 } }">

## DevOps
2명

</div>

</div>
```

---

## 성능 최적화

### 애니메이션 수 제한

슬라이드당 클릭 수를 10개 이하로 유지하는 것이 좋습니다:

```md
---
clicks: 10  # 명시적으로 제한
---
```

### Transform 우선 사용

성능을 위해 `transform` 속성 사용:

```md
<!-- 좋음: GPU 가속 -->
<div v-motion :initial="{ x: -100 }" :enter="{ x: 0 }">

<!-- 나쁨: 레이아웃 리플로우 -->
<div v-motion :initial="{ left: '-100px' }" :enter="{ left: '0' }">
```

### 복잡한 애니메이션 그룹화

여러 요소를 컨테이너로 묶어서 애니메이션:

```md
<div v-motion :initial="{ opacity: 0 }" :enter="{ opacity: 1 }">
  <div>항목 1</div>
  <div>항목 2</div>
  <div>항목 3</div>
</div>
```

---

## 디버깅 팁

### 클릭 카운트 확인

개발자 도구에서 현재 클릭 상태 확인:

```js
// 브라우저 콘솔
$slidev.nav.clicks
```

### 애니메이션 속도 조절

CSS로 전역 애니메이션 속도 조절:

```css
<style>
.slidev-vclick-target {
  transition: all 0.3s ease !important;
}
</style>
```

### 애니메이션 비활성화 (테스트용)

```md
---
clicks: 0  # 모든 클릭 애니메이션 건너뛰기
---
```
