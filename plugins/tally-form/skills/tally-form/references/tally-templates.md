# Tally template reference index

A collection of official Tally templates to reference for structure·design when creating a new form. This skill builds md → blocks deterministically, so it does not import templates. Reference only the patterns (section makeup·question flow) to write the checklist md. It is also the distillation source for the preset voices.

| Template | URL | Use | Structure / design notes |
|--------|-----|------|--------------------|
| Web Project Intake Questionnaire | `tally.so/templates/web-project-intake-questionnaire/w44adw` | web project intake | feature priority + free input mix. dev-survey preset source. |
| Project Intake Form | `tally.so/templates/project-intake-form/mBB15m` | general project intake | overview→scope→schedule flow. dev-survey preset source. |
| Project Intake Form (Template) | `tally.so/templates/project-intake-form-template/wQ0aX3` | project intake variant | short required fields mostly. lightweight-intake reference. |
| Course Registration Form | `tally.so/templates/course-registration-form-template/3N09On` | course registration | applicant info + field selection. lecture preset source. |
| Pre-assessment for Coaching | `tally.so/templates/pre-assessment-for-coaching/mD4Abm` | coaching pre-assessment | current-level·goal diagnostic questions. lecture preset source. |
| User Onboarding Survey | `tally.so/templates/user-onboarding-survey-template/PmObkn` | user onboarding survey | short multiple-choice focused. lightweight satisfaction/onboarding reference. |

- Scheduling is handled with native `%%matrix` (day×time-slot) / `%%date` / `%%time` instead of an external scheduler (Cal.com/Calendly) — external schedulers are not oEmbed targets → no Tally embed, only link-out.
- If interactive editing is needed, there is also the official Tally MCP (`api.tally.so/mcp`, beta), but this skill does not adopt it (preserving determinism·idempotency·dependency-freedom).
