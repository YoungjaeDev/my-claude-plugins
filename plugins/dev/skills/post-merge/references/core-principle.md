# Core Principle: No Stamps, Topical Names, Current State Only

Normative docs (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.claude/rules/*`, Serena memory) hold the **current rules only**. Change history (provenance) is already preserved permanently in git commit messages, PR bodies, and GitHub blame — do not duplicate it inside the docs.

## Forbidden patterns (regex-identifiable)

- `\(?#\d+\)?` — `(#123)`, `#123` inline citations
- `\b(PR|pr|Pull Request) ?#?\d+\b` — `PR #50`, `PR50`, `Pull Request 50`
- `\b([Ii]ssue|이슈) ?#?\d+\b` — `Issue #65`, `이슈 #53` (Korean stamp variant retained so the regex matches both English and Korean projects)
- `\b(Added|Removed|Fixed|Changed|Introduced) in (PR|#)` — historical narrative openers
- `## Post-Merge` — date- or PR-based section headers
- `<YYYY-MM-DD>` embedded inside a section header itself

## Exception — designed history sections

A section MAY opt out of these rules by placing `<!-- history-allowed [max=N] -->` immediately after its H2/H3 heading. The marker applies until the next same-or-higher-level heading. Inside a marked section:

- Pre-Audit stamp grep MUST skip hits.
- Pre-presentation self-check MUST skip added/modified lines.
- Date suffixes in the section name (see Section naming below) are allowed.
- The Anti-Patterns "Never cite a PR or issue" rule does NOT apply.
- If `max=N` is set, History Rotation (see `learning-integration.md`) applies.

Use only when the section MUST hold time-ordered bullets that cannot be absorbed into normative sections (e.g. CHANGELOG entries migrated into a CLAUDE.md summary). Do NOT use as a blanket escape — when in doubt, absorb the learning into a topical section and delete the bullet.

## Section naming

Topical names only (e.g., `## Process Lifecycle`, `## Crawler Throttling`). PR numbers and issue numbers are forbidden in any section name. Date suffixes (`(YYYY-MM)`, `(YYYY-Q[1-4])`) are allowed ONLY inside a section marked `<!-- history-allowed -->`. Full ISO dates (`YYYY-MM-DD`) remain forbidden in section names regardless of marker — bullet-level dates belong inside the bullet text, not in the heading.

## Writing tone

"X is async" (current-state). NOT "X was changed to async in PR #50" (history). NOT "Previously we used Y; now we use X (#50)" (transition narrative).

## Generalize the rule, not the instance

A merged PR shows one concrete case. Record the rule that case is an instance of, not the case. This is a separate axis from stamp removal: a line can carry no `(#N)`, no date, and perfect current-state tone while still encoding a literal that only ever fires on this one diff — every check above passes and the rule is still worthless on the next PR.

- Bad — `'Q4 매출' 열이 있으면 해당 열을 숫자로 변환한다`
- Good — `열 이름에 매출·금액·수량 등 수치를 암시하는 키워드가 있으면 해당 열을 숫자 타입으로 변환한다`

**Test.** Would this line still be true for the next PR that touches the same subsystem? If it only fires on the exact literal from this diff — a column name, a file name, a threshold, a plugin name — it is an instance, not a rule. Restate it at the level of the property that made the literal matter.

**Floor.** Generalize up to the property, not past it. A rule that no longer names what to check (`데이터를 적절히 처리한다`) has been generalized into nothing — keep the discriminating property concrete even when the example is not.

## Language consistency

Match the language of the surrounding section. If the existing doc/section is Korean, write the new bullet in Korean; if English, write English. Never introduce a second language into a single-language section — mid-sentence code-switching breaks readability and grep. Inspect the file's dominant language before writing; when unsure, use the language of the closest sibling bullet.

## Single source of truth (cross-file dedup)

Each rule lives in exactly one file. Before adding new content to one normative doc, briefly check whether a sibling rule file (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.claude/rules/*`) already covers the same topic. If a sibling already owns it, reference via `See @path/to/file.md` instead of duplicating the body. If two files already overlap on the same topic, pick the more specific file as owner, replace the other site with the `See @path` reference, and migrate any unique nuance into the owner. The check is intentionally lightweight — a focused grep on the topic keyword, not a full re-read of every rule file.

## Exception

`Closes #N` / `Fixes #N` GitHub keywords are allowed only inside commit messages, PR bodies, and issue bodies. Forbidden inside normative docs.

## Content-First principle

Refine stale/duplicate content **in place first**, consolidate duplicates next, and only delete a file when it becomes empty or orphaned. File-level deletion is the last resort, not the default.

## Knowledge-routing boundary (lore vs rule)

These normative docs hold **mechanical / tool-operation rules** only. Cross-agent **lore** — provider quirks, design rationale, debugging stories, domain knowledge — does NOT belong here; it graduates to `.llmwiki/` through the wiki ingest step (Step 8, `wiki-ingest.md`), and a finding that meets the graduation bar lands in `.llmwiki/insight/` (read by both Claude and Codex via the shared prompt-inject hook), **never** in `.claude/rules/` (Codex cannot read it). Record each fact in exactly one home: a rule in a normative doc, lore in the wiki. The wiki step runs after config integration precisely so it can dedup against what Steps 6-7 already absorbed.
