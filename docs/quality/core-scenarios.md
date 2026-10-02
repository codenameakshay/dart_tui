# Core command and input scenarios

Run the focused verification from the package root:

```sh
dart test test/cmd_test.dart test/cmd_alias_test.dart test/key_buffer_parser_test.dart
dart analyze lib/src/cmd.dart lib/src/program.dart lib/src/key_buffer_parser.dart lib/src/printf_format.dart
dart run tool/core_parser_bench.dart
```

Expected behavior:

- `every` rejects zero and negative intervals immediately with `ArgumentError`.
- `tick` and `tickWithId` reject negative delays immediately; a zero delay remains an immediate asynchronous tick.
- The public `printf` command helper and `Program.printf` share the package's `%s` substitution implementation.
- The parser emits one key event per UTF-8 scalar, waits without consuming an incomplete scalar, and consumes malformed input one byte at a time so invalid bytes cannot stall later keys.

The streaming-decoder benchmark processes the mixed ASCII/Unicode input 100,000 times. On the same worktree and runtime, the pre-change parser took 755,876 μs for 500,000 emitted events; the scalar-sized parser took 260,009 μs for 1,100,000 events. This is a simple throughput check, not a stable performance threshold.

The automated tests above exercise these cases directly; this note records the command and contract for maintainers without duplicating their assertions.
