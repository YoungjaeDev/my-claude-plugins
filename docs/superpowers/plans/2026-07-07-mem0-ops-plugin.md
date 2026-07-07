# mem0-ops Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 플릿 레벨 mem0 진단·정리 플러그인 — fleet-scan / doctor / cleanup 스킬 3종 + stdlib 스크립트.

**Architecture:** 결정론 작업(스캔·감사·삭제·설정 점검)은 stdlib-only Python 스크립트 4종이 전담하고, 스킬(LLM) 레이어는 실행 오케스트레이션 + 회색지대 판단 + AskUserQuestion 게이트만 담당. 모든 API 접근은 REST v1/v2 직결(`_api.py` 공유 헬퍼), upstream mem0 플러그인 의존 없음.

**Tech Stack:** Python 3 stdlib (urllib/json), mem0 Platform REST API, Claude Code plugin manifest.

**Spec:** `docs/superpowers/specs/2026-07-07-mem0-ops-plugin-design.md`

## Global Constraints

- 스크립트는 stdlib만 — 서드파티 import 금지 (`mem0ai` SDK 포함).
- upstream `mem0@mem0-plugins` 스크립트/venv 참조 금지. REST 엔드포인트: `POST /v2/memories/`(list), `DELETE /v1/memories/{id}/`, `GET /v1/entities/`.
- `MEM0_API_KEY` 부재 시 graceful stop (exit 1 + 안내 메시지, traceback 금지).
- cleanup은 `--dry-run` 기본, 삭제 전 JSON 백업 필수(`~/.mem0/backups/`).
- 스킬 `description` frontmatter < 1024자, colon-space(`: `) 포함 시 큰따옴표 쿼팅.
- 코드·문서에 이모지 금지, AI attribution 금지.
- 검증된 원형: `~/.mem0/mem0_audit.py`, `~/.mem0/mem0_cleanup.py` (2026-07-07 세션, 793건 삭제 실패 0).

## File Structure

```
plugins/mem0-ops/
├── .claude-plugin/plugin.json     # Task 6
├── CLAUDE.md                      # Task 6
├── scripts/
│   ├── _api.py                    # Task 1 — REST 헬퍼 + 스코프 해석 (공유)
│   ├── fleet_scan.py              # Task 2
│   ├── audit.py                   # Task 3 — mem0_audit.py 이식
│   ├── cleanup.py                 # Task 4 — mem0_cleanup.py 이식 + 일반화
│   └── doctor.py                  # Task 5
├── tests/
│   └── test_cleanup_targets.py    # Task 4 — 순수 로직 unit test
└── skills/
    ├── fleet-scan/SKILL.md        # Task 6
    ├── doctor/SKILL.md            # Task 6
    └── cleanup/SKILL.md           # Task 6
```

루트 문서 fan-out (Task 6): `.claude-plugin/marketplace.json`, `CLAUDE.md`, `README.md`, `AGENTS.md`, `.claude/settings.json`.

---

### Task 1: 스캐폴드 + `_api.py` 공유 헬퍼

**Files:**
- Create: `plugins/mem0-ops/scripts/_api.py`

**Interfaces:**
- Produces: `api_key() -> str`, `req_json(url, body=None, method=None, retries=3) -> dict`, `list_memories(filters: dict) -> list[dict]`, `list_apps() -> list[str]`, `resolve_app_id() -> tuple[str, str]` (app_id, source∈{env,map,git,basename})

- [ ] **Step 1: `_api.py` 작성**

```python
"""Shared REST helpers for mem0-ops scripts. stdlib only.

All mem0-ops scripts talk to the mem0 Platform REST API directly
(v1 entities/delete, v2 list). No dependency on the upstream mem0
plugin's scripts or venv.
"""
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

BASE = "https://api.mem0.ai"


def api_key() -> str:
    k = os.environ.get("MEM0_API_KEY")
    if not k:
        sys.exit("MEM0_API_KEY not set. mem0-ops requires a mem0 Platform API key.")
    return k


def req_json(url, body=None, method=None, retries=3):
    """JSON request with 5xx retry/backoff. DELETE 404 is idempotent-ok."""
    last = None
    for i in range(retries):
        try:
            data = json.dumps(body).encode() if body is not None else None
            req = urllib.request.Request(url, data=data, method=method, headers={
                "Authorization": f"Token {api_key()}",
                "Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=30) as r:
                if r.status == 204 or not r.length:
                    return {}
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 404 and method == "DELETE":
                return {}
            if e.code in (500, 502, 503, 504) and i < retries - 1:
                time.sleep(2 ** i)
                last = e
                continue
            raise
    raise last


def list_memories(filters):
    """Page through POST /v2/memories/ (list-by-filter). Returns all rows."""
    mems, page = [], 1
    while True:
        d = req_json(f"{BASE}/v2/memories/?page={page}&page_size=100",
                     {"filters": filters})
        res = d.get("results", []) if isinstance(d, dict) else d
        mems.extend(res)
        if not isinstance(d, dict) or not d.get("next") or not res:
            break
        page += 1
    return mems


def list_apps():
    """All app entity names via GET /v1/entities/."""
    apps, page = [], 1
    while True:
        d = req_json(f"{BASE}/v1/entities/?page={page}")
        apps += [e["name"] for e in d["results"] if e["type"] == "app"]
        if not d.get("next"):
            break
        page += 1
    return apps


def resolve_app_id():
    """Mirror the upstream mem0 plugin's cwd->app_id resolution chain.

    Order: MEM0_PROJECT_ID env -> ~/.mem0/project_map.json[$PWD]
    -> git remote slug (owner-repo) -> basename fallback.
    Returns (app_id, source). source == "basename" callers should warn:
    unmapped dirs are exactly how junk app_ids get created.
    """
    env = os.environ.get("MEM0_PROJECT_ID")
    if env:
        return env, "env"
    cwd = os.getcwd()
    pmap = os.path.expanduser("~/.mem0/project_map.json")
    if os.path.isfile(pmap):
        try:
            mapped = json.load(open(pmap)).get(cwd)
            if mapped:
                return mapped, "map"
        except (json.JSONDecodeError, OSError):
            pass
    try:
        url = subprocess.run(["git", "remote", "get-url", "origin"],
                             capture_output=True, text=True, timeout=5).stdout.strip()
    except (subprocess.SubprocessError, OSError):
        url = ""
    if url:
        slug = url.removesuffix(".git")
        for p in ("https://", "http://", "ssh://", "git://", "git@"):
            slug = slug.removeprefix(p)
        slug = slug.replace(":", "/")
        parts = [p for p in slug.split("/") if p]
        if len(parts) >= 2:
            return f"{parts[-2]}-{parts[-1]}", "git"
    return os.path.basename(cwd), "basename"
```

- [ ] **Step 2: 컴파일 확인**

Run: `python3 -m py_compile plugins/mem0-ops/scripts/_api.py`
Expected: exit 0, 출력 없음

- [ ] **Step 3: resolve_app_id 라이브 확인 (repo 루트에서)**

Run: `cd /home/hsserver/workspace/my-claude-plugins && python3 -c "import sys; sys.path.insert(0,'plugins/mem0-ops/scripts'); from _api import resolve_app_id; print(resolve_app_id())"`
Expected: `('YoungjaeDev-my-claude-plugins', 'map')` (project_map.json에 등록된 경로)

- [ ] **Step 4: Commit**

```bash
git add plugins/mem0-ops/scripts/_api.py
git commit -m "feat(mem0-ops): REST helper + cwd scope resolution (_api.py)"
```

---

### Task 2: `fleet_scan.py`

**Files:**
- Create: `plugins/mem0-ops/scripts/fleet_scan.py`

**Interfaces:**
- Consumes: `_api.list_apps`, `_api.list_memories`
- Produces: stdout 리포트 (앱별 total/noise%/user split + JUNK?/FRAG 플래그), exit 0

- [ ] **Step 1: 작성**

```python
"""Fleet-wide mem0 scan: per-app noise ratio, type mix, fragmentation.

Read-only. Junk heuristic: basename-looking name (no owner- prefix pattern
match to a sibling), noise >= 90%, zero manually-typed memories.
Fragmentation: app A whose name is a suffix of app B (owner-prefixed pair).
"""
import sys
from collections import Counter

from _api import list_apps, list_memories

MANUAL_TYPES = {"decision", "feedback", "task_learning", "convention",
                "anti_pattern", "user_preference", "project_profile", "project"}
NOISE_TYPES = {"session_summary", "compact_summary", "session_state"}


def scan_app(app):
    mems = list_memories({"AND": [{"user_id": "*"}, {"app_id": app}]})
    types = Counter((m.get("metadata") or {}).get("type") or "(none)" for m in mems)
    users = Counter(m.get("user_id") for m in mems)
    noise = sum(n for t, n in types.items() if t in NOISE_TYPES)
    manual = sum(n for t, n in types.items() if t in MANUAL_TYPES)
    return {"app": app, "total": len(mems), "noise": noise,
            "manual": manual, "users": users, "types": types}


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
    print(f"\nGRAND total={grand} noise={grand_noise} "
          f"({100 * grand_noise // max(grand, 1)}%) across "
          f"{sum(1 for r in rows if r['total'])} active apps")
    if frag:
        print("\nFragmentation pairs (report-only; merge is out of scope v1):")
        for a, b in frag:
            print(f"  {a}  <->  {b}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: 컴파일 + 라이브 스모크 (read-only)**

Run: `python3 -m py_compile plugins/mem0-ops/scripts/fleet_scan.py && python3 plugins/mem0-ops/scripts/fleet_scan.py | tail -15`
Expected: GRAND 라인 + Fragmentation pairs에 `cc-card-news-deck <-> YoungjaeDev-cc-card-news-deck` 포함

- [ ] **Step 3: Commit**

```bash
git add plugins/mem0-ops/scripts/fleet_scan.py
git commit -m "feat(mem0-ops): fleet-wide noise/fragmentation scan"
```

---

### Task 3: `audit.py` (원형 이식)

**Files:**
- Create: `plugins/mem0-ops/scripts/audit.py` — 원형 `~/.mem0/mem0_audit.py`를 복사 후 아래 diff 적용

**Interfaces:**
- Consumes: `_api.list_memories`, `_api.resolve_app_id`
- Produces: stdout JSON 리포트 (total, by_type, duplicate_pairs, excl_violation_*, age_buckets), `--dump <path>` 시 전문 저장

- [ ] **Step 1: 원형 복사 + 변경 적용**

원형: `~/.mem0/mem0_audit.py` (Jaccard 중복쌍, Exclusions 위반 정규식, 연령 버킷 로직은 그대로 유지). 변경점:

```python
# (1) 상단 상수/자체 fetch 제거, _api 공유 헬퍼 사용
import argparse
from _api import list_memories, resolve_app_id

# (2) main() 시그니처: APP_ID 상수 -> argv
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
            print(f"WARNING: unmapped directory resolved to '{app}' (basename "
                  f"fallback) — this is how junk app_ids are born. "
                  f"Run from a project root or pass --app.", file=sys.stderr)
    mems = list_memories({"AND": [{"user_id": args.user}, {"app_id": app}]})
    if args.dump:
        with open(args.dump, "w") as f:
            json.dump(mems, f, ensure_ascii=False)
    # ... 이하 원형의 집계 로직 그대로 (by_type/by_cat/dups/exclusions/ages) ...
```

원형의 `fetch_all()` 함수와 `OUT` 상수는 삭제(위 `list_memories` + `--dump`로 대체). 나머지 함수(`toks`, `jaccard`, `age_days`, Exclusions 정규식 3종, 리포트 dict)는 그대로.

- [ ] **Step 2: 컴파일 + 라이브 스모크**

Run: `python3 -m py_compile plugins/mem0-ops/scripts/audit.py && cd /home/hsserver/workspace/my-claude-plugins && python3 plugins/mem0-ops/scripts/audit.py | python3 -c "import json,sys; r=json.load(sys.stdin); print(r['total'], dict(r['by_type'][:3]))"`
Expected: `230 {...}` 수준 (2026-07-07 정리 후 값 근방, session_summary 0)

- [ ] **Step 3: Commit**

```bash
git add plugins/mem0-ops/scripts/audit.py
git commit -m "feat(mem0-ops): single-app audit (port of session-proven mem0_audit.py)"
```

---

### Task 4: `cleanup.py` + targets 순수 로직 테스트 (TDD)

**Files:**
- Create: `plugins/mem0-ops/tests/test_cleanup_targets.py`
- Create: `plugins/mem0-ops/scripts/cleanup.py`

**Interfaces:**
- Consumes: `_api.list_memories`, `_api.req_json`, `_api.resolve_app_id`, `_api.BASE`
- Produces: `select_targets(mems, mem_type=None, all_types=False) -> list[str]` (순수 함수, 테스트 대상), CLI `cleanup.py [--app X] [--type T | --all] [--execute]`

- [ ] **Step 1: 실패하는 테스트 작성**

```python
"""Pure-logic tests for cleanup target selection. No network."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))
from cleanup import select_targets

MEMS = [
    {"id": "a", "metadata": {"type": "session_summary"}},
    {"id": "b", "metadata": {"type": "decision"}},
    {"id": "c", "metadata": None},
    {"id": "d"},
]


def test_type_filter_selects_only_matching():
    assert select_targets(MEMS, mem_type="session_summary") == ["a"]


def test_all_selects_everything():
    assert select_targets(MEMS, all_types=True) == ["a", "b", "c", "d"]


def test_no_selector_selects_nothing():
    assert select_targets(MEMS) == []


def test_missing_metadata_never_matches_type():
    assert select_targets(MEMS, mem_type="decision") == ["b"]
```

- [ ] **Step 2: 실패 확인**

Run: `cd plugins/mem0-ops && python3 -m pytest tests/test_cleanup_targets.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'cleanup'` (pytest 부재 시 `uv run --with pytest python3 -m pytest ...`)

- [ ] **Step 3: `cleanup.py` 작성**

```python
"""Backup-then-delete mem0 cleanup. --dry-run is the default; --execute deletes.

Safety contract (spec section 6): mandatory full-app JSON backup to
~/.mem0/backups/<app>-<YYYY-MM-DD>.json before any DELETE; 5xx retry in
_api.req_json; DELETE 404 treated as already-deleted (idempotent).
Restore: re-add backup rows via add_memory with infer=False.
"""
import argparse
import json
import os
import sys
from concurrent.futures import ThreadPoolExecutor
from datetime import date

from _api import BASE, list_memories, req_json, resolve_app_id


def select_targets(mems, mem_type=None, all_types=False):
    if all_types:
        return [m["id"] for m in mems]
    if not mem_type:
        return []
    return [m["id"] for m in mems
            if (m.get("metadata") or {}).get("type") == mem_type]


def backup(app, mems):
    bdir = os.path.expanduser("~/.mem0/backups")
    os.makedirs(bdir, exist_ok=True)
    path = os.path.join(bdir, f"{app}-{date.today().isoformat()}.json")
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
    ap.add_argument("--user", default=os.environ.get("MEM0_USER_ID", "*"))
    ap.add_argument("--type", dest="mem_type",
                    help="delete only this metadata.type (e.g. session_summary)")
    ap.add_argument("--all", action="store_true",
                    help="delete the whole app (junk app_id teardown)")
    ap.add_argument("--execute", action="store_true",
                    help="actually delete; default is dry-run")
    args = ap.parse_args()
    if not args.mem_type and not args.all:
        sys.exit("pass --type <metadata.type> or --all")
    app = args.app
    if not app:
        app, source = resolve_app_id()
        if source == "basename":
            sys.exit(f"refusing to run against basename-fallback scope "
                     f"'{app}' — run from a project root or pass --app.")
    mems = list_memories({"AND": [{"user_id": args.user}, {"app_id": app}]})
    targets = select_targets(mems, mem_type=args.mem_type, all_types=args.all)
    print(f"app={app} total={len(mems)} targets={len(targets)} "
          f"selector={'ALL' if args.all else args.mem_type}")
    if not args.execute:
        for m in mems[:5]:
            if m["id"] in set(targets[:5]):
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
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd plugins/mem0-ops && python3 -m pytest tests/test_cleanup_targets.py -q`
Expected: `4 passed`

- [ ] **Step 5: dry-run 라이브 스모크 (no-op 확인)**

Run: `cd /home/hsserver/workspace/my-claude-plugins && python3 plugins/mem0-ops/scripts/cleanup.py --type session_summary`
Expected: `app=YoungjaeDev-my-claude-plugins ... targets=0` 근방 + `dry-run` 라인, 삭제 없음

- [ ] **Step 6: Commit**

```bash
git add plugins/mem0-ops/tests/test_cleanup_targets.py plugins/mem0-ops/scripts/cleanup.py
git commit -m "feat(mem0-ops): backup-then-delete cleanup with dry-run default"
```

---

### Task 5: `doctor.py`

**Files:**
- Create: `plugins/mem0-ops/scripts/doctor.py`

**Interfaces:**
- Consumes: `_api.req_json`, `_api.BASE`, `GET /v1/entities/`
- Produces: stdout PASS/WARN 리포트, exit 0 (경고는 정보 제공 — 실패 아님)

- [ ] **Step 1: 작성**

```python
"""mem0 config posture check. Read-only, machine+account level.

Checks (spec section 5): MEM0_RERANK env, ~/.mem0/settings.json auto_save
(the file, not env, is authoritative — upstream _identity.sh overwrites the
env from this file on every hook run), project decay flag via REST,
upstream hook timeout budget, identity fragmentation.
"""
import glob
import json
import os
import sys
from collections import Counter

from _api import BASE, req_json


def check(label, ok, detail):
    print(f"{'PASS' if ok else 'WARN'}  {label:<22} {detail}")


def main():
    rerank = os.environ.get("MEM0_RERANK", "")
    check("MEM0_RERANK", rerank.strip().lower() in ("0", "false", "no", "off"),
          f"env={rerank or '(unset -> rerank ON, against mem0 best practice)'}")

    spath = os.path.expanduser("~/.mem0/settings.json")
    auto_save = True
    if os.path.isfile(spath):
        try:
            auto_save = json.load(open(spath)).get("auto_save", True)
        except (json.JSONDecodeError, OSError):
            pass
    check("auto_save", auto_save is False,
          f"~/.mem0/settings.json auto_save={auto_save} "
          f"(this file governs; env MEM0_AUTO_SAVE is overwritten per hook)")

    try:
        decay = req_json(f"{BASE}/api/v1/orgs/projects/?fields=decay")
    except Exception:
        decay = None
    if isinstance(decay, dict) and "decay" in str(decay):
        check("decay", True, f"project response: {json.dumps(decay)[:80]}")
    else:
        print("INFO  decay                  could not read via REST "
              "(verify in GUI or SDK: client.project.get(fields=['decay']))")

    hooks = glob.glob(os.path.expanduser(
        "~/.claude/plugins/cache/mem0-plugins/mem0/*/hooks/hooks.json"))
    for h in sorted(hooks):
        try:
            cfg = json.load(open(h))
            ups = cfg["hooks"]["UserPromptSubmit"][0]["hooks"][0].get("timeout")
            check("hook timeout", (ups or 0) >= 10,
                  f"{h.split('/cache/')[-1]} UserPromptSubmit timeout={ups}s "
                  f"(8s budget overruns on resume-type prompts)")
        except (KeyError, IndexError, json.JSONDecodeError, OSError):
            continue

    users, page = Counter(), 1
    while True:
        d = req_json(f"{BASE}/v1/entities/?page={page}")
        for e in d["results"]:
            users[e["type"]] += 1
        if not d.get("next"):
            break
        page += 1
    check("identity", users.get("user", 0) <= 2,
          f"entities: {users.get('user', 0)} users, {users.get('app', 0)} apps "
          f"(>2 users = fragmentation; recall splits across user_ids)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: 컴파일 + 라이브 스모크**

Run: `python3 -m py_compile plugins/mem0-ops/scripts/doctor.py && python3 plugins/mem0-ops/scripts/doctor.py`
Expected: 현 머신 기준 `PASS MEM0_RERANK`, `PASS auto_save`, hook timeout WARN(8s), identity WARN(9 users)

- [ ] **Step 3: Commit**

```bash
git add plugins/mem0-ops/scripts/doctor.py
git commit -m "feat(mem0-ops): config posture doctor"
```

---

### Task 6: SKILL.md 3종 + plugin.json + 매니페스트 fan-out + 최종 검증

**Files:**
- Create: `plugins/mem0-ops/skills/fleet-scan/SKILL.md`, `plugins/mem0-ops/skills/doctor/SKILL.md`, `plugins/mem0-ops/skills/cleanup/SKILL.md`
- Create: `plugins/mem0-ops/.claude-plugin/plugin.json`, `plugins/mem0-ops/CLAUDE.md`
- Modify: `.claude-plugin/marketplace.json` (엔트리 추가 + `metadata.version` 1.83.0→1.84.0), 루트 `CLAUDE.md` (Plugins 23→24 + 구조 트리 + Codex eligible 21→22), `README.md` (카운트·배지·상세), `AGENTS.md` (Codex 검증 코멘트 `# 22 entries` — Hermes 카운트는 불변), `.claude/settings.json` (`plugins.local`에 `./plugins/mem0-ops`)

**Interfaces:**
- Consumes: Task 1-5의 스크립트 4종 CLI
- Produces: 로드 가능한 플러그인 + 재생성된 `.codex-plugin/` 매니페스트

- [ ] **Step 1: `plugin.json` 작성**

```json
{
  "name": "mem0-ops",
  "version": "0.1.0",
  "description": "Fleet-level mem0 diagnostics and cleanup — complements the upstream mem0 plugin (which owns per-project quality). fleet-scan reports per-app noise ratio, junk app_id candidates, and app/user_id fragmentation across all apps; doctor checks config posture (MEM0_RERANK env, ~/.mem0/settings.json auto_save precedence trap, project decay flag, hook timeout budget, identity fragmentation); cleanup does backup-then-delete by metadata.type or whole junk app behind a dry-run default and per-app confirmation gate. stdlib-only REST scripts, zero LLM cost for the deterministic parts.",
  "skills": [
    "./skills/fleet-scan",
    "./skills/doctor",
    "./skills/cleanup"
  ]
}
```

- [ ] **Step 2: SKILL.md 3종 작성**

`skills/fleet-scan/SKILL.md`:

```markdown
---
name: fleet-scan
description: "Scan ALL mem0 app_ids at once — per-app memory count, noise ratio (session_summary and friends), junk app_id candidates (JUNK? flag), and app/user_id fragmentation pairs. Read-only, deterministic script, zero LLM cost. Use when the user asks for a mem0-wide overview, 'which projects are noisy', 'mem0 전체 점검', or before a cleanup round. Per-project quality (duplicates inside one app) belongs to the upstream mem0 plugin's memory-reviewer instead."
---

# fleet-scan

1. Run `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/fleet_scan.py`.
   - Requires `MEM0_API_KEY`; the script exits with guidance if unset.
2. Interpret the report for the user:
   - `JUNK?` flag = basename-style name + noise >= 90% + zero manual types.
     These are cwd-fallback artifacts; suggest `cleanup --app <name> --all`.
   - `FRAG` pairs = same project split across two app_ids (recall is split).
     Merge is out of scope v1 — report only.
   - High noise% on a real project = suggest `cleanup --app <name> --type session_summary`.
3. Do NOT delete anything from this skill. Route to the cleanup skill.
```

`skills/doctor/SKILL.md`:

```markdown
---
name: doctor
description: "Check mem0 configuration posture on this machine — MEM0_RERANK env (unset means rerank ON, against mem0's own best practice), ~/.mem0/settings.json auto_save (the file overrides env on every hook run — common trap), project decay flag, upstream hook UserPromptSubmit timeout budget, and user_id/app_id identity fragmentation. Read-only; suggests fixes but never applies them. Use for 'mem0 설정 점검', hook timeout complaints, or after installing mem0 on a new machine."
---

# doctor

1. Run `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/doctor.py`.
2. For each WARN, explain the fix but do NOT apply automatically:
   - MEM0_RERANK unset -> add `"MEM0_RERANK": "off"` to `~/.claude/settings.json` env.
   - auto_save true -> set `"auto_save": false` in `~/.mem0/settings.json`
     (env MEM0_AUTO_SAVE does NOT work — upstream _identity.sh overwrites it).
   - hook timeout 8s -> raising it means editing the plugin cache copy, which
     resets on update; prefer rerank off first, upstream issue second.
   - identity fragmentation -> consolidate MEM0_USER_ID across machines.
3. decay INFO line: if REST read failed, tell the user to check the GUI toggle.
```

`skills/cleanup/SKILL.md`:

```markdown
---
name: cleanup
description: "Backup-then-delete mem0 noise for one app (default: current project's app_id resolved from cwd like the upstream plugin does) or any app via --app. Dry-run is the default; deletion requires --execute and per-app user confirmation. Full-app teardown (--all) for junk app_ids. Always writes a JSON backup to ~/.mem0/backups/ first; restore = re-add with infer=False. Use for 'mem0 정리', 'session_summary 삭제', junk app teardown after fleet-scan."
---

# cleanup

1. Resolve scope: no args = current project (script mirrors upstream chain:
   MEM0_PROJECT_ID env -> project_map.json -> git slug -> basename).
   The script REFUSES basename-fallback scope; pass --app explicitly then.
2. Dry-run first, always:
   `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/cleanup.py [--app X] --type session_summary`
3. Show the dry-run count + samples to the user, then gate with
   AskUserQuestion (one question per app: delete N of M? yes/no).
   On Codex (no AskUserQuestion), ask in plain text and wait.
4. Only after explicit yes: re-run with `--execute`. Report ok/failed counts
   and the backup path.
5. Verify: run `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/audit.py --app X` and
   confirm the deleted type count is now 0.
6. Restore procedure (if the user regrets): read the backup JSON and re-add
   each row via mem0 add_memory with infer=False, same app_id/user_id/metadata.
```

- [ ] **Step 3: `plugins/mem0-ops/CLAUDE.md` 작성**

```markdown
# mem0-ops

플릿 레벨 mem0 진단·정리. upstream `mem0@mem0-plugins`(프로젝트 내부 품질:
health/memory-reviewer/stats/dream)와 역할 분리 — 이 플러그인은 app_id **간**
운영만 담당한다. 기능 복제 금지.

| Skill | 역할 |
|---|---|
| `fleet-scan` | 전 앱 노이즈율·쓰레기 후보·파편화 리포트 (read-only) |
| `doctor` | 설정 자세 점검 — rerank env, auto_save 파일 우선순위 함정, decay, 훅 timeout, 정체성 파편화 (제안만) |
| `cleanup` | 백업→타입/앱 단위 삭제. dry-run 기본, `--execute` + 사용자 확인 필수 |

스크립트는 stdlib + REST 직결(`scripts/_api.py`). upstream 스크립트/venv 의존
없음. `MEM0_API_KEY` 필수. 근거 스펙:
`docs/superpowers/specs/2026-07-07-mem0-ops-plugin-design.md`.
```

- [ ] **Step 4: 루트 fan-out 5파일 수정**

- `.claude-plugin/marketplace.json`: plugins 배열에 엔트리 추가(name/source `./plugins/mem0-ops`/description은 plugin.json과 동일/version `0.1.0`/category `productivity`) + `metadata.version` `1.83.0` → `1.84.0` (머지 직전 origin/main 재확인 규칙 적용)
- 루트 `CLAUDE.md`: `## Plugins (23)` → `(24)`, Productivity 표에 mem0-ops 행, 구조 트리에 `mem0-ops/` 줄, Codex 섹션 `21 eligible` → `22`
- `README.md`: 카운트 문장·배지 `23` → `24`, Codex `21 / 23` → `22 / 24`, 플러그인 상세 섹션에 mem0-ops 추가
- `AGENTS.md`: Codex 검증 코멘트 `# 21 entries` → `# 22 entries` (Hermes allowlist 카운트는 불변 — mem0-ops는 HERMES_ELIGIBLE 아님)
- `.claude/settings.json`: `plugins.local` 배열에 `"./plugins/mem0-ops"`

- [ ] **Step 5: 생성기 재실행 + 검증**

Run: `node scripts/sync-codex-manifests.mjs && node scripts/sync-codex-manifests.mjs --check && node scripts/sync-hermes-manifests.mjs --check`
Expected: mem0-ops `.codex-plugin/plugin.json` 생성(23 manifests), `--check` 통과, Hermes adapter는 미생성(allowlist 밖)

- [ ] **Step 6: 최종 검증 — `tmp` 쓰레기 앱 실증 (스펙 §10)**

```bash
python3 plugins/mem0-ops/scripts/cleanup.py --app tmp --all            # dry-run: targets=57
python3 plugins/mem0-ops/scripts/cleanup.py --app tmp --all --execute  # 사용자 확인 후
python3 plugins/mem0-ops/scripts/audit.py --app tmp                    # total=0 확인
ls ~/.mem0/backups/tmp-*.json                                          # 백업 존재 확인
```

Expected: dry-run 57건 → execute ok=57 failed=0 → audit total=0 → 백업 파일 존재.
주의: `--execute`는 스킬 규약대로 사용자 확인(AskUserQuestion) 후에만.

- [ ] **Step 7: Commit**

```bash
git add plugins/mem0-ops/ .claude-plugin/marketplace.json CLAUDE.md README.md AGENTS.md .claude/settings.json .agents/plugins/marketplace.json
git commit -m "feat(mem0-ops): fleet-level mem0 diagnostics/cleanup plugin (0.1.0)"
```

---

## Self-Review 결과

- 스펙 §3 구조·§4 스코프·§5 doctor·§6 cleanup 계약·§8 fan-out — Task 1-6에 전부 매핑됨. §2 결정 5건 중 병합 제외/리포트만(fleet_scan frag 출력), 쓰레기 앱 게이트(cleanup SKILL.md 3항), Windows 안내만(doctor SKILL.md 2항) 반영.
- 타입 정합: `select_targets` 시그니처가 Task 4 테스트·구현 동일. `resolve_app_id() -> (str, str)` Task 1 정의를 Task 3·4가 동일 사용.
- placeholder 없음 — audit.py만 "원형 이식 + diff" 형태이나 원형 경로와 변경 코드가 명시돼 실행 가능.
```
