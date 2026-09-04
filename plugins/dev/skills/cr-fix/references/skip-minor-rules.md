# --skip-minor Post-classification Filter

Opt-in via `--skip-minor`. Applied AFTER `references/tier-classification.md` resolves the base tier.

## Demotion rules

- CR/CLI items with severity ∈ {`🟡 Minor`, `🟢 Trivial`, `🟢 Info`} AND type ∉ {`🚨 Bug`, `🔒 Security`} → tier forced to **skip**.
- Codex items with `p_badge == "2"` → tier forced to **skip**.

## Safety net

- `Bug + Minor` keeps its gated tier.
- `Security + Minor` keeps its gated tier.
- Codex P1 unaffected (stays gated).
- Codex P3 unaffected (stays skip — was already skip in base tier).

The base tier table in `references/tier-classification.md` is the source of truth; this filter only **narrows** what the user sees in the gated/auto queue, never widens it.

## Counters

`skip` tier items are dropped from the working list before the Step 9a table renders. They never appear to the user, never enter Step 9b/9c, never increment `applied_this_cycle` / `deferred_this_cycle`.

Sub-counters drive the footer disclosure only — the Step 16 final JSON keeps `skipped_total` for backward compatibility:

- `skipped_nitpick` — CR/CLI Nitpick filtered by base tier.
- `skipped_p3` — Codex P3 filtered by base tier.
- `skipped_minor` — added only when `--skip-minor` triggers (CR Minor severity + Codex P2).

Invariant: `skipped_total = skipped_nitpick + skipped_p3 + skipped_minor`.

## Footer disclosure format

```text
(N items hidden: <m> CR Nitpicks, <k> Codex P3[, <j> Minor severity / Codex P2])
```

The `Minor severity / Codex P2` segment appears only when `SKIP_MINOR=true` AND `skipped_minor > 0`.
