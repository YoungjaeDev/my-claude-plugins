# Slidev 프로젝트 설정 가이드

Slidev 프로젝트를 처음부터 설정하고 배포하는 전체 가이드입니다.

---

## 1. Prerequisites

Slidev 실행을 위한 필수 요구사항:

- **Node.js**: 18.0.0 이상 (LTS 버전 권장)
- **Package Manager**: npm, pnpm, yarn 중 하나

**버전 확인:**
```bash
node --version  # v18.0.0 이상이어야 함
npm --version   # 8.0.0 이상 권장
```

---

## 2. Project Initialization

### 기본 설치

```bash
# npm 사용
npm init slidev@latest

# pnpm 사용 (더 빠름)
pnpm create slidev

# yarn 사용
yarn create slidev
```

### 초기화 프로세스

명령 실행 시 다음 질문들이 표시됩니다:

1. **프로젝트 이름**: 디렉토리명이 됩니다
2. **패키지 매니저 선택**: npm/pnpm/yarn
3. **템플릿 선택**:
   - `starter`: 기본 템플릿 (권장)
   - `blank`: 빈 템플릿
   - `custom`: 사용자 정의

### 생성되는 파일들

```
my-presentation/
├── package.json          # 프로젝트 의존성
├── slides.md             # 메인 프레젠테이션 파일
├── README.md             # 프로젝트 설명
└── node_modules/         # 설치된 패키지들
```

---

## 3. Theme Installation

### 테마 설치 방법

```bash
# 인기 있는 테마들
npm install @slidev/theme-apple-basic
npm install @slidev/theme-seriph
npm install @slidev/theme-default
npm install @slidev/theme-shibainu
npm install @slidev/theme-bricks
```

### 테마 적용

`slides.md` 파일 상단 headmatter에 추가:

```yaml
---
theme: apple-basic
---
```

### 자동 설치

테마를 headmatter에 지정하고 처음 실행하면 자동으로 설치됩니다:

```bash
# slides.md에 theme: apple-basic 설정 후
npx slidev
# → @slidev/theme-apple-basic이 자동으로 설치됨
```

### 사용 가능한 공식 테마

| 테마 이름 | 패키지 | 특징 |
|----------|--------|------|
| Default | `@slidev/theme-default` | 기본 테마 |
| Seriph | `@slidev/theme-seriph` | 세리프 폰트, 우아한 디자인 |
| Apple Basic | `@slidev/theme-apple-basic` | Apple 스타일 |
| Shibainu | `@slidev/theme-shibainu` | 미니멀한 디자인 |
| Bricks | `@slidev/theme-bricks` | 블록 스타일 |

더 많은 테마: https://sli.dev/themes/gallery.html

---

## 4. Project Structure

### 표준 디렉토리 구조

```
my-presentation/
├── package.json              # 프로젝트 설정 및 의존성
├── slides.md                 # 메인 슬라이드 파일
├── vercel.json              # Vercel 배포 설정 (선택)
├── netlify.toml             # Netlify 배포 설정 (선택)
│
├── components/              # 커스텀 Vue 컴포넌트
│   ├── MyComponent.vue
│   └── Counter.vue
│
├── public/                  # 정적 파일 (이미지, 폰트 등)
│   ├── images/
│   │   ├── logo.png
│   │   └── diagram.svg
│   └── fonts/
│       └── custom-font.woff2
│
├── pages/                   # 슬라이드 분할 파일 (선택)
│   ├── 01-intro.md
│   ├── 02-features.md
│   └── 03-conclusion.md
│
├── styles/                  # 커스텀 스타일
│   ├── index.css           # 전역 CSS
│   └── custom.scss         # SCSS 파일 (선택)
│
├── setup/                   # Vue 앱 설정 (고급)
│   ├── main.ts             # 메인 설정
│   └── shortcuts.ts        # 키보드 단축키
│
└── snippets/               # 재사용 가능한 코드 스니펫
    └── example.ts
```

### 파일 역할 설명

| 파일/폴더 | 용도 | 필수 여부 |
|----------|------|----------|
| `slides.md` | 메인 슬라이드 콘텐츠 | 필수 |
| `components/` | 재사용 가능한 Vue 컴포넌트 | 선택 |
| `public/` | 정적 파일 (이미지, 폰트) | 선택 |
| `pages/` | 슬라이드를 여러 파일로 분할 | 선택 |
| `styles/` | 커스텀 CSS/SCSS | 선택 |
| `setup/` | Vue 앱 고급 설정 | 선택 |

---

## 5. Development Commands

### 개발 서버 실행

```bash
# 기본 실행 (slides.md 사용)
npx slidev

# 특정 파일 실행
npx slidev presentation.md

# 브라우저 자동 열기
npx slidev --open

# 포트 지정
npx slidev --port 3030

# 원격 접속 허용 (네트워크 프레젠테이션)
npx slidev --remote

# 비밀번호 설정
npx slidev --remote=your-password
```

### 빌드 및 배포

```bash
# SPA로 빌드 (배포용)
npx slidev build

# 빌드 출력 디렉토리 지정
npx slidev build --out dist

# Base URL 설정 (서브디렉토리 배포)
npx slidev build --base /my-presentation/
```

### 내보내기 (Export)

```bash
# PDF로 내보내기
npx slidev export

# PDF 출력 파일명 지정
npx slidev export --output my-slides.pdf

# PNG 이미지로 내보내기
npx slidev export --format png

# PNG 출력 디렉토리
npx slidev export --format png --output ./slides-images

# PowerPoint로 내보내기
npx slidev export --format pptx

# 특정 슬라이드 범위만 내보내기
npx slidev export --range 1,3-5,8
```

### 기타 명령어

```bash
# 테마 정보 확인
npx slidev theme

# 스크린샷 생성 (썸네일)
npx slidev export --format png --output ./screenshots --range 1

# 프로젝트 정보 확인
npx slidev info
```

---

## 6. Configuration Options

### Headmatter 전체 레퍼런스

`slides.md` 파일 상단에 작성하는 설정:

```yaml
---
# 테마 및 스타일
theme: apple-basic              # 테마 선택
background: /cover.jpg          # 배경 이미지
class: text-center             # 전역 CSS 클래스
highlighter: shiki             # 코드 하이라이터 (shiki/prism)
lineNumbers: true              # 코드 라인 번호 표시
monaco: true                   # Monaco 에디터 활성화
remoteAssets: true             # 원격 에셋 다운로드

# 메타데이터
title: 프레젠테이션 제목
titleTemplate: '%s - Slidev'
info: |
  ## 프레젠테이션 설명
  Markdown으로 작성 가능

# 레이아웃
layout: cover                  # 기본 레이아웃
canvasWidth: 980              # 캔버스 너비

# 기능
download: true                 # 다운로드 버튼 표시
exportFilename: slides        # 내보내기 파일명
selectable: true              # 텍스트 선택 가능
colorSchema: auto             # 색상 모드 (auto/light/dark)
aspectRatio: 16/9             # 화면 비율 (16/9, 4/3, 3/2)
transition: slide-left        # 슬라이드 전환 효과
mdc: true                     # MDC 구문 활성화

# 드로잉
drawings:
  enabled: true               # 드로잉 활성화
  persist: true              # 드로잉 저장
  presenterOnly: false       # 발표자만 드로잉

# 폰트
fonts:
  sans: Pretendard            # Sans-serif 폰트
  serif: Noto Serif KR        # Serif 폰트
  mono: D2Coding               # Monospace 폰트
  weights: 200,400,700        # 폰트 weight
  provider: google            # 폰트 제공자

# 발표자 모드
presenter: true               # 발표자 노트 활성화
htmlAttrs:
  lang: ko                    # HTML lang 속성

# 녹화
record: dev                   # 녹화 모드 (dev/build/true/false)

# 고급
css: unocss                   # CSS 엔진
routerMode: history           # 라우터 모드
plantUmlServer: https://www.plantuml.com/plantuml  # PlantUML 서버
---
```

### Font Configuration

#### Google Fonts 사용

```yaml
---
fonts:
  sans: Roboto
  serif: Noto Serif
  mono: Fira Code
  weights: 300,400,700,900
  provider: google
---
```

#### Local Fonts 사용

```yaml
---
fonts:
  sans: My Custom Font
  local: My Custom Font
  provider: none
---
```

`public/fonts/` 디렉토리에 폰트 파일 배치:

```
public/
└── fonts/
    ├── MyCustomFont-Regular.woff2
    └── MyCustomFont-Bold.woff2
```

`styles/index.css`에 @font-face 추가:

```css
@font-face {
  font-family: 'My Custom Font';
  src: url('/fonts/MyCustomFont-Regular.woff2') format('woff2');
  font-weight: 400;
}

@font-face {
  font-family: 'My Custom Font';
  src: url('/fonts/MyCustomFont-Bold.woff2') format('woff2');
  font-weight: 700;
}
```

### Highlighter Configuration

#### Shiki (기본, 권장)

```yaml
---
highlighter: shiki
highlightTheme:
  light: github-light
  dark: github-dark
---
```

사용 가능한 테마: https://shiki.style/themes

#### Prism

```yaml
---
highlighter: prism
---
```

### Drawing/Annotation Setup

```yaml
---
drawings:
  enabled: true               # 드로잉 기능 활성화
  persist: true              # 드로잉을 로컬에 저장
  presenterOnly: false       # false: 모든 모드에서 드로잉 가능
  syncAll: true              # 모든 인스턴스 간 동기화
---
```

**단축키:**
- `d`: 드로잉 모드 토글
- `c`: 드로잉 지우기
- `z`: 실행 취소

### UnoCSS Customization

`unocss.config.ts` 파일 생성:

```typescript
import { defineConfig, presetUno, presetAttributify } from 'unocss'

export default defineConfig({
  presets: [
    presetUno(),
    presetAttributify(),
  ],
  shortcuts: {
    'btn': 'px-4 py-2 rounded bg-blue-500 text-white hover:bg-blue-600',
    'card': 'p-6 rounded-lg shadow-lg bg-white dark:bg-gray-800',
  },
  theme: {
    colors: {
      primary: '#3b82f6',
      secondary: '#8b5cf6',
    },
  },
})
```

사용 예시:

```vue
<button class="btn">클릭하세요</button>
<div class="card">카드 콘텐츠</div>
```

---

## 7. Deployment

### Netlify 배포

**netlify.toml 생성:**

```toml
[build]
  publish = "dist"
  command = "npm run build"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

**배포 단계:**

1. GitHub에 프로젝트 푸시
2. Netlify에서 "New site from Git" 선택
3. 레포지토리 연결
4. Build command: `npm run build`
5. Publish directory: `dist`
6. Deploy

### Vercel 배포

**vercel.json 생성:**

```json
{
  "buildCommand": "npm run build",
  "outputDirectory": "dist",
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

**배포 단계:**

1. `npm i -g vercel` (Vercel CLI 설치)
2. `vercel` (첫 배포)
3. 설정 확인
4. `vercel --prod` (프로덕션 배포)

또는 Vercel 웹 대시보드에서:
1. "Import Project" 클릭
2. GitHub 레포지토리 선택
3. Framework Preset: "Other"
4. Build Command: `npm run build`
5. Output Directory: `dist`
6. Deploy

### GitHub Pages 배포

**`.github/workflows/deploy.yml` 생성:**

```yaml
name: Deploy Slidev to GitHub Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: actions/setup-node@v3
        with:
          node-version: 18

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build -- --base /${{ github.event.repository.name }}/

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v2
        with:
          path: dist

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v2
```

**GitHub Pages 설정:**
1. 레포지토리 Settings → Pages
2. Source: "GitHub Actions" 선택
3. 코드 푸시하면 자동 배포

### 정적 호스팅 (일반)

**빌드:**

```bash
npx slidev build
```

**생성된 `dist/` 폴더를 다음 서비스에 업로드:**
- AWS S3 + CloudFront
- Firebase Hosting
- Cloudflare Pages
- Surge.sh

**Surge.sh 예시:**

```bash
npm install -g surge
npx slidev build
cd dist
surge
```

---

## 8. Troubleshooting

### 공통 오류 및 해결 방법

#### 1. 테마 로딩 실패

**증상:**
```
[vite] Error: Cannot find module '@slidev/theme-xxx'
```

**해결:**
```bash
# 테마 수동 설치
npm install @slidev/theme-xxx

# node_modules 삭제 후 재설치
rm -rf node_modules package-lock.json
npm install
```

#### 2. 폰트 로딩 실패

**증상:** 폰트가 기본 폰트로 표시됨

**해결:**

```yaml
# headmatter에서 폰트 provider 확인
---
fonts:
  sans: Pretendard
  provider: google  # 또는 none (로컬 폰트)
---
```

로컬 폰트인 경우 `public/fonts/`에 파일이 있는지 확인.

#### 3. Build 실패

**증상:**
```
[vite] Build failed with errors
```

**해결:**

```bash
# 캐시 삭제
rm -rf .slidev dist node_modules/.vite

# 재설치
npm install

# 빌드 재시도
npx slidev build

# Verbose 모드로 디버깅
DEBUG=* npx slidev build
```

#### 4. 코드 하이라이팅 오류

**증상:** 코드 블록이 하이라이트되지 않음

**해결:**

```yaml
---
highlighter: shiki  # 또는 prism
---
```

```bash
# Shiki 언어 패키지 재설치
npm install shiki@latest
```

#### 5. Monaco 에디터 오류

**증상:** Monaco 에디터가 작동하지 않음

**해결:**

```yaml
---
monaco: true  # 명시적으로 활성화
---
```

```bash
# Monaco 관련 패키지 확인
npm install monaco-editor@latest
```

#### 6. PDF/PNG 내보내기 실패

**증상:**
```
Error: Failed to launch browser
```

**해결:**

```bash
# Playwright 브라우저 설치
npx playwright install chromium

# 전체 시스템 의존성 설치 (Linux)
npx playwright install-deps

# 권한 문제 (Linux)
sudo apt-get install -y chromium-browser
```

#### 7. 원격 접속 안 됨

**증상:** `--remote` 옵션으로 실행했으나 다른 기기에서 접속 불가

**해결:**

```bash
# 호스트 IP 확인
hostname -I  # Linux
ipconfig     # Windows

# 방화벽 포트 개방 (3030)
sudo ufw allow 3030  # Linux

# 명시적 호스트 바인딩
npx slidev --host 0.0.0.0 --remote
```

#### 8. UnoCSS 클래스 작동 안 함

**증상:** UnoCSS 유틸리티 클래스가 스타일 적용 안 됨

**해결:**

```bash
# UnoCSS 설정 확인
cat unocss.config.ts

# 캐시 삭제
rm -rf .slidev node_modules/.vite
```

```yaml
# headmatter에서 css 엔진 확인
---
css: unocss
---
```

#### 9. Node.js 버전 호환성

**증상:**
```
Error: The engine "node" is incompatible with this module
```

**해결:**

```bash
# Node.js 버전 확인
node --version

# Node.js 18+ 설치 (nvm 사용)
nvm install 18
nvm use 18

# 또는 최신 LTS
nvm install --lts
```

#### 10. 이미지 로딩 실패

**증상:** 이미지가 표시되지 않음

**해결:**

```markdown
<!-- public/ 디렉토리 이미지는 / 로 시작 -->
![Logo](/images/logo.png)

<!-- 상대 경로는 작동하지 않음 -->
![Logo](./images/logo.png)  ❌
```

```
public/
└── images/
    └── logo.png
```

### 디버깅 팁

```bash
# 상세 로그 출력
DEBUG=vite:* npx slidev

# Vite 설정 확인
npx slidev --debug

# 브라우저 개발자 도구 콘솔 확인
# F12 → Console 탭
```

### 도움 받기

- **공식 문서**: https://sli.dev
- **GitHub Issues**: https://github.com/slidevjs/slidev/issues
- **Discord**: https://chat.sli.dev

---

## Quick Reference

### 프로젝트 시작 체크리스트

- [ ] Node.js 18+ 설치 확인
- [ ] `npm init slidev@latest` 실행
- [ ] 테마 선택 및 설치
- [ ] `slides.md`에 headmatter 설정
- [ ] `npx slidev` 실행하여 개발 서버 확인
- [ ] 이미지 파일을 `public/` 디렉토리에 배치
- [ ] 커스텀 컴포넌트를 `components/`에 작성
- [ ] 스타일 커스터마이징 (`styles/index.css`)

### 자주 사용하는 명령어

```bash
# 개발
npx slidev --open

# 빌드
npx slidev build

# PDF 내보내기
npx slidev export

# 원격 프레젠테이션
npx slidev --remote=password123
```

### 배포 전 체크리스트

- [ ] `npx slidev build` 로컬 빌드 성공 확인
- [ ] `dist/` 폴더 생성 확인
- [ ] 배포 설정 파일 작성 (netlify.toml/vercel.json)
- [ ] Base URL 설정 (`--base` 옵션)
- [ ] 환경 변수 설정 (필요시)
- [ ] HTTPS 적용 확인
- [ ] 반응형 테스트 (모바일/태블릿)
