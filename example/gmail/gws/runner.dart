import 'dart:async';
import 'dart:convert';
import 'dart:io';

class GwsException implements Exception {
  GwsException(this.message, {this.exitCode, this.stderr});
  final String message;
  final int? exitCode;
  final String? stderr;

  @override
  String toString() => 'GwsException: $message';
}

Future<String> runGws(
  List<String> args, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final result = await Process.run('gws', args).timeout(
    timeout,
    onTimeout: () =>
        throw GwsException('gws timed out after ${timeout.inSeconds}s'),
  );
  if (result.exitCode != 0) {
    throw GwsException(
      'gws exited with code ${result.exitCode}',
      exitCode: result.exitCode,
      stderr: (result.stderr as String?)?.trim(),
    );
  }
  return result.stdout as String;
}

Map<String, dynamic> decodeJsonObject(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) throw GwsException('empty response from gws');
  final decoded = jsonDecode(trimmed);
  if (decoded is! Map<String, dynamic>) {
    throw GwsException('expected JSON object, got ${decoded.runtimeType}');
  }
  return decoded;
}
