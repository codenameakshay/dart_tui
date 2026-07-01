import 'dart:io';

/// Appends timestamped diagnostic lines to a file.
///
/// A running [Program] owns stdout, so `print()` corrupts the rendered UI.
/// Write debug output here instead and `tail -f` the file in another terminal:
///
/// ```dart
/// final log = FileLog('debug.log');
/// log('got message: $msg');
/// // on shutdown:
/// await log.close();
/// ```
///
/// Use [FileLog.none] to obtain a logger that silently discards everything
/// (handy for toggling logging off without sprinkling null checks).
final class FileLog {
  /// Open [path] for appending. Timestamps use [clock] (defaults to
  /// [DateTime.now]); inject a fixed clock in tests for deterministic output.
  FileLog(String path, {DateTime Function()? clock})
      : _sink = File(path).openWrite(mode: FileMode.append),
        _clock = clock ?? DateTime.now;

  FileLog._none()
      : _sink = null,
        _clock = DateTime.now;

  /// A logger that discards every message.
  factory FileLog.none() = FileLog._none;

  final IOSink? _sink;
  final DateTime Function() _clock;

  /// Write [message] as a single timestamped line.
  void call(Object? message) {
    _sink?.writeln('[${_clock().toIso8601String()}] $message');
  }

  /// Flush and close the underlying file.
  Future<void> close() async {
    await _sink?.flush();
    await _sink?.close();
  }
}
