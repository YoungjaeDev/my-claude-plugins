---
name: council
description: Convene a multi-model "LLM Council" — query several AI models (Claude Opus, Claude Sonnet, Codex, Gemini) in parallel on a question, anonymize their answers as Response A/B/C/D, cross-deliberate over up to 3 rounds, then synthesize a collective verdict with the model identities revealed. Use when the user wants multiple AI perspectives, a "council", or cross-model deliberation on a decision or question — phrasings like "ask the council", "council on X", "get multiple models' opinions", "what would different models say". Supports a quick single-round mode when the user wants speed.
---

# LLM Council

Inspired by Andrej Karpathy's LLM Council: query multiple AI models with the same question, anonymize their responses, and synthesize collective wisdom through multi-round deliberation.

**Core philosophy:**
- Collective intelligence > single expert opinion
- Anonymization prevents model favoritism
- Multi-round deliberation resolves conflicts and fills gaps
- Diverse perspectives lead to better answers

## Inferring intent (replaces command arguments)

This skill has no slash-command arguments. Infer everything from the user's request and conversation:

- **The question**: derive it from what the user asked. If they referenced "this code", "the API", "the current implementation", etc., resolve the referent from recent context, open files, or git diff. If the question is genuinely missing or too ambiguous to act on, ask exactly once via `AskUserQuestion`, then proceed.
- **Quick mode**: if the user signals they want speed ("quick", "fast", "just a quick take", "don't overthink it", a simple yes/no question), run **quick mode**. Otherwise run the **full** deliberation.

**Full mode (default):**
- Maximum reasoning depth (Codex: `reasoningEffort=xhigh`)
- Full multi-round deliberation (up to 3 rounds)
- YAML schema enforced
- All CLIs use their own default models (no hardcoded model names)

**Quick mode:**
- All available models queried
- Single round only (Round 1 → direct Synthesis, skip Round 1.5 analysis)
- YAML schema not enforced (free-form responses accepted)
- Codex: `reasoningEffort=high` instead of `xhigh`

## Pre-flight check

Before querying, detect available council members.

**1. Detect available models** — Opus + Sonnet are always available (2). Probe optional CLIs:

```bash
AVAILABLE_MODELS="opus,sonnet"; MODEL_COUNT=2
command -v codex  >/dev/null 2>&1 && { AVAILABLE_MODELS="$AVAILABLE_MODELS,codex";  MODEL_COUNT=$((MODEL_COUNT+1)); }
command -v gemini >/dev/null 2>&1 && { AVAILABLE_MODELS="$AVAILABLE_MODELS,gemini"; MODEL_COUNT=$((MODEL_COUNT+1)); }
echo "Available models ($MODEL_COUNT): $AVAILABLE_MODELS"
```

**2. Availability decision:**

| Models available | Action |
|------------------|--------|
| 4 (all) | Proceed with full council |
| 3 | Proceed, note missing model |
| 2 (Opus + Sonnet only) | Proceed with reduced council |
| < 2 | Error — cannot proceed |

**3. Setup recommendation** — if Codex or Gemini is missing, tell the user the council will run with N models and that they can install more by running **the council-setup skill** (a sibling skill in this plugin) for richer deliberation. Offer the choice via `AskUserQuestion`:
- "Proceed with [N] models" (recommended if ≥ 2)
- "Run council-setup first"

**4. Guidelines files (optional but recommended)** — note presence/absence of `./CLAUDE.md`, `./AGENTS.md`, `./GEMINI.md`; missing files mean limited context for the corresponding model.

**5. Dynamic selection** — only query available models; skip unavailable ones gracefully.

## Context gathering (before Round 1)

Collect relevant context before querying. Auto-collect git status/diff and a shallow directory tree, and read the project's own `CLAUDE.md` at runtime (plus `./AGENTS.md`, `./GEMINI.md`, `~/.claude/CLAUDE.md`, and `.claude/rules/*.md` if present) and follow their conventions. When relevant files aren't clear from the question, spawn `Explore` agents to find them. Filter out sensitive data and keep prompt size bounded.

Full procedure — Explore-agent trigger/skip conditions, the mandatory file-path inclusion format, per-model file-access methods, sensitive-data filters, and prompt-size limits: see `references/model-invocation.md`.

## Council member output schema

All council members return structured YAML (`model`, `response.summary`, `detailed_answer`, `key_points` with evidence, optional `code_references` / `caveats` / `beyond_question`, plus `gaps` / `conflicts` in Round 2+). Schema violators are flagged and re-queried. "Beyond the question" suggestions are accepted **only** with specific file:line evidence — generic best practices without codebase evidence are rejected.

Full schema and enforcement rules: see `references/model-invocation.md`.

## Progress tracking

Use `TodoWrite` to show one todo per model query plus "Analyze responses" and "Synthesize". Mark each model completed as its response arrives; move "Analyze" to in_progress once all are in; add re-query todos when a Round 2 is triggered. Template: see `references/output-format.md`.

## Execution

### Round 1 — collect initial responses

Query all available models **in parallel** using the Task tool with `run_in_background: true` for true parallelism. Each model gets a role-specific prompt (Opus/Sonnet via Read tool, Codex via the `mcp__codex-cli__codex` tool read-only sandbox, Gemini via CLI/MCP), the question, context files, and the output schema.

Per-model prompt templates, tool-usage specifics, reasoning-effort settings, and per-model timeouts (Opus/Sonnet 5min, Codex 8min, Gemini 10min — TaskOutput must use the matching timeout): see `references/model-invocation.md`.

Continue with successful responses if some models fail (minimum 2 required).

### Round 1.5 — coordinator analysis (MANDATORY in full mode)

**Do not skip in full mode** — skipping defeats multi-round deliberation. In **quick mode**, skip straight to Synthesis.

Steps: (1) anonymize responses as **Response A/B/C/D** in arrival order, keeping an internal label→model map hidden until synthesis; (2) gap analysis; (3) conflict detection; (4) convergence check that decides `proceed_to_round_2` vs `terminate_and_synthesize`.

Full anonymization mechanics, the gap/conflict/convergence YAML structures, and the exact decision logic: see `references/deliberation-protocol.md`.

### Rounds 2–3 — targeted re-queries (conditional)

If convergence criteria aren't met, re-query only the models with gaps/conflicts, showing them the anonymized prior positions and a focused ask. Re-run coordinator analysis (Round 2.5) and check convergence again. Round 3 is a final cross-validation focused on remaining conflicts.

Re-query prompt template and round details: see `references/deliberation-protocol.md`.

### Synthesis

After convergence or max rounds: (1) reveal the label→model mapping; (2) analyze consensus, resolved conflicts, remaining disagreements, and unique insights; (3) produce the final verdict combining the best elements.

## Termination criteria

**Hard limits:** max 3 rounds; max 20 min total; max 10 min per-model (Gemini); minimum 2 successful models (proceed with partial results); all-models-failed → immediate termination.

**Soft limits (any triggers termination):** strong consensus (3+ models agree on core conclusion); all gaps resolved; all conflicts resolved; conflicts irreconcilable.

Full tables: see `references/deliberation-protocol.md`.

## Output, errors, and user interaction

Produce the final deliberation report in the standard markdown structure (question, deliberation-process table, anonymized responses, model reveal, coordinator analysis, council synthesis, final verdict, code references).

Full output template, the error-handling table, and the `AskUserQuestion` interaction guidance (when to clarify before/during/after deliberation): see `references/output-format.md`.

## Guidelines

- Respond in the same language as the user's question.
- No emojis in code or documentation.
- Gather context before querying models; for code questions include file snippets with line numbers.
- Read and follow the project's `CLAUDE.md` conventions at runtime.
- Never assume unclear context — use `AskUserQuestion` to clarify, then proceed.
