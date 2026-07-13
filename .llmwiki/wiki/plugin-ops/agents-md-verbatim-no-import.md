---
id: agents-md-verbatim-no-import
aliases: [agents-md-pointer-trap, codex-no-at-import, claude-md-imports-agents-md]
last_verified: 2026-07-13
status: active
volatility: stable
sources: 6
---

# AGENTS.md is loaded verbatim — `@import` is Claude-only, and one-directional

The tempting cleanup ("stop hand-maintaining the `AGENTS.md` mirror; just point it at `CLAUDE.md`") fails silently on the two runtimes that read `AGENTS.md`. This page holds the evidence; the operational rule lives in `.claude/rules/dual-integration.md` and its `AGENTS.md` mirror.

## Mechanism

Codex reads `AGENTS.md` as bytes. `codex-rs/core/src/agents_md.rs` does `String::from_utf8_lossy(&data).to_string()`, discovers the files from project root down to CWD, concatenates them with `\n\n--- project-doc ---\n\n` separators, and truncates at `project_doc_max_bytes`. **No `@file`, `@path`, or `@import` directive is ever expanded.** Nesting is directory-scoped (nearest file wins), never an include graph.

Hermes has no documented import mechanism either. Zero evidence of support — treated as unsupported (`unverified` that it is impossible; fail-safe verdict).

Two operational corollaries of that same reader. Codex's configuration root is `${CODEX_HOME:-~/.codex}`, not a hardcoded `~/.codex` (`codex --help`: "Layer `$CODEX_HOME/<name>.config.toml` on top of the base user config"), so a tool that reads the cap from `$HOME/.codex/config.toml` reports no Codex config at all on a machine that sets `CODEX_HOME`. And because the files are concatenated root-down and cut at `project_doc_max_bytes`, the bytes lost to the cap are the **tail** of the deepest `AGENTS.md` — which in a repo that follows the project-init template is `## Review guidelines`, precisely the section the cloud reviewer loads. Exceeding the budget deletes the reviewer's instructions and reports nothing.

Claude Code never reads `AGENTS.md` as a discovery target. It reads `CLAUDE.md`, and `@path/to/import` — a **Claude-only** feature that lives on `CLAUDE.md` (recursive, max depth four hops) — is the only way `AGENTS.md` content reaches Claude when the two are wired together.

## The consequence

An `AGENTS.md` reduced to `@CLAUDE.md` (or `See @CLAUDE.md`) leaves Codex and Hermes with a ~12-byte file of literal Markdown. Every rule, review guideline, and integration note is gone from their context. **No error, no warning** — the byte-limit/concat path succeeds on a tiny file, so the failure is invisible from the Claude side, which never consulted `AGENTS.md` in the first place.

A *prose* redirect ("read `CLAUDE.md` before starting") half-works: Codex CLI is an agent with file tools and can comply, at the cost of a tool call per session and a soft, model-dependent guarantee. It does **not** reach the Codex GitHub cloud reviewer, which loads the `## Review guidelines` section straight into its system prompt rather than following such a prose pointer to other files — a redirect there returns the reviewer to generic lint nits on every PR.

One documented exception narrows the "walks no files" claim: per the Codex best-practices doc, *"If you and your team have a `code_review.md` file and reference it from `AGENTS.md`, Codex can follow that guidance during review as well."* So a **specifically-referenced `code_review.md`** is a file the reviewer *can* follow — but only as a **soft guarantee** ("can follow"), categorically weaker than the hard system-prompt injection of the `## Review guidelines` section itself, and distinct from a vague "read `CLAUDE.md`" prose redirect (which is not a referenced review file and does not work). This repo uses exactly that pattern: `AGENTS.md` keeps a hard-injected P0/P1 minimal core and points at a root `code_review.md` for the full detail.

## The direction that works

Official Claude Code memory docs state the inverse pattern:

> Claude Code reads `CLAUDE.md`, not `AGENTS.md`. If your repository already uses `AGENTS.md` … create a `CLAUDE.md` that imports it.

So `AGENTS.md` becomes the SSOT and `CLAUDE.md` carries `@AGENTS.md`. Codex and Hermes read the full file natively; Claude expands the import. The mirror disappears in the one direction that is loader-valid on all three runtimes.

This repo made that call: root `CLAUDE.md` is a one-line `@AGENTS.md` import. `AGENTS.md` is a curated *superset* (Codex cloud-reviewer guidelines and Codex/Hermes integration sections that `CLAUDE.md` lacks, minus Claude-only content like Plan Mode), so a naive `cat CLAUDE.md .claude/rules/*.md` generator cannot produce it, and inverting means Claude carries reviewer guidelines it never uses — accepted as the cost of a single SSOT.

## `@import` vs symlink — why the import won

A root `CLAUDE.md` **symlink** to `AGENTS.md` reaches the same single-file SSOT and is marginally stronger — one physical inode cannot drift from itself. It was the first form tried (the `agents-md-single-file` branch, revived from a closed earlier attempt). But a git symlink (mode `120000`) checks out **broken on Windows** without `core.symlinks`: git materializes `CLAUDE.md` as a regular text file whose contents are the literal target string `AGENTS.md`, so Claude Code on a Windows clone reads nine bytes of guidance and silently loses everything — the same invisible-failure shape as the `@CLAUDE.md` pointer trap above, just platform-gated instead of runtime-gated. The `@AGENTS.md` import is a plain text file that resolves identically on every platform, so it is preferred over the symlink for a repo cloned on Windows. Drift stays impossible in practice: the one-line pointer has no content to drift from.

## Why the older phrasing under-stated it

The rule used to read "Codex cannot `@import` `.claude/rules/`", which implies a *reach* limitation into a Claude-only directory. The real constraint is categorical: Codex has no `@import` at all. The weaker phrasing is what makes the pointer cleanup look plausible.

> Refines: [[shared-source-codex-manifests]]
> See-also: [[insight-layer-via-hook]]
> See-also: [[hermes-plugin-adapter]]
> Promoted-to: [[agents-md-no-import]]
> Evidence: .claude/rules/dual-integration.md
> Evidence: plugins/project-init/references/codex-review-discovery.md
> See-also: [[detector-cannot-look-vs-nothing-wrong]]

## Sources
1. **`codex-rs/core/src/agents_md.rs`** (github.com/openai/codex, main) — the verbatim reader: byte read → `from_utf8_lossy` → concat with `--- project-doc ---`. No directive expansion anywhere in the path.
2. **Locally installed `codex-cli` 0.142.3** — the embedded model system prompt describes `AGENTS.md` purely as directory-scoped text ("The scope of an AGENTS.md file is the entire directory tree rooted at the folder that contains it… More-deeply-nested AGENTS.md files take precedence"). No import syntax. Newer than the 0.135 this repo targets, so the claim is not stale.
3. **agents.md spec** — "AGENTS.md is just standard Markdown. … the agent simply parses the text you provide." Nesting is directory-only.
4. **Claude Code memory docs** (`code.claude.com/docs/en/memory`) — Claude reads `CLAUDE.md`, not `AGENTS.md`; `@path` imports are a `CLAUDE.md` feature, recursive to four hops; the documented interop pattern is a `CLAUDE.md` that imports `AGENTS.md`.

5. **OpenAI Codex best-practices doc** (`developers.openai.com/codex/learn/best-practices`, served at `learn.chatgpt.com/guides/best-practices`, verified 2026-07-13) — "If you and your team have a `code_review.md` file and reference it from `AGENTS.md`, Codex can follow that guidance during review as well." The "can follow" wording is what makes this a soft guarantee. The companion GitHub review page (`developers.openai.com/codex/code-review`) confirms the cloud reviewer surfaces only P0/P1 comments.
6. **`codex --help` / `codex doctor` on codex-cli 0.144.1** — `$CODEX_HOME` is the documented config root. The shipped binary also carries the literal `.codex/config.toml` plus `"Error parsing project config file"` / `"Failed to read project config file"`, so a project-level config surface exists; whether `project_doc_max_bytes` is honored there, and under what trust gating (`trust_level` appears in the binary), is **unverified** — `codex doctor` reports only the user-level path.
