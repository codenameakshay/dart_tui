import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('non-terminal stdin remains a no-op', () async {
    if (!Platform.isMacOS && !Platform.isLinux) return;

    final probe = '${Directory.current.path}/tool/posix_terminal_probe.dart';
    final result = await Process.run(Platform.resolvedExecutable, [
      probe,
      '--non-tty',
    ]);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  test('raw input mode restores exactly the prior flags across child changes',
      () async {
    if (!Platform.isMacOS && !Platform.isLinux) return;

    final probe = '${Directory.current.path}/tool/posix_terminal_probe.dart';
    final python = await Process.run('python3', [
      '-c',
      '''
import os, pty, subprocess, sys
master, slave = pty.openpty()
try:
    result = subprocess.run([sys.argv[1], sys.argv[2]], stdin=slave,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    raise SystemExit(result.returncode)
finally:
    os.close(master)
    os.close(slave)
''',
      Platform.resolvedExecutable,
      probe,
    ]);

    expect(python.exitCode, 0, reason: '${python.stdout}\n${python.stderr}');
    expect(python.stdout, contains('POSIX raw mode PTY probe passed'));
  });
}
