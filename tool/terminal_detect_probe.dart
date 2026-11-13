import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/src/color_detect.dart';
import 'package:dart_tui/src/program.dart'
    show PlainSession, Program, withEnvironment;

void main(List<String> arguments) {
  final mode = arguments.single;
  if (mode == 'unrelated') {
    IOOverrides.runZoned(probe, createDirectory: Directory.new);
  } else if (mode.startsWith('fake-')) {
    final fake = _FakeStdout(mode == 'fake-true');
    IOOverrides.runZoned(probe, stdout: () => fake);
  } else {
    probe();
  }
}

void probe() {
  final program = Program(
    options: [
      withEnvironment({'TERM': 'xterm-256color'})
    ],
  );
  stderr.writeln(jsonEncode({
    'hasTerminal': stdout.hasTerminal,
    'stdioType': stdioType(stdout).name,
    'stdoutIsTerminal': stdoutIsTerminal(),
    'profile': detectColorProfile(
      environment: {'TERM': 'xterm-256color'},
    ).name,
    'plain': PlainSession.open(program) != null,
  }));
}

final class _FakeStdout implements Stdout {
  _FakeStdout(this.hasTerminal);

  @override
  final bool hasTerminal;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
