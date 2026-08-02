---
id: tally-api-schema-vs-live
aliases: [tally-form-api, tally-openapi-quirks, tally-grouptype-lenient, tally-matrix-maxchoices, tally-image-hosting, tally-free-vs-pro, tally-checkbox-grouptype, tally-required-on-option]
last_verified: 2026-08-02
status: active
volatility: volatile
sources: 5
---

# Tally form API: the published OpenAPI diverges from the live /forms contract

`tally-form` builds Tally forms by POSTing a flat block array to `api.tally.so/forms`. The vendor OpenAPI (`developers.tally.so`) is the documented schema, but the **live API accepts and rejects shapes the schema doesn't predict**. Verify every payload against a real `POST` — a successful create returns `status: PUBLISHED`, `hasDraftBlocks: false`; do not trust the schema alone.

## What this page's last pass actually covered

Re-verified **2026-08-02**: the pricing/tier section only, against `tally.so/pricing`. The
schema-vs-live divergences below still date to their **2026-06-17** live run and were *not*
re-checked in that pass — confirming them requires a real `POST /forms`, and no `TALLY_API_KEY`
was available. Treat them as unverified against the current API until someone re-runs a create.

## Schema-vs-live divergences (live-verified 2026-06-17, not re-checked since)

- **`groupType` is lenient.** The OpenAPI lists `groupType: QUESTION` for input blocks (`TEXTAREA`/`INPUT_DATE`/`INPUT_TIME`) and `FORM_TITLE`, but the live API accepts `groupType == the block's own type` (`TEXTAREA`→`TEXTAREA`, `INPUT_DATE`→`INPUT_DATE`) and `FORM_TITLE`→`TEXT` (matching Tally's own worked example). Two Codex P1s ("forms will fail validation") were **false positives** — the live creates published fine. `MATRIX` is the one container that genuinely uses `groupType: QUESTION`.
- **Matrix single-select cap goes on the MATRIX block, not the rows.** `MatrixRowPayload` *lists* `hasMaxChoices`/`maxChoices`, yet a `POST` with those keys on a `MATRIX_ROW` returns `400 "payload.hasMaxChoices is not allowed"`. The cap must sit on the `MATRIX` container payload. Canonical "schema lists a field the live endpoint rejects" trap — only a real POST reveals it.
- **No media-upload endpoint.** The only path is `/forms`; image fields (`FORM_TITLE.logo`/`cover`, `IMAGE` block `images[].url`) are all `format: uri` — you pass a **hosted public URL**, you cannot upload bytes. A public GitHub repo's `assets/` + a `raw.githubusercontent.com` link is a viable zero-infra host. Image URLs must be **https** (http is blocked as mixed content on Tally's HTTPS-served forms). Live-confirmed: a form with `logo` (png), `cover` (**animated gif** — accepted; animation render is a frontend behavior), inline `IMAGE`, and `redirectOnCompletion` published clean.
- **No on-screen thank-you / confirmation message in the create API.** `FormSettings` has `redirectOnCompletion` and respondent-email fields, but no `thankYou`/`confirmation` field — the post-submit screen text is editor-only. `closeMessageTitle/Description` are for a *closed* form, not per-submission.
- **Per-question choices: checkbox is `CHECKBOX`/`CHECKBOXES`, `required` sits on the answer block, `desc` is a `TEXT` block.** The OpenAPI lists both `CHECKBOXES`/`CHECKBOX` and `MULTI_SELECT`/`MULTI_SELECT_OPTION` for multi-select; a live POST publishes an all-options-visible checkbox question as block `type=CHECKBOX`, `groupType=CHECKBOXES` (single-select stays `MULTIPLE_CHOICE_OPTION`/`MULTIPLE_CHOICE`). `isRequired` rides on each **answer block** — every option block, or the `INPUT_*` block for a short-answer field — the same position as MC/matrix, **not** a separate QUESTION container (live GET shows `isRequired:true` persisted per option/input). A per-question helper line (`desc`) is a `TEXT` block (`groupType TEXT`) placed right after the `TITLE`; its `payload.html` is stored back as `payload.safeHTMLSchema` on read (content round-trips), the same mechanism as intro paragraphs — no `<br>`. Short-answer `INPUT_TEXT`/`INPUT_NUMBER`/`INPUT_EMAIL`/`INPUT_PHONE_NUMBER`/`INPUT_LINK` follow the lenient `groupType==type` rule with `payload {isRequired, placeholder?}`.

## Free vs paid (tally.so/pricing, re-checked 2026-08-02)

Free: API access, unlimited forms/submissions, theme **colors/fonts**, and every question block this builder emits (multiple-choice, textarea, **matrix**, date, time). Pro (**$24/mo**, monthly billing): custom CSS, custom fonts (code injection), remove Tally branding, custom domains, **email notifications** (so respondent confirmation emails are Pro), partial submissions, analytics. A third tier, **Business ($74/mo)**, sits above Pro for org-level controls. → the builder stays entirely on the free tier; forms keep the "Made with Tally" badge unless the account is Pro.

Prices move: this page first recorded Pro at $29/mo and knew of no Business tier. Quote the tier a feature needs, not the number, unless the number is what was asked.

## Scope note

Field-level build mechanics (exact block payloads, count formula, theme presets) live in the plugin reference `plugins/tally-form/skills/tally-form/references/tally-blocks.md` — the operational home; this page is the distilled cross-cutting rule, not a duplicate.

> See-also: [[shared-source-codex-manifests]]
> Evidence: live `POST /forms` of `assets/example-matrix-schedule.md` + `example-dev-survey.md` + an image/redirect form (`logo`/`cover`-gif/`IMAGE`/`redirect`) + a `%%choice`/short-answer probe + `assets/example-intake.md` (46 blocks) — all `status: PUBLISHED`, `hasDraftBlocks: false`, session 2026-06-17.

## Sources

- Live verification (2026-06-17): created Tally forms `eqoXXk` (matrix/date/time, 17 blocks) + `A7QXgz` (divider/MC/intro, 38 blocks) + `QKEZog` (logo png / cover animated gif / inline IMAGE / redirect) — all published; `MATRIX_ROW` `maxChoices` 400 → moved to `MATRIX` block.
- Live verification (2026-06-17, tally-form v1.2.0 / PR #68): `%%choice` (single + multi) + short-answer `INPUT_*` + `required`/`desc` probe and the shipped `assets/example-intake.md` (46 blocks) — checkbox published as `CHECKBOX`/`CHECKBOXES`, `isRequired:true` persisted on each option/input payload, `desc` `payload.html` read back as `safeHTMLSchema`; both `status: PUBLISHED`, `hasDraftBlocks: false`, then deleted.
- Tally OpenAPI — `https://developers.tally.so/api-reference/endpoint/forms/post` (block + payload schemas).
- Tally pricing / Pro features — `https://tally.so/pricing`, `https://tally.so/help/tally-pro`.
- Pricing re-check (2026-08-02) — `https://tally.so/pricing` fetched directly: Pro **$24/mo** monthly, a **Business $74/mo** tier above it, and the Pro feature list (custom CSS, remove branding, custom domain, email notifications, partial submissions) unchanged. The schema-vs-live half was not re-run in this pass (no `TALLY_API_KEY`).
