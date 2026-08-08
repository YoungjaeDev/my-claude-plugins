# Tally API — blocks · themes · publishing (measured/verified)

Rules confirmed by measuring `build_tally_form.py` + the Tally official OpenAPI (`developers.tally.so`). Not guesswork.

## Create vs publish (most important)

| Operation | Method · Endpoint | Body |
|------|----------------------|------|
| Create | `POST /forms` | `{status, blocks, settings}` |
| Update·publish | `PATCH /forms/{id}` | `{status:"PUBLISHED", blocks, settings}` |

- Publishing·updating must include `status:"PUBLISHED"` in a **`PATCH /forms/{id}`**. The share URL (`/r/{id}`) is preserved.
- **Trap**: calling only `PATCH /forms/{id}/blocks` leaves it in draft state and **it does not reflect in the share URL**.
- Verify: `GET /forms/{id}` → `status == "PUBLISHED"`, `hasDraftBlocks == false`.

## Block structure

The block array is a flat list. Each block = `{uuid, type, groupUuid, groupType, payload}`.

| Logical element | block `type` | `groupType` | Note |
|-----------|--------------|-------------|------|
| Form title | `FORM_TITLE` | `TEXT` | its own `groupUuid`; `logo`/`cover` URL options in payload |
| Intro/description | `TEXT` | `TEXT` | `payload.html`, 1 block per paragraph |
| Image (in-body) | `IMAGE` | `IMAGE` | `payload.images:[{name,url}]` 1 image + caption/link |
| Divider | `DIVIDER` | `DIVIDER` | `payload {}`, visual separation between sections |
| Section title | `HEADING_2` | `HEADING_2` | `payload.html` |
| Question title | `TITLE` | `QUESTION` | common to all questions, its own `groupUuid` |
| Question helper line (desc) | `TEXT` | `TEXT` | placed right after the title, `payload.html` (question line break/helper) |
| Multiple-choice option (single) | `MULTIPLE_CHOICE_OPTION` | `MULTIPLE_CHOICE` | options share one `groupUuid` |
| Multi-select option | `CHECKBOX` | `CHECKBOXES` | checkbox (select several), share one `groupUuid` (measured) |
| Free-text input | `TEXTAREA` | `TEXTAREA` | its own `groupUuid` |
| Short-answer input | `INPUT_TEXT`·`INPUT_NUMBER`·`INPUT_EMAIL`·`INPUT_PHONE_NUMBER`·`INPUT_LINK` | =`type` | its own `groupUuid`, `payload {isRequired, placeholder?}` |
| Date input | `INPUT_DATE` | `INPUT_DATE` | its own `groupUuid` |
| Time input | `INPUT_TIME` | `INPUT_TIME` | its own `groupUuid` |
| Matrix (grid) | `MATRIX` | `QUESTION` | parent container for rows·columns |
| Matrix row | `MATRIX_ROW` | `MATRIX` | `groupUuid` = the MATRIX block uuid |
| Matrix column | `MATRIX_COLUMN` | `MATRIX` | `groupUuid` = the MATRIX block uuid |

- **TITLE has its own `groupUuid`** (a different group from the option/input blocks).
- One multiple-choice question = 1 `TITLE` + N `MULTIPLE_CHOICE_OPTION`. The options share the same `groupUuid` (`og`).
- Option payload = `{text, index, isFirst, isLast, isRequired}`. `isFirst = (index==0)`, `isLast = (index==N-1)`.
- One free-text/date/time question = 1 `TITLE` + 1 input block (each its own group).

### groupType convention caveat (measured vs OpenAPI)

The Tally OpenAPI schema uniformly lists the `groupType` of input-family blocks (`TEXTAREA`/`INPUT_*`) as `QUESTION`, but the **measured/official examples work with `groupType == type`** (e.g. `INPUT_EMAIL`→`INPUT_EMAIL`). This builder follows the verified `groupType == type` convention (`TEXTAREA`/`INPUT_DATE`/`INPUT_TIME`). Only the `MATRIX` container is the exception with `groupType == QUESTION` (it is classified as a container because `MatrixPayload` has no label field). A live creation confirmed `FORM_TITLE`→`TEXT`, `INPUT_DATE`/`INPUT_TIME`→their own type, `MATRIX`→`QUESTION` all as `status:PUBLISHED, hasDraftBlocks:false`.

## Per-question choices · required · multi-select · short-answer (%%choice / short-answer directives)

Separate from the `## `+`- [ ]` multiple choice that shares one global `options` set, a directive gives each question different choices·required·multi-select·short-answer (keeping the global path non-destructive).

### `%%choice … %%` — per-question multiple/multi-select choice

```markdown
%%choice
title: 관심 분야 (복수 선택)
options: 브랜딩, 웹사이트, 마케팅, 기타   # CSV, per-question choices (overrides the global options)
select: multi             # single -> MULTIPLE_CHOICE (default) | multi -> CHECKBOX
required: true            # default false
desc: 해당 항목 모두 선택   # (optional) a helper line under the title (TEXT) = question line break
%%
```

- Blocks: `TITLE`(QUESTION) + (a `TEXT` if `desc` is present) + N choices. `select:single` → `MULTIPLE_CHOICE_OPTION`/`MULTIPLE_CHOICE`, `select:multi` → `CHECKBOX`/`CHECKBOXES`.
- Directive questions, like matrix/date/time, are **not auto-numbered** (the title as-is). Only the global `## `+`- [ ]` keeps the `{n}.` number.

### Short-answer directives — `%%text`/`%%number`/`%%email`/`%%phone`/`%%link`

```markdown
%%text  label: 이름 (required) (placeholder: 홍길동)
%%email label: 이메일 (required)
%%phone label: 연락처 (desc: 010-0000-0000 형식)
%%number label: 인원수
%%link  label: 포트폴리오 URL
```

- keyword→block_type: `text→INPUT_TEXT, number→INPUT_NUMBER, email→INPUT_EMAIL, phone→INPUT_PHONE_NUMBER, link→INPUT_LINK`.
- Blocks: `TITLE`(QUESTION) + (a `TEXT` if `desc` is present) + 1 input. The tail syntax is the same shape as `%%date`/`%%time` — `label:` + a bare `(required)` + `(placeholder: …)` + `(desc: …)`.

### required / desc placement (measured/confirmed)

- **required** rides on the **answer block payload** — `%%choice` uses each option's (`MULTIPLE_CHOICE_OPTION`/`CHECKBOX`) `payload.isRequired`, and short-answer uses the input block's `payload.isRequired`. Same location as the existing MC/matrix pattern (confirmed `isRequired:true` persists live).
- **desc** goes as a `TEXT` (groupType TEXT) block placed **right after the title·before the answer**. Sending it via `payload.html` makes Tally store it with `safeHTMLSchema` (round-trip) — no dependence on `<br>`.

> Measured 2026-06-17: `%%choice` (single+multi/CHECKBOX, required, desc) + 5 short-answer kinds (text/number/email/phone/link, required/placeholder/desc) + 1 global `- [ ]` section POSTed as one form → 32 blocks `status:PUBLISHED, hasDraftBlocks:false`; GET confirmed CHECKBOX/CHECKBOXES·option/input `isRequired:true`·desc TEXT (safeHTMLSchema) round-trip, then the form was DELETEd.

## Matrix (scheduling grid)

One row×column grid question = 1 `TITLE` + 1 `MATRIX` + N `MATRIX_ROW` + M `MATRIX_COLUMN`.

- `MATRIX` block: `uuid == groupUuid` (= `mg`), `groupType QUESTION`, `payload {isRequired}` (+ `hasMaxChoices/maxChoices` if single-select, below).
- `MATRIX_ROW`/`MATRIX_COLUMN`: `groupUuid = mg` (the parent MATRIX uuid), `groupType MATRIX`.
- Row/column payload = `{index, isFirst, isLast, isRequired, text, html}`.
- **Single-select** (1 column per row): `hasMaxChoices:true, maxChoices:1` in the **`MATRIX` block payload**. **Multi-select**: leave it unset.
  - **Trap (measured)**: putting the same keys in the `MATRIX_ROW` payload gets rejected by the live API as `400 "payload.hasMaxChoices is not allowed"` — the OpenAPI `MatrixRowPayload` *lists* those keys, but they are actually not allowed on a row. Put them at the container (MATRIX) level.
- TITLE goes as its own group before the matrix (mirroring the verified multiple-choice `TITLE`+input-group pattern). Live creation verified — `/questions` returns MATRIX as one question.

## Date / time input

- `INPUT_DATE` payload = `{isRequired, placeholder?, format?}`. The `format` enum = `MM/dd/yyyy | dd/MM/yyyy | yyyy/MM/dd`.
  - The current OpenAPI `InputDatePayload` has no single field for min-date-style constraints (afterDate/dateRange). Fine-grained date constraints are outside v1 scope.
- `INPUT_TIME` payload = `{isRequired, placeholder?}`.

## Images & redirect (live-verified)

Tally has no media-upload endpoint (the only path is `/forms`) — all images are a **hosted public URL reference**. A public GitHub repo's `assets/` + a `raw.githubusercontent.com` link works as an infra-free host (measured). The builder converts the `owner/repo[@ref]:path` shorthand to a raw URL and uses a full `https://` URL as-is.

- **Logo / cover**: `logo` (circular, 200x200 recommended) / `cover` (full-width, 1500px+) URLs in `FORM_TITLE.payload`. Both `format: uri`.
- **In-body image**: an `IMAGE` block = `{type:IMAGE, groupType:IMAGE, payload:{images:[{name,url}], hasCaption?, caption?, hasLink?, link?}}`. `images` is exactly 1.
- **GIF**: a `.gif` URL goes in as-is (live POST confirmed). Whether it renders animated is Tally front-end behavior, so verify by opening the form.
- **Post-submit redirect**: `settings.redirectOnCompletion = {html:<url>, mentions:[]}` (free). Customizing the on-screen thank-you text has no field in the create API (editor-only).

> Measured 2026-06-17: one form with logo(png)+cover(animated gif)+IMAGE(png)+redirect was created as `status:PUBLISHED, hasDraftBlocks:false`.

## Themes

Specified via `settings.styles`:

```json
{
  "theme": "CUSTOM",
  "color": {
    "background": "#FFFFFF",
    "text": "#18181B",
    "accent": "#52525B",
    "buttonBackground": "#18181B",
    "buttonText": "#FFFFFF"
  },
  "direction": "ltr"
}
```

- **`--theme neutral` (default)** = clean monochrome ink-on-white (avoids the slop palette). **`--theme hermes`** = a warm off-white / ink / teal accent / gold CTA preset.
- `--theme none` → omit `settings.styles` (Tally default theme). `--theme <path.json>` → use that JSON as `styles`. A frontmatter `theme:` file path is confined so it cannot read outside the workspace.
- Custom CSS·fonts are Tally paid — out of scope.

## Auth · environment

- The urllib call **requires a browser User-Agent header**. Without it, Cloudflare returns 403 (code 1010).
  - UA used: `Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36`
- The API key = env `TALLY_API_KEY` → if absent, auto-search the repo `.env` (`TALLY_API_KEY=...`) from CWD upward. `.env` is gitignored — **no key exposure·printing**.
- Standard library only (urllib) — no extra dependency. Run directly with `uv run`.

## Block count (for parse validation)

```text
total = 1 (title)
      + number of intro paragraphs
      + number of ## sections
      + max(0, number of sections with a heading - 1)  # divider between sections when dividers on
      + number of multiple-choice items × (1 + option count)
      + number of free-text items × 2
      + number of date items × 2
      + number of time items × 2
      + number of image (%%image) items
      + Σ matrix (2 + row count + column count)
      + Σ %%choice (1 + (desc?1:0) + option count)
      + Σ short-answer directive (1 + 1 + (desc?1:0))
```

`logo`/`cover` (FORM_TITLE payload) and `redirect` (settings) add no blocks.

Example (like the bundled `assets/example-matrix-schedule.md`): title 1 + intro 1 + section 1 + dividers 0 + matrix (2+5+3) + date 1×2 + time 1×2 = **17 blocks**. The `built payload: N blocks` in the `--dry-run` output and the sum of the itemized parts must match (a regression gate).
