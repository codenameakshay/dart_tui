#!/usr/bin/env python3
"""Unix PTY characterization tests for Program lifecycle behavior."""

from __future__ import annotations

import errno
import fcntl
import os
from pathlib import Path
import pty
import select
import shlex
import shutil
import signal
import subprocess
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

    def read_until_count(self, marker: bytes, count: int) -> bytes:
        deadline = time.monotonic() + TIMEOUT
        while self.data.count(marker) < count and time.monotonic() < deadline:
            self._read_once(0.1)
            if self._poll():
                self._drain()
                break
        if self.data.count(marker) < count:
            self.fail(
                f"missing occurrence {count} of {marker!r}; "
                f"output={bytes(self.data)!r}"
            )
        return bytes(self.data)

    def send(self, data: bytes) -> None:
        os.write(self.master, data)

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

    def assert_cooked_mode(self, probe: _Probe) -> None:
        iflag, _, _, lflag = termios.tcgetattr(probe.master)[:4]
        self.assertTrue(lflag & termios.ECHO)
        self.assertTrue(lflag & termios.ICANON)
        self.assertTrue(lflag & termios.ISIG)
        self.assertTrue(lflag & termios.IEXTEN)
        self.assertTrue(iflag & termios.IXON)

    def test_kill_wakes_an_idle_program_and_restores_terminal(self) -> None:
        probe = self._probe("kill")
        probe.read_until(b"KILL_READY")
        output = probe.finish()
        self.assert_terminal_restored(output)
        self.assert_cooked_mode(probe)

    def test_external_cancellation_interrupts_and_restores_terminal(self) -> None:
        probe = self._probe("cancel")
        probe.read_until(b"CANCEL_READY")
        output = probe.finish()
        self.assert_terminal_restored(output)
        self.assert_cooked_mode(probe)

    def test_q_exits_and_restores_terminal(self) -> None:
        probe = self._probe("stdin-quit")
        probe.read_until(b"STDIN_QUIT_READY")
        probe.send(b"q")
        output = probe.finish()
        self.assert_terminal_restored(output)
        self.assert_cooked_mode(probe)

    def test_ctrl_c_exits_and_restores_terminal(self) -> None:
        probe = self._probe("stdin-ctrl-c")
        probe.read_until(b"STDIN_CTRL_C_READY")
        probe.send(b"\x03")
        output = probe.finish()
        self.assert_terminal_restored(output)
        self.assert_cooked_mode(probe)

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

    def test_default_stdin_program_exits_after_quit(self) -> None:
        probe = self._probe("default-quit")
        probe.read_until(b"DEFAULT_QUIT_READY")
        probe.send(b"q")
        self.assert_terminal_restored(probe.finish())
        self.assert_cooked_mode(probe)

    def test_plain_password_restores_disabled_echo(self) -> None:
        probe = self._probe("plain-password-echo")
        probe.read_until(b"SECRET")
        probe.send(b"private\r")
        output = probe.finish()
        self.assertIn(b"ECHO_RESTORED=false", output)
        self.assertNotIn(b"private", output)
        self.assertNotIn(b"\x1b", output)

    def test_plain_prompt_pushback_reaches_tui_program(self) -> None:
        probe = self._probe("plain-then-tui")
        probe.read_until(b"PLAIN_NAME:")
        probe.send(b"Ada\rq\r")
        output = probe.finish()
        self.assertIn(b"PLAIN_ANSWER=Ada", output)
        self.assertIn(b"PLAIN_TUI_DONE", output)
        self.assert_terminal_restored(output)
        self.assert_cooked_mode(probe)

    def test_plain_prompt_then_tui_program_share_stdin(self) -> None:
        probe = self._probe("plain-then-tui")
        probe.read_until(b"PLAIN_NAME:")
        probe.send(b"Ada\r")
        probe.read_until(b"PLAIN_TUI_READY")
        self.assertIn(b"PLAIN_ANSWER=Ada", bytes(probe.data))
        probe.send(b"q")
        probe.read_until(b"PLAIN_TUI_DONE")
        self.assert_terminal_restored(probe.finish())
        self.assert_cooked_mode(probe)

    def test_sequential_default_stdin_programs_share_input_and_exit(self) -> None:
        probe = self._probe("default-chain")
        probe.read_until(b"CHAIN_ONE_READY")
        probe.send(b"q")
        probe.read_until(b"CHAIN_TWO_READY")
        probe.send(b"q")
        probe.read_until(b"CHAIN_DONE")
        self.assert_terminal_restored(probe.finish())
        self.assert_cooked_mode(probe)

    def test_signal_keys_arrive_as_key_messages(self) -> None:
        probe = self._probe("default-keys")
        probe.read_until(b"DEFAULT_KEYS_READY")
        probe.send(b"\x1a")
        probe.read_until(b"KEY:ctrl+z")
        probe.send(b"\x03")
        probe.read_until(b"KEY:ctrl+c")
        self.assert_terminal_restored(probe.finish())
        self.assert_cooked_mode(probe)

    def test_ctrl_z_suspend_releases_terminal_and_resumes_raw(self) -> None:
        probe = self._probe("default-suspend")
        probe.read_until(b"DEFAULT_SUSPEND_READY")
        probe.send(b"\x1a")
        probe.wait_for_stop()
        self.assert_terminal_restored(bytes(probe.data))
        self.assert_cooked_mode(probe)
        probe.continue_process()
        probe.read_until(b"RESUMED")
        lflag = termios.tcgetattr(probe.master)[3]
        self.assertFalse(lflag & (termios.ICANON | termios.ISIG))
        probe.send(b"q")
        self.assert_terminal_restored(probe.finish())
        self.assert_cooked_mode(probe)

    def test_exec_child_receives_terminal_input(self) -> None:
        for iteration in range(3):
            with self.subTest(iteration=iteration + 1):
                probe = self._probe("default-exec-chain")
                probe.read_until(b"DEFAULT_EXEC_READY")
                for line in (b"hello", b"world"):
                    release_count = probe.data.count(b"\x1b[?1049l") + 1
                    probe.send(b"x")
                    probe.read_until_count(b"\x1b[?1049l", release_count)
                    self.assert_cooked_mode(probe)
                    child_count = probe.data.count(b"CHILD:") + 1
                    done_count = probe.data.count(b"EXEC_DONE:0") + 1
                    probe.send(line + b"\r")
                    probe.read_until_count(b"CHILD:", child_count)
                    self.assertIn(b"CHILD:" + line, probe.data)
                    probe.read_until_count(b"EXEC_DONE:0", done_count)
                probe.send(b"q")
                probe.read_until(b"EXEC_FIRST_DONE")
                self.assert_cooked_mode(probe)
                probe.read_until(b"EXEC_FOLLOWUP_READY")
                probe.send(b"q")
                self.assert_terminal_restored(probe.finish())
                self.assert_cooked_mode(probe)

    def test_explicit_stdin_exec_child_receives_terminal_input_twice(self) -> None:
        probe = self._probe("explicit-exec")
        probe.read_until(b"EXPLICIT_EXEC_READY")
        for line in (b"hello", b"world"):
            release_count = probe.data.count(b"\x1b[?1049l") + 1
            probe.send(b"x")
            probe.read_until_count(b"\x1b[?1049l", release_count)
            self.assert_cooked_mode(probe)
            child_count = probe.data.count(b"CHILD:") + 1
            done_count = probe.data.count(b"EXPLICIT_EXEC_DONE") + 1
            probe.send(line + b"\r")
            probe.read_until_count(b"CHILD:", child_count)
            self.assertIn(b"CHILD:" + line, probe.data)
            probe.read_until_count(b"EXPLICIT_EXEC_DONE", done_count)
        probe.send(b"q")
        self.assert_terminal_restored(probe.finish())
        self.assert_cooked_mode(probe)

    def test_killed_suspend_run_cannot_suspend_its_replacement(self) -> None:
        probe = self._probe("restart-suspend")
        probe.read_until(b"SECOND_RUN_READY")
        probe.send(b"q")
        self.assert_terminal_restored(probe.finish())
        self.assert_cooked_mode(probe)

    def test_exec_child_input_is_not_taken_by_another_program(self) -> None:
        probe = self._probe("default-exec-concurrent")
        probe.read_until(b"DEFAULT_EXEC_READY")
        time.sleep(0.2)
        probe.send(b"x")
        probe.read_until(b"\x1b[?1049l")
        probe.send(b"hello\r")
        probe.read_until(b"CHILD:")
        self.assertIn(b"CHILD:hello", probe.data)
        probe.read_until(b"EXEC_DONE:0")
        probe.send(b"q")
        probe.read_until(b"CONCURRENT_EXEC_DONE")
        self.assert_terminal_restored(probe.finish())
        self.assert_cooked_mode(probe)

    def test_init_command_exec_waits_for_stdin_control_startup(self) -> None:
        probe = self._probe("default-init-exec")
        probe.read_until(b"INIT_EXEC_CHILD")
        self.assert_terminal_restored(probe.finish())
        self.assert_cooked_mode(probe)

    def test_init_exec_child_does_not_read_query_replies(self) -> None:
        probe = self._probe("default-init-exec-reads")
        # Answer the startup queries the way a slower terminal (or one over
        # SSH) does: after the program has already started its child.
        probe.read_until(b"\x1b]11;?\x07")
        time.sleep(0.1)
        probe.send(
            b"\x1b[?2026;2$y\x1b[?2027;0$y"
            b"\x1b]11;rgb:0000/0000/0000\x1b\\"
        )
        probe.read_until(b"CHILD_GOT:")
        line = bytes(probe.data).split(b"CHILD_GOT:", 1)[1].split(b"\r", 1)[0]
        self.assertEqual(line.strip(), b"")
        self.assert_terminal_restored(probe.finish())
        self.assert_cooked_mode(probe)

    def test_unrelated_mode_report_does_not_replace_background_reply(self) -> None:
        probe = self._probe("default-init-exec-reads")
        probe.read_until(b"\x1b]11;?\x07")
        probe.send(b"\x1b[?2026;2$y\x1b[?2027;0$y\x1b[?11;2$y")
        time.sleep(0.1)
        probe.send(b"\x1b]11;rgb:0000/0000/0000\x1b\\")
        probe.read_until(b"CHILD_GOT:")
        line = bytes(probe.data).split(b"CHILD_GOT:", 1)[1].split(b"\r", 1)[0]
        self.assertEqual(line.strip(), b"")
        self.assert_terminal_restored(probe.finish())
        self.assert_cooked_mode(probe)

    def test_init_exec_consumes_bel_and_fragmented_startup_replies(self) -> None:
        for terminator in (b"\x07", b"\x1b\\"):
            with self.subTest(terminator=terminator):
                probe = self._probe("default-init-exec-reads")
                probe.read_until(b"\x1b]11;?\x07")
                for chunk in (
                    b"\x1b[?2026;",
                    b"2$y\x1b[?2027;0$y\x1b]11;rgb:0000/",
                    b"0000/0000" + terminator[:1],
                    terminator[1:],
                ):
                    if chunk:
                        probe.send(chunk)
                        time.sleep(0.02)
                probe.read_until(b"CHILD_GOT:")
                line = bytes(probe.data).split(b"CHILD_GOT:", 1)[1].split(b"\r", 1)[0]
                self.assertEqual(line.strip(), b"")
                self.assert_terminal_restored(probe.finish())
                self.assert_cooked_mode(probe)

    def test_partial_query_reply_wait_times_out_only_once(self) -> None:
        probe = self._probe("default-exec-chain")
        probe.read_until(b"DEFAULT_EXEC_READY")
        probe.send(b"\x1b[?2026;2$y")
        started = time.monotonic()
        probe.send(b"x")
        probe.read_until_count(b"\x1b[?1049l", 1)
        self.assertLess(time.monotonic() - started, 1.5)
        probe.send(b"hello\r")
        probe.read_until(b"EXEC_DONE:0")
        started = time.monotonic()
        probe.send(b"x")
        probe.read_until_count(b"\x1b[?1049l", 2)
        self.assertLess(time.monotonic() - started, 0.2)
        probe.send(b"world\r")
        probe.read_until_count(b"EXEC_DONE:0", 2)
        probe.send(b"q")
        probe.read_until(b"EXEC_FOLLOWUP_READY")
        probe.send(b"q")
        self.assert_terminal_restored(probe.finish())
        self.assert_cooked_mode(probe)

    def test_sigterm_quits_and_restores_terminal(self) -> None:
        probe = self._probe("default-term")
        probe.read_until(b"DEFAULT_TERM_READY")
        os.kill(probe.pid, signal.SIGTERM)
        self.assert_terminal_restored(probe.finish())
        self.assert_cooked_mode(probe)


class PlainPipeTest(unittest.TestCase):
    """Helpers work without a terminal: piped stdin and stdout."""

    def _run(self, script: str, stdin: bytes) -> str:
        result = subprocess.run(
            ["dart", "run", script],
            cwd=ROOT, input=stdin, capture_output=True, timeout=120,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn(b"\x1b", result.stdout)
        return result.stdout.decode()

    def test_prompts_chain_answers_from_a_pipe(self) -> None:
        out = self._run("example/prompts_chain.dart", b"2\ny\nAkshay\n")
        self.assertIn("1. Vanilla\n2. Chocolate\n3. Strawberry\n", out)
        self.assertIn("Enter a number: 2\nSelected: Chocolate", out)
        self.assertIn("Confirmed: true", out)
        self.assertIn("Notes: Akshay", out)

    def test_end_of_input_cancels_without_hanging(self) -> None:
        out = self._run("example/prompts_chain.dart", b"")
        self.assertIn("flavor = null", out)
        self.assertIn("confirmed = null", out)
        self.assertIn("notes = null", out)

    def test_form_answers_from_a_pipe(self) -> None:
        out = self._run("example/form.dart", b"billing-api\n2\n\n1,3\n")
        self.assertIn("name    = billing-api", out)
        self.assertIn("runtime = Go", out)
        self.assertIn("deploy  = true", out)
        self.assertIn("regions = [iad, sfo]", out)


class _Tmux:
    """A detached tmux pane: a real terminal emulator with scrollback."""

    def __init__(self, command: str, rows: int = 24, columns: int = 80):
        self.socket = f"dart_tui_test_{os.getpid()}_{time.monotonic_ns()}"
        self._tmux(
            "new-session", "-d", "-s", "t", "-x", str(columns), "-y", str(rows),
            f"cd {shlex.quote(str(ROOT))} && {command}; sleep 60",
        )
        self._tmux("set-option", "-t", "t", "history-limit", "5000")

    def _tmux(self, *args: str) -> str:
        return subprocess.run(
            ["tmux", "-L", self.socket, *args],
            check=True, capture_output=True, text=True,
        ).stdout

    def history(self) -> list[str]:
        """Every line in scrollback and on screen, top to bottom."""
        text = self._tmux("capture-pane", "-p", "-S", "-", "-t", "t")
        return [line.rstrip() for line in text.splitlines()]

    def wait_for(self, marker: str, count: int = 1) -> list[str]:
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            lines = self.history()
            if sum(marker in line for line in lines) >= count:
                return lines
            time.sleep(0.1)
        raise AssertionError(
            f"missing {marker!r} x{count}; pane=\n" + "\n".join(self.history())
        )

    def keys(self, keys: str) -> None:
        for key in keys:
            self._tmux("send-keys", "-t", "t", "-l", key)
            time.sleep(0.15)

    def close(self) -> None:
        subprocess.run(
            ["tmux", "-L", self.socket, "kill-server"], capture_output=True
        )


@unittest.skipUnless(shutil.which("tmux"), "tmux is not installed")
class InlineRenderingTmuxTest(unittest.TestCase):
    """Inline frames keep the shell history above them (#18)."""

    def _run(self, scenario: str) -> _Tmux:
        command = (
            "printf 'MARK_1\\nMARK_2\\nMARK_3\\n'; "
            f"dart run {shlex.quote(str(PROBE))} {scenario}; echo AFTER_MARK"
        )
        pane = _Tmux(command)
        self.addCleanup(pane.close)
        return pane

    def _index(self, lines: list[str], marker: str) -> int:
        found = [i for i, line in enumerate(lines) if marker in line]
        self.assertEqual(len(found), 1, f"{marker!r} not once in {lines!r}")
        return found[0]

    def test_inline_program_keeps_history_and_ends_above_the_prompt(self) -> None:
        for scenario in ("inline", "inline-cell"):
            with self.subTest(scenario=scenario):
                pane = self._run(scenario)
                pane.wait_for("INLINE_LAST rows=2")
                pane.keys("g")
                pane.wait_for("INLINE_LAST rows=5")
                pane.keys("p")
                pane.wait_for("INLINE_PRINTED")
                pane.keys("s")
                pane.wait_for("INLINE_LAST rows=2")
                pane.keys("q")
                lines = pane.wait_for("AFTER_MARK")
                marks = [self._index(lines, f"MARK_{n}") for n in (1, 2, 3)]
                printed = self._index(lines, "INLINE_PRINTED")
                top = self._index(lines, "INLINE_TOP rows=2")
                last = self._index(lines, "INLINE_LAST rows=2")
                after = self._index(lines, "AFTER_MARK")
                self.assertEqual(marks, sorted(marks))
                self.assertEqual(marks[2] + 1, printed, lines)
                self.assertEqual(printed + 1, top, lines)
                self.assertEqual(top + 1, last, lines)
                self.assertEqual(last + 1, after, lines)
                # The rows the frame shrank away from were erased.
                self.assertFalse(any("INLINE_ROW_" in line for line in lines))

    def test_clear_resize_and_exec_preserve_inline_history(self) -> None:
        for scenario in ("inline-lifecycle", "inline-lifecycle-cell"):
            with self.subTest(scenario=scenario):
                pane = self._run(scenario)
                pane.wait_for("LIFECYCLE_LAST v0")
                pane.keys("c")
                pane.wait_for("LIFECYCLE_LAST v1")
                pane._tmux("resize-window", "-t", "t", "-x", "90", "-y", "28")
                time.sleep(0.3)
                pane.keys("x")
                pane.wait_for("LIFECYCLE_LAST v2")
                pane.keys("q")
                lines = pane.wait_for("AFTER_MARK")
                expected = [
                    "MARK_1", "MARK_2", "MARK_3", "INLINE_CHILD",
                    "LIFECYCLE_TOP v2", "LIFECYCLE_LAST v2", "AFTER_MARK",
                ]
                found = [self._index(lines, marker) for marker in expected]
                self.assertEqual(
                    found, list(range(found[0], found[0] + len(found))), lines
                )

    def test_exec_from_alt_screen_keeps_shell_history(self) -> None:
        for scenario in ("inline-lifecycle", "inline-lifecycle-cell"):
            with self.subTest(scenario=scenario):
                pane = self._run(scenario)
                pane.wait_for("LIFECYCLE_LAST v0")
                pane.keys("a")
                pane.wait_for("LIFECYCLE_LAST v1")
                pane.keys("x")
                pane.wait_for("LIFECYCLE_LAST v2")
                pane.keys("a")
                pane.wait_for("LIFECYCLE_LAST v3")
                pane.keys("q")
                lines = pane.wait_for("AFTER_MARK")
                expected = [
                    "MARK_1", "MARK_2", "MARK_3", "INLINE_CHILD",
                    "LIFECYCLE_TOP v3", "LIFECYCLE_LAST v3", "AFTER_MARK",
                ]
                found = [self._index(lines, marker) for marker in expected]
                self.assertEqual(
                    found, list(range(found[0], found[0] + len(found))), lines
                )

    def test_quit_in_alt_screen_after_inline_frame_parks_below_frame(self) -> None:
        for scenario in ("inline-lifecycle", "inline-lifecycle-cell"):
            with self.subTest(scenario=scenario):
                pane = self._run(scenario)
                pane.wait_for("LIFECYCLE_LAST v0")
                pane.keys("a")
                pane.wait_for("LIFECYCLE_LAST v1")
                pane.keys("q")
                lines = pane.wait_for("AFTER_MARK")
                last = self._index(lines, "LIFECYCLE_LAST v0")
                self.assertEqual(self._index(lines, "AFTER_MARK"), last + 1, lines)
                for n in (1, 2, 3):
                    self._index(lines, f"MARK_{n}")

    def test_tall_frame_redraws_do_not_flood_scrollback(self) -> None:
        for scenario in ("inline", "inline-cell"):
            with self.subTest(scenario=scenario):
                pane = self._run(scenario)
                pane.wait_for("INLINE_LAST rows=2")
                for redraw in (1, 2, 3):
                    pane.keys("t")
                    pane.wait_for(f"INLINE_ROW_38 v{redraw}")
                pane.keys("q")
                lines = pane.wait_for("AFTER_MARK")
                # 40 rows in a 24-row pane: only the last 24 are ever drawn,
                # and each redraw rewrites them in place.
                self.assertFalse(any("INLINE_ROW_01 " in line for line in lines))
                self.assertEqual(
                    sum("INLINE_ROW_38" in line for line in lines), 1, lines
                )
                self.assertEqual(
                    sum("INLINE_LAST rows=40" in line for line in lines), 1
                )
                for n in (1, 2, 3):
                    self._index(lines, f"MARK_{n}")

    def test_sequential_programs_start_below_each_other(self) -> None:
        for scenario in ("inline-chain", "inline-chain-cell"):
            with self.subTest(scenario=scenario):
                pane = self._run(scenario)
                pane.wait_for("FIRST_LAST")
                pane.keys("q")
                pane.wait_for("SECOND_LAST")
                pane.keys("q")
                lines = pane.wait_for("AFTER_MARK")
                expected = [
                    "MARK_1", "MARK_2", "MARK_3",
                    "FIRST_TOP", "FIRST_LAST",
                    "SECOND_TOP", "SECOND_LAST",
                    "AFTER_MARK",
                ]
                found = [self._index(lines, marker) for marker in expected]
                self.assertEqual(
                    found, list(range(found[0], found[0] + len(found))), lines
                )


if __name__ == "__main__":
    if os.name != "posix":
        raise SystemExit("PTY runtime tests require a Unix host")
    unittest.main(verbosity=2)
