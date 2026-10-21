#!/usr/bin/env python3
"""Cooperative Aside task gate, not a security sandbox.

Only runtimes using this gate cooperate. Reservations never expire automatically;
release only after the caller verifies actual task completion or cancellation.
No browser decisions, terminal-state inference, or authentication inspection.
"""

import argparse
from contextlib import contextmanager, suppress
import fcntl
import errno
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import uuid


REQUEST_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]{0,127}")
OWNERS = ("claude-code", "hermes")


@contextmanager
def coordination(root, create):
    directory = root / ".coordination"
    if directory.is_symlink():
        raise ValueError("refusing symlink coordination directory")
    if create:
        directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    try:
        descriptor = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    except FileNotFoundError:
        if create:
            raise
        yield None
        return
    try:
        yield descriptor
    finally:
        os.close(descriptor)


def check_record(directory, name):
    try:
        mode = os.stat(name, dir_fd=directory, follow_symlinks=False).st_mode
    except FileNotFoundError:
        return False
    if stat.S_ISLNK(mode):
        raise ValueError(f"refusing symlink {name}")
    if not stat.S_ISREG(mode):
        raise ValueError(f"{name} must be a regular file")
    return True


def read_reservation(directory):
    if not check_record(directory, "owner.json"):
        return None
    descriptor = os.open("owner.json", os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
                         dir_fd=directory)
    with os.fdopen(descriptor) as stream:
        reservation = json.load(stream)
    if (not isinstance(reservation, dict)
            or set(reservation) != {"request_id", "owner"}
            or not isinstance(reservation["request_id"], str)
            or not REQUEST_ID.fullmatch(reservation["request_id"])
            or reservation["owner"] not in OWNERS):
        raise ValueError("invalid reservation in owner.json; refusing automatic reclamation")
    return reservation


def reserve(directory, owner):
    temporary = f".owner-{uuid.uuid4().hex}.tmp"
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                         0o600, dir_fd=directory)
    try:
        with os.fdopen(descriptor, "w") as stream:
            json.dump(owner, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, "owner.json", src_dir_fd=directory, dst_dir_fd=directory)
    finally:
        with suppress(FileNotFoundError):
            os.unlink(temporary, dir_fd=directory)


def mutate(directory, args):
    reservation = read_reservation(directory)
    expected = {"request_id": args.request_id, "owner": args.owner}
    if reservation is not None and reservation != expected:
        print("aside_gate: reservation belongs to another task or runtime", file=sys.stderr)
        return 75
    if args.command == "release":
        if reservation is None:
            print("aside_gate: no reservation to release", file=sys.stderr)
            return 75
        os.unlink("owner.json", dir_fd=directory)
        return 0
    if not args.aside_bin:
        print("aside_gate: Aside executable not found; set --aside-bin or ASIDE_BIN", file=sys.stderr)
        return 127
    if reservation is None:
        reserve(directory, expected)
    try:
        process = subprocess.Popen([args.aside_bin, *args.aside_args])
    except OSError as error:
        # Only known exec/setup errors prove that no child executable started.
        if reservation is None and error.errno in {
                errno.ENOENT, errno.EACCES, errno.ENOEXEC, errno.ENOTDIR,
                errno.EISDIR, errno.ELOOP, errno.ENAMETOOLONG, errno.ETXTBSY,
                errno.EPERM, errno.E2BIG, errno.EAGAIN, errno.ENOMEM,
                errno.EMFILE, errno.ENFILE, errno.EBADF, errno.EFAULT,
                errno.EINVAL, errno.ENOSYS}:
            os.unlink("owner.json", dir_fd=directory)
        if error.errno == errno.ENOENT:
            print(f"aside_gate: Aside executable not found: {error}", file=sys.stderr)
            return 127
        print(f"aside_gate: cannot execute Aside executable: {error}", file=sys.stderr)
        return 126
    # Popen returned: the executable started. No wait/exit outcome permits cleanup.
    return process.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=os.environ.get("ASIDE_OPS_ROOT") or "~/aside-ops")
    parser.add_argument("--aside-bin", default=os.environ.get("ASIDE_BIN") or shutil.which("aside"))
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("status")
    for command in ("run", "release"):
        child = commands.add_parser(command)
        child.add_argument("--request-id", required=True)
        child.add_argument("--owner", required=True, choices=OWNERS)
        if command == "run":
            child.add_argument("aside_args", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.command != "status" and not REQUEST_ID.fullmatch(args.request_id):
        parser.error("request ID must match [A-Za-z0-9][A-Za-z0-9_-]{0,127}")
    if args.command == "run":
        if args.aside_args[:1] == ["--"]:
            args.aside_args = args.aside_args[1:]
        if not args.aside_args:
            parser.error("run requires nonempty Aside arguments after --")
    try:
        with coordination(Path(args.root).expanduser(), args.command != "status") as directory:
            if directory is None:
                print(json.dumps({"reservation": None}))
                return 0
            check_record(directory, "gate.lock")
            if args.command == "status":
                print(json.dumps({"reservation": read_reservation(directory)}))
                return 0
            lock = os.open("gate.lock", os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK,
                           0o600, dir_fd=directory)
            try:
                if not stat.S_ISREG(os.fstat(lock).st_mode):
                    raise ValueError("gate.lock must be a regular file")
                try:
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError:
                    print("aside_gate: another command is in flight", file=sys.stderr)
                    return 75
                return mutate(directory, args)
            finally:
                os.close(lock)
    except (OSError, ValueError) as error:
        print(f"aside_gate: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
