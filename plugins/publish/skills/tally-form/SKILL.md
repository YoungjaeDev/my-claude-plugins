---
name: tally-form
description: "Build a Tally questionnaire/survey form from a checklist markdown — parse the md, run a copy-voice + humanize pass, build blocks with theme presets, section dividers, paragraph-split intros, per-question choices with required + checkbox (multi-select), short-answer inputs (text/number/email/phone/link), native scheduling (matrix grid, date, time), and form images (logo/cover/inline, URL-hosted) plus redirect-on-completion, then create or idempotently publish via the Tally API and return the share URL. Reusable per project or client. Use when the user wants to '설문 폼 만들어', 'Tally 폼 만들어', 'questionnaire', '체크리스트를 폼으로', '상담 신청 폼', '일정 조율 설문', '폼에 로고/이미지', '필수/복수선택/단답 문항', 'dev survey form', or 'lecture consultation form'."
argument-hint: "--md <checklist.md> [--update <formId>] [--theme neutral|hermes|none|<styles.json>] [--no-dividers] [--no-humanize]"
allowed-tools: Bash(uv run *) Bash(curl *) Read AskUserQuestion
---

# Tally Form

Builds a checklist markdown into a Tally survey form, creates/publishes it, and returns the share URL. Reusable per project/client (dev intake, lecture consultation, etc.). A deterministic, dependency-free (stdlib-only urllib), idempotent builder.

- Verified blocks·themes·publishing rules + the Matrix/DIVIDER/INPUT_*/CHECKBOX·per-question·required·short-answer schema: `references/tally-blocks.md`
- Generic copy tone: `references/form-copy-style.md`
- Domain voice presets: `references/preset-dev-survey.md`, `references/preset-lecture-consultation.md`
- Template reference index: `references/tally-templates.md`
- Ready-to-build example md: `assets/example-{dev-survey,lecture-consultation,matrix-schedule,with-images,intake}.md`

## Workflow

1. **Confirm input** — `--md <checklist.md>` (default) or `--json <spec.json>`. To update an existing form, `--update <formId>` or frontmatter `form_id`. For a new form, set the voice·options·section skeleton with the domain-appropriate preset (`preset-*.md`), and if needed, copy/edit `assets/example-*.md` to start.
2. **Copy-voice + humanize pass** (when writing/editing md) — after applying `references/form-copy-style.md`, by default delegate Korean copy rewriting to `/humanize-korean:humanize-korean` (fast). Detailed routing is under "humanize default routing" below.
3. **Build + preview** — check the block count first with `--dry-run` (parse validation). The itemized parts of the output `built payload: N blocks (...)` must sum to N (matching the count formula in `references/tally-blocks.md`).
4. **Create/publish** — with a key present, POST-create when there is no `--update`, PATCH-publish when there is (preserving the share URL).
5. **Return the result** — print the EDIT/SHARE URL. After publishing, verify `status=PUBLISHED`·`hasDraftBlocks=false` via `GET /forms/{id}` (recommended).

## Execution

`uv run <script>` — under Claude Code, `${CLAUDE_PLUGIN_ROOT}/skills/tally-form/scripts/build_tally_form.py` (works from any install/dev cwd). Codex 0.135 does not export `CLAUDE_PLUGIN_ROOT` and loads the plugin from the cache tree (`~/.codex/plugins/cache/<marketplace>/publish/<version>/`) — so no separate `~/.agents/skills/tally-form` install is created — so use the resolver block below to find the real script path first, then `uv run "$TALLY_SCRIPT"` (the final run is still `uv run`). Hermes searches plugin/skill-level install paths additively (unverified). Since it is stdlib-only, `uv run` runs it directly in an ephemeral environment.

```bash
# Claude Code — CLAUDE_PLUGIN_ROOT is set, run directly (cwd-independent)
uv run "${CLAUDE_PLUGIN_ROOT}/skills/tally-form/scripts/build_tally_form.py" --md <checklist.md> --dry-run   # preview (no API call)
uv run "${CLAUDE_PLUGIN_ROOT}/skills/tally-form/scripts/build_tally_form.py" --md <checklist.md>              # create new
uv run "${CLAUDE_PLUGIN_ROOT}/skills/tally-form/scripts/build_tally_form.py" --md <checklist.md> --update <formId>   # update·publish (idempotent)

# Codex / CLAUDE_PLUGIN_ROOT unset — resolve the real script path from the plugin cache.
# Each branch confirms the target exists before committing; the cache picks the first "complete" version in descending version order.
# The HERMES_HOME search is additive/unverified. The final run is still uv run.
S="skills/tally-form/scripts/build_tally_form.py"
TALLY_SCRIPT=""
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$CLAUDE_PLUGIN_ROOT/$S" ] && TALLY_SCRIPT="$CLAUDE_PLUGIN_ROOT/$S"
[ -z "$TALLY_SCRIPT" ] && [ -f "plugins/publish/$S" ] && TALLY_SCRIPT="plugins/publish/$S"
if [ -z "$TALLY_SCRIPT" ]; then
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  while IFS= read -r d; do
    [ -f "$d/$S" ] && { TALLY_SCRIPT="$d/$S"; break; }
  done < <(ls -1d "$cache_root"/*/publish/*/ 2>/dev/null | awk -F/ '{print $(NF-1)"\t"$0}' | sort -t. -k1,1rn -k2,2rn -k3,3rn | cut -f2- | sed 's#/$##')
fi
[ -z "$TALLY_SCRIPT" ] && [ -n "${HERMES_HOME:-}" ] && [ -f "$HERMES_HOME/plugins/publish/$S" ] && TALLY_SCRIPT="$HERMES_HOME/plugins/publish/$S"   # unverified
[ -z "$TALLY_SCRIPT" ] && [ -n "${HERMES_HOME:-}" ] && [ -f "$HERMES_HOME/$S" ] && TALLY_SCRIPT="$HERMES_HOME/$S"                                          # unverified (skill-level install)
[ -n "$TALLY_SCRIPT" ] || { echo "tally-form: build script not resolved" >&2; exit 1; }
uv run "$TALLY_SCRIPT" --md <checklist.md> --dry-run
```

- `--theme neutral` (default) | `hermes` | `none` (Tally default theme) | `<styles.json>` (custom `settings.styles`).
- `--dividers`/`--no-dividers` — section dividers (default on). `--no-humanize` — skip the humanize pass (see below).
- `--out <path>` — payload sidecar location (default: `<name>_tally_payload.json` next to the input).

## Presets / themes

- **Theme presets** — `neutral` (default, clean monochrome) / `hermes` (warm off-white brand). Custom is `<styles.json>`.
- **Domain presets** — the voice·default options·section skeleton for a new form: `preset-dev-survey.md` (dev/project intake), `preset-lecture-consultation.md` (lecture/coaching consultation). A preset alone cannot build (this skill is input-md based) — edit `assets/example-*.md` as a starting point.
- A `## ` multiple-choice question shares a single frontmatter `options`. When you need **different choices·required·multi-select per question**, override with the `%%choice` directive (see "per-question choices · required · multi-select · short-answer" below). Short-answer is `%%text`/`%%email` etc., free text is `### ` + `- 라벨: ___`, and matrix/date/time are under scheduling.

## Readability

- **Paragraph splitting** — the intro (the first blockquote run right after the title) renders as a separate TEXT block per paragraph when you split paragraphs with an empty `>` line. No dependence on `<br>`.
- **Section dividers** — a DIVIDER block is inserted automatically between `## 섹션` sections (default on, none before the first section). Turn it off with frontmatter `dividers: false` or `--no-dividers`.

## Per-question choices · required · multi-select · short-answer (%%choice / short-answer directives)

Separate from the global `options`-sharing multiple choice (`## `+`- [ ]`), a directive gives each question different choices/required/multi-select/short-answer (non-destructive to the global path). Details·measured basis in `references/tally-blocks.md`.

```markdown
%%choice
title: 관심 분야 (복수 선택)
options: 브랜딩, 웹사이트, 마케팅, 기타   # per-question choices (overrides the global options)
select: multi             # single -> single-select (default) | multi -> checkbox
required: true            # default false
desc: 해당 항목 모두 선택   # (optional) a helper line under the title (question line break)
%%

%%text  label: 이름 (required) (placeholder: 홍길동)
%%email label: 이메일 (required)
%%phone label: 연락처 (desc: 010-0000-0000 형식)
%%number label: 인원수
%%link  label: 포트폴리오 URL
```

- `%%choice` → a per-question-choices multiple choice. `select:multi` = checkbox (multi), `required:true` = required, `desc:` = a helper line right after the title.
- Short-answer `%%text`/`%%number`/`%%email`/`%%phone`/`%%link` → an `INPUT_*` single-line input. The tail is `label:` + a bare `(required)` + `(placeholder: …)` + `(desc: …)` (same shape as `%%date`/`%%time`).
- Directive questions are not auto-numbered (the title as-is). Only the global `- [ ]` gets a `{n}.` number.

## Scheduling (matrix / date / time)

Handled with native blocks instead of embedding an external scheduler (external schedulers are not oEmbed targets → link-out only). At the 1:1-consultation level (Lv1).

```markdown
## 가능한 상담 시간
%%matrix
rows: 월요일, 화요일, 수요일, 목요일, 금요일
cols: 오전, 오후, 저녁
select: single        # single (1 per row) | multi (several)
%%
%%date label: 희망 상담일 (format: yyyy/MM/dd)
%%time label: 희망 시간
```

- `%%matrix … %%` → one MATRIX-grid question. `%%date`/`%%time` → one INPUT_DATE/INPUT_TIME question.
- `select: single` limits each row to 1 column. The `format` enum = `MM/dd/yyyy | dd/MM/yyyy | yyyy/MM/dd`. Fine-grained date constraints (min-date) are outside v1 scope, as the current Tally schema has no single field for it.

## Images & post-submit redirect

Tally has no media-upload API, so images accept only a **hosted public URL**. The builder uses a full `https://` URL as-is, and converts the `owner/repo[@ref]:path` shorthand to a `raw.githubusercontent.com` URL (a public GitHub repo's `assets/` is an infra-free host). A `.gif` URL goes in as-is; verify animated rendering by opening the form.

```markdown
---
logo:  YoungjaeDev/my-claude-plugins@main:assets/logo.png   # circular 200x200 / shorthand OR full URL
cover: https://example.com/cover.jpg                         # full-width 1500px+
redirect: https://yoursite.com/thanks                        # go here after submit (free)
---
# 제목
...
%%image url: owner/repo@main:assets/banner.png
caption: (optional) caption
%%
%%image https://example.com/inline.png                       # single-line shorthand
```

- `logo`·`cover` → the `FORM_TITLE` payload. `%%image` → an in-body `IMAGE` block (`caption`/`link` options). `redirect` → `settings.redirectOnCompletion`.
- Customizing the on-screen thank-you text has no field in the create API (editor-only) — the alternative is `redirect`. A respondent confirmation email is Tally Pro.

## humanize default routing

- **When writing or editing copy**: by default delegate Korean copy rewriting to `/humanize-korean:humanize-korean` (fast) before building.
- **`--update` rebuild** (publish only, no text change): skip humanize.
- **`--no-humanize`**: an explicit escape (a script pass-through flag — omit the rewrite call itself in the main session). The script does not call the rewrite.
- **`humanize-korean` not installed**: graceful degrade — apply only the `form-copy-style.md` rules manually and continue.

## Key handling

- The API key = env `TALLY_API_KEY` → if absent, auto-search the repo `.env` (`TALLY_API_KEY=...`) from CWD upward.
- `.env` is gitignored. **Never print·log·commit the key.**
- With no key, the script only builds the payload and prints `NO_KEY` (safe).

## Publishing & idempotent update (important)

- Publishing = a `PATCH /forms/{id}` including `status:"PUBLISHED"`. PATCHing only `/forms/{id}/blocks` leaves a draft → the share URL does not reflect it. (`references/tally-blocks.md`.)
- `--update <formId>` is safe to run repeatedly with the same md, since it overwrites the same form (idempotent). The share URL is unchanged.

## Checklist md convention

```markdown
---
options:                 # (optional) default = 네, 해주세요 / 나중에 / 설명 듣고 정할게요
  - 네, 해주세요
  - 나중에
  - 설명 듣고 정할게요
theme: neutral           # (optional) neutral (default) | hermes | none | <styles.json>
dividers: true           # (optional) section dividers, default on
form_id: vGWGr0          # (optional) existing form to update (= --update)
logo: owner/repo@main:assets/logo.png   # (optional) logo (shorthand OR full URL)
cover: https://example.com/cover.jpg     # (optional) cover image
redirect: https://example.com/thanks     # (optional) post-submit redirect
---
# 폼 제목                  -> FORM_TITLE
> 인트로 문단 1            -> intro TEXT (the first blockquote run right after the title)
>
> 인트로 문단 2            -> a separate TEXT block when split by an empty `>` line

## 섹션 제목              -> HEADING_2 (the following - [ ] items are multiple choice)
- [ ] 항목 (예: …)        -> a multiple-choice question (auto global numbering, shared options)

### 자유 의견             -> HEADING_2 (the following - 라벨: ___ are free-text)
- 라벨: ___               -> a free-text (TEXTAREA) question (no numbering)

%%choice / %%text / %%number / %%email / %%phone / %%link -> see "per-question choices · required · multi-select · short-answer" above
%%matrix / %%date / %%time -> see "Scheduling" above
```

- Frontmatter takes precedence over the body (`title`/`intro` can be overridden too). The CLI `--theme`/`--update`/`--dividers` take precedence over frontmatter.
- Only the first blockquote run right after the title is the intro. A later blockquote broken off by a blank line (option notes·share URL·internal memo) is ignored.

## Template reference

When shaping a new form structure, consult the URLs·structure notes of the 6 official Tally templates (intake·course registration·coaching·onboarding) in `references/tally-templates.md`. Do not import them; reference the patterns only.

## Alternative: the official Tally MCP (not adopted)

If interactive editing is needed, there is also the official Tally MCP (`claude mcp add tally --transport http https://api.tally.so/mcp`, beta), but this skill does not adopt it — it keeps the urllib builder to preserve determinism·idempotency·dependency-freedom.

## Out of scope

- GIF generation (a separate project — image *references* are supported, generation is not), the on-screen thank-you text (unsupported by the create API — `redirect` is the alternative), a respondent confirmation email (Tally Pro).
- Receiving·aggregating submissions, an all-overlap heatmap (when2meet Lv2+) — outside the 1:1-consultation scope.
- Custom CSS·fonts (Tally paid).
