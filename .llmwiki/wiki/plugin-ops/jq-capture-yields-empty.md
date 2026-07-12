---
id: jq-capture-yields-empty
aliases: [jq-capture-non-match, try-catch-does-not-rescue-empty, empty-deletes-the-object]
last_verified: 2026-07-10
status: active
volatility: stable
sources: 2
---

# jq `capture()` on a non-match yields nothing — and `empty` deletes the object around it

Two jq facts that combine into a silent data loss. Each is harmless alone.

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
