# codex-image

A one-skill bridge that generates and edits raster images from Claude Code by driving `codex exec`
and the Codex built-in image tool. Claude-only by design: it is excluded from Codex sync, because
under Codex the bridge would summon the host it is bridging to.

## Why this exists

Claude Code has no image generation. The alternatives are an OpenAI API key (a secret to store,
rotate, and leak) or a third-party skill repo (code to clone and run). Codex CLI already
authenticates through ChatGPT OAuth and already ships an `imagegen` system skill with a built-in
image tool. This plugin is the prompt contract that reaches that tool and nothing else: no REST
call, no API key, no runner, no bundled scripts.

## Shape

| Piece | Where |
|---|---|
| Entry point | `/codex-image:codex-image` |
| Transport | `codex exec -` with the prompt on stdin, `-i` for attachments |
| Codex-side tool | built-in `image_gen`, plus `view_image` to load an attachment |
| Default output | `assets/generated/codex-image/` under the project root |
| Where Codex writes first | `${CODEX_HOME:-~/.codex}/generated_images/<session-id>/` |

## Flags

| Flag | Meaning |
|---|---|
| `--size` / `--quality` / `--out` | validated, never silently downgraded |
| `-n <count>` | the same prompt rendered N times, in one `codex exec` turn |
| `--variants <count>` | N *materially different* images from one brief, cap 4, one parallel `codex exec` per image |
| `--verbatim` | pass the prompt to Codex untouched; suppresses the default shaping of short or vague prompts |
| `--edit <path>` | edit an existing local image; output is always a new file |
| `--ref <path>` | attach a style/character reference for an otherwise new image; mutually exclusive with `--edit` |
| `--model` / `--reasoning` / `--sandbox` | passthrough, shell-validated before interpolation |

`-n` and `--variants` are deliberately separate flags. Making `-n` classify the request would
silently change behavior for anyone already using it to mean "render this four times".

## Design decisions worth not re-litigating

- **The output almost never lands where it was asked to.** The built-in tool writes into the
  session folder under `$CODEX_HOME` on every platform; moving the file to the output directory is
  an instruction the Codex session may drop. Recovery (newest `*.png` in the session folder, copied
  under the requested filename base, refusing to overwrite) is the normal path, not a Windows
  edge case. Never re-run generation because a copy failed — the image already exists and a second
  run bills a second generation.
- **Do not pin the generated filename pattern.** It has changed between Codex versions. Sort by
  mtime instead.
- **Shaping is the default, `--verbatim` is the escape hatch.** A short prompt reaches the image
  model as a short prompt and produces a generic image; a spec-shaped prompt does not. But a user
  who has already written their final prompt is entitled to have it left alone.
- **Sentinels, not a `Prompt:` label.** The prompt body wraps user text in
  `BEGIN USER PROMPT` / `END USER PROMPT` and labels the options block as operational metadata, so
  the Codex session cannot read a size constraint as creative direction.
- **Every `codex exec` turn is ephemeral.** Attachments, prompt, and output do not survive into the
  next turn. This is why the absolute output path must appear in every response: it is the handle
  for the next `--edit`.
- **Attachments need a real path, or the skill stops and asks.** Guessing the newest file in
  `~/.claude/image-cache` can attach the wrong image, or a private one.
- **Transparency is asked for, not faked.** Request a genuinely transparent background from the
  built-in tool and verify alpha; chroma-key is the fallback, and it does not survive hair, glass,
  or smoke.
- **No runner, no manifest, no installer.** A Node CLI, a batch manifest schema, or
  `doctor`/`bootstrap` subcommands would add a runtime dependency to a zero-dependency skill.
  Parallel Bash tool calls already give what a concurrency runner would.

## Portability

No bundled scripts, so no `PLUGIN_ROOT` resolver is needed. The inline shell in the skill sticks to
`ls -t`, `cp`, and `[`, which behave the same on GNU and BSD. The here-document delimiter is
randomized per invocation and re-checked against the prompt text, because a prompt line equal to a
fixed delimiter closes the block early and executes the rest as shell commands. PowerShell's `'@`
terminator cannot be randomized, so a prompt line starting with `'@` is rejected instead.
