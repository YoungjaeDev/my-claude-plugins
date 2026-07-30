# voice-prompt

One skill, `voice-prompt`, that normalizes Korean voice-mode STT input before the session acts
on it. Typed once, it stays active until released.

## Why this exists

Korean voice mode breaks in three ways: orthography misrecognition, failed Korean-to-English
code-switching (an English identifier spoken with Korean pronunciation comes back as Korean
syllables — "로더 파일"), and speech habits landing inside the command ("어쨌든", "그냥", "뭐").

Two of the three barely need a plugin. A model already ignores fillers and reads through
misspellings, so making that explicit buys consistency, not new capability. The third one is
different in kind: hearing "로더 파일", a model **guesses** a filename. It cannot know whether
`loader.py` exists without looking. That is not a comprehension failure, it is a missing action —
and a missing action is exactly what instructions can add.

So this plugin is not a text cleaner. It is a threshold changer. Everything it really
contributes is a decision rather than a transform:

| What it adds | Kind |
|---|---|
| Resolve identifiers against the repo instead of guessing | action added |
| Never rewrite numbers, dates, versions, PR/issue numbers | action forbidden |
| Echo one line of what was understood before acting | observability |
| Confirm before an irreversible action | gate |

## Shape

```
plugins/voice-prompt/
├── CLAUDE.md
├── .claude-plugin/plugin.json
└── skills/voice-prompt/
    ├── SKILL.md                             # the body
    ├── references/stt-error-classes.md      # error taxonomy, live-command stance
    ├── references/korean-filler.md          # filler classes + function-residue test
    └── templates/speech-profile.md          # seeded to .claude/voice-prompt/speech-profile.md
```

## Boundary with plaud-note-taking

Both correct STT output, and the error distribution is the same, so the taxonomy is shared in
spirit. The discipline is not. `plaud-note-taking` treats its transcript as immutable evidence
and preserves every filler because the filler is part of the record; this skill treats its input
as a disposable command and deletes the filler because the filler is noise. Their term
dictionaries do not overlap either — one holds meeting attendees and company names, the other
holds one speaker's pronunciation habits.

Two plugins, not one skill with a mode flag: a body carrying both stances would need a
conditional on every rule.

## Known limit

This is instruction-following, not interception. Nothing sits between STT and the model — a
skill cannot rewrite the incoming message, and `UserPromptSubmit` hook output arrives as
appended `additionalContext` rather than a replacement. So the normalization happens in the
model's own reasoning and carries the same reliability as any other skill: it can fade in a long
session.

The echo line is the tell. If it stops appearing, the skill has drifted out — re-invoke
`/voice-prompt`. That self-signal is why the echo is mandatory rather than optional, and why
this plugin ships no marker file or re-injection hook to enforce stickiness.
