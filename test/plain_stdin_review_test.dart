import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  test('closed pipe preserves pushed-back answers before EOF', () async {
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'tool/pty_program_probe.dart', 'plain-chain'],
    );
    addTearDown(() => process.kill(ProcessSignal.sigkill));
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    process.stdin.add(utf8.encode('Ada\nGrace\n'));
    await process.stdin.close();
    expect(await process.exitCode.timeout(const Duration(seconds: 15)), 0,
        reason: await errors);
    final text = await output;
    expect(text, contains('ANSWERS=Ada|Grace|null'));
    expect(text, isNot(contains('\x1b')));
  }, skip: Platform.isWindows);

  test('plain helpers that never read stdin work outside the main isolate',
      () async {
    final text = await Isolate.run(() async {
      final output = StreamController<List<int>>();
      final text = output.stream.transform(utf8.decoder).join();
      final sink = IOSink(output.sink);
      final options = [
        withPlainMode(),
        withEnvironment(const {}),
        withOutput(sink),
      ];
      await pager('Page', options: options);
      final value =
          await spin(Future.value(42), label: 'Work', options: options);
      await sink.close();
      return '$value:${await text}';
    });
    expect(text, '42:Page\nWork…\n✓ Work\n');
  });
}
