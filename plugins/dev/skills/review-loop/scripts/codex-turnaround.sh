# Sourced, never run: the Codex turnaround ADR 0002 measured (68-726 s, median 224 s)
# and the wait budget built on it, in one place so the wait rules (next-check.sh) and
# the budgets (codex-head-verdict.sh, head-verdicts.sh, poll-codex-grace.sh,
# pre-flight.sh) cannot drift apart.
CODEX_FASTEST=68
CODEX_SLOWEST=726
# Default Codex wait budget (CODEX_PREFLIGHT_TIMEOUT, poll-codex-grace CAP): above the
# slowest turnaround seen, so a late but ordinary review is waited for, not dropped
# (ADR 0006).
CODEX_BUDGET_DEFAULT=900
