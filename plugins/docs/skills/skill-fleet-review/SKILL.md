---
name: skill-fleet-review
description: "Sweep every skill in a plugin tree at once — measure the whole fleet, select a cohort from the numbers, review it across seven axes, and emit a dated audit report plus CSV with P0/P1/P2 tiers. Measurement-first so a model reads only the skills the numbers single out, except the pointer axis which covers every skill because trigger collisions only appear when sibling descriptions are read side by side. Use for a repository-wide skill review, before or after a plugin reorganization, or when deciding which skills to refactor next. Triggers — 스킬 전수 검토, 전체 스킬 감사, 스킬 플릿 리뷰, 스킬 일괄 점검, fleet review, review all skills, audit every skill, repository-wide skill sweep. For one skill use docs:skill-audit; for writing a skill use docs:skill-forge."
---

# skill-fleet-review

Review every skill in the tree without reading every skill with a model.

## Overview

A fleet review that reads 50 bodies with a model costs more than it returns, and most of what it
would find is mechanical. So: measure everything, let the numbers pick the cohort, and spend
judgment there.

The pointer axis is the exception. Descriptions are short, so reading all of them is cheap, and a
trigger collision is invisible from inside one skill. It only shows up when siblings are read
together, which is exactly what a fleet pass makes possible.

The rules being applied belong to `docs:skill-forge` and live in its bundled references.

## When to use

A repository-wide sweep: before or after reorganizing plugins, when choosing what to refactor next,
or on a periodic pass over accumulated drift.

Do not use it for one skill (`docs:skill-audit`) or to write one (`docs:skill-forge`).

## Prerequisites

Run from the repository root. Node 18+ for the measurement script. Nothing else: no MCP server, no
external CLI, and no other skill is required at any step.

## Procedure

### 1. Measure the fleet

```bash
# Honor a caller-supplied PLUGIN_ROOT first — the abort message below tells the user to
# export it, and starting from CLAUDE_PLUGIN_ROOT would overwrite that escape hatch.
PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
[ -z "$PLUGIN_ROOT" ] && [ -d plugins/docs/skills ] && PLUGIN_ROOT=plugins/docs
if [ -z "$PLUGIN_ROOT" ]; then
  # Rank Codex cache candidates on the version basename, not the whole path: a plain
  # sort puts 0.9.0 above 0.10.0 and lets the marketplace directory outrank the version.
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  if sort -V </dev/null >/dev/null 2>&1; then vsort="sort -V"; else vsort="sort -t. -k1,1n -k2,2n -k3,3n"; fi
  PLUGIN_ROOT=$(ls -1d "$cache_root"/*/docs/* 2>/dev/null | awk -F/ '{print $NF "\t" $0}' | $vsort | tail -1 | cut -f2-)
fi
[ -d "$PLUGIN_ROOT/skills" ] || { echo "docs plugin root not found; export PLUGIN_ROOT" >&2; exit 1; }
MEASURE="$PLUGIN_ROOT/skills/skill-forge/scripts/measure-skills.mjs"
mkdir -p docs/audit
# Name the roots to sweep. With no argument the measurer defaults to `plugins/` when it
# exists, so a repository that also keeps skills under `.claude/skills/` gets a partial
# scan reported as repository-wide. List every root that holds skills here.
SWEEP_ROOTS="${SWEEP_ROOTS:?set SWEEP_ROOTS to every skill root to sweep, e.g. \"plugins .claude/skills\"}"
# zsh does not word-split an unquoted parameter, so a multi-root value would arrive as one
# path and measure nothing. Ask for POSIX splitting; the probe is a no-op under bash/sh.
set -o shwordsplit 2>/dev/null || true
node "$MEASURE" $SWEEP_ROOTS; rc=$?
# Exit 2 means part of the tree could not be read. Continuing would build a cohort and a
# report from a baseline that silently omits those skills — the false-clean sweep this
# skill's Pitfalls section forbids. Stop and report the unverified scope instead.
[ "$rc" -eq 0 ] || { echo "measure-skills exited $rc — scope incomplete, sweep stopped" >&2; exit 1; }

# Never overwrite an earlier run's artifacts: the first run's numbers are the baseline
# the next one is compared against. Testing for the file and then redirecting is not
# enough — two sweeps started in the same second, or in parallel, both pass the test and
# the second `>` wins. Reserve the CSV atomically instead: under `noclobber` the shell
# opens with O_EXCL, so exactly one racing run gets each candidate.
# Both artifacts share one base, so the base is what gets reserved — not just the CSV.
# Checking only `.csv` re-picked a base whose `.md` still existed (the failure cleanup
# below removes the CSV but never the report), and Step 6 then overwrote that report.
base="docs/audit/$(date +%Y-%m-%d)-fleet"; OUT="$base"; n=0
until [ ! -e "$OUT.md" ] && (set -o noclobber; : > "$OUT.csv") 2>/dev/null; do
  n=$((n + 1)); OUT="$base-$n"
  [ "$n" -gt 50 ] && { echo "measure: cannot reserve an audit path under $base" >&2; exit 1; }
done
node "$MEASURE" --csv $SWEEP_ROOTS > "$OUT.csv"; rc=$?
# Remove the reservation on failure. Leaving the truncated file behind hands the next
# reader a zero-row CSV that looks exactly like a fleet with nothing to report.
[ "$rc" -eq 0 ] || { rm -f "$OUT.csv"; echo "measure-skills --csv exited $rc — reservation $OUT.csv removed, no baseline written" >&2; exit 1; }
echo "report base: $OUT"
```

Then run the mechanical guards, whose output feeds the P0 tier directly. They are
repository scripts, not bundled with this plugin: in a repo that does not carry them,
report the gap instead of dying on it:

Unlike `skill-forge`'s verification gate, a nonzero guard here is **data, not an error**:
a guard exits nonzero precisely because it found the violations that become the P0 tier, so
aborting on it would kill the sweep for doing its job. The statuses are still recorded per
guard and carried into the report; what must never happen is a status disappearing.

```bash
for g in "check-skill-contract.mjs" "check-skill-prose.mjs"; do
  s=${g%% *}; rest=${g#"$s"}
  if [ -f "scripts/$s" ]; then
    node "scripts/$s" $rest; rc=$?
    echo "[$s exit $rc]"   # nonzero here means findings — record it, do not abort
  else
    echo "[$s not present in this repository — P0 tier loses its mechanical input]"
  fi
done
```

Carry every `[... exit N]` line into the report's guard section verbatim. A guard that exited
nonzero and produced no findings in the report means the guard itself broke, not that the
fleet is clean.

### 2. Select the cohort

Per-body review goes to:

- every skill flagged by a guard in step 1;
- every skill over 300 lines, or in the top decile of body tokens;
- every skill carrying a frontmatter key that fewer than three other skills use;
- every skill with `references` depth above 1.

Record how many skills the cohort covers and how many it leaves unread. A sweep that silently
skipped 40 skills reads as "everything is fine" to whoever finds the report later.

### 3. Run the pointer axis over every skill

Not just the cohort. `Read` all descriptions and group them by the request they would match. For
each group with more than one member, decide which skill owns the branch and what the others should
say instead. Also flag descriptions that summarize a subject instead of encoding reaching
conditions, and synonym runs that spend permanent context to say one thing several ways.

### 4. Review the cohort across the remaining six axes

`Read` the axis table in `../skill-forge/references/axes.md` and apply every row except Pointer,
which step 3 already covered fleet-wide.

The inline sequential path is the primary one: take the axes in order, and for each, read the cohort
and record findings. It completes on all three runtimes and must stay complete on its own.

Under Claude Code only, the same work can be accelerated by dispatching one read-only `Task` agent
per axis over the cohort and merging the results. That is an accelerator, not a requirement: never
move an axis's rules into an agent definition, because Codex has no agents surface and relocated
logic would silently vanish for it.

### 5. Tier

Per the tiers in `../skill-forge/references/axes.md`: **P0** silent failure on a runtime (name it),
**P1** structure / completion criteria / sibling pointer collision, **P2** pruning and phrasing.

### 6. Emit the report

Write `$OUT.md` (the base path step 1 printed, beside the CSV it wrote) containing:

1. Scope: how many skills measured, how many in the cohort, how many read for the pointer axis
   only, and the selection rule used.
2. The mechanical guard output, verbatim.
3. Findings by tier, each naming plugin, skill, axis, file and line, and the concrete edit.
4. Pointer-collision groups, each with the proposed owner of the branch.
5. Skills read and found clean, listed by name, so a later reader can separate passed from unread.
6. Anything undetermined, marked `unverified`.

Do not apply edits during the sweep. The report is the deliverable; applying it is a separate,
tier-by-tier decision the caller makes, and each applied batch carries its own version bumps.

## Pitfalls

- **Silent truncation.** Capping the cohort without saying so turns "reviewed the top 12" into
  "reviewed everything" for whoever reads the report later. State the cap.
- **Skipping the fleet-wide pointer pass.** Collisions are the one finding class that cannot be seen
  from inside a single skill, and it is the cheapest axis to run.
- **Treating a prior audit's grades as current.** An earlier report is a baseline to compare
  against, not a result to carry forward. Re-derive.
- **Applying P2 edits as they are found.** Every touched plugin needs a version bump; a sweep that
  edits opportunistically produces a change nobody can review.
- **Letting the subagent path become primary.** If the inline path no longer works standing alone,
  the skill has quietly become Claude-only.

## Verification

The sweep is done when: the CSV and the dated report both exist, the report states its cohort rule
and its unread count, every P0 names the runtime it breaks, the pointer axis covers every skill in
the tree, and no edits were applied without a matching version bump.
