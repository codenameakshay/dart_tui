#!/usr/bin/env python3
"""Terminal detection against real Unix file descriptors."""

import fcntl
import json
import os
from pathlib import Path
import pty
import struct
import subprocess
import tempfile
import termios
import unittest
from contextlib import ExitStack

ROOT = Path(__file__).resolve().parents[1]
PROBE = ROOT / 'tool' / 'terminal_detect_probe.dart'


class TerminalDetectTest(unittest.TestCase):
    def run_probe(self, target, override='native', pipe_stdin=False):
        master, slave = pty.openpty()
        try:
            size = (0, 0) if target == 'zero-pty' else (24, 80)
            fcntl.ioctl(slave, termios.TIOCSWINSZ,
                        struct.pack('HHHH', *size, 0, 0))
            with ExitStack() as stack:
                output = {
                    'zero-pty': slave,
                    'pty': slave,
                    'pipe': subprocess.PIPE,
                    'file': stack.enter_context(tempfile.TemporaryFile()),
                    'null': stack.enter_context(open(os.devnull, 'wb')),
                }[target]
                result = subprocess.run(
                    ['dart', 'run', str(PROBE), override], cwd=ROOT,
                    stdin=subprocess.PIPE if pipe_stdin else slave,
                    stdout=output, stderr=subprocess.PIPE, timeout=15,
                )
                self.assertEqual(result.returncode, 0, result.stderr.decode())
                return json.loads(result.stderr)
        finally:
            os.close(master)
            os.close(slave)

    def test_stdout_detection_and_color_matrix(self):
        for target in ('zero-pty', 'pty', 'pipe', 'file', 'null'):
            with self.subTest(stdout=target):
                result = self.run_probe(target)
                terminal = target in ('zero-pty', 'pty')
                self.assertEqual(result['stdoutIsTerminal'], terminal, result)
                self.assertEqual(result['hasTerminal'], target == 'pty', result)
                self.assertEqual(result['profile'],
                                 'ansi256' if terminal else 'noColor', result)
                self.assertEqual(result['plain'], not terminal, result)

    def test_overrides_do_not_confuse_native_and_fake_stdout(self):
        for target in ('zero-pty', 'pipe'):
            for override in ('unrelated', 'fake-true', 'fake-false'):
                with self.subTest(stdout=target, override=override):
                    result = self.run_probe(target, override)
                    terminal = (target == 'zero-pty' if override == 'unrelated'
                                else override == 'fake-true')
                    self.assertEqual(result['stdoutIsTerminal'], terminal, result)
                    self.assertEqual(result['profile'],
                                     'ansi256' if terminal else 'noColor', result)

    def test_pipe_stdin_keeps_helpers_plain(self):
        result = self.run_probe('pty', pipe_stdin=True)
        self.assertTrue(result['stdoutIsTerminal'], result)
        self.assertTrue(result['plain'], result)


if __name__ == '__main__':
    unittest.main(verbosity=2)
