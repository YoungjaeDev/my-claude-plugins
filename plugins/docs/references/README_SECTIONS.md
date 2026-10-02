# README Section Menu

When to include each readme.so section, and where it lands in the internal repo order.

Source: [octokatherine/readme.so](https://github.com/octokatherine/readme.so),
`data/section-templates-en_EN.js` at commit `90420ff` (2026-03-13), MIT License. readme.so is an
editor: pick sections, edit them, drag to reorder, download the file. The file defines 34 sections;
names and slugs below are from it, and the "Core" column paraphrases each template rather than
copying it.

The "Internal slot" column refers to the numbered order in `README_PATTERNS.md`
`## Internal Repo Structure` (1 Banner, 2 Name + summary, 3 Badges, 4 Demo or Results, 5 Current
status, 6 Quick start, 7 Structure, 8 Verification, 9 Risks, 10 Docs map, 11 Owner).

## Project sections (29)

| Section (slug) | Core | Include when | Internal slot |
|----------------|------|--------------|---------------|
| Title and Description (`title-and-description`) | H1 plus one line on what it does and for whom | always | 2 |
| Logo (`logo`) | one image at the top | the project has an identity mark and no banner | 1, replaced by the banner; never stack both |
| Badges (`badges`) | shields.io badge row | always, 3-5 badges | 3, static badges |
| Demo (`demo`) | GIF or link to a demo | UI or demo material exists | 4 |
| Screenshots (`screenshots`) | `## Screenshots` with an app image | UI exists | 4, folded into Demo |
| Features (`features`) | bullet list of capabilities | open-source adoption; several capabilities to compare | usually omitted; Current status shows what works |
| Installation (`installation`) | package-manager install command | distributed as a package | folded into 6 |
| Run Locally (`run-locally`) | clone, cd, install dependencies, start | an app or service a teammate runs | 6 |
| Environment Variables (`env-variables`) | env keys to put in `.env` | configuration comes from env | 6, key names only, never values |
| Usage/Examples (`usage-examples`) | a code snippet calling the project | library or CLI | after 6, optional |
| API Reference (`api`) | endpoint or function tables with parameters | others call it | short: after 6; long: linked from 10 |
| Running Tests (`tests`) | the test command | tests exist | 8 |
| Deployment (`deployment`) | the deploy command | the project is deployed | after 8, or a link to a deploy doc (`/docs:deploy-doc`) |
| Tech (`tech`) | client and server stack, one line each | the stack is not obvious from the tree | one line in 7, or a badge in 3 |
| Roadmap (`roadmap`) | planned work as bullets | the plan is stable enough to publish | a "next step" line in 5; the full plan lives in issues or docs |
| FAQ (`faq`) | question and answer pairs | the same questions recur | before 10, or linked from it |
| Documentation (`documentation`) | link to the docs | docs exist | 10 |
| Related (`related`) | links to related projects | sibling repositories matter | 10 |
| Authors (`authors`) | GitHub handles | credit matters | 11 |
| Support (`support`) | where to get help | someone answers | 11, as the contact channel |
| Feedback (`feedback`) | where to send feedback | feedback is wanted | merged into 11 |
| Acknowledgements (`acknowledgement`) | links to resources the project built on | it builds on others' work | after 10, optional |
| Optimizations (`optimizations`) | what was optimized and how | portfolio README | omitted; measured gains go in 5 |
| Lessons (`lessons`) | lessons learned, challenges | portfolio README | omitted; lore belongs in a wiki or docs |
| Used By (`used-by`) | companies using the project | open-source social proof | omitted |
| Contributing (`contributing`) | contributing guide and code of conduct | open to outside contributors | omitted; team workflow lives in `AGENTS.md` or `CONTRIBUTING.md` |
| License (`license`) | license link | distributed | omitted when not distributed |
| Color Reference (`colorreference`) | hex table with swatch images | the repo defines a palette, e.g. a design system | a UI repo only, linked from 10; the swatches load from an external image service |
| Appendix (`appendix`) | anything else | rarely | last |

## Excluded (5)

`github-profile-intro`, `github-profile-about-me`, `github-profile-skills`,
`github-profile-links`, `github-profile-other`: they build a personal GitHub profile README, not a
project README.
