"""Single-app mem0 audit: duplicates, exclusions compliance, age buckets.

Read-only. Deterministic heuristics only (Jaccard + regex) — no LLM cost.
Port of the session-proven ~/.mem0/mem0_audit.py (2026-07-07), APP_ID
constant replaced by --app / cwd scope resolution.
ponytail: pairwise O(n^2) dup scan within type groups, fine at ~1k memories.
"""

import argparse
import json
import os
import re
import sys
from collections import Counter, defaultdict
from datetime import date, datetime

from _api import entity_filters, list_memories, resolve_app_id

STOP = set(
    "a an the and or of to in on for with is are was were be been this that "
    "it its as by from at not no via into during when what which who how "
    "user assistant session user's".split()
)
WORD = re.compile(r"[a-zA-Z가-힣][a-zA-Z0-9_.가-힣-]+")

# Exclusions-compliance heuristics (mirror the GUI custom-instructions Exclusions)
E_FILELIST = re.compile(r"files touched|listed the files|file list", re.I)
E_NARRATION = re.compile(
    r"\b(this session|in the session|during (this|the) session)\b", re.I
)
E_TRANSIENT = re.compile(
    r"\b([0-9a-f]{7,40}|PR ?#\d+|issue ?#\d+|branch [\w/.-]+|run.id|task.id)\b", re.I
)


def toks(text):
    return {w.lower() for w in WORD.findall(text)} - STOP


def jaccard(a, b):
    return len(a & b) / len(a | b) if a | b else 0.0


def age_days(iso, today):
    try:
        d = datetime.fromisoformat(iso.replace("Z", "+00:00")).date()
        return (today - d).days
    except (ValueError, AttributeError):
        return None


def main():
    ap = argparse.ArgumentParser(description="Single-app mem0 audit (read-only)")
    ap.add_argument("--app", help="app_id (default: resolve from cwd)")
    ap.add_argument("--user", default=os.environ.get("MEM0_USER_ID", "*"))
    ap.add_argument("--dump", help="write full memory dump JSON to this path")
    args = ap.parse_args()

    app = args.app
    if not app:
        app, source = resolve_app_id()
        if source == "basename":
            print(
                f"WARNING: unmapped directory resolved to '{app}' (basename "
                f"fallback) — this is how junk app_ids are born. "
                f"Run from a project root or pass --app.",
                file=sys.stderr,
            )

    mems = list_memories(entity_filters(app, args.user))
    if args.dump:
        with open(args.dump, "w") as f:
            json.dump(mems, f, ensure_ascii=False)

    today = date.today()
    by_type = Counter()
    by_cat = Counter()
    by_source = Counter()
    ages = Counter()
    untagged = []
    stale = []
    excl_filelist, excl_narration, excl_transient_only = [], [], []
    groups = defaultdict(list)
    oldest, newest = None, None

    for m in mems:
        md = m.get("metadata") or {}
        t = md.get("type") or "(none)"
        by_type[t] += 1
        cats = m.get("categories") or []
        c0 = cats[0] if cats else "(none)"
        if c0 == "auto_capture":
            c0 = "uncategorized"
        by_cat[c0] += 1
        by_source[md.get("source") or "(none)"] += 1
        text = m.get("memory") or ""
        a = age_days(m.get("created_at", ""), today)
        if a is not None:
            oldest = max(oldest, a) if oldest is not None else a
            newest = min(newest, a) if newest is not None else a
            if a < 7:
                ages["<7d"] += 1
            elif a < 30:
                ages["7-30d"] += 1
            elif a < 90:
                ages["30-90d"] += 1
            else:
                ages[">90d"] += 1
        if not md.get("type"):
            untagged.append(m["id"])
        if t in ("session_state", "compact_summary") and a is not None and a > 90:
            stale.append((m["id"], t, a))
        elif (
            a is not None
            and a > 180
            and m.get("updated_at", "")[:10] == m.get("created_at", "")[:10]
        ):
            stale.append((m["id"], t, a))
        tk = toks(text)
        if E_FILELIST.search(text):
            excl_filelist.append((m["id"], t, text[:90]))
        elif E_NARRATION.search(text):
            excl_narration.append((m["id"], t, text[:90]))
        if E_TRANSIENT.search(text) and len(tk) <= 12:
            excl_transient_only.append((m["id"], t, text[:90]))
        groups[t].append((m["id"], tk, text))

    dups = []
    for t, items in groups.items():
        n = len(items)
        for i in range(n):
            for j in range(i + 1, n):
                s = jaccard(items[i][1], items[j][1])
                if s > 0.6:
                    dups.append(
                        (
                            round(s, 2),
                            t,
                            items[i][0],
                            items[j][0],
                            items[i][2][:70],
                            items[j][2][:70],
                        )
                    )
    dups.sort(reverse=True)

    rep = {
        "app": app,
        "total": len(mems),
        "by_type": by_type.most_common(),
        "by_category": by_cat.most_common(),
        "by_source": by_source.most_common(),
        "age_buckets": dict(ages),
        "oldest_days": oldest,
        "newest_days": newest,
        "duplicate_pairs": len(dups),
        "dup_top20": dups[:20],
        "untagged": len(untagged),
        "untagged_ids": untagged[:10],
        "stale": len(stale),
        "stale_sample": stale[:10],
        "excl_violation_filelist": len(excl_filelist),
        "excl_filelist_sample": excl_filelist[:8],
        "excl_violation_narration": len(excl_narration),
        "excl_narration_sample": excl_narration[:8],
        "excl_transient_only": len(excl_transient_only),
        "excl_transient_sample": excl_transient_only[:8],
    }
    json.dump(rep, sys.stdout, ensure_ascii=False, indent=1, default=str)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
