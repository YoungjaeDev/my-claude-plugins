## Post-generation Hints

After any mode completes, append these hints to the summary based on
detected state. Each hint is informational only: no auto-modification.

| Detected state | Hint shown to user |
|---|---|
| `AGENTS.md` exists | "Detected `AGENTS.md` ({LINES} lines). Consider adding `@AGENTS.md` as the first line of CLAUDE.md so Claude reads both without duplication. See `assets/references/claude-code-memory.md` AGENTS.md section." |
| No `.gitignore` mentions `CLAUDE.local.md` | "Tip: 개인 프로젝트별 선호도는 `CLAUDE.local.md` 에 두고 `.gitignore` 에 추가하면 버전 제어 영향 없이 사용 가능." |
| Root file is `./.claude/CLAUDE.md` (not `./CLAUDE.md`) | "Note: `./.claude/CLAUDE.md` 와 `./CLAUDE.md` 둘 다 유효 — 둘 다 있으면 둘 다 로드되니 하나만 유지 권장." |
| Generated 3+ rules files | "참고: 자동 메모리는 `~/.claude/projects/<proj>/memory/` 에서 Claude 가 직접 관리. write-rules 가 만든 `.claude/rules/` 와 무관." |
| `/compact` 워크플로우가 잦다고 사용자가 언급 | "주의: 하위 디렉토리의 CLAUDE.md 는 `/compact` 후 자동 재주입 안 됨. 핵심 지침은 root CLAUDE.md 에." |

## SPLIT Section Classification Heuristics

Used in Mode: SPLIT step 4, to map a parsed section header to a
target `.claude/rules/<name>.md` file.

- Headers containing "Architecture", "Design", "Structure" → `architecture.md`
- Headers containing "Framework", "Next.js", "React", "Vue" → `framework.md`
- Headers containing "Stack", "Tool", "Database", "Style" → `tech-stack.md`
- Headers containing "Test", "QA", "Verification" → `testing.md`
- Headers containing "Deploy", "Release", "CI" → `deployment.md`
- Headers containing "Security", "Auth", "Permission" → `security.md`
- Headers with dense bash command blocks ≥30 lines → `<purpose>.md`
  (e.g., `experiments.md`, `vlm-serving.md`)

## Assets Reference

Index of the files each mode's execution steps already cite. The
single source of truth for *when* to Read each file is the numbered
step list inside each Mode Execution section; this table is just
a quick lookup.

| Mode | Always Read | Read if `contentSignals` matches |
|---|---|---|
| NEW (interview) | `templates/root-claude-md.md`, `templates/rule-file.md`, `templates/rule-categories.md` | `examples/nextjs-clean-arch.md` (clean-arch), `examples/nextjs-framework.md` (nextjs-framework), `examples/tech-stack-supabase.md` (supabase), `examples/saas-service-spec.md` (service-spec) |
| TIGHTEN | `templates/root-claude-md.md` | same example-tag mapping as above |
| SPLIT | `templates/rule-categories.md`, `templates/rule-file.md` | same example-tag mapping as above |
| REORGANIZE | `templates/rule-file.md`, `templates/rule-categories.md` | same example-tag mapping as above |
| Any (when user asks "why this structure") | `references/claude-code-memory.md` | - |

`contentSignals` are emitted by the Detection Logic bash scan
(`grep -liE`). Tags: `clean-arch`, `nextjs-framework`, `supabase`,
`service-spec`. Empty list = no example Read.
