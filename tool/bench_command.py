#!/usr/bin/env python3
"""Benchmark command startup: time-to-first-visible-output and total runtime."""

from __future__ import annotations

import argparse
import json
import math
import os
import pty
import select
import statistics
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from typing import Any


ESC = "\x1b"


def strip_ansi_sequences(text: str) -> str:
    """Strip common ANSI escape sequences from text."""
    out: list[str] = []
    i = 0
    n = len(text)

    while i < n:
        ch = text[i]
        if ch != ESC:
            out.append(ch)
            i += 1
            continue

        # ESC ... sequence
        if i + 1 >= n:
            i += 1
            continue

        nxt = text[i + 1]
        i += 2

        # CSI: ESC [ ... final-byte(0x40-0x7E)
        if nxt == "[":
            while i < n:
                c = ord(text[i])
                i += 1
                if 0x40 <= c <= 0x7E:
                    break
            continue

        # OSC: ESC ] ... (BEL or ST)
        if nxt == "]":
            while i < n:
                c = text[i]
                if c == "\x07":
                    i += 1
                    break
                if c == ESC and i + 1 < n and text[i + 1] == "\\":
                    i += 2
                    break
                i += 1
            continue

        # DCS/PM/APC: ESC P/^/_ ... ST
        if nxt in {"P", "^", "_"}:
            while i < n:
                c = text[i]
                if c == ESC and i + 1 < n and text[i + 1] == "\\":
                    i += 2
                    break
                i += 1
            continue

        # Single-char escape sequence: skip

    return "".join(out)


def first_visible_char(text: str) -> str | None:
    cleaned = strip_ansi_sequences(text)
    for ch in cleaned:
        if ch.isprintable() and not ch.isspace():
            return ch
    return None


@dataclass
class RunResult:
    run: int
    exit_code: int
    timed_out: bool
    first_visible_ms: float | None
    total_ms: float


def _quantile(values: list[float], q: float) -> float:
    if not values:
        return math.nan
    if len(values) == 1:
        return values[0]
    sorted_vals = sorted(values)
    pos = (len(sorted_vals) - 1) * q
    lo = int(math.floor(pos))
    hi = int(math.ceil(pos))
    if lo == hi:
        return sorted_vals[lo]
    frac = pos - lo
    return sorted_vals[lo] * (1 - frac) + sorted_vals[hi] * frac


def _summary(values: list[float]) -> dict[str, float | None]:
    if not values:
        return {"min": None, "median": None, "mean": None, "p95": None}
    return {
        "min": min(values),
        "median": statistics.median(values),
        "mean": statistics.fmean(values),
        "p95": _quantile(values, 0.95),
    }


def run_once(command: list[str], timeout_s: float, passthrough: bool, run: int) -> RunResult:
    master_fd, slave_fd = pty.openpty()
    proc = subprocess.Popen(
        command,
        stdin=slave_fd,
        stdout=slave_fd,
        stderr=slave_fd,
        close_fds=True,
    )
    os.close(slave_fd)

    start_ns = time.perf_counter_ns()
    first_visible_ns: int | None = None
    text_buf: list[str] = []
    exit_code: int | None = None
    timed_out = False

    try:
        while True:
            now_ns = time.perf_counter_ns()
            elapsed_s = (now_ns - start_ns) / 1_000_000_000
            if elapsed_s > timeout_s:
                timed_out = True
                proc.kill()
                try:
                    proc.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    pass
                exit_code = 124
                break

            ready, _, _ = select.select([master_fd], [], [], 0.05)
            if ready:
                try:
                    chunk = os.read(master_fd, 4096)
                except OSError:
                    chunk = b""
                if chunk:
                    decoded = chunk.decode("utf-8", errors="replace")
                    text_buf.append(decoded)
                    if passthrough:
                        sys.stdout.write(decoded)
                        sys.stdout.flush()
                    if first_visible_ns is None:
                        if first_visible_char("".join(text_buf)) is not None:
                            first_visible_ns = time.perf_counter_ns()

            polled = proc.poll()
            if polled is not None:
                exit_code = polled
                break

        if exit_code is None:
            exit_code = proc.wait(timeout=1)
    finally:
        try:
            os.close(master_fd)
        except OSError:
            pass

    end_ns = time.perf_counter_ns()
    return RunResult(
        run=run,
        exit_code=exit_code,
        timed_out=timed_out,
        first_visible_ms=None
        if first_visible_ns is None
        else (first_visible_ns - start_ns) / 1_000_000,
        total_ms=(end_ns - start_ns) / 1_000_000,
    )


def _fmt_ms(value: float | None) -> str:
    return "-" if value is None else f"{value:.2f}"


def print_report(results: list[RunResult], warmup: int) -> None:
    measured = results[warmup:]
    first_values = [r.first_visible_ms for r in measured if r.first_visible_ms is not None]
    total_values = [r.total_ms for r in measured]

    first_summary = _summary(first_values)
    total_summary = _summary(total_values)

    print("\nPer-run timings (ms)")
    print("run  first_visible  total_runtime  exit  timed_out")
    for r in results:
        print(
            f"{r.run:>3}  {_fmt_ms(r.first_visible_ms):>13}  {r.total_ms:>12.2f}  {r.exit_code:>4}  {str(r.timed_out):>9}"
        )

    print("\nSummary (excluding warmups)")
    print(f"warmup_runs: {warmup}")
    print(
        "first_visible_ms: "
        f"min={_fmt_ms(first_summary['min'])} "
        f"median={_fmt_ms(first_summary['median'])} "
        f"mean={_fmt_ms(first_summary['mean'])} "
        f"p95={_fmt_ms(first_summary['p95'])}"
    )
    print(
        "total_runtime_ms: "
        f"min={_fmt_ms(total_summary['min'])} "
        f"median={_fmt_ms(total_summary['median'])} "
        f"mean={_fmt_ms(total_summary['mean'])} "
        f"p95={_fmt_ms(total_summary['p95'])}"
    )


def build_json_payload(
    command: list[str],
    timeout_s: float,
    warmup: int,
    results: list[RunResult],
) -> dict[str, Any]:
    measured = results[warmup:]
    first_values = [r.first_visible_ms for r in measured if r.first_visible_ms is not None]
    total_values = [r.total_ms for r in measured]

    return {
        "metadata": {
            "command": command,
            "runs": len(results),
            "warmup_runs": warmup,
            "timeout_seconds": timeout_s,
            "timestamp_utc": datetime.now(tz=timezone.utc).isoformat(),
        },
        "per_run": [asdict(r) for r in results],
        "summary": {
            "first_visible_ms": _summary(first_values),
            "total_runtime_ms": _summary(total_values),
            "first_visible_missing_count": len(measured) - len(first_values),
        },
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Benchmark a command in a PTY and report time-to-first-visible-output "
            "and total runtime."
        )
    )
    parser.add_argument("-n", "--runs", type=int, default=5, help="Number of runs.")
    parser.add_argument(
        "--warmup",
        type=int,
        default=1,
        help="Warmup runs to exclude from summary stats.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=60.0,
        help="Timeout per run in seconds.",
    )
    parser.add_argument(
        "--json-out",
        type=str,
        help="Optional path to write JSON report.",
    )
    parser.add_argument(
        "--passthrough",
        action="store_true",
        help="Stream child output while benchmarking.",
    )
    parser.add_argument(
        "command",
        nargs=argparse.REMAINDER,
        help="Command to run. Use -- before command.",
    )

    ns = parser.parse_args(argv)
    if ns.command and ns.command[0] == "--":
        ns.command = ns.command[1:]
    if not ns.command:
        parser.error("No command provided. Example: bench_command.py -- fvm dart run example/showcase.dart")
    if ns.runs <= 0:
        parser.error("--runs must be > 0")
    if ns.warmup < 0:
        parser.error("--warmup must be >= 0")
    if ns.warmup >= ns.runs:
        parser.error("--warmup must be less than --runs")
    if ns.timeout <= 0:
        parser.error("--timeout must be > 0")
    return ns


def main(argv: list[str] | None = None) -> int:
    ns = parse_args(sys.argv[1:] if argv is None else argv)

    print(f"Benchmarking: {' '.join(ns.command)}")
    print(
        f"runs={ns.runs} warmup={ns.warmup} timeout={ns.timeout}s passthrough={ns.passthrough}"
    )

    results: list[RunResult] = []
    for run in range(1, ns.runs + 1):
        result = run_once(ns.command, ns.timeout, ns.passthrough, run)
        results.append(result)

    print_report(results, ns.warmup)

    if ns.json_out:
        payload = build_json_payload(
            command=ns.command,
            timeout_s=ns.timeout,
            warmup=ns.warmup,
            results=results,
        )
        with open(ns.json_out, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2)
        print(f"\nWrote JSON report: {ns.json_out}")

    # Return non-zero if any measured run failed.
    measured = results[ns.warmup :]
    if any(r.exit_code != 0 for r in measured):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
