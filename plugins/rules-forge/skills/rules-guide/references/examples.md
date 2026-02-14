# Project Type Examples

## Python ML/DL Project

**Input:**
```
Project: Deepfake detection using DINOv3-ViT with LoRA adaptation
Tech: Python, PyTorch, Optuna, YOLO, Gradio
```

**Output Structure:**
```
./CLAUDE.md (root - overview + @imports)
.claude/rules/
  - models.md       # paths: src/models/**/*.py
  - data.md         # paths: src/data/**/*.py
  - inference.md    # paths: src/inference/**/*.py
  - optimization.md # paths: src/optimization/**/*.py
  - labeling.md     # paths: src/labeling/**/*.py
```

**Sample Root CLAUDE.md:**
```markdown
# CLAUDE.md

## Project Context

Deepfake detection competition project using DINOv3-ViT with LoRA adaptation.
Tech: Python 3.11, PyTorch, Optuna, YOLO-Face, Gradio

## Operational Commands

```bash
uv sync
uv run python run_inference.py
uv run pytest tests/
```

## Golden Rules

### Immutable

- BGR to RGB conversion required for all OpenCV inputs
- LoRA rank/alpha must match checkpoint exactly

### Do's

- Use albumentations for image augmentation
- Back-half sampling for video inference

### Don'ts

- Optimize solely for local metrics (inverse LDB correlation)
- Use system Python directly

## Modular Rules

See @.claude/rules/models.md for detector architecture and checkpoints
See @.claude/rules/data.md for preprocessing, caching, face detection
See @.claude/rules/inference.md for prediction pipeline and aggregation
See @.claude/rules/optimization.md for Optuna hyperparameter tuning
```

---

## Web Application (Fullstack)

**Input:**
```
Project: SaaS dashboard with user auth and billing
Tech: Next.js 14, TypeScript, Prisma, Stripe, Tailwind
```

**Output Structure:**
```
./CLAUDE.md (root)
.claude/rules/
  - api.md          # paths: app/api/**/*
  - components.md   # paths: components/**/*
  - auth.md         # paths: lib/auth/**/*
  - billing.md      # paths: lib/billing/**/*
  - db.md           # paths: prisma/**/*
```

**Sample Root CLAUDE.md:**
```markdown
# CLAUDE.md

## Project Context

SaaS dashboard with authentication, team management, and Stripe billing.
Tech: Next.js 14 (App Router), TypeScript, Prisma, Stripe, Tailwind CSS

## Operational Commands

```bash
pnpm install
pnpm dev
pnpm test
pnpm db:push
```

## Golden Rules

### Immutable

- Never commit .env files
- All API routes require authentication middleware

### Do's

- Use server components by default
- Validate all inputs with Zod

### Don'ts

- Store API keys in client code
- Skip error boundaries

## Modular Rules

See @.claude/rules/api.md for API route patterns
See @.claude/rules/components.md for UI component guidelines
See @.claude/rules/auth.md for authentication flow
See @.claude/rules/billing.md for Stripe integration
See @.claude/rules/db.md for Prisma schema conventions
```

---

## CLI Tool

**Input:**
```
Project: CLI for managing cloud infrastructure
Tech: Rust, clap, tokio, AWS SDK
```

**Output Structure:**
```
./CLAUDE.md (root)
.claude/rules/
  - commands.md     # paths: src/commands/**/*
  - core.md         # paths: src/core/**/*
  - aws.md          # paths: src/aws/**/*
```

**Sample Root CLAUDE.md:**
```markdown
# CLAUDE.md

## Project Context

CLI tool for managing AWS infrastructure with declarative configs.
Tech: Rust, clap (CLI parsing), tokio (async), AWS SDK

## Operational Commands

```bash
cargo build --release
cargo test
cargo run -- --help
```

## Golden Rules

### Immutable

- All AWS operations must be idempotent
- Never store credentials in code

### Do's

- Use structured logging with tracing
- Provide --dry-run for destructive operations

### Don'ts

- Block the async runtime
- Panic in library code

## Modular Rules

See @.claude/rules/commands.md for CLI command structure
See @.claude/rules/core.md for business logic patterns
See @.claude/rules/aws.md for AWS SDK usage
```

---

## Monorepo

**Input:**
```
Project: E-commerce platform with web, mobile API, and shared packages
Tech: Turborepo, Next.js, Fastify, React Native, TypeScript
```

**Output Structure:**
```
./CLAUDE.md (root - routing only)
apps/
  web/CLAUDE.md           # Next.js storefront
  api/CLAUDE.md           # Fastify backend
  mobile/CLAUDE.md        # React Native app
packages/
  shared/CLAUDE.md        # Shared utilities
  ui/CLAUDE.md            # Component library
infra/CLAUDE.md           # Terraform/Pulumi
```

**Sample Root CLAUDE.md:**
```markdown
# CLAUDE.md

## Project Context

E-commerce platform monorepo with web storefront, API, mobile app, and shared packages.
Tech: Turborepo, pnpm workspaces, TypeScript throughout

## Operational Commands

```bash
pnpm install
pnpm dev           # Run all apps
pnpm build         # Build all packages
pnpm test          # Test all packages
```

## Golden Rules

### Immutable

- All packages must have explicit dependencies (no implicit imports)
- Shared types live in @repo/shared only

### Do's

- Use workspace protocol for internal deps
- Run affected tests before PR

### Don'ts

- Import directly from other apps
- Skip the build step for packages

## App-Specific Rules

Web storefront: @apps/web/CLAUDE.md
API server: @apps/api/CLAUDE.md
Mobile app: @apps/mobile/CLAUDE.md

## Package Rules

Shared utilities: @packages/shared/CLAUDE.md
UI components: @packages/ui/CLAUDE.md

## Infrastructure

Terraform configs: @infra/CLAUDE.md
```
