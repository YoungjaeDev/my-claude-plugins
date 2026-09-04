---
name: codex-image
description: Generate or edit bitmap images from Claude Code by delegating to Codex CLI image generation, without managing OpenAI API keys. Use when the user asks to generate or edit a raster image, or when an active task's spec explicitly designates codex-image as the image path (e.g. deck builds); never research raw codex invocation instead of loading this skill. When the grounding or scope is ambiguous, confirm before generating — image generation has cost and side effects.
argument-hint: "[--size auto|WIDTHxHEIGHT] [--quality low|medium|high|auto] [--out <dir>] [-n <count>] [--edit <image-path>] [--ref <image-path>] [--model <id>] [--reasoning <effort>] [--sandbox <mode>] <prompt>"
allowed-tools: Bash(codex *) Bash(git rev-parse *) Bash(pwd) Bash(mkdir *) Bash(ls *) Read AskUserQuestion
---

# Codex Image

Generate or edit raster images by asking Codex CLI to use its image generation capability. This skill is a Claude Code bridge: do not call the OpenAI REST API, do not ask for an API key, and do not clone or run third-party skill code.

## Defaults

- Generation needs explicit grounding: a direct user request, or a task spec that names codex-image as the image path. Without that grounding, or when scope/count is ambiguous, ask before generating, because image generation has cost and side effects.
- Default output directory: `assets/generated/codex-image/` under the project root.
- Default size: `auto`.
- Default quality: `auto`.
- Default count: `1`.
- Keep generated filenames unique and non-destructive: `codex-image-YYYYMMDD-HHMMSS[-N].png`.
- Treat `-n` as variations of one prompt. For distinct assets, run separate generations.

## Argument Handling

Invocation arguments:

```text
$ARGUMENTS
```

Parse the invocation arguments manually:

- `--size`: `auto` or `WIDTHxHEIGHT`.
- `--quality`: `low`, `medium`, `high`, or `auto`.
- `--out`: output directory. Resolve relative paths from the project root.
- `-n`: number of variants. Use `1` through `4` without extra confirmation; ask before generating more.
- `--edit`: local image path to use as the base to edit; the prompt describes the change. Like every other run, the output is still saved as a **new**, non-destructive file in the output directory (see Defaults / Result Handling); the input at `--edit`'s path is never overwritten. Verify it exists and read it before delegating.
- `--ref`: local image path to attach as a style/character reference while generating an image whose subject/scene is otherwise **new** (not a modification of the reference's own scene): distinct intent from `--edit`, though the output is a new file either way. Verify it exists and read it before delegating. `--edit` and `--ref` are mutually exclusive (editing a specific image vs. using one as inspiration for a different image are different intents); if both are given, ask which one is meant. **Unverified mechanism**: `codex exec`'s `-i, --image <FILE>...` flag (confirmed via `codex exec --help` on codex-cli 0.142.3) is a generic "attach image(s) to the prompt" transport; it does not itself distinguish edit-in-place from reference-only. The edit-vs-reference distinction relies entirely on how the prompt text frames the intent (see Prompt Handoff), not on a separate CLI mechanism. This has not been empirically verified with a live generation in this repo; on first real use, check the result actually looks like a new image guided by the reference (not a near-copy or a literal edit of it) and report back if it doesn't behave as expected.
- `--model`: Codex model id, passed through as `codex exec -m <id>`. Omit to use Codex's own default model: that auto-tracks the latest model, so no model pin is maintained here.
- `--reasoning`: reasoning effort, passed through as `-c model_reasoning_effort="<effort>"` (e.g. `low`, `medium`, `high`, `xhigh`). Explicit opt-in only: image generation barely benefits from reasoning effort, so omit unless the user asks for it.
- `--sandbox`: Codex sandbox mode for the run: `read-only`, `workspace-write` (default), or `danger-full-access`. The default stays `workspace-write` (enough to save the PNG); escalate only on explicit request. The full approval+sandbox bypass is `--dangerously-bypass-approvals-and-sandbox`; pass it only when the user explicitly asks, never by default.
- Remaining text is the image prompt.

If the prompt is missing, ask the user for one concise image prompt. If the request asks for true/native transparent output, explain that the Codex CLI bridge may not expose a guaranteed transparent-background control; ask before switching to any API-key fallback.

## Validation

Before generating:

1. Run `codex --version`. If missing, stop and tell the user to install Codex CLI and run `codex login`.
2. Run `codex login status`. If not logged in, stop and tell the user to run `codex login`.
3. Find the project root with `git rev-parse --show-toplevel`; if that fails, use the current working directory and add `--skip-git-repo-check` to `codex exec`.
4. Create the output directory if needed.
5. Validate size:
   - `auto` is valid.
   - For `WIDTHxHEIGHT`, both dimensions must be positive integers.
   - Prefer Codex imagegen-compatible sizes: both edges multiples of 16, max edge <= 3840, aspect ratio <= 3:1, and total pixels from 655360 to 8294400.
   - If the requested size fails these constraints, ask for a valid size instead of silently changing it.
6. Validate quality and count. Do not silently downgrade quality or reduce count.
7. Validate the passthrough overrides before they reach the shell: each is interpolated into the `codex exec` command line:
   - `--model`: must match `^[A-Za-z0-9._:-]+$`. Refuse any other value (a model id with shell metacharacters could be parsed as a separate command).
   - `--reasoning`: must be one of `low`, `medium`, `high`, `xhigh`.
   - `--sandbox`: must be one of `read-only`, `workspace-write`, `danger-full-access`.
   Do not silently drop or rewrite an invalid value; ask for a valid one, the same way size/quality are handled above.
8. `--edit` / `--ref` also reach the shell, quoted into `-i "<path>"` (see Prompt Handoff); validate the path the same way: resolve it, confirm it exists (step already required above), and confirm it resolves to a plain file under the project. Refuse any value containing shell-command metacharacters (`` ` $ " ' ; | & < > ( ) ``), but **not** `\` or `:`, which are legitimate on Windows paths (backslash separator, drive letter). Never interpolate the raw value directly; pass it as a single quoted/escaped shell argument (or via an array-form exec, not string concatenation): correct quoting, not blanket character exclusion, is what actually stops injection. Ask for a corrected path instead of silently stripping characters.

## Prompt Handoff

Pass instructions to Codex through stdin with `codex exec -`. Do not interpolate the raw user prompt inside a shell command argument.

Use host-appropriate stdin syntax. Append `--skip-git-repo-check` to `codex exec` only when no git root was found. Insert `-m <model>`, `-c model_reasoning_effort="<effort>"`, and a non-default `-s <mode>` only when the matching `--model` / `--reasoning` / `--sandbox` argument was supplied; with none given, the command is exactly `codex exec - -C "<project-root>" -s workspace-write` as before.

### Delimiter safety (required every invocation)

The prompt is delivered as the body of a quoted here-document (bash) or here-string (PowerShell), never interpolated into a shell argument. A *fixed* delimiter is unsafe: if the prompt's own text contains a line equal to the delimiter, the block closes early and the lines after it execute as shell commands. Guard the handoff:

- **Bash: randomize the delimiter.** Pick a fresh token per invocation, e.g. `CODEX_PROMPT_EOF_<8+ random hex/alnum>`, and write that exact literal token in BOTH the opening `<<'TOKEN'` and the closing `TOKEN` line (substitute a concrete suffix for `<random>` in the template below). Then scan the exact prompt text: if any line equals the token, pick a new token and re-check before emitting the command. Keep the delimiter single-quoted so the body is never expanded. Do **not** put the token in a shell variable (`<<"$DELIM"` … `$DELIM`): bash does not parameter-expand the here-document delimiter word, so it would match the literal string `$DELIM` (a fixed, predictable value), and the randomization is lost. The token must be a concrete literal in both places.
- **PowerShell: the here-string terminator `'@` is fixed** and cannot be randomized. Reject instead: if any line of the prompt begins with `'@`, ask the user to reword that line before generating.

For bash-like shells:

```bash
codex exec - [-m <model>] [-c model_reasoning_effort="<effort>"] -C "<project-root>" -s <sandbox, default workspace-write> <<'CODEX_PROMPT_EOF_<random>'
Use the built-in image generation capability to create the requested image.

Prompt:
<exact user prompt>

Options:
- size: <size>
- quality: <quality>
- count: <count>
- edit target: <image path or none>
- reference image: <image path or none — attach as style/character guidance for this new generation, do not modify it>
- output directory: <absolute output directory>
- filename base: <codex-image timestamp base>

Requirements:
1. Generate exactly the requested count unless the tool reports it cannot.
2. Save final PNG file(s) in the output directory with the requested filename base.
3. Never overwrite existing files.
4. Print the saved file path(s), file size(s), and any tool/model limitation encountered.
5. If image generation is unavailable in this Codex CLI session, say so directly and do not create placeholders.
CODEX_PROMPT_EOF_<random>
```

For PowerShell, set the native-pipe encoding to UTF-8 first, otherwise PowerShell 5.1 transcodes the pipe to ASCII and corrupts non-ASCII text (e.g. Korean becomes `??`):

```powershell
$OutputEncoding = [System.Text.Encoding]::UTF8
@'
Use the built-in image generation capability to create the requested image.

Prompt:
<exact user prompt>

Options:
- size: <size>
- quality: <quality>
- count: <count>
- edit target: <image path or none>
- reference image: <image path or none — attach as style/character guidance for this new generation, do not modify it>
- output directory: <absolute output directory>
- filename base: <codex-image timestamp base>

Requirements:
1. Generate exactly the requested count unless the tool reports it cannot.
2. Save final PNG file(s) in the output directory with the requested filename base.
3. Never overwrite existing files.
4. Print the saved file path(s), file size(s), and any tool/model limitation encountered.
5. If image generation is unavailable in this Codex CLI session, say so directly and do not create placeholders.
'@ | codex exec - [-m <model>] [-c model_reasoning_effort="<effort>"] -C "<project-root>" -s <sandbox, default workspace-write>
```

If `--edit` or `--ref` is provided, also pass the image via Codex CLI's image attachment option (`-i`): the same flag, different intent conveyed in the prompt text (edit-in-place vs. reference-for-a-new-image):

```bash
codex exec - -i "<edit-or-ref-image-path>" -C "<project-root>" -s workspace-write ...
```

## Prompt Quality

Shape vague prompts into a short production spec without inventing unrelated content:

- Intended use: asset, mockup, slide visual, product photo, illustration, etc.
- Subject and setting.
- Style or medium.
- Composition and framing.
- Lighting and mood.
- Exact text, quoted verbatim, if any.
- Constraints and avoid list.

For edits, preserve invariants explicitly: say what must change and what must remain unchanged. For a reference-guided new generation (`--ref`), state what to carry over from the reference (character, style, palette) and what is new (scene, pose, composition); do not imply the reference itself will be altered.

## Transparent Output

Use the Codex CLI bridge first for ordinary image generation. For transparent-background requests:

1. If simple cutout quality is acceptable, ask Codex to generate the subject on a flat chroma-key background such as `#00ff00`, then remove the background locally only if a suitable helper exists in the active environment.
2. If the user asks for true/native transparency, or the subject is complex (hair, glass, smoke, translucent material, soft shadows, reflections), ask before using any fallback that requires `OPENAI_API_KEY`.
3. Do not claim that `gpt-image-2` supports `background=transparent`.

## Result Handling

After `codex exec` finishes:

1. Verify every reported file exists under the requested output directory.
   - Observed on Windows (codex-cli 0.136.0; not documented upstream, treat as environment-specific): the `codex exec` sandbox can block all shell spawns with `windows sandbox: spawn setup refresh`. When that happens the image is still generated but Codex cannot copy it into the output directory; it stays at `~/.codex/generated_images/<session-id>/ig_*.png`. Codex prints `session id: <UUID>` near the top of its output. Recover the file from outside the sandbox: take the newest `ig_*.png` under that session folder and copy it to the output directory with the requested filename base, refusing to overwrite an existing file. Do not re-run generation just because the in-sandbox copy failed.
2. Read/display the generated image file(s) for review.
3. Report:
   - saved path(s)
   - size and quality requested
   - count requested and count produced
   - whether this used Codex CLI bridge mode
4. If generation failed, report the Codex CLI version, the relevant error text, and the next concrete command for the user (`codex login`, Codex update, or retry with lower quality). Do not fabricate images or write placeholder files.
