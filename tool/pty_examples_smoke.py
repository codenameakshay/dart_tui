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
    {
        "name": "shopping_list",
        "keys": ["q"],
        "repeat_last": True,
        "markers": ["\x1b[?1049h", "\x1b[?1049l"],
    },
    {
        "name": "showcase",
        "keys": ["q"],
        "repeat_last": True,
        "markers": ["\x1b[?1049h", "\x1b[?1049l"],
    },
    {
        "name": "all_features",
        "keys": ["q"],
        "repeat_last": True,
        "markers": ["\x1b[?1049h", "\x1b[?1049l"],
    },
    {
        "name": "prompts_chain",
        # Each prompt is its own Program, so wait for it before typing.
        "keys": [
            ("Favorite ice cream", "\r"),
            ("Ship to production", "y"),
            ("Notes:", "hello\r"),
        ],
        "repeat_last": False,
        "markers": ["Selected: Vanilla", "Confirmed: true", "Notes: hello"],
    },
    {
        "name": "shopping_list",
        "ready": "What should we buy",
        "keys": [" ", "q"],
        "repeat_last": False,
        "markers": ["[x]"],
    },
    {
        "name": "textinput",
        "ready": "Enter your name:",
        "keys": ["\x1b[200~pasted-text\x1b[201~", "\r", "\x03"],
        "repeat_last": False,
        "markers": ["You typed: pasted-text"],
    },
]

# After the last marker, a quit key must end the process on its own: the
# implicit stdin reader used to keep the VM alive after teardown (#15).
EXIT_GRACE_S = 5.0


def _dart_runner() -> list[str]:
    override = os.environ.get("DART_TUI_RUNNER", "").strip()
    if override:
        return override.split()
    if shutil.which("dart"):
        return ["dart"]
    if shutil.which("fvm"):
        return ["fvm", "dart"]
    raise RuntimeError("Neither 'fvm' nor 'dart' is available in PATH.")


def _run_example(
    example: str,
    keys: list[str | tuple[str, str]],
    *,
    repeat_last: bool,
    markers: list[str],
    ready: str | None = None,
    timeout_s: float = 20.0,
) -> dict:
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
    checkpoints_ok = False
    is_ready = ready is None

    while True:
        now = time.monotonic()
        if is_ready and now >= next_key_at:
            if key_idx < len(keys):
                key = keys[key_idx]
                gate, data = key if isinstance(key, tuple) else (None, key)
                if gate is None or gate in out.decode("utf-8", errors="replace"):
                    os.write(master, data.encode())
                    key_idx += 1
            elif repeat_last and keys:
                os.write(master, keys[-1].encode())
            next_key_at = now + 0.8

        readable, _, _ = select.select([master], [], [], 0.1)
        if readable:
            try:
                chunk = os.read(master, 4096)
            except OSError:
                chunk = b""
            if chunk:
                out.extend(chunk)
                text = out.decode("utf-8", errors="replace")
                if not is_ready and ready in text:
                    is_ready = True
                    next_key_at = time.monotonic() + 0.3
                checkpoints_ok = all(m in text for m in markers)
                if checkpoints_ok and key_idx >= len(keys):
                    break

        exit_code = proc.poll()
        if exit_code is not None:
            break

        if now - start > timeout_s:
            proc.kill()
            exit_code = 124
            break

    if exit_code is None:
        try:
            exit_code = proc.wait(timeout=EXIT_GRACE_S)
        except subprocess.TimeoutExpired:
            proc.kill()
            exit_code = 125  # still running after quit
    while True:
        readable, _, _ = select.select([master], [], [], 0.1)
        if not readable:
            break
        try:
            chunk = os.read(master, 4096)
        except OSError:
            break
        if not chunk:
            break
        out.extend(chunk)
    if exit_code == 0 and not all(
        m in out.decode("utf-8", errors="replace") for m in markers
    ):
        exit_code = 126  # exited without showing every marker

    try:
        os.close(master)
    except OSError:
        pass

    text = out.decode("utf-8", errors="replace")
    return {
        "example": example,
        "exit_code": int(exit_code),
        "timed_out": exit_code == 124,
        "checkpoints_ok": checkpoints_ok,
        "saw_alt_enter": "\x1b[?1049h" in text,
        "saw_alt_leave": "\x1b[?1049l" in text,
        "tail": text[-220:],
    }


def main() -> int:
    print("PTY example smoke tests")
    failures: list[dict] = []
    for spec in EXAMPLES:
        result = _run_example(
            spec["name"],
            spec["keys"],
            repeat_last=spec["repeat_last"],
            markers=spec["markers"],
            ready=spec.get("ready"),
        )
        status = "PASS" if result["exit_code"] == 0 else "FAIL"
        print(f"[{status}] {spec['name']} exit={result['exit_code']}")
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
