---
name: codex-image
description: Generate or edit bitmap images from Claude Code by delegating to Codex CLI image generation, without managing OpenAI API keys. Use when the user asks to generate or edit a raster image, to produce several design variants or alternative directions for one brief, or when an active task's spec explicitly designates codex-image as the image path (e.g. deck builds); never research raw codex invocation instead of loading this skill. When the grounding or scope is ambiguous, confirm before generating — image generation has cost and side effects.
argument-hint: "[--size auto|WIDTHxHEIGHT] [--quality low|medium|high|auto] [--out <dir>] [-n <count>] [--variants <count>] [--verbatim] [--edit <image-path>] [--ref <image-path>] [--model <id>] [--reasoning <effort>] [--sandbox <mode>] <prompt>"
allowed-tools: Bash(codex *) Bash(git rev-parse *) Bash(pwd) Bash(mkdir *) Bash(ls *) Bash(cp *) Read AskUserQuestion
---

# Codex Image

Generate or edit raster images by asking Codex CLI to use its built-in image generation tool. This skill is a Claude Code bridge: do not call the OpenAI REST API, do not ask for an API key, and do not clone or run third-party skill code.

This bridge runs on Claude Code only. Inside Codex it would summon the host it is bridging to, and its confirmation gates have no tool to ask through; a Codex session uses the built-in `imagegen` skill directly instead.

## Defaults

- Generation needs explicit grounding: a direct user request, or a task spec that names codex-image as the image path. Without that grounding, or when scope/count is ambiguous, ask before generating, because image generation has cost and side effects.
- Default output directory: `assets/generated/codex-image/` under the project root.
- Default size: `auto`. Default quality: `auto`. Default count: `1`.
- Keep generated filenames unique and non-destructive: `codex-image-YYYYMMDD-HHMMSS[-N].png`.
- Every `codex exec` turn is ephemeral. Nothing from a previous turn — prompt, attachment, or output — exists in the next one unless it is passed again.

## Argument Handling

Invocation arguments:

```text
$ARGUMENTS
```

Parse the invocation arguments manually:

- `--size`: `auto` or `WIDTHxHEIGHT`.
- `--quality`: `low`, `medium`, `high`, or `auto`.
- `--out`: output directory. Resolve relative paths from the project root.
- `-n`: the same prompt rendered N times. Use `1` through `4` without extra confirmation; ask before generating more.
- `--variants`: N materially different images from one brief. See Variants. Cap 4.
- `--verbatim`: pass the prompt through to Codex untouched. See Prompt Quality.
- `--edit`: local image path to use as the base to edit; the prompt describes the change. The output is always a **new** file in the output directory; the input is never overwritten.
- `--ref`: local image path to attach as a style/character reference while generating an image whose subject/scene is otherwise **new**. `--edit` and `--ref` are mutually exclusive; if both are given, ask which one is meant.
- `--model`: Codex model id, passed through as `codex exec -m <id>`. Omit to use Codex's own default model: that auto-tracks the latest model, so no model pin is maintained here. The value is passed through unvalidated against the built-in image tool, which does not document a model parameter — a model id meant for the API fallback may simply be ignored.
- `--reasoning`: reasoning effort, passed through as `-c model_reasoning_effort="<effort>"` (`low`, `medium`, `high`, `xhigh`). Explicit opt-in only: image generation barely benefits from reasoning effort.
- `--sandbox`: Codex sandbox mode: `read-only`, `workspace-write` (default), or `danger-full-access`. Escalate only on explicit request. Pass `--dangerously-bypass-approvals-and-sandbox` only when the user explicitly asks.
- Remaining text is the image prompt. If it is missing, ask for one concise image prompt.

### Resolving `--edit` / `--ref` inputs

Both need a real, readable local path before anything is delegated:

- An explicit path the user typed is the path. Read it to confirm it exists and is an image.
- If the host exposed a pasted image at an exact readable temp path, copy that file into an `inputs/` subdirectory of the output directory and use the copy.
- If the host exposes no path, **stop and ask**. Never guess the newest file in a cache directory such as `~/.claude/image-cache` — the newest file may be the wrong image or a private one. Never silently substitute a prose description for the attachment.

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
7. Validate the passthrough overrides before they reach the shell; each is interpolated into the `codex exec` command line:
   - `--model`: must match `^[A-Za-z0-9._:-]+$`. Refuse any other value (a model id with shell metacharacters could be parsed as a separate command).
   - `--reasoning`: must be one of `low`, `medium`, `high`, `xhigh`.
   - `--sandbox`: must be one of `read-only`, `workspace-write`, `danger-full-access`.
   Do not silently drop or rewrite an invalid value; ask for a valid one, the same way size/quality are handled above.
8. `--edit` / `--ref` also reach the shell, quoted into `-i "<path>"`. Confirm the resolved path is a plain file under the project. Refuse any value containing shell-command metacharacters (`` ` $ " ' ; | & < > ( ) ``), but **not** `\` or `:`, which are legitimate on Windows paths (backslash separator, drive letter). Never interpolate the raw value directly; pass it as a single quoted shell argument. Correct quoting, not blanket character exclusion, is what stops injection.

## Prompt Handoff

Pass instructions to Codex through stdin with `codex exec -`. Do not interpolate the raw user prompt inside a shell command argument.

Append `--skip-git-repo-check` only when no git root was found. Insert `-m <model>`, `-c model_reasoning_effort="<effort>"`, and a non-default `-s <mode>` only when the matching argument was supplied; with none given, the command is exactly `codex exec - -C "<project-root>" -s workspace-write`.

### Delimiter safety (required every invocation)

The prompt is delivered as the body of a quoted here-document (bash) or here-string (PowerShell), never interpolated into a shell argument. A *fixed* delimiter is unsafe: if the prompt's own text contains a line equal to the delimiter, the block closes early and the lines after it execute as shell commands.

- **Bash: randomize the delimiter.** Pick a fresh token per invocation, e.g. `CODEX_PROMPT_EOF_<8+ random hex/alnum>`, and write that exact literal token in BOTH the opening `<<'TOKEN'` and the closing `TOKEN` line. Then scan the prompt text: if any line equals the token, pick a new token and re-check before emitting the command. Keep the delimiter single-quoted so the body is never expanded. Do **not** put the token in a shell variable (`<<"$DELIM"` … `$DELIM`): bash does not parameter-expand the here-document delimiter word, so it would match the literal string `$DELIM`, and the randomization is lost.
- **PowerShell: the here-string terminator `'@` is fixed** and cannot be randomized. Reject instead: if any line of the prompt begins with `'@`, ask the user to reword that line before generating.

### Prompt body

For bash-like shells:

```bash
codex exec - [-m <model>] [-c model_reasoning_effort="<effort>"] -C "<project-root>" -s <sandbox, default workspace-write> <<'CODEX_PROMPT_EOF_<random>'
Use the built-in image generation tool to produce the requested image. This turn is ephemeral: only the files attached to this turn exist.

BEGIN USER PROMPT
<exact user prompt>
END USER PROMPT

Operational metadata (not creative direction — use it only to attach files and apply the stated constraints):
- use case: <Codex imagegen taxonomy slug, or omit>
- size: <size>
- quality: <quality>
- count: <count>
- edit target: <image path or none — this is Image 1>
- reference image: <image path or none — style/character guidance for this new generation, do not modify it>
- output directory: <absolute output directory>
- filename base: <codex-image timestamp base>

Requirements:
1. If an edit target or reference image is attached, open it with the view_image tool first, then pass it to the built-in image tool.
2. Generate exactly the requested count, calling the image tool once per image if it produces one at a time.
3. Save the final PNG file(s) in the output directory under the requested filename base. Never overwrite an existing file.
4. If image generation is unavailable in this session, say so directly and do not create placeholders.
5. Your final response must contain only the absolute saved path(s), one per line.
CODEX_PROMPT_EOF_<random>
```

For PowerShell, set the native-pipe encoding to UTF-8 first, otherwise PowerShell 5.1 transcodes the pipe to ASCII and corrupts non-ASCII text (e.g. Korean becomes `??`). The body is identical:

```powershell
$OutputEncoding = [System.Text.Encoding]::UTF8
@'
<same body as above>
'@ | codex exec - [-m <model>] [-c model_reasoning_effort="<effort>"] -C "<project-root>" -s <sandbox, default workspace-write>
```

Attach `--edit` / `--ref` images with Codex CLI's `-i` option. It is a generic attachment transport; the edit-vs-reference distinction is carried by the prompt text and by attachment order — the edit target is always Image 1, references follow.

```bash
codex exec - -i "<edit-or-ref-image-path>" -C "<project-root>" -s workspace-write ...
```

`use case` is optional. When the request maps cleanly onto Codex's own imagegen taxonomy (`photorealistic-natural`, `product-mockup`, `ui-mockup`, `logo-brand`, `identity-preserve`, `precise-object-edit`, and siblings), naming the slug lets Codex apply its per-use-case tips.

## Prompt Quality

Shape a short or vague prompt into a production spec without inventing unrelated content:

- Intended use: asset, mockup, slide visual, product photo, illustration.
- Subject and setting. Style or medium. Composition and framing. Lighting and mood.
- Exact text, quoted verbatim, if any.
- Constraints and avoid list.

A prompt that already carries those slots is passed through with at most normalization. With `--verbatim`, pass the text through untouched and add to the prompt body: *"Use the text between the sentinels exactly as written. Do not rewrite, expand, optimize, translate, or add creative details."*

For edits, state invariants explicitly: what must change and what must remain unchanged, repeated every iteration. For `--ref`, state what carries over from the reference (character, style, palette) and what is new (scene, pose, composition); do not imply the reference itself will be altered.

## Variants

`--variants N` produces N materially different images from one brief, capped at 4. `-n` is unchanged and means the same prompt N times.

Classify the request once, then run:

| Request | Anchor | Per-image prompt |
|---|---|---|
| same design, different styles | one image via `--edit` | the shared design, restyled |
| same subject, different scenes | one image via `--ref` | the shared subject in a new scene |
| different concepts | none | N standalone prompts, materially different in composition and art direction |
| plain repeat (a bare count, no word implying difference) | none | delegate to `-n` |

Words like *different*, *alternatives*, *concepts*, *directions*, *options*, *시안*, *다른 디자인* select the concept branch; a bare count does not.

- If a branch needs an anchor and none exists yet, generate image #1 first, then fan out from that path.
- Issue the N `codex exec` calls as parallel Bash tool calls, each writing its own file.
- Each prompt must stand alone and carry **no ordinal metadata** — no "option 2", no "1번째 시안". Ordering lives in the filename only.
- Finish by `Read`-ing all N and presenting them with their paths so the user picks one. The picked path becomes the `--edit` target for the next revision.

## Revisions

A `codex exec` turn keeps nothing. To revise the last result, pass its output path as `--edit` and re-attach any `--ref` still needed. Always keep the absolute output path in the response: it is the only handle the next turn has.

## Transparent Output

1. Ask the built-in image tool for a genuinely transparent background and to preserve its alpha channel.
2. Verify the result actually has alpha. A returned PNG with an opaque background did not honor the request.
3. Only if that fails, fall back to generating the subject on a flat chroma-key background such as `#00ff00` and removing it locally, and only if a suitable helper exists in the active environment. Complex subjects (hair, glass, smoke, translucent material, soft shadows) do not survive chroma-key; say so rather than shipping a bad cutout.
4. Report transparency as what the returned file shows, not as a model capability. Ask before using any fallback that requires `OPENAI_API_KEY`.

## Result Handling

The built-in image tool always writes first to `${CODEX_HOME:-~/.codex}/generated_images/<session-id>/`. Copying the file into the requested output directory is an extra step the Codex session performs on instruction, and it can fail to happen on any platform — one known trigger is the Windows `codex exec` sandbox blocking shell spawns. Treat recovery as the normal path, not an error branch.

After `codex exec` finishes:

1. Check the output directory for the expected file(s).
2. If one is missing, recover it. `codex exec` prints `session id: <UUID>` near the top of its output. Take the newest `*.png` under that session folder — do not pin a filename pattern, it varies by Codex version — and copy it into the output directory under the requested filename base, refusing to overwrite:

   ```bash
   src=$(ls -t "${CODEX_HOME:-$HOME/.codex}/generated_images/<session-id>"/*.png 2>/dev/null | head -1)
   [ -n "$src" ] || { echo "no image in session folder" >&2; exit 1; }
   dest="<output-dir>/<filename-base>.png"
   [ -e "$dest" ] && { echo "refusing to overwrite $dest" >&2; exit 1; }
   cp "$src" "$dest"
   ```

   Never re-run generation because a copy failed. The image already exists; a second run bills a second generation.
3. `Read` each file for review.
4. Report saved path(s), size and quality requested, count requested versus produced, and any tool limitation Codex mentioned.
5. If generation itself failed, report the Codex CLI version, the error text, and the next concrete command for the user (`codex login`, a Codex update, or a retry at lower quality). Do not fabricate images or write placeholder files.
