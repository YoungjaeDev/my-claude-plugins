---
id: harness-loop-guide-sensor
aliases: [self-improvement-loop, guide-and-sensor, delegation-criterion, harness-two-parts]
tier: insight
promoted_from: [[harness-engineering-principles]]
evidence_count: 2
last_verified: 2026-06-17
status: active
volatility: stable
sources: 2
---

# Build a self-improvement loop: guide before, sensor after

**Rule.** When building a harness (a skill, plugin, or agent workflow), design for a self-improvement loop — generate → verify → fix → re-run — not a one-shot. The loop needs two parts: a **guide** that sets direction *before* action (instruction files, MCP, skills, an operating SSOT doc) and a **sensor** that enables self-correction *after* action (tests, linters, type-checkers, traces). Prefer a deterministic/cheap/fast sensor over an LLM grader.

**Apply when.** Deciding how much to delegate to an agent, or designing any harness: "can I give this a guide + a sensor so it self-corrects?" If yes, delegate and let it loop; if no, that gap is the human's job. A test that is a sensor when run is also a spec when read — one artifact covers verification + always-current spec.

**Why.** Models are lenient on their own output and stop early, so a sensor is the highest-leverage harness piece (more so with stronger models, not less). Thinking is delegable, understanding is not — merge-readiness and domain decisions stay human-owned, and the harness reshapes (never disappears) as models improve.

> Evidence: [[harness-engineering-principles]] (full rationale + the case for E2E as the sensor) and [[playwright-ai-harness]] (the concrete realization in `e2e-harness`).

## Sources

1. Naver Financial FE talk on agent E2E harnesses (2026) — articulates the loop, the guide/sensor split, evaluator-optimizer with a deterministic grader.
2. The `e2e-harness` plugin built in this repo — applied the pattern (setup = guide, author/debug = sensor + healer loop).
