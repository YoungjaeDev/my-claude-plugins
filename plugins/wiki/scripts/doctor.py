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

from _api import BASE, list_entities, req_json


def check(label, ok, detail):
    print(f"{'PASS' if ok else 'WARN'}  {label:<22} {detail}")


def main():
    rerank = os.environ.get("MEM0_RERANK", "")
    check(
        "MEM0_RERANK",
        rerank.strip().lower() in ("0", "false", "no", "off"),
        f"env={rerank or '(unset -> rerank ON, against mem0 best practice)'}",
    )

    spath = os.path.expanduser("~/.mem0/settings.json")
    auto_save = True
    if os.path.isfile(spath):
        try:
            auto_save = json.load(open(spath)).get("auto_save", True)
        except (json.JSONDecodeError, OSError):
            pass
    check(
        "auto_save",
        auto_save is False,
        f"~/.mem0/settings.json auto_save={auto_save} "
        f"(this file governs; env MEM0_AUTO_SAVE is overwritten per hook)",
    )

    try:
        decay = req_json(f"{BASE}/api/v1/orgs/projects/?fields=decay")
    except Exception:
        decay = None
    if isinstance(decay, dict) and "decay" in decay:
        val = decay.get("decay")
        check(
            "decay",
            bool(val),
            f"project decay={val}"
            + ("" if val else " (search-time ranking decay disabled)"),
        )
    else:
        print(
            "INFO  decay                  could not read via REST "
            "(verify in GUI or SDK: client.project.get(fields=['decay']))"
        )

    hooks = glob.glob(
        os.path.expanduser(
            "~/.claude/plugins/cache/mem0-plugins/mem0/*/hooks/hooks.json"
        )
    )
    for h in sorted(hooks):
        try:
            cfg = json.load(open(h))
            ups = cfg["hooks"]["UserPromptSubmit"][0]["hooks"][0].get("timeout")
            check(
                "hook timeout",
                (ups or 0) >= 10,
                f"{h.split('/cache/')[-1]} UserPromptSubmit timeout={ups}s "
                f"(8s budget overruns on resume-type prompts)",
            )
        except (KeyError, IndexError, json.JSONDecodeError, OSError):
            continue

    users = Counter(e["type"] for e in list_entities())
    check(
        "identity",
        users.get("user", 0) <= 2,
        f"entities: {users.get('user', 0)} users, {users.get('app', 0)} apps "
        f"(>2 users = fragmentation; recall splits across user_ids)",
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
