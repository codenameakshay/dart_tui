import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('default stdin readers release after immediate quits in child isolates',
      () async {
    final probe = await _ProbeProcess.start();
    addTearDown(probe.killIfRunning);

    await probe.readUntil('ISOLATE_PROGRAMS_DONE');
    expect(await probe.waitForExit(), 0, reason: await probe.errors);
  });

  test('concurrent default programs both receive input and exit', () async {
    final probe = await _ProbeProcess.start('concurrent');
    addTearDown(probe.killIfRunning);

    await probe.readUntil('CONCURRENT_READY');
    probe.process.stdin.write('q');
    await probe.process.stdin.flush();
    await probe.process.stdin.close();

    await probe.readUntil('CONCURRENT_DONE');
    expect(await probe.waitForExit(), 0, reason: await probe.errors);
  });

  test('a fresh default program can quit after stdin reaches EOF', () async {
    final probe = await _ProbeProcess.start('eof');
    addTearDown(probe.killIfRunning);

    await probe.readUntil('EOF_READY');
    probe.process.stdin.write('q');
    await probe.process.stdin.flush();
    await probe.process.stdin.close();

    await probe.readUntil('EOF_CHAIN_DONE');
    expect(await probe.waitForExit(), 0, reason: await probe.errors);
  });

  test('SIGTERM filter can veto then quit and handler removal restores default',
      () async {
    if (!Platform.isLinux && !Platform.isMacOS) return;
    final probe = await _ProbeProcess.start('term');
    addTearDown(probe.killIfRunning);

    await probe.readUntil('TERM_READY');
    probe.process.kill(ProcessSignal.sigterm);
    await probe.readUntil('TERM_VETOED');
    probe.process.kill(ProcessSignal.sigterm);
    await probe.readUntil('TERM_AFTER_READY');

    probe.process.kill(ProcessSignal.sigterm);
    expect(await probe.waitForExit(), -ProcessSignal.sigterm.signalNumber,
        reason: 'the process retained a SIGTERM watcher after Program.run');
  });
}

final class _ProbeProcess {
  _ProbeProcess(this.process)
      : lines = StreamIterator<String>(
          process.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter()),
        ),
        errors = process.stderr.transform(utf8.decoder).join();

  final Process process;
  final StreamIterator<String> lines;
  final Future<String> errors;

  static Future<_ProbeProcess> start([String? scenario]) async {
    final root = Directory.current.path;
    final process = await Process.start(
      Platform.resolvedExecutable,
      [
        'run',
        '$root/tool/pty_stdin_isolate_probe.dart',
        if (scenario != null) scenario,
      ],
      workingDirectory: root,
    );
    return _ProbeProcess(process);
  }

  Future<void> readUntil(String marker) async {
    while (await lines.moveNext().timeout(const Duration(seconds: 12))) {
      if (lines.current.contains(marker)) return;
    }
    fail('child exited before $marker; stderr=${await errors}');
  }

  Future<int> waitForExit() => process.exitCode.timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          throw TimeoutException('stdin probe did not exit');
        },
      );

  Future<void> killIfRunning() async {
    if (process.kill(ProcessSignal.sigkill)) {
      await process.exitCode.timeout(const Duration(seconds: 2));
    }
    await lines.cancel();
  }
}
