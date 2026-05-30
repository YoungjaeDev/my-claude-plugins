# Deliberation Protocol

Round-by-round protocol for the LLM Council: anonymization, gap/conflict analysis, convergence decisions, re-queries, and termination criteria. Round 1.5+ analysis is MANDATORY in full mode; quick mode goes Round 1 → Synthesis directly.

## Round 1.5 — Coordinator Analysis (MANDATORY in full mode)

> DO NOT SKIP in full mode. After collecting responses, the coordinator MUST perform this analysis before synthesis. Skipping Round 1.5 defeats the purpose of multi-round deliberation.

### 1. Anonymize responses

```
1. Assign labels in response arrival order: Response A, B, C, D
2. Create internal mapping:
   label_to_model = {
     "Response A": "[first arrived]",
     "Response B": "[second arrived]",
     "Response C": "[third arrived]",
     "Response D": "[fourth arrived]"
   }
3. Present responses by label only (hide model names until synthesis)
```

### 2. Gap analysis

```yaml
gaps_detected:
  - model: "opus"
    gap: "performance benchmarks not addressed"
    severity: "medium"
  - model: "gemini"
    gap: "security implications missing"
    severity: "high"
```

### 3. Conflict detection

```yaml
conflicts_detected:
  - topic: "recommended approach"
    positions:
      - model: "opus"
        position: "use library A"
        evidence: "official docs recommend"
      - model: "codex"
        position: "use library B"
        evidence: "better performance"
    resolution_needed: true
```

### 4. Convergence check (REQUIRED before synthesis)

```yaml
convergence_status:
  agreement_count: 3  # models with same core conclusion
  gaps_remaining: 2
  conflicts_remaining: 1
  decision: "proceed_to_round_2" | "terminate_and_synthesize"
```

**Decision logic:**
- If `agreement_count >= 3` → `terminate_and_synthesize` (strong consensus)
- If `gaps_remaining == 0` AND `conflicts_remaining == 0` → `terminate_and_synthesize`
- If `conflicts_remaining > 0` AND round < 3 → `proceed_to_round_2`
- If `gaps_remaining > 0` AND round < 3 → `proceed_to_round_2`
- Otherwise → `terminate_and_synthesize`

## Round 2 — Targeted Re-queries (Conditional)

If convergence criteria not met, re-query only models with gaps/conflicts:

```
## Previous Round Summary
Round 1 produced the following positions:

### Response A
- Position: [summary]
- Key points: [list]

### Response B
- Position: [summary]
- Key points: [list]

[... other responses ...]

## Gaps Identified
- [gap 1]
- [gap 2]

## Conflicts Detected
- Topic: [topic]
  - Position A: [description]
  - Position B: [description]

## Re-query Focus
Please address specifically:
1. [specific gap or conflict to resolve]
2. [specific gap or conflict to resolve]

Provide evidence and reasoning for your position.

## Output (YAML format required)
[COUNCIL_MEMBER_SCHEMA with gaps/conflicts fields]
```

## Round 2.5 — Coordinator Analysis

Same as Round 1.5. Check convergence again.

## Round 3 — Final Cross-Validation (Conditional)

If still not converged after Round 2:
- Focused on resolving remaining conflicts
- Models see other models' positions (still anonymized)
- Final opportunity for consensus

## Synthesis

After convergence or max rounds:

1. **Reveal** the label-to-model mapping
2. **Analyze** all responses:
   - Consensus points (where models agree)
   - Resolved conflicts (with reasoning)
   - Remaining disagreements (with analysis)
   - Unique insights (valuable points from individual models)
3. **Produce** final verdict combining best elements

## Termination Criteria

### Hard limits (mandatory termination)

| Condition | Value |
|-----------|-------|
| Max rounds | 3 |
| Max total time | 20 min |
| Max per-model timeout | 10 min (Gemini) |
| Min successful models | 2/4 (proceed with partial results) |
| All models failed | immediate termination |

### Soft limits (convergence — any triggers termination)

| Condition | Threshold |
|-----------|-----------|
| Strong consensus | 3+ models agree on core conclusion |
| All gaps resolved | 0 remaining |
| All conflicts resolved | 0 remaining |
| Conflicts irreconcilable | Cannot be resolved with more queries |
