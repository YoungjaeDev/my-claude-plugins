# Writing levers

The reasoning behind skill prose. `structure.md` says where text goes; this file says why one
sentence earns its place and another does not.

## The description is a context pointer

Every skill's `description` sits in the model's context on every turn, whether or not the skill is
ever used. The body is the payload; the description is the pointer that decides whether the payload
is ever reached.

Two consequences:

- **Reach is set by wording, not by subject.** A skill about CHANGELOG files is not reached because
  it concerns changelogs; it is reached because the description contains the phrases a user actually
  types. Encode the reaching conditions.
- **One trigger per branch, not synonyms per branch.** Listing "review, audit, inspect, examine"
  for one behavior spends always-on context to say one thing four times. Listing four genuinely
  different entry points is not the same move and is worth the space.

## Two loads, and only one of them should be minimized

- **Context load** — what sits in the model's window every turn. Real, measurable, worth cutting.
- **Cognitive load** — what a person has to remember exists in order to use the tool. This one is
  the price of their judgment, not waste. A skill nobody can remember is invisible even at zero
  context cost.

Trading cognitive load away to save a few hundred tokens is the most common bad deal in skill
authoring. `disable-model-invocation` is the explicit form of that trade: context load drops to
zero, and the user now has to know the skill exists.

## The information-hierarchy ladder

Three rungs, in increasing distance from the model's attention:

1. **In-file step** — the model reads it while executing.
2. **In-file reference** — present in the body, consulted when the case arises.
3. **Disclosed reference** — a bundled file, loaded only when the body points at it.

The branch test decides the rung: **content every branch uses goes inline; content only some
branches reach goes behind a pointer.** Progressive disclosure is a way to protect the hierarchy,
not a token-optimization trick. Moving something that every run needs into a reference file does not
save tokens, it adds a read.

## Co-location

Keep a concept's definition, its rules, and its exceptions under one heading. Two distinct failures
look similar and have opposite fixes:

- **Duplication** — one meaning stated in two places. Fix by deleting one.
- **Scattering** — one meaning split across several places, none complete. Fix by merging.

Deleting a fragment of a scattered concept makes it worse. Establish which failure you have before
editing.

## Completion criteria have two properties

- **Clarity** — can the model tell done from not-done? A criterion that cannot be evaluated causes
  premature completion, and no amount of emphasis fixes it.
- **Demand** — how much the criterion asks for. "Check the file" and "list every caller and state
  which ones the change affects" are both clear; only the second pulls real legwork.

Defend in that order: sharpen the criterion first. Only if work still ends early does splitting the
sequence help — and splitting only works at a real context boundary (a handoff, a subagent), not at
an arbitrary heading.

## Leading words

Reach for compressed concepts the model already carries from pretraining — `root cause`,
`tight loop`, `dry run`, `tracer bullet`, `fail loud`. One such token pulls in a whole behavior.

An invented term pulls in nothing; it has no prior to activate, so it costs a definition and returns
a word. When a standard term exists, use it. Coin one only for something genuinely new to this
repository, and define it once, in the place it is used.

## Negation is a weak steering mechanism

Prohibitions put the prohibited thing into context. "Do not use `cat` to read files" leaves `cat` in
the model's working set. Write the target behavior positively: "Read files with `Read`."

Keep prohibitions for hard guardrails — irreversible actions, silent-failure traps — and even there,
pair them with the positive goal so the instruction has somewhere to land.

## Pruning: five tests for a line

Apply in order; the first failure decides.

1. **Single source of truth** — is this stated authoritatively elsewhere? Point at that instead.
2. **Cache** — the environment is itself a source of truth. Prose that restates what a file or
   command already shows is a cache entry, and it goes stale silently. Cache only lookups expensive
   enough to be worth the staleness risk.
3. **Relevance** — does anyone reaching this point need it?
4. **No-op** — does this line change behavior relative to the default? "Be careful" and "write good
   code" do not. This is a judgment relative to the model, not an absolute one; when it is close,
   settle it by running the skill with the line removed.
5. **Sediment** — was this true for a version, a workflow, or a bug that no longer exists? Sediment
   reads as authoritative precisely because nobody remembers writing it.

A line that survives all five earns its tokens.

## Choosing who invokes

- **Model-invoked** (the default) — the description is permanent context load. Correct when an
  agent, or another skill, has to reach it without a person deciding.
- **User-invoked** (`disable-model-invocation: true`) — zero context load, full cognitive load.
  Correct for side-effecting workflows where the timing is the user's call.

In this repository the second option is unavailable for Codex-eligible plugins; see
`frontmatter.md`. That constraint does not make the trade-off irrelevant — it means the lever is
description discipline instead.

## Provenance

The levers above were synthesized while authoring this skill from public writing on agent-facing
documentation, from the Hermes skill-authoring guidance, and from this repository's own audit
history. That is attribution, not a pointer: nothing here requires reading any external skill, and
this skill never loads one at runtime.
