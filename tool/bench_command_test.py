#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import pathlib
import sys
import unittest


ROOT = pathlib.Path(__file__).resolve().parent
SCRIPT = ROOT / "bench_command.py"

spec = importlib.util.spec_from_file_location("bench_command", SCRIPT)
assert spec and spec.loader
bench_command = importlib.util.module_from_spec(spec)
sys.modules["bench_command"] = bench_command
spec.loader.exec_module(bench_command)


class BenchCommandTest(unittest.TestCase):
    def test_strip_ansi_sequences_removes_csi_and_osc(self) -> None:
        raw = "\x1b[31mhello\x1b[0m\x1b]0;title\x07 world"
        self.assertEqual(bench_command.strip_ansi_sequences(raw), "hello world")

    def test_first_visible_char_ignores_whitespace_and_controls(self) -> None:
        raw = "\x1b[2J\x1b[H   \n\t\x1b[32mX"
        self.assertEqual(bench_command.first_visible_char(raw), "X")

    def test_run_once_detects_delayed_output(self) -> None:
        cmd = [
            sys.executable,
            "-c",
            "import time; time.sleep(0.15); print('ready', flush=True)",
        ]
        result = bench_command.run_once(cmd, timeout_s=3.0, passthrough=False, run=1)
        self.assertEqual(result.exit_code, 0)
        self.assertIsNotNone(result.first_visible_ms)
        assert result.first_visible_ms is not None
        self.assertGreaterEqual(result.first_visible_ms, 100.0)

    def test_run_once_detects_stderr_visible_output(self) -> None:
        cmd = [
            sys.executable,
            "-c",
            "import sys,time; time.sleep(0.05); sys.stderr.write('err\\n'); sys.stderr.flush()",
        ]
        result = bench_command.run_once(cmd, timeout_s=3.0, passthrough=False, run=1)
        self.assertEqual(result.exit_code, 0)
        self.assertIsNotNone(result.first_visible_ms)

    def test_run_once_reports_none_when_no_visible_output(self) -> None:
        cmd = [sys.executable, "-c", "import time; time.sleep(0.05)"]
        result = bench_command.run_once(cmd, timeout_s=3.0, passthrough=False, run=1)
        self.assertEqual(result.exit_code, 0)
        self.assertIsNone(result.first_visible_ms)

    def test_run_once_times_out(self) -> None:
        cmd = [sys.executable, "-c", "import time; time.sleep(1.5)"]
        result = bench_command.run_once(cmd, timeout_s=0.2, passthrough=False, run=1)
        self.assertEqual(result.exit_code, 124)
        self.assertTrue(result.timed_out)


if __name__ == "__main__":
    unittest.main()
