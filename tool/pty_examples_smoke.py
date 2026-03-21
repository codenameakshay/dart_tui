#!/usr/bin/env python3
"""Run interactive example smoke tests in a real PTY (Linux/macOS)."""

from __future__ import annotations

import os
import pty
import select
import shutil
import subprocess
import sys
import time


EXAMPLES = [
    ("shopping_list", ["q"]),
    ("showcase", ["q"]),
    ("all_features", ["q"]),
    ("prompts_chain", ["\r", "y", "hello\r"]),
]


def _dart_runner() -> list[str]:
    if shutil.which("fvm"):
        return ["fvm", "dart"]
    if shutil.which("dart"):
        return ["dart"]
    raise RuntimeError("Neither 'fvm' nor 'dart' is available in PATH.")


def _run_example(example: str, keys: list[str], timeout_s: float = 20.0) -> dict:
    cmd = _dart_runner() + ["run", f"example/{example}.dart"]
    master, slave = pty.openpty()
    proc = subprocess.Popen(
        cmd,
        stdin=slave,
        stdout=slave,
        stderr=slave,
        close_fds=True,
    )
    os.close(slave)

    out = bytearray()
    start = time.monotonic()
    next_key_at = start + 1.0
    key_idx = 0
    exit_code: int | None = None

    while True:
        now = time.monotonic()
        if key_idx < len(keys) and now >= next_key_at:
            os.write(master, keys[key_idx].encode())
            key_idx += 1
            next_key_at = now + 0.8

        readable, _, _ = select.select([master], [], [], 0.1)
        if readable:
            try:
                chunk = os.read(master, 4096)
            except OSError:
                chunk = b""
            if chunk:
                out.extend(chunk)

        exit_code = proc.poll()
        if exit_code is not None:
            break

        if now - start > timeout_s:
            proc.kill()
            exit_code = 124
            break

    try:
        os.close(master)
    except OSError:
        pass

    text = out.decode("utf-8", errors="replace")
    return {
        "example": example,
        "exit_code": int(exit_code),
        "timed_out": exit_code == 124,
        "saw_alt_enter": "\x1b[?1049h" in text,
        "saw_alt_leave": "\x1b[?1049l" in text,
        "tail": text[-220:],
    }


def main() -> int:
    print("PTY example smoke tests")
    failures: list[dict] = []
    for example, keys in EXAMPLES:
        result = _run_example(example, keys)
        status = "PASS" if result["exit_code"] == 0 else "FAIL"
        print(f"[{status}] {example} exit={result['exit_code']}")
        if result["exit_code"] != 0:
            failures.append(result)

    if failures:
        print("\nFailures:")
        for failure in failures:
            print(f"- {failure['example']} (exit={failure['exit_code']})")
            print(f"  tail: {failure['tail']!r}")
        return 1

    print("\nAll PTY example smoke tests passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
