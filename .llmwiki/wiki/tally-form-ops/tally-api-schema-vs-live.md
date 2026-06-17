---
id: tally-api-schema-vs-live
aliases: [tally-form-api, tally-openapi-quirks, tally-grouptype-lenient, tally-matrix-maxchoices, tally-image-hosting, tally-free-vs-pro]
last_verified: 2026-06-17
status: active
volatility: volatile
sources: 3
---

# Tally form API: the published OpenAPI diverges from the live /forms contract

`tally-form` builds Tally forms by POSTing a flat block array to `api.tally.so/forms`. The vendor OpenAPI (`developers.tally.so`) is the documented schema, but the **live API accepts and rejects shapes the schema doesn't predict**. Verify every payload against a real `POST` — a successful create returns `status: PUBLISHED`, `hasDraftBlocks: false`; do not trust the schema alone.

## Schema-vs-live divergences (live-verified 2026-06-17)

- **`groupType` is lenient.** The OpenAPI lists `groupType: QUESTION` for input blocks (`TEXTAREA`/`INPUT_DATE`/`INPUT_TIME`) and `FORM_TITLE`, but the live API accepts `groupType == the block's own type` (`TEXTAREA`→`TEXTAREA`, `INPUT_DATE`→`INPUT_DATE`) and `FORM_TITLE`→`TEXT` (matching Tally's own worked example). Two Codex P1s ("forms will fail validation") were **false positives** — the live creates published fine. `MATRIX` is the one container that genuinely uses `groupType: QUESTION`.
- **Matrix single-select cap goes on the MATRIX block, not the rows.** `MatrixRowPayload` *lists* `hasMaxChoices`/`maxChoices`, yet a `POST` with those keys on a `MATRIX_ROW` returns `400 "payload.hasMaxChoices is not allowed"`. The cap must sit on the `MATRIX` container payload. Canonical "schema lists a field the live endpoint rejects" trap — only a real POST reveals it.
- **No media-upload endpoint.** The only path is `/forms`; image fields (`FORM_TITLE.logo`/`cover`, `IMAGE` block `images[].url`) are all `format: uri` — you pass a **hosted public URL**, you cannot upload bytes. A public GitHub repo's `assets/` + a `raw.githubusercontent.com` link is a viable zero-infra host.
- **No on-screen thank-you / confirmation message in the create API.** `FormSettings` has `redirectOnCompletion` and respondent-email fields, but no `thankYou`/`confirmation` field — the post-submit screen text is editor-only. `closeMessageTitle/Description` are for a *closed* form, not per-submission.

## Free vs Pro (tally.so/pricing)

Free: API access, unlimited forms/submissions, theme **colors/fonts**, and every question block this builder emits (multiple-choice, textarea, **matrix**, date, time). Pro ($29/mo): custom CSS, custom fonts (code injection), remove Tally branding, custom domains, **email notifications** (so respondent confirmation emails are Pro), partial submissions, analytics. → the builder stays entirely on the free tier; forms keep the "Made with Tally" badge unless the account is Pro.

## Scope note

Field-level build mechanics (exact block payloads, count formula, theme presets) live in the plugin reference `plugins/tally-form/skills/tally-form/references/tally-blocks.md` — the operational home; this page is the distilled cross-cutting rule, not a duplicate.

> See-also: [[shared-source-codex-manifests]]
> Evidence: live `POST /forms` of `assets/example-matrix-schedule.md` + `example-dev-survey.md` (both `status: PUBLISHED`, `hasDraftBlocks: false`), session 2026-06-17.

## Sources

- Live verification (2026-06-17): created Tally forms `eqoXXk` (matrix/date/time, 17 blocks) + `A7QXgz` (divider/MC/intro, 38 blocks) — both published; `MATRIX_ROW` `maxChoices` 400 → moved to `MATRIX` block.
- Tally OpenAPI — `https://developers.tally.so/api-reference/endpoint/forms/post` (block + payload schemas).
- Tally pricing / Pro features — `https://tally.so/pricing`, `https://tally.so/help/tally-pro`.
