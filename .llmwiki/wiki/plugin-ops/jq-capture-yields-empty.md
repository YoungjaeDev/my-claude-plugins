---
id: jq-capture-yields-empty
aliases: [jq-capture-non-match, try-catch-does-not-rescue-empty, empty-deletes-the-object, jq-missing-r-flag]
last_verified: 2026-07-13
status: active
volatility: stable
sources: 3
---

# jq `capture()` on a non-match yields nothing — and `empty` deletes the object around it

Three jq output facts that silently defeat the shell code consuming them. Each is harmless alone.

## Fact 1: `capture()` does not throw and does not return null

On a non-match, `capture()` produces **no output**. It is not an error, so `try … catch null` never runs its handler, and the expression still evaluates to `empty`:

```
$ jq -nr 'try ("tidy" | capture("at line (?<n>[0-9]+)").n) catch "CAUGHT"'
$          # nothing. Not "CAUGHT", not null.
```

The alternative operator rescues it — `empty // null` is `null` — which is why `capture(...) // .fallback` looks like it works. It only works when there *is* a fallback.

## Fact 2: an `empty` anywhere inside an object constructor deletes the whole object

```
$ jq -c '{a: 1, b: (try (.x | capture("z").n) catch null)}' <<< '{"x":"abc"}'
$          # no object at all — not {"a":1,"b":null}
```

Inside `[ .[] | {…} ]` this is worse than a wrong field: the **element vanishes from the array**, and `length` silently drops. Nothing errors, nothing warns.

## How it bites

`parse-cr-cli-jsonl.sh` projects CodeRabbit CLI findings into records. A finding whose guidance carried no `around lines N` / `at line N` hint produced an `empty` for its `line` field, so the entire finding disappeared from the emitted array. Findings *with* a line hint came through; the array just came back shorter than the input. The bug was found by a fixture asserting `length == 2`, not by reading the code.

## The fix

Force "no match" into a value before it reaches the constructor:

```jq
def first_or_null(f): ([ f? ] | .[0]);   # [] | .[0] is null
line: first_or_null(capture("at line (?<n>[0-9]+)").n)
```

`f?` also swallows genuine errors, which is what you want here — a malformed body must not abort the whole array.

## Fact 3: without `-r`, an "empty" string result is the two-char literal `""`

`jq '... | .id // ""'` on an empty selection prints not nothing but the JSON-encoded string — two literal quote characters. Any shell truthiness test downstream then passes:

```
$ id=$(echo '[]' | jq 'last | .id // ""'); [ -n "$id" ] && echo "FOUND: $id"
FOUND: ""
```

How it bit (PR #122, reproduced live): `poll-codex-grace.sh` used exactly this shape as an `until` condition, so with no new Codex review the loop exited on round 1 and emitted a fabricated empty review id — the grace window never waited. The same missing `-r` in the SKILL.md Step 6b snippet made `candidate` look found, skipping grace polling entirely and silently dropping that iteration's Codex findings. Rule: **any jq output that feeds a shell emptiness/truthiness test must be produced with `-r`** (numbers print identically either way, so `-r` costs nothing).

## The comment that taught the wrong lesson

`sniff-cr-rate-limit.sh` carried, for months:

> `jq capture() THROWS on non-match (not null) — // empty only catches null/false. Wrap in try … catch empty so non-matching bodies don't kill the script under set -euo pipefail.`

Every clause is wrong except the conclusion. It does not throw; `try … catch empty` changes nothing; the thing that actually rescued that script was the surrounding `[ … ] | first // empty`. A comment that explains a correct line with a wrong mechanism propagates the wrong mechanism into the next script.

> See-also: [[detector-cannot-look-vs-nothing-wrong]]
> Refines: [[cr-cli-fallback-contract-drift]]
> Evidence: plugins/github-dev/skills/cr-fix/scripts/parse-cr-cli-jsonl.sh
> Evidence: plugins/github-dev/skills/cr-fix/tests/run-tests.sh

## Sources

1. **jq 1.7 behavior, measured** — `capture()` on non-match emits no output under `jq -n`; `try/catch` does not convert it to null; an `empty` field drops the enclosing object from a `[ .[] | {…} ]` construction.
2. **PR #109** (`fix(github-dev): cr-fix 2.7.1`) — the CLI-parser regression. Fixture `cr-cli-0.5.x-findings.jsonl` has two findings; the parser returned one. Caught by the assertion `0.5.x nitpick header parsed`, which failed with `null` because element `[1]` did not exist.
3. **PR #122** (`fix(github-dev): cr-fix iter-5 — grace poll jq -r flag`) — the missing-`-r` instance, reproduced live during the run itself: the grace poll returned `{"codex_review_id":""}` instantly instead of polling; regression cases `unprocessed review found -> id 777` / `no unprocessed review -> no terminal line` in `tests/run-tests.sh`.
