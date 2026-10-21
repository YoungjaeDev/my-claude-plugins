#!/usr/bin/env python3
"""Compatibility launcher for the single shared Aside gate implementation."""

import argparse
import os
from pathlib import Path
import sys


def main():
    # Parse only global options, never an Aside argument after the subcommand.
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--root", default=os.environ.get("ASIDE_OPS_ROOT") or "~/aside-ops")
    parser.add_argument("--aside-bin")
    parser.add_argument("remaining", nargs=argparse.REMAINDER)
    args, _ = parser.parse_known_args()
    runtime = Path(args.root).expanduser() / "bin" / "aside_gate.py"
    if not runtime.is_file():
        bundled = Path(__file__).resolve().parent.parent / "runtime"
        print(f"aside_gate: shared runtime unavailable: {runtime}; install it with: "
              f"mkdir -p '{runtime.parent.parent}' && cp -R '{bundled}/.' '{runtime.parent.parent}/'",
              file=sys.stderr)
        return 127
    os.execv(sys.executable, [sys.executable, str(runtime), *sys.argv[1:]])


if __name__ == "__main__":
    raise SystemExit(main())
