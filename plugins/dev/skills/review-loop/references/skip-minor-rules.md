# --skip-minor Post-classification Filter

Opt-in via `--skip-minor`, applied after `references/tier-classification.md` resolves the base tier. It only narrows the gated and auto queue, never widens it.

## Demotion rules

- CR/CLI items with severity ∈ {`🟡 Minor`, `🔵 Trivial`, `⚪ Info`} AND category ≠ `🔒 Security & Privacy` → tier forced to **skip**.
- Codex items with `p_badge == "2"` → tier forced to **skip**.
- `Security & Privacy + Minor` keeps its gated tier, and Codex P1 stays gated.

## Counters

`skip` tier items leave the working list before the Step 9a table renders: they are never shown, never enter Step 9c, and never count in `applied_this_cycle` / `deferred_this_cycle`.

Sub-counters drive the footer disclosure only — the Step 16 final JSON keeps `skipped_total` for backward compatibility:

- `skipped_trivial` — CR/CLI `🔵 Trivial` / `⚪ Info` (and any `📝 Nitpick` that reaches a record) filtered by base tier.
- `skipped_minor` — added only when `--skip-minor` triggers (CR Minor severity + Codex P2).

Invariant: `skipped_total = skipped_trivial + skipped_minor`.

## Footer disclosure format

```text
(N items hidden: <m> CR Trivial/Info[, <j> Minor severity / Codex P2])
```

The `Minor severity / Codex P2` segment appears only when `SKIP_MINOR=true` AND `skipped_minor > 0`.
