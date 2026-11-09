# Validation and handoff detail

Detail for the Validation and Prompt Handoff steps of `SKILL.md`: the prompt body sent to every `codex exec`, the value checks, the PowerShell form, attachments and the `use case` slug. The bright lines (stdin only, randomized delimiter, path refusal) stay in `SKILL.md`.

## Prompt body (bash)

The randomized delimiter rules in `SKILL.md` apply: replace `<random>` in both lines with the same fresh token. Insert the optional flags only when their arguments were given.

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

## Size, quality and count

- **`auto`**: always valid.
- **`WIDTHxHEIGHT`**: both dimensions positive integers, both edges multiples of 16, max edge <= 3840, aspect ratio <= 3:1, total pixels from 655360 to 8294400.
- **Source of the size rules**: the `gpt-image-2` constraints in the "gpt-image-2 guidance for CLI fallback" section of `${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/SKILL.md`. The built-in tool states none and gets the size only as prompt text, so this check is the only guard; when that file lists different constraints, follow the file.
- **Failure**: ask for a valid size, quality or count instead of changing, downgrading or reducing it.

## Model and reasoning overrides

- **`--model`**: passed through unvalidated against the built-in image tool, which documents no model parameter, so an id meant for the API fallback may be ignored. Omitting it lets Codex's default track the latest model.
- **`--reasoning`**: levels depend on the model and change between Codex releases; read them from `codex debug models` (`supported_reasoning_levels`). When `--model` is given and listed there, the value must be one of that model's levels; otherwise pass it through and let Codex reject it.
- **Opt-in**: image generation barely benefits from reasoning effort, so send it only when the flag is given.

## PowerShell form

Set the native-pipe encoding to UTF-8 first, or PowerShell 5.1 transcodes the pipe to ASCII and Korean becomes `??`. The body is the same as the bash form above:

```powershell
$OutputEncoding = [System.Text.Encoding]::UTF8
@'
<same body as the bash form>
'@ | codex exec - [-m <model>] [-c model_reasoning_effort="<effort>"] -C "<project-root>" -s <sandbox, default workspace-write>
```

## Attachments and use case

`-i` is a generic attachment transport. The prompt text and the attachment order carry the edit-versus-reference meaning: the edit target is always Image 1, references follow.

```bash
codex exec - -i "<edit-or-ref-image-path>" -C "<project-root>" -s workspace-write ...
```

`use case` is optional. When the request maps cleanly onto Codex's imagegen taxonomy, pick the slug from the "Use-case taxonomy" section of `${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/SKILL.md` so Codex applies its per-use-case tips. Omit it when that file is not readable.
