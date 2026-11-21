#!/usr/bin/env python3
"""PTY tests for `dart_tui dev` (hot reload). POSIX only.

Runs `dart_tui dev` on a fixture app in a pseudo-terminal, edits the app on
disk, and checks the screen, the exit code and the terminal modes.

    python3 tool/pty_dev_test.py
"""

from __future__ import annotations

import fcntl
import os
from pathlib import Path
import pty
import re
import select
import shutil
import signal
import struct
import subprocess
import tempfile
import termios
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
TIMEOUT = 60.0
ROWS, COLUMNS = 24, 100

APP = """\
import 'dart:io';

import 'package:dart_tui/dart_tui.dart';

enum Mode { a, b }

Future<void> main() async {
  await Program().run(Counter());
}

final class Counter extends Model {
  int count = 0;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      if (msg.key == 'q' || msg.key == 'ctrl+c') return (this, () => quit());
      if (msg.key == 'x') throw StateError('boom');
      if (msg.key == 'e') exit(7);
      if (msg.key == '+') count++;
    }
    return (this, null);
  }

  @override
  View view() => newView('VIEW-ONE count=$count ${Mode.a.name}');
}
"""


class Screen:
    """Just enough of a terminal to read the inline renderer's frames."""

    _token = re.compile(
        rb"\x1b\[([?<=>0-9;]*)[ -/]*([@-~])|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)"
        rb"|\x1bP[^\x1b]*\x1b\\|\x1b[^\[\]P]|\r|\n|[^\x1b\r\n]+"
    )

    def __init__(self, rows: int, columns: int):
        self.rows, self.columns = rows, columns
        self.lines = [""] * rows
        self.row = self.col = 0

    def feed(self, data: bytes) -> None:
        for match in self._token.finditer(data):
            text = match.group(0)
            if match.group(2):
                self._csi(match.group(1).decode(), match.group(2).decode())
            elif text == b"\r":
                self.col = 0
            elif text == b"\n":
                self.row += 1
                if self.row == self.rows:
                    self.lines = self.lines[1:] + [""]
                    self.row -= 1
            elif not text.startswith(b"\x1b"):
                self._write(text.decode("utf-8", "replace"))

    def _write(self, text: str) -> None:
        line = self.lines[self.row].ljust(self.col)
        self.lines[self.row] = line[: self.col] + text + line[self.col + len(text):]
        self.col += len(text)

    def _csi(self, params: str, final: str) -> None:
        if params[:1] in ("?", "<", "=", ">"):
            return
        n = int(params.split(";")[0] or 1) if final in "ABCDG" else 0
        if final == "A":
            self.row = max(0, self.row - n)
        elif final == "B":
            self.row = min(self.rows - 1, self.row + n)
        elif final == "C":
            self.col += n
        elif final == "D":
            self.col = max(0, self.col - n)
        elif final == "G":
            self.col = n - 1
        elif final == "H":
            parts = (params.split(";") + ["1", "1"])[:2]
            self.row, self.col = int(parts[0] or 1) - 1, int(parts[1] or 1) - 1
        elif final == "K":
            self.lines[self.row] = self.lines[self.row][: self.col]
        elif final == "J":
            self.lines[self.row] = self.lines[self.row][: self.col]
            for r in range(self.row + 1, self.rows):
                self.lines[r] = ""

    def text(self) -> str:
        return "\n".join(line.rstrip() for line in self.lines)


class DevSession:
    def __init__(self, app: Path, snapshot: Path):
        pid, master = pty.fork()
        if pid == 0:
            os.chdir(app)
            env = os.environ.copy()
            env["TERM"] = "xterm-256color"
            for name in ("CI", "NO_COLOR", "ACCESSIBLE", "DART_TUI_ACCESSIBLE"):
                env.pop(name, None)
            os.execvpe("dart", ["dart", str(snapshot), "dev"], env)
        self.pid, self.master = pid, master
        self.status: int | None = None
        self.data = bytearray()
        self.screen = Screen(ROWS, COLUMNS)
        size = struct.pack("HHHH", ROWS, COLUMNS, 0, 0)
        fcntl.ioctl(master, termios.TIOCSWINSZ, size)
        os.set_blocking(master, False)

    def wait_screen(self, pattern: str, timeout: float = TIMEOUT) -> str:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if re.search(pattern, self.screen.text()):
                return self.screen.text()
            self._read(0.1)
            if self._poll():
                self._read(0)
                break
        if re.search(pattern, self.screen.text()):
            return self.screen.text()
        raise AssertionError(
            f"screen never matched {pattern!r}:\n{self.screen.text()}\n"
            f"raw tail={bytes(self.data[-600:])!r}"
        )

    def send(self, data: bytes) -> None:
        os.write(self.master, data)

    def exit_code(self) -> int:
        deadline = time.monotonic() + 20
        while not self._poll() and time.monotonic() < deadline:
            self._read(0.1)
        if self.status is None:
            raise AssertionError(f"dart_tui dev did not exit:\n{self.screen.text()}")
        self._read(0)
        return os.waitstatus_to_exitcode(self.status)

    def close(self) -> None:
        running = not self._poll()
        if running:
            try:
                os.killpg(self.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        # Close first: on macOS an exiting process waits for its unread
        # terminal output to drain.
        os.close(self.master)
        if running:
            os.waitpid(self.pid, 0)

    def _poll(self) -> bool:
        if self.status is None:
            pid, status = os.waitpid(self.pid, os.WNOHANG)
            if pid == self.pid:
                self.status = status
        return self.status is not None

    def _read(self, timeout: float) -> None:
        while True:
            readable, _, _ = select.select([self.master], [], [], timeout)
            if not readable:
                return
            try:
                chunk = os.read(self.master, 65536)
            except (BlockingIOError, OSError):
                return
            if not chunk:
                return
            self.data += chunk
            self.screen.feed(chunk)
            timeout = 0


class DevPtyTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tmp = Path(tempfile.mkdtemp(prefix="dart_tui_dev_pty"))
        cls.snapshot = cls.tmp / "dart_tui.dill"
        subprocess.run(
            ["dart", "compile", "kernel", "bin/dart_tui.dart", "-o", str(cls.snapshot)],
            cwd=ROOT, check=True, capture_output=True, stdin=subprocess.DEVNULL,
        )

    @classmethod
    def tearDownClass(cls) -> None:
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def setUp(self) -> None:
        self.app = Path(tempfile.mkdtemp(prefix="app", dir=self.tmp))
        (self.app / "bin").mkdir()
        (self.app / "pubspec.yaml").write_text(
            "name: counter\n"
            "environment:\n  sdk: '>=3.5.0 <4.0.0'\n"
            f"dependencies:\n  dart_tui:\n    path: {ROOT}\n"
        )
        self.write(APP)
        subprocess.run(
            ["dart", "pub", "get", "--offline"],
            cwd=self.app, check=True, capture_output=True, stdin=subprocess.DEVNULL,
        )

    def write(self, source: str) -> None:
        (self.app / "bin" / "counter.dart").write_text(source)

    def edit(self, old: str, new: str) -> None:
        path = self.app / "bin" / "counter.dart"
        source = path.read_text()
        self.assertIn(old, source)
        path.write_text(source.replace(old, new))

    def start(self) -> DevSession:
        session = DevSession(self.app, self.snapshot)
        self.addCleanup(session.close)
        session.wait_screen(r"VIEW-ONE count=0")
        return session

    def assert_restored(self, session: DevSession) -> None:
        output = bytes(session.data)
        self.assertGreater(output.rfind(b"\x1b[?25h"), output.rfind(b"\x1b[?25l"))
        self.assertGreater(output.rfind(b"\x1b[>4m"), output.rfind(b"\x1b[>4;2m"))
        self.assertIn(b"\x1b[=0;1u", output[output.rfind(b"\x1b[>4m"):])
        iflag, _, _, lflag = termios.tcgetattr(session.master)[:4]
        for flag in (termios.ECHO, termios.ICANON, termios.ISIG, termios.IEXTEN):
            self.assertTrue(lflag & flag)
        self.assertTrue(iflag & termios.IXON)

    def test_reload_keeps_state_shows_errors_and_restarts(self) -> None:
        session = self.start()
        session.send(b"+++")
        session.wait_screen(r"VIEW-ONE count=3")

        # A new view() shows, and the counter keeps its value.
        self.edit("VIEW-ONE", "VIEW-TWO")
        session.wait_screen(r"VIEW-TWO count=3")

        # A syntax error shows the banner; the app still answers keys.
        self.edit("=> newView(", "=> + newView(")
        session.wait_screen(
            r"Compile error \(\.dart_tool/dart_tui/dev\.log\): "
            r"bin/counter\.dart:\d+:\d+: '\+' is not a prefix operator"
        )
        session.send(b"+")
        session.wait_screen(r"VIEW-TWO count=4")

        # Fixing it clears the banner.
        self.edit("=> + newView('VIEW-TWO", "=> newView('VIEW-THREE")
        # The new line and the erase below it can arrive in separate reads.
        session.wait_screen(r"(?s)^(?!.*Compile error).*VIEW-THREE count=4")
        log = (self.app / ".dart_tool" / "dart_tui" / "dev.log").read_text()
        self.assertIn("is not a prefix operator", log)

        # A change the VM cannot apply restarts the app.
        self.edit(
            "enum Mode { a, b }",
            "class Mode {\n  static const a = Mode();\n  const Mode();\n"
            "  String get name => 'a';\n}",
        )
        screen = session.wait_screen(r"restarted: .*Mode")
        self.assertRegex(screen, r"VIEW-THREE count=0")

        # Ctrl+C exits with the cursor visible and the terminal cooked.
        session.send(b"\x03")
        self.assertEqual(session.exit_code(), 0)
        self.assert_restored(session)

    def test_sigint_to_the_process_group_waits_for_the_app(self) -> None:
        session = self.start()
        os.killpg(session.pid, signal.SIGINT)
        self.assertEqual(session.exit_code(), 0)
        self.assert_restored(session)

    def test_sigint_to_dev_only_is_ignored(self) -> None:
        session = self.start()
        os.kill(session.pid, signal.SIGINT)
        # SIGINT belongs to the app when the terminal sends it to the process
        # group. A signal sent only to the watcher must not stop the app.
        time.sleep(0.2)
        self.assertIsNone(session.status)
        session.send(b"+")
        session.wait_screen(r"VIEW-ONE count=1")
        session.send(b"\x03")
        self.assertEqual(session.exit_code(), 0)
        self.assert_restored(session)

    def test_sighup_to_dev_quits_the_app_first(self) -> None:
        session = self.start()
        os.kill(session.pid, signal.SIGHUP)
        self.assertEqual(session.exit_code(), 0)
        self.assert_restored(session)

    def test_sigterm_to_dev_quits_the_app_first(self) -> None:
        session = self.start()
        os.kill(session.pid, signal.SIGTERM)
        self.assertEqual(session.exit_code(), 0)
        self.assert_restored(session)

    def test_app_exception_exits_with_its_code_and_restores(self) -> None:
        session = self.start()
        session.send(b"x")
        self.assertEqual(session.exit_code(), 255)
        self.assert_restored(session)

    def test_app_that_calls_exit_gets_its_terminal_back(self) -> None:
        # exit() skips the Program's restore; dev puts the terminal back.
        session = self.start()
        session.send(b"e")
        self.assertEqual(session.exit_code(), 7)
        self.assert_restored(session)


if __name__ == "__main__":
    unittest.main(verbosity=2)
