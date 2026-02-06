# CRO (Conversion Rate Optimization) Checklist

Optimize README for user adoption and engagement.

---

## The 5-Second Test

Can a visitor understand these in 5 seconds?

- [ ] What is this project?
- [ ] Who is it for?
- [ ] Why should I care?

If not, rewrite your header.

---

## Trust Signals

### Badges (Pick 3-5)

| Badge | Trust Signal | Priority |
|-------|--------------|----------|
| Build passing | "It works" | High |
| Version number | "Actively maintained" | High |
| Download count | "Others use this" | Medium |
| Coverage % | "Quality code" | Medium |
| License | "Safe to use" | High |
| TypeScript | "Modern tooling" | Low |
| Last commit | "Not abandoned" | Medium |

### Social Proof

- [ ] "Used by" section with recognizable names
- [ ] Star count (if significant: 1k+)
- [ ] Contributor count/avatars
- [ ] Testimonials or quotes (if available)

### Quality Indicators

- [ ] Benchmarks (if performance matters)
- [ ] Test coverage badge
- [ ] Security audit badge (if applicable)
- [ ] "Backed by" or sponsor logos

---

## Quick Start Optimization

### Time to First Success

Target: Under 5 minutes from landing to working result.

**Measure your quick start:**
1. Fresh machine test
2. Time each step
3. Identify friction points
4. Eliminate unnecessary steps

### Friction Reducers

- [ ] Single command install when possible
- [ ] Copy button on code blocks (GitHub provides this)
- [ ] Minimal configuration for first run
- [ ] Expected output shown ("You should see...")
- [ ] Troubleshooting link nearby

### Quick Start Anti-Patterns

| Friction | Fix |
|----------|-----|
| "First, install X, Y, Z..." | Use package manager |
| Long config file | Provide defaults |
| "Edit config.json with your..." | Use env vars or prompts |
| No verification step | Show expected output |
| Multiple choices at start | Pick one default path |

---

## Call-to-Action Hierarchy

### Primary CTA (One per section)

```markdown
## Get Started

[Quick Start Guide](#quick-start)  <- Primary, prominent
```

### Secondary CTAs

```markdown
[Documentation](link) | [Examples](link) | [Community](link)
```

### CTA Placement

| Position | Best CTA Type |
|----------|---------------|
| Header | Quick links (Docs, Demo, Discord) |
| After tagline | Quick Start link |
| After features | "Try it now" or Install |
| End of README | Contributing, Community |

### CTA Language

| Weak | Strong |
|------|--------|
| "Click here" | "Get started" |
| "Documentation" | "Learn more" |
| "See examples" | "Try these examples" |
| "Issues" | "Get help" |

---

## Visual Optimization

### Above the Fold

First screen should contain:
- [ ] Logo (recognizable identity)
- [ ] Name + tagline (what + why)
- [ ] Badges (trust)
- [ ] Quick links (navigation)
- [ ] Quick start OR hero image

### Visual Elements

| Element | When to Use | Impact |
|---------|-------------|--------|
| Logo | Always | Brand recognition |
| GIF demo | UI/interactive tools | +40% comprehension |
| Screenshot | Static output | Trust building |
| Architecture diagram | Complex systems | Clarity |
| Benchmark chart | Performance tools | Credibility |

### Visual Placement

```
[Logo]
[Badges]
[Tagline]
[Navigation links]
[Hero GIF/Screenshot]  <- Immediately after header
[Quick Start]
[Features]
...
```

---

## Progressive Disclosure

### Information Hierarchy

```
Level 1: What is this? (Header, tagline)
Level 2: Why use it? (Features, benefits)
Level 3: How to use? (Quick start, examples)
Level 4: Deep details (API, configuration)
Level 5: Advanced (Internals, contributing)
```

### Collapsible Sections

Use `<details>` for:
- Advanced configuration
- Platform-specific instructions
- Long code examples
- Troubleshooting guides

```markdown
<details>
<summary>Advanced Configuration</summary>

Content hidden until clicked...

</details>
```

---

## Audience Targeting

### Decision Tree for Heterogeneous Audiences

```markdown
## Installation

**For quick evaluation:**
```bash
npx tool-name
```

**For project integration:**
```bash
npm install tool-name
```

**For contributors:**
```bash
git clone ... && npm install
```
```

### Skill Level Accommodation

| Audience | Needs |
|----------|-------|
| Beginners | Definitions, full examples, prerequisites |
| Intermediate | Options, configuration, API reference |
| Advanced | Internals, extension points, contributing |

---

## Friction Points Audit

### Common Friction Sources

- [ ] Prerequisites not listed
- [ ] Missing platform-specific instructions
- [ ] No troubleshooting section
- [ ] Outdated screenshots
- [ ] Dead links
- [ ] Jargon without explanation
- [ ] Too many choices at once
- [ ] No expected output shown

### Self-Test Questions

1. Can someone with no context understand the first paragraph?
2. Can they install in under 2 minutes?
3. Can they see it working in under 5 minutes?
4. Do they know where to get help if stuck?
5. Is there a clear next step after quick start?

---

## Conversion Funnel

```
Visitor -> Reader -> Installer -> User -> Contributor
   |         |          |          |          |
   v         v          v          v          v
 Header   Features  Quick Start  Docs   Contributing
```

### Optimize Each Stage

| Stage | Goal | Optimize |
|-------|------|----------|
| Visitor -> Reader | "This looks useful" | Header, badges, tagline |
| Reader -> Installer | "I want to try this" | Features, demo, social proof |
| Installer -> User | "This works!" | Quick start, verification |
| User -> Contributor | "I want to help" | Contributing guide, issues |

---

## A/B Testing Ideas

If you have analytics on your repo/docs:

1. **Header variants**: Logo vs no logo, badge count
2. **Quick start**: Steps vs single command
3. **Feature format**: List vs table vs cards
4. **CTA text**: "Get Started" vs "Install" vs "Try Now"
5. **Demo type**: GIF vs video vs interactive

---

## Checklist Summary

### Must Have (Critical)

- [ ] Clear tagline (what + who + why)
- [ ] 3-5 trust badges
- [ ] Quick start under 5 minutes
- [ ] Copy-paste commands
- [ ] Expected output shown
- [ ] Help/troubleshooting link

### Should Have (Important)

- [ ] Visual demo (GIF/screenshot)
- [ ] "Used by" or social proof
- [ ] Progressive disclosure
- [ ] Platform-specific instructions
- [ ] Clear CTA hierarchy

### Nice to Have (Enhancement)

- [ ] One-click deploy buttons
- [ ] Interactive playground link
- [ ] Video walkthrough
- [ ] Benchmark comparisons
- [ ] Limitations section (builds trust)

---

## Quick Wins

Highest impact, lowest effort improvements:

1. **Add "You should see:" after install** - Immediate verification
2. **Add 3 badges** - Instant credibility
3. **Move quick start up** - Reduce scroll to value
4. **Add GIF** - Visual proof it works
5. **Add "Used by" line** - Social proof
6. **Link troubleshooting** - Safety net reduces anxiety
