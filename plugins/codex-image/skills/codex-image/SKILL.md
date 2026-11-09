---
name: codex-image
description: Generate or edit bitmap images from Claude Code by delegating to Codex CLI image generation, without managing OpenAI API keys. Use when the user asks to generate or edit a raster image, to produce several design variants or alternative directions for one brief, or when an active task's spec explicitly designates codex-image as the image path (e.g. deck builds); never research raw codex invocation instead of loading this skill. When the grounding or scope is ambiguous, confirm before generating — image generation has cost and side effects.
argument-hint: "[--size auto|WIDTHxHEIGHT] [--quality low|medium|high|auto] [--out <dir>] [-n <count>] [--variants <count>] [--verbatim] [--edit <image-path>] [--ref <image-path>] [--model <id>] [--reasoning <effort>] [--sandbox <mode>] <prompt>"
allowed-tools: Bash(codex *) Bash(git rev-parse *) Bash(pwd) Bash(mkdir *) Bash(ls *) Bash(cp *) Read AskUserQuestion
---

# Codex Image

Generate or edit raster images, 1 to 4 per call without extra confirmation, by asking Codex CLI to use its built-in image generation tool. Do not call the OpenAI REST API, do not ask for an API key, and do not clone or run third-party skill code.

This bridge runs on Claude Code only; a Codex session uses its built-in `imagegen` skill directly. Every question to the user goes through `AskUserQuestion`.

## Defaults

- **Grounding**: generate only on a direct user request or a task spec that names codex-image as the image path. Otherwise, or when scope or count is ambiguous, ask first: generation has cost and side effects.
- **Output**: `assets/generated/codex-image/` under the project root, size `auto`, quality `auto`, count `1`.
- **Filenames**: unique and non-destructive, `codex-image-YYYYMMDD-HHMMSS[-N].png`. Never overwrite an existing file.
- **Ephemeral turns**: nothing from a previous `codex exec` turn (prompt, attachment, output) exists in the next one. To revise a result, pass its output path as `--edit` and re-attach any `--ref`, and always report the absolute output path.

## Argument Handling

Invocation arguments:

```text
$ARGUMENTS
```

Parse them manually:

- `--size`: `auto` or `WIDTHxHEIGHT`. `--quality`: `low`, `medium`, `high` or `auto`.
- `--out`: output directory, relative paths resolved from the project root.
- `-n`: the same prompt rendered N times. 1 to 4 need no confirmation; ask before more.
- `--variants`: N materially different images from one brief, capped at 4. See Variants.
- `--verbatim`: pass the prompt to Codex untouched. See Prompt Quality.
- `--edit`: local image to edit; the prompt describes the change. The output is always a new file and the input is never overwritten.
- `--ref`: local image attached as style or character reference for an otherwise new image. `--edit` and `--ref` are mutually exclusive; if both are given, ask which one is meant.
- `--model`: passed through as `codex exec -m <id>`; omit it to use Codex's own default. `--reasoning`: passed as `-c model_reasoning_effort="<effort>"`, explicit opt-in only.
- `--sandbox`: `read-only`, `workspace-write` (default) or `danger-full-access`, escalated only on explicit request. Pass `--dangerously-bypass-approvals-and-sandbox` only when the user explicitly asks.
- **Prompt**: the remaining text. If it is missing, ask for one concise image prompt.

An `--edit` or `--ref` input needs a real, readable local path before anything is delegated. Read a typed path to confirm it is an image; copy a host-exposed pasted image from its exact temp path into an `inputs/` subdirectory of the output directory. If the host exposes no path, stop and ask: never guess the newest file in a cache such as `~/.claude/image-cache`, and never substitute a prose description for the attachment.

## Validation

Before generating:

1. `codex --version` and `codex login status`. If either fails, stop and tell the user to install Codex CLI or run `codex login`.
2. Find the project root with `git rev-parse --show-toplevel`; if that fails, use the current directory and add `--skip-git-repo-check`. Create the output directory if needed.
3. Validate size, quality and count with the rules in `references/prompt-handoff.md`. An invalid value gets a question, never a silent change, downgrade or reduction.
4. Validate the passthrough overrides, which reach the command line: `--model` matches `^[A-Za-z0-9._:-]+$`, `--reasoning` matches `^[a-z]+$`, `--sandbox` is one of the three modes. Ask for a valid value rather than dropping or rewriting one.
5. `--edit` / `--ref` must resolve to a plain file under the project. Refuse a path containing `` ` $ " ' ; | & < > ( ) `` (but allow `\` and `:`, which Windows paths need), and pass it as one quoted `-i "<path>"` argument.

## Prompt Handoff

Pass instructions to Codex on stdin with `codex exec -`, never inside a shell argument. Add `-m`, `-c model_reasoning_effort=...` and a non-default `-s` only when the matching flag was given; with none, the command is exactly `codex exec - -C "<project-root>" -s workspace-write`.

- **Bash delimiter**: a fresh random token per call, such as `CODEX_PROMPT_EOF_<8+ random alnum>`, written literally in the single-quoted opener `<<'TOKEN'` and as the bare closing line `TOKEN` (no quotes, or bash never ends the here-document). If any prompt line equals the token, pick a new one. Never put the token in a shell variable: bash does not expand the delimiter word.
- **PowerShell**: the `'@` terminator cannot be randomized, so if any prompt line begins with `'@`, ask the user to reword it.

Before the first `codex exec`, read `references/prompt-handoff.md` and send its prompt body as written: user text between the `BEGIN USER PROMPT` / `END USER PROMPT` sentinels, options under the `Operational metadata` label so a size is never read as creative direction. The same file holds the PowerShell form, `-i` attachment order and the optional `use case` slug.

## Prompt Quality

- **Shaping**: turn a short or vague prompt into a production spec without inventing unrelated content: intended use, subject and setting, style or medium, composition, lighting and mood, exact text quoted verbatim, constraints and an avoid list. A prompt that already carries those slots passes with at most normalization.
- **Verbatim**: with `--verbatim`, pass the text untouched and add to the prompt body: *"Use the text between the sentinels exactly as written. Do not rewrite, expand, optimize, translate, or add creative details."*
- **Edits and references**: for `--edit`, state what must change and what must stay, repeated every iteration. For `--ref`, state what carries over (character, style, palette) and what is new, without implying the reference itself will be altered.

## Variants

`--variants N` produces N materially different images from one brief, capped at 4; `-n` still means the same prompt N times. Classify the request once:

| Request | Anchor | Per-image prompt |
|---|---|---|
| same design, different styles | one image via `--edit` | the shared design, restyled |
| same subject, different scenes | one image via `--ref` | the shared subject in a new scene |
| different concepts | none | N standalone prompts, materially different in composition and art direction |
| plain repeat (a bare count, no word implying difference) | none | delegate to `-n` |

Words like *different*, *alternatives*, *concepts*, *directions*, *options*, *시안*, *다른 디자인* select the concept branch; a bare count does not.

- **Anchor**: when a branch needs one and none exists, generate image #1 first and count it as one of the N. `--variants 4` is four generations, never five.
- **Parallel calls**: run the remaining calls as parallel Bash tool calls, each with `count: 1` and its own filename base, so nothing bills extra images or overwrites a sibling.
- **No ordinals**: each prompt stands alone with no "option 2" or "1번째 시안"; ordering lives in the filename only.
- **Pick**: `Read` all N and present them with their paths. The picked path becomes the `--edit` target for the next revision.

## Transparent Output

1. Ask the built-in image tool for a genuinely transparent background with its alpha channel preserved, then verify the returned file has alpha.
2. Only if that fails, fall back to a flat chroma-key background such as `#00ff00` removed locally, and only when a suitable helper exists. Hair, glass, smoke, translucent material and soft shadows do not survive chroma-key; say so rather than ship a bad cutout.
3. Report transparency as what the file shows, not as a model capability. Ask before any fallback that requires `OPENAI_API_KEY`.

## Result Handling

The built-in tool writes first to `${CODEX_HOME:-$HOME/.codex}/generated_images/<session-id>/`, and the copy into the output directory can fail on any platform. Treat recovery as the normal path. After `codex exec` finishes:

1. Check the output directory for the expected file(s).
2. If one is missing, recover it with `references/result-recovery.md`: one source file per missing destination, copied without overwriting. Never re-run generation because a copy failed; the image exists and a second run bills a second generation.
3. `Read` each file for review.
4. Report saved paths, size requested versus produced (read from the file with an image-inspecting command such as `file`, or report it as unverified), quality requested, count requested versus produced, and any tool limitation Codex mentioned.
5. If generation itself failed, report the Codex CLI version, the error text, and the next command for the user (`codex login`, a Codex update, or a retry at lower quality). Never fabricate images or write placeholder files.
