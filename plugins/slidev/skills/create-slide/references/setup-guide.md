# Slidev project setup guide

A full guide to setting up and deploying a Slidev project from scratch.

---

## 1. Prerequisites

Requirements for running Slidev:

- **Node.js**: 18.0.0 or higher (LTS version recommended)
- **Package Manager**: one of npm, pnpm, yarn

**Check versions:**
```bash
node --version  # must be v18.0.0 or higher
npm --version   # 8.0.0 or higher recommended
```

---

## 2. Project Initialization

### Basic install

```bash
# using npm
npm init slidev@latest

# using pnpm (faster)
pnpm create slidev

# using yarn
yarn create slidev
```

### Initialization process

Running the command prompts these questions:

1. **Project name**: becomes the directory name
2. **Choose a package manager**: npm/pnpm/yarn
3. **Choose a template**:
   - `starter`: the default template (recommended)
   - `blank`: an empty template
   - `custom`: user-defined

### Files created

```
my-presentation/
├── package.json          # project dependencies
├── slides.md             # main presentation file
├── README.md             # project description
└── node_modules/         # installed packages
```

---

## 3. Theme Installation

### How to install a theme

```bash
# popular themes
npm install @slidev/theme-apple-basic
npm install @slidev/theme-seriph
npm install @slidev/theme-default
npm install @slidev/theme-shibainu
npm install @slidev/theme-bricks
```

### Applying a theme

Add it to the headmatter at the top of `slides.md`:

```yaml
---
theme: apple-basic
---
```

### Automatic install

If you name a theme in the headmatter and run for the first time, it installs automatically:

```bash
# after setting theme: apple-basic in slides.md
npx slidev
# → @slidev/theme-apple-basic is installed automatically
```

### Available official themes

| Theme name | Package | Feature |
|----------|--------|------|
| Default | `@slidev/theme-default` | the default theme |
| Seriph | `@slidev/theme-seriph` | serif fonts, elegant design |
| Apple Basic | `@slidev/theme-apple-basic` | Apple style |
| Shibainu | `@slidev/theme-shibainu` | minimal design |
| Bricks | `@slidev/theme-bricks` | block style |

More themes: https://sli.dev/themes/gallery.html

---

## 4. Project Structure

### Standard directory structure

```
my-presentation/
├── package.json              # project config and dependencies
├── slides.md                 # main slide file
├── vercel.json              # Vercel deploy config (optional)
├── netlify.toml             # Netlify deploy config (optional)
│
├── components/              # custom Vue components
│   ├── MyComponent.vue
│   └── Counter.vue
│
├── public/                  # static files (images, fonts, etc.)
│   ├── images/
│   │   ├── logo.png
│   │   └── diagram.svg
│   └── fonts/
│       └── custom-font.woff2
│
├── pages/                   # split slide files (optional)
│   ├── 01-intro.md
│   ├── 02-features.md
│   └── 03-conclusion.md
│
├── styles/                  # custom styles
│   ├── index.css           # global CSS
│   └── custom.scss         # SCSS file (optional)
│
├── setup/                   # Vue app config (advanced)
│   ├── main.ts             # main config
│   └── shortcuts.ts        # keyboard shortcuts
│
└── snippets/               # reusable code snippets
    └── example.ts
```

### File-role descriptions

| File/folder | Purpose | Required |
|----------|------|----------|
| `slides.md` | main slide content | required |
| `components/` | reusable Vue components | optional |
| `public/` | static files (images, fonts) | optional |
| `pages/` | split slides into multiple files | optional |
| `styles/` | custom CSS/SCSS | optional |
| `setup/` | advanced Vue app config | optional |

---

## 5. Development Commands

### Run the dev server

```bash
# default run (uses slides.md)
npx slidev

# run a specific file
npx slidev presentation.md

# open the browser automatically
npx slidev --open

# specify a port
npx slidev --port 3030

# allow remote access (network presentation)
npx slidev --remote

# set a password
npx slidev --remote=your-password
```

### Build and deploy

```bash
# build as an SPA (for deployment)
npx slidev build

# specify the build output directory
npx slidev build --out dist

# set the base URL (subdirectory deployment)
npx slidev build --base /my-presentation/
```

### Export

```bash
# export to PDF
npx slidev export

# specify the PDF output file name
npx slidev export --output my-slides.pdf

# export to PNG images
npx slidev export --format png

# PNG output directory
npx slidev export --format png --output ./slides-images

# export to PowerPoint
npx slidev export --format pptx

# export only a specific slide range
npx slidev export --range 1,3-5,8
```

### Other commands

```bash
# check theme info
npx slidev theme

# generate a screenshot (thumbnail)
npx slidev export --format png --output ./screenshots --range 1

# check project info
npx slidev info
```

---

## 6. Configuration Options

### Full headmatter reference

The config written at the top of `slides.md`:

```yaml
---
# theme and style
theme: apple-basic              # choose a theme
background: /cover.jpg          # background image
class: text-center             # global CSS class
highlighter: shiki             # code highlighter (shiki/prism)
lineNumbers: true              # show code line numbers
monaco: true                   # enable the Monaco editor
remoteAssets: true             # download remote assets

# metadata
title: Presentation Title
titleTemplate: '%s - Slidev'
info: |
  ## Presentation description
  Can be written in Markdown

# layout
layout: cover                  # default layout
canvasWidth: 980              # canvas width

# features
download: true                 # show the download button
exportFilename: slides        # export file name
selectable: true              # text is selectable
colorSchema: auto             # color mode (auto/light/dark)
aspectRatio: 16/9             # aspect ratio (16/9, 4/3, 3/2)
transition: slide-left        # slide transition
mdc: true                     # enable MDC syntax

# drawing
drawings:
  enabled: true               # enable drawing
  persist: true              # persist drawings
  presenterOnly: false       # presenter-only drawing

# fonts
fonts:
  sans: Pretendard            # Sans-serif font
  serif: Noto Serif KR        # Serif font
  mono: D2Coding               # Monospace font
  weights: 200,400,700        # font weights
  provider: google            # font provider

# presenter mode
presenter: true               # enable presenter notes
htmlAttrs:
  lang: ko                    # HTML lang attribute

# recording
record: dev                   # recording mode (dev/build/true/false)

# advanced
css: unocss                   # CSS engine
routerMode: history           # router mode
plantUmlServer: https://www.plantuml.com/plantuml  # PlantUML server
---
```

### Font Configuration

#### Using Google Fonts

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

#### Using Local Fonts

```yaml
---
fonts:
  sans: My Custom Font
  local: My Custom Font
  provider: none
---
```

Place the font files in the `public/fonts/` directory:

```
public/
└── fonts/
    ├── MyCustomFont-Regular.woff2
    └── MyCustomFont-Bold.woff2
```

Add @font-face to `styles/index.css`:

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

#### Shiki (default, recommended)

```yaml
---
highlighter: shiki
highlightTheme:
  light: github-light
  dark: github-dark
---
```

Available themes: https://shiki.style/themes

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
  enabled: true               # enable the drawing feature
  persist: true              # persist drawings locally
  presenterOnly: false       # false: drawing available in all modes
  syncAll: true              # sync across all instances
---
```

**Shortcuts:**
- `d`: toggle drawing mode
- `c`: clear drawings
- `z`: undo

### UnoCSS Customization

Create a `unocss.config.ts` file:

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

Usage example:

```vue
<button class="btn">Click me</button>
<div class="card">Card content</div>
```

---

## 7. Deployment

### Netlify deployment

**Create netlify.toml:**

```toml
[build]
  publish = "dist"
  command = "npm run build"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

**Deploy steps:**

1. Push the project to GitHub
2. Choose "New site from Git" in Netlify
3. Connect the repository
4. Build command: `npm run build`
5. Publish directory: `dist`
6. Deploy

### Vercel deployment

**Create vercel.json:**

```json
{
  "buildCommand": "npm run build",
  "outputDirectory": "dist",
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

**Deploy steps:**

1. `npm i -g vercel` (install the Vercel CLI)
2. `vercel` (first deploy)
3. Confirm the settings
4. `vercel --prod` (production deploy)

Or from the Vercel web dashboard:
1. Click "Import Project"
2. Select the GitHub repository
3. Framework Preset: "Other"
4. Build Command: `npm run build`
5. Output Directory: `dist`
6. Deploy

### GitHub Pages deployment

**Create `.github/workflows/deploy.yml`:**

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

**GitHub Pages settings:**
1. Repository Settings → Pages
2. Source: choose "GitHub Actions"
3. Pushing code deploys automatically

### Static hosting (general)

**Build:**

```bash
npx slidev build
```

**Upload the generated `dist/` folder to a service such as:**
- AWS S3 + CloudFront
- Firebase Hosting
- Cloudflare Pages
- Surge.sh

**Surge.sh example:**

```bash
npm install -g surge
npx slidev build
cd dist
surge
```

---

## 8. Troubleshooting

### Common errors and fixes

#### 1. Theme loading failure

**Symptom:**
```
[vite] Error: Cannot find module '@slidev/theme-xxx'
```

**Fix:**
```bash
# install the theme manually
npm install @slidev/theme-xxx

# delete node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

#### 2. Font loading failure

**Symptom:** the font shows as the default font

**Fix:**

```yaml
# check the font provider in the headmatter
---
fonts:
  sans: Pretendard
  provider: google  # or none (local fonts)
---
```

For a local font, check that the file exists in `public/fonts/`.

#### 3. Build failure

**Symptom:**
```
[vite] Build failed with errors
```

**Fix:**

```bash
# clear the cache
rm -rf .slidev dist node_modules/.vite

# reinstall
npm install

# retry the build
npx slidev build

# debug in verbose mode
DEBUG=* npx slidev build
```

#### 4. Code highlighting error

**Symptom:** code blocks are not highlighted

**Fix:**

```yaml
---
highlighter: shiki  # or prism
---
```

```bash
# reinstall the Shiki language package
npm install shiki@latest
```

#### 5. Monaco editor error

**Symptom:** the Monaco editor does not work

**Fix:**

```yaml
---
monaco: true  # enable explicitly
---
```

```bash
# check the Monaco-related package
npm install monaco-editor@latest
```

#### 6. PDF/PNG export failure

**Symptom:**
```
Error: Failed to launch browser
```

**Fix:**

```bash
# install the Playwright browser
npx playwright install chromium

# install full system dependencies (Linux)
npx playwright install-deps

# permission issue (Linux)
sudo apt-get install -y chromium-browser
```

#### 7. Remote access not working

**Symptom:** ran with `--remote` but cannot connect from another device

**Fix:**

```bash
# check the host IP
hostname -I  # Linux
ipconfig     # Windows

# open the firewall port (3030)
sudo ufw allow 3030  # Linux

# explicit host binding
npx slidev --host 0.0.0.0 --remote
```

#### 8. UnoCSS classes not working

**Symptom:** UnoCSS utility classes do not apply styles

**Fix:**

```bash
# check the UnoCSS config
cat unocss.config.ts

# clear the cache
rm -rf .slidev node_modules/.vite
```

```yaml
# check the css engine in the headmatter
---
css: unocss
---
```

#### 9. Node.js version compatibility

**Symptom:**
```
Error: The engine "node" is incompatible with this module
```

**Fix:**

```bash
# check the Node.js version
node --version

# install Node.js 18+ (using nvm)
nvm install 18
nvm use 18

# or the latest LTS
nvm install --lts
```

#### 10. Image loading failure

**Symptom:** images do not display

**Fix:**

```markdown
<!-- images in the public/ directory start with / -->
![Logo](/images/logo.png)

<!-- relative paths do not work -->
![Logo](./images/logo.png)  ❌
```

```
public/
└── images/
    └── logo.png
```

### Debugging tips

```bash
# print detailed logs
DEBUG=vite:* npx slidev

# check the Vite config
npx slidev --debug

# check the browser devtools console
# F12 → Console tab
```

### Getting help

- **Official docs**: https://sli.dev
- **GitHub Issues**: https://github.com/slidevjs/slidev/issues
- **Discord**: https://chat.sli.dev

---

## Quick Reference

### Project-start checklist

- [ ] Confirm Node.js 18+ is installed
- [ ] Run `npm init slidev@latest`
- [ ] Choose and install a theme
- [ ] Set the headmatter in `slides.md`
- [ ] Run `npx slidev` to check the dev server
- [ ] Place image files in the `public/` directory
- [ ] Write custom components in `components/`
- [ ] Customize styles (`styles/index.css`)

### Frequently used commands

```bash
# development
npx slidev --open

# build
npx slidev build

# export to PDF
npx slidev export

# remote presentation
npx slidev --remote=password123
```

### Pre-deployment checklist

- [ ] Confirm `npx slidev build` succeeds locally
- [ ] Confirm the `dist/` folder is created
- [ ] Write the deploy config file (netlify.toml/vercel.json)
- [ ] Set the base URL (`--base` option)
- [ ] Set environment variables (if needed)
- [ ] Confirm HTTPS
- [ ] Responsive test (mobile/tablet)
```
