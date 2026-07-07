"""Backup-then-delete mem0 cleanup. --dry-run is the default; --execute deletes.

Safety contract (spec section 6): mandatory full-app JSON backup to
~/.mem0/backups/<app>-<timestamp>.json before any DELETE; 5xx retry in
_api.req_json; DELETE 404 treated as already-deleted (idempotent).
Restore: re-add backup rows via add_memory with infer=False.
"""

import argparse
import json
import os
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime

from _api import BASE, list_memories, req_json, resolve_app_id


def select_targets(mems, mem_type=None, all_types=False):
    if all_types:
        return [m["id"] for m in mems]
    if not mem_type:
        return []
    return [m["id"] for m in mems if (m.get("metadata") or {}).get("type") == mem_type]


def backup(app, mems):
    bdir = os.path.expanduser("~/.mem0/backups")
    os.makedirs(bdir, exist_ok=True)
    # app is user-controlled (--app / env / project_map) — sanitize the filename
    # component so absolute paths or separators cannot escape the backup dir,
    # and timestamp per run so a same-day second cleanup never overwrites the
    # only recovery copy of the first.
    safe = re.sub(r"[^A-Za-z0-9._-]", "_", app) or "app"
    stamp = datetime.now().strftime("%Y-%m-%dT%H%M%S")
    path = os.path.join(bdir, f"{safe}-{stamp}.json")
    with open(path, "w") as f:
        json.dump(mems, f, ensure_ascii=False)
    return path


def delete_one(mid):
    try:
        req_json(f"{BASE}/v1/memories/{mid}/", method="DELETE")
        return mid, "ok"
    except Exception as e:  # 부분 실패 리포트용 — 전체 중단 금지
        return mid, f"ERR:{e}"


def main():
    ap = argparse.ArgumentParser(description="mem0 backup-then-delete cleanup")
    ap.add_argument("--app", help="app_id (default: resolve from cwd)")
    ap.add_argument(
        "--user",
        default=None,
        help="user_id filter (default: MEM0_USER_ID env; "
        "--all defaults to '*' so whole-app teardown "
        "never silently inherits one user)",
    )
    ap.add_argument(
        "--type",
        dest="mem_type",
        help="delete only this metadata.type (e.g. session_summary)",
    )
    ap.add_argument(
        "--all", action="store_true", help="delete the whole app (junk app_id teardown)"
    )
    ap.add_argument(
        "--execute", action="store_true", help="actually delete; default is dry-run"
    )
    args = ap.parse_args()
    if not args.mem_type and not args.all:
        sys.exit("pass --type <metadata.type> or --all")
    if args.user:
        user = args.user
    elif args.all:
        user = "*"
    else:
        user = os.environ.get("MEM0_USER_ID", "*")
    app = args.app
    if not app:
        app, source = resolve_app_id()
        if source == "basename":
            sys.exit(
                f"refusing to run against basename-fallback scope "
                f"'{app}' — run from a project root or pass --app."
            )
    mems = list_memories({"AND": [{"user_id": user}, {"app_id": app}]})
    targets = select_targets(mems, mem_type=args.mem_type, all_types=args.all)
    print(
        f"app={app} user={user} total={len(mems)} targets={len(targets)} "
        f"selector={'ALL' if args.all else args.mem_type}"
    )
    if not args.execute:
        target_set = set(targets[:5])
        for m in mems:
            if m["id"] in target_set:
                print(f"  sample: [{m['id'][:8]}] {(m.get('memory') or '')[:80]}")
        print("dry-run (pass --execute to delete)")
        return 0
    if not targets:
        print("nothing to delete")
        return 0
    path = backup(app, mems)
    print(f"backup: {path}")
    with ThreadPoolExecutor(max_workers=8) as ex:
        results = list(ex.map(delete_one, targets))
    ok = sum(1 for _, s in results if s == "ok")
    errs = [(m, s) for m, s in results if s != "ok"]
    print(f"deleted ok={ok} failed={len(errs)}")
    for m, s in errs[:10]:
        print(f"  FAIL {m} {s}")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
