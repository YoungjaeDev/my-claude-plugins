# codex-image

A 1-skill bridge that generates and edits raster images from Claude Code by driving `codex exec` and
the Codex built-in image tool. Claude Code has no image generation, and the alternatives are an
OpenAI API key or a third-party skill repo; Codex CLI already authenticates through ChatGPT OAuth
and ships the tool. Claude-only by design: under Codex the bridge would summon the host it is
bridging to.

## Shape

| Piece | Where |
|---|---|
| Entry point | `/codex-image:codex-image` |
| Procedure | `skills/codex-image/SKILL.md`; size rules, PowerShell form and recovery in `skills/codex-image/references/` |
| Transport | `codex exec -` with the prompt on stdin, `-i` for attachments |
| Codex-side tool | built-in `image_gen`, plus `view_image` to load an attachment |
| Default output | `assets/generated/codex-image/` under the project root |
| Where Codex writes first | `${CODEX_HOME:-$HOME/.codex}/generated_images/<session-id>/` |

Flags and the default output directory are cited by `deck:deck-assets`, `deck:deck-ask` and
`/docs:readme`; renaming one breaks them.

## Decisions

- **Separate `-n` and `--variants`**: `-n` keeps meaning "render this N times"; only `--variants`
  classifies the request.
- **Recovery is the normal path**: the built-in tool writes into the session folder on every
  platform, and the copy to the output directory can be dropped.
- **Shaping by default**: short prompts are shaped into a spec, and `--verbatim` leaves a final
  prompt alone.
- **Sentinels**: user text sits between `BEGIN USER PROMPT` / `END USER PROMPT`, and the options
  block is labelled operational metadata, so a size is never read as creative direction.
- **No runner, manifest or installer**: parallel Bash tool calls already give what a concurrency
  runner would, with zero dependencies.
- **Portability**: no bundled scripts, so no `PLUGIN_ROOT` resolver is needed. The inline shell
  sticks to `ls -t`, `sed -n`, `cp` and `[`, which behave the same on GNU and BSD.
