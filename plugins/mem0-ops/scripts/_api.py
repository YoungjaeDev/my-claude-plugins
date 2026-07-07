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
            req = urllib.request.Request(
                url,
                data=data,
                method=method,
                headers={
                    "Authorization": f"Token {api_key()}",
                    "Content-Type": "application/json",
                },
            )
            with urllib.request.urlopen(req, timeout=30) as r:
                if r.status == 204 or not r.length:
                    return {}
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 404 and method == "DELETE":
                return {}
            if e.code in (500, 502, 503, 504) and i < retries - 1:
                time.sleep(2**i)
                last = e
                continue
            raise
    assert last is not None  # loop always returns or raises on final attempt
    raise last


def list_memories(filters):
    """Page through POST /v2/memories/ (list-by-filter). Returns all rows."""
    mems, page = [], 1
    while True:
        d = req_json(
            f"{BASE}/v2/memories/?page={page}&page_size=100", {"filters": filters}
        )
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
        url = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            capture_output=True,
            text=True,
            timeout=5,
        ).stdout.strip()
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
