# Icon System Reference

> **Applicability:**
> - **Minimal**: Carbon (`i-carbon:`) and MDI (`mdi-`) for bullet icons and UI elements only. Use class syntax.
> - **Rich**: All icon sets. Use attributify syntax (no `class=""` wrapping). Requires `presetIcons()` in `uno.config.ts` with `prefix: 'i-'`.

---

## 1. Installation

```bash
# Core sets (sufficient for most presentations)
npm add -D @iconify-json/carbon @iconify-json/logos @iconify-json/mdi

# Optional for tech/dev talks
npm add -D @iconify-json/devicon @iconify-json/ri

# Optional for additional coverage
npm add -D @iconify-json/simple-icons @iconify-json/bi @iconify-json/fluent
```

Add to `uno.config.ts`:

```ts
import config from '@slidev/client/uno.config'
import { mergeConfigs, presetAttributify, presetIcons, presetWind3 } from 'unocss'

export default mergeConfigs([config, {
  presets: [
    presetWind3({ dark: 'class' }),
    presetAttributify(),
    presetIcons({
      prefix: 'i-',
      extraProperties: { display: 'inline-block', 'vertical-align': 'middle' },
    }),
  ],
}])
```

---

## 2. Icon Sets Overview

| Set | Prefix | Use Case | Example Icons |
|-----|--------|----------|---------------|
| Carbon | `i-carbon:` | UI icons, actions, status | `warning-alt`, `checkmark-filled`, `arrow-right`, `chip`, `cube`, `close` |
| Logos | `i-logos:` | Tech brand logos | `kubernetes`, `docker-icon`, `react`, `python`, `jupyter` |
| MDI | `mdi-` | General purpose (class mode) | `mdi-arrow-right`, `mdi-github`, `mdi-check` |
| Devicon | `i-devicon:` | Dev tool logos | `python`, `typescript`, `go`, `kubernetes`, `pytorch` |
| Ri | `i-ri:` | Remix icons | `github-fill`, `twitter-x-fill` |
| Simple Icons | `i-simple-icons:` | Brand icons | `github`, `docker`, `kubernetes` |
| BI | `i-bi:` | Bootstrap icons | `gpu-card`, `nvidia` |
| Fluent | `i-fluent:` | Microsoft Fluent UI | `error-circle-settings-20-regular`, `globe-error-20-regular` |

---

## 3. Syntax - Attributify Mode (Rich)

Preferred for Rich presentations. No `class=""` needed.

```html
<!-- Icon only -->
<div i-carbon:warning-alt text-red-300 text-xl mr-2 />

<!-- Brand logo -->
<div i-logos:kubernetes text-3xl mr-3 />

<!-- Large hero icon -->
<div i-carbon:chip h-20 w-20 text-blue-300 />

<!-- Icon in header bar -->
<div bg="blue-800/40" px-4 py-2 flex items-center>
  <div i-carbon:cube text-blue-300 text-xl mr-2 />
  <span font-bold>Section Title</span>
</div>
```

---

## 4. Syntax - Class Mode (Minimal)

For Minimal presentations or when attributify is not configured.

```html
<!-- Class attribute syntax -->
<div class="i-carbon:warning-alt text-red-300 text-xl mr-2" />

<!-- Component tag syntax (Slidev supports this) -->
<carbon:warning-alt class="text-red-300 text-xl mr-2" />

<!-- MDI prefix style -->
<mdi-arrow-right class="text-green-400 text-xl" />
```

---

## 5. Size Patterns (from KubeCon presentations)

| Context | Attributes | Approximate Size |
|---------|-----------|-----------------|
| Inline text icon | `text-sm mr-1` | ~14px |
| Header bar icon | `text-xl mr-2` | ~20px |
| Medium brand logo | `text-3xl mr-3` | ~30px |
| Large card icon | `h-20 w-20` | 80px |
| Hero icon | `text-[96px]` or `text-8xl` | 96px |

```html
<!-- Inline text -->
<div i-carbon:arrow-right text-sm mr-1 />

<!-- Card header bar -->
<div i-carbon:warning-alt text-red-300 text-xl mr-2 />

<!-- Medium brand logo next to title -->
<div i-logos:kubernetes text-3xl mr-3 />

<!-- Large centered card icon -->
<div i-carbon:chip h-20 w-20 text-blue-300 />

<!-- Full-size hero -->
<div class="text-[96px] i-logos:python" />
```

---

## 6. Inline Alignment

Icons in inline text contexts need vertical adjustment:

```html
<!-- translate-y-0.8 aligns icon baseline with text -->
<div inline-block mr-1 translate-y-0.8 i-devicon:pytorch />
<span>PyTorch training loop</span>
```

For MDI in class mode:

```html
<mdi-github class="inline-block mr-1 translate-y-0.5" />
```

---

## 7. Brand Color Mapping

Use official hex values instead of Tailwind color approximations for brand accuracy.

```html
<!-- Technology brands -->
<span text="[#5791f7]">Kubernetes</span>
<span text="[#f6432f]">PyTorch</span>
<span text="[#ff6f00]">TensorFlow</span>
<span text="[#2496ED]">Docker</span>
<span text="[#326CE5]">K8s blue</span>
<span text="[#f97248]">Prometheus</span>
<span text="[#667fe3]">OpenTelemetry</span>
<span text="[#5e98f6]">Jax</span>
<span text="[#64b023]">NCCL</span>
<span text="[#1577fc]">DLRover</span>
```

Combine with `i-logos:` icons for consistent brand representation:

```html
<div flex items-center gap-2>
  <div i-logos:kubernetes text-2xl />
  <span text="[#5791f7]" font-semibold>Kubernetes</span>
</div>
```

---

## 8. Context-Based Icon Recommendations

### Technical / Infrastructure Talks (Kubernetes, Docker, ML)

Primary sets: `carbon` + `logos` + `devicon`

| Situation | Recommended Icons |
|-----------|------------------|
| Warning / error | `i-carbon:warning-alt`, `i-carbon:data-error` |
| Success / checkmark | `i-carbon:checkmark-filled`, `i-carbon:checkmark-outline` |
| Kubernetes | `i-logos:kubernetes`, `i-devicon:kubernetes` |
| Docker | `i-logos:docker-icon`, `i-devicon:docker` |
| Python | `i-logos:python`, `i-devicon:python` |
| GPU / hardware | `i-bi:gpu-card`, `i-bi:nvidia`, `i-carbon:chip` |
| Cloud / infra | `i-carbon:cloud-alerting`, `i-carbon:edge-node` |
| Container | `i-carbon:web-services-container` |
| Microservices | `i-carbon:microservices-1` |
| Arrow / flow | `i-carbon:arrow-right`, `i-carbon:flow-stream-reference` |
| GitHub | `i-ri:github-fill`, `i-simple-icons:github` |

### Business / Product Talks

Primary sets: `carbon` + `mdi`

| Situation | Recommended Icons |
|-----------|------------------|
| Bullet point | `i-carbon:arrow-right`, `mdi-check` |
| Feature highlight | `i-carbon:star`, `i-carbon:lightning` |
| Problem / risk | `i-carbon:warning-alt`, `i-carbon:close-filled` |
| Solution / benefit | `i-carbon:checkmark-filled`, `i-carbon:idea` |
| Time / schedule | `i-carbon:time`, `i-carbon:event-schedule` |
| Team / people | `i-carbon:user`, `i-carbon:group` |

### Academic / Research Talks

Primary sets: `carbon` + `mdi` (minimal icon use; reserve for key callouts only)

| Situation | Recommended Icons |
|-----------|------------------|
| Citation / reference | `i-carbon:document` |
| Data / chart | `i-carbon:chart-bar` |
| Algorithm step | `i-carbon:arrow-right` |
| Warning / caveat | `i-carbon:warning-alt` |

---

## 9. Commonly Used Carbon Icons Quick Reference

```
# Status
i-carbon:warning-alt          warning triangle
i-carbon:checkmark-filled     filled checkmark
i-carbon:checkmark-outline    outline checkmark
i-carbon:close-filled         filled X
i-carbon:close                outline X
i-carbon:data-error           data error indicator
i-carbon:cloud-alerting       cloud alert

# Navigation / Flow
i-carbon:arrow-right          right arrow
i-carbon:chevron-down         chevron down
i-carbon:chevron-up           chevron up
i-carbon:flow-stream-reference flow with reference

# Infrastructure
i-carbon:cube                 3D cube / service
i-carbon:chip                 microchip / hardware
i-carbon:edge-node            edge node
i-carbon:microservices-1      microservices
i-carbon:web-services-container container
i-carbon:kubernetes-operator  K8s operator
i-carbon:name-space           namespace
i-carbon:ibm-cloud-bare-metal-servers-vpc server

# Data / ML
i-carbon:hinton-plot          matrix/plot visualization
i-carbon:ibm-watson-openscale AI/ML platform
i-carbon:exam-mode            evaluation/testing

# People / Time
i-carbon:user                 single user
i-carbon:group                group of users
i-carbon:time                 clock
i-carbon:event-schedule       calendar event
```
