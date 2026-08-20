#!/usr/bin/env python3
"""Unix PTY characterization tests for Program lifecycle behavior."""

from __future__ import annotations

import errno
import fcntl
import os
from pathlib import Path
import pty
import select
import signal
import struct
import termios
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
PROBE = ROOT / "tool" / "pty_program_probe.dart"
TIMEOUT = 10.0


class _Probe:
    def __init__(self, scenario: str, *, rows: int = 24, columns: int = 80):
        pid, master = pty.fork()
        if pid == 0:
            os.chdir(ROOT)
            os.execvp(
                "dart",
                ["dart", "run", str(PROBE), scenario],
            )
        self.pid = pid
        self.master = master
        self.status: int | None = None
        self.data = bytearray()
        self._set_size(master, rows, columns)
        os.set_blocking(master, False)

    def _set_size(self, fd: int, rows: int, columns: int) -> None:
        size = struct.pack("HHHH", rows, columns, 0, 0)
        fcntl.ioctl(fd, termios.TIOCSWINSZ, size)

    def resize(self, rows: int, columns: int) -> None:
        self._set_size(self.master, rows, columns)
        os.kill(self.pid, signal.SIGWINCH)

    def continue_process(self) -> None:
        os.kill(self.pid, signal.SIGCONT)

    def wait_for_stop(self) -> None:
        deadline = time.monotonic() + TIMEOUT
        while time.monotonic() < deadline:
            pid, status = os.waitpid(
                self.pid,
                os.WNOHANG | os.WUNTRACED,
            )
            if pid == self.pid and os.WIFSTOPPED(status):
                self._drain()
                return
            time.sleep(0.02)
        self._drain()
        self.fail(
            f"probe did not stop for suspend; output={bytes(self.data)!r}"
        )

    def read_until(self, marker: bytes) -> bytes:
        deadline = time.monotonic() + TIMEOUT
        while marker not in self.data and time.monotonic() < deadline:
            self._read_once(0.1)
            if self._poll():
                self._drain()
                break
        if marker not in self.data:
            self.fail(f"missing marker {marker!r}; output={bytes(self.data)!r}")
        return bytes(self.data)

    def finish(self) -> bytes:
        deadline = time.monotonic() + TIMEOUT
        while not self._poll() and time.monotonic() < deadline:
            self._read_once(0.1)
        if self.status is None:
            self._kill()
            self.fail("probe did not exit before timeout")
        self._drain()
        return_code = os.waitstatus_to_exitcode(self.status)
        if return_code != 0:
            self.fail(
                f"probe exited {return_code}; output={bytes(self.data)!r}"
            )
        return bytes(self.data)

    def close(self) -> None:
        if not self._poll():
            self._kill()
        os.close(self.master)

    def _kill(self) -> None:
        try:
            os.killpg(self.pid, signal.SIGKILL)
        except (PermissionError, ProcessLookupError):
            try:
                os.kill(self.pid, signal.SIGKILL)
                os.kill(self.pid, signal.SIGCONT)
            except ProcessLookupError:
                pass
        deadline = time.monotonic() + 2
        while not self._poll() and time.monotonic() < deadline:
            time.sleep(0.01)

    def _poll(self) -> bool:
        if self.status is not None:
            return True
        pid, status = os.waitpid(self.pid, os.WNOHANG)
        if pid == self.pid:
            self.status = status
            return True
        return False

    def _read_once(self, timeout: float) -> None:
        readable, _, _ = select.select([self.master], [], [], timeout)
        if not readable:
            return
        try:
            chunk = os.read(self.master, 65536)
        except OSError as error:
            if error.errno == errno.EIO:
                return
            raise
        self.data.extend(chunk)

    def _drain(self) -> None:
        while True:
            before = len(self.data)
            self._read_once(0)
            if len(self.data) == before:
                return

    def fail(self, message: str) -> None:
        raise AssertionError(message)


class ProgramRuntimePtyTest(unittest.TestCase):
    def _probe(self, scenario: str) -> _Probe:
        probe = _Probe(scenario)
        self.addCleanup(probe.close)
        return probe

    def assert_terminal_restored(self, output: bytes) -> None:
        self.assertIn(b"\x1b[?25h", output)
        self.assertIn(b"\x1b[?1049l", output)
        self.assertIn(b"\x1b[?2004l", output)

    def test_kill_wakes_an_idle_program_and_restores_terminal(self) -> None:
        probe = self._probe("kill")
        probe.read_until(b"KILL_READY")
        output = probe.finish()
        self.assert_terminal_restored(output)

    def test_external_cancellation_interrupts_and_restores_terminal(self) -> None:
        probe = self._probe("cancel")
        probe.read_until(b"CANCEL_READY")
        output = probe.finish()
        self.assert_terminal_restored(output)

    def test_sigwinch_delivers_the_new_pty_size(self) -> None:
        probe = self._probe("resize")
        probe.read_until(b"RESIZE_READY")
        probe.resize(37, 101)
        probe.read_until(b"RESIZED:101x37")
        self.assert_terminal_restored(probe.finish())

    def test_suspend_releases_then_restores_terminal_on_resume(self) -> None:
        probe = self._probe("suspend")
        probe.read_until(b"SUSPEND_READY")
        probe.wait_for_stop()
        released = bytes(probe.data)
        self.assert_terminal_restored(released)
        probe.continue_process()
        probe.read_until(b"RESUMED")
        self.assertIn(b"\x1b[?1049h", bytes(probe.data)[len(released) :])
        self.assert_terminal_restored(probe.finish())

    def test_quit_releases_stdin_and_exits_cleanly(self) -> None:
        probe = self._probe("stdin-quit")
        probe.read_until(b"STDIN_QUIT_READY")
        self.assert_terminal_restored(probe.finish())


if __name__ == "__main__":
    if os.name != "posix":
        raise SystemExit("PTY runtime tests require a Unix host")
    unittest.main(verbosity=2)
