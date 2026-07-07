---
id: mem0-rest-list-contract
aliases: [mem0-v2-list-quirks, mem0-entity-wildcard, show-expired, mem0-api-contract]
last_verified: 2026-07-07
status: active
volatility: volatile
sources: 2
---

# mem0 v2 list API: live contract vs docs (3 verified quirks)

Same class as the Tally schema-vs-live page: the vendor's REST contract has
behaviors the obvious reading of the docs does not predict. All three were
found by review on the mem0-ops plugin and live-verified against
`POST /v2/memories/` on 2026-07-07.

## The rules

1. **Entity wildcards match non-null only.** `{"user_id": "*"}` matches rows
   where `user_id` is set — it does NOT mean "any value including null".
   Even an OR of all three entity wildcards (user/agent/run) misses rows
   written with `app_id` alone (absent entity fields are null per the
   entity-scoped-memory docs). For whole-app scope, a bare
   `{"AND": [{"app_id": X}]}` filter is accepted, simpler, and complete.
2. **Expired memories are hidden by default.** The list API silently omits
   rows past `expiration_date` unless the body carries `show_expired: true`.
   Any deletion/backup/audit SSOT must set it, or teardown reports complete
   while expired rows silently remain.
3. **`HTTPResponse.length` is None on chunked responses.** A guard like
   `if r.status == 204 or not r.length: return {}` silently drops a real
   JSON body whenever the server omits Content-Length. Read the body and
   test emptiness (`raw = r.read(); if not raw: ...`) instead.

## Why this matters

mem0-ops' cleanup is a destructive tool whose backup is the only recovery
path — each of these quirks made "teardown complete" a false report while
data survived (1, 2) or made the helper drop server responses (3). Any
future mem0 REST consumer (not just mem0-ops) inherits these.

> See-also: [[mem0-hook-latency-budget]]
> See-also: [[tally-api-schema-vs-live]]

## Sources

- PR #97 review rounds 1/3 (CR Major `_api.py:44`; Codex P2 `_api.py:71`, `_api.py:82`) — findings live-verified with direct `POST /v2/memories/` probes before applying (bare app_id count == OR-filter count; `show_expired` accepted; docs link: mem0 entity-scoped-memory + get-memories API reference).
- `plugins/mem0-ops/scripts/_api.py` (`entity_filters()`, `list_memories()`, `req_json()`) — the shipped encoding of all three rules, with in-code rationale.
