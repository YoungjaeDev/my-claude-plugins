# CodeRabbit notices that say it did NOT review: rate limits, quota refills, skips.
# Sourced (`. cr-notices.sh`) by cr-head-verdict.sh, engagement-gate.sh,
# sniff-cr-rate-limit.sh and cr-commit-state.sh, so a new phrasing reaches every
# reader. Each is a jq regex, matched with test(_; "i").

# Refill phrasings carry no rate-limit noun of their own; they appear alone in
# Fair-Usage comments.
CR_REFILL_RE='More reviews will be available in|Next (included )?review available in'

# A comment or review body that is a rate-limit or skip notice (sniff-cr-rate-limit.sh).
CR_RATE_LIMIT_RE="auto-generated comment: rate limited by coderabbit\\.ai|$CR_REFILL_RE|Review limit reached|Review skipped: free tier disabled|Review skipped: [0-9]+ files exceed the limit"

# The same plus "Review rate limited", the passing check's title that CodeRabbit also
# posts as a review body: neither engagement nor a HEAD verdict.
CR_NOTICE_RE="$CR_RATE_LIMIT_RE|Review rate limited"

# A success status or check-run description that is a rate limit, not a review
# (cr-commit-state.sh). The transient "Review skipped: free tier disabled" is
# deliberately left out: its CR_SKIP_GRACE hold lives in the callers.
CR_STATUS_RL_RE="rate limited|Review limit reached|$CR_REFILL_RE"
