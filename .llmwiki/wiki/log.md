# Wiki Log

Append-only event log for the resolved wiki root (`.llmwiki/wiki/`, or a legacy `.claude/wiki/` if that is what the repo has). Each entry under a `## YYYY-MM-DD — <one-line summary>` header. Newest first.

Every `/ingest-finding` run and every `/github-dev:post-merge` run that executes the wiki ingest step writes a block here **before** touching the page, so `git revert` of the resulting commit cleanly reverses both. (Post-merge skips the ingest — and this log — for trivial merges or when no wiki root resolves.) See `ingest-finding` skill for the diff-log discipline.

---

## 2026-07-27 — #166 review: removal sweeps must grep the callers, not just the artifact (ingest-finding)

Diff log written before applying the page edit (git-revertible). Second ingest of the day, from PR #168's review round rather than its authoring. A removal sweep that grepped only the deleted artifact names (`sync-hermes`, `HERMES_ELIGIBLE`, `plugin.yaml`) reported clean while 24 files across 7 plugins still instructed users to run `hermes plugins install` and `skill_view("<plugin>:<skill>")` — the *callers* of the deleted artifact. Codex review caught it. Same page as the existing default-scope trap because both are the same question: "did the detector look where the breakage actually is?"

- plugin-ops/detector-cannot-look-vs-nothing-wrong.md: add Mode 7 (removal sweep greps the artifact's name but not the user-facing commands that depend on it) + a `## Sources` entry for PR #168; sources 5→6, last_verified 2026-07-24 → 2026-07-27.

No insight graduation: Mode 6 (the sibling trap) has not graduated either, and the page is already the consolidated home for this failure family.

## 2026-07-27 — #166: Hermes plugin adapter retired, npx skills is the sole Hermes path (ingest-finding)

Diff log written before applying the page edits (git-revertible). PR #166 deletes `scripts/sync-hermes-manifests.mjs`, `scripts/mock-load-hermes.py`, and the 7 generated `plugin.yaml` + `__init__.py` adapter pairs, plus the `HERMES_ELIGIBLE` allowlist and both Hermes CI/pre-commit guards. Hermes now gets skills only through `npx skills` (`scripts/install-skills.mjs`). Supersede, not overwrite — the adapter page keeps real historical value (the `register_skill` signature settlement, the git-pull-only update model, the generated-but-never-executed blind spot).

- plugin-ops/hermes-plugin-adapter.md: status active→stale, add `> Superseded-by: [[skills-install-wrapper]]` + a retirement note at the top; body kept intact as the record of a retired mechanism. last_verified 2026-07-27, sources 5→7 (adds the #166 entry and corrects a pre-existing off-by-one — the page already carried 6 `## Sources` bullets under `sources: 5`).
- plugin-ops/skills-install-wrapper.md: add `> Supersedes: [[hermes-plugin-adapter]]`; record that this is now the only Hermes delivery path, that `~/.hermes/skills/` is Hermes' skill SoT with passive `skills_list()` + slash-command exposure (retiring the `skill_view()` opt-in load contract), that `-a hermes-agent` installs by COPY not symlink (measured), and that the layout-divergence caveat resolves to the single flat layout. Skill count 47→52. last_verified 2026-07-27, sources 2→4.
- plugin-ops/shared-source-codex-manifests.md: See-also target retargeted to [[skills-install-wrapper]] (the live Hermes page) — the stale adapter page is no longer the right entry point.
- plugin-ops/agents-md-verbatim-no-import.md: same See-also retarget.
- index.md: rewrote both plugin-ops hooks (skills-install-wrapper now carries the Hermes contract; hermes-plugin-adapter marked retired).

No insight graduation: the finding is one PR old, so it fails the "recurs across 2+ independent sessions" bar.

## 2026-07-24 — post-merge #164: brightdata CLI preflight quirks + rg hidden-path parity blindspot (post-merge)

Diff log written before applying the page edits (git-revertible). Merge SHA `b5d288f` — search-stack migration (firecrawl→brightdata + slidev plugin removal). Config integration (Step 6): none new — plugin counts / version bumps / the code-scout brightdata tier landed in the merge itself, and the plugin-removal-is-MINOR rule already lives in `.claude/rules/plugin-versioning.md`; the durable lore is provider-quirk + a verification debugging-story, routed here.

- research-harness/brightdata-cli-preflight-quirks.md: new page, status: active, volatility: volatile, sources: 3 — the Bright Data CLI (bdata 0.3.2) preflight quirks (`budget` exits 0 on 403; `search` needs `default_zone_serp` while `scrape` needs only `default_zone_unlocker`; `scrape_batch` group ambiguity; Pro is a tool-group toggle not a billing tier) + the global search-stack tier + preflight-stop contract.
- plugin-ops/detector-cannot-look-vs-nothing-wrong.md: add Mode 6 (recursive `rg` skips dot-dirs → a parity/removal grep reports a false all-clear while a hidden manifest still holds the token), + Evidence line, sources 4→5, last_verified 2026-07-24.
- index.md: added research-harness/brightdata-cli-preflight-quirks.md hook.

## 2026-07-22 — post-merge #161: grep -oP → POSIX porting traps (post-merge)

Diff log written before applying the page edit (git-revertible). Merge SHA `f4a58c3` — the second macOS/BSD sweep PR (#160): converted all 18 `grep -oP`/`-cP`/`-rhoP`/`-rlP` sites in llm-wiki to portable sed/awk/exact-compare, plus `.githooks/pre-commit` node/PyYAML guards, `.gitattributes` CRLF pinning, and core-config ruff resolution. Config integration (Step 6): none new — the cross-platform review rules already landed in `code_review.md`/`AGENTS.md`/`llm-wiki/CLAUDE.md` via #153's post-merge, so this PR's incremental lore (the porting traps caught in review) routes to the wiki. Also removed 6 `.remember/*` backup-daemon files that a local auto-backup process swept into the PR branch, and gitignored `.remember/`.

- `plugin-ops/stock-userland-verification.md`: new `## Porting traps: grep -oP → POSIX` section — three traps that the #161 review surfaced when replacing PCRE extraction: (1) a greedy sed `.*"key"` prefix selects the LAST match on the line, not the first, so `grep -oP … | head -1` first-match semantics are silently inverted — use awk `match()` (first occurrence) instead; (2) `awk '{…; print}'` prints nothing on empty input (awk exits 0, so a `|| echo 0` fallback never fires) — move the print into `END{}`; (3) both the sed and awk JSON fallbacks stop at the first unescaped-looking `"`, so an escaped quote in a value truncates it (pre-existing, tolerated on the jq-absent fallback path). sources 2 → 3, last_verified 2026-07-22.

## 2026-07-22 — post-merge #153: BSD/macOS userland breaks + stock-userland verification (post-merge)

Diff log written before applying the page edits (git-revertible). Merge SHA `70456bc` — cr-fix path-trust works on BSD/macOS userland (#152). Surfaced by a full macOS 26 (Apple Silicon, bash 3.2, BSD userland) compatibility audit of all 24 plugins; this PR fixed only the blocking prerequisite (cr-fix's own path-trust gate), the rest deferred to a follow-up issue. Config integration (Step 6): `code_review.md` cross-platform bullet extended (`realpath -m` GNU-only; bare `realpath` not a substitute — both GNU/BSD fail on not-yet-existing paths; `cd`+`pwd -P`+`readlink` for the final-component symlink) and a new stock-userland verification rule; `AGENTS.md` P1 mirror updated (`sed -i`·`realpath -m` GNU-only). Those are review-rule mechanics (config), the two wiki items below are lore.

- `plugin-ops/detector-cannot-look-vs-nothing-wrong.md`: new `## Mode 5` — the same "could not look → false clean" invariant, but the detector broke because its own tool was non-portable, not because the input was ugly. `realpath -m` under `set -euo pipefail` aborted for every path on BSD; the Step 9c gate's `|| { skip; continue; }` turned that into "every finding untrusted", and skip touches neither applied nor deferred, so Step 13 declared `final_state=clean` — the one auto-merge-eligible state. Fourth PR in the family (#104/#106/#122/#153), the graduation candidate the 2026-07-13 drain flagged and deferred. sources 3 → 4, last_verified → 2026-07-22.
- `plugin-ops/stock-userland-verification.md` (NEW): an interactive shell can route `grep` through a shim (ugrep) that accepts `-P`, so a `grep -oP` break looks like it works; hooks run as child processes that do not inherit the shell function, and Codex/Hermes have no shim at all. A portability claim verified in the interactive shell is unsound — re-verify under `env -i PATH=/usr/bin:/bin`. Evidenced by this PR's RED (the first symlink-escape test falsely passed under the shim) and the audit's 7 `grep -oP` hits across llm-wiki hooks. volatility stable, sources 2.
- insight graduation: `detector-cannot-look-vs-nothing-wrong` → `.llmwiki/insight/detector-cannot-look.md` — meets all four criteria (recurs across 4 PRs, generalizable, costly [auto-merge of unresolved findings], stabilized). MOC hook added to `insight/index.md`.
- `index.md`: detector hook extended (Mode 5 / non-portable-tool family); new stock-userland-verification entry.

## 2026-07-13 — post-merge #130: heredoc prompt-handoff injection defense (post-merge)

Diff log written before applying the page edit (git-revertible). Merge SHA `936781a` — codex-image heredoc shell-injection fix (#112). A second injection surface on the same skill, distinct from the `-i "<path>"` argument case already on the page: the prompt-body heredoc handoff. Config integration: none — security-design lore, routed to the wiki.

- `plugin-ops/codex-image-bridge-design.md`: new `## Heredoc prompt handoff: random literal delimiter, not a fixed or variable one` section — a fixed `EOF` delimiter lets a prompt line equal to `EOF` close the heredoc early and execute the rest as shell (reproduced live with a canary); the fix is a per-invocation random LITERAL token in both open `<<'TOKEN'` and close, plus a pre-check rejecting a prompt line equal to it. Load-bearing gotcha: bash does NOT parameter-expand the heredoc delimiter word, so a `<<"$DELIM"` variable form matches the literal string `$DELIM` (fixed, predictable) — zero real randomization; the token must be a concrete literal in both positions. Companion to the existing quote/array-exec lesson (two injection vectors, same skill). sources 3 → 4, last_verified → 2026-07-13.

## 2026-07-13 — post-merge #129: resolver-robustness refinements (post-merge)

Diff log written before applying the page edit (git-revertible). Merge SHA `11bdacf` — the cross-runtime PLUGIN_ROOT resolver wave (#111). The base resolver pattern was already on `dual-surface-command-skill-pattern.md`; #129's review (2 Major + 3 Minor across two rounds) surfaced five robustness rules the base pattern omitted. Config integration: none — this is resolver lore, routed to the wiki, not a CLAUDE.md rule.

- `plugin-ops/dual-surface-command-skill-pattern.md`: new `### Resolver robustness` subsection — (1) existence-check each candidate's target BEFORE committing to that branch (a stale `CLAUDE_PLUGIN_ROOT` or incomplete cache dir otherwise blocks valid fallbacks); (2) walk cache versions descending and take the first COMPLETE one, not merely the highest; (3) `${PLUGIN_ROOT}` must be DEFINED (run the resolver) wherever it is substituted, not just in the one entry skill — a sibling skill that references `${PLUGIN_ROOT}/...` without the resolver expands to a broken path; (4) newline-safe cache iteration (`while IFS= read -r`, not `for d in $(ls …)`) so a cache path containing a space survives; (5) required target → hard abort, supplementary target (a doc) → quiet degrade (`PLUGIN_ROOT=""`, rc 0); and the Codex note that a `~/.agents/skills/<plugin>` path is fictional (Codex loads the plugin tree/cache). sources 5 → 6, last_verified 2026-07-07 → 2026-07-13.

## 2026-07-13 — staging drain (33 markers): PR #110/#122 repair-set lore batch (ingest-finding)

Diff log written before applying the page edits (git-revertible). Batch drain of 33 `.staging/` markers (31 from session f24900c0 — recon fleet + #110 impl/reviewer/counsel agents + main; 2 from session 242b83c4). Consolidated by lore item: 4 existing-page edits, 0 new pages. The ~20 anonymous recon-fleet pointers resolve to the recon report, preserved as raw evidence (it lived only in the deletable job tmp dir). Session 242b83c4 markers (PRs 33-84 era) dropped as already-curated — that lore entered the wiki via each PR's mandatory post-merge ingest. Tonight's unattended process decisions (minor_floor vs merge authority, cap extensions) intentionally NOT ingested — single-source, not yet stabilized; PR #122 state file + morning report carry them. Graduation candidate noted, not acted on: detector-cannot-look family now spans 3 PRs (#104/#106/#122) and may meet the insight bar — deferred to an attended session.

- raw/audits/2026-07-12-plugin-fleet-recon.md: recon report copied in from the job tmp dir (17-agent fleet recon; source of the v3 program plan).
- plugin-ops/jq-capture-yields-empty.md: Fact 3 added — jq without `-r` prints an empty-string result as the two-char JSON literal `""`, which passes `[ -n ]`; live repro: poll-codex-grace.sh returned a fabricated empty review id on round 1; sibling in SKILL.md Step 6b skipped grace polling entirely (silent Codex-finding loss). sources 2 -> 3, last_verified 2026-07-13, alias +jq-missing-r-flag.
- plugin-ops/detector-cannot-look-vs-nothing-wrong.md: Mode 4 added — the same family in remote fetchers (PR #122): GraphQL null envelope passing `// []` as false-clean convergence; missing pageInfo = silent multi-page truncation; cursorless hasNextPage = first-page infinite loop; auto-merge-gate probe rc 0 read as 404-unprotected; cr-commit-state fetch failure reported as clean `none` (now a distinct `error` channel, terminal after ERROR_STREAK_MAX); and (added post-merge) auto-merge-gate reading the commit-status surface only while CR posts a check-run — cr_state:unknown forever, --auto-merge never fires — fixed by delegating to cr-commit-state.sh's dual-surface reader. sources 2 -> 3, last_verified 2026-07-13.
- cr-fix-ops/cr-rate-limit-progressive-refill.md: `## The active query` section added — `@coderabbitai rate limit` resolves ambiguous passive sniffs (2.8.0), but anchoring its reply by body-match `last` is ambiguous across runs posting identical text (a prior run's reply is served as fresh while the new post is list-invisible); anchor on the own post id from the `gh pr comment` URL, `reply.id > post.id`. sources 6 -> 7, last_verified 2026-07-13.
- cr-fix-ops/codex-review-threads-never-resolve.md: CR-side counterpart added — CR auto-resolves only threads a fix satisfies; deliberately-skipped suggestions stay open and are re-raised verbatim on every re-review (PR #122 lines 71/604 across 3 rounds), so convergence counts applies/defers only and standing skip-judged threads are expected residue. sources 2 -> 3, last_verified 2026-07-13.
- index.md: jq hook extended (missing `-r` member); detector hook extended (remote-fetcher family).

Markers consumed and deleted: all 33 `.staging/pending-*` files.

## 2026-07-12 — register_skill signature settled by upstream source read (ingest-finding)

Diff log written before applying the page edit (git-revertible). Fleet-recon research agent read `hermes_cli/plugins.py` L1196: `register_skill(self, name, path, description="")` — 2 required + optional 3rd. This retires the same-day "upstream documents 2-arg; our 3-arg emission unverified" caveat (added this morning from the 2026-07-10 docs re-check): docs lag source. Generator + all 7 adapters are correct; a P1 that had been reported 7x across audit groups collapses to this one wiki correction.

- `plugin-ops/hermes-plugin-adapter.md`: provenance-caveat bullet replaced with the settled signature; update-model section's example reworded (the scare itself demonstrates the adapters-never-executed blind spot); Sources +1 (upstream source read), DeepWiki source's "provenance gap" note removed. sources 5 → 6, last_verified unchanged (2026-07-12).

## 2026-07-12 — post-merge #109: fallback-contract drift resolved by cr-fix 2.7.1 + offline test suite (post-merge)

Diff log written before applying the page edits (git-revertible). Merge SHA `75f7c9d` — fix(github-dev): cr-fix 2.7.1 — make the fallback and detection paths work (closes #105). Config integration skipped: the check-run/commit-status dual-surface contract is housed in the PR's own cr-fix references (SSOT) — no CLAUDE.md/rules duplication.

- `cr-fix-ops/cr-cli-fallback-contract-drift.md`: new `## Resolution — cr-fix 2.7.1` section — all three measured drifts fixed (parser rewritten for the 0.6.5 five-key schema incl. string `suggestions` + prose-parsed `line`; Step 5b two-dot → three-dot merge-base diff; sniffer extracts "Next review available in" minutes AND counts that phrasing as a hit), plus the previously-unread check-run surface (`cr-commit-state.sh`: statuses preferred, queued run with null `started_at` sorts newest so a stale success can't mask a queued re-review), plus the root cause addressed (21-test offline suite + fixtures now run the fallback path in CI/pre-commit). Body stays as the drift record; lesson section unchanged. last_verified 2026-07-10 → 2026-07-12, sources 4 → 5 (+PR #109 merge).
- `index.md`: cr-fix-ops drift hook line gains "(fixed in 2.7.1 — offline suite now guards the fallback)".

No insight graduation — plugin-scoped fix record; the general lesson ("fallback paths run only when nobody is watching") already lives in this page.

## 2026-07-12 — post-merge #107: conditional-pointer rule generalizes (2nd instance: [council]) (post-merge)

Diff log written before applying the page edits (git-revertible). Merge SHA `47c796c` — feat(core-config): 1.10.0 — conditional [council] pointer + English global guidance. The English-canonical CLAUDE.md.global decision + cp-not-symlink sync contract are fully housed in that file's own preamble (rule AND rationale) — not duplicated into the wiki per the routing/no-double-recording principle.

- `llm-wiki-design/insight-layer-via-hook.md`: the hook-delivery section now states the generalized conditional-pointer rule — prompt_inject.sh only names surfaces that actually resolve on this machine (knowledge root in cwd → insight pointer; `codex`/`agy` on PATH → one-line `[council]` delegation pointer, Claude-only since Codex is itself a council member). Two instances make it the hook's design rule, not a one-off. sources 2 → 3 (+PR #107 merge), last_verified 2026-06-01 → 2026-07-12.
- `index.md`: insight-layer-via-hook hook line extended (conditional-pointer rule).

No insight graduation — the rule is enforced in one script (`prompt_inject.sh`), not a cross-repo behavioral rule.

## 2026-07-12 — staging drain 88102e17 re-capture: Hermes update-model reality + stacked-PR auto-close (ingest-finding)

Diff log written before applying the page edits (git-revertible). The 3 re-captured `.staging/` markers from session 88102e17 (Stop hook fired after the post-merge #106 mid-session ingest) are NOT fully already-curated — the post-#106 window (Hermes real-machine investigation + PR #107/#108/#109 creation) carries new lore. Ingest-recap portions are DUP and dropped. Repo-actionable (non-lore) findings routed to the current audit backlog instead of the wiki: README orphan commands (`/github-dev:code-review`, `/github-dev:cr-wait`), stale Serena `project-init` memory, cr-fix SKILL.md `$HERMES_HOME/plugins/...` path assumption, 3-arg `register_skill` in generated adapters.

- `plugin-ops/hermes-plugin-adapter.md`: coverage staleness fixed (6 → 7 HERMES_ELIGIBLE, adds `brightdata-guide`); new `## Update model` section (`hermes plugins update` = plain `git pull`, errors `not installed from git` on non-git installs — real-machine output; `plugin.yaml version` unread by Hermes, exists only for `--check` drift guard; adapters in this repo are generated-but-never-executed — only byte-drift is tested); provenance caveats (monorepo subpath install works empirically but is undocumented upstream; `ctx.register_skill` documented 2-arg vs our 3-arg emission; `author:` undocumented key, `kind` enum real); SKILL_DIR layout-divergence caveat (plugin-route `$HERMES_HOME/plugins/<name>/skills/` vs measured npx-skills route `$HERMES_HOME/skills` — two install routes, two layouts). last_verified 2026-07-01 → 2026-07-12, sources 4 → 5.
- `plugin-ops/worktree-squash-merge-gotchas.md`: gotcha 4 added — squash-merging base PR #106 with `--delete-branch` auto-CLOSED stacked child PR #108 (base = the deleted branch); GitHub did not retarget to main; head branch survives, recovery = new PR (observed once, recorded as observation not universal mechanism). alias added. last_verified 2026-07-09 → 2026-07-12, sources 2 → 3.
- `plugin-ops/skills-install-wrapper.md`: 1 cross-ref bullet on the layout divergence (`$HERMES_HOME/skills` flat, per-skill) vs the plugin-adapter route — `> See-also: [[hermes-plugin-adapter]]` already present in reverse; no last_verified bump (no re-measurement).
- `index.md`: hermes-plugin-adapter hook updated (7 plugins + update-model note); worktree hook extended (stacked-PR auto-close).
- `.llmwiki/.staging/`: 3 re-captured markers consumed and deleted (`pending-88102e17…{,-a5813…,-a58fb…}.md`). Plus `pending-242b83c4…-ade1a15f….md` — the Stop-hook capture of this drain's own Explore scan agent, whose entire output IS this ingest; consumed as self-referential, deleted.

No insight graduation — all findings are single-session Hermes/GitHub observations (fail the recurs-across-2+-sessions bar).

## 2026-07-10 — post-merge #106: 진단기의 침묵 실패 + Codex 리뷰 스레드 비해소 + CLI 파서 크래시 지점 정정 (post-merge)

Diff log written before applying the page edits (git-revertible). Merge SHA `78384b5` — feat(project-init): ASK verdict class + three efficacy axes for wiring. 기계적 규율(`jq` 실패를 축 안에 가두기, `CODEX_HOME` 해석, `ASK` 는 묻는 단계를 가진다)은 이번 run 의 Step 6 에서 `plugins/project-init/CLAUDE.md` 에 안착 — 위키는 메커니즘과 증거만 보관 (routing 원칙, 이중 기록 금지). `.llmwiki/.staging/` 의 pending 마커 7건을 이 배치에서 소비.

- `plugin-ops/detector-cannot-look-vs-nothing-wrong.md`: new page (id detector-cannot-look-vs-nothing-wrong, status active, volatility stable, sources 2). read-only 진단기가 `set -euo pipefail` 아래서 한 축의 실패에 통째로 죽거나(출력 0바이트), `|| true` 로 실패를 삼켜 "문제 없음" 으로 답하는 두 실패 모드. `find` 의 exit 1, `jq` 의 손상 입력, `jq --argjson` 에 넘어가는 비-JSON TOML 값이 전부 같은 뿌리. `> See-also: [[jq-capture-yields-empty]]`.
- `plugin-ops/jq-capture-yields-empty.md`: new page (id jq-capture-yields-empty, status active, volatility stable, sources 2). jq `capture()` 는 비매치에서 예외도 null 도 아닌 **무출력**을 낸다. `try … catch null` 이 구제하지 못하고, 객체 생성자 안의 `empty` 는 객체 전체를 소멸시킨다 — 배열에서 항목이 조용히 사라진다. `sniff-cr-rate-limit.sh` 의 "capture() THROWS" 주석은 오기. `> See-also: [[detector-cannot-look-vs-nothing-wrong]]`, `> Refines: [[cr-cli-fallback-contract-drift]]`.
- `cr-fix-ops/codex-review-threads-never-resolve.md`: new page (id codex-review-threads-never-resolve, status active, volatility volatile, sources 2). CodeRabbit 은 재리뷰에서 스레드를 auto-resolve 하지만 Codex 는 하지 않는다. 이미 고친 Codex 코멘트가 매 푸시마다 HEAD 로 재앵커돼 열린 채 쌓인다. 신구 판별은 `pull_request_review_id` 로만 가능하고, `post-merge` Step 1.5 의 `OPEN_THREADS` 프록시는 그래서 과대 계상한다. `> See-also: [[cr-fix-yagni-over-engineering-axis]]`.
- `cr-fix-ops/cr-cli-fallback-contract-drift.md`: 크래시 지점 정정 + `comment` 부재 추가. 파서는 `fileName`/`severity`/`codegenInstructions` 를 이미 처리하고 있었고, 실제 사망 지점은 `.suggestions[0].line` — `suggestions` 가 객체 배열이 아니라 패치 **문자열** 배열이라 문자열 인덱싱에서 jq 가 죽는다. CLI 0.6.5 의 `finding` 키 합집합은 `type/fileName/severity/suggestions/codegenInstructions` 뿐이고 `comment` 는 0건이라, 크래시를 고쳐도 `body`/`type_emoji`/`line` 이 모두 빈다. last_verified 2026-07-09 → 2026-07-10, sources 3 → 4.
- `plugin-ops/agents-md-verbatim-no-import.md`: Codex 설정 루트가 `${CODEX_HOME:-~/.codex}` 라는 한 줄 + doc-budget 절단면이 곧 `## Review guidelines` 라는 점 명시. last_verified 2026-07-09 → 2026-07-10, sources 4 → 5.
- `index.md`: plugin-ops 2줄, cr-fix-ops 1줄 hook 추가.
- `.llmwiki/.staging/`: pending 마커 7건 소비 후 삭제 (5건은 subagent 캡처, 2건은 세션 캡처 — 전부 신호 카운트 색인이고 본문 lore 는 이 배치에 흡수).

insight 승격 없음. `detector-cannot-look-vs-nothing-wrong` 은 4기준(재현·일반화·비용·안정) 을 만족하지만 bash 진단기를 **작성할 때만** 필요한 규율이라, 매 프롬프트에 주입되는 insight 층이 아니라 위키에 둔다.

---

## 2026-07-09 — post-merge #104: AGENTS.md verbatim-load 계약 + worktree .git 파일 + cr-fix CLI 폴백 계약 드리프트 (post-merge)

Diff log written before applying the page edits (git-revertible). Merge SHA `61190bf` — feat(project-init): add wiring skill with shared state detector. 규칙 텍스트 자체(`AGENTS.md` 를 포인터로 축약 금지)는 이번 run 의 Step 6 에서 `.claude/rules/dual-integration.md` + `AGENTS.md` 에 이미 안착 — 위키는 증거와 근거만 보관 (routing 원칙, 이중 기록 금지).

- `plugin-ops/agents-md-verbatim-no-import.md`: new page (id agents-md-verbatim-no-import, status active, volatility stable, sources 4). Codex 는 `@import` 메커니즘 자체가 없고 AGENTS.md 를 verbatim 로드한다 (`codex-rs/core/src/agents_md.rs`); `@import` 는 Claude 전용이며 `CLAUDE.md` 쪽에만 있다. 따라서 유일하게 성립하는 redirect 는 `CLAUDE.md` 가 `@AGENTS.md` 를 import 하는 역방향. prose redirect 도 Codex GitHub cloud reviewer 에는 안 닿는다 (`## Review guidelines` 를 시스템 프롬프트에 직접 로드). `> Refines: [[shared-source-codex-manifests]]`, `> See-also: [[insight-layer-via-hook]]`, `> Promoted-to: [[agents-md-no-import]]`.
- `plugin-ops/worktree-squash-merge-gotchas.md`: gotcha 3 추가 — worktree/submodule 에서 `.git` 은 gitdir 포인터 *파일*이라 `test -d .git` 이 false. 2차 파급(git-flag 로 단락되는 `git check-ignore` 헬퍼가 전부 false → `.gitignore` 커버리지 축이 확정적 거짓 FAIL)은 읽어선 안 보이고 돌려야 보인다. H1 을 squash-merge 한정에서 worktree lifecycle 로 넓힘 (id 불변), alias 추가. last_verified 2026-07-02 → 2026-07-09, sources 1 → 2.
- `cr-fix-ops/cr-cli-fallback-contract-drift.md`: new page (id cr-cli-fallback-contract-drift, status active, volatility volatile, sources 3). rate-limit 폴백 경로가 현재 도구와 계약 불일치 — CodeRabbit CLI 0.6.1 의 finding JSONL 스키마 변경(`fileName`/`severity`/`suggestions[]`, `location` 없음)으로 `parse-cr-cli-jsonl.sh` 사망; Step 5b 의 `git diff A..B` 는 merge-base 가 아니라 양 끝점 비교라 base 전진 시 small-diff 휴리스틱 오판; `sniff-cr-rate-limit.sh` 가 본문의 "Next review available in: 41 minutes" 를 못 읽음. `> See-also: [[cr-rate-limit-progressive-refill]]`.
- `cr-fix-ops/cr-rate-limit-progressive-refill.md`: 신규 페이지 아님 — 기존 페이지가 이미 `Review limit reached` 즉시-rate_limited 라우팅과 content-empty `cr_state: success` 함정을 담고 있어 dedup 통과. Evidence 에 4번째 인스턴스 1줄만 추가 (Fair Usage adaptive limit, commit-status `success / Review completed` 인데 인라인 0건) + `> See-also: [[cr-cli-fallback-contract-drift]]`. last_verified 2026-06-08 → 2026-07-09, sources 5 → 6.
- `plugin-ops/shared-source-codex-manifests.md`: cross-ref 1줄 (`> Refined-by: [[agents-md-verbatim-no-import]]`).
- `index.md`: plugin-ops + cr-fix-ops 에 hook 2줄 추가.
- `../insight/agents-md-no-import.md`: **graduated** (tier insight, promoted_from [[agents-md-verbatim-no-import]], evidence_count 2). 4기준 충족 — PR #43 (insight-layer-via-hook, "Codex 는 `.claude/rules/` 를 못 읽는다") 과 이번 세션의 AGENTS.md redirect 제안으로 2회 재발, 어느 repo 에나 적용, 위반 시 Codex/Hermes 지침이 **에러 없이** 전부 소실, codex-cli 0.142.3 로 검증돼 안정.
- `../insight/index.md`: hook 1줄 추가.
- `.staging/pending-88102e17-*.md`, `.staging/pending-fddffdce-*.md`: 소비 후 삭제. 88102e17 = 이번 세션(lore 는 위 4건이 전부). fddffdce = PR 32–56 참조인데 `post-merge #99`/`#101` ingest 가 이미 적재 — 중복이라 새 페이지 없음.

## 2026-07-09 — post-merge #103: codex-image gpt-image 출력 behavior quirk 3종 (post-merge)

Diff log written before applying the page edits (git-revertible). Merge SHA `6d7750d` — feat(ppt-yeong-style): 0.9.0 — 본문 스토리 개념 일러스트 규약 + 레터링 경계 + drawio 삼분. PR이 실측한 codex-image(gpt-image) 출력 behavior 3종을 재사용 provider lore로 synth. 스토리 일러스트 저작 규약 자체(개념유형→서사패턴·마스코트 연기·anti-slop)는 skill(`plugins/ppt-yeong-style/.../images-and-pop.md` §5d)이 SoT라 위키에 미복제 — routing 원칙.

- `plugin-ops/codex-imagegen-output-behavior.md`: new page (id codex-imagegen-output-behavior, status active, volatility volatile, sources 1). gpt-image via `codex exec`의 출력 behavior 3종 실측 — (1) 짧은 한글 라벨·말풍선은 자소분리·오타 0으로 정상 렌더(장문·자주 바뀌는 문구·정확 수치만 SVG 폴백), (2) "flat, no gradient" 과잉 강조 시 팔레트를 뭉갬 → "flat vector with soft subtle shading"로 완화, (3) 역할색 미명시 시 의미색으로 폴백(배터리→신호등색) → 프롬프트에 역할색 명시. `> See-also: [[codex-image-bridge-design]]`.
- `index.md`: plugin-ops에 codex-imagegen-output-behavior hook 1줄 추가.
- Not graduated to insight: 단일 세션 실측(recurs-across-2+-sessions 미충족) + model-output이라 volatile — 위키 레이어 유지.

## 2026-07-09 — post-merge #101: SubagentStop hook payload contract + post_commit merge-detection fix (post-merge)

Diff log written before applying the page edits (git-revertible). Merge SHA `17a1f26` — fix(llm-wiki): 훅 결함 (2.5.0). Also corrected a concurrent-release `metadata.version` collision (#101 + #102 both bumped 1.85.0→1.86.0 from the shared base; fixed to 1.87.0 per the existing plugin-versioning.md concurrent-release rule — a value fix, no new rule or wiki page).

- `plugin-ops/subagentstop-hook-payload.md`: new page (id subagentstop-hook-payload, status active, volatility volatile, sources 1). The empirically-verified SubagentStop hook stdin contract — Claude Code docs are silent on the two facts that matter: `transcript_path` + `session_id` are the PARENT session's, while the subagent's OWN transcript is under `agent_transcript_path` (`.../subagents/agent-<agent_id>.jsonl`, present at fire time — Explore 68KB / claude-code-guide 116KB verified). To capture delegated-task lore, prefer `agent_transcript_path` and key staging/markers by `agent_id` (session_id collides with the parent). `agent_type` present for typed agents, empty for internal; matcher `""` matches all. `> See-also: [[capture-curation-split]]`.
- `llm-wiki-design/post-merge-trigger.md`: the `wiki_post_commit_hint` bullet now notes the merge-vs-commit split is by command string (`gh pr merge` is a remote op — local `is_merge`/HEAD detection was unreliable, ~always false for `--squash`), per-event rate-limit markers, and `--auto` suppression (deferred merge ≠ completed). sources 4→5, last_verified 2026-07-09.
- `index.md`: added the subagentstop-hook-payload hook under plugin-ops; extended the post-merge-trigger hook.
- Not graduated to insight: single-session finding (fails recurs-across-2+-sessions); stays in the wiki layer.

## 2026-07-08 — post-merge #99: Hermes llm-wiki cross-check consolidated into curated-conservative (ingest-finding)

Diff log written before applying the page edits (git-revertible). Merge SHA `8c2df03` — docs(llm-wiki): Hermes 채택분 반영 + raw/ source-type 재구조화 (2.4.0). The spec (`docs/superpowers/specs/2026-07-07-llm-wiki-hermes-adoption-design.md`) reserved the adopt/reject rationale for this hub page (not a new page); the earlier same-day raw-restructure entry below flagged the same. No insight graduation — design-stance lore, single ingestion; the "steal the ideas, not the plan" thesis stays wiki-layer.

- `llm-wiki-design/curated-conservative.md`: added `## Second cross-check — Hermes llm-wiki skill (2026-07)`. Hermes' `skills/research/llm-wiki/SKILL.md` re-surfaced already-rejected rohitg00-v2 ideas (confidence bands, archive-move, type dirs, raw `[[wikilink]]`s) → re-rejected on the same senior-engineer-test grounds (a 2nd independent maximalist design converging on the same Rejected list); adopted 5 cheap git-legible hygiene gap-fillers (`log.md` year-rotation, raw body-sha256 immutability check, link-poverty lint, bulk-ingest batching, 10+-page edit-scope gate) that fill real plugin gaps without the maximalist machinery; newly rejected Hermes-specific PKM devices (tags taxonomy, query-answer recall / C-group, Obsidian). sources 2→3 (+Hermes SKILL.md); last_verified 2026-07-08.
- `index.md`: extended the curated-conservative hook to note the Hermes 2nd cross-check.
- Staging drain: consumed `pending-61cfe914` (this planning session — the Hermes rationale is ingested here; the hook-defect analysis the transcript also carries is tracked in issue #100, not yet merged, so it stays out of the wiki until #100 lands). PR refs 36–99 all covered by prior log entries. File deleted.

## 2026-07-08 — raw/ source-type restructure + Evidence ref rewrite (ingest-finding)

Diff log written before commit (git-revertible — log + page edits land in one commit). Part of llm-wiki 2.4.0 (#98): `.llmwiki/raw/` moves from a flat dump to source-type buckets (`external/ research/ transcripts/ audits/`). Body sha256 verified unchanged across all 4 `git mv`s — immutability is content, not path.

- `raw/`: `git mv` 4 files into buckets — karpathy·rohitg00 gist → `external/2026-05-29-*`, perplexity md·pdf → `research/2026-05-29-perplexity-llm-wiki-survey.*`; empty `transcripts/`·`audits/` seeded with `.gitkeep`. Files moved as-is (no frontmatter backfill — prospective-only).
- `llm-wiki-design/volatility-over-decay.md`: `> Evidence:` + body raw refs (rohitg00, karpathy) rewritten to new bucket paths. No `last_verified` bump — path maintenance, not re-verification.
- `llm-wiki-design/provenance-over-confidence.md`: rohitg00 + karpathy Evidence refs → new paths (same rationale).
- `llm-wiki-design/curated-conservative.md`: rohitg00 + karpathy Evidence refs → new paths.
- `llm-wiki-design/neutral-llmwiki-root.md`: perplexity survey Evidence ref → new `research/` path.
- No new wiki pages. The Hermes-adoption adopt/reject rationale consolidates into `curated-conservative` at post-merge #98 (not a new page).

## 2026-07-07 — staging drain: re-captured 73e1c10b marker cleared as already-curated (ingest-finding)

- Staging drain: deleted `pending-73e1c10b` (re-captured by the Stop hook when session 73e1c10b ended after the earlier same-day drain — that drain's auto_save lore entry plus the session's own post-merge #97 ingest, commit `47352ff`, cover the transcript's lore; PR refs 12–50 are all in prior log entries). Provenance-only; no page content.

## 2026-07-07 — post-merge #97: mem0 REST list 계약 quirk 3종 + PLUGIN_ROOT 재발 evidence (ingest-finding)

Diff log written before applying the page edits (git-revertible). Merge SHA `24064a7` — feat(mem0-ops): 플릿 레벨 mem0 진단·정리 플러그인 (0.1.0).

- `plugin-ops/mem0-rest-list-contract.md`: new page (id `mem0-rest-list-contract`, status active, volatility volatile, sources 2) — v2 list API의 라이브 계약 quirk 3종(전부 2026-07-07 실검증): (1) entity 와일드카드(`user_id:"*"` 등)는 해당 필드 non-null 행만 매칭 — user/agent/run OR로도 app-only 행 누락, 전체 앱 스코프는 bare `{"app_id"}` 필터가 단순+완전, (2) list는 만료 메모리를 기본 은닉 — 삭제·백업 SSOT는 `show_expired: true` 필수, (3) `HTTPResponse.length`는 chunked 응답에서 None — `not r.length` 가드는 본문을 조용히 버림. tally-api-schema-vs-live와 같은 클래스(vendor 계약 vs 문서). `> See-also: [[mem0-hook-latency-budget]]`, `> See-also: [[tally-api-schema-vs-live]]`.
- `plugin-ops/dual-surface-command-skill-pattern.md`: PLUGIN_ROOT resolver 절에 재발 evidence 추가 — mem0-ops PR #97에서 Codex P1이 bare `${CLAUDE_PLUGIN_ROOT}` 참조를 잡음(2번째 독립 발생). 규칙의 mechanical 홈은 `.claude/rules/dual-integration.md` + AGENTS.md 미러로 승격(이번 post-merge Step 6) — insight 졸업은 이중 기록이라 안 함. sources +1, last_verified 2026-07-07.
- `index.md`: plugin-ops에 mem0-rest-list-contract hook 추가.

## 2026-07-07 — staging drain 73e1c10b: mem0 auto_save 우선순위 함정 (ingest-finding)

Diff log written before applying the page edit (git-revertible). Source: staging marker `pending-73e1c10b` (mem0-ops 플러그인 빌드 + auto_save off 적용 세션).

- `plugin-ops/mem0-hook-latency-budget.md`: rule 4 추가 — env-lever 패턴(rule 1)은 플래그별로 일반화되지 않음: `_identity.sh:68`이 매 훅 실행마다 `~/.mem0/settings.json`의 `auto_save` 값으로 `MEM0_AUTO_SAVE`를 무조건 재할당·export하므로 `~/.claude/settings.json` env에 둔 `MEM0_AUTO_SAVE`는 무효, `~/.mem0/settings.json`이 이 플래그의 SOT (`MEM0_RERANK`는 `_identity.sh`가 안 건드려 env가 유효). AUTO_SAVE off는 자동 캡처 쓰기만 끄고 검색·주입·SessionStart 로드·nudge는 남음. aliases +`mem0-auto-save-priority`; sources 3→4 (session 73e1c10b + `_identity.sh` 재검증 2026-07-07).
- mem0-ops 플러그인 설계 lore(결정론 stdlib 스크립트 = LLM 비용 0, fleet/project 역할 분리)는 root `CLAUDE.md` + 플러그인 문서가 SOT라 위키 페이지 미신설.
- staging marker `pending-73e1c10b` 소비 후 삭제.

## 2026-07-07 — staging drain: mem0 hook latency budget lore + 1 marker already-curated (ingest-finding)

Diff log written before applying the page edits (git-revertible). Source: staging markers `pending-48e62aa5` (2026-07-06 mem0 hook-timeout investigation session) + `pending-5986d0a2` (2026-07-03).

- `plugin-ops/mem0-hook-latency-budget.md`: new page (id `mem0-hook-latency-budget`, status active, volatility volatile, sources 3) — mem0 plugin(0.2.12) UserPromptSubmit 훅의 8s 예산 vs blocking 검색 비용 구조(HTTP 캡 5s/호출, resume 분기 2연속 검색 ~10s, rerank +150-200ms 기본 on), 사용자 소유 `settings.json` env(`MEM0_RERANK=off`)가 캐시 파일 수정보다 업데이트-생존하는 레버라는 규칙, 플러그인 기본 rerank-on이 mem0 공식 Best Practice(측정 전 rerank 금지)와 반대라는 관찰. `> See-also: [[cache-version-pinning]]`, `> See-also: [[mem0-llmwiki-federation]]`.
- `index.md`: `## plugin-ops`에 mem0-hook-latency-budget hook 1줄 추가.
- staging marker `pending-5986d0a2` cleared as already-curated — 해당 세션은 #94/#95 구현 세션(transcript 내 ppt-yeong/gws-sync 마커 2575건)이고 그 lore는 2026-07-06 post-merge #94/#95 ingest가 커버. PR refs 33-68은 전부 기존 log 엔트리에 존재.
- 두 staging 파일 모두 소비 후 삭제.

## 2026-07-06 — post-merge #94/#95: plugin-own agents/ dispatch needs runtime fallback; gws-sync add (ingest-finding)

Diff log written before applying the page edit (git-revertible). Merge SHAs `7b5a721` (#94 ppt-yeong-style 0.7.0 — 서브스킬 분리 + agents/ 4종), `b4d8b59` (#95 gws-sync 신규).

- `plugin-ops/shared-source-codex-manifests.md`: "Skill bodies must be runtime-portable" 절에 plugin-own `agents/` dispatch 케이스 추가 — 플러그인이 자기 `agents/`를 정의하고 스킬(deck-review)이 그걸 subagent로 dispatch하면, `agents/`가 Codex 매니페스트에 미emit + Codex/Hermes에 subagent-dispatch 부재라 이중으로 막힘 → 스킬 body가 순차 체크리스트 fallback을 명문화해야 함. `last_verified` 2026-06-30→2026-07-06, sources 8→9(PR #94), `See-also: [[skill-engine-layering]]`.
- gws-sync의 제안형 Drive 동기화 안전 교훈(캐시 ID 재검증·Shared Drive +upload gap #722·folder MIME·read≠write scope)은 플러그인 내용 특화라 위키 페이지 미신설 — 해당 SKILL.md/CLAUDE.md가 SOT.
- 카운트 정합(23 plugins / 21 Codex-eligible / metadata 1.83.0)은 문서 자체에 반영됨(위키 lore 아님).

## 2026-07-02 — post-merge #92: reference-image arg + quote-don't-denylist shell validation (ingest-finding)

Diff log written before applying the page edits (git-revertible). Merge SHA `e431312` — docs(ppt-yeong-style): logo-source bundle-first + codex-image -i re-check gate (0.5.1).

- plugin-ops/codex-image-bridge-design.md: added 5th design rule "Generic attach flag, no built-in edit-vs-reference semantics" — `codex exec`'s `-i, --image <FILE>...` (verified via `codex exec --help` on codex-cli 0.142.3) is a bare "attach image(s) to the prompt" transport with no CLI-level distinction between edit-in-place and reference-only; a new `--ref` argument added alongside the existing `--edit` relies entirely on prompt-text framing for that distinction, which is unverified with a live generation and documented as such. Extended "Validate passthrough args at the shell trust boundary" with the dogfooded correction from cr-fix PR #92 (5 real findings across 5 iterations, incl. one P0): the first fix denylisted all shell metacharacters including `\` and broke every Windows path (the skill's own PowerShell examples use `C:\...`) — correct rule is quote/array-exec as the actual injection defense, with the character check scoped to shell-command metacharacters only (excluding path-legitimate `\` and `:`), not a blanket denylist. sources 2 → 3; aliases +`--ref`, `edit-vs-reference-arg`; last_verified 2026-07-02.
- index.md: extended the codex-image-bridge-design hook with both facets.

## 2026-07-02 — post-merge #91: invisible-skill cost gate + declared-mirror fan-out (ingest-finding)

Diff log written before applying the page edits (git-revertible). Merge SHA `7be395d` — docs(ppt-yeong-style)+feat(codex-image): layout gates, execution discipline, model-invocable image bridge.

- plugin-ops/codex-image-bridge-design.md: added 4th design rule "Visibility is not a cost gate" — `disable-model-invocation: true` hid the skill from the agent's available list entirely, so a deck-build pipeline whose spec named codex-image re-derived raw `codex exec` usage via a 140k+-token research agent while generation still ran autonomously (the flag hid the recipe without preventing cost); since 1.2.0 the skill is model-invocable with the gate moved in-body (explicit grounding + ask-when-ambiguous). Intro "three design rules" → four; alias `disable-model-invocation` added; sources 1 → 2; last_verified 2026-07-02.
- plugin-ops/skill-engine-layering.md: added declared-mirror fan-out facet — the layer hand-maintains mirrors (SKILL.md SOT → references file → injection-prompt "1:1 압축판" → README section) and PR #91's review findings were 4/4 mirror/doc-sync gaps (enum member missing in one home; new gate conflicting with a boundary in another section; a fix landing in the SOT but not the standalone mirror; README still stating the superseded policy), plus a reverse-drift case (the mirror carried a "같은 layout 5장 연속" ban the SOT lacked). Rule: fan a rule change out to every declared mirror home in the same commit (grep the rule's key tokens across the plugin + README); reviewer re-review is the backstop, not the mechanism. sources 4 → 5; last_verified 2026-07-02.
- index.md: extended both hooks (codex-image in-body gate facet; skill-engine-layering mirror fan-out facet).
- Not promoted to insight: both facets observed in one PR each (recurrence bar not met).

## 2026-07-02 — staging drain: 3 re-captured markers cleared as already-curated (ingest-finding)

- Staging drain: deleted pending-adab2d74 + pending-aec5d2f2 (re-captured by the Stop hook when those sessions ended again after the earlier same-day drain — original skip rationale in that entry) and pending-2d3ca0b3 (this session pre-/clear; PR refs 28/37/47/60/64/81/86/87/89/90 all covered by prior post-merge ingests) as skips. Provenance-only; no page content.

## 2026-07-02 — post-merge #89: worktree lifecycle gotchas around squash-merge (ingest-finding)

- plugin-ops/worktree-squash-merge-gotchas.md: new page (id worktree-squash-merge-gotchas, status active, volatility volatile, sources 1). Distills two git/harness gotchas hit during PR #89's worktree-based implementation: (1) `EnterWorktree`'s default `baseRef: fresh` branches from `origin/<default-branch>`, not local HEAD — local-only unpushed commits on main are invisible in a freshly created worktree until rebased in; (2) `gh pr merge --delete-branch` run from inside a worktree can switch that worktree's own checkout to the base branch and attempt (and fail) a local fast-forward, producing a "not possible to fast-forward" error and an `ExitWorktree` ancestry false-positive — resolved both times via bidirectional content-diff proving no unique local content, then `git reset --hard origin/main` + `discard_changes: true`. Not promoted to insight (recurred within one continuous work session, not across independent sessions).
- index.md: added the worktree-squash-merge-gotchas hook under plugin-ops.

## 2026-07-02 — staging drain: 3 pending markers cleared as already-curated (ingest-finding)

- Staging drain: cleared pending-adab2d74 (this session's PR #87 lore already ingested this same session, see the entry immediately below — `skill-engine-layering.md` sources 3→4, commit `07c407c`), pending-ccadfa81 (PR #84/#83 Hermes lore already ingested via commit `a298d65`, see the 2026-07-01 entry), and pending-aec5d2f2 (PR #86 roster-removal learnings routed to config, not wiki — `.claude/rules/plugin-versioning.md` + `AGENTS.md` via commit `e454cfe`, README via `bb7ec8d`) as skips. No new wiki page/section content — decision is provenance-only.

## 2026-07-02 — post-merge #87: ppt-master lever-alignment as 3rd skill-engine-layering dogfood (post-merge)

- plugin-ops/skill-engine-layering.md: added PR #87 as a 3rd dogfood source; new paragraph on periodic re-audit (a layer's prose can drift/gap even after initial authoring as the engine evolves — re-check against the engine's actual current source, not just at authoring time); two concrete new failure modes recorded (missing lever coverage: ppt-yeong-style's signature had no `visual_style` mapping at all; inaccurate mechanism claim: a lever was described as engine-enforced when it only applies under a different `image_usage` path); sources 3 -> 4; last_verified 2026-07-02.
- index.md: extended the skill-engine-layering hook with the periodic-re-audit facet.

## 2026-07-01 — post-merge #84: Hermes generator + midjourney removal (post-merge)

- plugin-ops/hermes-plugin-adapter.md: updated for PR #84 — adapters now generator-produced (`sync-hermes-manifests.mjs`, 6 HERMES_ELIGIBLE plugins) not hand-written; `plugin.yaml` documented as 5 marketplace-derived fields with the CodeRabbit minimal-manifest decision recorded (kept 5 — drift moot post-generator, `kind: standalone` load-bearing, pilot proves extra fields don't break Hermes); `__init__.py` `yaml.safe_load` try/except hardening; tool-name table expanded (Read/Write, Glob/Grep→search_files, Skill→skill_view, image→image_generate, WebFetch/WebSearch→web_extract/browser_*, NotebookEdit→Jupyter Live Kernel); `${HERMES_SKILL_DIR}`→3-branch revert (Codex caught the var is undocumented/unset on install); version-sync now `--check`-guarded; sources 3→4 (+PR #84, +DeepWiki NousResearch/hermes-agent); last_verified 2026-07-01.
- plugin-ops/shared-source-codex-manifests.md: EXCLUDED 3-member → 2-member (midjourney plugin deleted in PR #84; core-config + codex-image remain); eligible = total − 2; install-skills line drops midjourney.
- plugin-ops/skills-install-wrapper.md: EXCLUDED list → core-config / codex-image (midjourney dropped).
- index.md: shared-source entry EXCLUDED 3→2; skills-install entry drops midjourney; hermes-plugin-adapter entry rewritten for generator-based adapters + expanded tool map + SKILL_DIR revert.
- Staging drain: consumed pending-21b7e3c3 + pending-ccadfa81 (this PR #84's sessions, lore ingested above); cleared already-curated pending-3cf343d1 (PR #72-81) + pending-5419c694 (PR #80-82) as skips (their lore was ingested by their own post-merges).

## 2026-06-30 — post-merge #83: Hermes native plugin adapter (third runtime) (ingest-finding)

- plugin-ops/hermes-plugin-adapter.md: new page (id hermes-plugin-adapter, status active, volatility stable, sources 3). Distills the third-runtime adapter pattern: the shared-source `plugins/<name>/` tree is consumed by Hermes Agent via two hand-written files in the plugin root — `plugin.yaml` (`kind: standalone`) + `__init__.py` entrypoint — installed with `hermes plugins install <owner>/<repo>/plugins/<name> --enable` (github-dev is the pilot; without them install warns). Opt-in skill loading: Hermes plugin-provided skills are NOT auto-exposed in system prompt / skills_list, so callers must `skill_view("<plugin>:<skill>")` and quickstarts cannot use bare slash/text invocation. Runtime-portable bodies extend the shared-source rule with a Claude/Codex→Hermes tool-name map (Bash→terminal, Read→read_file, Edit→patch, AskUserQuestion→clarify, Task→delegate_task, Monitor→process) + dynamic SKILL_DIR (source tree → $HERMES_HOME → ~/.hermes). Version-sync mechanics deliberately NOT restated (routed to .claude/rules/plugin-versioning.md). `> See-also:` shared-source-codex-manifests, skills-install-wrapper.
- plugin-ops/shared-source-codex-manifests.md: added `> See-also: hermes-plugin-adapter` refining the two-runtime (Claude+Codex) framing — a third runtime now consumes the same tree via a native adapter; last_verified 2026-06-30.
- index.md: added the hermes-plugin-adapter hook under plugin-ops.

## 2026-06-25 — post-merge #80: codex-image delegated-CLI bridge design (post-merge)

- plugin-ops/codex-image-bridge-design.md: new page (id codex-image-bridge-design, status active, volatility stable, sources 1). Distills how a Claude skill that delegates to an external CLI (`codex exec` for image gen) is built: (1) inherit the sub-CLI's default model — omit `-m` so it auto-tracks the latest upstream model with zero per-release pin maintenance; `--model` is opt-in only; (2) least-privilege sandbox — default `-s workspace-write` (minimal mode that can still save the PNG), `danger-full-access` / `--dangerously-bypass-approvals-and-sandbox` opt-in only (codex 0.142 exposes no `--yolo` alias for `codex exec`); (3) validate passthrough at the shell trust boundary — `--model` against `^[A-Za-z0-9._:-]+$`, enum-constrain `--reasoning`/`--sandbox` (trailing `-` in a char class is literal; a Codex P2 spuriously read it as excluding hyphens, refuted with bash ERE + python re). `> See-also: codex-image-bridge-design`→`shared-source-codex-manifests`. Evidence: plugins/codex-image/skills/codex-image/SKILL.md.
- index.md: added the codex-image-bridge-design hook under plugin-ops.
- Not graduated to insight: first occurrence (single PR #80) — fails recurs-across-2+-sessions; stays in the wiki layer.
- Routing note: the concurrent-release `metadata.version` collision (PR #77 + #80 both bumped 1.69.0→1.70.0; identical value = no git conflict, so main was left one release short → corrected to 1.71.0) is already covered by `.claude/rules/plugin-versioning.md` Don'ts; recorded there, not duplicated here.

---

## 2026-06-24 — post-merge #79: skills install wrapper (npx skills) lore + EXCLUDED install-scope (post-merge)

- plugin-ops/skills-install-wrapper.md: new page (id skills-install-wrapper, status active, volatility stable, sources 2). Distills `scripts/install-skills.mjs` wrapping `npx skills` (vercel-labs/skills): source arg `.` (reads marketplace.json, groups by plugin), skill selection via *repeated* `-s <name>` (comma fails → "No matching skills found", exit 1), codex global install lands in `~/.agents/skills/<name>/` (not `~/.codex/skills`), Hermes profile targeted by injecting `HERMES_HOME` with one spawn per (agent, profile), and the EXCLUDED-is-manifest-scoped decision (installer filters by skill count, so midjourney/codex-image ARE installable to Codex). `> See-also: skills-install-wrapper`→`shared-source-codex-manifests`. Evidence: scripts/install-skills.mjs.
- plugin-ops/shared-source-codex-manifests.md: added one clause clarifying `EXCLUDED` governs Codex *manifest eligibility*, not *install availability*, plus `> See-also: [[skills-install-wrapper]]`; last_verified 2026-06-23 → 2026-06-24 (EXCLUDED set re-confirmed against the generator this session); sources unchanged (8).
- index.md: added the skills-install-wrapper hook under plugin-ops.
- Not graduated to insight: first occurrence (single PR #79) — fails recurs-across-2+-sessions; stays in the wiki layer.

---

## 2026-06-24 — post-merge #76: cr-fix YAGNI/over-engineering judgment axis (post-merge)

- cr-fix-ops/cr-fix-yagni-over-engineering-axis.md: new page (id cr-fix-yagni-over-engineering-axis, status active, volatility stable, sources 2). Distills the Step 9c 5th axis — a real reviewer finding can still demand unrequested complexity; `over_engineering=yes` skips and overrides `fix_size` (small-safe doesn't save a pure over-engineering suggestion); cr-fix refuses *added* complexity while `ponytail-review` (optional) deletes *existing* — division of labor, bare-name optional dep. `> See-also: skill-engine-layering`. Evidence: PR #76.
- index.md: added the cr-fix-yagni-over-engineering-axis hook under cr-fix-ops.
- Not graduated to insight: first occurrence (single PR #76) — fails recurs-across-2+-sessions; stays in the wiki layer.

## 2026-06-24 — post-merge #75: core-config prompt_inject englishize + federation default off + memory_nudge retired (post-merge)

- llm-wiki-design/mem0-llmwiki-federation.md: corrected the now-stale reversibility claim — `CORE_CONFIG_FEDERATE_MEM0` default flipped 1->0, so federation labels ship OFF and `=1` opts in (was "`=0` reverts", implying default-on); marked the authority section conditional on FEDERATE=1; added `## Retiring a hook that fights the enforced memory system` (memory_nudge.sh retired — its MEMORY.md save-nudge contradicts the mem0 plugin's enforced `block_memory_write.sh` PreToolUse block). `## Sources` += mem0 plugin block_memory_write.sh; sources 2 -> 3; last_verified 2026-06-24.
- plugin-ops/prompt-inject-korean-persistence.md: noted the block was rewritten Korean->English while line 1 still mandates a Korean final reply (English wording stops the model drifting into its own English register while pinning output language); the quoted Korean directive is the original phrasing, the rule now reads in English. last_verified 2026-06-24; sources unchanged at 2.
- index.md: updated the mem0<->llmwiki federation hook — labels off by default (`=1` opts in), not "`=0` reverts".
- Not graduated to insight: federation default + memory_nudge retirement are single-PR design tweaks (fail recurs-across-2+-sessions); stay in the wiki layer.

## 2026-06-23 — post-merge #74: ppt-yeong-style v0.2.0 lore (3 pages) (post-merge)

- plugin-ops/skill-engine-layering.md: 2nd-dogfood refinement — "copy" includes reproducing the engine's internal API *in prose* (exact script names, dev-server ports, Strategist step ordinals, `design_spec` section numbers, layout enum values), not only duplicating files; reference the lever *concept* + stable spec_lock contract keys (`page_rhythm`/`page_layouts`/`image_rendering`) and mark the engine SKILL.md as SOT for exact values. Evidence: PR #74 merged ppt-master-craft.md "SOT 주의" note + SKILL.md §3b enum→concept-reference change. sources 2 -> 3; last_verified 2026-06-23. Not graduated — multi-facet wiki lore, no single crisp promotable rule.
- plugin-ops/shared-source-codex-manifests.md: added `## Skill bodies must be runtime-portable` — a shared skill body that hard-depends on a Claude-only built-in agent (e.g. `claude-code-guide`) in a command/fact-check path is unfollowable under Codex; default to a both-runtime path (official docs), make the Claude-only agent an optional enhancement. Evidence: PR #74 ppt-yeong-style SKILL.md §원칙4 fact-check path. sources 7 -> 8; last_verified 2026-06-23.
- insight/codex-skill-desc-1024.md: added `## CodeRabbit byte-count false positive` — the enforced limit is 1024 *characters* (`desc.length`); CR's description-length finding measures *bytes*, so a Korean (multibyte) description under the char cap but over 1024 bytes is flagged spuriously (ppt-yeong-style: 594 chars / 1049 bytes). Recurred PR #72 + #74 → cr-fix skips when `--check` already passes. last_verified 2026-06-23; evidence_count unchanged at 2 (graduation basis is the real-violation recurrences; the false positive is a complementary skip-rule).
- index.md: extended the skill-engine-layering + shared-source-codex-manifests hooks for the new facets.

## 2026-06-23 — stale-check enforcement covers the insight layer too (ingest-finding)

- llm-wiki-design/volatility-over-decay.md: added `## Enforcement must cover every layer that shares the contract` — the `volatility:`/`last_verified:` window applies to both `.llmwiki/wiki/` and the promoted `.llmwiki/insight/` layer; `wiki_stale_check.sh` was scanning only `.llmwiki/wiki` (insight = silent-rot blind spot), now adds `.llmwiki/insight` when the resolved root is `.llmwiki/wiki`. Generalized rule: a derived layer reusing a freshness contract must sit inside the same enforcement sweep. `## Sources` += the hook script; `> See-also: [[insight-layer-via-hook]]` + `> Evidence:` hook; sources 2 -> 3; last_verified 2026-06-23.
- index.md: volatility-over-decay hook extended to note the sweep covers wiki + insight.
- Not graduated to insight: first occurrence (single PR #73) — fails recurs-across-2+-sessions; stays in the wiki layer.

## 2026-06-23 — skill-on-skill engine layering + cross-marketplace prerequisite-stop (ingest-finding)

- plugin-ops/skill-engine-layering.md: new page (id skill-engine-layering, status active, volatility stable, sources 2). Distills the ppt-yeong-style-on-ppt-master contract — bare-name engine reference (no vendor/copy), optional deps graceful-degrade, but a HARD engine in a separate marketplace is NOT a degrade target: a fresh install of the layer alone has no engine and blocks the build, so stop-before-build + guide install (prerequisite-stop). Invisible in the author's env where the engine is already installed. `> See-also: dual-surface-command-skill-pattern`. Evidence: PR #72 merged SKILL.md §엔진·의존 + Codex P1 fresh-install block. last_verified 2026-06-23.
- index.md: added skill-engine-layering hook under plugin-ops.
- Not graduated to insight: first occurrence (single PR) — fails the recurs-across-2+-sessions criterion; stays in the wiki layer.

## 2026-06-18 — post-merge #71: dogfood-harvest skill-authoring discipline (post-merge)

- plugin-ops/skill-authoring-source-grounded-then-audit.md: added `## 3. Dogfood harvest — interview-gate generic vs project-specific`. A reference skill can grow from your own dogfooded real-project build, not only external OSS; interview-gate each harvested learning generic (-> the shared plugin lane, marketplace-wide) vs project-specific (-> stays in the origin repo) before merging, else the shared plugin is polluted for every other caller. anti-slop-design v0.2.0 PPT lane reflected only the generic slice (color mono / presentation register / build-vs-validation scope + render-validation traps) distilled from a real 27-slide KCI 발표 덱 build; project-specific deck rules stayed in the source repo. Added PR #71 source; sources 1 -> 2; last_verified 2026-06-18.

## 2026-06-17 — harness-engineering principles from the Naver Financial E2E talk (ingest-finding)

- e2e-harness-ops/harness-engineering-principles.md: new page (sources 2 — the talk transcript + the e2e-harness build). Transferable design rationale behind `e2e-harness`: verification is the bottleneck; AI-era bugs cluster at component boundaries (units pass, composed flow breaks); test code = sensor (run) + spec (read); the self-improvement loop (guide before + sensor after) is the delegation criterion; onboard the official agents like a new hire; independent tests via API state-setup; mock by call-site; flake-at-authoring; thinking is delegable but understanding is not; the harness evolves with the model. `> See-also: playwright-ai-harness`.
- insight/harness-loop-guide-sensor.md: promoted the loop principle to insight (promoted_from harness-engineering-principles, evidence_count 2 = talk + e2e-harness build) — "build a self-improvement loop: guide before, sensor after; that question is the delegation criterion." insight/index.md hook added.
- index.md (wiki MOC): added the harness-engineering-principles hook under e2e-harness-ops.
- e2e-harness plugin (recorded for trail, not wiki): enriched e2e-author + the E2E SSOT template with the API state-setup test-independence pattern, and e2e-setup with the "onboard agents like a new hire" rationale; version 0.1.0 -> 0.1.1.

## 2026-06-17 — tally-form per-question choice/required/desc live-verified (PR #68) (ingest-finding)

- tally-form-ops/tally-api-schema-vs-live.md: added a divergence bullet — multi-select checkbox is `CHECKBOX`/`CHECKBOXES` (not `MULTI_SELECT`); `isRequired` rides on each answer block (option / `INPUT_*`), same position as MC/matrix; per-question `desc` is a `TEXT` block after the TITLE (`payload.html`→`safeHTMLSchema` round-trip); short-answer `INPUT_*` follow the lenient `groupType==type` rule. aliases += `tally-checkbox-grouptype`, `tally-required-on-option`; `## Sources` += PR #68 live verification; sources 3 -> 4. last_verified 2026-06-17.
- index.md: hook left unchanged — the existing "OpenAPI diverges from the live /forms API" hook still covers it, and index.md carries an unrelated uncommitted e2e-harness edit in the working tree that must not be bundled into this commit.

<!-- New entries go directly under this line -->

## 2026-06-17 — post-merge #66 + #67: github-dev TDD uplift + e2e-harness plugin (post-merge)

- e2e-harness-ops/playwright-ai-harness.md: new page (domain e2e-harness-ops, parallel to cr-fix-ops/tally-form-ops). Captures Playwright 1.61 `init-agents --loop=claude` actual output (prefixed `playwright-test-*` agent files, `.mcp.json` IS generated with `playwright run-test-mcp-server`, root `seed.spec.ts`, no `playwright.config`, no `copilot` loop value), headless `npx playwright trace` (1.59+) subcommands, burn-in vs CI retries, and GH Actions gotchas (native `paths:` ⊥ `labeled` event, `gh pr comment` needs `issues: write`, no official PR-comment step). sources 2 (playwright.dev + direct 1.61 execution). `> See-also: cr-cli-false-positive-generated-files`.
- index.md: added e2e-harness-ops domain + hook; bumped MOC last_verified 2026-06-10 -> 2026-06-17; rewrote the shared-source hook's stale "19 of 22 eligible" to the durable "all but 3 EXCLUDED" form.
- plugin-ops/shared-source-codex-manifests.md: replaced the hard "19 of 22" eligible count with the durable "total − 3 EXCLUDED" invariant (count shifts on every plugin add/remove); last_verified -> 2026-06-17.
- Config (not wiki, recorded here for the routing trail): added the "update the Codex-eligible count on plugin add/remove" rule to `.claude/rules/plugin-versioning.md` + its `AGENTS.md` mirror — the gap Codex P1 caught on PR #67 (total count bumped, eligible count left stale).
- Staging drain: 7 mechanical Stop-hook captures from prior sessions (PRs 36/62/63/64/65/66/67/68 etc.) skipped — those PRs' post-merge Step 8 already ingested their lore (cr-fix-ops/tally-form-ops/etc. pages exist); the #66/#67 lore is this entry. Consumed files deleted.

## 2026-06-17 — post-merge #65: tally-form v1.1.0 images/redirect — wiki update (post-merge)

- tally-form-ops/tally-api-schema-vs-live.md: consolidated the v2 image/redirect findings into the existing no-media-upload bullet — image URLs must be **https** (http blocked as mixed content on HTTPS forms), and live-confirmed that `logo` (png) + `cover` (animated gif) + inline `IMAGE` + `redirectOnCompletion` publish clean (form `QKEZog`). Extended Evidence + Sources with that form. No new section/page (consolidate-not-append); sources stays 3, last_verified 2026-06-17.

## 2026-06-17 — post-merge #64: tally-form plugin + Tally API schema-vs-live lore (post-merge)

- tally-form-ops/tally-api-schema-vs-live.md: new page + new domain (id `tally-api-schema-vs-live`, status active, volatility volatile, sources 3). Tally OpenAPI diverges from the live `/forms` contract — `groupType` lenient (input blocks accept own type, FORM_TITLE accepts TEXT; two Codex P1s false-positive), matrix single-select `maxChoices` belongs on the `MATRIX` container not `MATRIX_ROW` (live 400 on rows despite the schema listing it), no media-upload endpoint (logo/cover/IMAGE need hosted URLs — public-repo `assets/` + raw link is a host), no create-API thank-you-message field (redirect/email only, email = Pro), API + theme colors + matrix/date/time all free. Field-level specifics stay in the plugin's `references/tally-blocks.md` (not duplicated). last_verified 2026-06-17.
- index.md: new `## tally-form-ops` domain heading + 1-line hook.

## 2026-06-17 — post-merge #63: anti-slop-design skill + source-grounded/coverage-audit methodology (post-merge)

Merge `1ea9f41` (squash). New `anti-slop-design` plugin (v0.1.0): cross-agent guidance skill blocking the AI-generated look (slop) across web/PPT/dashboard/copy, source-grounded in 6 OSS repos. The plugin's WHAT lives in-repo (`plugins/anti-slop-design/skills/anti-slop-design/SKILL.md` + spec + synthesis) — NOT duplicated here. Mechanical tool-rules (YAML frontmatter colon-quote; `.claude/settings.json` `plugins.local` registration surface) routed to `.claude/rules/{dual-integration,plugin-versioning}.md` + `AGENTS.md` (NOT re-recorded here, per knowledge routing). One reusable methodology lesson lands in the wiki.

- plugin-ops/skill-authoring-source-grounded-then-audit.md: NEW page (id `skill-authoring-source-grounded-then-audit`, status active, volatility stable, sources 1) — build a reference/guidance skill from source-grounded OSS investigation (read the repos, not summaries-of-summaries — counts drift: impeccable README "27" vs registry 44, hallmark "57" vs 58), then run a COVERAGE AUDIT of the distillation whose key axis is documented-vs-enforced (anti-slop-design: 21/21 patterns in the reference taxonomy but only 19/21 in the binary ship-gate until patched). Build and verify as separate passes.
- index.md: added plugin-ops/skill-authoring-source-grounded-then-audit.md hook

## 2026-06-16 — cr-fix state-file not self-describing until emit-final-json persists final fields (ingest-finding)

- cr-fix-ops/state-file-self-describing.md: new page, status active, volatility stable, sources 1 — emit-final-json assembled final_state + auto_judge_stats into stdout only, never into the archived state file; post-merge Step 1.5 reading the archive saw final_state=unknown / defer=0 and silently hid deferred reviews. Caught by Codex P1 in the PR #62 dogfood. Fixed by persisting final fields before the archive mv. Active design contract (minor_floor / same-file generalization) deliberately NOT duplicated — it lives in cr-fix `references/`.
- index.md: added cr-fix-ops/state-file-self-describing.md hook

## 2026-06-10 — post-merge #61 (post-merge)

Merge `0d08b9e` (squash). Issue #59 (PR 2 of 2): borrow two mem0 *patterns* (not data, not runtime) into llmwiki, mem0 fully decoupled. Scanned the PR file list (`gh pr diff 61 --name-only`): `core-config/hooks/prompt_inject.sh` (authority label + CORE_CONFIG_FEDERATE_MEM0 flag), `llm-wiki/skills/lint-wiki/SKILL.md` (Step 1 dedup scoring), core-config 1.7.0→1.8.0, llm-wiki 2.2.0→2.3.0, marketplace metadata 1.54.0→1.55.0. cr-fix converged clean after iter 1 (2 real findings applied: CR Minor — PCRE-quote `$tok` with `\Q\E`; Codex P2 — map alias clusters to files; iter 2 CR clean + Codex no re-review). Mechanical facts (the flag + labels, the llm-wiki hook count 3→5 straggler) routed to `plugins/core-config/CLAUDE.md` + `plugins/llm-wiki/CLAUDE.md` (NOT re-recorded here). One design-lore finding lands in the wiki.

- llm-wiki-design/mem0-llmwiki-federation.md: NEW page (id `mem0-llmwiki-federation`, status active, volatility stable, sources 2) — why mem0 and llmwiki coexist by **labels only**, never runtime coupling. prompt_inject.sh labels the `.llmwiki/` pointer `[AUTHORITATIVE]` (dated/sourced wins) and emits a `[RECALL]` note placing mem0 recall as secondary — it never calls/reads mem0 (mem0 surfacing stays mem0's own hooks). Codex omits `[RECALL]` (no mem0 layer there), so durable cross-agent lore must still reach `.llmwiki/`. The borrow is conceptual: an authority *label* and (in lint-wiki) a scoring *rubric* — coarse High/Medium/Low band, never a fabricated float (provenance-over-confidence). `CORE_CONFIG_FEDERATE_MEM0=0` reverts to the plain pointer. Evidence: `plugins/core-config/hooks/prompt_inject.sh`, `plugins/llm-wiki/skills/lint-wiki/SKILL.md`.
- index.md: registered the new page under llm-wiki-design; last_verified bump.

## 2026-06-10 — post-merge #60 (post-merge)

Merge `83e075c` (squash). Issue #58: make llmwiki actually auto-trigger by splitting mechanical capture (Stop hook) from LLM curation (next SessionStart drain). Scanned the PR file list (`gh pr diff 60 --name-only`): llm-wiki gains `hooks/wiki_session_capture.sh` (Stop) + `hooks/wiki_session_start_drain.sh` (SessionStart), plugin.json hook registration 2.0.0→2.2.0, post-merge Step 8 forced-logging contract (github-dev 2.2.1→2.3.0), `.gitignore` staging entry, marketplace metadata 1.52.0→1.54.0 (two-step advance past the concurrent #56 release, per `.claude/rules/plugin-versioning.md`). Mechanical fact (llm-wiki hook count 3→5) routed to root `CLAUDE.md` (NOT re-recorded here). Two design-lore findings land in the wiki.

- llm-wiki-design/capture-curation-split.md: NEW page (id `capture-curation-split`, status active, volatility stable, sources 2) — why session-boundary auto-capture is split into a mechanical Stop hook (scans transcript for ingest signals, writes per-session `.staging/pending-<sid>.md` pointer, touches no wiki page) and an LLM curation turn (next SessionStart drain injects an `ingest-finding` directive). A shell hook can't dedup/resolve conflicts, so it only flags + points at the transcript; over-capture is safe because the `ingest-finding` dedup gate absorbs it. Honest limitation: if the next session never opens, staging accumulates (lint flags it) — fully unattended instant ingest is impossible with a shell hook alone. Evidence: `plugins/llm-wiki/hooks/wiki_session_capture.sh`, `wiki_session_start_drain.sh`.
- llm-wiki-design/post-merge-trigger.md: UPDATED (sources 3→4, last_verified→2026-06-10). Added the **forced-logging contract**: Step 8 now emits a single mandatory checkpoint on every path (`wiki-ingest: ingested N` / `no-lore (<reason>)`) — no silent skip. `WIKI_AUTOINGEST=0` disables the auto-ingest while still logging the skip. `> See-also: [[capture-curation-split]]` (the session-boundary third path, complementing the two merge paths).
- index.md: registered the new page under llm-wiki-design; last_verified bump.

## 2026-06-08 — post-merge #56 (post-merge)

Merge `6dd72e5` (squash). Issue #55 fix: cr-fix mistook the transient `success / "Review skipped: free tier disabled"` placeholder for a terminal status and dropped the real review. Scanned the PR file list (`gh pr diff 56 --name-only`): cr-fix `poll-cr-status.sh` + `pre-flight.sh` + `SKILL.md` + `references/pre-flight-rules.md`, github-dev 2.2.0→2.2.1, marketplace metadata 1.51.0→1.52.0 (two-step advance past the concurrent #54 release, per `.claude/rules/plugin-versioning.md`). This is a **code-level correction** of existing volatile lore — no new page; no config/CLAUDE.md mechanical rule (the `CR_SKIP_GRACE` knob is self-documented in the cr-fix skill; the lore home is the wiki).

- cr-fix-ops/cr-rate-limit-progressive-refill.md: UPDATED (sources 3→4, last_verified stays 2026-06-08). Added `## Code-level fix (PR #56)` section: pre-flight/poll no longer route `success / "Review skipped: free tier disabled"` straight to `rate_limited`; they hold it non-terminal for `CR_SKIP_GRACE` seconds (default 300, env-only, mirrors `EARLY_CHECK_WINDOW`). Within grace → `cr_wait` (sniff guarded so the placeholder can't re-flag); past grace → `rate_limited`; grace anchored to status `created_at` / `push_age` (a one-shot probe has no prior observation). `poll-cr-status.sh` records first-seen-skip and keeps polling until the row flips to `Review completed` or grace expires. Genuine `Review limit reached` / `rate limited` route immediately, unchanged. Resolves the page's own open note that the gate "should distinguish progressive-refill from hard-cap" and the content-empty `cr_state: success` false-clean caveat (poll now holds instead of returning premature success). Open follow-up noted (not asserted): sniffer comment-channel false-positive (#57).

## 2026-06-08 — post-merge #54 (post-merge)

Merge `582cfa6` (squash). Scanned the PR file list (`gh pr diff 54 --name-only`): docs-forge gains `/docs-forge:deploy-doc` + `/docs-forge:moc` (command + guide-skill SSOT + reference each), version 0.2.1→0.3.0, marketplace metadata 1.50.0→1.51.0, Codex manifests regenerated. Merged diff applies already-documented patterns (`[[dual-surface-command-skill-pattern]]`, `[[shared-source-codex-manifests]]`, `.claude/rules/plugin-versioning`) — no NEW lore from the diff; no config/CLAUDE.md mechanical rule needed (conventions already captured). One process finding from the 5-iter cr-fix loop ties to existing lore.

- cr-fix-ops/cr-rate-limit-progressive-refill.md: UPDATED (sources 2→3, last_verified→2026-06-08). Added a 3rd confirming dogfood instance (PR #54): a 5-push burst where CR skipped early commits (`"Review skipped: free tier disabled"`) and completed the final one (progressive refill), with Codex co-reviewing throughout. Establishes the **co-reviewer recovery path** (distinct from the PR #50 CLI fallback) and the caveat that `cr_state: success` is content-empty during the CR skip window — a false "clean" if CR is the only reviewer.

## 2026-06-05 — post-merge #50 (post-merge)

Merge `ffab9c7` (squash). Scanned the PR file list (`gh pr diff 50 --name-only`): prompt_inject.sh block strengthen + post-merge Step 4.5 ephemeral pruning + versioning. Two findings tie to lore; one existing page re-verified. The gh `{owner}/{repo}` invariant surfaced by Codex review was routed to `plugins/github-dev/CLAUDE.md` (mechanical rule) — NOT duplicated here.

- plugin-ops/prompt-inject-korean-persistence.md: NEW page (id `prompt-inject-korean-persistence`, status active, volatility stable, sources 2) — why the per-prompt block must explicitly name internal workflow / subagent / English-skill paths (ultracode, deep-research) as NOT a "별도 지시"; otherwise an English skill body downstream reads as the override the Korean-default line defers to, and the final user answer regresses to English. Evidence: `plugins/core-config/hooks/prompt_inject.sh`.
- cr-fix-ops/cr-cli-false-positive-generated-files.md: NEW page (id `cr-cli-false-positive-generated-files`, status active, volatility stable, sources 2) — the local CodeRabbit CLI flags a *correctly regenerated* `.codex-plugin/plugin.json` as "manually edited, revert + regenerate" (Major). It is a false positive: the canonical edits were in `plugin.json` + `marketplace.json` and the generator was run. `node scripts/sync-codex-manifests.mjs --check` passing proves the file is generator-consistent → skip the finding. `> See-also: [[codex-manifest-regen]]`. Evidence: `plugins/github-dev/.codex-plugin/plugin.json`.
- cr-fix-ops/cr-rate-limit-progressive-refill.md: UPDATE — PR #50 is a 2nd independent dogfood confirming `cr_desc: "Review skipped: free tier disabled"` → `gate=rate_limited` → auto→cli fallback (CLI v0.5.2 gave a full review). Added as a confirming data point; last_verified 2026-05-30 → 2026-06-05 (sources unchanged).
- index.md: registered the 2 new pages under their domains; last_verified bump.
- Evidence: `plugins/core-config/hooks/prompt_inject.sh`, `plugins/github-dev/.codex-plugin/plugin.json`, `scripts/sync-codex-manifests.mjs`.

## 2026-06-01 — insight promotion (3 entries) + body-transform dedup + code-scout id fix (ingest-finding)

Diff log written before applying the page edits (git-revertible). Full insight-layer pass over the existing wiki: promote 3 stabilized findings to `.llmwiki/insight/`, compress one duplicated narrative, fix one identity-rot id. No wiki page deleted; each insight entry condenses (never copies) its `promoted_from:` source.

- insight/codex-manifest-regen.md: new insight entry (id `codex-manifest-regen`, tier insight, promoted_from [[shared-source-codex-manifests]], evidence_count 2, volatility stable, sources 2) — rule: regenerate Codex manifests (`node scripts/sync-codex-manifests.mjs`) on any plugin skills/version/description/category change; `--check` is the CI drift gate; never hand-edit generated manifests or reintroduce a body-transform mirror.
- insight/cr-rate-limit-budget.md: new insight entry (id `cr-rate-limit-budget`, tier insight, promoted_from [[cr-rate-limit-progressive-refill]], evidence_count 2, volatility stable — stable core only; the source page stays volatile, sources 2) — rule: CR `Review skipped: free tier disabled` = progressive-refill quota exhaustion, NOT a plan downgrade; do not add a sniff cooldown; treat `--max-iter` as a CR quota budget. (The planned-v3 `--push-spacing` detail is intentionally left in the wiki, not promoted.)
- insight/plugin-cache-restart.md: new insight entry (id `plugin-cache-restart`, tier insight, promoted_from [[cache-version-pinning]], evidence_count 2, volatility stable, sources 2) — rule: a session pins each plugin's version at startup; mid-session marketplace updates are invisible until restart; during a migration window drive work from repo source, not the pinned skill; refresh via restart or `rm -rf` of the plugin cache.
- insight/index.md: registered the 3 entries under `## Entries`; last_verified 2026-06-01.
- llm-wiki-design/neutral-llmwiki-root.md: consolidation — compressed the `## Vindication` section (a full re-telling of the 275-hit body-transform audit + the same 3 examples) to a short pointer at the canonical account in [[shared-source-codex-manifests]] (`## Why the body-transform mirror was wrong`). Kept the conclusion; removed the duplicated body. last_verified 2026-06-01 (sources unchanged).
- research-harness/code-scout-vs-deep-research-boundary.md: identity-rot fix — `id: code-scout-deep-research-boundary` → `code-scout-vs-deep-research-boundary` (now matches the filename and the `code-scout-vs-deep-research` alias); no cross-page `[[ref]]` pointed at the old id. last_verified 2026-06-01.
- Evidence: `.llmwiki/wiki/plugin-ops/{shared-source-codex-manifests,cache-version-pinning}.md`, `.llmwiki/wiki/cr-fix-ops/cr-rate-limit-progressive-refill.md`, `.llmwiki/insight/index.md`.

## 2026-06-01 — post-merge #42 + #43 (post-merge-wiki)

Scanned the merge diffs `f6efe50` (#42 dual-integration rule) + `799a9bb` (#43 insight layer + prompt-inject hook) per `git show --name-only`. No new wiki page ingested — both PRs were already self-documenting:

- #43 shipped its own wiki lore in-PR: `llm-wiki-design/insight-layer-via-hook.md` (new) + `neutral-llmwiki-root.md` / `curated-conservative.md` updates + a `log.md` entry (the 2026-06-01 insight-layer entry below).
- #42's `.claude/rules/dual-integration.md` is a normative Claude↔Codex surface-sync checklist whose design rationale already lives in `plugin-ops/shared-source-codex-manifests.md` (the rule cites it at its Source-of-Truth line) + `llm-wiki-design/{neutral-llmwiki-root,insight-layer-via-hook}.md`. A dedicated page would duplicate that, so none was added.
- rules/*.md flags: none — dual-integration.md is a new rule file, not an invariant change.

## 2026-06-01 — insight layer + refine design record (ingest-finding)

Diff log written before applying the page edits (git-revertible). Captures the WS2 insight-layer migration (the `.llmwiki/insight/` promoted layer + the `.claude/rules/`-as-promotion-target retirement).

- insight/index.md: new insight MOC at `.llmwiki/insight/` (promotion criteria, `tier`/`promoted_from`/`evidence_count` frontmatter schema, non-append consolidation discipline). Separate from the wiki MOC; pointed at by the wiki `index.md` intro + the core-config prompt-inject hook.
- llm-wiki-design/insight-layer-via-hook.md: new page (id `insight-layer-via-hook`, status active, volatility stable, sources 2) — promoted insight layer at `.llmwiki/insight/` delivered via the core-config prompt-inject hook (Claude `UserPromptSubmit` + Codex `~/.codex/hooks.json`), NOT `.claude/rules/` (Codex can't read it); `.claude/rules/` retired as a wiki-promotion target; `.llmwiki/insight/` is the one justified new physical dir. `> Refines: [[neutral-llmwiki-root]]`, `> Refines: [[curated-conservative]]`, `> See-also: [[shared-source-codex-manifests]]`.
- llm-wiki-design/neutral-llmwiki-root.md: kept active (origin refreshed it via #39); added `> See-also: [[insight-layer-via-hook]]` + a refinement note that promotion of cross-agent rules moved to `.llmwiki/insight/` (the `.claude/rules/`-schema-home claim holds only for Claude auto-load). last_verified 2026-05-31 → 2026-06-01.
- llm-wiki-design/curated-conservative.md: refined the "no new dirs" bullet to carve out `.llmwiki/insight/` as the one justified exception; added `> See-also: [[insight-layer-via-hook]]`; last_verified bumped.
- index.md: added the insight-layer pointer to the intro + the insight-layer-via-hook hook under `## llm-wiki-design`.
- Evidence: `.claude/spec/2026-05-29-llm-wiki-v2.md`, `.llmwiki/insight/index.md`.

## 2026-05-31 — post-merge #41 (post-merge-wiki)

Diff log written before applying the page edits (git-revertible). Merge SHA `05bedcd` — feat: skillify deepwiki + project-init (dual-surface, 17→19 Codex-eligible).

- plugin-ops/shared-source-codex-manifests.md: updated (sources 3 → 4; last_verified stays 2026-05-31). EXCLUDED list trimmed from `{core-config, midjourney, deepwiki, project-init}` to `{core-config, midjourney}` with refreshed rationale (core-config = no Codex hook surface; midjourney = execution-model mismatch). Eligibility count "17 of 21" → "**19 of 21**". Added a paragraph explaining that `deepwiki` and `project-init` left the EXCLUDED set via the 1.41.0 dual-surface conversion (links to new `[[dual-surface-command-skill-pattern]]` page). Added `> See-also: [[dual-surface-command-skill-pattern]]` cross-ref, plus PR #41 to the Sources block.
- plugin-ops/dual-surface-command-skill-pattern.md: new page (id `dual-surface-command-skill-pattern`, status active, volatility stable, sources 4). Documents the layout (`commands/` thin pointer + `skills/<name>/SKILL.md` thin pointer + shared `references/<name>-procedure.md` body), the description-narrowing + runtime hard-guard pattern for destructive plugins (`project-init`'s `find -mindepth 1 -maxdepth 5` block that aborts on any non-`.git`, non-OS-metadata cwd entry), and the `PLUGIN_ROOT` resolver that turns `${CLAUDE_PLUGIN_ROOT}` Claude-only env into a portable 4-step resolution (caller PLUGIN_ROOT → CLAUDE_PLUGIN_ROOT → `~/.codex/plugins/cache/<marketplace>/<plugin>/<version>/` → abort). Includes the GNU `sort -V` BSD fallback discovered during cr-fix iter 2. `> Refines: [[shared-source-codex-manifests]]`, `> Evidence: plugins/project-init/references/new-procedure.md`, `> Evidence: plugins/deepwiki/skills/ask/SKILL.md`.
- index.md: added dual-surface-command-skill-pattern hook under `## plugin-ops`; updated the shared-source line with the 19/21 eligibility number.
- Evidence (in-diff, from `git show --name-only` on merge SHA 05bedcd): `scripts/sync-codex-manifests.mjs` (EXCLUDED set + comment), `.claude-plugin/marketplace.json` (metadata + deepwiki + project-init versions), `plugins/deepwiki/{skills/ask,skills/generate-llmstxt,references}/*` + `commands/{ask,generate-llmstxt}.md` + `CLAUDE.md`, `plugins/project-init/{skills/new,references}/*` + `commands/new.md` + `CLAUDE.md`, `plugins/{deepwiki,project-init}/.codex-plugin/plugin.json` (generated), `.agents/plugins/marketplace.json` (generated catalog), root `CLAUDE.md` / `AGENTS.md` / `README.md`.

## 2026-05-31 — post-merge #39 (post-merge-wiki)

Diff log written before applying the page edits (git-revertible). Merge SHA `158c438` — feat: shared-source Codex bridge (retire codex-bridge plugin).

- plugin-ops/shared-source-codex-manifests.md: new page (id `shared-source-codex-manifests`, status active, volatility stable, sources 3) — Codex 0.135 reads the same `plugins/<name>/` tree Claude does via a thin manifest generator (`scripts/sync-codex-manifests.mjs`, ~140 LOC, zero deps) instead of the retired `codex-bridge` body-transform mirror (1,214-line `sync.mjs`). Documents Codex 0.135 manifest top-level constraint (only `skills` / `hooks` / `mcpServers` / `apps` supported — `commands` and `agents` are Claude-only), the EXCLUDED set rationale (`core-config`, `midjourney`, `deepwiki`, `project-init` → 17 of 21 eligible), and the `--check` drift guard's orphan-manifest detection. `> Supersedes: (codex-bridge plugin, retired)`, `> See-also: [[neutral-llmwiki-root]]`, `> Evidence: scripts/sync-codex-manifests.mjs`, `> Evidence: ~/.codex/skills/.system/plugin-creator/references/plugin-json-spec.md`.
- llm-wiki-design/neutral-llmwiki-root.md: updated (last_verified 2026-05-29 → 2026-05-31, sources 2 → 3) — added "Vindication" subsection: the PR #39 body-transform audit found 275 `.claude/` hits across skill bodies were nearly all *legitimate authorial documentation* (llm-wiki bootstraps `.claude/rules/`, github-dev/cr-fix accepts `CONFIG_FILES="CLAUDE.md AGENTS.md"`, rules-forge explains `CLAUDE.md` semantics). The transforms themselves were corrupting authorial intent. The fix is now structural: the codex-bridge plugin (the transform source) is retired in 1.40.0; both runtimes read the same source. Neutral-root defense remains correct for any future mirror that might re-emerge. Updated status note on the bridge.
- index.md: added shared-source-codex-manifests hook under `## plugin-ops`; MOC `last_verified:` bumped to 2026-05-31.
- Evidence (in-diff, from `git show --name-only`): `scripts/sync-codex-manifests.mjs` (new generator), `plugins/codex-bridge/scripts/sync.mjs` (deleted 1,214-line transform engine), `plugins/codex-bridge/` directory (deleted in full), `.agents/plugins/marketplace.json` (generated catalog), `plugins/*/.codex-plugin/plugin.json` × 17 (generated per-plugin manifests), `AGENTS.md` / `CLAUDE.md` / `README.md` (shared-source docs).

## 2026-05-30 — post-merge #33 (post-merge-wiki)

Diff log written before applying the page edits (git-revertible). Merge SHA `bcc3939` — feat(github-dev): cr-fix v2 — pre-flight detection + autonomous judgment.

- cr-fix-ops/: new domain directory established under `.llmwiki/wiki/` to hold per-plugin cr-fix operational lore (rate-limit semantics, dogfood-derived design rationale). Distinct from `plugin-ops/` (Claude Code runtime cache) and from the cr-fix references files (active design contract).
- cr-fix-ops/cr-rate-limit-progressive-refill.md: new page (id `cr-rate-limit-progressive-refill`, status active, volatility volatile, sources 2) — `cr_desc: "Review skipped: free tier disabled"` does NOT mean the org reverted to Free plan. It signals CR trial/Pro **progressive-refill hourly quota exhaustion** per the [Fair Usage Limits Policy](https://docs.coderabbit.ai/management/plans#fair-usage-limits-policy). Reviews trickle back (not a 60-min reset). Treat `--max-iter` as a CR quota budget (default 5 = Pro 5-rev/hour). Do NOT add a sniff cooldown — use `--push-spacing` instead. Overturns the v2-development intuition. `> Evidence: plugins/github-dev/skills/cr-fix/references/lessons-from-dogfood.md`.
- index.md: added `## cr-fix-ops` domain section with the cr-rate-limit-progressive-refill hook; MOC `last_verified:` bumped to 2026-05-30.
- Evidence (in-diff, from `git show --name-only bcc3939`): `plugins/github-dev/skills/cr-fix/references/lessons-from-dogfood.md` (Lesson 5 = corrected reading after consulting CR docs) + `plugins/github-dev/skills/cr-fix/scripts/sniff-cr-rate-limit.sh` (detection implementation). External source: CR Fair Usage Policy docs.

## 2026-05-30 — post-merge #30 (post-merge-wiki)

Diff log written before applying the page edits (git-revertible). Merge SHA `fc4d994` — feat(code-scout): v2.1 — paper-scout 5th axis + insane-search tier-4 + deep-research boundary + drop deep-scout.

- research-harness/: new domain directory established under `.llmwiki/wiki/` to hold cross-plugin research harness boundary contracts (code-scout, /deep-research, paper-search-tools). Distinct from per-plugin operational lore — this domain captures **inter-harness routing rules** that span plugins.
- research-harness/code-scout-vs-deep-research-boundary.md: new page (id `code-scout-deep-research-boundary`, status active, volatility stable, sources 2) — code-scout owns the code / ML / docs / papers domain; `/deep-research` owns generic topics (politics, market, history, biographies, general policy). The `research-orchestrator` skill explicitly does **NOT** delegate to `/deep-research` even when the query is out-of-domain. The two harnesses tune their fan-out for incompatible domains; routing one through the other would mis-tune. `> Evidence: plugins/code-scout/skills/research-orchestrator/SKILL.md`.
- index.md: added `## research-harness` domain section with the code-scout-vs-deep-research-boundary hook.
- Evidence (in-diff, from `git show --name-only fc4d994`): `plugins/code-scout/skills/research-orchestrator/SKILL.md` (boundary contract authored here, frontmatter line 17-21 + body line 41).

## 2026-05-29 — post-merge #29 (post-merge-wiki)

Diff log written before applying the page edits (git-revertible). Merge SHA `2a166d5` — chore: post-v2 maintenance (docs-forge frontmatter + settings.json local).

- plugin-ops/: new domain directory established under `.llmwiki/wiki/` to hold plugin operational lore (cache, loading, version resolution), distinct from the schema-layer rules in `.claude/rules/plugin-versioning.md`.
- plugin-ops/cache-version-pinning.md: new page (id `cache-version-pinning`, status active, volatility volatile, sources 2) — the plugin cache holds multiple versions per plugin side by side; a running session pins the startup-resolved version, so a newer already-cached version is not served until restart (or via a `local` settings.json source). Folds in the v1->v2 root-resolution manifestation: a v1-pinned llm-wiki skill resolves the legacy `.claude/wiki/` and misses the neutral `.llmwiki/` root. `> See-also: [[neutral-llmwiki-root]]`, `> See-also: [[curated-conservative]]`, `> Evidence: .claude/rules/plugin-versioning.md`.
- index.md: added `## plugin-ops` domain section with the cache-version-pinning hook; MOC `last_verified:` kept 2026-05-29.
- Evidence (runtime observation): `~/.claude/plugins/cache/my-claude-plugins/<plugin>/<version>/` held `llm-wiki/{1.1.1, 1.2.0}` + `github-dev/{1.22.0, 1.23.0}` while this session served v1 (llm-wiki 1.1.1 / github-dev 1.22.0). Complementary schema-layer doc: `.claude/rules/plugin-versioning.md`.

## 2026-05-29 — post-merge #28 (post-merge-wiki)

Diff log written before applying the page edit (git-revertible). Merge SHA `62315ed` — feat(github-dev): post-merge Step 5.8 conditional wiki ingest chain.

- llm-wiki-design/post-merge-trigger.md: new page (id `post-merge-trigger`, status active, volatility stable, sources 2) — post-merge-wiki has two complementary triggers: github-dev:post-merge Step 5.8 (conditional soft-dependency, mirrors the spec-state Step 5.7 pattern, covers GitHub-UI merges) + the wiki_post_commit_hint.sh PostToolUse hook (local CLI merge commits only). `> See-also: [[curated-conservative]]`.
- index.md: added the post-merge-trigger hook under the `## llm-wiki-design` domain section; MOC `last_verified:` kept 2026-05-29.
- Evidence (in-diff, from `git show --name-only`): `plugins/github-dev/commands/post-merge.md` (Step 5.8). Complementary pre-existing source: `plugins/llm-wiki/hooks/wiki_post_commit_hint.sh`.

## 2026-05-29 — ingest v2 design record: 4 pages (ingest-finding)

Diff log written before applying the page edits (git-revertible).

- llm-wiki-design/curated-conservative.md: new page (id `curated-conservative`, status active, volatility stable, sources 2) — hub thesis: harvest the git-auditable kernel of each rohitg00-v2 idea, reject the heavyweight parts; adopted vs rejected lists.
- llm-wiki-design/neutral-llmwiki-root.md: new page (id `neutral-llmwiki-root`, status active, volatility stable, sources 2) — `.llmwiki/` neutral root defeats the codex-bridge `.claude/`->`.codex/` body-transform fork; schema stays at `.claude/rules/`; resolution order. `> Refines: [[curated-conservative]]`.
- llm-wiki-design/volatility-over-decay.md: new page (id `volatility-over-decay`, status active, volatility stable, sources 2) — discrete `volatility:` class + fixed window replaces Ebbinghaus decay; old is not stale. `> Refines: [[curated-conservative]]`, `> See-also: [[provenance-over-confidence]]`.
- llm-wiki-design/provenance-over-confidence.md: new page (id `provenance-over-confidence`, status active, volatility stable, sources 2) — `sources: N` + named `## Sources` replaces float confidence. `> Refines: [[curated-conservative]]`, `> See-also: [[volatility-over-decay]]`.
- index.md: MOC `last_verified:` set to 2026-05-29; added `## llm-wiki-design` domain section with the 4 page hooks.
- Raw evidence cited: `.llmwiki/raw/rohitg00-llm-wiki-v2-gist.md`, `.llmwiki/raw/karpathy-llm-wiki-gist.md`, `.llmwiki/raw/perplexity-llm-wiki-survey-2026-05.md`, plus `.claude/spec/2026-05-29-llm-wiki-v2.md`.

## 2026-05-29 — bootstrap llm-wiki-design domain (bootstrap-wiki)

- llm-wiki-design/: domain directory established under `.llmwiki/wiki/` (2-depth domain/page layout) to hold the v2 design record.

## 2026-06-08 — Codex 1024-char skill-description silent-skip guard (ingest-finding)

- plugin-ops/shared-source-codex-manifests.md: added `## Skill-description length guard` section (Codex 0.135 silently skips skills with `description` > 1024 chars; `--check` now validates length via SKILL_DESC_MAX before drift; 3-layer enforcement: sync-script guard + `.githooks/pre-commit` + `validate-codex.yml` CI). Updated `--check` mode bullet to note length validation. Added PR #46 source; sources 4 -> 5; last_verified 2026-06-08.
- index.md: extended the shared-source-codex-manifests hook to mention the 1024-char description guard.

## 2026-06-08 — codex-image joins EXCLUDED set (Claude->Codex bridge) (ingest-finding)

- plugin-ops/shared-source-codex-manifests.md: EXCLUDED entries 2 -> 3 (added `codex-image` with circular-bridge rationale, distinct from the schema-driven exclusion of core-config/midjourney); eligible count 19 of 21 -> 19 of 22; added PR #49 source; sources 5 -> 6; last_verified 2026-06-08.
- index.md: shared-source hook eligible count 19 of 21 -> 19 of 22.

## 2026-06-08 — graduate Codex 1024-char skill-desc limit to insight (ingest-finding)

- insight/codex-skill-desc-1024.md: new insight entry (tier insight, promoted_from shared-source-codex-manifests, evidence_count 2 — PR #46 research-orchestrator 1214 chars dropped + PR #51 post-merge skill near-miss at 1019/1024 during humanizer->humanize-korean swap). Recurrence across 2 independent PRs met the graduation bar.
- insight/index.md: added codex-skill-desc-1024 hook.
- plugin-ops/shared-source-codex-manifests.md: added PR #51 near-miss evidence to the length-guard section + `> Promoted-to:` backlink; last_verified 2026-06-08.

## 2026-06-08 — distill cr-rate-limit page from PR diary to rule + index lint cleanup (ingest-finding)

- cr-fix-ops/cr-rate-limit-progressive-refill.md: collapsed three per-PR narrative sections (`## Trial dogfood data (PR #33)` / `## Confirming dogfood (PR #50)` / `## Confirming dogfood (PR #54)`) and the `## Code-level fix (PR #56)` section into a single distilled `## The rule` (CR_SKIP_GRACE non-terminal semantics) + one `## Evidence across dogfood runs` (1 bullet per run); inline PR #56 narratives in `## Why this matters` rewritten as rule statements; `## Sources` retains PR #33/#50/#54/#56 + policy provenance; sources 4 -> 5 (PR #50 given its own citation); page dropped 8.0K -> ~5K (resolves lint Level >5KB). last_verified 2026-06-08.
- index.md: removed leftover `(<domain>/<slug>.md)` template-comment artifact (was a phantom orphan-scan hit); added 1 line allowing wiki->insight `[[insight-id]]` cross-layer refs.

## 2026-07-13 — CLAUDE.md symlink -> @AGENTS.md import; symlink-vs-import Windows tradeoff (post-merge #131)

- plugin-ops/agents-md-verbatim-no-import.md: recorded the repo's actual adoption of the inversion (root `CLAUDE.md` is now a one-line `@AGENTS.md` import, previously a symlink) and added `## @import vs symlink — why the import won`: a git symlink (mode 120000) checks out broken on Windows without `core.symlinks` (git writes CLAUDE.md as a text file holding the literal target string `AGENTS.md`), the same invisible-failure shape as the `@CLAUDE.md` pointer trap but platform-gated instead of runtime-gated; the `@AGENTS.md` import resolves identically on every platform. Refined the "Claude never reads AGENTS.md at all" line for post-inversion accuracy. Evidence: PR #131 (`.claude/rules/dual-integration.md`). last_verified 2026-07-10 -> 2026-07-13.

## 2026-07-13 — split review rules into code_review.md; soft-follow + keep-should-block-hard lesson (post-merge #132)

- plugin-ops/agents-md-verbatim-no-import.md: PR #132 corrected the "walks no files" absolute with the documented `code_review.md` soft-follow exception ("Codex *can* follow that guidance" — soft, weaker than the hard `## Review guidelines` injection; sources 5 -> 6, Codex best-practices doc). Post-merge added `## Splitting detail into code_review.md — keep should-block rules hard`: the safe split boundary (all P0/P1 should-block stay hard-injected inline, only Domain-specific/rationale/elaboration goes soft — a "minimal core" that demoted `--slurp`/sed-safety/frontmatter/CI-perms P1s was a live coverage gap while soft-follow is unvalidated) + the verbatim-move relative-ref trap ("이 문서" rebinds from the source file to `code_review.md`). Both surfaced by the Codex reviewer on the split PR. Evidence: code_review.md.

## 2026-07-14 — cr-rate-limit page: doc-confirmed adaptive Fair-Usage table + query command (Issue #121)

- cr-fix-ops/cr-rate-limit-progressive-refill.md: added `## The adaptive Fair-Usage table (Pro+)` with the doc-confirmed per-hour-by-7-day-review-count numbers (0-29 → 10/hr, 30-39 → 8/hr, 90+ → 1/hr one-at-a-time) and the official `@coderabbitai rate limit` / `reviews remaining?` self-serve query, confirming the previously reverse-engineered progressive-refill lore. sources 7 -> 8 (new source 8 cites the specific adaptive numbers + query command, distinct from source 2's refill *semantics* on the same page); last_verified 2026-07-13 -> 2026-07-14. Paired with the new root `.coderabbit.yaml` (Issue #121 — CodeRabbit Pro+ config; root config, not plugin content, so no version bump).

## 2026-07-14 — Wave D/E milestone ingest + staging drain (ingest-finding)

- plugin-ops/shared-source-codex-manifests.md: EXCLUDED shrank to `{codex-image}` (core-config now Codex-eligible as a hooks-only manifest); new `## Native plugin hooks` section — Codex 0.135 *does* support bundled hooks via a source-controlled `hooks/codex-hooks.json` descriptor wired to the manifest's top-level `hooks` (path form), `--check` validates shape + referenced scripts + orphans, and the orphan-hooks check is `--check`-only so write mode regenerates cleanly. last_verified 2026-07-06 -> 2026-07-14, sources 9 -> 10 (PR #124).
- plugin-ops/prompt-inject-korean-persistence.md: added the compaction loss vector — Claude Code drops the injected `additionalContext` on compaction; core-config's `SessionStart` `compact` matcher re-injects the same block (Claude-only single-surface). last_verified 2026-06-24 -> 2026-07-14, sources 2 -> 3 (PR #119).
- plugin-ops/cache-version-pinning.md: re-verified (46d > 30d volatile window) — behavior still current (github-dev 2.8.0 pinned this session while newer caches may exist). last_verified 2026-05-29 -> 2026-07-14, no content change.
- staging drain: consumed 12 Stop-hook markers (Wave A-C subagent captures already ingested via per-PR post-merge + low-signal noise + this session's cb434eaf) — no new pages (dedup: their lore already in the wiki or below the page-creation threshold).

## 2026-07-16 — channel-authority rule on the re-fetch path + 12-marker staging drain (ingest-finding)

- cr-fix-ops/cr-rate-limit-progressive-refill.md: added "Channel authority on the re-fetch path" to `## The rule` (comment-channel RL hits yield to a fresh terminal state; SHA-scoped description-channel evidence keeps its authority — a fresh success whose description is a limit marker falls through to rate_limited, never terminal success); new source 9 (PR #147 + Issue #57, fixture-locked). last_verified 2026-07-14 -> 2026-07-16, sources 8 -> 9.
- staging drain: consumed 13 Stop-hook markers (1 main session bf292551 + main session cb434eaf + 10 workflow-subagent captures from the 2026-07-15 fleet-audit followup investigation + the 2026-07-16 backlog-drain session d4d66fc5's own mid-run self-capture, whose lore is this very entry + the PR verdict comments on #23/#36/#53). Dedup verdict: their distilled lore already lives in the merged spec docs (.claude/spec/2026-07-15-fleet-audit-followups.md + 2026-07-15-wiring-lsp-axis-design.md, PR #151), in per-PR post-merge ingests for the old PR refs (24-68 recon), and in the page edit above — no new pages (page-creation threshold not met by any remaining item).
- insight graduation: considered for the channel-authority rule, declined — it is cr-fix-internal mechanics already fixture-enforced in CI, not a per-prompt behavioral rule agents need injected.
## 2026-07-17 — post-drain re-capture skip (ingest-finding)

- staging drain: consumed 1 marker (pending-d4d66fc5) — the Stop hook re-captured session d4d66fc5 AFTER the 2026-07-16 drain that already folded its self-capture (see the 2026-07-16 entry above). Dedup verdict: duplicate, no pages touched.

## 2026-07-22 — adopt-by-posture-diff insight from mattpocock/skills batch (ingest-finding)

- plugin-ops/skill-authoring-source-grounded-then-audit.md: added §4 "Adopt from an external library: gap-fill / reflect / skip, and diff posture not rules" — grill-me overlapped interview-methodology on ~90% of rules yet its value was the opposite default posture (relentless vs restrained), so it landed as a new mode, not a port. last_verified 2026-06-18 -> 2026-07-22, sources 2 -> 3.
- insight graduation: declined — one-off (single session), stays wiki lore per the recurs-across-sessions criterion.
- routing dedup: the merged skill rules (relentless mode, expand-contract, tautological-test, wiring FAIL verdicts, mcp drift) are skill-internal and already homed in their skill bodies — not re-recorded here.

## 2026-07-27 — diverge-fork as a fourth adopt lane + 35-marker staging drain (ingest-finding)

- plugin-ops/skill-authoring-source-grounded-then-audit.md: §4 gains a fourth lane, **diverge-fork** — when the wanted change is structural (rename, funnel removal, SKILL.md restructure, re-design against your own runtime contract) rather than additive, the honest framing is that a fork takes upstream update latency to zero, not to fast, and the upstream attempt should come first because an external repo cannot run your review loop. last_verified 2026-07-22 -> 2026-07-27, sources 3 -> 4.
- index.md: extended the skill-authoring hook with the diverge-fork lane.
- staging drain: consumed 35 Stop-hook markers — 28 from session 542db770 (1 parent + 27 workflow-subagent captures of the mattpocock/skills fan-out, whose lore is the 2026-07-22 entry above; the parent's other topic, the /wiring WARN->FAIL promotion, landed as PR #154 and was dedup'd as skill-internal in that same entry), 1 from d4d66fc5 (a THIRD re-capture of the backlog-drain session already folded on 2026-07-16 and skipped on 2026-07-17), 3 from 7b593104 (davidondrej/skills council + its codex/agy council seats — the decisions are the durable spec `.claude/spec/2026-07-22-adopt-from-davidondrej-skills.md`, the method lore is already the 2026-07-22 entry), 1 from 8b96f451 (an Agent-Teams doc-consistency PR into the upstream `fivetaku/kkirikkiri` — its one transferable fact, that an external repo cannot run our cr-fix loop, is folded into the §4 diverge-fork paragraph rather than given its own page), 1 from caea2bff (the gptaku fork interview — source of the §4 edit above), 1 from 266b8a66 (a YouTube-derived principles review that concluded "nothing to add" and ended on an unanswered offer to write one insight note — undecided, so it does not graduate).
- insight graduation: declined — diverge-fork has one occurrence and the fork itself is decided-but-unexecuted, failing both the recurs-across-sessions and the stabilized criteria.
- not ingested, surfaced instead: PR #164's body linked its issues as `소스 이슈: #162, #163` (a plain mention, inert to GitHub) instead of a closing keyword, so both issues stayed open through a post-merge run that recorded `conclusion: success`. That is a skill gap to file against github-dev, not lore for a page.
