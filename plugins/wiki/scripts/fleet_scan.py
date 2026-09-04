"""Fleet-wide mem0 scan: per-app noise ratio, type mix, fragmentation.

Read-only. Junk heuristic: basename-looking name (no owner- prefix pattern
match to a sibling), noise >= 90%, zero manually-typed memories.
Fragmentation: app A whose name is a suffix of app B (owner-prefixed pair).
"""

import sys
from collections import Counter

from _api import entity_filters, list_apps, list_memories

MANUAL_TYPES = {
    "decision",
    "feedback",
    "task_learning",
    "convention",
    "anti_pattern",
    "user_preference",
    "project_profile",
    "project",
}
NOISE_TYPES = {"session_summary", "compact_summary", "session_state"}


def scan_app(app):
    mems = list_memories(entity_filters(app, "*"))
    types = Counter((m.get("metadata") or {}).get("type") or "(none)" for m in mems)
    users = Counter(m.get("user_id") for m in mems)
    noise = sum(n for t, n in types.items() if t in NOISE_TYPES)
    manual = sum(n for t, n in types.items() if t in MANUAL_TYPES)
    return {
        "app": app,
        "total": len(mems),
        "noise": noise,
        "manual": manual,
        "users": users,
        "types": types,
    }


def fragmentation_pairs(apps):
    pairs = []
    for a in apps:
        for b in apps:
            if a != b and b.endswith("-" + a):
                pairs.append((a, b))
    return pairs


def main():
    apps = list_apps()
    rows = [scan_app(a) for a in apps]
    rows.sort(key=lambda r: -r["total"])
    frag = fragmentation_pairs(apps)
    frag_names = {a for pair in frag for a in pair}
    print(f"{'total':>6} {'noise%':>6}  app  [flags]  [user split]")
    grand = grand_noise = 0
    for r in rows:
        if not r["total"]:
            continue
        grand += r["total"]
        grand_noise += r["noise"]
        pct = 100 * r["noise"] // r["total"]
        flags = []
        if pct >= 90 and r["manual"] == 0 and "-" not in r["app"]:
            flags.append("JUNK?")
        if r["app"] in frag_names:
            flags.append("FRAG")
        u = ",".join(f"{k}:{v}" for k, v in r["users"].most_common())
        print(f"{r['total']:>6} {pct:>5}%  {r['app']}  [{' '.join(flags)}]  [{u}]")
    print(
        f"\nGRAND total={grand} noise={grand_noise} "
        f"({100 * grand_noise // max(grand, 1)}%) across "
        f"{sum(1 for r in rows if r['total'])} active apps"
    )
    if frag:
        print("\nFragmentation pairs (report-only; merge is out of scope v1):")
        for a, b in frag:
            print(f"  {a}  <->  {b}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
