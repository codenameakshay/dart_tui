// ignore_for_file: avoid_print

/// Wall-clock startup latency benchmark for dart_tui examples.
///
/// Measures time from process start → first byte on stdout (i.e., first
/// rendered frame). Each example is run twice to show cold (first JIT
/// compile) vs warm (cached kernel) times.
///
/// Usage:
///   fvm dart run tool/startup_bench.dart example/simple.dart        # JIT (source)
///   fvm dart run tool/startup_bench.dart --dill tool/bin/simple.dill # kernel snapshot
///   fvm dart run tool/startup_bench.dart --aot example/simple.dart   # AOT (native exe)
///   fvm dart run tool/startup_bench.dart --all                        # all examples (JIT)
///
/// Build kernel snapshots first with:
///   bash tool/build.sh --kernel example/simple.dart
library;

import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _usage();
    exit(1);
  }

  final isAot = args.contains('--aot');
  final isDill = args.contains('--dill');
  final allExamples = args.contains('--all');
  final filteredArgs =
      args.where((a) => a != '--aot' && a != '--dill' && a != '--all').toList();

  if (allExamples) {
    await _benchAll(aot: isAot, dill: isDill);
  } else if (filteredArgs.isNotEmpty) {
    await _benchOne(
      filteredArgs.first,
      aot: isAot,
      dill: isDill,
      runs: 3,
      printHeader: true,
    );
  } else {
    _usage();
    exit(1);
  }
}

void _usage() {
  print('usage:');
  print('  fvm dart run tool/startup_bench.dart example/simple.dart');
  print('  fvm dart run tool/startup_bench.dart --dill tool/bin/simple.dill');
  print('  fvm dart run tool/startup_bench.dart --aot example/simple.dart');
  print('  fvm dart run tool/startup_bench.dart --all');
}

Future<void> _benchAll({bool aot = false, bool dill = false}) async {
  final examples = Directory('example')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.path)
      .toList()
    ..sort();

  const nameWidth = 30;
  const msWidth = 10;
  final header =
      '${'example'.padRight(nameWidth)}  ${'run1 (ms)'.padLeft(msWidth)}  ${'run2 (ms)'.padLeft(msWidth)}  ${'run3 (ms)'.padLeft(msWidth)}';
  print(header);
  print('-' * header.length);

  for (final path in examples) {
    await _benchOne(path, aot: aot, dill: dill, runs: 3, printHeader: false);
  }
}

Future<void> _benchOne(
  String path, {
  required bool aot,
  required bool dill,
  required int runs,
  required bool printHeader,
}) async {
  final name = dill
      ? path.replaceFirst('tool/bin/', '').replaceFirst('.dill', '')
      : path.replaceFirst('example/', '').replaceFirst('.dart', '');

  if (printHeader) {
    final mode = dill
        ? 'kernel snapshot'
        : aot
            ? 'AOT'
            : 'JIT source';
    print('Benchmarking: $path  [$mode]');
    print('');
  }

  final results = <int>[];
  for (var i = 0; i < runs; i++) {
    final ms = await _measureStartup(path, aot: aot, dill: dill);
    results.add(ms);
  }

  if (printHeader) {
    for (var i = 0; i < results.length; i++) {
      print('  run ${i + 1}: ${results[i]} ms');
    }
    final median = _median(results);
    print('  median : $median ms');
  } else {
    const nameWidth = 30;
    const msWidth = 10;
    final cols = results.map((r) => r.toString().padLeft(msWidth)).join('  ');
    print('${name.padRight(nameWidth)}  $cols');
  }
}

/// Starts the example process, waits for first stdout byte, and returns the
/// elapsed milliseconds. Sends Ctrl-C after receiving the first byte so the
/// process doesn't linger.
Future<int> _measureStartup(
  String path, {
  bool aot = false,
  bool dill = false,
}) async {
  List<String> command;
  if (aot) {
    final name = path.replaceFirst('example/', '').replaceFirst('.dart', '');
    command = ['tool/bin/$name'];
  } else if (dill) {
    command = ['fvm', 'dart', 'run', path];
  } else {
    command = ['fvm', 'dart', 'run', path];
  }

  final sw = Stopwatch()..start();
  Process proc;
  try {
    proc = await Process.start(
      command.first,
      command.skip(1).toList(),
      environment: {
        ...Platform.environment,
        // Suppress in-process bench output during wall-clock measurement.
        'DART_TUI_BENCH': '0',
        // Provide a fake terminal size so programs that query it don't block.
        'COLUMNS': '80',
        'LINES': '24',
      },
    );
  } catch (e) {
    stderr.writeln('Failed to start $path: $e');
    return -1;
  }

  int elapsed = -1;

  // Wait for the first byte on stdout (first rendered frame).
  await for (final _ in proc.stdout) {
    sw.stop();
    elapsed = sw.elapsedMilliseconds;
    break;
  }

  // Terminate the process.
  proc.kill(ProcessSignal.sigterm);
  await proc.exitCode.timeout(
    const Duration(seconds: 2),
    onTimeout: () {
      proc.kill(ProcessSignal.sigkill);
      return -1;
    },
  );

  return elapsed;
}

int _median(List<int> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid];
  return ((sorted[mid - 1] + sorted[mid]) / 2).round();
}
