// ignore_for_file: avoid_print

/// Wall-clock startup latency benchmark for dart_tui examples.
///
/// Measures time from process start → first byte on stdout (i.e., first
/// rendered frame). Each example is run twice to show cold (first JIT
/// compile) vs warm (cached kernel) times.
///
/// Usage:
///   fvm dart run tool/startup_bench.dart example/simple.dart
///   fvm dart run tool/startup_bench.dart --all
///   fvm dart run tool/startup_bench.dart --aot example/simple.dart
///
/// The --aot flag assumes the example has already been compiled with:
///   fvm dart compile exe example/simple.dart -o tool/bin/simple
library;

import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _usage();
    exit(1);
  }

  final isAot = args.contains('--aot');
  final allExamples = args.contains('--all');
  final filteredArgs = args.where((a) => a != '--aot' && a != '--all').toList();

  if (allExamples) {
    await _benchAll(aot: isAot);
  } else if (filteredArgs.isNotEmpty) {
    await _benchOne(filteredArgs.first, aot: isAot, runs: 2, printHeader: true);
  } else {
    _usage();
    exit(1);
  }
}

void _usage() {
  print('usage:');
  print('  fvm dart run tool/startup_bench.dart example/simple.dart');
  print('  fvm dart run tool/startup_bench.dart --all');
  print('  fvm dart run tool/startup_bench.dart --aot example/simple.dart');
}

Future<void> _benchAll({bool aot = false}) async {
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
      '${'example'.padRight(nameWidth)}  ${'cold (ms)'.padLeft(msWidth)}  ${'warm (ms)'.padLeft(msWidth)}';
  print(header);
  print('-' * header.length);

  for (final path in examples) {
    await _benchOne(path, aot: aot, runs: 2, printHeader: false);
  }
}

Future<void> _benchOne(
  String path, {
  required bool aot,
  required int runs,
  required bool printHeader,
}) async {
  final name = path.replaceFirst('example/', '').replaceFirst('.dart', '');

  if (printHeader) {
    print('Benchmarking: $path');
    print('');
  }

  final results = <int>[];
  for (var i = 0; i < runs; i++) {
    final ms = await _measureStartup(path, aot: aot);
    results.add(ms);
  }

  if (printHeader) {
    print('  cold run : ${results[0]} ms');
    if (results.length > 1) print('  warm run : ${results[1]} ms');
  } else {
    const nameWidth = 30;
    const msWidth = 10;
    final cold = results[0].toString().padLeft(msWidth);
    final warm = results.length > 1 ? results[1].toString().padLeft(msWidth) : '         -';
    print('${name.padRight(nameWidth)}  $cold  $warm');
  }
}

/// Starts the example process, waits for first stdout byte, and returns the
/// elapsed milliseconds. Sends Ctrl-C after receiving the first byte so the
/// process doesn't linger.
Future<int> _measureStartup(String dartFile, {bool aot = false}) async {
  List<String> command;
  if (aot) {
    final name = dartFile
        .replaceFirst('example/', '')
        .replaceFirst('.dart', '');
    command = ['tool/bin/$name'];
  } else {
    command = ['fvm', 'dart', 'run', dartFile];
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
    stderr.writeln('Failed to start $dartFile: $e');
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
