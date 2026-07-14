#!/usr/bin/env python3
"""Mock-load every generated Hermes adapter and assert its register_skill calls fire.

The byte-drift guard (sync-hermes-manifests.mjs --check) only checks that the
generated plugins/<name>/__init__.py matches the generator output — it never
executes it. A generator regression that emits a syntactically broken or
non-registering adapter passes --check but fails at Hermes load time. This smoke
test imports each adapter with a stub ctx and asserts register() registers one
skill per SKILL.md, catching that "generated but never executed" gap.

Requires PyYAML (the adapters do `import yaml`); it is preinstalled on the CI
runner. Run: python3 scripts/mock-load-hermes.py
"""

import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLUGINS = ROOT / "plugins"


class StubCtx:
    """Records register_skill calls the way the real Hermes context would receive them."""

    def __init__(self):
        self.calls = []

    def register_skill(self, name, path, description):
        assert isinstance(name, str) and name, f"empty skill name from {path!r}"
        self.calls.append((name, str(path), description))


def load_adapter(init_py):
    spec = importlib.util.spec_from_file_location(
        f"hermes_adapter_{init_py.parent.name}", init_py
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    adapters = sorted(PLUGINS.glob("*/__init__.py"))
    if not adapters:
        sys.exit(
            "no Hermes adapters found — expected generated plugins/<name>/__init__.py"
        )

    failures = []
    for init_py in adapters:
        plugin = init_py.parent.name
        expected = len(sorted((init_py.parent / "skills").glob("*/SKILL.md")))
        try:
            module = load_adapter(init_py)
            ctx = StubCtx()
            module.register(ctx)
        except Exception as exc:  # noqa: BLE001 - report any adapter breakage
            failures.append(f"{plugin}: {type(exc).__name__}: {exc}")
            continue
        if len(ctx.calls) != expected:
            failures.append(
                f"{plugin}: register_skill fired {len(ctx.calls)}x, expected {expected}"
            )

    if failures:
        print("Hermes adapter mock-load FAILED:")
        for line in failures:
            print(f"  {line}")
        sys.exit(1)
    print(
        f"Hermes adapter mock-load OK — {len(adapters)} adapters, register_skill exercised."
    )


if __name__ == "__main__":
    main()
